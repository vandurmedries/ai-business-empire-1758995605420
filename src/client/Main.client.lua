--!nonstrict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteNames = require(Shared:WaitForChild("Remotes"))
local remoteFolder = ReplicatedStorage:WaitForChild(RemoteNames.Folder)

local getStateRemote = remoteFolder:WaitForChild(RemoteNames.GetState)
local runCycleRemote = remoteFolder:WaitForChild(RemoteNames.RunCycle)
local upgradeRemote = remoteFolder:WaitForChild(RemoteNames.UpgradeDepartment)
local requestMissionRemote = remoteFolder:WaitForChild(RemoteNames.RequestMission)
local promptOfferRemote = remoteFolder:WaitForChild(RemoteNames.PromptOffer)
local stateChangedRemote = remoteFolder:WaitForChild(RemoteNames.StateChanged)
local toastRemote = remoteFolder:WaitForChild(RemoteNames.Toast)

local COLORS = {
	Background = Color3.fromRGB(8, 12, 22),
	Panel = Color3.fromRGB(18, 25, 42),
	PanelAlt = Color3.fromRGB(24, 33, 54),
	Accent = Color3.fromRGB(92, 233, 190),
	AccentDark = Color3.fromRGB(31, 133, 111),
	Text = Color3.fromRGB(244, 248, 255),
	Muted = Color3.fromRGB(158, 172, 199),
	Warning = Color3.fromRGB(255, 195, 92),
	Danger = Color3.fromRGB(255, 115, 128),
	Success = Color3.fromRGB(112, 239, 150),
	Stroke = Color3.fromRGB(47, 61, 91),
}

local state = nil
local autoRunEnabled = false
local autoRunGeneration = 0
local cycleBusy = false
local actionBusy = false
local offerRows = {}
local departmentButtons = {}

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Stroke
	stroke.Transparency = transparency or 0.25
	stroke.Thickness = 1
	stroke.Parent = instance
	return stroke
end

local function makeLabel(parent, text, size, position, textSize, color, font)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.Size = size
	label.Position = position
	label.Font = font or Enum.Font.Gotham
	label.TextSize = textSize or 16
	label.TextColor3 = color or COLORS.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function makeButton(parent, text, size, position)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Text = text
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = COLORS.AccentDark
	button.TextColor3 = COLORS.Text
	button.Font = Enum.Font.GothamSemibold
	button.TextSize = 15
	button.TextWrapped = true
	button.Parent = parent
	addCorner(button, 10)
	addStroke(button, 0.5)

	button.MouseEnter:Connect(function()
		if button.Active then
			TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.Accent }):Play()
			TweenService:Create(button, TweenInfo.new(0.12), { TextColor3 = COLORS.Background }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		if button.Active then
			TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.AccentDark }):Play()
			TweenService:Create(button, TweenInfo.new(0.12), { TextColor3 = COLORS.Text }):Play()
		end
	end)
	return button
end

local function setButtonEnabled(button, enabled, disabledText)
	button.Active = enabled
	button.Selectable = enabled
	if enabled then
		button.BackgroundColor3 = COLORS.AccentDark
		button.TextColor3 = COLORS.Text
	else
		button.BackgroundColor3 = Color3.fromRGB(49, 57, 75)
		button.TextColor3 = COLORS.Muted
		if disabledText then
			button.Text = disabledText
		end
	end
end

local function formatNumber(value)
	local number = math.floor(tonumber(value) or 0)
	local negative = number < 0
	number = math.abs(number)
	local suffix = ""
	local display = number
	if number >= 1_000_000_000 then
		display = number / 1_000_000_000
		suffix = "B"
	elseif number >= 1_000_000 then
		display = number / 1_000_000
		suffix = "M"
	elseif number >= 1_000 then
		display = number / 1_000
		suffix = "K"
	end
	local text
	if suffix == "" then
		text = tostring(number)
	elseif display >= 100 then
		text = string.format("%.0f%s", display, suffix)
	elseif display >= 10 then
		text = string.format("%.1f%s", display, suffix)
	else
		text = string.format("%.2f%s", display, suffix)
	end
	return (negative and "-" or "") .. text
end

local errorMessages = {
	data_not_loaded = "Your company data is still loading.",
	cycle_cooldown = "The company cycle is recharging.",
	action_cooldown = "That action was requested too quickly.",
	invalid_department = "That department is not available.",
	insufficient_cash = "You need more company cash for that upgrade.",
	mission_cooldown = "Your AI operator is preparing the next mission.",
	active_mission_exists = "Complete the active mission first.",
	offer_not_configured = "This Roblox product ID still needs to be configured.",
	already_owned = "You already own this benefit.",
	prompt_failed = "Roblox checkout could not be opened.",
}

local screen = Instance.new("ScreenGui")
screen.Name = "AIFounderDashboard"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = player:WaitForChild("PlayerGui")

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = COLORS.Background
background.BorderSizePixel = 0
background.Parent = screen

local glow = Instance.new("Frame")
glow.AnchorPoint = Vector2.new(0.5, 0)
glow.Position = UDim2.fromScale(0.5, 0)
glow.Size = UDim2.fromScale(0.9, 0.22)
glow.BackgroundColor3 = COLORS.AccentDark
glow.BackgroundTransparency = 0.78
glow.BorderSizePixel = 0
glow.Parent = background
addCorner(glow, 999)

local app = Instance.new("Frame")
app.Name = "App"
app.AnchorPoint = Vector2.new(0.5, 0.5)
app.Position = UDim2.fromScale(0.5, 0.5)
app.Size = UDim2.fromScale(0.94, 0.92)
app.BackgroundTransparency = 1
app.Parent = background

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 72)
header.BackgroundColor3 = COLORS.Panel
header.Parent = app
addCorner(header, 15)
addStroke(header, 0.2)

local titleLabel = makeLabel(
	header,
	"AI FOUNDER EMPIRE",
	UDim2.new(0.5, -20, 0, 32),
	UDim2.new(0, 22, 0, 10),
	23,
	COLORS.Text,
	Enum.Font.GothamBold
)
local subtitleLabel = makeLabel(
	header,
	"Build value. Automate operations. Grow sustainable revenue.",
	UDim2.new(0.58, -20, 0, 22),
	UDim2.new(0, 22, 0, 42),
	13,
	COLORS.Muted,
	Enum.Font.Gotham
)

local experimentPill = Instance.new("TextLabel")
experimentPill.AnchorPoint = Vector2.new(1, 0.5)
experimentPill.Position = UDim2.new(1, -18, 0.5, 0)
experimentPill.Size = UDim2.new(0, 230, 0, 38)
experimentPill.BackgroundColor3 = COLORS.PanelAlt
experimentPill.TextColor3 = COLORS.Accent
experimentPill.Font = Enum.Font.GothamSemibold
experimentPill.TextSize = 13
experimentPill.Text = "SAFE EXPERIMENT • CONTROL"
experimentPill.Parent = header
addCorner(experimentPill, 999)
addStroke(experimentPill, 0.4)

local leftScroll = Instance.new("ScrollingFrame")
leftScroll.Name = "Company"
leftScroll.Position = UDim2.new(0, 0, 0, 84)
leftScroll.Size = UDim2.new(0.64, -6, 1, -84)
leftScroll.BackgroundTransparency = 1
leftScroll.BorderSizePixel = 0
leftScroll.ScrollBarThickness = 5
leftScroll.ScrollBarImageColor3 = COLORS.AccentDark
leftScroll.CanvasSize = UDim2.new(0, 0, 0, 760)
leftScroll.Parent = app

local rightScroll = Instance.new("ScrollingFrame")
rightScroll.Name = "Store"
rightScroll.Position = UDim2.new(0.66, 6, 0, 84)
rightScroll.Size = UDim2.new(0.34, -6, 1, -84)
rightScroll.BackgroundColor3 = COLORS.Panel
rightScroll.BorderSizePixel = 0
rightScroll.ScrollBarThickness = 5
rightScroll.ScrollBarImageColor3 = COLORS.AccentDark
rightScroll.CanvasSize = UDim2.new(0, 0, 0, 810)
rightScroll.Parent = app
addCorner(rightScroll, 15)
addStroke(rightScroll, 0.2)

local statsPanel = Instance.new("Frame")
statsPanel.Size = UDim2.new(1, -6, 0, 174)
statsPanel.BackgroundColor3 = COLORS.Panel
statsPanel.Parent = leftScroll
addCorner(statsPanel, 15)
addStroke(statsPanel, 0.2)

makeLabel(statsPanel, "COMPANY OVERVIEW", UDim2.new(1, -32, 0, 34), UDim2.new(0, 18, 0, 8), 14, COLORS.Accent, Enum.Font.GothamBold)

local statsGridFrame = Instance.new("Frame")
statsGridFrame.BackgroundTransparency = 1
statsGridFrame.Position = UDim2.new(0, 14, 0, 48)
statsGridFrame.Size = UDim2.new(1, -28, 1, -60)
statsGridFrame.Parent = statsPanel

local statsGrid = Instance.new("UIGridLayout")
statsGrid.CellSize = UDim2.new(0.19, -5, 1, 0)
statsGrid.CellPadding = UDim2.new(0.012, 0, 0, 0)
statsGrid.SortOrder = Enum.SortOrder.LayoutOrder
statsGrid.Parent = statsGridFrame

local statLabels = {}
local statDefinitions = {
	{ key = "cash", title = "CASH", prefix = "$" },
	{ key = "lifetimeRevenue", title = "REVENUE", prefix = "$" },
	{ key = "customers", title = "CUSTOMERS", prefix = "" },
	{ key = "reputation", title = "REPUTATION", prefix = "" },
	{ key = "level", title = "LEVEL", prefix = "" },
}
for index, definition in ipairs(statDefinitions) do
	local card = Instance.new("Frame")
	card.LayoutOrder = index
	card.BackgroundColor3 = COLORS.PanelAlt
	card.Parent = statsGridFrame
	addCorner(card, 11)
	local heading = makeLabel(card, definition.title, UDim2.new(1, -18, 0, 28), UDim2.new(0, 10, 0, 8), 11, COLORS.Muted, Enum.Font.GothamSemibold)
	heading.TextXAlignment = Enum.TextXAlignment.Center
	local value = makeLabel(card, "—", UDim2.new(1, -18, 0, 50), UDim2.new(0, 10, 0, 39), 23, COLORS.Text, Enum.Font.GothamBold)
	value.TextXAlignment = Enum.TextXAlignment.Center
	statLabels[definition.key] = { label = value, prefix = definition.prefix }
end

local operationsPanel = Instance.new("Frame")
operationsPanel.Position = UDim2.new(0, 0, 0, 188)
operationsPanel.Size = UDim2.new(1, -6, 0, 176)
operationsPanel.BackgroundColor3 = COLORS.Panel
operationsPanel.Parent = leftScroll
addCorner(operationsPanel, 15)
addStroke(operationsPanel, 0.2)

makeLabel(operationsPanel, "OPERATIONS", UDim2.new(1, -32, 0, 32), UDim2.new(0, 18, 0, 8), 14, COLORS.Accent, Enum.Font.GothamBold)
local operationSummary = makeLabel(
	operationsPanel,
	"Run one coordinated product, marketing, and sales cycle.",
	UDim2.new(1, -36, 0, 42),
	UDim2.new(0, 18, 0, 40),
	14,
	COLORS.Muted
)
local cycleButton = makeButton(operationsPanel, "RUN COMPANY CYCLE", UDim2.new(0.62, -23, 0, 54), UDim2.new(0, 18, 0, 100))
local autoButton = makeButton(operationsPanel, "AUTO-RUN: OFF", UDim2.new(0.38, -23, 0, 54), UDim2.new(0.62, 5, 0, 100))
local advancedLabel = makeLabel(
	operationsPanel,
	"Executive metrics unlock with the Executive Dashboard pass.",
	UDim2.new(1, -36, 0, 22),
	UDim2.new(0, 18, 1, -28),
	12,
	COLORS.Muted
)

local departmentsPanel = Instance.new("Frame")
departmentsPanel.Position = UDim2.new(0, 0, 0, 378)
departmentsPanel.Size = UDim2.new(1, -6, 0, 210)
departmentsPanel.BackgroundColor3 = COLORS.Panel
departmentsPanel.Parent = leftScroll
addCorner(departmentsPanel, 15)
addStroke(departmentsPanel, 0.2)
makeLabel(departmentsPanel, "DEPARTMENTS", UDim2.new(1, -32, 0, 32), UDim2.new(0, 18, 0, 8), 14, COLORS.Accent, Enum.Font.GothamBold)

for index, department in ipairs({ "Product", "Marketing", "Sales" }) do
	local button = makeButton(
		departmentsPanel,
		department,
		UDim2.new(1, -36, 0, 48),
		UDim2.new(0, 18, 0, 42 + ((index - 1) * 53))
	)
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Text = "  " .. department
	departmentButtons[department] = button
end

local missionPanel = Instance.new("Frame")
missionPanel.Position = UDim2.new(0, 0, 0, 602)
missionPanel.Size = UDim2.new(1, -6, 0, 150)
missionPanel.BackgroundColor3 = COLORS.Panel
missionPanel.Parent = leftScroll
addCorner(missionPanel, 15)
addStroke(missionPanel, 0.2)
makeLabel(missionPanel, "AI OPERATOR MISSION", UDim2.new(1, -32, 0, 30), UDim2.new(0, 18, 0, 8), 14, COLORS.Accent, Enum.Font.GothamBold)
local missionTitle = makeLabel(missionPanel, "No active mission", UDim2.new(0.65, -22, 0, 28), UDim2.new(0, 18, 0, 39), 16, COLORS.Text, Enum.Font.GothamSemibold)
local missionBrief = makeLabel(missionPanel, "Ask the AI operator for a curated growth objective.", UDim2.new(0.65, -22, 0, 52), UDim2.new(0, 18, 0, 67), 13, COLORS.Muted)
local missionProgress = makeLabel(missionPanel, "", UDim2.new(0.65, -22, 0, 22), UDim2.new(0, 18, 0, 117), 12, COLORS.Warning, Enum.Font.GothamSemibold)
local missionButton = makeButton(missionPanel, "GENERATE MISSION", UDim2.new(0.35, -24, 0, 82), UDim2.new(0.65, 6, 0, 48))

makeLabel(rightScroll, "FOUNDER STORE", UDim2.new(1, -36, 0, 32), UDim2.new(0, 18, 0, 14), 17, COLORS.Text, Enum.Font.GothamBold)
makeLabel(
	rightScroll,
	"Optional upgrades use Roblox checkout. Prices are shown by Roblox before purchase.",
	UDim2.new(1, -36, 0, 48),
	UDim2.new(0, 18, 0, 48),
	12,
	COLORS.Muted
)

local offerContainer = Instance.new("Frame")
offerContainer.Position = UDim2.new(0, 14, 0, 106)
offerContainer.Size = UDim2.new(1, -28, 0, 630)
offerContainer.BackgroundTransparency = 1
offerContainer.Parent = rightScroll

local offerLayout = Instance.new("UIListLayout")
offerLayout.Padding = UDim.new(0, 10)
offerLayout.SortOrder = Enum.SortOrder.LayoutOrder
offerLayout.Parent = offerContainer

for index, key in ipairs({
	"FounderClub",
	"AutomationPro",
	"ExecutiveDashboard",
	"StarterCapital",
	"FocusBoost",
	"RevenueSprint",
}) do
	local row = Instance.new("Frame")
	row.Name = key
	row.LayoutOrder = index
	row.Size = UDim2.new(1, 0, 0, 94)
	row.BackgroundColor3 = COLORS.PanelAlt
	row.Parent = offerContainer
	addCorner(row, 11)
	addStroke(row, 0.5)

	local nameLabel = makeLabel(row, key, UDim2.new(0.62, -16, 0, 28), UDim2.new(0, 14, 0, 9), 15, COLORS.Text, Enum.Font.GothamSemibold)
	local benefitLabel = makeLabel(row, "", UDim2.new(0.62, -16, 0, 48), UDim2.new(0, 14, 0, 36), 12, COLORS.Muted)
	local buyButton = makeButton(row, "VIEW PRICE", UDim2.new(0.36, -14, 0, 58), UDim2.new(0.64, 0, 0.5, -29))
	buyButton.TextSize = 12

	offerRows[key] = {
		row = row,
		name = nameLabel,
		benefit = benefitLabel,
		button = buyButton,
	}
end

local disclaimer = makeLabel(
	rightScroll,
	"No guaranteed earnings. Game currency has no cash value. The operator cannot change prices, publish builds, spend on ads, or send players to off-platform checkout.",
	UDim2.new(1, -36, 0, 62),
	UDim2.new(0, 18, 0, 742),
	11,
	COLORS.Muted
)
disclaimer.TextYAlignment = Enum.TextYAlignment.Top

local toastFrame = Instance.new("Frame")
toastFrame.AnchorPoint = Vector2.new(0.5, 1)
toastFrame.Position = UDim2.new(0.5, 0, 1, -18)
toastFrame.Size = UDim2.new(0, 460, 0, 50)
toastFrame.BackgroundColor3 = COLORS.PanelAlt
toastFrame.BackgroundTransparency = 1
toastFrame.Visible = false
toastFrame.ZIndex = 20
toastFrame.Parent = screen
addCorner(toastFrame, 12)
addStroke(toastFrame, 0.4)
local toastLabel = makeLabel(toastFrame, "", UDim2.new(1, -28, 1, 0), UDim2.new(0, 14, 0, 0), 14, COLORS.Text, Enum.Font.GothamSemibold)
toastLabel.TextXAlignment = Enum.TextXAlignment.Center
toastLabel.ZIndex = 21

local toastToken = 0
local function showToast(message, kind)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = tostring(message or "")
	toastLabel.TextColor3 = if kind == "error" then COLORS.Danger else if kind == "success" then COLORS.Success else COLORS.Text
	toastFrame.Visible = true
	toastFrame.BackgroundTransparency = 0.04
	toastLabel.TextTransparency = 0
	task.delay(2.8, function()
		if token ~= toastToken then
			return
		end
		local tween = TweenService:Create(toastFrame, TweenInfo.new(0.22), { BackgroundTransparency = 1 })
		local textTween = TweenService:Create(toastLabel, TweenInfo.new(0.22), { TextTransparency = 1 })
		tween:Play()
		textTween:Play()
		tween.Completed:Wait()
		if token == toastToken then
			toastFrame.Visible = false
		end
	end)
end

local function invoke(remote, ...)
	local arguments = table.pack(...)
	local ok, result = pcall(function()
		return remote:InvokeServer(table.unpack(arguments, 1, arguments.n))
	end)
	if not ok then
		showToast("The server did not respond. Please try again.", "error")
		return nil
	end
	if type(result) ~= "table" then
		showToast("The server returned an invalid response.", "error")
		return nil
	end
	return result
end

local function metricLabel(metric)
	local names = {
		RunCycles = "cycles",
		EarnCash = "cash earned",
		GainCustomers = "customers",
		UpgradeDepartment = "upgrades",
		ImproveReputation = "reputation",
	}
	return names[metric] or tostring(metric)
end

local function tutorialHint(variant, step)
	if step >= 4 then
		return "Your operating loop is active. Balance departments and complete AI missions."
	end
	if variant == "benefit_first" then
		return "Every cycle creates cash and customers. Reinvest cash to compound company power."
	elseif variant == "goal_first" then
		return "Goal: complete a cycle, upgrade one department, then accept an AI mission."
	end
	return "Step 1: run a cycle. Step 2: upgrade a department. Step 3: generate an AI mission."
end

local function renderState(nextState)
	if type(nextState) ~= "table" then
		return
	end
	state = nextState

	for key, definition in pairs(statLabels) do
		local value = state[key] or 0
		if key == "reputation" then
			definition.label.Text = formatNumber(value) .. "%"
		else
			definition.label.Text = definition.prefix .. formatNumber(value)
		end
	end

	local liveConfig = state.liveConfig or {}
	experimentPill.Text = string.upper("SAFE EXPERIMENT • " .. tostring(liveConfig.variant or liveConfig.Variant or "control"))
	operationSummary.Text = tutorialHint(liveConfig.TutorialHintVariant, state.tutorialStep or 0)

	local multiplierParts = {}
	if state.entitlements and state.entitlements.FounderClub then
		table.insert(multiplierParts, "Founder Club +10%")
	end
	if state.boosts and (state.boosts.focusCharges or 0) > 0 then
		table.insert(multiplierParts, tostring(state.boosts.focusCharges) .. " focus cycles")
	end
	if state.boosts and (state.boosts.revenueMultiplierUntil or 0) > (state.serverNow or os.time()) then
		table.insert(multiplierParts, "Revenue Sprint active")
	end
	if #multiplierParts > 0 then
		cycleButton.Text = "RUN CYCLE • " .. table.concat(multiplierParts, " • ")
	else
		cycleButton.Text = "RUN COMPANY CYCLE"
	end
	setButtonEnabled(cycleButton, not cycleBusy)

	local automationOwned = state.entitlements and state.entitlements.AutomationPro
	if automationOwned then
		autoButton.Text = "AUTO-RUN: " .. (autoRunEnabled and "ON" or "OFF")
		setButtonEnabled(autoButton, true)
	else
		autoRunEnabled = false
		autoButton.Text = "AUTOMATION PRO REQUIRED"
		setButtonEnabled(autoButton, false)
	end

	if state.entitlements and state.entitlements.ExecutiveDashboard then
		local perLevel = (state.companyPower or 0) / math.max(1, state.level or 1)
		advancedLabel.Text = string.format(
			"Executive: power %s • %.1f power/level • next level %s XP",
			formatNumber(state.companyPower),
			perLevel,
			formatNumber(state.nextLevelXP)
		)
		advancedLabel.TextColor3 = COLORS.Accent
	else
		advancedLabel.Text = "Executive metrics unlock with the Executive Dashboard pass."
		advancedLabel.TextColor3 = COLORS.Muted
	end

	for department, button in pairs(departmentButtons) do
		local level = state.departments and state.departments[department] or 1
		local cost = state.upgradeCosts and state.upgradeCosts[department] or 0
		button.Text = string.format("  %s  •  Level %d  •  Upgrade $%s", department, level, formatNumber(cost))
		setButtonEnabled(button, not actionBusy)
	end

	local mission = state.activeMission
	if mission then
		missionTitle.Text = mission.Title or "Active mission"
		missionBrief.Text = mission.Brief or "Complete the objective."
		missionProgress.Text = string.format(
			"%s / %s %s  •  Reward $%s",
			formatNumber(mission.Progress),
			formatNumber(mission.TargetValue),
			metricLabel(mission.TargetMetric),
			formatNumber(mission.RewardCash)
		)
		missionButton.Text = "MISSION ACTIVE"
		setButtonEnabled(missionButton, false)
	else
		missionTitle.Text = "No active mission"
		missionBrief.Text = "The AI selects a safe objective from curated mission templates."
		missionProgress.Text = ""
		local promptVariant = liveConfig.MissionPromptVariant
		if promptVariant == "reward_first" then
			missionButton.Text = "GET REWARD MISSION"
		elseif promptVariant == "challenge_first" then
			missionButton.Text = "START A CHALLENGE"
		else
			missionButton.Text = "GENERATE MISSION"
		end
		setButtonEnabled(missionButton, not actionBusy)
	end

	if type(state.offers) == "table" then
		for _, offer in ipairs(state.offers) do
			local row = offerRows[offer.key]
			if row then
				row.row.LayoutOrder = offer.layoutOrder or 1
				row.name.Text = offer.displayName or offer.key
				row.benefit.Text = offer.benefit or ""
				if offer.owned then
					row.button.Text = "OWNED"
					setButtonEnabled(row.button, false)
				elseif not offer.configured then
					row.button.Text = "SETUP REQUIRED"
					setButtonEnabled(row.button, false)
				else
					row.button.Text = if offer.kind == "Subscription" then "VIEW SUBSCRIPTION" else "VIEW ROBLOX PRICE"
					setButtonEnabled(row.button, true)
				end
			end
		end
	end
end

local function handleResponse(result)
	if not result then
		return false
	end
	if result.state then
		renderState(result.state)
	end
	if not result.ok then
		local message = errorMessages[result.error] or ("Action failed: " .. tostring(result.error or "unknown_error"))
		if result.retryAfter and result.retryAfter > 0.2 then
			message = message .. string.format(" Try again in %.1fs.", result.retryAfter)
		end
		showToast(message, "error")
		return false
	end
	return true
end

local function runCycle(showResultToast)
	if cycleBusy then
		return false
	end
	cycleBusy = true
	setButtonEnabled(cycleButton, false, "RUNNING COMPANY CYCLE…")
	local result = invoke(runCycleRemote)
	local success = handleResponse(result)
	cycleBusy = false
	if state then
		renderState(state)
	end
	if success and showResultToast and result.result then
		showToast(
			string.format("Cycle complete: +$%s and +%s customers", formatNumber(result.result.revenue), formatNumber(result.result.customers)),
			"success"
		)
	end
	return success
end

cycleButton.Activated:Connect(function()
	runCycle(true)
end)

autoButton.Activated:Connect(function()
	if not state or not state.entitlements or not state.entitlements.AutomationPro then
		return
	end
	autoRunEnabled = not autoRunEnabled
	autoRunGeneration += 1
	renderState(state)
	if not autoRunEnabled then
		showToast("Automation paused.", "info")
		return
	end
	showToast("Automation started. It stops when you leave the server.", "success")
	local generation = autoRunGeneration
	task.spawn(function()
		while autoRunEnabled and generation == autoRunGeneration do
			runCycle(false)
			local cooldown = if state then state.cycleCooldownSeconds or 8 else 8
			task.wait(math.max(2, cooldown + 0.15))
		end
	end)
end)

for department, button in pairs(departmentButtons) do
	button.Activated:Connect(function()
		if actionBusy then
			return
		end
		actionBusy = true
		if state then
			renderState(state)
		end
		local result = invoke(upgradeRemote, department)
		local success = handleResponse(result)
		actionBusy = false
		if state then
			renderState(state)
		end
		if success then
			showToast(department .. " upgraded.", "success")
		end
	end)
end

missionButton.Activated:Connect(function()
	if actionBusy then
		return
	end
	actionBusy = true
	setButtonEnabled(missionButton, false, "AI OPERATOR IS THINKING…")
	local result = invoke(requestMissionRemote)
	local success = handleResponse(result)
	actionBusy = false
	if state then
		renderState(state)
	end
	if success then
		showToast("New AI mission accepted.", "success")
	end
end)

for key, row in pairs(offerRows) do
	row.button.Activated:Connect(function()
		local result = invoke(promptOfferRemote, key)
		handleResponse(result)
	end)
end

stateChangedRemote.OnClientEvent:Connect(function(nextState)
	renderState(nextState)
end)

toastRemote.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" then
		showToast(payload.message, payload.kind)
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, purchased)
	if userId == player.UserId and purchased then
		showToast("Purchase submitted. Roblox is confirming the receipt.", "success")
	end
end)

local camera = workspace.CurrentCamera
local function updateLayout()
	if not camera then
		return
	end
	local narrow = camera.ViewportSize.X < 900
	if narrow then
		app.Size = UDim2.fromScale(0.97, 0.96)
		header.Size = UDim2.new(1, 0, 0, 68)
		experimentPill.Visible = false
		subtitleLabel.Size = UDim2.new(1, -44, 0, 22)
		leftScroll.Position = UDim2.new(0, 0, 0, 78)
		leftScroll.Size = UDim2.new(1, 0, 0.57, -44)
		rightScroll.Position = UDim2.new(0, 0, 0.57, 44)
		rightScroll.Size = UDim2.new(1, 0, 0.43, -44)
		statsGrid.CellSize = UDim2.new(0.32, -5, 0, 52)
		statsGrid.CellPadding = UDim2.new(0.012, 0, 0, 6)
		statsPanel.Size = UDim2.new(1, -6, 0, 188)
		operationsPanel.Position = UDim2.new(0, 0, 0, 202)
		departmentsPanel.Position = UDim2.new(0, 0, 0, 392)
		missionPanel.Position = UDim2.new(0, 0, 0, 616)
		leftScroll.CanvasSize = UDim2.new(0, 0, 0, 780)
	else
		app.Size = UDim2.fromScale(0.94, 0.92)
		header.Size = UDim2.new(1, 0, 0, 72)
		experimentPill.Visible = true
		subtitleLabel.Size = UDim2.new(0.58, -20, 0, 22)
		leftScroll.Position = UDim2.new(0, 0, 0, 84)
		leftScroll.Size = UDim2.new(0.64, -6, 1, -84)
		rightScroll.Position = UDim2.new(0.66, 6, 0, 84)
		rightScroll.Size = UDim2.new(0.34, -6, 1, -84)
		statsGrid.CellSize = UDim2.new(0.19, -5, 1, 0)
		statsGrid.CellPadding = UDim2.new(0.012, 0, 0, 0)
		statsPanel.Size = UDim2.new(1, -6, 0, 174)
		operationsPanel.Position = UDim2.new(0, 0, 0, 188)
		departmentsPanel.Position = UDim2.new(0, 0, 0, 378)
		missionPanel.Position = UDim2.new(0, 0, 0, 602)
		leftScroll.CanvasSize = UDim2.new(0, 0, 0, 760)
	end
end

if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
end
updateLayout()

makeLabel(background, "Loading your company…", UDim2.new(0, 300, 0, 30), UDim2.new(0.5, -150, 0.5, -15), 15, COLORS.Muted).Visible = false

task.spawn(function()
	for attempt = 1, 20 do
		local result = invoke(getStateRemote)
		if result and result.ok and result.state then
			renderState(result.state)
			return
		end
		task.wait(math.min(2, 0.25 + (attempt * 0.1)))
	end
	showToast("Company data could not be loaded. Rejoin the server to retry.", "error")
end)
