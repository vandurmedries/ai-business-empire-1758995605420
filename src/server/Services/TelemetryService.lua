--!strict

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BackendClient = require(script.Parent:WaitForChild("BackendClient"))

local TelemetryService = {}

local sessions: { [Player]: string } = setmetatable({}, { __mode = "k" }) :: any
local pending: { any } = {}
local observers: { (Player, string, number, any) -> () } = {}
local closing = false
local flushing = false
local backendEnabled = false

local ALLOWED_FIELD_TYPES = {
	string = true,
	number = true,
	boolean = true,
}

local function cleanText(value: any, maxLength: number): string
	local text = tostring(value)
	text = string.gsub(text, "[%c]", " ")
	return string.sub(text, 1, maxLength)
end

local function cleanFields(fields: any): any
	if type(fields) ~= "table" then
		return {}
	end

	local output = {}
	local count = 0
	for rawKey, rawValue in pairs(fields) do
		if count >= 10 then
			break
		end

		local valueType = type(rawValue)
		if ALLOWED_FIELD_TYPES[valueType] then
			local key = cleanText(rawKey, 40)
			if key ~= "" then
				if valueType == "string" then
					output[key] = cleanText(rawValue, 80)
				elseif valueType == "number" then
					output[key] = math.clamp(rawValue, -1e9, 1e9)
				else
					output[key] = rawValue
				end
				count += 1
			end
		end
	end
	return output
end

local function sessionFor(player: Player): string
	local existing = sessions[player]
	if existing then
		return existing
	end
	local sessionId = HttpService:GenerateGUID(false)
	sessions[player] = sessionId
	return sessionId
end

local function notifyObservers(player: Player, eventName: string, value: number, fields: any)
	for _, observer in ipairs(observers) do
		local ok, err = pcall(observer, player, eventName, value, fields)
		if not ok then
			warn(("Telemetry observer failed: %s"):format(tostring(err)))
		end
	end
end

local function enqueue(player: Player, eventName: string, value: number, fields: any?)
	if #pending >= 500 then
		table.remove(pending, 1)
	end

	table.insert(pending, {
		schemaVersion = 1,
		sessionId = sessionFor(player),
		event = cleanText(eventName, 60),
		value = math.clamp(value, -1e9, 1e9),
		occurredAt = os.time(),
		context = cleanFields(fields),
		gameVersion = Config.Version,
		placeId = game.PlaceId,
		universeId = game.GameId,
	})
end

function TelemetryService.RegisterObserver(observer: (Player, string, number, any) -> ())
	table.insert(observers, observer)
end

function TelemetryService.GetSessionId(player: Player): string
	return sessionFor(player)
end

function TelemetryService.Track(player: Player, eventName: string, value: number?, fields: any?)
	local safeName = cleanText(eventName, 60)
	local safeValue = tonumber(value) or 1
	local safeFields = cleanFields(fields)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, safeName, safeValue, {})
	end)
	notifyObservers(player, safeName, safeValue, safeFields)
	if backendEnabled then
		enqueue(player, safeName, safeValue, safeFields)
	end
end

function TelemetryService.OnboardingStep(player: Player, step: number, stepName: string)
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, cleanText(stepName, 60), {})
	end)
	TelemetryService.Track(player, "OnboardingStep", step, {
		step = step,
		stepName = cleanText(stepName, 60),
	})
end

function TelemetryService.LogEconomy(
	player: Player,
	flowType: Enum.AnalyticsEconomyFlowType,
	amount: number,
	endingBalance: number,
	transactionType: string,
	itemSku: string,
	fields: any?
)
	pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flowType,
			"CompanyCash",
			math.max(0, amount),
			math.max(0, endingBalance),
			cleanText(transactionType, 60),
			cleanText(itemSku, 60),
			{}
		)
	end)

	TelemetryService.Track(
		player,
		if flowType == Enum.AnalyticsEconomyFlowType.Source then "EconomySource" else "EconomySink",
		amount,
		{
			transactionType = cleanText(transactionType, 60),
			itemSku = cleanText(itemSku, 60),
			endingBalance = endingBalance,
			context = if type(fields) == "table" then cleanText(fields.context or "", 60) else "",
		}
	)
end

function TelemetryService.Flush(): boolean
	if not backendEnabled or flushing or #pending == 0 then
		return true
	end
	flushing = true

	local batch = {}
	local take = math.min(#pending, Config.BackendTelemetryBatchSize)
	for index = 1, take do
		table.insert(batch, pending[index])
	end

	local ok = BackendClient.Post("/api/v1/events", {
		schemaVersion = 1,
		events = batch,
	})
	if ok then
		for _ = 1, take do
			table.remove(pending, 1)
		end
	end

	flushing = false
	return ok
end

function TelemetryService.Start()
	closing = false
	backendEnabled = BackendClient.IsConfigured()
	for _, player in ipairs(Players:GetPlayers()) do
		sessionFor(player)
	end

	Players.PlayerAdded:Connect(function(player)
		sessionFor(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)

	if backendEnabled then
		task.spawn(function()
			while not closing do
				task.wait(Config.BackendTelemetryFlushSeconds)
				if not closing then
					TelemetryService.Flush()
				end
			end
		end)
	end
end

function TelemetryService.Shutdown()
	closing = true
	if not backendEnabled then
		return
	end
	local deadline = os.clock() + 3
	repeat
		if #pending == 0 or not TelemetryService.Flush() then
			break
		end
		task.wait()
	until os.clock() >= deadline
end

return TelemetryService
