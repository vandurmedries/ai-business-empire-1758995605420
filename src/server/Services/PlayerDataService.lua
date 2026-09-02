--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlayerDataService = {}

local playerStore = DataStoreService:GetDataStore(Config.DataStoreName)
local sessions: { [Player]: any } = {}
local loadedCallbacks: { (Player) -> () } = {}
local closing = false

local ALLOWED_MUTATION_ERRORS = table.freeze({
	insufficient_cash = true,
	active_mission_exists = true,
})

local function mutationErrorCode(err: any): string
	local raw = tostring(err)
	local code = string.match(raw, "([%a][%w_]*)$")
	if code and ALLOWED_MUTATION_ERRORS[code] then
		return code
	end
	return "mutation_failed"
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

local function reconcile(defaults: any, loaded: any): any
	if type(defaults) ~= "table" then
		if loaded == nil then
			return defaults
		end
		return loaded
	end

	local result = if type(loaded) == "table" then deepCopy(loaded) else {}
	for key, defaultValue in pairs(defaults) do
		result[key] = reconcile(defaultValue, result[key])
	end
	return result
end

local function newData(): any
	local data = deepCopy(Config.InitialData)
	data.SchemaVersion = 1
	data.UpdatedAt = os.time()
	return data
end

local function boundedString(value: any, maximumLength: number): string
	return string.sub(tostring(value or ""), 1, maximumLength)
end

local function normalizeMission(value: any): any?
	if type(value) ~= "table" then
		return nil
	end

	local now = os.time()
	local targetMetric = boundedString(value.TargetMetric, 40)
	if not Config.Mission.AllowedTargets[targetMetric] then
		return nil
	end

	local targetValue = math.clamp(math.floor(tonumber(value.TargetValue) or 0), 1, 1_000_000_000)
	local expiresAt = math.floor(tonumber(value.ExpiresAt) or 0)
	if expiresAt <= now then
		return nil
	end
	expiresAt = math.min(expiresAt, now + (Config.Mission.MaximumDurationMinutes * 60))

	local id = boundedString(value.Id, 100)
	local templateId = boundedString(value.TemplateId, 60)
	if id == "" or templateId == "" then
		return nil
	end

	return {
		Id = id,
		TemplateId = templateId,
		Title = boundedString(value.Title, 100),
		Brief = boundedString(value.Brief, 240),
		TargetMetric = targetMetric,
		TargetValue = targetValue,
		Progress = math.clamp(math.floor(tonumber(value.Progress) or 0), 0, targetValue),
		RewardCash = math.clamp(
			math.floor(tonumber(value.RewardCash) or 0),
			0,
			Config.Mission.MaximumRewardCash
		),
		IssuedAt = math.clamp(math.floor(tonumber(value.IssuedAt) or now), 0, now),
		ExpiresAt = expiresAt,
		Source = boundedString(value.Source, 40),
	}
end

local function normalizeData(value: any): any
	local data = reconcile(newData(), value)
	data.Cash = math.max(0, math.floor(tonumber(data.Cash) or Config.InitialData.Cash))
	data.LifetimeRevenue = math.max(0, math.floor(tonumber(data.LifetimeRevenue) or 0))
	data.Customers = math.max(0, math.floor(tonumber(data.Customers) or 0))
	data.Reputation = math.clamp(math.floor(tonumber(data.Reputation) or 50), 0, 100)
	data.Level = math.max(1, math.floor(tonumber(data.Level) or 1))
	data.XP = math.max(0, math.floor(tonumber(data.XP) or 0))
	data.TutorialStep = math.clamp(math.floor(tonumber(data.TutorialStep) or 0), 0, 10)
	data.CompletedMissions = math.max(0, math.floor(tonumber(data.CompletedMissions) or 0))
	data.Departments.Product = math.clamp(math.floor(tonumber(data.Departments.Product) or 1), 1, 100)
	data.Departments.Marketing = math.clamp(math.floor(tonumber(data.Departments.Marketing) or 1), 1, 100)
	data.Departments.Sales = math.clamp(math.floor(tonumber(data.Departments.Sales) or 1), 1, 100)
	data.Boosts.FocusCharges = math.max(0, math.floor(tonumber(data.Boosts.FocusCharges) or 0))
	data.Boosts.RevenueMultiplierUntil = math.max(0, math.floor(tonumber(data.Boosts.RevenueMultiplierUntil) or 0))
	data.ActiveMission = normalizeMission(data.ActiveMission)

	local receipts = {}
	if type(data.ProcessedReceipts) == "table" then
		for _, rawReceipt in ipairs(data.ProcessedReceipts) do
			local receipt = boundedString(rawReceipt, 160)
			if receipt ~= "" then
				table.insert(receipts, receipt)
			end
		end
	end
	while #receipts > Config.MaximumRememberedReceipts do
		table.remove(receipts, 1)
	end
	data.ProcessedReceipts = receipts
	data.UpdatedAt = os.time()
	return data
end

local function keyForUserId(userId: number): string
	return (`player_{userId}`)
end

local function loadPlayer(player: Player)
	local data = newData()
	local ok, result = pcall(function()
		return playerStore:GetAsync(keyForUserId(player.UserId))
	end)
	if ok and result ~= nil then
		data = normalizeData(result)
	elseif not ok then
		warn(("Could not load data for %d: %s"):format(player.UserId, tostring(result)))
	end

	if player.Parent ~= Players then
		return
	end

	sessions[player] = data
	for _, callback in ipairs(loadedCallbacks) do
		task.spawn(callback, player)
	end
end

function PlayerDataService.OnLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
end

function PlayerDataService.IsLoaded(player: Player): boolean
	return sessions[player] ~= nil
end

function PlayerDataService.Get(player: Player): any?
	return sessions[player]
end

function PlayerDataService.Mutate(player: Player, callback: (any) -> ()): (boolean, string?)
	local data = sessions[player]
	if not data then
		return false, "data_not_loaded"
	end

	local ok, err = pcall(callback, data)
	if not ok then
		warn(("Player data mutation failed for %d: %s"):format(player.UserId, tostring(err)))
		return false, mutationErrorCode(err)
	end
	data.UpdatedAt = os.time()
	return true, nil
end

function PlayerDataService.Snapshot(player: Player, entitlements: any?, liveConfig: any?): any?
	local data = sessions[player]
	if not data then
		return nil
	end

	return {
		version = Config.Version,
		cash = data.Cash,
		lifetimeRevenue = data.LifetimeRevenue,
		customers = data.Customers,
		reputation = data.Reputation,
		level = data.Level,
		xp = data.XP,
		tutorialStep = data.TutorialStep,
		completedMissions = data.CompletedMissions,
		departments = deepCopy(data.Departments),
		boosts = {
			focusCharges = data.Boosts.FocusCharges,
			revenueMultiplierUntil = data.Boosts.RevenueMultiplierUntil,
		},
		activeMission = deepCopy(data.ActiveMission),
		entitlements = deepCopy(entitlements or {}),
		liveConfig = deepCopy(liveConfig or {}),
	}
end

function PlayerDataService.Save(player: Player): boolean
	local data = sessions[player]
	if not data then
		return true
	end

	local toSave = normalizeData(deepCopy(data))
	local ok, err = pcall(function()
		playerStore:UpdateAsync(keyForUserId(player.UserId), function()
			return toSave
		end)
	end)
	if not ok then
		warn(("Could not save data for %d: %s"):format(player.UserId, tostring(err)))
		return false
	end
	return true
end

local function containsReceipt(receipts: { any }, purchaseId: string): boolean
	for _, existing in ipairs(receipts) do
		if tostring(existing) == purchaseId then
			return true
		end
	end
	return false
end

function PlayerDataService.ApplyReceipt(
	userId: number,
	purchaseId: string,
	grant: (any) -> ()
): (boolean, any?, boolean)
	local updatedData = nil
	local newlyGranted = false
	local ok, err = pcall(function()
		updatedData = playerStore:UpdateAsync(keyForUserId(userId), function(current)
			local data = normalizeData(current)
			if containsReceipt(data.ProcessedReceipts, purchaseId) then
				newlyGranted = false
				return data
			end

			newlyGranted = true
			grant(data)
			table.insert(data.ProcessedReceipts, purchaseId)
			while #data.ProcessedReceipts > Config.MaximumRememberedReceipts do
				table.remove(data.ProcessedReceipts, 1)
			end
			data.UpdatedAt = os.time()
			return data
		end)
	end)

	if not ok or updatedData == nil then
		warn(("Receipt %s for %d could not be persisted: %s"):format(purchaseId, userId, tostring(err)))
		return false, nil, false
	end

	for player, _ in pairs(sessions) do
		if player.UserId == userId then
			sessions[player] = normalizeData(updatedData)
			break
		end
	end
	return true, updatedData, newlyGranted
end

function PlayerDataService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.Save(player)
		sessions[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(loadPlayer, player)
	end

	task.spawn(function()
		while not closing do
			task.wait(Config.AutoSaveSeconds)
			for player, _ in pairs(sessions) do
				task.spawn(PlayerDataService.Save, player)
			end
		end
	end)
end

function PlayerDataService.Shutdown()
	closing = true
	for player, _ in pairs(sessions) do
		PlayerDataService.Save(player)
	end
end

return PlayerDataService
