--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BackendClient = require(script.Parent:WaitForChild("BackendClient"))

local LiveConfigService = {}

local current: any = nil
local closing = false

local ALLOWED_HINTS = {
	step_by_step = true,
	benefit_first = true,
	goal_first = true,
}
local ALLOWED_MISSION_PROMPTS = {
	progress_first = true,
	reward_first = true,
	challenge_first = true,
}
local OFFER_KEYS = {
	FounderClub = true,
	AutomationPro = true,
	ExecutiveDashboard = true,
	StarterCapital = true,
	FocusBoost = true,
	RevenueSprint = true,
}

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local output = {}
	for key, child in pairs(value) do
		output[key] = copy(child)
	end
	return output
end

local function defaults(): any
	return copy(Config.LiveConfigDefaults)
end

local function validateShopOrder(value: any): { string }
	local output = {}
	local seen = {}
	if type(value) == "table" then
		for _, rawKey in ipairs(value) do
			local key = tostring(rawKey)
			if OFFER_KEYS[key] and not seen[key] then
				seen[key] = true
				table.insert(output, key)
			end
		end
	end
	for _, key in ipairs(Config.LiveConfigDefaults.ShopOrder) do
		if not seen[key] then
			table.insert(output, key)
		end
	end
	return output
end

local function validate(raw: any): any
	local output = defaults()
	if type(raw) ~= "table" then
		return output
	end
	local source = if type(raw.config) == "table" then raw.config else raw

	output.ExperimentId = string.sub(tostring(source.experimentId or source.ExperimentId or "control"), 1, 80)
	output.Variant = string.sub(tostring(source.variant or source.Variant or "control"), 1, 40)

	local hint = tostring(source.tutorialHintVariant or source.TutorialHintVariant or "")
	if ALLOWED_HINTS[hint] then
		output.TutorialHintVariant = hint
	end

	local prompt = tostring(source.missionPromptVariant or source.MissionPromptVariant or "")
	if ALLOWED_MISSION_PROMPTS[prompt] then
		output.MissionPromptVariant = prompt
	end

	if type(source.valueDemoEnabled) == "boolean" then
		output.ValueDemoEnabled = source.valueDemoEnabled
	elseif type(source.ValueDemoEnabled) == "boolean" then
		output.ValueDemoEnabled = source.ValueDemoEnabled
	end

	output.CycleRewardMultiplier = math.clamp(
		tonumber(source.cycleRewardMultiplier or source.CycleRewardMultiplier) or 1,
		0.9,
		1.2
	)
	output.CyclePacingMultiplier = math.clamp(
		tonumber(source.cyclePacingMultiplier or source.CyclePacingMultiplier) or 1,
		0.8,
		1.2
	)
	output.ShopOrder = validateShopOrder(source.shopOrder or source.ShopOrder)

	return output
end

function LiveConfigService.Get(): any
	if not current then
		current = defaults()
	end
	return copy(current)
end

function LiveConfigService.ApplyNativeExperiment(raw: any): boolean
	current = validate(raw)
	return true
end

function LiveConfigService.Refresh(): boolean
	local ok, response = BackendClient.Get("/api/v1/config")
	if not ok then
		return false
	end
	current = validate(response)
	return true
end

function LiveConfigService.Start()
	closing = false
	current = defaults()
	if not BackendClient.IsConfigured() then
		return
	end

	task.spawn(LiveConfigService.Refresh)
	task.spawn(function()
		while not closing do
			task.wait(Config.BackendConfigRefreshSeconds)
			if not closing then
				LiveConfigService.Refresh()
			end
		end
	end)
end

function LiveConfigService.Shutdown()
	closing = true
end

return LiveConfigService
