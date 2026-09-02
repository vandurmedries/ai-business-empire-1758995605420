--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local AIService = {}

local TEMPLATES = {
	cycle_streak = {
		Title = "Ship a focused work sprint",
		Brief = "Run company cycles and turn your departments into measurable revenue.",
		TargetMetric = "RunCycles",
		MinTarget = 3,
		MaxTarget = 12,
		BaseReward = 90,
	},
	revenue_target = {
		Title = "Reach the next revenue milestone",
		Brief = "Earn company cash through the core business loop.",
		TargetMetric = "EarnCash",
		MinTarget = 150,
		MaxTarget = 5000,
		BaseReward = 120,
	},
	customer_growth = {
		Title = "Win new customers",
		Brief = "Grow demand by balancing marketing, sales, and product quality.",
		TargetMetric = "GainCustomers",
		MinTarget = 5,
		MaxTarget = 250,
		BaseReward = 110,
	},
	department_upgrade = {
		Title = "Invest in your operating system",
		Brief = "Upgrade a department to increase long-term company power.",
		TargetMetric = "UpgradeDepartment",
		MinTarget = 1,
		MaxTarget = 3,
		BaseReward = 140,
	},
	reputation_lift = {
		Title = "Improve customer trust",
		Brief = "Strengthen product quality and raise your company reputation.",
		TargetMetric = "ImproveReputation",
		MinTarget = 1,
		MaxTarget = 10,
		BaseReward = 100,
	},
}

local TEMPLATE_ORDER = {
	"cycle_streak",
	"revenue_target",
	"customer_growth",
	"department_upgrade",
	"reputation_lift",
}

local missionSchema = HttpService:JSONEncode({
	type = "object",
	additionalProperties = false,
	properties = {
		templateId = {
			type = "string",
			["enum"] = TEMPLATE_ORDER,
		},
		targetValue = {
			type = "integer",
			minimum = 1,
			maximum = 5000,
		},
		rewardCash = {
			type = "integer",
			minimum = 25,
			maximum = Config.Mission.MaximumRewardCash,
		},
		durationMinutes = {
			type = "integer",
			minimum = 10,
			maximum = Config.Mission.MaximumDurationMinutes,
		},
	},
	required = { "templateId", "targetValue", "rewardCash", "durationMinutes" },
})

local generator: any = nil
local nextNativeRequestAt = 0

local function createGenerator(): any
	local ok, value = pcall(function()
		local textGenerator = Instance.new("TextGenerator")
		textGenerator.Name = "FounderMissionPlanner"
		textGenerator.SystemPrompt = [[
You create missions for AI Founder Empire, a Roblox business simulation. Your objective is to improve fun, comprehension, retention, trust, and sustainable voluntary monetization.

Choose only one of the supplied curated mission template IDs. Adapt target, reward, and duration to the player's current progression. Keep the mission achievable and useful. Never claim the player will earn real money. Never create gambling, paid random rewards, external purchases, deceptive urgency, pressure aimed at minors, price changes, autonomous publishing, or ad spend. Output only JSON matching the supplied schema.
]]
		textGenerator.Temperature = 0.4
		textGenerator.TopP = 0.5
		textGenerator.Parent = script
		return textGenerator
	end)
	if not ok then
		warn("Roblox native TextGenerator is unavailable; missions will use the deterministic safe planner")
		return nil
	end
	return value
end

generator = createGenerator()

local function fallbackSelection(data: any): any
	local index = ((data.CompletedMissions or 0) % #TEMPLATE_ORDER) + 1
	local templateId = TEMPLATE_ORDER[index]
	if templateId == "reputation_lift" and data.Reputation >= 95 then
		templateId = "cycle_streak"
	end
	local template = TEMPLATES[templateId]
	local level = math.max(1, data.Level)
	local target = template.MinTarget
	if template.TargetMetric == "RunCycles" then
		target = math.clamp(3 + math.floor(level / 3), template.MinTarget, template.MaxTarget)
	elseif template.TargetMetric == "EarnCash" then
		target = math.clamp(150 + (level * 75), template.MinTarget, template.MaxTarget)
	elseif template.TargetMetric == "GainCustomers" then
		target = math.clamp(5 + (level * 3), template.MinTarget, template.MaxTarget)
	elseif template.TargetMetric == "UpgradeDepartment" then
		target = math.clamp(1 + math.floor(level / 10), template.MinTarget, template.MaxTarget)
	elseif template.TargetMetric == "ImproveReputation" then
		target = math.clamp(2 + math.floor(level / 8), template.MinTarget, template.MaxTarget)
	end
	return {
		templateId = templateId,
		targetValue = target,
		rewardCash = math.clamp(template.BaseReward + (level * 15), 50, Config.Mission.MaximumRewardCash),
		durationMinutes = 240,
		source = "local_fallback",
	}
end

local function validateSelection(raw: any, data: any, sourceName: string): any
	if type(raw) ~= "table" then
		return fallbackSelection(data)
	end
	local mission = if type(raw.mission) == "table" then raw.mission else raw
	local templateId = tostring(mission.templateId or "")
	local template = TEMPLATES[templateId]
	if not template or not Config.Mission.AllowedTargets[template.TargetMetric] then
		return fallbackSelection(data)
	end
	if templateId == "reputation_lift" and data.Reputation >= 99 then
		return fallbackSelection(data)
	end

	return {
		templateId = templateId,
		targetValue = math.clamp(
			math.floor(tonumber(mission.targetValue) or template.MinTarget),
			template.MinTarget,
			template.MaxTarget
		),
		rewardCash = math.clamp(
			math.floor(tonumber(mission.rewardCash) or template.BaseReward),
			25,
			Config.Mission.MaximumRewardCash
		),
		durationMinutes = math.clamp(
			math.floor(tonumber(mission.durationMinutes) or 240),
			10,
			Config.Mission.MaximumDurationMinutes
		),
		source = sourceName,
	}
end

local function nativeSelection(data: any, liveConfig: any): any?
	if not generator then
		return nil
	end
	if os.clock() < nextNativeRequestAt then
		return nil
	end
	nextNativeRequestAt = os.clock() + 0.65

	local prompt = HttpService:JSONEncode({
		objective = "Choose the single best safe mission for this player's next session goal.",
		company = {
			level = data.Level,
			cash = data.Cash,
			lifetimeRevenue = data.LifetimeRevenue,
			customers = data.Customers,
			reputation = data.Reputation,
			completedMissions = data.CompletedMissions,
			departments = data.Departments,
		},
		context = {
			experimentId = liveConfig.ExperimentId,
			variant = liveConfig.Variant,
			missionPromptVariant = liveConfig.MissionPromptVariant,
		},
		allowedTemplateIds = TEMPLATE_ORDER,
	})

	local ok, response = pcall(function()
		return generator:GenerateTextAsync({
			UserPrompt = prompt,
			MaxTokens = 160,
			JsonSchema = missionSchema,
		})
	end)
	if not ok or type(response) ~= "table" or type(response.GeneratedText) ~= "string" then
		return nil
	end

	local decodeOk, decoded = pcall(function()
		return HttpService:JSONDecode(response.GeneratedText)
	end)
	if not decodeOk then
		return nil
	end

	return validateSelection(decoded, data, "roblox_native_ai")
end

function AIService.CreateMission(data: any, liveConfig: any, _sessionId: string): any
	local selection = nativeSelection(data, liveConfig) or fallbackSelection(data)
	local template = TEMPLATES[selection.templateId]
	local now = os.time()
	return {
		Id = HttpService:GenerateGUID(false),
		TemplateId = selection.templateId,
		Title = template.Title,
		Brief = template.Brief,
		TargetMetric = template.TargetMetric,
		TargetValue = selection.targetValue,
		Progress = 0,
		RewardCash = selection.rewardCash,
		IssuedAt = now,
		ExpiresAt = now + (selection.durationMinutes * 60),
		Source = selection.source,
	}
end

return AIService
