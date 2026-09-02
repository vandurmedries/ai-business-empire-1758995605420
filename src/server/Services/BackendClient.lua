--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local BackendClient = {}

local consecutiveFailures = 0
local nextAttemptAt = 0
local cachedSecret: Secret? = nil
local secretLookupAttempted = false

local function isConfigured(): boolean
	return Config.BackendEnabled
		and string.sub(Config.BackendBaseUrl, 1, 8) == "https://"
		and not string.find(Config.BackendBaseUrl, "YOUR%-VERCEL%-PROJECT")
end

local function getSecret(): Secret?
	if cachedSecret then
		return cachedSecret
	end
	if secretLookupAttempted then
		return nil
	end

	secretLookupAttempted = true
	local ok, value = pcall(function()
		return HttpService:GetSecret(Config.BackendSecretName)
	end)
	if ok then
		cachedSecret = value
		return value
	end

	warn("AI Founder backend secret is unavailable; backend calls will use local fallbacks")
	return nil
end

local function noteFailure()
	consecutiveFailures += 1
	local delaySeconds = math.min(60, 2 ^ math.min(consecutiveFailures, 5))
	nextAttemptAt = os.clock() + delaySeconds
end

local function noteSuccess()
	consecutiveFailures = 0
	nextAttemptAt = 0
end

function BackendClient.IsConfigured(): boolean
	return isConfigured() and getSecret() ~= nil
end

function BackendClient.Post(path: string, payload: any): (boolean, any)
	if not isConfigured() then
		return false, "backend_not_configured"
	end
	if os.clock() < nextAttemptAt then
		return false, "backend_circuit_open"
	end

	local secret = getSecret()
	if not secret then
		return false, "backend_secret_missing"
	end

	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = Config.BackendBaseUrl .. path,
			Method = "POST",
			Headers = {
				["content-type"] = "application/json",
				["x-roblox-secret"] = secret,
			},
			Body = HttpService:JSONEncode(payload),
		})
	end)

	if not ok then
		noteFailure()
		return false, tostring(response)
	end

	if not response.Success then
		noteFailure()
		return false, (`backend_http_{response.StatusCode}`)
	end

	local decodeOk, decoded = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)
	if not decodeOk then
		noteFailure()
		return false, "backend_invalid_json"
	end

	noteSuccess()
	return true, decoded
end

function BackendClient.Get(path: string): (boolean, any)
	if not isConfigured() then
		return false, "backend_not_configured"
	end
	if os.clock() < nextAttemptAt then
		return false, "backend_circuit_open"
	end

	local secret = getSecret()
	if not secret then
		return false, "backend_secret_missing"
	end

	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = Config.BackendBaseUrl .. path,
			Method = "GET",
			Headers = {
				["x-roblox-secret"] = secret,
			},
		})
	end)

	if not ok or not response.Success then
		noteFailure()
		return false, if ok then (`backend_http_{response.StatusCode}`) else tostring(response)
	end

	local decodeOk, decoded = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)
	if not decodeOk then
		noteFailure()
		return false, "backend_invalid_json"
	end

	noteSuccess()
	return true, decoded
end

return BackendClient
