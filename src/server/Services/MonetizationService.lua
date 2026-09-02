--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MonetizationService = {}

local playerDataService: any = nil
local telemetryService: any = nil
local stateRefreshCallback: ((Player) -> ())? = nil
local entitlements: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any

local function defaults(): any
	return {
		AutomationPro = false,
		ExecutiveDashboard = false,
		FounderClub = false,
	}
end

local function copy(value: any): any
	local output = {}
	for key, child in pairs(value) do
		output[key] = child
	end
	return output
end

local function idForOffer(key: string): any
	if key == "StarterCapital" or key == "FocusBoost" or key == "RevenueSprint" then
		return Config.Monetization.DeveloperProducts[key]
	elseif key == "AutomationPro" or key == "ExecutiveDashboard" then
		return Config.Monetization.Passes[key]
	elseif key == "FounderClub" then
		return Config.Monetization.Subscriptions[key]
	end
	return nil
end

local function isConfiguredOffer(key: string): boolean
	local value = idForOffer(key)
	if type(value) == "number" then
		return value > 0
	end
	if type(value) == "string" then
		return value ~= ""
	end
	return false
end

local function notifyState(player: Player)
	if stateRefreshCallback then
		task.spawn(stateRefreshCallback, player)
	end
end

function MonetizationService.SetStateRefreshCallback(callback: (Player) -> ())
	stateRefreshCallback = callback
end

function MonetizationService.GetEntitlements(player: Player): any
	return copy(entitlements[player] or defaults())
end

function MonetizationService.Refresh(player: Player): any
	local result = defaults()

	local automationPassId = Config.Monetization.Passes.AutomationPro
	if automationPassId > 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, automationPassId)
		end)
		if ok then
			result.AutomationPro = owns == true
		end
	end

	local dashboardPassId = Config.Monetization.Passes.ExecutiveDashboard
	if dashboardPassId > 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, dashboardPassId)
		end)
		if ok then
			result.ExecutiveDashboard = owns == true
		end
	end

	local subscriptionId = Config.Monetization.Subscriptions.FounderClub
	if subscriptionId ~= "" then
		local ok, status = pcall(function()
			return MarketplaceService:GetUserSubscriptionStatusAsync(player, subscriptionId)
		end)
		if ok and type(status) == "table" then
			result.FounderClub = status.IsSubscribed == true
		end
	end

	entitlements[player] = result
	notifyState(player)
	return copy(result)
end

function MonetizationService.GetOfferCatalog(player: Player, order: { string }): { any }
	local owned = entitlements[player] or defaults()
	local output = {}
	for index, key in ipairs(order) do
		local definition = Config.Monetization.Offers[key]
		if definition then
			local isOwned = false
			if definition.Kind == "GamePass" or definition.Kind == "Subscription" then
				isOwned = owned[key] == true
			end
			table.insert(output, {
				key = key,
				displayName = definition.DisplayName,
				benefit = definition.Benefit,
				kind = definition.Kind,
				configured = isConfiguredOffer(key),
				owned = isOwned,
				layoutOrder = index,
			})
		end
	end
	return output
end

function MonetizationService.PromptOffer(player: Player, key: string): (boolean, string?)
	local definition = Config.Monetization.Offers[key]
	if not definition then
		return false, "unknown_offer"
	end
	if not isConfiguredOffer(key) then
		return false, "offer_not_configured"
	end

	local current = entitlements[player] or defaults()
	if (definition.Kind == "GamePass" or definition.Kind == "Subscription") and current[key] then
		return false, "already_owned"
	end

	local offerId = idForOffer(key)
	local ok, err = pcall(function()
		if definition.Kind == "DeveloperProduct" then
			MarketplaceService:PromptProductPurchase(player, offerId)
		elseif definition.Kind == "GamePass" then
			MarketplaceService:PromptGamePassPurchase(player, offerId)
		elseif definition.Kind == "Subscription" then
			MarketplaceService:PromptSubscriptionPurchase(player, offerId)
		else
			error("unsupported_offer_kind")
		end
	end)
	if not ok then
		warn(("Could not prompt offer %s: %s"):format(key, tostring(err)))
		return false, "prompt_failed"
	end

	telemetryService.Track(player, "OfferPrompted", 1, {
		offerKey = key,
		offerKind = definition.Kind,
	})
	return true, nil
end

local function configuredProductGrant(productId: number): ((any) -> ())?
	if productId == Config.Monetization.DeveloperProducts.StarterCapital and productId > 0 then
		return function(data)
			data.Cash += Config.Monetization.Grants.StarterCapitalCash
		end
	end
	if productId == Config.Monetization.DeveloperProducts.FocusBoost and productId > 0 then
		return function(data)
			data.Boosts.FocusCharges += Config.Monetization.Grants.FocusBoostCharges
		end
	end
	if productId == Config.Monetization.DeveloperProducts.RevenueSprint and productId > 0 then
		return function(data)
			data.Boosts.RevenueMultiplierUntil = math.max(data.Boosts.RevenueMultiplierUntil, os.time())
				+ Config.Monetization.Grants.RevenueSprintSeconds
		end
	end
	return nil
end

local function productKey(productId: number): string
	for key, configuredId in pairs(Config.Monetization.DeveloperProducts) do
		if configuredId == productId then
			return key
		end
	end
	return "UnknownProduct"
end

local function processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local playerId = tonumber(receiptInfo.PlayerId)
	local productId = tonumber(receiptInfo.ProductId)
	local purchaseId = tostring(receiptInfo.PurchaseId or "")
	if not playerId or not productId or purchaseId == "" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local grant = configuredProductGrant(productId)
	if not grant then
		warn(("No grant is configured for developer product %d"):format(productId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, updatedData, newlyGranted = playerDataService.ApplyReceipt(playerId, purchaseId, grant)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(playerId)
	if player and newlyGranted then
		local key = productKey(productId)
		telemetryService.Track(player, "PurchaseGranted", 1, {
			offerKey = key,
			offerKind = "DeveloperProduct",
		})
		if key == "StarterCapital" then
			telemetryService.LogEconomy(
				player,
				Enum.AnalyticsEconomyFlowType.Source,
				Config.Monetization.Grants.StarterCapitalCash,
				updatedData.Cash,
				Enum.AnalyticsEconomyTransactionType.IAP.Name,
				key,
				{ context = "developer_product" }
			)
		end
		notifyState(player)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Start(dataService: any, telemetry: any)
	playerDataService = dataService
	telemetryService = telemetry
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
		if not player:IsA("Player") or not wasPurchased then
			return
		end
		local current = entitlements[player] or defaults()
		if gamePassId == Config.Monetization.Passes.AutomationPro then
			current.AutomationPro = true
		elseif gamePassId == Config.Monetization.Passes.ExecutiveDashboard then
			current.ExecutiveDashboard = true
		else
			return
		end
		entitlements[player] = current
		telemetryService.Track(player, "PassConfirmed", 1, { gamePassIdConfigured = true })
		notifyState(player)
	end)

	MarketplaceService.PromptSubscriptionPurchaseFinished:Connect(function(player, subscriptionId, didTryPurchasing)
		if not didTryPurchasing or subscriptionId ~= Config.Monetization.Subscriptions.FounderClub then
			return
		end
		task.delay(2, function()
			if player.Parent == Players then
				MonetizationService.Refresh(player)
				telemetryService.Track(player, "SubscriptionStatusRefreshed", 1, {})
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		entitlements[player] = nil
	end)
end

return MonetizationService
