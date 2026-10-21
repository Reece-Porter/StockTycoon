--!strict
-- The weapon shop and the weapon in each player's hands (docs/design.md,
-- "Combat and weapon shop").
--
-- Weapons are bought with Cash only, at Workspace.Map.Shops.WeaponShop's
-- ShopPrompt part, and kept for good. One is equipped at a time: its Tool goes
-- in the player's Backpack, and in their StarterGear so it comes back after
-- every respawn. Equipping a weapon already owned works anywhere.
--
-- Tools are built when the server starts (Lib/WeaponModels, from
-- Config/WeaponLooks) into ReplicatedStorage.Assets.Weapons, unless one there
-- was made by hand (a HandMade attribute), with a "Default" Tool for any
-- weapon without one. If neither is there the weapon still works, as a Tool
-- with no handle, and the problem is reported. The shop's pegboard gets a
-- copy of each weapon, on the WeaponHook parts studio/BuildMap.luau leaves.
--
-- Players get OwnedWeapons (JSON list of ids) and EquippedWeapon attributes
-- for the shop screen.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local WeaponModels = require(script.Parent.Parent.Lib.WeaponModels)

local MAX_ID_LENGTH = 32

local shopPrompt: BasePart? = nil
local problems: { string } = {}
-- The weapon each player's Tools were last made for.
local given: { [Player]: string } = {}
local buyLimiter = RateLimiter.new(2, 4)
local equipLimiter = RateLimiter.new(2, 4)

local WeaponShopService = {}

local function weaponsFolder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Weapons")
end

local function makeTool(weapon: Weapons.Weapon): Tool
	local folder = weaponsFolder()
	local template = folder and (folder:FindFirstChild(weapon.id) or folder:FindFirstChild("Default"))
	local tool: Tool
	if template and template:IsA("Tool") then
		tool = template:Clone()
	else
		tool = Instance.new("Tool")
		tool.RequiresHandle = false
	end
	tool.Name = weapon.name
	tool.ToolTip = weapon.description
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", weapon.id)
	return tool
end

local function removeWeaponTools(container: Instance?)
	if container == nil then
		return
	end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("WeaponId") ~= nil then
			child:Destroy()
		end
	end
end

-- Swaps the player's weapon Tools for their equipped weapon.
local function giveTools(player: Player, weapon: Weapons.Weapon)
	given[player] = weapon.id
	local starterGear = player:FindFirstChildOfClass("StarterGear")
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local wasHolding = character ~= nil and character:FindFirstChildOfClass("Tool") ~= nil

	removeWeaponTools(starterGear)
	removeWeaponTools(backpack)
	removeWeaponTools(character)
	if starterGear then
		makeTool(weapon).Parent = starterGear
	end
	if backpack then
		local tool = makeTool(weapon)
		tool.Parent = backpack
		-- Someone swapping weapons keeps one in their hands.
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if wasHolding and humanoid then
			humanoid:EquipTool(tool)
		end
	end
end

local function publish(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	player:SetAttribute("OwnedWeapons", HttpService:JSONEncode(data.OwnedWeapons))
	player:SetAttribute("EquippedWeapon", data.EquippedWeapon)
	local weapon = Weapons.byId[data.EquippedWeapon] or Weapons.byId[Weapons.Starter]
	if given[player] ~= weapon.id then
		giveTools(player, weapon)
	end
end

local function isNearShop(player: Player, prompt: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local reach = CombatConfig.ShopDistance + CombatConfig.ShopDistanceTolerance
	return root ~= nil and root:IsA("BasePart") and (root.Position - prompt.Position).Magnitude <= reach
end

-- Returns the message for the player.
local function buy(player: Player, weaponId: string): string
	local weapon = Weapons.byId[weaponId]
	if weapon == nil then
		return "That weapon isn't for sale."
	end
	if DataService:GetData(player) == nil then
		return "Your data hasn't loaded yet."
	end
	if DataService:OwnsWeapon(player, weapon.id) then
		return `You already own the {weapon.name}.`
	end
	local prompt = shopPrompt
	if prompt == nil then
		return "The weapon shop isn't built yet."
	end
	if not isNearShop(player, prompt) then
		return "Go to the weapon shop to buy it."
	end
	if not DataService:SpendCash(player, weapon.price) then
		return `You need {Format.cash(weapon.price)} for the {weapon.name}.`
	end
	if not DataService:AddWeapon(player, weapon.id) then
		DataService:AddCash(player, weapon.price)
		return `You already own the {weapon.name}.`
	end
	DataService:SetEquippedWeapon(player, weapon.id)
	AnalyticsService:Spent(player, "Weapon", weapon.price, weapon.id)
	return `Bought the {weapon.name}! It's in your backpack.`
end

local function equip(player: Player, weaponId: string): string?
	local weapon = Weapons.byId[weaponId]
	if weapon == nil or not DataService:OwnsWeapon(player, weapon.id) then
		return "You don't own that weapon."
	end
	local data = DataService:GetData(player)
	if data and data.EquippedWeapon == weapon.id then
		return nil
	end
	DataService:SetEquippedWeapon(player, weapon.id)
	return `Equipped the {weapon.name}.`
end

-- Admin testing: gives a player a weapon without paying and equips it.
function WeaponShopService:Give(player: Player, weaponId: string): boolean
	if Weapons.byId[weaponId] == nil or DataService:GetData(player) == nil then
		return false
	end
	DataService:AddWeapon(player, weaponId)
	return DataService:SetEquippedWeapon(player, weaponId)
end

-- Problems found with the hand-built shop and weapon Tools, for the debug panel.
function WeaponShopService:GetProblems(): { string }
	return problems
end

-- A copy of each weapon hanging on its hook on the pegboard.
local function dressPegboard(shop: Instance)
	local goods = shop:FindFirstChild("Goods")
	if goods == nil then
		return
	end
	for _, hook in goods:GetChildren() do
		local weaponId = hook:GetAttribute("WeaponId")
		if hook.Name == "WeaponHook" and hook:IsA("BasePart") and typeof(weaponId) == "string" then
			local display = WeaponModels.display(weaponId)
			if display then
				display:PivotTo(hook.CFrame)
				display.Parent = goods
			end
		end
	end
end

function WeaponShopService:Init()
	WeaponModels.prepare()
	local map = workspace:FindFirstChild("Map")
	local shops = map and map:FindFirstChild("Shops")
	local shop = shops and shops:FindFirstChild("WeaponShop")
	if shop then
		dressPegboard(shop)
	end
	local prompt = shop and shop:FindFirstChild("ShopPrompt")
	if prompt and prompt:IsA("BasePart") then
		shopPrompt = prompt
	else
		table.insert(problems, "Workspace.Map.Shops.WeaponShop.ShopPrompt is missing or isn't a part")
	end

	local folder = weaponsFolder()
	local missing = {}
	for _, weapon in Weapons.list do
		local tool = folder and folder:FindFirstChild(weapon.id)
		if tool == nil or not tool:IsA("Tool") then
			table.insert(missing, weapon.id)
		end
	end
	if #missing > 0 then
		local default = folder and folder:FindFirstChild("Default")
		local fallback = if default and default:IsA("Tool")
			then "use Default"
			else "have no model (no Default Tool either)"
		table.insert(
			problems,
			`ReplicatedStorage.Assets.Weapons is missing Tools for {table.concat(missing, ", ")}, so they {fallback}`
		)
	end
	for _, problem in problems do
		warn(`[WeaponShopService] {problem}. Build it in Studio (see "Map naming" in docs/design.md).`)
	end
end

function WeaponShopService:Start()
	DataService:OnDataLoaded(publish)
	DataService:OnDataChanged(publish)
	Players.PlayerRemoving:Connect(function(player)
		given[player] = nil
	end)

	Remotes.BuyWeapon.OnServerEvent:Connect(function(player: Player, weaponId: unknown)
		if buyLimiter:allow(player) and typeof(weaponId) == "string" and #weaponId <= MAX_ID_LENGTH then
			Remotes.Notify:FireClient(player, buy(player, weaponId))
		end
	end)

	Remotes.EquipWeapon.OnServerEvent:Connect(function(player: Player, weaponId: unknown)
		if equipLimiter:allow(player) and typeof(weaponId) == "string" and #weaponId <= MAX_ID_LENGTH then
			local message = equip(player, weaponId)
			if message then
				Remotes.Notify:FireClient(player, message)
			end
		end
	end)
end

return WeaponShopService
