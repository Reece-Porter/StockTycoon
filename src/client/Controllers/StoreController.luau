--!strict
-- The Store button (right side, above Rebirth) and its window: the game
-- passes, marked once owned, and the developer products, each with its Robux
-- price from Roblox (Config/Monetisation). Buying opens Roblox's own purchase
-- prompt; the server decides what the player gets (MonetisationService).
-- Anything without an id yet shows as not on sale.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Monetisation = require(ReplicatedStorage.Shared.Config.Monetisation)
local RewardMath = require(ReplicatedStorage.Shared.RewardMath)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.Rewards)

-- Just above the Rebirth button.
local BUTTON_POSITION = UDim2.new(1, -12, 0.5, -56)
local BUTTON_SIZE = UDim2.fromOffset(120, 48)
local PANEL_MAX_SIZE = Vector2.new(420, 560)
local ROW_HEIGHT = 72
local BACKGROUND = Color3.fromRGB(20, 20, 25)
local BUTTON_COLOUR = Color3.fromRGB(45, 45, 55)
local BUY = Color3.fromRGB(70, 150, 90)
local OFF_SALE = Color3.fromRGB(70, 70, 80)
local OWNED = Color3.fromRGB(60, 110, 70)
local UPDATE_SECONDS = 1

local player = Players.LocalPlayer

type Row = {
	id: number,
	isPass: boolean,
	passName: Monetisation.PassName?,
	product: Monetisation.Product?,
	detail: TextLabel,
	action: TextButton,
	title: string,
	description: string,
}

local StoreController = {}

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

local function heading(parent: Instance, order: number, text: string)
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, 28)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
end

-- Robux prices, looked up once each. A failed lookup waits a while before
-- it's tried again.
local RETRY_PRICE_SECONDS = 30
local prices: { [number]: number } = {}
local failedAt: { [number]: number } = {}
local function priceOf(id: number, isPass: boolean): number?
	local known = prices[id]
	if known then
		return known
	end
	if os.clock() - (failedAt[id] or -math.huge) < RETRY_PRICE_SECONDS then
		return nil
	end
	local infoType = if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
	if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
		prices[id] = info.PriceInRobux
		return info.PriceInRobux
	end
	failedAt[id] = os.clock()
	return nil
end

-- What a Cash pack gives right now, from the player's income without any
-- reward boost.
local function cashHint(grant: RewardsConfig.Grant?): string
	if grant == nil then
		return ""
	end
	local income = player:GetAttribute("IncomePerSecond")
	local perSecond = if typeof(income) == "number" then income else 0
	local boostEndsAt = player:GetAttribute("BoostEndsAt")
	if typeof(boostEndsAt) == "number" and boostEndsAt > workspace:GetServerTimeNow() then
		perSecond /= RewardsConfig.BoostMultiplier
	end
	return ` About {Format.cash(RewardMath.cashValue(grant, perSecond))} right now.`
end

function StoreController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Store"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local openButton = button("Store", Color3.fromRGB(205, 150, 40))
	openButton.Name = "Open"
	openButton.AnchorPoint = Vector2.new(1, 0.5)
	openButton.Position = BUTTON_POSITION
	openButton.Size = BUTTON_SIZE
	openButton.Parent = gui

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
	title.Text = "Store"
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

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local rows: { Row } = {}
	local function addRow(entry: Row)
		local row = Instance.new("Frame")
		row.LayoutOrder = nextOrder()
		row.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
		row.BackgroundColor3 = BUTTON_COLOUR
		corner(row)
		row.Parent = list
		entry.detail.Position = UDim2.fromOffset(10, 0)
		entry.detail.Size = UDim2.new(1, -130, 1, 0)
		entry.detail.Parent = row
		entry.action.AnchorPoint = Vector2.new(1, 0.5)
		entry.action.Position = UDim2.new(1, -8, 0.5, 0)
		entry.action.Size = UDim2.fromOffset(108, 48)
		entry.action.Parent = row
		entry.action.Activated:Connect(function()
			if entry.id == 0 then
				return
			end
			if entry.isPass then
				local passName = entry.passName
				if passName and player:GetAttribute(`Pass{passName}`) ~= true then
					MarketplaceService:PromptGamePassPurchase(player, entry.id)
				end
			else
				MarketplaceService:PromptProductPurchase(player, entry.id)
			end
		end)
		table.insert(rows, entry)
	end
	local function detailLabel(): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.BuilderSansMedium
		label.TextSize = 14
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = true
		label.RichText = true
		return label
	end

	heading(list, nextOrder(), "Game passes")
	for _, pass in Monetisation.Passes do
		addRow({
			id = pass.id,
			isPass = true,
			passName = pass.name,
			product = nil,
			detail = detailLabel(),
			action = button("", OFF_SALE),
			title = pass.title,
			description = pass.description,
		})
	end
	heading(list, nextOrder(), "Extras")
	for _, product in Monetisation.Products do
		addRow({
			id = product.id,
			isPass = false,
			passName = nil,
			product = product,
			detail = detailLabel(),
			action = button("", OFF_SALE),
			title = product.title,
			description = product.description,
		})
	end
	local note = Instance.new("TextLabel")
	note.LayoutOrder = nextOrder()
	note.Size = UDim2.new(1, -6, 0, 40)
	note.BackgroundTransparency = 1
	note.Font = Enum.Font.BuilderSansMedium
	note.TextSize = 13
	note.TextColor3 = Color3.fromRGB(190, 190, 200)
	note.TextWrapped = true
	note.Text = "Nothing here changes the Valuation Machine. Pet spins are only ever bought with Cash."
	note.Parent = list

	local function refresh()
		for _, row in rows do
			local extra = if row.product then cashHint(row.product.grant) else ""
			row.detail.Text = `<b>{row.title}</b>\n{row.description}{extra}`
			local owned = row.passName ~= nil and player:GetAttribute(`Pass{row.passName}`) == true
			if owned then
				row.action.Text = "Owned"
				row.action.BackgroundColor3 = OWNED
				row.action.AutoButtonColor = false
			elseif row.id == 0 then
				row.action.Text = "Not on sale yet"
				row.action.TextSize = 14
				row.action.BackgroundColor3 = OFF_SALE
				row.action.AutoButtonColor = false
			else
				local price = priceOf(row.id, row.isPass)
				row.action.Text = if price then `R$ {Format.number(price)}` else "Buy"
				row.action.BackgroundColor3 = BUY
				row.action.AutoButtonColor = true
			end
		end
	end

	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			task.spawn(refresh)
		end
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	gui.Parent = player:WaitForChild("PlayerGui")

	while true do
		task.wait(UPDATE_SECONDS)
		if panel.Visible then
			refresh()
		end
	end
end

return StoreController
