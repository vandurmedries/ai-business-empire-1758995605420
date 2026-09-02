--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RemoteNames = require(Shared:WaitForChild("Remotes"))

local AIService = require(script.Parent:WaitForChild("AIService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local LiveConfigService = require(script.Parent:WaitForChild("LiveConfigService"))
local MonetizationService = require(script.Parent:WaitForChild("MonetizationService"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local RateLimiter = require(script.Parent:WaitForChild("RateLimiter"))
local RemotesService = require(script.Parent:WaitForChild("RemotesService"))
local TelemetryService = require(script.Parent:WaitForChild("TelemetryService"))

local BusinessService = {}

local function responseError(code: string, state: any?, retryAfter: number?): any
	return {
		ok = false,
		error = code,
		state = state,
		retryAfter = retryAfter,
	}
end

local function getState(player: Player): any?
	local data = PlayerDataService.Get(player)
	if not data then
		return nil
	end
	local liveConfig = LiveConfigService.Get()
	local entitlements = MonetizationService.GetEntitlements(player)
	local state = PlayerDataService.Snapshot(player, entitlements, liveConfig)
	if not state then
		return nil
	end
	state.serverNow = os.time()
	state.nextLevelXP = EconomyService.GetNextLevelXP(data.Level)
	state.companyPower = EconomyService.GetCompanyPower(data)
	state.upgradeCosts = EconomyService.GetAllUpgradeCosts(data)
	state.cycleCooldownSeconds = EconomyService.GetCycleCooldown(entitlements, liveConfig)
	state.offers = MonetizationService.GetOfferCatalog(player, liveConfig.ShopOrder)
	state.hardPolicy = Config.HardPolicy
	return state
end

local function pushState(player: Player)
	local state = getState(player)
	if state then
		RemotesService.PushState(player, state)
	end
end

local function setTutorialStep(data: any, targetStep: number): boolean
	if data.TutorialStep >= targetStep then
		return false
	end
	data.TutorialStep = targetStep
	return true
end

local function advanceMission(data: any, metric: string, amount: number, entitlements: any): any?
	local mission = data.ActiveMission
	if not mission then
		return nil
	end
	if mission.ExpiresAt <= os.time() then
		data.ActiveMission = nil
		return {
			expired = true,
			completed = false,
		}
	end
	if mission.TargetMetric ~= metric or amount <= 0 then
		return nil
	end

	mission.Progress = math.min(mission.TargetValue, mission.Progress + amount)
	if mission.Progress < mission.TargetValue then
		return {
			expired = false,
			completed = false,
			progress = mission.Progress,
		}
	end

	local reward = mission.RewardCash
	if entitlements.FounderClub then
		reward = math.floor(reward * Config.Mission.FounderClubRewardMultiplier)
	end
	data.Cash += reward
	data.CompletedMissions += 1
	data.ActiveMission = nil
	return {
		expired = false,
		completed = true,
		reward = reward,
		templateId = mission.TemplateId,
	}
end

local function logMissionOutcome(player: Player, outcome: any?)
	if not outcome then
		return
	end
	if outcome.expired then
		TelemetryService.Track(player, "MissionExpired", 1, {})
	elseif outcome.completed then
		TelemetryService.Track(player, "MissionCompleted", 1, {
			templateId = outcome.templateId,
			reward = outcome.reward,
		})
		local data = PlayerDataService.Get(player)
		if data then
			TelemetryService.LogEconomy(
				player,
				Enum.AnalyticsEconomyFlowType.Source,
				outcome.reward,
				data.Cash,
				Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
				"MissionReward",
				{ context = "mission" }
			)
		end
		RemotesService.Toast(player, (`Mission complete: +{outcome.reward} cash`), "success")
	end
end

local function runCycle(player: Player): any
	local stateBefore = getState(player)
	if not stateBefore then
		return responseError("data_not_loaded", nil, 1)
	end

	local allowed, retryAfter = RateLimiter.Allow(player, "RunCycle", stateBefore.cycleCooldownSeconds)
	if not allowed then
		return responseError("cycle_cooldown", stateBefore, retryAfter)
	end

	local entitlements = MonetizationService.GetEntitlements(player)
	local liveConfig = LiveConfigService.Get()
	local result = nil
	local missionOutcome = nil
	local tutorialAdvanced = false
	local ok, err = PlayerDataService.Mutate(player, function(data)
		result = EconomyService.CalculateCycle(data, entitlements, liveConfig)
		data.Cash += result.revenue
		data.LifetimeRevenue += result.revenue
		data.Customers += result.customers
		data.Reputation = math.clamp(data.Reputation + result.reputationDelta, 0, 100)
		if result.usedFocus then
			data.Boosts.FocusCharges = math.max(0, data.Boosts.FocusCharges - 1)
		end
		result.levelsGained = EconomyService.ApplyXP(data, result.xp)
		tutorialAdvanced = setTutorialStep(data, 2)

		missionOutcome = advanceMission(data, "RunCycles", 1, entitlements)
		if not missionOutcome then
			missionOutcome = advanceMission(data, "EarnCash", result.revenue, entitlements)
		end
		if not missionOutcome then
			missionOutcome = advanceMission(data, "GainCustomers", result.customers, entitlements)
		end
		if not missionOutcome and result.reputationDelta > 0 then
			missionOutcome = advanceMission(data, "ImproveReputation", result.reputationDelta, entitlements)
		end
	end)
	if not ok then
		return responseError(err or "cycle_failed", getState(player), 1)
	end

	local data = PlayerDataService.Get(player)
	if data then
		TelemetryService.LogEconomy(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			result.revenue,
			data.Cash,
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			"CompanyCycle",
			{ context = "core_loop" }
		)
	end
	TelemetryService.Track(player, "CompanyCycleCompleted", result.revenue, {
		customers = result.customers,
		level = if data then data.Level else 1,
		boosted = result.multiplier > 1,
	})
	if tutorialAdvanced then
		TelemetryService.OnboardingStep(player, 2, "Completed first company cycle")
	end
	if result.levelsGained > 0 then
		TelemetryService.Track(player, "CompanyLevelUp", result.levelsGained, {
			level = if data then data.Level else 1,
		})
		RemotesService.Toast(player, "Company level increased", "success")
	end
	logMissionOutcome(player, missionOutcome)

	local state = getState(player)
	if state then
		RemotesService.PushState(player, state)
	end
	return {
		ok = true,
		state = state,
		result = result,
	}
end

local function upgradeDepartment(player: Player, rawDepartment: any): any
	local department = tostring(rawDepartment)
	if not EconomyService.IsDepartment(department) then
		return responseError("invalid_department", getState(player), nil)
	end
	local allowed, retryAfter = RateLimiter.Allow(player, "UpgradeDepartment", 0.4)
	if not allowed then
		return responseError("action_cooldown", getState(player), retryAfter)
	end
	if not PlayerDataService.IsLoaded(player) then
		return responseError("data_not_loaded", nil, 1)
	end

	local cost = 0
	local newLevel = 0
	local missionOutcome = nil
	local tutorialAdvanced = false
	local entitlements = MonetizationService.GetEntitlements(player)
	local ok, err = PlayerDataService.Mutate(player, function(data)
		cost = EconomyService.GetUpgradeCost(department, data.Departments[department])
		if data.Cash < cost then
			error("insufficient_cash")
		end
		data.Cash -= cost
		data.Departments[department] += 1
		newLevel = data.Departments[department]
		tutorialAdvanced = setTutorialStep(data, 3)
		missionOutcome = advanceMission(data, "UpgradeDepartment", 1, entitlements)
	end)
	if not ok then
		return responseError(err or "upgrade_failed", getState(player), nil)
	end

	local data = PlayerDataService.Get(player)
	if data then
		TelemetryService.LogEconomy(
			player,
			Enum.AnalyticsEconomyFlowType.Sink,
			cost,
			data.Cash,
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			department .. "Upgrade",
			{ context = "department_upgrade" }
		)
	end
	TelemetryService.Track(player, "DepartmentUpgraded", 1, {
		department = department,
		level = newLevel,
		cost = cost,
	})
	if tutorialAdvanced then
		TelemetryService.OnboardingStep(player, 3, "Upgraded first department")
	end
	logMissionOutcome(player, missionOutcome)

	local state = getState(player)
	if state then
		RemotesService.PushState(player, state)
	end
	return {
		ok = true,
		state = state,
		result = {
			department = department,
			level = newLevel,
			cost = cost,
		},
	}
end

local function requestMission(player: Player): any
	if not PlayerDataService.IsLoaded(player) then
		return responseError("data_not_loaded", nil, 1)
	end
	local allowed, retryAfter = RateLimiter.Allow(player, "RequestMission", Config.Mission.RequestCooldownSeconds)
	if not allowed then
		return responseError("mission_cooldown", getState(player), retryAfter)
	end

	local data = PlayerDataService.Get(player)
	if not data then
		return responseError("data_not_loaded", nil, 1)
	end
	if data.ActiveMission and data.ActiveMission.ExpiresAt > os.time() then
		return responseError("active_mission_exists", getState(player), nil)
	end

	local mission = AIService.CreateMission(data, LiveConfigService.Get(), TelemetryService.GetSessionId(player))
	local tutorialAdvanced = false
	local ok, err = PlayerDataService.Mutate(player, function(current)
		if current.ActiveMission and current.ActiveMission.ExpiresAt > os.time() then
			error("active_mission_exists")
		end
		current.ActiveMission = mission
		tutorialAdvanced = setTutorialStep(current, 4)
	end)
	if not ok then
		return responseError(err or "mission_failed", getState(player), nil)
	end

	TelemetryService.Track(player, "MissionStarted", 1, {
		templateId = mission.TemplateId,
		source = mission.Source,
		targetMetric = mission.TargetMetric,
	})
	if tutorialAdvanced then
		TelemetryService.OnboardingStep(player, 4, "Accepted first AI mission")
	end
	RemotesService.Toast(player, "Your AI operator created a new mission", "success")

	local state = getState(player)
	if state then
		RemotesService.PushState(player, state)
	end
	return {
		ok = true,
		state = state,
		result = mission,
	}
end

local function promptOffer(player: Player, rawKey: any): any
	local allowed, retryAfter = RateLimiter.Allow(player, "PromptOffer", 1)
	if not allowed then
		return responseError("action_cooldown", getState(player), retryAfter)
	end
	local key = string.sub(tostring(rawKey), 1, 40)
	local ok, err = MonetizationService.PromptOffer(player, key)
	if not ok then
		return responseError(err or "prompt_failed", getState(player), nil)
	end
	return {
		ok = true,
		state = getState(player),
	}
end

function BusinessService.Start()
	MonetizationService.SetStateRefreshCallback(pushState)

	RemotesService.GetRemoteFunction(RemoteNames.GetState).OnServerInvoke = function(player)
		local state = getState(player)
		if not state then
			return responseError("data_not_loaded", nil, 1)
		end
		return { ok = true, state = state }
	end
	RemotesService.GetRemoteFunction(RemoteNames.RunCycle).OnServerInvoke = runCycle
	RemotesService.GetRemoteFunction(RemoteNames.UpgradeDepartment).OnServerInvoke = upgradeDepartment
	RemotesService.GetRemoteFunction(RemoteNames.RequestMission).OnServerInvoke = requestMission
	RemotesService.GetRemoteFunction(RemoteNames.PromptOffer).OnServerInvoke = promptOffer

	PlayerDataService.OnLoaded(function(player)
		TelemetryService.OnboardingStep(player, 1, "Joined experience")
		TelemetryService.Track(player, "PlayerSessionStarted", 1, {
			gameVersion = Config.Version,
		})
		MonetizationService.Refresh(player)
		pushState(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		RateLimiter.Clear(player)
	end)
end

return BusinessService
