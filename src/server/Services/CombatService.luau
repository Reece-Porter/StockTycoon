--!strict
-- Fighting (docs/design.md, "Combat and weapon shop"). Cartoon style only:
-- knockback, stuns and ragdolls, no blood.
--
-- The client swings its weapon and, if it thinks it hit someone, asks with the
-- Attack remote. That is only a request. The server checks the attacker is
-- holding the weapon they own and have equipped, that its cooldown has passed,
-- that the target is in range and in line of sight, and that the target isn't
-- protected, before anything happens. Then:
--   - a target carrying a company drops it (DropService),
--   - they take the weapon's damage, are pushed back and maybe stunned.
--
-- Nobody takes damage on their own base; anyone attacking them there can
-- still be hit by them. Players get Config/Combat.SpawnProtectionSeconds of
-- protection after respawning, which ends early if they attack. At 0 health
-- they ragdoll, then respawn at their own base after RespawnSeconds.
--
-- Admins see why their last attack was or wasn't allowed on the debug panel.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local AdminService = require(script.Parent.AdminService)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local DropService = require(script.Parent.DropService)
local Movement = require(script.Parent.Parent.Lib.Movement)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local PROTECTION_NAME = "SpawnProtection"
-- How long a hit's push and red flash last.
local KNOCKBACK_SECONDS = 0.15
local FLASH_SECONDS = 0.2

local lastHit: { [Player]: number } = {}
local protectedUntil: { [Player]: number } = {}
local attackLimiter = RateLimiter.new(8, 10)

local CombatService = {}

type Fighter = { character: Model, humanoid: Humanoid, root: BasePart }

local function fighter(player: Player): Fighter?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character == nil or humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return { character = character, humanoid = humanoid, root = root }
end

local function isProtected(player: Player): boolean
	return (protectedUntil[player] or 0) > os.clock()
end

local function endProtection(player: Player)
	protectedUntil[player] = nil
	local character = player.Character
	local forceField = character and character:FindFirstChild(PROTECTION_NAME)
	if forceField then
		forceField:Destroy()
	end
end

local function isOnOwnBase(player: Player): boolean
	local base = BaseService:GetBase(player)
	return base ~= nil and BaseService:IsOnBase(player, base)
end

-- Whether anything solid is between the two characters.
local function canSee(attacker: Fighter, target: Fighter): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker.character, target.character }
	params.RespectCanCollide = true
	local from = attacker.root.Position
	return workspace:Raycast(from, target.root.Position - from, params) == nil
end

-- The weapon the player has equipped, if they own it and are holding it.
local function heldWeapon(player: Player, character: Model): Weapons.Weapon?
	local data = DataService:GetData(player)
	local tool = character:FindFirstChildOfClass("Tool")
	if data == nil or tool == nil or tool:GetAttribute("WeaponId") ~= data.EquippedWeapon then
		return nil
	end
	if not DataService:OwnsWeapon(player, data.EquippedWeapon) then
		return nil
	end
	return Weapons.byId[data.EquippedWeapon]
end

local function knockBack(target: Fighter, from: Vector3, speed: number)
	local away = target.root.Position - from
	local flat = Vector3.new(away.X, 0, away.Z)
	local direction = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero
	local velocity = direction * speed + Vector3.new(0, CombatConfig.KnockbackLift, 0)

	-- The target's own client simulates their character, and runs this
	-- constraint once it replicates.
	local attachment = Instance.new("Attachment")
	attachment.Name = "Knockback"
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VectorVelocity = velocity
	push.MaxForce = math.huge
	push.Parent = attachment
	attachment.Parent = target.root
	Debris:AddItem(attachment, KNOCKBACK_SECONDS)
end

local function flash(target: Fighter)
	local highlight = Instance.new("Highlight")
	highlight.Name = "HitFlash"
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 1
	highlight.Parent = target.character
	Debris:AddItem(highlight, FLASH_SECONDS)
end

-- Returns why the attack was refused, or what it did.
local function attack(attacker: Player, targetValue: unknown): string
	if typeof(targetValue) ~= "Instance" or not targetValue:IsA("Player") then
		return "Refused: no target"
	end
	local target = targetValue :: Player
	if target == attacker or target.Parent ~= Players then
		return "Refused: not a valid target"
	end
	local from = fighter(attacker)
	local to = fighter(target)
	if from == nil or to == nil then
		return "Refused: one of you isn't alive"
	end

	local weapon = heldWeapon(attacker, from.character)
	if weapon == nil then
		return "Refused: not holding an owned, equipped weapon"
	end
	local since = os.clock() - (lastHit[attacker] or -math.huge)
	if since < weapon.cooldown - CombatConfig.CooldownTolerance then
		return string.format("Refused: cooldown (%.2fs of %.2fs)", since, weapon.cooldown)
	end
	local distance = (from.root.Position - to.root.Position).Magnitude
	local reach = weapon.range + CombatConfig.RangeTolerance
	if distance > reach then
		return string.format("Refused: out of range (%.1f > %.1f studs)", distance, reach)
	end
	if not canSee(from, to) then
		return "Refused: no line of sight"
	end
	if isProtected(target) then
		return `Refused: {target.Name} has spawn protection`
	end
	if isOnOwnBase(target) then
		return `Refused: {target.Name} is on their own base`
	end

	lastHit[attacker] = os.clock()
	endProtection(attacker)

	-- Drop first, so a knockout never counts as dying while carrying.
	local dropped = DropService:Drop(target)
	to.humanoid.Health = math.max(0, to.humanoid.Health - weapon.damage)
	knockBack(to, from.root.Position, weapon.knockback)
	if weapon.stunSeconds then
		Movement.stun(target, weapon.stunSeconds)
	end
	flash(to)

	return `Hit {target.Name} with the {weapon.name} for {weapon.damage}{if dropped
		then ", dropped their company"
		else ""}`
end

-- Swaps every joint for a loose ball socket so the character flops over.
local function ragdoll(character: Model)
	for _, motor in character:GetDescendants() do
		if not motor:IsA("Motor6D") then
			continue
		end
		local part0, part1 = motor.Part0, motor.Part1
		if part0 == nil or part1 == nil then
			continue
		end
		local attachment0 = Instance.new("Attachment")
		attachment0.CFrame = motor.C0
		attachment0.Parent = part0
		local attachment1 = Instance.new("Attachment")
		attachment1.CFrame = motor.C1
		attachment1.Parent = part1
		local socket = Instance.new("BallSocketConstraint")
		socket.Attachment0 = attachment0
		socket.Attachment1 = attachment1
		socket.LimitsEnabled = true
		socket.TwistLimitsEnabled = true
		socket.Parent = part0
		motor.Enabled = false
	end
	-- Body parts only: hats and tools stay as they are.
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = true
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	-- Only this protection counts, so remove any a SpawnLocation adds.
	character.ChildAdded:Connect(function(child)
		if child:IsA("ForceField") and child.Name ~= PROTECTION_NAME then
			task.defer(child.Destroy, child)
		end
	end)
	for _, child in character:GetChildren() do
		if child:IsA("ForceField") then
			child:Destroy()
		end
	end
	protectedUntil[player] = os.clock() + CombatConfig.SpawnProtectionSeconds
	local forceField = Instance.new("ForceField")
	forceField.Name = PROTECTION_NAME
	forceField.Parent = character
	Debris:AddItem(forceField, CombatConfig.SpawnProtectionSeconds)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = CombatConfig.MaxHealth
	humanoid.Health = CombatConfig.MaxHealth
	humanoid.Died:Connect(function()
		ragdoll(character)
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function CombatService:Init()
	Players.RespawnTime = CombatConfig.RespawnSeconds
end

function CombatService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
		protectedUntil[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Remotes.Attack.OnServerEvent:Connect(function(attacker: Player, target: unknown)
		if attackLimiter:allow(attacker) then
			AdminService:SetDebugValue(attacker, "LastAttack", attack(attacker, target))
		end
	end)
end

return CombatService
