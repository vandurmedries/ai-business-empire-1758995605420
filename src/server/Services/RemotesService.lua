--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteNames = require(Shared:WaitForChild("Remotes"))

local RemotesService = {}
local remotes: { [string]: Instance } = {}

local function ensureRemote(folder: Folder, className: string, name: string): Instance
	local existing = folder:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, (`Remote {name} has the wrong class`))
		return existing
	end

	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

function RemotesService.Init()
	local folder = ReplicatedStorage:FindFirstChild(RemoteNames.Folder)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = RemoteNames.Folder
		folder.Parent = ReplicatedStorage
	end
	assert(folder:IsA("Folder"), "Remote folder has the wrong class")

	remotes[RemoteNames.GetState] = ensureRemote(folder, "RemoteFunction", RemoteNames.GetState)
	remotes[RemoteNames.RunCycle] = ensureRemote(folder, "RemoteFunction", RemoteNames.RunCycle)
	remotes[RemoteNames.UpgradeDepartment] = ensureRemote(folder, "RemoteFunction", RemoteNames.UpgradeDepartment)
	remotes[RemoteNames.RequestMission] = ensureRemote(folder, "RemoteFunction", RemoteNames.RequestMission)
	remotes[RemoteNames.PromptOffer] = ensureRemote(folder, "RemoteFunction", RemoteNames.PromptOffer)
	remotes[RemoteNames.StateChanged] = ensureRemote(folder, "RemoteEvent", RemoteNames.StateChanged)
	remotes[RemoteNames.Toast] = ensureRemote(folder, "RemoteEvent", RemoteNames.Toast)
end

function RemotesService.GetRemoteFunction(name: string): RemoteFunction
	local remote = remotes[name]
	assert(remote and remote:IsA("RemoteFunction"), (`RemoteFunction {name} is not initialized`))
	return remote
end

function RemotesService.GetRemoteEvent(name: string): RemoteEvent
	local remote = remotes[name]
	assert(remote and remote:IsA("RemoteEvent"), (`RemoteEvent {name} is not initialized`))
	return remote
end

function RemotesService.PushState(player: Player, state: any)
	RemotesService.GetRemoteEvent(RemoteNames.StateChanged):FireClient(player, state)
end

function RemotesService.Toast(player: Player, message: string, kind: string?)
	RemotesService.GetRemoteEvent(RemoteNames.Toast):FireClient(player, {
		message = string.sub(message, 1, 180),
		kind = kind or "info",
	})
end

return RemotesService
