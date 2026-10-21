--!strict
-- Cartoon combat effects on each player's device (docs/visual-pass.md,
-- Phase 7). Looks only: the server decides every hit.
--   - Swings: this player's own swing gets a quick whoosh in the weapon's
--     colour in front of them; the Stapler Gun kicks back and puffs at the
--     nozzle instead (Config/WeaponLooks). The swing itself is the default
--     character animation (CombatController), which everyone sees.
--   - Hits: when the server confirms a hit it flashes the target (its
--     HitFlash), and everyone sees a cartoon puff with a word like "BONK!"
--     and stars bursting from the target's head. If this player made the
--     hit, their own screen shakes a little; nobody else's does.
--   - Stuns and knockouts: stars circle the head while a character can't
--     move (the server sets its walk speed to 0) or is knocked out.
--   - Knockback: a dust puff where the character lands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Pieces = require(ReplicatedStorage.Shared.Pieces)
local Theme = require(ReplicatedStorage.Shared.Theme)
local WeaponLooks = require(ReplicatedStorage.Shared.Config.WeaponLooks)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)
local Make = require(script.Parent.Parent.Ui.Kit.Make)

local WORDS = { "BONK!", "POW!", "WHAM!", "BOP!", "THWACK!" }
local HIT_SECONDS = 0.7
local HIT_SIZE = 150
local HIT_STARS = 5
-- How soon after asking to hit someone their flash counts as this player's
-- hit, and the shake.
local SHAKE_WINDOW = 0.6
local SHAKE_SECONDS = 0.18
local SHAKE_STRENGTH = 0.22
local DIZZY_STARS = 3
local DIZZY_SPEED = 4
local DIZZY_SIZE = 90
-- Knockback: how long to wait before looking for the landing, and give up.
local LAND_AFTER = 0.2
local LAND_GIVE_UP = 2.5
local LAND_REACH = 4
local DUST_PUFFS = 6
local WHOOSH_SECONDS = 0.22
local RECOIL_SECONDS = 0.08
local RECOIL_KICK = 0.35

local player = Players.LocalPlayer

type Dizzy = { gui: BillboardGui, stars: { Frame } }
type Fighter = {
	character: Model,
	humanoid: Humanoid?,
	root: BasePart?,
	head: BasePart?,
	dizzy: Dizzy?,
	knockedAt: number?,
}

local fighters: { [Model]: Fighter } = {}
local lastAttack: { target: Player?, at: number } = { target = nil, at = -math.huge }
local shakeUntil = 0

local CombatFxController = {}

-- A part only for looks, gone after a moment.
local function puffPart(name: string, size: number, cframe: CFrame, colour: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.CFrame = cframe
	part.Color = colour
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = workspace
	return part
end

local function fadeAway(part: BasePart, seconds: number, grow: number)
	local tween = TweenService:Create(
		part,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1, Size = part.Size * grow }
	)
	tween.Completed:Connect(function()
		part:Destroy()
	end)
	tween:Play()
end

-- This player's own swing: a whoosh, or a recoil and a puff for a weapon
-- that fires.
function CombatFxController.swing(tool: Tool, weaponId: string)
	local look = WeaponLooks.looks[weaponId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if look == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	if look.shoots then
		local handle = tool:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			local tip = handle.CFrame * CFrame.new(Pieces.vector(look.tip))
			fadeAway(puffPart("Puff", 0.5, tip, Theme.Colours.Card, Enum.Material.SmoothPlastic), 0.3, 3)
		end
		local grip = tool.Grip
		tool.Grip = grip * CFrame.new(0, 0, RECOIL_KICK)
		task.delay(RECOIL_SECONDS, function()
			tool.Grip = grip
		end)
		return
	end
	-- Three thin streaks in an arc in front of the character.
	for index = -1, 1 do
		local arc = root.CFrame * CFrame.Angles(0, math.rad(index * 30), 0) * CFrame.new(0, 0.6, -2.4)
		local streak = Instance.new("Part")
		streak.Name = "Whoosh"
		streak.Size = Vector3.new(1.8, 0.12, 0.12)
		streak.CFrame = arc
		streak.Color = look.trail
		streak.Material = Enum.Material.Neon
		streak.Transparency = 0.3
		streak.Anchored = true
		streak.CanCollide = false
		streak.CanTouch = false
		streak.CanQuery = false
		streak.CastShadow = false
		streak.Parent = workspace
		fadeAway(streak, WHOOSH_SECONDS, 1.4)
	end
end

-- This player asked to hit target (CombatController).
function CombatFxController.attacked(target: Player)
	lastAttack = { target = target, at = os.clock() }
end

local function shake()
	shakeUntil = os.clock() + SHAKE_SECONDS
end

-- The puff, the word and the stars over a hit character's head.
function CombatFxController.hit(character: Model)
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "HitFx"
	gui.Size = UDim2.fromOffset(HIT_SIZE, HIT_SIZE)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = head
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = gui
	-- A cloud of white puffs behind the word.
	for index, puff in { { 0.5, 0.5, 0.62 }, { 0.3, 0.42, 0.42 }, { 0.7, 0.42, 0.42 }, { 0.5, 0.3, 0.4 } } do
		local cloud = Instance.new("Frame")
		cloud.Name = `Cloud{index}`
		cloud.AnchorPoint = Vector2.new(0.5, 0.5)
		cloud.Position = UDim2.fromScale(puff[1], puff[2])
		cloud.Size = UDim2.fromScale(puff[3], puff[3])
		cloud.BackgroundColor3 = Theme.Colours.Card
		cloud.BorderSizePixel = 0
		Make.corner(cloud, 999)
		cloud.Parent = gui
	end
	local word = Make.label(gui, {
		text = WORDS[math.random(1, #WORDS)],
		font = Theme.Fonts.Display,
		colour = Theme.Colours.Gold,
		outline = true,
	})
	word.Name = "Word"
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.Position = UDim2.fromScale(0.5, 0.48)
	word.Size = UDim2.fromScale(0.8, 0.32)
	word.TextScaled = true
	word.Rotation = math.random(-12, 12)
	word.ZIndex = 3
	for index = 1, HIT_STARS do
		local star = Icons.make("Star", 26, Theme.Colours.Gold)
		star.Name = "Star"
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(0.5, 0.5)
		star.ZIndex = 2
		star.Parent = gui
		local angle = index / HIT_STARS * 2 * math.pi
		TweenService:Create(star, TweenInfo.new(HIT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.5, 0.5 + math.sin(angle) * 0.5),
			Rotation = 180,
		}):Play()
	end
	gui.Parent = head
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	task.delay(HIT_SECONDS, function()
		gui:Destroy()
	end)

	-- This player's own hit: a small shake, only on their screen.
	local target = lastAttack.target
	if target and target.Character == character and os.clock() - lastAttack.at <= SHAKE_WINDOW then
		shake()
	end
end

local function makeDizzy(fighter: Fighter): Dizzy?
	local head = fighter.head
	if head == nil then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Dizzy"
	gui.Size = UDim2.fromOffset(DIZZY_SIZE, DIZZY_SIZE / 2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Adornee = head
	local stars = {}
	for _ = 1, DIZZY_STARS do
		local star = Icons.make("Star", 22, Theme.Colours.Gold)
		star.Name = "Star"
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Parent = gui
		table.insert(stars, star)
	end
	gui.Parent = head
	return { gui = gui, stars = stars }
end

-- A puff of dust round the character's feet.
function CombatFxController.dust(position: Vector3)
	for index = 1, DUST_PUFFS do
		local angle = index / DUST_PUFFS * 2 * math.pi
		local at = CFrame.new(position + Vector3.new(math.cos(angle) * 0.9, 0.3, math.sin(angle) * 0.9))
		local puff = puffPart("Dust", 0.7, at, Theme.Colours.Locked, Enum.Material.SmoothPlastic)
		puff.Transparency = 0.25
		fadeAway(puff, 0.5, 2.4)
	end
end

local function grounded(fighter: Fighter): boolean
	local root = fighter.root
	if root == nil then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fighter.character }
	return workspace:Raycast(root.Position, Vector3.new(0, -LAND_REACH, 0), params) ~= nil
		and root.AssemblyLinearVelocity.Y > -2
end

local function watchCharacter(character: Model)
	if fighters[character] then
		return
	end
	local fighter: Fighter = { character = character }
	fighters[character] = fighter
	local function refresh()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		local head = character:FindFirstChild("Head")
		fighter.humanoid = humanoid
		fighter.root = if root and root:IsA("BasePart") then root else nil
		fighter.head = if head and head:IsA("BasePart") then head else nil
	end
	refresh()
	character.ChildAdded:Connect(function(child)
		if child.Name == "HitFlash" and child:IsA("Highlight") then
			CombatFxController.hit(character)
		end
		refresh()
	end)
	local root = fighter.root
	if root then
		root.ChildAdded:Connect(function(child)
			if child.Name == "Knockback" then
				fighter.knockedAt = os.clock()
			end
		end)
	end
end

local function watchPlayer(other: Player)
	other.CharacterAdded:Connect(watchCharacter)
	if other.Character then
		watchCharacter(other.Character)
	end
end

-- Whether a character can't move: stunned or knocked out.
local function isDizzy(fighter: Fighter): boolean
	local humanoid = fighter.humanoid
	return humanoid ~= nil and (humanoid.Health <= 0 or humanoid.WalkSpeed <= 0.01)
end

function CombatFxController.step(now: number)
	for character, fighter in fighters do
		if character.Parent == nil then
			if fighter.dizzy then
				fighter.dizzy.gui:Destroy()
			end
			fighters[character] = nil
			continue
		end
		-- Stars round the head while it can't move.
		if isDizzy(fighter) then
			if fighter.dizzy == nil then
				fighter.dizzy = makeDizzy(fighter)
			end
			local dizzy = fighter.dizzy
			if dizzy then
				for index, star in dizzy.stars do
					local angle = now * DIZZY_SPEED + index / #dizzy.stars * 2 * math.pi
					star.Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.4, 0.5 + math.sin(angle) * 0.25)
				end
			end
		elseif fighter.dizzy then
			fighter.dizzy.gui:Destroy()
			fighter.dizzy = nil
		end
		-- A dust puff where a knocked-back character lands.
		local knockedAt = fighter.knockedAt
		if knockedAt and now - knockedAt >= LAND_AFTER then
			if now - knockedAt > LAND_GIVE_UP then
				fighter.knockedAt = nil
			elseif grounded(fighter) and fighter.root then
				fighter.knockedAt = nil
				CombatFxController.dust(fighter.root.Position - Vector3.new(0, 2.8, 0))
			end
		end
	end
end

-- The camera's shake for this moment (nothing once it's over).
function CombatFxController.shakeOffset(now: number): CFrame
	local left = shakeUntil - now
	if left <= 0 then
		return CFrame.new()
	end
	local strength = SHAKE_STRENGTH * left / SHAKE_SECONDS
	return CFrame.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
end

function CombatFxController:Start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	RunService.RenderStepped:Connect(function()
		CombatFxController.step(os.clock())
	end)
	-- After the camera has moved, so the shake sits on top of it.
	RunService:BindToRenderStep("CombatShake", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		local offset = CombatFxController.shakeOffset(os.clock())
		if camera and offset ~= CFrame.new() then
			camera.CFrame *= offset
		end
	end)
end

return CombatFxController
