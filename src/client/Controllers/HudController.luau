--!strict
-- The Cash pill in the bottom left corner of the screen: a cash icon, the
-- player's Cash (counting up to each new amount) and their income per second
-- underneath. Above it, side by side, a smaller Gold pill (a coin and their
-- Gold) and a chip while a 2x income boost runs, its bar running down.
-- Stacked rather than all in a row, so it stays narrow and clear of the tool
-- bar in the middle, and no taller than Cash and one chip.
-- Reads leaderstats.Cash and the Gold, IncomePerSecond and BoostEndsAt
-- attributes, all set by the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.Rewards)
local Theme = require(ReplicatedStorage.Shared.Theme)
local CountUp = require(script.Parent.Parent.Ui.Kit.CountUp)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)

local PILL_HEIGHT = 58
local GOLD_HEIGHT = 40
local CHIP_HEIGHT = 40
local BAR_HEIGHT = 5
local UPDATE_SECONDS = 0.25

local player = Players.LocalPlayer

local HudController = {}

-- A rounded pill that lays its children out in a row.
local function pill(colour: Color3, height: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(0, height)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.BackgroundColor3 = colour
	Make.corner(frame)
	Make.outline(frame, Theme.Colours.Ink, Theme.Stroke.Thick)
	local layout = Make.list(frame, Enum.FillDirection.Horizontal, Theme.Size.Gap)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	return frame
end

function HudController:Start()
	local stack = Instance.new("Frame")
	stack.Name = "Hud"
	stack.AutomaticSize = Enum.AutomaticSize.XY
	stack.BackgroundTransparency = 1
	local stackLayout = Make.list(stack, Enum.FillDirection.Vertical, Theme.Size.Gap)
	stackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	-- Cash and income, at the bottom.
	local cashPill = pill(Theme.Colours.Card, PILL_HEIGHT)
	cashPill.Name = "Cash"
	cashPill.LayoutOrder = 2
	Make.padding(cashPill, 0, 10).PaddingRight = UDim.new(0, 20)
	cashPill.Parent = stack
	local icon = Icons.make("Cash", 40)
	icon.LayoutOrder = 1
	icon.Parent = cashPill
	local texts = Instance.new("Frame")
	texts.LayoutOrder = 2
	texts.Size = UDim2.fromScale(0, 1)
	texts.AutomaticSize = Enum.AutomaticSize.X
	texts.BackgroundTransparency = 1
	texts.Parent = cashPill
	local textLayout = Make.list(texts, Enum.FillDirection.Vertical, 0)
	textLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local cashText = Make.label(texts, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Title + 2,
		colour = Theme.Colours.Text,
		alignX = Enum.TextXAlignment.Left,
	})
	cashText.LayoutOrder = 1
	cashText.Size = UDim2.fromOffset(0, 30)
	cashText.AutomaticSize = Enum.AutomaticSize.X
	local incomeText = Make.label(texts, {
		font = Theme.Fonts.Body,
		size = Theme.TextSize.Small,
		colour = Theme.shade(Theme.Colours.Cash, 0.25),
		alignX = Enum.TextXAlignment.Left,
	})
	incomeText.LayoutOrder = 2
	incomeText.Size = UDim2.fromOffset(0, 18)
	incomeText.AutomaticSize = Enum.AutomaticSize.X

	-- Above Cash, a row: Gold, then the boost chip.
	local chips = Instance.new("Frame")
	chips.Name = "Chips"
	chips.LayoutOrder = 1
	chips.AutomaticSize = Enum.AutomaticSize.XY
	chips.BackgroundTransparency = 1
	local chipsLayout = Make.list(chips, Enum.FillDirection.Horizontal, Theme.Size.Gap)
	chipsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	chips.Parent = stack

	-- Gold: a coin and the amount.
	local goldPill = pill(Theme.Colours.Card, GOLD_HEIGHT)
	goldPill.Name = "Gold"
	goldPill.LayoutOrder = 1
	Make.padding(goldPill, 0, 8).PaddingRight = UDim.new(0, 16)
	goldPill.Parent = chips
	local coin = Icons.make("Gold", 28)
	coin.LayoutOrder = 1
	coin.Parent = goldPill
	local goldText = Make.label(goldPill, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Body,
		colour = Theme.shade(Theme.Colours.Gold, 0.35),
		alignX = Enum.TextXAlignment.Left,
	})
	goldText.Name = "Amount"
	goldText.LayoutOrder = 2
	goldText.Size = UDim2.fromScale(0, 1)
	goldText.AutomaticSize = Enum.AutomaticSize.X
	local function renderGold()
		local gold = player:GetAttribute("Gold")
		goldText.Text = Format.gold(if typeof(gold) == "number" then gold else 0)
	end
	player:GetAttributeChangedSignal("Gold"):Connect(renderGold)
	renderGold()

	-- The boost chip, beside Gold: 2x and the time left, with a bar that runs
	-- down along its bottom edge.
	local chip = Instance.new("Frame")
	chip.Name = "Boost"
	chip.LayoutOrder = 2
	chip.Size = UDim2.fromOffset(0, CHIP_HEIGHT)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundColor3 = Theme.Colours.Gold
	chip.Visible = false
	Make.corner(chip)
	Make.outline(chip, Theme.Colours.Ink, Theme.Stroke.Thick)
	chip.Parent = chips
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.fromScale(0, 1)
	content.AutomaticSize = Enum.AutomaticSize.X
	content.BackgroundTransparency = 1
	Make.padding(content, 0, 12)
	content.Parent = chip
	local contentLayout = Make.list(content, Enum.FillDirection.Horizontal, 6)
	contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local bolt = Icons.make("Bolt", 26)
	bolt.LayoutOrder = 1
	bolt.Parent = content
	local boostText = Make.label(content, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Body,
		colour = Theme.Colours.TextOnColour,
		outline = true,
	})
	boostText.LayoutOrder = 2
	boostText.Size = UDim2.fromScale(0, 1)
	boostText.AutomaticSize = Enum.AutomaticSize.X
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -4)
	track.Size = UDim2.new(1, -24, 0, BAR_HEIGHT)
	track.BackgroundColor3 = Theme.shade(Theme.Colours.Gold, 0.4)
	Make.corner(track)
	track.Parent = chip
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Theme.Colours.Card
	Make.corner(fill)
	fill.Parent = track

	Menu.addBottomLeft(stack, 1)

	-- The bar runs from the longest time left seen since the boost started.
	local boostTotal = 0
	local function renderIncome()
		local rate = player:GetAttribute("IncomePerSecond")
		incomeText.Text = Format.income(if typeof(rate) == "number" then rate else 0)
		local endsAt = player:GetAttribute("BoostEndsAt")
		local left = if typeof(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else 0
		chip.Visible = left > 0
		if left > 0 then
			boostTotal = math.max(boostTotal, left)
			boostText.Text = `{RewardsConfig.BoostMultiplier}x  {Format.duration(left)}`
			fill.Size = UDim2.fromScale(math.clamp(left / boostTotal, 0, 1), 1)
		else
			boostTotal = 0
		end
	end
	player:GetAttributeChangedSignal("IncomePerSecond"):Connect(renderIncome)
	player:GetAttributeChangedSignal("BoostEndsAt"):Connect(renderIncome)
	renderIncome()
	task.spawn(function()
		while true do
			task.wait(UPDATE_SECONDS)
			renderIncome()
		end
	end)

	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash") :: IntValue
	local counter = CountUp.new(cashText, Format.cash, cash.Value)
	cash.Changed:Connect(function()
		counter.set(cash.Value)
	end)
end

return HudController
