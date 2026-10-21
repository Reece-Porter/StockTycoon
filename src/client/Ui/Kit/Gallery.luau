--!strict
-- Every UI kit piece on one screen, for checking the look in Studio's device
-- emulator before screens are rebuilt with them. Opened from the admin debug
-- panel only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)
local Badge = require(script.Parent.Badge)
local Button = require(script.Parent.Button)
local Card = require(script.Parent.Card)
local CountUp = require(script.Parent.CountUp)
local Icons = require(script.Parent.Icons)
local Make = require(script.Parent.Make)
local Toasts = require(script.Parent.Toasts)
local Window = require(script.Parent.Window)

local TABS = { "Buttons", "Cards", "Badges", "Icons" }

local Gallery = {}

local window: Window.Window? = nil

local function page(parent: Frame, name: string): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = name
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Theme.Colours.Ink
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Visible = false
	scroll.Parent = parent
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(Theme.Size.Gap, Theme.Size.Gap)
	grid.Parent = scroll
	return scroll
end

local function buttonsPage(parent: Frame): ScrollingFrame
	local scroll = page(parent, "Buttons")
	local grid = scroll:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	grid.CellSize = UDim2.fromOffset(170, Theme.Size.ButtonHeight)
	local samples: { Button.Props } = {
		{ text = "Buy", colour = Theme.Colours.Cash, icon = "Cash" },
		{ text = "Upgrade", colour = Theme.Colours.Primary, icon = "Arrow" },
		{ text = "Store", colour = Theme.Colours.Gold, icon = "Gem" },
		{ text = "Pets", colour = Theme.Colours.Purple, icon = "Plus" },
		{ text = "Sell", colour = Theme.Colours.Danger, icon = "Cross" },
		{ text = "Home", colour = Theme.Colours.Primary, icon = "Home" },
	}
	for order, sample in samples do
		sample.layoutOrder = order
		local button = Button.new(sample)
		button.Instance.Parent = scroll
		button.Activated:Connect(function()
			Toasts.show(`Pressed {sample.text}`, "Success")
		end)
	end
	local disabled = Button.new({ text = "Locked", icon = "Padlock", layoutOrder = 10 })
	disabled.setEnabled(false)
	disabled.Instance.Parent = scroll

	-- Toast kinds.
	for order, kindName in { "Info", "Success", "Warning", "Error" } do
		local kind: Toasts.Kind = kindName :: any
		local button = Button.new({
			text = `Toast: {kind}`,
			colour = Theme.Toasts[kind],
			layoutOrder = 20 + order,
			textSize = Theme.TextSize.Body,
		})
		button.Instance.Parent = scroll
		button.Activated:Connect(function()
			Toasts.show(`This is a {string.lower(kind)} message that's long enough to wrap onto a second line.`, kind)
		end)
	end

	-- The Cash count-up.
	local number = Instance.new("Frame")
	number.LayoutOrder = 30
	number.BackgroundColor3 = Theme.Colours.Card
	Make.corner(number, Theme.Corner.Medium)
	Make.outline(number, Theme.Colours.Ink, Theme.Stroke.Normal)
	local label = Make.label(number, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Button,
		colour = Theme.Colours.Cash,
	})
	Make.textOutline(label, Theme.Stroke.Thin)
	number.Parent = scroll
	local counter = CountUp.new(label, Format.cash, 950)
	local add = Button.new({ text = "+ Cash", colour = Theme.Colours.Cash, layoutOrder = 31 })
	add.Instance.Parent = scroll
	add.Activated:Connect(function()
		counter.set(counter.get() * 1.7 + 120)
	end)
	return scroll
end

local function cardsPage(parent: Frame): ScrollingFrame
	local scroll = page(parent, "Cards")
	local grid = scroll:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	grid.CellSize = UDim2.fromOffset(140, 222)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local companies = assets and assets:FindFirstChild("Companies")
	local default = companies and companies:FindFirstChild("Default")
	for order, tier in Tiers.list do
		local card = Card.new({
			accent = tier.color,
			title = tier.name,
			stat = `+{Format.number(tier.income)}/s`,
			badge = Badge.tier(tier.id),
			model = if default and default:IsA("Model") then default else nil,
			icon = "Gem",
			footerHeight = 46,
			layoutOrder = order,
		})
		local buy = Button.new({
			text = Format.cash(tier.price),
			colour = Theme.Colours.Cash,
			size = UDim2.fromScale(1, 1),
			textSize = Theme.TextSize.Body,
		})
		buy.Instance.Parent = card.Footer
		card.setLocked(order == #Tiers.list)
		card.setOwned(order == 1)
		card.Instance.Parent = scroll
	end
	return scroll
end

local function badgesPage(parent: Frame): ScrollingFrame
	local scroll = page(parent, "Badges")
	local grid = scroll:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	grid.CellSize = UDim2.fromOffset(120, 28)
	local order = 0
	local function add(badge: Frame)
		order += 1
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1
		cell.LayoutOrder = order
		badge.Parent = cell
		cell.Parent = scroll
	end
	for _, tier in Tiers.list do
		add(Badge.tier(tier.id))
	end
	for _, rarity in Pets.rarities do
		add(Badge.rarity(rarity.id))
	end
	for _, variant in Variants.list do
		add(Badge.variant(variant.id))
	end
	return scroll
end

local function iconsPage(parent: Frame): ScrollingFrame
	local scroll = page(parent, "Icons")
	local grid = scroll:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	grid.CellSize = UDim2.fromOffset(64, 64)
	for order, name in Icons.names do
		local cell = Instance.new("Frame")
		cell.LayoutOrder = order
		cell.BackgroundColor3 = Theme.Colours.Primary
		Make.corner(cell, Theme.Corner.Small)
		Make.outline(cell, Theme.Colours.Ink, Theme.Stroke.Normal)
		local icon = Icons.make(name :: any, 40)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Parent = cell
		cell.Parent = scroll
	end
	return scroll
end

-- Opens the gallery (made the first time).
function Gallery.open()
	if window == nil then
		local pages: { [string]: ScrollingFrame } = {}
		local made = Window.new({
			title = "UI kit",
			colour = Theme.Colours.Purple,
			tabs = TABS,
			displayOrder = 150,
			onTab = function(name)
				for pageName, scroll in pages do
					scroll.Visible = pageName == name
				end
			end,
		})
		pages.Buttons = buttonsPage(made.Body)
		pages.Cards = cardsPage(made.Body)
		pages.Badges = badgesPage(made.Body)
		pages.Icons = iconsPage(made.Body)
		made.Gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
		window = made
	end
	(window :: Window.Window).open()
end

return Gallery
