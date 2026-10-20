--!strict
-- The Cash display at the top of the buttons on the left of the screen: the
-- player's Cash and income per second, and the time left on a 2x income boost.
-- Reads leaderstats.Cash and the IncomePerSecond and BoostEndsAt attributes,
-- all set by the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.Rewards)

local SIZE = UDim2.fromOffset(160, 64)
-- The top of the stack of buttons on the left edge (bottom edge given).
local POSITION = UDim2.new(0, 12, 0.5, -80)
local BOOST_COLOUR = Color3.fromRGB(255, 200, 70)

local player = Players.LocalPlayer

local HudController = {}

local function label(parent: Instance, position: UDim2, height: number, textSize: number, colour: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Position = position
	text.Size = UDim2.new(1, -24, 0, height)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.BuilderSansBold
	text.TextSize = textSize
	text.TextColor3 = colour
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = parent
	return text
end

function HudController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40

	local frame = Instance.new("Frame")
	frame.Name = "Cash"
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = POSITION
	frame.Size = SIZE
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	frame.BackgroundTransparency = 0.2
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local cashText = label(frame, UDim2.fromOffset(12, 4), 34, 28, Color3.new(1, 1, 1))
	local incomeText = label(frame, UDim2.fromOffset(12, 38), 20, 17, Color3.fromRGB(120, 220, 130))
	cashText.Text = Format.cash(0)

	incomeText.RichText = true
	local function renderIncome()
		local rate = player:GetAttribute("IncomePerSecond")
		local text = Format.income(if typeof(rate) == "number" then rate else 0)
		local endsAt = player:GetAttribute("BoostEndsAt")
		local left = if typeof(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else 0
		if left > 0 then
			local hex = BOOST_COLOUR:ToHex()
			text ..= `  <font color="#{hex}">{RewardsConfig.BoostMultiplier}x {Format.duration(left)}</font>`
		end
		incomeText.Text = text
	end
	player:GetAttributeChangedSignal("IncomePerSecond"):Connect(renderIncome)
	player:GetAttributeChangedSignal("BoostEndsAt"):Connect(renderIncome)
	renderIncome()
	task.spawn(function()
		while true do
			task.wait(0.5)
			renderIncome()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")

	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash") :: IntValue
	local function renderCash()
		cashText.Text = Format.cash(cash.Value)
	end
	cash.Changed:Connect(renderCash)
	renderCash()
end

return HudController
