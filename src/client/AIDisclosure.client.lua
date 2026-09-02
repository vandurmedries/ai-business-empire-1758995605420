--!strict

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("AIFounderDisclosure") then
	return
end

local screen = Instance.new("ScreenGui")
screen.Name = "AIFounderDisclosure"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.DisplayOrder = 100
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

local label = Instance.new("TextLabel")
label.Name = "Disclosure"
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -5)
label.Size = UDim2.new(0.94, 0, 0, 24)
label.BackgroundColor3 = Color3.fromRGB(8, 12, 22)
label.BackgroundTransparency = 0.18
label.BorderSizePixel = 0
label.Font = Enum.Font.GothamMedium
label.Text = "AI-selected missions • The AI is not human and may make mistakes • All purchases use Roblox checkout"
label.TextColor3 = Color3.fromRGB(190, 202, 222)
label.TextSize = 11
label.TextWrapped = true
label.ZIndex = 100
label.Parent = screen

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(250, 24)
sizeConstraint.MaxSize = Vector2.new(1100, 36)
sizeConstraint.Parent = label
