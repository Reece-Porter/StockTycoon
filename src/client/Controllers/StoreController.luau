--!strict
-- The Store menu button (gold with a slow shine, right side) and its window:
-- the game passes, ticked once owned, and the developer products, each with
-- its Robux price from Roblox (Config/Monetisation). Buying opens Roblox's own
-- purchase prompt; the server decides what the player gets
-- (MonetisationService). Only what has an id (set up on the Creator
-- Dashboard) is shown; with nothing on sale yet there's no Store button.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Monetisation = require(ReplicatedStorage.Shared.Config.Monetisation)
local RewardMath = require(ReplicatedStorage.Shared.RewardMath)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.Rewards)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)
local Row = require(script.Parent.Parent.Ui.Kit.Row)
local Scroll = require(script.Parent.Parent.Ui.Kit.Scroll)

local ROW_HEIGHT = 84
local ACTION_WIDTH = 116
local UPDATE_SECONDS = 1

local player = Players.LocalPlayer

type Entry = {
	id: number,
	isPass: boolean,
	passName: Monetisation.PassName?,
	product: Monetisation.Product?,
	description: string,
	row: Row.Row,
	button: Button.Button,
}

local StoreController = {}

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
	local passes: { Monetisation.Pass } = {}
	for _, pass in Monetisation.Passes do
		if pass.id ~= 0 then
			table.insert(passes, pass)
		end
	end
	local products: { Monetisation.Product } = {}
	for _, product in Monetisation.Products do
		if product.id ~= 0 then
			table.insert(products, product)
		end
	end
	if #passes == 0 and #products == 0 then
		return
	end

	local window = Menu.window({ title = "Store", colour = Theme.Menu.Store })
	local list = Scroll.list(window.Body)

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local entries: { Entry } = {}
	local function add(
		id: number,
		title: string,
		description: string,
		icon: Icons.IconName,
		passName: Monetisation.PassName?,
		product: Monetisation.Product?
	)
		local row = Row.new({
			title = title,
			icon = icon,
			accent = if passName then Theme.Colours.Gold else Theme.Colours.Cash,
			height = ROW_HEIGHT,
			actionWidth = ACTION_WIDTH,
			layoutOrder = nextOrder(),
		})
		row.Instance.Parent = list
		local button = Button.new({
			text = "",
			colour = Theme.Colours.Cash,
			size = UDim2.fromScale(1, 1),
			textSize = Theme.TextSize.Body,
		})
		button.Instance.Parent = row.Action
		local isPass = passName ~= nil
		button.Activated:Connect(function()
			if isPass then
				if player:GetAttribute(`Pass{passName}`) ~= true then
					MarketplaceService:PromptGamePassPurchase(player, id)
				end
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
		table.insert(entries, {
			id = id,
			isPass = isPass,
			passName = passName,
			product = product,
			description = description,
			row = row,
			button = button,
		})
	end

	if #passes > 0 then
		Scroll.heading(list, "Game passes", nextOrder())
		for _, pass in passes do
			add(pass.id, pass.title, pass.description, "Gem", pass.name, nil)
		end
	end
	if #products > 0 then
		Scroll.heading(list, "Extras", nextOrder())
		for _, product in products do
			add(
				product.id,
				product.title,
				product.description,
				if product.grant then "Cash" else "Padlock",
				nil,
				product
			)
		end
	end
	local note = Make.label(list, {
		text = "Nothing here changes the Valuation Machine. Pet spins are only ever bought with Cash.",
		size = Theme.TextSize.Small,
		colour = Theme.Colours.TextMuted,
		wrapped = true,
	})
	note.LayoutOrder = nextOrder()
	note.Size = UDim2.new(1, 0, 0, 40)

	local function refresh()
		for _, entry in entries do
			local extra = if entry.product then cashHint(entry.product.grant) else ""
			entry.row.setDetail(`{entry.description}{extra}`)
			local owned = entry.passName ~= nil and player:GetAttribute(`Pass{entry.passName}`) == true
			if owned then
				entry.button.setText("Owned")
				entry.button.setEnabled(false)
			else
				local price = priceOf(entry.id, entry.isPass)
				entry.button.setText(if price then `R$ {Format.number(price)}` else "Buy")
				entry.button.setEnabled(true)
			end
		end
	end

	local menuButton = Menu.button({
		name = "Store",
		text = "Store",
		icon = "Gem",
		colour = Theme.Menu.Store,
		order = 2,
		side = "Right",
		shine = true,
	})
	menuButton.Activated:Connect(function()
		Menu.toggle(window)
		if window.isOpen() then
			task.spawn(refresh)
		end
	end)

	while true do
		task.wait(UPDATE_SECONDS)
		if window.isOpen() then
			refresh()
		end
	end
end

return StoreController
