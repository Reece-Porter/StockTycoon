--!strict
-- The Rebirth menu button (with a dot once the player can rebirth) and its
-- window: the income multiplier now and after, what the next rebirth needs
-- (ticked once the player has it), what it resets and keeps, and a big
-- Rebirth button that takes two taps. The server sends Rebirths, RebirthCost
-- and RebirthHasTier and checks everything again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.Rebirth)
local RebirthMath = require(ReplicatedStorage.Shared.RebirthMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)
local Scroll = require(script.Parent.Parent.Ui.Kit.Scroll)

-- How long "Tap again" stays up before the button resets.
local CONFIRM_SECONDS = 3
local NEED_HEIGHT = 40
local GO_HEIGHT = 64

local player = Players.LocalPlayer

type Need = { frame: Frame, label: TextLabel, tick: Frame, cross: Frame }

local RebirthController = {}

local function numberAttribute(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- A line with a tick or cross in front of it.
local function need(parent: Instance, order: number): Need
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, NEED_HEIGHT)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local function mark(name: Icons.IconName, colour: Color3): Frame
		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0, 0.5)
		circle.Position = UDim2.fromScale(0, 0.5)
		circle.Size = UDim2.fromOffset(30, 30)
		circle.BackgroundColor3 = colour
		Make.corner(circle)
		Make.outline(circle, Theme.Colours.Ink, Theme.Stroke.Normal)
		Icons.make(name, 30).Parent = circle
		circle.Parent = frame
		return circle
	end
	local tick = mark("Tick", Theme.Colours.Cash)
	local cross = mark("Cross", Theme.Colours.Danger)
	local label = Make.label(frame, {
		size = Theme.TextSize.Body,
		colour = Theme.Colours.Text,
		alignX = Enum.TextXAlignment.Left,
		wrapped = true,
	})
	label.Position = UDim2.fromOffset(40, 0)
	label.Size = UDim2.new(1, -40, 1, 0)
	return { frame = frame, label = label, tick = tick, cross = cross }
end

function RebirthController:Start()
	local window = Menu.window({ title = "Rebirth", colour = Theme.Menu.Rebirth })
	local top = GO_HEIGHT + Theme.Size.Gap
	local list = Scroll.list(window.Body)
	list.Size = UDim2.new(1, 0, 1, -top)

	local multiplier = Make.label(list, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Big,
		colour = Theme.Menu.Rebirth,
		outline = true,
	})
	multiplier.LayoutOrder = 1
	multiplier.Size = UDim2.new(1, 0, 0, 48)
	local multiplierNote = Make.label(list, {
		text = "income, plus slightly better odds on your own conveyor",
		size = Theme.TextSize.Small,
		colour = Theme.Colours.TextMuted,
	})
	multiplierNote.LayoutOrder = 2
	multiplierNote.Size = UDim2.new(1, 0, 0, 20)

	Scroll.heading(list, "You need", 3)
	local cashNeed = need(list, 4)
	local tierNeed = need(list, 5)
	Scroll.heading(list, "Resets", 6)
	local resets = Make.label(list, {
		text = "Cash, every company, plots and floors",
		size = Theme.TextSize.Body,
		colour = Theme.Colours.Text,
		alignX = Enum.TextXAlignment.Left,
		wrapped = true,
	})
	resets.LayoutOrder = 7
	resets.Size = UDim2.new(1, 0, 0, 24)
	Scroll.heading(list, "Keeps", 8)
	local keeps = Make.label(list, {
		text = "Rebirths, weapons and pets (pets go back to your Pets window)",
		size = Theme.TextSize.Body,
		colour = Theme.Colours.Text,
		alignX = Enum.TextXAlignment.Left,
		wrapped = true,
	})
	keeps.LayoutOrder = 9
	keeps.Size = UDim2.new(1, 0, 0, 44)

	local go = Button.new({
		text = "Rebirth",
		icon = "Rebirth",
		colour = Theme.Menu.Rebirth,
		size = UDim2.new(1, 0, 0, GO_HEIGHT),
		textSize = Theme.TextSize.Title,
	})
	go.Instance.AnchorPoint = Vector2.new(0, 1)
	go.Instance.Position = UDim2.fromScale(0, 1)
	go.Instance.Parent = window.Body

	local menuButton = Menu.button({
		name = "Rebirth",
		text = "Rebirth",
		icon = "Rebirth",
		colour = Theme.Menu.Rebirth,
		order = 6,
		side = "Left",
	})

	local cash: IntValue? = nil
	local confirming = false

	local function isReady(): boolean
		local cost = numberAttribute("RebirthCost")
		return cash ~= nil and cost > 0 and cash.Value >= cost and player:GetAttribute("RebirthHasTier") == true
	end

	local function render()
		local rebirths = numberAttribute("Rebirths")
		local cost = numberAttribute("RebirthCost")
		local have = if cash then cash.Value else 0
		local hasTier = player:GetAttribute("RebirthHasTier") == true
		local tier = Tiers.byId[RebirthConfig.RequiredTier]
		local ready = isReady()

		window.setTitle(`Rebirth ({rebirths} so far)`)
		multiplier.Text =
			`x{RebirthMath.incomeMultiplier(rebirths)}  →  x{RebirthMath.incomeMultiplier(rebirths + 1)}`
		cashNeed.label.Text = `{Format.cash(cost)} Cash (you have {Format.cash(have)})`
		cashNeed.tick.Visible = have >= cost
		cashNeed.cross.Visible = have < cost
		tierNeed.label.Text = `A {tier.name} company or better, placed or in storage`
		tierNeed.tick.Visible = hasTier
		tierNeed.cross.Visible = not hasTier

		menuButton.setDot(ready)
		go.setEnabled(ready)
		go.setText(if confirming then "Tap again to rebirth" else "Rebirth")
	end

	menuButton.Activated:Connect(function()
		confirming = false
		render()
		Menu.toggle(window)
	end)
	go.Activated:Connect(function()
		if not isReady() then
			return
		end
		if confirming then
			confirming = false
			window.close()
			Remotes.Rebirth:FireServer()
		else
			confirming = true
			task.delay(CONFIRM_SECONDS, function()
				confirming = false
				render()
			end)
		end
		render()
	end)

	for _, name in { "Rebirths", "RebirthCost", "RebirthHasTier" } do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
	render()

	-- Cash comes from the player list value the server keeps up to date.
	local leaderstats = player:WaitForChild("leaderstats")
	local cashValue = leaderstats:WaitForChild("Cash")
	if cashValue:IsA("IntValue") then
		cash = cashValue
		cashValue.Changed:Connect(render)
		render()
	end
end

return RebirthController
