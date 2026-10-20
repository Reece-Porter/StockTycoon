--!strict
-- The weapon shop screen. It opens from the prompt at the weapon shop
-- (Workspace.Map.Shops.WeaponShop.ShopPrompt) or the Weapons button on the
-- left, and lists every weapon with Buy or Equip. Buying only works at the
-- shop; the server checks that and the price. The server sends what the
-- player owns as JSON in the OwnedWeapons attribute, and EquippedWeapon.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

-- Under the Upgrade button, which is under Storage on the left edge.
local BUTTON_POSITION = UDim2.new(0, 12, 0.5, 96)
local BUTTON_SIZE = UDim2.fromOffset(160, 48)
local ROW_HEIGHT = 76
local PANEL_MAX_SIZE = Vector2.new(400, 480)
local BACKGROUND = Color3.fromRGB(20, 20, 25)
local BUTTON_COLOUR = Color3.fromRGB(45, 45, 55)
local EQUIP = Color3.fromRGB(70, 150, 90)
local BUY = Color3.fromRGB(205, 150, 40)
local EQUIPPED = Color3.fromRGB(70, 70, 80)

local player = Players.LocalPlayer

local WeaponShopController = {}

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
	local parts = {
		`{weapon.damage} damage`,
		if weapon.projectileSpeed then `ranged {weapon.range}` else "melee",
		string.format("every %.1fs", weapon.cooldown),
	}
	if weapon.stunSeconds then
		table.insert(parts, `stuns {weapon.stunSeconds}s`)
	end
	return table.concat(parts, "  ·  ")
end

local function addRow(
	list: ScrollingFrame,
	order: number,
	weapon: Weapons.Weapon,
	isOwned: boolean,
	isEquipped: boolean
)
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = BUTTON_COLOUR
	row.BackgroundTransparency = 0.3
	corner(row)

	local text = Instance.new("TextLabel")
	text.Position = UDim2.fromOffset(12, 0)
	text.Size = UDim2.new(1, -136, 1, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.BuilderSansMedium
	text.TextSize = 15
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextWrapped = true
	text.RichText = true
	local stats = statsLine(weapon)
	text.Text =
		`<b><font size="18">{weapon.name}</font></b>\n{weapon.description}\n<font color="#C8C8C8">{stats}</font>`
	text.Parent = row

	local label = if isEquipped then "Equipped" elseif isOwned then "Equip" else `Buy {Format.cash(weapon.price)}`
	local action = button(label, if isEquipped then EQUIPPED elseif isOwned then EQUIP else BUY)
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.new(1, -8, 0.5, 0)
	action.Size = UDim2.fromOffset(116, 48)
	action.AutoButtonColor = not isEquipped
	action.Activated:Connect(function()
		if isEquipped then
			return
		elseif isOwned then
			Remotes.EquipWeapon:FireServer(weapon.id)
		else
			Remotes.BuyWeapon:FireServer(weapon.id)
		end
	end)
	action.Parent = row

	row.Parent = list
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
	local gui = Instance.new("ScreenGui")
	gui.Name = "WeaponShop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local openButton = button("Weapons", BACKGROUND)
	openButton.Name = "Open"
	openButton.BackgroundTransparency = 0.2
	openButton.Position = BUTTON_POSITION
	openButton.Size = BUTTON_SIZE
	openButton.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.75)
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
	title.Text = "Weapons"
	title.Parent = panel

	local close = button("X", BUTTON_COLOUR)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(44, 44)
	close.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Position = UDim2.fromOffset(16, 52)
	hint.Size = UDim2.new(1, -32, 0, 20)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.BuilderSansMedium
	hint.TextSize = 14
	hint.TextColor3 = Color3.fromRGB(200, 200, 200)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = "Buy at the weapon shop. Equip anywhere."
	hint.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 80)
	list.Size = UDim2.new(1, -24, 1, -92)
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

	local function render()
		for _, child in list:GetChildren() do
			if child.Name == "Row" then
				child:Destroy()
			end
		end
		local ownedSet = owned()
		local equipped = player:GetAttribute("EquippedWeapon")
		for index, weapon in Weapons.list do
			addRow(list, index, weapon, ownedSet[weapon.id] == true, equipped == weapon.id)
		end
	end

	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	player:GetAttributeChangedSignal("OwnedWeapons"):Connect(render)
	player:GetAttributeChangedSignal("EquippedWeapon"):Connect(render)
	render()

	gui.Parent = player:WaitForChild("PlayerGui")

	-- The shop's prompt. The shop is built by hand and streams in and out
	-- with distance, so watch for it rather than wait.
	local function addPrompt(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("WeaponShopPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "WeaponShopPrompt"
		prompt.ActionText = "Open shop"
		prompt.ObjectText = "Weapons"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = CombatConfig.ShopDistance
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			panel.Visible = true
		end)
		prompt.Parent = part
	end
	watchChild(workspace:WaitForChild("Map"), "Shops", function(shops)
		watchChild(shops, "WeaponShop", function(shop)
			watchChild(shop, "ShopPrompt", addPrompt)
		end)
	end)
end

return WeaponShopController
