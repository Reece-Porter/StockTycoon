--!strict
-- The Weapons menu button and window: a card for every weapon with Buy, Equip
-- or Equipped. It also opens from the prompt at the weapon shop
-- (Workspace.Map.Shops.WeaponShop.ShopPrompt). Buying only works at the shop,
-- so away from it the Buy buttons wait; the server checks that and the
-- price. The server sends what the player owns as JSON in the OwnedWeapons
-- attribute, and EquippedWeapon.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Badge = require(script.Parent.Parent.Ui.Kit.Badge)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Card = require(script.Parent.Parent.Ui.Kit.Card)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)
local Models = require(script.Parent.Parent.Ui.Models)
local Scroll = require(script.Parent.Parent.Ui.Kit.Scroll)

local CARD_SIZE = UDim2.fromOffset(150, 226)
local FOOTER_HEIGHT = 50
local HINT_HEIGHT = 24
local UPDATE_SECONDS = 0.5

local player = Players.LocalPlayer

type WeaponCard = { weapon: Weapons.Weapon, card: Card.Card, button: Button.Button, equipped: Frame }

local WeaponShopController = {}

local function owned(): { [string]: boolean }
	local set = {}
	local json = player:GetAttribute("OwnedWeapons")
	if typeof(json) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
		if ok and typeof(decoded) == "table" then
			for _, id in decoded do
				if typeof(id) == "string" then
					set[id] = true
				end
			end
		end
	end
	return set
end

local function statsLine(weapon: Weapons.Weapon): string
	local reach = if weapon.projectileSpeed then "ranged" else "melee"
	local stun = if weapon.stunSeconds then ", stuns" else ""
	return `{weapon.damage} damage, {reach}{stun}`
end

-- Runs callback(child) for the child with this name now and whenever one
-- appears later.
local function watchChild(parent: Instance, name: string, callback: (Instance) -> ())
	parent.ChildAdded:Connect(function(child)
		if child.Name == name then
			callback(child)
		end
	end)
	local existing = parent:FindFirstChild(name)
	if existing then
		callback(existing)
	end
end

function WeaponShopController:Start()
	local window = Menu.window({ title = "Weapons", colour = Theme.Menu.Weapons })
	local hint = Make.label(window.Body, {
		size = Theme.TextSize.Small,
		colour = Theme.Colours.TextMuted,
		alignX = Enum.TextXAlignment.Left,
	})
	hint.Size = UDim2.new(1, 0, 0, HINT_HEIGHT)
	local grid = Scroll.grid(window.Body, CARD_SIZE)
	grid.Position = UDim2.fromOffset(0, HINT_HEIGHT)
	grid.Size = UDim2.new(1, 0, 1, -HINT_HEIGHT)

	local cards: { WeaponCard } = {}
	for order, weapon in Weapons.list do
		local equipped = Badge.new("Equipped", Theme.Colours.Cash)
		local card = Card.new({
			accent = Theme.Menu.Weapons,
			title = weapon.name,
			stat = statsLine(weapon),
			badge = equipped,
			model = Models.weapon(weapon.id),
			icon = "Weapon",
			footerHeight = FOOTER_HEIGHT,
			layoutOrder = order,
		})
		card.Instance.Parent = grid
		local button = Button.new({
			text = "",
			colour = Theme.Colours.Gold,
			size = UDim2.fromScale(1, 1),
			textSize = Theme.TextSize.Body,
		})
		button.Instance.Parent = card.Footer
		table.insert(cards, { weapon = weapon, card = card, button = button, equipped = equipped })
	end

	local shopPart: BasePart? = nil
	local function nearShop(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local spot = shopPart
		if spot == nil or root == nil or not root:IsA("BasePart") then
			return false
		end
		local reach = CombatConfig.ShopDistance + CombatConfig.ShopDistanceTolerance
		return (root.Position - spot.Position).Magnitude <= reach
	end

	local function render()
		local ownedSet = owned()
		local equippedId = player:GetAttribute("EquippedWeapon")
		local here = nearShop()
		hint.Text = if here then "Buy here, then equip anywhere." else "Buy at the weapon shop. Equip anywhere."
		for _, entry in cards do
			local weapon = entry.weapon
			local isOwned = ownedSet[weapon.id] == true
			local isEquipped = equippedId == weapon.id
			entry.card.setOwned(isOwned)
			entry.equipped.Visible = isEquipped
			if isEquipped then
				entry.button.setText("Equipped")
				entry.button.setColour(Theme.Colours.Cash)
				entry.button.setEnabled(false)
			elseif isOwned then
				entry.button.setText("Equip")
				entry.button.setColour(Theme.Colours.Primary)
				entry.button.setEnabled(true)
			else
				entry.button.setText(if weapon.price == 0 then "Free" else Format.cash(weapon.price))
				entry.button.setColour(Theme.Colours.Gold)
				entry.button.setEnabled(here)
			end
		end
	end
	for _, entry in cards do
		entry.button.Activated:Connect(function()
			if owned()[entry.weapon.id] then
				Remotes.EquipWeapon:FireServer(entry.weapon.id)
			else
				Remotes.BuyWeapon:FireServer(entry.weapon.id)
			end
		end)
	end

	local menuButton = Menu.button({
		name = "Weapons",
		text = "Weapons",
		icon = "Weapon",
		colour = Theme.Menu.Weapons,
		order = 3,
		side = "Left",
	})
	menuButton.Activated:Connect(function()
		render()
		Menu.toggle(window)
	end)
	player:GetAttributeChangedSignal("OwnedWeapons"):Connect(render)
	player:GetAttributeChangedSignal("EquippedWeapon"):Connect(render)
	render()

	-- The shop's prompt. The shop is built by hand and streams in and out
	-- with distance, so watch for it rather than wait.
	local function addPrompt(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("WeaponShopPrompt") then
			return
		end
		shopPart = part
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "WeaponShopPrompt"
		prompt.ActionText = "Open shop"
		prompt.ObjectText = "Weapons"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = CombatConfig.ShopDistance
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			render()
			Menu.open(window)
		end)
		prompt.Parent = part
	end
	watchChild(workspace:WaitForChild("Map"), "Shops", function(shops)
		watchChild(shops, "WeaponShop", function(shop)
			watchChild(shop, "ShopPrompt", addPrompt)
		end)
	end)

	while true do
		task.wait(UPDATE_SECONDS)
		if window.isOpen() then
			render()
		end
	end
end

return WeaponShopController
