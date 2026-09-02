--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local EconomyService = {}

local DEPARTMENT_NAMES = { "Product", "Marketing", "Sales" }

function EconomyService.IsDepartment(value: any): boolean
	return value == "Product" or value == "Marketing" or value == "Sales"
end

function EconomyService.GetUpgradeCost(departmentName: string, currentLevel: number): number
	local definition = Config.Departments[departmentName]
	if not definition then
		return math.huge
	end
	return math.max(1, math.floor(definition.BaseUpgradeCost * (definition.CostGrowth ^ (currentLevel - 1))))
end

function EconomyService.GetAllUpgradeCosts(data: any): any
	local output = {}
	for _, name in ipairs(DEPARTMENT_NAMES) do
		output[name] = EconomyService.GetUpgradeCost(name, data.Departments[name])
	end
	return output
end

function EconomyService.GetCompanyPower(data: any): number
	local power = 0
	for _, name in ipairs(DEPARTMENT_NAMES) do
		power += data.Departments[name] * Config.Departments[name].RevenueWeight
	end
	return power
end

function EconomyService.GetNextLevelXP(level: number): number
	return math.floor(Config.CoreLoop.LevelXPBase * (1.22 ^ math.max(0, level - 1)))
end

function EconomyService.GetCycleCooldown(entitlements: any, liveConfig: any): number
	local multiplier = tonumber(liveConfig.CyclePacingMultiplier) or 1
	if entitlements.AutomationPro then
		multiplier *= Config.CoreLoop.AutomationCooldownMultiplier
	end
	return math.max(2, Config.CoreLoop.CycleCooldownSeconds * multiplier)
end

function EconomyService.CalculateCycle(data: any, entitlements: any, liveConfig: any): any
	local companyPower = EconomyService.GetCompanyPower(data)
	local balanceScore = math.min(
		data.Departments.Product,
		data.Departments.Marketing,
		data.Departments.Sales
	)
	local baseRevenue = Config.CoreLoop.BaseRevenue + companyPower + (balanceScore * 2)
	local multiplier = tonumber(liveConfig.CycleRewardMultiplier) or 1
	local usedFocus = false
	local timedBoostActive = data.Boosts.RevenueMultiplierUntil > os.time()

	if data.Boosts.FocusCharges > 0 then
		multiplier *= Config.CoreLoop.FocusMultiplier
		usedFocus = true
	end
	if timedBoostActive then
		multiplier *= Config.CoreLoop.TimedBoostMultiplier
	end
	if entitlements.FounderClub then
		multiplier *= Config.CoreLoop.FounderClubMultiplier
	end

	local revenue = math.clamp(
		math.floor(baseRevenue * multiplier),
		Config.CoreLoop.MinimumRevenue,
		Config.CoreLoop.MaximumSingleCycleRevenue
	)
	local customers = math.max(1, math.floor((data.Departments.Marketing * 0.7) + (data.Departments.Sales * 0.5)))
	local qualityGap = data.Departments.Product - math.max(data.Departments.Marketing, data.Departments.Sales)
	local reputationDelta = if qualityGap >= 0 then 1 else if qualityGap <= -3 then -1 else 0
	local xp = math.max(5, math.floor(revenue * 0.25))

	return {
		revenue = revenue,
		customers = customers,
		reputationDelta = reputationDelta,
		xp = xp,
		usedFocus = usedFocus,
		timedBoostActive = timedBoostActive,
		multiplier = multiplier,
		companyPower = companyPower,
	}
end

function EconomyService.ApplyXP(data: any, amount: number): number
	data.XP += math.max(0, math.floor(amount))
	local levelsGained = 0
	while data.XP >= EconomyService.GetNextLevelXP(data.Level) and levelsGained < 20 do
		data.XP -= EconomyService.GetNextLevelXP(data.Level)
		data.Level += 1
		levelsGained += 1
	end
	return levelsGained
end

return EconomyService
