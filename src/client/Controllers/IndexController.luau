--!strict
-- The Index button (bottom left, beside Rewards, with a badge counting prizes
-- ready to claim) and its window: the prizes for collecting so many different
-- companies, and every company by tier, with "???" for ones not found yet.
-- The server sends IndexDiscovered and IndexClaimed (JSON lists) and checks
-- every claim.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local IndexConfig = require(ReplicatedStorage.Shared.Config.Index)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardMath = require(ReplicatedStorage.Shared.RewardMath)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)

-- Beside the Rewards button, at the bottom of the stack on the left edge.
local BUTTON_POSITION = UDim2.new(0, 96, 0.5, 104)
local BUTTON_SIZE = UDim2.fromOffset(76, 48)
local PANEL_MAX_SIZE = Vector2.new(420, 560)
local BACKGROUND = Color3.fromRGB(20, 20, 25)
local BUTTON_COLOUR = Color3.fromRGB(45, 45, 55)
local CLAIM = Color3.fromRGB(70, 150, 90)
local WAITING = Color3.fromRGB(70, 70, 80)
local DONE = Color3.fromRGB(60, 110, 70)
local UNKNOWN = Color3.fromRGB(55, 55, 62)
local BADGE = Color3.fromRGB(230, 60, 60)

local player = Players.LocalPlayer

local IndexController = {}

local function corner(parent: Instance, radius: number?)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius or 8)
	uiCorner.Parent = parent
end

local function button(text: string, colour: Color3): TextButton
	local newButton = Instance.new("TextButton")
	newButton.BackgroundColor3 = colour
	newButton.Font = Enum.Font.BuilderSansBold
	newButton.TextSize = 18
	newButton.TextColor3 = Color3.new(1, 1, 1)
	newButton.Text = text
	newButton.AutoButtonColor = true
	corner(newButton)
	return newButton
end

local function readList(name: string): { any }
	local json = player:GetAttribute(name)
	if typeof(json) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

local function heading(parent: Instance, order: number, text: string, colour: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, -6, 0, 28)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = 18
	label.TextColor3 = colour or Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

function IndexController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Index"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local openButton = button("Index", BACKGROUND)
	openButton.Name = "Open"
	openButton.BackgroundTransparency = 0.2
	openButton.Position = BUTTON_POSITION
	openButton.Size = BUTTON_SIZE
	openButton.TextSize = 16
	openButton.Parent = gui

	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -4, 0, 4)
	badge.Size = UDim2.fromOffset(22, 22)
	badge.BackgroundColor3 = BADGE
	badge.Font = Enum.Font.BuilderSansBold
	badge.TextSize = 14
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Visible = false
	corner(badge, 11)
	badge.Parent = openButton

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.85)
	panel.BackgroundColor3 = BACKGROUND
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	corner(panel)
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = PANEL_MAX_SIZE
	sizeLimit.Parent = panel

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.new(1, -80, 0, 44)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = 22
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local close = button("X", BUTTON_COLOUR)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(44, 44)
	close.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 56)
	list.Size = UDim2.new(1, -24, 1, -68)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	local function render()
		local discoveredList = readList("IndexDiscovered")
		local claimed = readList("IndexClaimed")
		local discovered: { [string]: boolean } = {}
		for _, id in discoveredList do
			discovered[id] = true
		end
		local found = #discoveredList
		local ready = RewardMath.readyIndex(found, claimed)
		badge.Visible = #ready > 0
		badge.Text = tostring(#ready)
		title.Text = `Index ({found}/{#Companies.list})`

		for _, child in list:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end

		heading(list, nextOrder(), "Prizes for collecting companies")
		for _, milestone in IndexConfig.Milestones do
			local row = Instance.new("Frame")
			row.LayoutOrder = nextOrder()
			row.Size = UDim2.new(1, -6, 0, 52)
			row.BackgroundColor3 = BUTTON_COLOUR
			row.BackgroundTransparency = 0.3
			corner(row)
			row.Parent = list

			local detail = Instance.new("TextLabel")
			detail.Position = UDim2.fromOffset(10, 0)
			detail.Size = UDim2.new(1, -130, 1, 0)
			detail.BackgroundTransparency = 1
			detail.Font = Enum.Font.BuilderSansMedium
			detail.TextSize = 14
			detail.TextColor3 = Color3.new(1, 1, 1)
			detail.TextXAlignment = Enum.TextXAlignment.Left
			detail.TextWrapped = true
			detail.RichText = true
			detail.Text = `<b>Collect {milestone.count}</b>\n{RewardMath.describeAll(milestone.grants)}`
			detail.Parent = row

			local isClaimed = table.find(claimed, milestone.count) ~= nil
			local isReady = table.find(ready, milestone.count) ~= nil
			local label = if isClaimed
				then "Claimed"
				elseif isReady then "Claim"
				else `{math.min(found, milestone.count)}/{milestone.count}`
			local action = button(label, if isClaimed then DONE elseif isReady then CLAIM else WAITING)
			action.AutoButtonColor = isReady
			action.AnchorPoint = Vector2.new(1, 0.5)
			action.Position = UDim2.new(1, -8, 0.5, 0)
			action.Size = UDim2.fromOffset(110, 40)
			action.TextSize = 16
			action.Parent = row
			local count = milestone.count
			action.Activated:Connect(function()
				if isReady then
					Remotes.ClaimIndex:FireServer(count)
				end
			end)
		end

		-- Every variant, with what it earns and how rare it is. Ones not found
		-- yet are hidden.
		local variantsFound = readList("IndexVariants")
		heading(list, nextOrder(), `Variants  ({#variantsFound}/{#Variants.list})`)
		local variantGrid = Instance.new("Frame")
		variantGrid.LayoutOrder = nextOrder()
		variantGrid.Size = UDim2.new(1, -6, 0, 0)
		variantGrid.AutomaticSize = Enum.AutomaticSize.Y
		variantGrid.BackgroundTransparency = 1
		variantGrid.Parent = list
		local variantLayout = Instance.new("UIGridLayout")
		variantLayout.CellSize = UDim2.new(0.5, -4, 0, 44)
		variantLayout.CellPadding = UDim2.fromOffset(6, 6)
		variantLayout.SortOrder = Enum.SortOrder.LayoutOrder
		variantLayout.Parent = variantGrid
		for position, variant in Variants.list do
			local isFound = table.find(variantsFound, variant.id) ~= nil
			local cell = Instance.new("TextLabel")
			cell.LayoutOrder = position
			cell.BackgroundColor3 = if isFound then variant.colour else UNKNOWN
			cell.BackgroundTransparency = if isFound then 0.35 else 0
			cell.Font = Enum.Font.BuilderSansBold
			cell.TextSize = 14
			cell.TextColor3 = if isFound then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 160)
			cell.TextStrokeTransparency = if isFound then 0.5 else 1
			cell.TextWrapped = true
			cell.Text = if isFound
				then `{variant.name}\n{variant.multiplier}x, 1 in {variant.oneIn}`
				else `???\n{variant.multiplier}x, 1 in {variant.oneIn}`
			corner(cell, 6)
			cell.Parent = variantGrid
		end

		-- Every company, by tier. Ones not found yet are hidden.
		for _, tier in Tiers.list do
			local tierCompanies: { Companies.Company } = {}
			local inTier = Companies.byTier[tier.id]
			if inTier then
				tierCompanies = inTier
			end
			local tierFound = 0
			for _, company in tierCompanies do
				if discovered[company.id] then
					tierFound += 1
				end
			end
			heading(list, nextOrder(), `{tier.name}  ({tierFound}/{#tierCompanies})`, tier.color)
			local grid = Instance.new("Frame")
			grid.LayoutOrder = nextOrder()
			grid.Size = UDim2.new(1, -6, 0, 0)
			grid.AutomaticSize = Enum.AutomaticSize.Y
			grid.BackgroundTransparency = 1
			grid.Parent = list
			local gridLayout = Instance.new("UIGridLayout")
			gridLayout.CellSize = UDim2.new(0.5, -4, 0, 36)
			gridLayout.CellPadding = UDim2.fromOffset(6, 6)
			gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
			gridLayout.Parent = grid
			for position, company in tierCompanies do
				local isFound = discovered[company.id] == true
				local cell = Instance.new("TextLabel")
				cell.LayoutOrder = position
				cell.BackgroundColor3 = if isFound then tier.color else UNKNOWN
				cell.BackgroundTransparency = if isFound then 0.35 else 0
				cell.Font = Enum.Font.BuilderSansBold
				cell.TextSize = 15
				cell.TextColor3 = if isFound then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 160)
				cell.TextStrokeTransparency = if isFound then 0.5 else 1
				cell.TextWrapped = true
				cell.Text = if isFound then company.name else "???"
				corner(cell, 6)
				cell.Parent = grid
			end
		end
	end

	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	player:GetAttributeChangedSignal("IndexDiscovered"):Connect(render)
	player:GetAttributeChangedSignal("IndexClaimed"):Connect(render)
	player:GetAttributeChangedSignal("IndexVariants"):Connect(render)
	render()
	gui.Parent = player:WaitForChild("PlayerGui")
end

return IndexController
