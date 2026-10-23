--!strict
-- The Rebirth menu button (with a dot once the player can rebirth) and its
-- window: the income multiplier, and the Stock Spinner Luck (with the
-- player's Spinner Luck upgrade) and odds, now and after, the plots it opens,
-- what the next rebirth needs (each ticked once the player has it: Cash and
-- the one or two particular companies for that rebirth), what it takes and
-- keeps, and a big Rebirth button that takes two taps. The server sends
-- Rebirths, RebirthCost, RebirthNeeds, RebirthHave and RebirthReady and
-- checks everything again.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.Shared.Config.Base)
local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Format = require(ReplicatedStorage.Shared.Format)
local PerkMath = require(ReplicatedStorage.Shared.PerkMath)
local RebirthMath = require(ReplicatedStorage.Shared.RebirthMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpinnerConfig = require(ReplicatedStorage.Shared.Config.Spinner)
local SpinnerMath = require(ReplicatedStorage.Shared.SpinnerMath)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local UpgradeMath = require(ReplicatedStorage.Shared.UpgradeMath)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)
local Scroll = require(script.Parent.Parent.Ui.Kit.Scroll)

-- How long "Tap again" stays up before the button resets.
local CONFIRM_SECONDS = 3
local NEED_HEIGHT = 40
local ODDS_HEIGHT = 24
local GO_HEIGHT = 64
-- The most companies a rebirth needs (Config/Rebirth.RequiredCompanies).
local MAX_COMPANY_NEEDS = 2

local player = Players.LocalPlayer

type Need = { frame: Frame, label: TextLabel, tick: Frame, cross: Frame }

local RebirthController = {}

-- A JSON list attribute from the server, or an empty list.
local function readList(name: string): { any }
	local json = player:GetAttribute(name)
	if typeof(json) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

-- The player's Spinner Luck upgrade level (kept through rebirth).
local function luckLevel(): number
	local json = player:GetAttribute("PerkLevels")
	if typeof(json) ~= "string" then
		return 0
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and typeof(decoded) == "table" then PerkMath.level(decoded :: any, "ConveyorLuck") else 0
end

-- Each spinner tier's chance (0 to 100) with the Luck this many rebirths
-- give, with the player's Spinner Luck upgrade.
local function oddsAfter(rebirths: number): { [string]: number }
	return SpinnerMath.percents(SpinnerMath.weights(SpinnerConfig.Weights, SpinnerMath.luck(rebirths, luckLevel())))
end

-- "1.8%", or "0.04%" for small chances.
local function percent(value: number): string
	return if value < 0.1 then string.format("%.2f%%", value) else string.format("%.1f%%", value)
end

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
		circle.Name = name
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
		text = "income, plus better odds in your Stock Spinner",
		size = Theme.TextSize.Small,
		colour = Theme.Colours.TextMuted,
	})
	multiplierNote.LayoutOrder = 2
	multiplierNote.Size = UDim2.new(1, 0, 0, 20)

	Scroll.heading(list, "Stock Spinner Luck and odds", 3)
	local luckLabel = Make.label(list, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Button,
		colour = Theme.Colours.Gold,
		outline = true,
		alignX = Enum.TextXAlignment.Left,
	})
	luckLabel.LayoutOrder = 4
	luckLabel.Size = UDim2.new(1, 0, 0, ODDS_HEIGHT + 4)
	local oddsLabels: { [string]: TextLabel } = {}
	for index, entry in SpinnerConfig.Weights do
		local label = Make.label(list, {
			size = Theme.TextSize.Body,
			colour = Theme.Colours.Text,
			alignX = Enum.TextXAlignment.Left,
		})
		label.LayoutOrder = 4 + index
		label.Size = UDim2.new(1, 0, 0, ODDS_HEIGHT)
		oddsLabels[entry.tier] = label
	end
	local after = 5 + #SpinnerConfig.Weights
	Scroll.heading(list, "New plots", after)
	local plotsLabel = Make.label(list, {
		size = Theme.TextSize.Body,
		colour = Theme.Colours.Text,
		alignX = Enum.TextXAlignment.Left,
		wrapped = true,
	})
	plotsLabel.Name = "Plots"
	plotsLabel.LayoutOrder = after + 1
	plotsLabel.Size = UDim2.new(1, 0, 0, 44)
	Scroll.heading(list, "You need", after + 2)
	local cashNeed = need(list, after + 3)
	local companyNeeds: { Need } = {}
	for index = 1, MAX_COMPANY_NEEDS do
		local row = need(list, after + 3 + index)
		row.frame.Name = `Company{index}`
		table.insert(companyNeeds, row)
	end
	after += MAX_COMPANY_NEEDS - 1
	Scroll.heading(list, "Takes", after + 5)
	local resets = Make.label(list, {
		text = "Your Cash, and the Cash on your cash pads",
		size = Theme.TextSize.Body,
		colour = Theme.Colours.Text,
		alignX = Enum.TextXAlignment.Left,
		wrapped = true,
	})
	resets.LayoutOrder = after + 6
	resets.Size = UDim2.new(1, 0, 0, 24)
	Scroll.heading(list, "Keeps", after + 7)
	local keeps = Make.label(list, {
		text = "Every company, plot and floor, your pets where they are, weapons, Gold and upgrade levels, and your Index",
		size = Theme.TextSize.Body,
		colour = Theme.Colours.Text,
		alignX = Enum.TextXAlignment.Left,
		wrapped = true,
	})
	keeps.LayoutOrder = after + 8
	keeps.Size = UDim2.new(1, 0, 0, 64)

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
		return cash ~= nil and cost > 0 and cash.Value >= cost and player:GetAttribute("RebirthReady") == true
	end

	local function render()
		local rebirths = numberAttribute("Rebirths")
		local cost = numberAttribute("RebirthCost")
		local have = if cash then cash.Value else 0
		local needs = readList("RebirthNeeds")
		local owned = readList("RebirthHave")
		local ready = isReady()

		window.setTitle(`Rebirth ({rebirths} so far)`)
		multiplier.Text =
			`x{RebirthMath.incomeMultiplier(rebirths)}  →  x{RebirthMath.incomeMultiplier(rebirths + 1)}`
		local level = luckLevel()
		luckLabel.Text = `Luck {SpinnerMath.luckText(SpinnerMath.luck(rebirths, level))}  →  {SpinnerMath.luckText(
			SpinnerMath.luck(rebirths + 1, level)
		)}`
		local maxPlots = (BaseConfig.MaxFloors - BaseConfig.CashFloors) * BaseConfig.PlotsPerFloor
		local earned = UpgradeMath.rebirthPlots(rebirths + 1)
		local added = earned - UpgradeMath.rebirthPlots(rebirths)
		-- The Cash floors are full once there's no Cash upgrade left.
		local cashFull = typeof(player:GetAttribute("NextUpgradeCost")) ~= "number"
		if added <= 0 then
			plotsLabel.Text = `Every plot above floor {BaseConfig.CashFloors} is already yours.`
		else
			local whenOpen = if cashFull then "" else ` They open once floor {BaseConfig.CashFloors} is full.`
			plotsLabel.Text = `+{added} plots above floor {BaseConfig.CashFloors} ({earned} of {maxPlots}).{whenOpen}`
		end
		local now, later = oddsAfter(rebirths), oddsAfter(rebirths + 1)
		for tierId, label in oddsLabels do
			label.Text = `{Tiers.byId[tierId].name}:  {percent(now[tierId])}  →  {percent(later[tierId])}`
		end
		cashNeed.label.Text = `{Format.cash(cost)} Cash (you have {Format.cash(have)})`
		cashNeed.tick.Visible = have >= cost
		cashNeed.cross.Visible = have < cost
		for index, row in companyNeeds do
			local companyId = needs[index]
			local company = if typeof(companyId) == "string" then Companies.byId[companyId] else nil
			row.frame.Visible = company ~= nil
			if company then
				local tier = Tiers.byId[company.tier]
				local hasIt = table.find(owned, company.id) ~= nil
				row.label.Text = `{company.name} ({if tier then tier.name else company.tier}), placed or in storage`
				row.tick.Visible = hasIt
				row.cross.Visible = not hasIt
			end
		end

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

	for _, name in
		{ "Rebirths", "RebirthCost", "RebirthNeeds", "RebirthHave", "RebirthReady", "PerkLevels", "NextUpgradeCost" }
	do
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
