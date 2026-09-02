--!strict

local RateLimiter = {}

local deadlines: { [Player]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

function RateLimiter.Allow(player: Player, action: string, cooldownSeconds: number): (boolean, number)
	local now = os.clock()
	local playerDeadlines = deadlines[player]
	if not playerDeadlines then
		playerDeadlines = {}
		deadlines[player] = playerDeadlines
	end

	local deadline = playerDeadlines[action] or 0
	if deadline > now then
		return false, math.max(0, deadline - now)
	end

	playerDeadlines[action] = now + cooldownSeconds
	return true, 0
end

function RateLimiter.Clear(player: Player)
	deadlines[player] = nil
end

return RateLimiter
