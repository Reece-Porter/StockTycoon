--!strict
-- The Storage button (left side of the screen) and its window: what is in
-- storage, a Take out button for each company, and a button to store what the
-- player is carrying. The server sends the list as JSON in the StorageList
-- attribute and checks every request; this only shows things and asks.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.Shared.Config.Base)
local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)

type Entry = { instanceId: string, companyId: string, tier: string, income: number }

local BUTTON_HEIGHT = 48
local ROW_HEIGHT = 56
local PANEL_MAX_SIZE = Vector2.new(380, 440)
local BACKGROUND = Color3.fromRGB(20, 20, 25)
local BUTTON_COLOUR = Color3.fromRGB(45, 45, 55)
local ACCENT = Color3.fromRGB(70, 150, 90)

local player = Players.LocalPlayer

local StorageController = {}

local function corner(parent: Instance)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
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

local function readStorage(): { Entry }
	local json = player:GetAttribute("StorageList")
	if typeof(json) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

local function addRow(list: ScrollingFrame, order: number, entry: Entry)
	local company = Companies.byId[entry.companyId]
	local tier = Tiers.byId[entry.tier]

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = BUTTON_COLOUR
	row.BackgroundTransparency = 0.3
	corner(row)

	local text = Instance.new("TextLabel")
	text.Position = UDim2.fromOffset(12, 0)
	text.Size = UDim2.new(1, -130, 1, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.BuilderSansMedium
	text.TextSize = 16
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextWrapped = true
	text.RichText = true
	local name = if company then company.name else entry.companyId
	local tierName = if tier then tier.name else entry.tier
	text.Text = `<b>{name}</b>\n{tierName}  ·  {Format.income(entry.income)}`
	text.Parent = row

	local takeOut = button("Take out", ACCENT)
	takeOut.AnchorPoint = Vector2.new(1, 0.5)
	takeOut.Position = UDim2.new(1, -8, 0.5, 0)
	takeOut.Size = UDim2.fromOffset(104, 44)
	takeOut.Activated:Connect(function()
		Remotes.TakeFromStorage:FireServer(entry.instanceId)
	end)
	takeOut.Parent = row

	row.Parent = list
end

function StorageController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Storage"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local openButton = button("Storage", BACKGROUND)
	openButton.Name = "Open"
	openButton.BackgroundTransparency = 0.2
	openButton.AnchorPoint = Vector2.new(0, 0.5)
	openButton.Position = UDim2.new(0, 12, 0.5, 0)
	openButton.Size = UDim2.fromOffset(160, BUTTON_HEIGHT)
	openButton.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.7)
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

	local store = button("Store what I'm carrying", ACCENT)
	store.Position = UDim2.fromOffset(12, 60)
	store.Size = UDim2.new(1, -24, 0, 44)
	store.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 112)
	list.Size = UDim2.new(1, -24, 1, -124)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list

	local empty = Instance.new("TextLabel")
	empty.Name = "Empty"
	empty.Size = UDim2.new(1, 0, 0, 60)
	empty.BackgroundTransparency = 1
	empty.Font = Enum.Font.BuilderSansMedium
	empty.TextSize = 16
	empty.TextColor3 = Color3.fromRGB(200, 200, 200)
	empty.TextWrapped = true
	empty.Text =
		"Nothing stored. Store a company you're carrying, or one comes back here if you reset while carrying it."
	empty.Parent = list

	local function render()
		local entries = readStorage()
		local carrying = player:GetAttribute("CarryingCompanyId") ~= nil

		openButton.Text = `Storage {#entries}/{BaseConfig.StorageCapacity}`
		title.Text = `Storage ({#entries}/{BaseConfig.StorageCapacity})`

		store.Visible = carrying
		list.Position = UDim2.fromOffset(12, if carrying then 112 else 60)
		list.Size = UDim2.new(1, -24, 1, if carrying then -124 else -72)

		for _, child in list:GetChildren() do
			if child.Name == "Row" then
				child:Destroy()
			end
		end
		empty.Visible = #entries == 0
		for index, entry in entries do
			addRow(list, index, entry)
		end
	end

	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	store.Activated:Connect(function()
		Remotes.StoreCarried:FireServer()
	end)

	player:GetAttributeChangedSignal("StorageList"):Connect(render)
	player:GetAttributeChangedSignal("CarryingCompanyId"):Connect(render)
	render()

	gui.Parent = player:WaitForChild("PlayerGui")
end

return StorageController
