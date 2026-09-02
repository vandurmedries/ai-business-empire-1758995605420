--!strict

local Services = script:WaitForChild("Services")

local BusinessService = require(Services:WaitForChild("BusinessService"))
local LiveConfigService = require(Services:WaitForChild("LiveConfigService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local RemotesService = require(Services:WaitForChild("RemotesService"))
local TelemetryService = require(Services:WaitForChild("TelemetryService"))

RemotesService.Init()
LiveConfigService.Start()
TelemetryService.Start()
MonetizationService.Start(PlayerDataService, TelemetryService)
BusinessService.Start()
PlayerDataService.Start()

game:BindToClose(function()
	LiveConfigService.Shutdown()
	PlayerDataService.Shutdown()
	TelemetryService.Shutdown()
end)
