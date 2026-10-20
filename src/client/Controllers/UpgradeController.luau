--!strict
-- The Upgrade button, under the Storage button on the left: shows the next
-- base upgrade and its cost (the NextUpgrade and NextUpgradeCost attributes
-- set by the server) and asks the server to buy it. It dims while the player
-- can't afford the upgrade; the server checks again either way.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Just below the Storage button, which is centred on the left edge.
local POSITION = UDim2.new(0, 12, 0.5, 32)
local SIZE = UDim2.fromOffset(160, 56)
local AFFORDABLE = Color3.fromRGB(205, 150, 40)
local UNAFFORDABLE = Color3.fromRGB(70, 65, 55)

local player = Players.LocalPlayer

local UpgradeController = {}

function UpgradeController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Upgrade"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local button = Instance.new("TextButton")
	button.Name = "Upgrade"
	button.Position = POSITION
	button.Size = SIZE
	button.BackgroundColor3 = UNAFFORDABLE
	button.Font = Enum.Font.BuilderSansBold
	button.TextSize = 18
	button.TextColor3 = Color3.new(1, 1, 1)
	button.RichText = true
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local cash: IntValue? = nil

	local function render()
		local label = player:GetAttribute("NextUpgrade")
		local cost = player:GetAttribute("NextUpgradeCost")
		if typeof(label) ~= "string" then
			button.Text = "Upgrade base"
			button.BackgroundColor3 = UNAFFORDABLE
			return
		end
		if typeof(cost) ~= "number" then
			button.Text = label
			button.BackgroundColor3 = UNAFFORDABLE
			return
		end
		local affordable = cash ~= nil and cash.Value >= cost
		button.BackgroundColor3 = if affordable then AFFORDABLE else UNAFFORDABLE
		button.Text = `Upgrade base\n<font size="15">{label}  ·  {Format.cash(cost)}</font>`
	end

	button.Activated:Connect(function()
		Remotes.BuyUpgrade:FireServer()
	end)
	player:GetAttributeChangedSignal("NextUpgrade"):Connect(render)
	player:GetAttributeChangedSignal("NextUpgradeCost"):Connect(render)
	render()

	gui.Parent = player:WaitForChild("PlayerGui")

	local cashValue = player:WaitForChild("leaderstats"):WaitForChild("Cash") :: IntValue
	cash = cashValue
	cashValue.Changed:Connect(render)
	render()
end

return UpgradeController
