--!strict
-- The player bases come alive on each player's device (docs/visual-pass.md,
-- Phase 5). Looks only: the server owns the bases.
--   - The headquarters sign over each base's way in shows its owner's
--     display name.
--   - Plots and pet slots the owner hasn't opened yet (the Locked attribute,
--     set by LockedLook on the server) get a padlock over them.
-- And for the bases near the camera:
--   - chevrons run along the personal conveyor at its speed, and the hatch
--     over its start swings open when a company comes out;
--   - the spawn's glow gently breathes;
--   - a VIP base's gold trim (the Vip attribute) has a slow shine running
--     along it.
-- The parts it adds (chevrons) are made here, in a ChevronFx folder in the
-- base's Conveyor, so only this player has them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ConveyorConfig = require(ReplicatedStorage.Shared.Config.Conveyor)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)

local CHECK_SECONDS = 0.5
-- A base is near while the camera is this close to its spawn.
local NEAR = 110
local CHEVRONS = 8
local CHEVRON_ARM = Vector3.new(0.2, 0.04, 1.3)
-- How long the hatch stays open after a company comes out, and how far it
-- swings.
local HATCH_OPEN_SECONDS = 3
local HATCH_ANGLE = math.rad(-80)
local HATCH_SWING = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
-- The spawn glow breathes between these.
local GLOW_LOW, GLOW_HIGH = 0.84, 0.92
-- The VIP shine: how fast it travels and how long a stretch it lights.
local SHINE_SPEED = 1.2
local SHINE_SPACING = 18
local SIGN_PIXELS_PER_STUD = 30
local SIGN_DISTANCE = 150
local PADLOCK_PIXELS = 44
local PADLOCK_DISTANCE = 45
local FREE_BASE = "Free base"

type Chevron = { left: Part, right: Part }

type BaseFx = {
	model: Model,
	near: boolean,
	accent: Color3,
	signLabels: { TextLabel },
	-- The conveyor: where it starts (on top of the belt), which way it runs,
	-- how long it is, and its chevrons.
	beltStart: Vector3?,
	beltDirection: Vector3?,
	beltLength: number,
	chevrons: { Chevron },
	door: BasePart?,
	doorClosed: CFrame?,
	doorOpen: boolean,
	doorCloseAt: number,
	glow: BasePart?,
}

local bases: { [Model]: BaseFx } = {}

local BaseFxController = {}

local function lookPart(parent: Instance, name: string, size: Vector3, colour: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = colour
	part.Material = Enum.Material.Neon
	part.Transparency = 0.15
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- The sign's two faces: the owner's name over "Headquarters".
local function signFace(panel: BasePart, face: Enum.NormalId, accent: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignText"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = SIGN_PIXELS_PER_STUD
	gui.MaxDistance = SIGN_DISTANCE
	gui.LightInfluence = 0

	local name = Instance.new("TextLabel")
	name.Name = "Owner"
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.fromScale(0.5, 0.06)
	name.Size = UDim2.fromScale(0.94, 0.62)
	name.BackgroundTransparency = 1
	name.Font = Theme.Fonts.Display
	name.TextScaled = true
	name.TextColor3 = Theme.shade(accent, 0.15)
	name.Text = FREE_BASE
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.Color = Theme.Colours.Ink
	outline.Thickness = Theme.Stroke.Normal
	outline.Parent = name
	name.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 1)
	title.Position = UDim2.fromScale(0.5, 0.96)
	title.Size = UDim2.fromScale(0.6, 0.26)
	title.BackgroundTransparency = 1
	title.Font = Theme.Fonts.Body
	title.TextScaled = true
	title.TextColor3 = Theme.Colours.TextMuted
	title.Text = "HEADQUARTERS"
	title.Parent = gui

	gui.Parent = panel
	return name
end

local function ownerName(base: Model): string
	local userId = base:GetAttribute("OwnerUserId")
	if typeof(userId) ~= "number" then
		return FREE_BASE
	end
	local owner = Players:GetPlayerByUserId(userId)
	return if owner then owner.DisplayName else FREE_BASE
end

local function showOwner(fx: BaseFx)
	local text = ownerName(fx.model)
	for _, label in fx.signLabels do
		label.Text = text
	end
end

-- Chevrons along the belt, pointing the way it runs.
local function makeChevrons(fx: BaseFx, conveyor: Instance)
	local colour = Theme.tint(fx.accent, 0.35)
	local folder = Instance.new("Folder")
	folder.Name = "ChevronFx"
	folder.Parent = conveyor
	for _ = 1, CHEVRONS do
		table.insert(fx.chevrons, {
			left = lookPart(folder, "Chevron", CHEVRON_ARM, colour),
			right = lookPart(folder, "Chevron", CHEVRON_ARM, colour),
		})
	end
end

-- Finds the base's pieces the first time each is there (they can stream in).
local function setUp(fx: BaseFx)
	local base = fx.model
	if #fx.signLabels == 0 then
		local sign = base:FindFirstChild("Sign")
		local panel = sign and sign:FindFirstChild("Panel")
		if panel and panel:IsA("BasePart") then
			table.insert(fx.signLabels, signFace(panel, Enum.NormalId.Right, fx.accent))
			table.insert(fx.signLabels, signFace(panel, Enum.NormalId.Left, fx.accent))
			showOwner(fx)
		end
	end
	local conveyor = base:FindFirstChild("Conveyor")
	if fx.beltStart == nil and conveyor then
		local belt = conveyor:FindFirstChild("Belt")
		local startPart = conveyor:FindFirstChild("Start")
		local endPart = conveyor:FindFirstChild("End")
		if belt and startPart and endPart and belt:IsA("BasePart") then
			if startPart:IsA("BasePart") and endPart:IsA("BasePart") then
				local beltTop = belt.Position.Y + belt.Size.Y / 2 + 0.03
				local from = Vector3.new(startPart.Position.X, beltTop, startPart.Position.Z)
				local to = Vector3.new(endPart.Position.X, beltTop, endPart.Position.Z)
				if (to - from).Magnitude > 1 then
					fx.beltStart = from
					fx.beltDirection = (to - from).Unit
					fx.beltLength = (to - from).Magnitude
					makeChevrons(fx, conveyor)
				end
			end
		end
	end
	if fx.door == nil and conveyor then
		local hatch = conveyor:FindFirstChild("Hatch")
		local door = hatch and hatch:FindFirstChild("Door")
		if door and door:IsA("BasePart") then
			fx.door = door
			fx.doorClosed = door.CFrame
		end
	end
	if fx.glow == nil then
		local spawn = base:FindFirstChild("Spawn")
		local glow = spawn and spawn:FindFirstChild("SpawnGlow")
		if glow and glow:IsA("BasePart") then
			fx.glow = glow
		end
	end
end

local function track(base: Instance)
	if not base:IsA("Model") or bases[base] then
		return
	end
	local accent = base:GetAttribute("Accent")
	local fx: BaseFx = {
		model = base,
		near = false,
		accent = if typeof(accent) == "Color3" then accent else Theme.Colours.Primary,
		signLabels = {},
		beltLength = 0,
		chevrons = {},
		doorOpen = false,
		doorCloseAt = 0,
	}
	bases[base] = fx
	setUp(fx)
	base:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		showOwner(fx)
	end)
end

-- Swings the hatch open for a moment when a company comes out at the start
-- of this base's belt.
local function companyOut(item: Instance, now: number)
	local start = item:GetAttribute("StartCFrame")
	if typeof(start) ~= "CFrame" then
		return
	end
	for _, fx in bases do
		local from, door, closed = fx.beltStart, fx.door, fx.doorClosed
		if from and door and closed then
			local offset = start.Position - from
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < 1.5 then
				fx.doorCloseAt = now + HATCH_OPEN_SECONDS
				if not fx.doorOpen then
					fx.doorOpen = true
					local half = door.Size.Y / 2
					local open = closed
						* CFrame.new(0, half, 0)
						* CFrame.Angles(HATCH_ANGLE, 0, 0)
						* CFrame.new(0, -half, 0)
					TweenService:Create(door, HATCH_SWING, { CFrame = open }):Play()
				end
			end
		end
	end
end

-- Padlocks over the plots and pet slots not yet open, and none over the
-- rest.
local function updatePadlocks(fx: BaseFx)
	local floors = fx.model:FindFirstChild("Floors")
	if floors == nil then
		return
	end
	local holders: { Instance } = {}
	for _, floor in floors:GetChildren() do
		for _, name in { "Plots", "PetSlots" } do
			local holder = floor:FindFirstChild(name)
			if holder then
				table.insert(holders, holder)
			end
		end
	end
	for _, holder in holders do
		for _, part in holder:GetChildren() do
			if not part:IsA("BasePart") then
				continue
			end
			local existing = part:FindFirstChild("Padlock")
			local locked = part:GetAttribute("Locked") == true
			if locked and existing == nil then
				local gui = Instance.new("BillboardGui")
				gui.Name = "Padlock"
				gui.Size = UDim2.fromOffset(PADLOCK_PIXELS, PADLOCK_PIXELS)
				gui.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
				gui.MaxDistance = PADLOCK_DISTANCE
				gui.LightInfluence = 0
				local icon = Icons.make("Padlock", PADLOCK_PIXELS, Theme.Colours.Card)
				icon.Parent = gui
				gui.Parent = part
			elseif not locked and existing then
				existing:Destroy()
			end
		end
	end
end

-- Which bases are near, every so often, plus anything slow to change.
function BaseFxController.check(cameraPosition: Vector3, now: number)
	for model, fx in bases do
		if model.Parent == nil then
			bases[model] = nil
			continue
		end
		setUp(fx)
		local spawn = model:FindFirstChild("Spawn")
		local spot = if spawn and spawn:IsA("BasePart") then spawn.Position else model:GetPivot().Position
		fx.near = (spot - cameraPosition).Magnitude <= NEAR
		local door, closed = fx.door, fx.doorClosed
		if fx.doorOpen and now >= fx.doorCloseAt and door and closed then
			fx.doorOpen = false
			TweenService:Create(door, HATCH_SWING, { CFrame = closed }):Play()
		end
		updatePadlocks(fx)
	end
end

local function shineTrim(fx: BaseFx, now: number)
	local gold = Theme.Colours.Gold
	local frame = fx.model:GetPivot()
	local holders: { Instance } = {}
	local tidy = fx.model:FindFirstChild("Tidy")
	if tidy then
		table.insert(holders, tidy)
	end
	local floors = fx.model:FindFirstChild("Floors")
	if floors then
		for _, floor in floors:GetChildren() do
			local floorTrim = floor:FindFirstChild("Trim")
			if floorTrim then
				table.insert(holders, floorTrim)
			end
		end
	end
	for _, holder in holders do
		for _, part in holder:GetChildren() do
			if part:IsA("BasePart") and (part.Name == "Border" or part.Name == "Support") then
				local along = frame:PointToObjectSpace(part.Position).X
				local wave = math.max(0, math.sin(now * SHINE_SPEED - along / SHINE_SPACING)) ^ 6
				part.Color = gold:Lerp(Theme.Colours.Card, 0.55 * wave)
			end
		end
	end
end

-- Moves everything that moves, for this moment, on the near bases.
function BaseFxController.step(now: number)
	local speed = ConveyorConfig.Personal.StudsPerSecond
	for _, fx in bases do
		local from, direction = fx.beltStart, fx.beltDirection
		for _, chevron in fx.chevrons do
			chevron.left.Transparency = if fx.near then 0.15 else 1
			chevron.right.Transparency = if fx.near then 0.15 else 1
		end
		if not fx.near then
			continue
		end
		if from and direction and fx.beltLength > 0 then
			local spacing = fx.beltLength / CHEVRONS
			local parts, cframes = {}, {}
			for index, chevron in fx.chevrons do
				local along = (now * speed + (index - 1) * spacing) % fx.beltLength
				local basis = CFrame.lookAt(from + direction * along, from + direction * (along + 1))
				for _, side in { -1, 1 } do
					local arm = if side < 0 then chevron.left else chevron.right
					table.insert(parts, arm)
					table.insert(
						cframes,
						basis * CFrame.new(side * 0.42, 0, 0) * CFrame.Angles(0, side * math.rad(40), 0)
					)
				end
			end
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
		local glow = fx.glow
		if glow then
			glow.Transparency = GLOW_LOW + (GLOW_HIGH - GLOW_LOW) * (math.sin(now * 1.5) + 1) / 2
		end
		if fx.model:GetAttribute("Vip") == true then
			shineTrim(fx, now)
		end
	end
end

function BaseFxController:Start()
	local map = workspace:WaitForChild("Map")
	local folder = map:WaitForChild("Bases")
	folder.ChildAdded:Connect(track)
	for _, base in folder:GetChildren() do
		track(base)
	end
	Players.PlayerAdded:Connect(function()
		for _, fx in bases do
			showOwner(fx)
		end
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			for _, fx in bases do
				showOwner(fx)
			end
		end)
	end)

	local items = workspace:WaitForChild("ConveyorItems")
	items.ChildAdded:Connect(function(item)
		companyOut(item, os.clock())
	end)

	RunService.RenderStepped:Connect(function()
		BaseFxController.step(os.clock())
	end)

	while true do
		local camera = workspace.CurrentCamera
		if camera then
			BaseFxController.check(camera.CFrame.Position, os.clock())
		end
		task.wait(CHECK_SECONDS)
	end
end

return BaseFxController
