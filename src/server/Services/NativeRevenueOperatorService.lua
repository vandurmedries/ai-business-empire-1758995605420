--!strict

local HttpService = game:GetService("HttpService")

local LiveConfigService = require(script.Parent:WaitForChild("LiveConfigService"))

local NativeRevenueOperatorService = {}

local EVALUATION_SECONDS = 15 * 60
local MINIMUM_SESSIONS = 5
local MINIMUM_NEW_SESSIONS = 3

local EXPERIMENTS = {
	control = {
		experimentId = "native-control",
		variant = "control",
	},
	tutorial_benefit_first = {
		experimentId = "native-tutorial-benefit-first",
		variant = "benefit_first",
		tutorialHintVariant = "benefit_first",
	},
	tutorial_goal_first = {
		experimentId = "native-tutorial-goal-first",
		variant = "goal_first",
		tutorialHintVariant = "goal_first",
	},
	mission_reward_first = {
		experimentId = "native-mission-reward-first",
		variant = "reward_first",
		missionPromptVariant = "reward_first",
	},
	mission_challenge_first = {
		experimentId = "native-mission-challenge-first",
		variant = "challenge_first",
		missionPromptVariant = "challenge_first",
	},
	value_demo = {
		experimentId = "native-value-demo",
		variant = "value_demo",
		valueDemoEnabled = true,
	},
	shop_automation_first = {
		experimentId = "native-shop-automation-first",
		variant = "automation_first",
		shopOrder = {
			"AutomationPro",
			"FounderClub",
			"ExecutiveDashboard",
			"RevenueSprint",
			"FocusBoost",
			"StarterCapital",
		},
	},
	shop_subscription_first = {
		experimentId = "native-shop-subscription-first",
		variant = "subscription_first",
		shopOrder = {
			"FounderClub",
			"AutomationPro",
			"ExecutiveDashboard",
			"RevenueSprint",
			"FocusBoost",
			"StarterCapital",
		},
	},
	pacing_faster = {
		experimentId = "native-pacing-faster",
		variant = "pacing_faster",
		cyclePacingMultiplier = 0.9,
	},
}

local EXPERIMENT_IDS = {
	"control",
	"tutorial_benefit_first",
	"tutorial_goal_first",
	"mission_reward_first",
	"mission_challenge_first",
	"value_demo",
	"shop_automation_first",
	"shop_subscription_first",
	"pacing_faster",
}

local metrics = {
	sessions = 0,
	cycles = 0,
	missionsStarted = 0,
	missionsCompleted = 0,
	offerPrompts = 0,
	purchases = 0,
	onboardingSteps = 0,
}

local generator: any = nil
local closing = false
local lastEvaluatedSessions = 0
local lastExperimentId = "control"

local schema = HttpService:JSONEncode({
	type = "object",
	additionalProperties = false,
	properties = {
		experimentId = {
			type = "string",
			["enum"] = EXPERIMENT_IDS,
		},
		rationale = {
			type = "string",
			maxLength = 240,
		},
		confidence = {
			type = "number",
			minimum = 0,
			maximum = 1,
		},
	},
	required = { "experimentId", "rationale", "confidence" },
})

local function createGenerator(): any
	local ok, value = pcall(function()
		local textGenerator = Instance.new("TextGenerator")
		textGenerator.Name = "NativeRevenueOperator"
		textGenerator.SystemPrompt = [[
You are the revenue operator for a Roblox business simulation. Your mission is to maximize sustainable creator revenue over 90 days by improving fun, retention, comprehension, trust, and voluntary purchase value.

Choose exactly one experiment from the supplied allowlist. Never propose price changes, external purchase links, paid random rewards, deceptive scarcity, pressure aimed at minors, autonomous publishing, ad spend, or claims that players will earn real money. Prefer the smallest reversible experiment supported by the metrics. Output only the required JSON object.
]]
		textGenerator.Temperature = 0.4
		textGenerator.TopP = 0.5
		textGenerator.Parent = script
		return textGenerator
	end)
	if not ok then
		warn("Roblox native TextGenerator is unavailable; the revenue operator will use safe heuristics")
		return nil
	end
	return value
end

local function ratio(numerator: number, denominator: number): number
	if denominator <= 0 then
		return 0
	end
	return numerator / denominator
end

local function snapshot(): any
	return {
		sessions = metrics.sessions,
		cycles = metrics.cycles,
		cyclesPerSession = ratio(metrics.cycles, metrics.sessions),
		missionsStarted = metrics.missionsStarted,
		missionsCompleted = metrics.missionsCompleted,
		missionCompletionRate = ratio(metrics.missionsCompleted, metrics.missionsStarted),
		offerPrompts = metrics.offerPrompts,
		purchases = metrics.purchases,
		purchaseSignalRate = ratio(metrics.purchases, metrics.offerPrompts),
		onboardingSteps = metrics.onboardingSteps,
		currentExperimentId = lastExperimentId,
		availableExperiments = EXPERIMENT_IDS,
	}
end

local function heuristicExperiment(): string
	if metrics.cycles < metrics.sessions * 2 then
		return "tutorial_goal_first"
	end
	if metrics.missionsStarted > 2 and ratio(metrics.missionsCompleted, metrics.missionsStarted) < 0.35 then
		return "mission_reward_first"
	end
	if metrics.offerPrompts < math.max(2, math.floor(metrics.sessions * 0.25)) then
		return "value_demo"
	end
	if metrics.offerPrompts >= 5 and metrics.purchases == 0 then
		return "shop_automation_first"
	end
	return "control"
end

local function chooseWithAI(): string?
	if not generator then
		return nil
	end

	local prompt = HttpService:JSONEncode({
		objective = "Select one safe, reversible experiment that is most likely to improve sustainable creator revenue.",
		metrics = snapshot(),
	})

	local ok, response = pcall(function()
		return generator:GenerateTextAsync({
			UserPrompt = prompt,
			MaxTokens = 180,
			JsonSchema = schema,
		})
	end)
	if not ok or type(response) ~= "table" or type(response.GeneratedText) ~= "string" then
		return nil
	end

	local decodeOk, decoded = pcall(function()
		return HttpService:JSONDecode(response.GeneratedText)
	end)
	if not decodeOk or type(decoded) ~= "table" then
		return nil
	end

	local experimentId = tostring(decoded.experimentId or "")
	if not EXPERIMENTS[experimentId] then
		return nil
	end
	return experimentId
end

local function evaluate()
	if metrics.sessions < MINIMUM_SESSIONS then
		return
	end
	if metrics.sessions - lastEvaluatedSessions < MINIMUM_NEW_SESSIONS then
		return
	end

	local experimentId = chooseWithAI() or heuristicExperiment()
	local experiment = EXPERIMENTS[experimentId]
	if not experiment then
		return
	end

	LiveConfigService.ApplyNativeExperiment(experiment)
	lastExperimentId = experimentId
	lastEvaluatedSessions = metrics.sessions
	print(("Native revenue operator activated safe experiment: %s"):format(experimentId))
end

local function observe(_player: Player, eventName: string, value: number, _fields: any)
	local amount = math.max(0, tonumber(value) or 0)
	if eventName == "PlayerSessionStarted" then
		metrics.sessions += 1
	elseif eventName == "CompanyCycleCompleted" then
		metrics.cycles += 1
	elseif eventName == "MissionStarted" then
		metrics.missionsStarted += 1
	elseif eventName == "MissionCompleted" then
		metrics.missionsCompleted += 1
	elseif eventName == "OfferPrompted" then
		metrics.offerPrompts += 1
	elseif eventName == "PurchaseGranted" or eventName == "PassConfirmed" then
		metrics.purchases += math.max(1, math.floor(amount))
	elseif eventName == "SubscriptionStatusRefreshed" then
		metrics.purchases += 1
	elseif eventName == "OnboardingStep" then
		metrics.onboardingSteps += 1
	end
end

function NativeRevenueOperatorService.Start(telemetryService: any)
	closing = false
	generator = createGenerator()
	telemetryService.RegisterObserver(observe)

	task.spawn(function()
		while not closing do
			task.wait(EVALUATION_SECONDS)
			if not closing then
				evaluate()
			end
		end
	end)
end

function NativeRevenueOperatorService.EvaluateNow()
	evaluate()
end

function NativeRevenueOperatorService.GetStatus(): any
	return {
		metrics = snapshot(),
		generatorAvailable = generator ~= nil,
		lastExperimentId = lastExperimentId,
	}
end

function NativeRevenueOperatorService.Shutdown()
	closing = true
	if generator then
		generator:Destroy()
		generator = nil
	end
end

return NativeRevenueOperatorService
