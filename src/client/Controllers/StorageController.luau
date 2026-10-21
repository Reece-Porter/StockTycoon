--!strict
-- The Storage menu button and its window: a card for each stored company
-- with a Take out button, and a button to store what the player is carrying.
-- The server sends the list as JSON in the StorageList attribute and checks
-- every request; this only shows things and asks.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.Shared.Config.Base)
local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local VariantMath = require(ReplicatedStorage.Shared.VariantMath)
local Badge = require(script.Parent.Parent.Ui.Kit.Badge)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Card = require(script.Parent.Parent.Ui.Kit.Card)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)
local Models = require(script.Parent.Parent.Ui.Models)
local Scroll = require(script.Parent.Parent.Ui.Kit.Scroll)

type Entry = { instanceId: string, companyId: string, tier: string, variant: string?, income: number }

local CARD_SIZE = UDim2.fromOffset(136, 226)
local FOOTER_HEIGHT = 50
local STORE_HEIGHT = Theme.Size.ButtonHeight

local player = Players.LocalPlayer

local StorageController = {}

local function readStorage(): { Entry }
	local json = player:GetAttribute("StorageList")
	if typeof(json) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

local function addCard(grid: ScrollingFrame, order: number, entry: Entry)
	local company = Companies.byId[entry.companyId]
	local name = VariantMath.name(entry.variant, if company then company.name else entry.companyId)
	local card = Card.new({
		accent = Theme.Tiers[entry.tier] or Theme.Colours.Locked,
		title = name,
		stat = Format.income(entry.income),
		badge = if entry.variant then Badge.variant(entry.variant) else Badge.tier(entry.tier),
		model = Models.company(entry.companyId),
		icon = "Box",
		footerHeight = FOOTER_HEIGHT,
		layoutOrder = order,
	})
	card.Instance.Name = "Entry"
	local takeOut = Button.new({
		text = "Take out",
		colour = Theme.Colours.Cash,
		size = UDim2.fromScale(1, 1),
		textSize = Theme.TextSize.Body,
	})
	takeOut.Instance.Parent = card.Footer
	takeOut.Activated:Connect(function()
		Remotes.TakeFromStorage:FireServer(entry.instanceId)
	end)
	card.Instance.Parent = grid
end

function StorageController:Start()
	local window = Menu.window({ title = "Storage", colour = Theme.Menu.Storage })
	local store = Button.new({
		text = "Store what I'm carrying",
		icon = "Box",
		colour = Theme.Colours.Cash,
		size = UDim2.new(1, 0, 0, STORE_HEIGHT),
		textSize = Theme.TextSize.Body,
	})
	store.Instance.Parent = window.Body
	store.Activated:Connect(function()
		Remotes.StoreCarried:FireServer()
	end)

	local grid = Scroll.grid(window.Body, CARD_SIZE)
	local empty = Make.label(window.Body, {
		text = "Nothing stored. Store a company you're carrying, or one comes back here if you leave while carrying it.",
		size = Theme.TextSize.Body,
		colour = Theme.Colours.TextMuted,
		wrapped = true,
	})
	empty.Size = UDim2.new(1, 0, 0, 80)

	local menuButton = Menu.button({
		name = "Storage",
		text = "Storage",
		icon = "Box",
		colour = Theme.Menu.Storage,
		order = 1,
		side = "Left",
	})
	menuButton.Activated:Connect(function()
		Menu.toggle(window)
	end)

	local function render()
		local entries = readStorage()
		-- A stolen company can only go on a plot, so it can't be stored.
		local carrying = player:GetAttribute("CarryingCompanyId") ~= nil
			and player:GetAttribute("CarryingStolen") ~= true
		window.setTitle(`Storage ({#entries}/{BaseConfig.StorageCapacity})`)
		store.Instance.Visible = carrying
		local top = if carrying then STORE_HEIGHT + Theme.Size.Gap else 0
		grid.Position = UDim2.fromOffset(0, top)
		grid.Size = UDim2.new(1, 0, 1, -top)
		empty.Position = UDim2.fromOffset(0, top)
		empty.Visible = #entries == 0

		for _, child in grid:GetChildren() do
			if child.Name == "Entry" then
				child:Destroy()
			end
		end
		-- Best first: the highest tier, then the highest income.
		table.sort(entries, function(a, b)
			local tierA, tierB = Tiers.byId[a.tier], Tiers.byId[b.tier]
			local priceA = if tierA then tierA.price else 0
			local priceB = if tierB then tierB.price else 0
			return if priceA ~= priceB then priceA > priceB else a.income > b.income
		end)
		for index, entry in entries do
			addCard(grid, index, entry)
		end
	end

	player:GetAttributeChangedSignal("StorageList"):Connect(render)
	player:GetAttributeChangedSignal("CarryingCompanyId"):Connect(render)
	player:GetAttributeChangedSignal("CarryingStolen"):Connect(render)
	render()
end

return StorageController
