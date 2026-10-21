--!strict
-- Swinging the weapon in the player's hands. On each activation (click or
-- tap) it plays the swing, picks the nearest other player the weapon could
-- reach, and asks the server to hit them with the Attack remote. The server
-- checks everything again and decides; this never deals damage itself.
--
-- Melee weapons hit someone in front of the character. Ranged weapons aim
-- where the player clicked or tapped, and fire a staple that only this
-- player sees.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

-- How far either side of straight ahead (as a dot product) still counts as in
-- front: about 70 degrees for melee, 20 for ranged.
local MELEE_FACING = 0.35
local RANGED_FACING = 0.94
local PROJECTILE_SIZE = Vector3.new(0.3, 0.3, 1)
local PROJECTILE_COLOUR = Theme.World.Projectile

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local lastSwing = -math.huge
local watched: { [Tool]: true } = {}

local CombatController = {}

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function isAlive(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Which way the swing goes: where the player aimed for ranged weapons,
-- otherwise the way the character faces.
local function aimDirection(root: BasePart, weapon: Weapons.Weapon): Vector3
	if weapon.projectileSpeed then
		local toAim = mouse.Hit.Position - root.Position
		local flat = Vector3.new(toAim.X, 0, toAim.Z)
		if flat.Magnitude > 0.5 then
			return flat.Unit
		end
	end
	local look = root.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z).Unit
end

local function findTarget(root: BasePart, weapon: Weapons.Weapon, direction: Vector3): Player?
	local facing = if weapon.projectileSpeed then RANGED_FACING else MELEE_FACING
	local best: Player? = nil
	local bestDistance = math.huge
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local otherRoot = rootOf(character)
		if other == player or character == nil or otherRoot == nil or not isAlive(character) then
			continue
		end
		local offset = otherRoot.Position - root.Position
		local distance = offset.Magnitude
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local inFront = flat.Magnitude < 1 or flat.Unit:Dot(direction) >= facing
		if distance <= weapon.range and inFront and distance < bestDistance then
			best = other
			bestDistance = distance
		end
	end
	return best
end

-- A staple flying from the player towards the target, or as far as the
-- weapon reaches. Only this player sees it.
local function fireProjectile(root: BasePart, weapon: Weapons.Weapon, direction: Vector3, target: Player?)
	local speed = weapon.projectileSpeed or 1
	local targetRoot = if target then rootOf(target.Character) else nil
	local from = root.Position + direction * 1.5
	local to = if targetRoot then targetRoot.Position else from + direction * weapon.range
	local staple = Instance.new("Part")
	staple.Name = "Staple"
	staple.Anchored = true
	staple.CanCollide = false
	staple.CanQuery = false
	staple.CanTouch = false
	staple.Size = PROJECTILE_SIZE
	staple.Color = PROJECTILE_COLOUR
	staple.Material = Enum.Material.Metal
	staple.CFrame = CFrame.lookAt(from, to)
	staple.Parent = workspace
	local seconds = (to - from).Magnitude / speed
	local tween = TweenService:Create(staple, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(to, to + (to - from)),
	})
	tween.Completed:Connect(function()
		staple:Destroy()
	end)
	tween:Play()
end

-- The default Animate script plays a swing when the Tool gets this value.
local function playSwing(tool: Tool)
	local swing = Instance.new("StringValue")
	swing.Name = "toolanim"
	swing.Value = "Slash"
	swing.Parent = tool
end

local function onActivated(tool: Tool)
	local weaponId = tool:GetAttribute("WeaponId")
	local weapon = if typeof(weaponId) == "string" then Weapons.byId[weaponId] else nil
	local character = player.Character
	local root = rootOf(character)
	if weapon == nil or character == nil or root == nil or not isAlive(character) then
		return
	end
	local now = os.clock()
	if now - lastSwing < weapon.cooldown then
		return
	end
	lastSwing = now

	playSwing(tool)
	local direction = aimDirection(root, weapon)
	local target = findTarget(root, weapon, direction)
	if weapon.projectileSpeed then
		fireProjectile(root, weapon, direction, target)
	end
	if target then
		Remotes.Attack:FireServer(target)
	end
end

-- Tools move between the Backpack and the character, so each is connected
-- once, the first time it is held.
local function watchTool(child: Instance)
	if child:IsA("Tool") and child:GetAttribute("WeaponId") ~= nil and watched[child] == nil then
		watched[child] = true
		child.Activated:Connect(function()
			onActivated(child)
		end)
		child.Destroying:Connect(function()
			watched[child] = nil
		end)
	end
end

local function onCharacterAdded(character: Model)
	character.ChildAdded:Connect(watchTool)
	for _, child in character:GetChildren() do
		watchTool(child)
	end
end

function CombatController:Start()
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

return CombatController
