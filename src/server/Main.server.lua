--!strict

local Services = script:WaitForChild("Services")

local BusinessService = require(Services:WaitForChild("BusinessService"))
local LiveConfigService = require(Services:WaitForChild("LiveConfigService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))
local NativeRevenueOperatorService = require(Services:WaitForChild("NativeRevenueOperatorService"))
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local RemotesService = require(Services:WaitForChild("RemotesService"))
local TelemetryService = require(Services:WaitForChild("TelemetryService"))

RemotesService.Init()
LiveConfigService.Start()
TelemetryService.Start()
NativeRevenueOperatorService.Start(TelemetryService)
MonetizationService.Start(PlayerDataService, TelemetryService)
BusinessService.Start()
PlayerDataService.Start()

game:BindToClose(function()
	NativeRevenueOperatorService.Shutdown()
	LiveConfigService.Shutdown()
	PlayerDataService.Shutdown()
	TelemetryService.Shutdown()
end)
