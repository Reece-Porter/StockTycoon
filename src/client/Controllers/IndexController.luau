--!strict
-- The Index menu button (with a dot while a prize is ready to claim) and its
-- window, in three tabs:
--   Companies: every company by tier as a card, with a dark silhouette and
--     "???" for ones not found yet.
--   Variants: every variant, what it earns and how rare it is, shown on a
--     sample company once found, with "???" for ones not found yet.
--   Prizes: the prizes for collecting so many different companies.
-- The server sends IndexDiscovered, IndexClaimed and IndexVariants (JSON
-- lists) and checks every claim. The cards are only built while the window
-- is open.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local IndexConfig = require(ReplicatedStorage.Shared.Config.Index)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardMath = require(ReplicatedStorage.Shared.RewardMath)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)
local Badge = require(script.Parent.Parent.Ui.Kit.Badge)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Card = require(script.Parent.Parent.Ui.Kit.Card)
local Menu = require(script.Parent.Parent.Ui.Menu)
local Models = require(script.Parent.Parent.Ui.Models)
local Row = require(script.Parent.Parent.Ui.Kit.Row)
local Scroll = require(script.Parent.Parent.Ui.Kit.Scroll)

local CARD_SIZE = UDim2.fromOffset(120, 168)
local ROW_HEIGHT = 72
local ACTION_WIDTH = 116
local UNKNOWN = "???"
-- Found variants are shown on this company.
local VARIANT_SAMPLE = Companies.list[1].id

local player = Players.LocalPlayer

local IndexController = {}

local function readList(name: string): { any }
	local json = player:GetAttribute(name)
	if typeof(json) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

-- A grid of cards inside a scrolling list, as tall as its cards need.
local function gridIn(parent: Instance, order: number): Frame
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.LayoutOrder = order
	grid.Size = UDim2.fromScale(1, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = CARD_SIZE
	layout.CellPadding = UDim2.fromOffset(Theme.Size.Gap, Theme.Size.Gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grid
	grid.Parent = parent
	return grid
end

local function clear(scroll: ScrollingFrame)
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function IndexController:Start()
	local pages: { [string]: GuiObject } = {}
	local made = Menu.window({
		title = "Index",
		colour = Theme.Menu.Index,
		tabs = { "Companies", "Variants", "Prizes" },
		onTab = function(name)
			for pageName, page in pages do
				page.Visible = pageName == name
			end
		end,
	})
	local function page(name: string): ScrollingFrame
		local scroll = Scroll.list(made.Body)
		scroll.Name = name
		scroll.Visible = false
		pages[name] = scroll
		return scroll
	end
	local companiesPage = page("Companies")
	local variantsPage = page("Variants")
	local prizesPage = page("Prizes")

	local menuButton = Menu.button({
		name = "Index",
		text = "Index",
		icon = "Book",
		colour = Theme.Menu.Index,
		order = 5,
		side = "Left",
	})

	local function render()
		local discoveredList = readList("IndexDiscovered")
		local claimed = readList("IndexClaimed")
		local found = #discoveredList
		local ready = RewardMath.readyIndex(found, claimed)
		menuButton.setDot(#ready > 0)
		made.setTitle(`Index ({found}/{#Companies.list})`)
		if not made.isOpen() then
			return
		end
		local discovered: { [string]: boolean } = {}
		for _, id in discoveredList do
			discovered[id] = true
		end

		-- Companies, by tier.
		clear(companiesPage)
		local order = 0
		for _, tier in Tiers.list do
			local inTier: { Companies.Company } = Companies.byTier[tier.id] or {}
			local tierFound = 0
			for _, company in inTier do
				if discovered[company.id] then
					tierFound += 1
				end
			end
			order += 1
			Scroll.heading(companiesPage, `{tier.name}  ({tierFound}/{#inTier})`, order, Theme.Tiers[tier.id])
			order += 1
			local grid = gridIn(companiesPage, order)
			for position, company in inTier do
				local isFound = discovered[company.id] == true
				local card = Card.new({
					accent = if isFound then Theme.Tiers[tier.id] else Theme.Colours.Locked,
					title = if isFound then company.name else UNKNOWN,
					stat = if isFound then tier.name else "Not found yet",
					model = Models.company(company.id),
					silhouette = not isFound,
					icon = "Box",
					size = CARD_SIZE,
					layoutOrder = position,
				})
				card.Instance.Parent = grid
			end
		end

		-- Variants.
		clear(variantsPage)
		local variantsFound = readList("IndexVariants")
		Scroll.heading(variantsPage, `Variants found  ({#variantsFound}/{#Variants.list})`, 1)
		local variantGrid = gridIn(variantsPage, 2)
		for position, variant in Variants.list do
			local isFound = table.find(variantsFound, variant.id) ~= nil
			local card = Card.new({
				accent = if isFound then variant.colour else Theme.Colours.Locked,
				title = if isFound then variant.name else UNKNOWN,
				stat = `{variant.multiplier}x, 1 in {variant.oneIn}`,
				badge = if isFound then Badge.variant(variant.id) else nil,
				model = if isFound then Models.companyVariant(VARIANT_SAMPLE, variant.id) else nil,
				icon = "Gem",
				size = CARD_SIZE,
				layoutOrder = position,
			})
			card.Instance.Parent = variantGrid
		end

		-- Prizes.
		clear(prizesPage)
		Scroll.heading(prizesPage, "Prizes for collecting companies", 1)
		for index, milestone in IndexConfig.Milestones do
			local isClaimed = table.find(claimed, milestone.count) ~= nil
			local isReady = table.find(ready, milestone.count) ~= nil
			local row = Row.new({
				title = `Collect {milestone.count}`,
				detail = RewardMath.describeAll(milestone.grants),
				icon = "Gift",
				accent = if isClaimed then Theme.Colours.Cash else Theme.Menu.Index,
				height = ROW_HEIGHT,
				actionWidth = ACTION_WIDTH,
				layoutOrder = 1 + index,
			})
			row.Instance.Parent = prizesPage
			local button = Button.new({
				text = if isClaimed
					then "Claimed"
					elseif isReady then "Claim"
					else `{math.min(found, milestone.count)}/{milestone.count}`,
				colour = Theme.Colours.Cash,
				size = UDim2.fromScale(1, 1),
				textSize = Theme.TextSize.Body,
			})
			button.setEnabled(isReady)
			button.Instance.Parent = row.Action
			local count = milestone.count
			button.Activated:Connect(function()
				Remotes.ClaimIndex:FireServer(count)
			end)
		end
	end

	menuButton.Activated:Connect(function()
		if not made.isOpen() then
			Menu.open(made)
			render()
		else
			made.close()
		end
	end)
	player:GetAttributeChangedSignal("IndexDiscovered"):Connect(render)
	player:GetAttributeChangedSignal("IndexClaimed"):Connect(render)
	player:GetAttributeChangedSignal("IndexVariants"):Connect(render)
	render()
end

return IndexController
