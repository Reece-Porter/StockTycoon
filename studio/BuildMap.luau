--!strict
-- Stock Tycoon map builder: the only Studio script needed for the map.
--
-- How to use it: stop the game if it's playing, clear the Command Bar
-- completely (Cmd+A, Delete), paste this whole file, press Run, then save the
-- place. The Output says "Map built" when it's done.
--
-- It builds or fixes everything the game code looks for under Workspace.Map
-- and ReplicatedStorage.Assets (see "Map naming" in docs/design.md). It puts
-- every part in its exact place rather than adjusting what's there, so it
-- works whatever state the map is in and is safe to run again. When the map
-- needs to change, this file changes; never run old map scripts alongside it.
--
-- It reads the game's colours from ReplicatedStorage.Shared.Theme, so Rojo
-- must be connected to the Test place when you run it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local themeModule = sharedFolder and sharedFolder:FindFirstChild("Theme")
if themeModule == nil or not themeModule:IsA("ModuleScript") then
	error("ReplicatedStorage.Shared.Theme is missing: connect Rojo to the Test place, then run this again.")
end
local Theme = require(themeModule :: ModuleScript) :: any
local BASE = Theme.Base

local DARK = Color3.fromRGB(60, 60, 70)
local GOLD = Color3.fromRGB(225, 185, 60)
local CASH = Theme.Colours.Cash
-- Parts only for looks cast a shadow only if at least this big.
local SHADOW_SIZE = 4
-- Stands a cylinder (which lies along x) up.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- Eight bases, four either side of a street with the middle conveyor down
-- the centre, all facing it. Each base is BASE_WIDTH along the street and
-- BASE_DEPTH back from it, with BASE_GAP between neighbours, so stealing
-- means a real trip. The middle four come first, so they fill first; Base1
-- faces Base2.
local BASE_WIDTH = 36
local BASE_DEPTH = 86
local BASE_GAP = 44
-- From the middle of the street to the front of the bases.
local STREET_HALF = 40
local BASE_X = STREET_HALF + BASE_DEPTH / 2
local BASE_STEP = BASE_WIDTH + BASE_GAP
local BASE_SPOTS = {
	{ x = -BASE_X, z = -BASE_STEP / 2 },
	{ x = BASE_X, z = -BASE_STEP / 2 },
	{ x = -BASE_X, z = BASE_STEP / 2 },
	{ x = BASE_X, z = BASE_STEP / 2 },
	{ x = -BASE_X, z = -BASE_STEP * 1.5 },
	{ x = BASE_X, z = -BASE_STEP * 1.5 },
	{ x = -BASE_X, z = BASE_STEP * 1.5 },
	{ x = BASE_X, z = BASE_STEP * 1.5 },
}
-- Inside a base, in its own frame: x runs from the back (-BASE_DEPTH / 2) to
-- the front by the street (+BASE_DEPTH / 2), and z across it. The front yard
-- has the conveyor, the Valuation Machine, the lock button and the spawn. In
-- the hall behind it a walkway runs straight back down the middle of every
-- floor, with five plots either side near the walls, each with a cash pad in
-- front of it by the walkway. The stairs zigzag up behind the hall in two
-- strips, meeting landings at either side.
local HALL_FRONT = 21
local HALL_BACK = -31
local WALKWAY = 8
local PLOT_Z = 11.5 -- plots either side of the walkway, near the walls
local PAD_Z = 6 -- cash pads, between the walkway and the plots
local SLOT_Z = 9 -- pet slots at the back of the hall
local STAIRS_X = { -34, -40 } -- floors 2 and 4 go up one strip, floor 3 the other
local LANDING_Z = 10.5 -- where every staircase starts and ends
local RISE = 12 -- height between floors
local RAIL_HEIGHT = 3
local RUN = 2 * LANDING_Z -- length of every staircase
-- The area players can be in, and the hills around it.
local PLAY_HALF_X = BASE_X + BASE_DEPTH / 2 + 14
local PLAY_HALF_Z = BASE_STEP * 1.5 + BASE_WIDTH / 2 + 22
local HILLS = 140 -- how far beyond the edge hills can reach
-- The middle conveyor runs the length of the map, a little way into a
-- tunnel in the hills at each end.
local TUNNEL = 16
local BELT_LENGTH = 2 * (PLAY_HALF_Z + TUNNEL)
-- The weapon and pet shops stand at one end of the street and the upgrade
-- station at the other, this far from the middle.
local STATION_Z = PLAY_HALF_Z - 16

local function newPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- The part with this name, made if missing (with this colour and material),
-- and put exactly here.
local function place(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	material: Enum.Material?
): BasePart
	local found = parent:FindFirstChild(name)
	if found and found:IsA("BasePart") then
		found.Anchored = true
		found.Size = size
		found.CFrame = cframe
		return found
	end
	if found then
		found:Destroy()
	end
	local part = newPart(parent, name, size, cframe, colour)
	if material then
		part.Material = material
	end
	return part
end

local function folder(parent: Instance, name: string): Instance
	local found = parent:FindFirstChild(name)
	if found then
		return found
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = name
	newFolder.Parent = parent
	return newFolder
end

local function model(parent: Instance, name: string): Instance
	local found = parent:FindFirstChild(name)
	if found then
		return found
	end
	local newModel = Instance.new("Model")
	newModel.Name = name
	newModel.Parent = parent
	return newModel
end

-- An empty model with this name, replacing whatever had the name before.
local function freshModel(parent: Instance, name: string): Model
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local newModel = Instance.new("Model")
	newModel.Name = name
	newModel.Parent = parent
	return newModel
end

local function hide(part: BasePart)
	part.Transparency = 1
	part.CanCollide = false
end

-- A part only for looks: anchored, and nothing collides with it, touches it
-- or hits it with a raycast, so it never gets in the way of walking, a shot
-- or a steal check. Small ones cast no shadow.
local function decor(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local part = newPart(parent, name, size, cframe, colour)
	if shape then
		part.Shape = shape
		part.Size = size
	end
	if material then
		part.Material = material
	end
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = math.max(size.X, size.Y, size.Z) >= SHADOW_SIZE
	return part
end

-- A decorative cylinder standing up, centred at cframe.
local function column(
	parent: Instance,
	name: string,
	height: number,
	diameter: number,
	cframe: CFrame,
	colour: Color3,
	material: Enum.Material?
): Part
	local size = Vector3.new(height, diameter, diameter)
	return decor(parent, name, size, cframe * UPRIGHT, colour, material, Enum.PartType.Cylinder)
end

-- How thick handrails are. A handrail sits with its top level with the top
-- of its railing, so the base stays no taller than it was.
local BAR = 0.35

-- A decorative cylinder lying along the z axis of cframe (a handrail).
local function bar(parent: Instance, name: string, length: number, cframe: CFrame, colour: Color3): Part
	local size = Vector3.new(length, BAR, BAR)
	return decor(parent, name, size, cframe * CFrame.Angles(0, math.rad(90), 0), colour, nil, Enum.PartType.Cylinder)
end

-- Takes off the looks hung on one of the game's parts (a plot, a pet slot,
-- the spawn or the lock button) before they're made again, so running this
-- twice changes nothing.
local function clearDecor(part: Instance)
	for _, child in part:GetChildren() do
		if child:IsA("BasePart") then
			child:Destroy()
		end
	end
end

local baseplate = Workspace:FindFirstChild("Baseplate")
local groundY = if baseplate and baseplate:IsA("BasePart")
	then baseplate.CFrame.Position.Y + baseplate.Size.Y / 2
	else 0

local map = folder(Workspace, "Map")

-- 1. The ground: grass instead of the default grey grid, with a paved street
-- down the middle between the two rows of bases, under the middle conveyor
-- and the shops. It sits a tenth of a stud above the grass so the two never
-- flicker.
if baseplate and baseplate:IsA("BasePart") then
	baseplate.Material = Enum.Material.Grass
	baseplate.Color = Color3.fromRGB(96, 156, 74)
	baseplate.TopSurface = Enum.SurfaceType.Smooth
	for _, child in baseplate:GetChildren() do
		if child:IsA("Texture") then
			child:Destroy()
		end
	end
end
local plaza = place(
	map,
	"Plaza",
	Vector3.new(2 * STREET_HALF, 1, 2 * PLAY_HALF_Z),
	CFrame.new(0, groundY - 0.4, 0),
	Color3.fromRGB(196, 190, 178),
	Enum.Material.Pavement
)
plaza.Color = Color3.fromRGB(196, 190, 178)
plaza.Material = Enum.Material.Pavement

local bases = folder(map, "Bases")

-- 2. The bases, each laid out the same way in its own frame (see the
-- constants at the top) and dressed in its own accent colour (Theme.Base,
-- also stored on the base as an Accent attribute). Everything only for looks
-- is a decor part and stays inside the base's floor and below its top
-- railings, so the game's idea of where a base is doesn't change. The game's
-- own parts keep their names, places and sizes; the Spawn, LockButton, the
-- machine's Pad and the pet slots became invisible pads with the look built
-- round them.
for index, spot in BASE_SPOTS do
	local base = model(bases, "Base" .. index)
	local center = Vector3.new(spot.x, groundY + 0.5, spot.z)
	local turn = if center.X < 0 then CFrame.new() else CFrame.Angles(0, math.pi, 0)
	local frame = CFrame.new(center.X, 0, center.Z) * turn
	local function at(lx: number, ly: number, lz: number): CFrame
		return frame * CFrame.new(lx, ly, lz)
	end
	local accent: Color3 = BASE.Accents[(index - 1) % #BASE.Accents + 1]
	base:SetAttribute("Accent", accent)
	local carpet: Color3 = Theme.shade(accent, 0.3)
	local light: Color3 = Theme.tint(accent, 0.55)
	local groundTop = groundY + 1
	local tops = { groundTop, groundTop + RISE, groundTop + 2 * RISE, groundTop + 3 * RISE }
	local halfWidth, halfDepth = BASE_WIDTH / 2, BASE_DEPTH / 2

	local floorPart = place(base, "Floor", Vector3.new(BASE_DEPTH, 1, BASE_WIDTH), at(0, groundY + 0.5, 0), BASE.Floor)
	floorPart.Color = BASE.Floor
	floorPart.Material = Enum.Material.SmoothPlastic

	-- The front yard. The spawn: a round pad with a glowing ring in the
	-- accent colour and a soft glow rising from it.
	local spawn = place(base, "Spawn", Vector3.new(6, 0.2, 6), at(27, groundTop + 0.1, 0), BASE.Plot)
	spawn.Transparency = 1
	clearDecor(spawn)
	column(spawn, "SpawnRing", 0.14, 6.6, at(27, groundTop + 0.07, 0), accent, Enum.Material.Neon)
	column(spawn, "SpawnDisc", 0.2, 6, at(27, groundTop + 0.1, 0), BASE.Plot)
	local spawnGlow = column(spawn, "SpawnGlow", 4, 5, at(27, groundTop + 2.2, 0), accent, Enum.Material.Neon)
	spawnGlow.Transparency = 0.88
	spawnGlow.CastShadow = false

	-- The personal conveyor: the belt between side rails with a roller at
	-- the far end, and a hatch over the start whose door the client opens
	-- when a company comes out. The client also runs chevrons along it.
	local conveyor = model(base, "Conveyor")
	local belt = place(conveyor, "Belt", Vector3.new(6, 1, 32), at(37, groundTop + 0.5, 0), BASE.Belt)
	belt.Color = BASE.Belt
	belt.Material = Enum.Material.SmoothPlastic
	hide(place(conveyor, "Start", Vector3.new(1, 1, 1), at(37, groundTop + 1.5, -16), Color3.fromRGB(0, 255, 0)))
	hide(place(conveyor, "End", Vector3.new(1, 1, 1), at(37, groundTop + 1.5, 16), Color3.fromRGB(255, 0, 0)))
	local beltLook = freshModel(conveyor, "Look")
	for _, side in { -1, 1 } do
		decor(
			beltLook,
			"Rail",
			Vector3.new(0.4, 1.3, 32),
			at(37 + side * 3.2, groundTop + 0.65, 0),
			Theme.shade(accent, 0.2)
		)
	end
	decor(
		beltLook,
		"Roller",
		Vector3.new(6.4, 1.1, 1.1),
		at(37, groundTop + 0.55, 16),
		BASE.Roller,
		nil,
		Enum.PartType.Cylinder
	)
	local hatch = freshModel(conveyor, "Hatch")
	decor(hatch, "Back", Vector3.new(7.2, 6.6, 0.4), at(37, groundTop + 3.3, -17.8), BASE.Housing)
	for _, side in { -1, 1 } do
		decor(hatch, "Side", Vector3.new(0.4, 6.6, 2.4), at(37 + side * 3.4, groundTop + 3.3, -16.6), BASE.Housing)
	end
	decor(hatch, "Roof", Vector3.new(7.2, 0.5, 2.8), at(37, groundTop + 6.85, -16.6), BASE.Housing)
	decor(hatch, "Stripe", Vector3.new(7.3, 0.25, 0.2), at(37, groundTop + 6.5, -15.25), accent, Enum.Material.Neon)
	decor(hatch, "Door", Vector3.new(6.2, 5.6, 0.2), at(37, groundTop + 3.8, -15.3), Theme.shade(accent, 0.15))

	-- The Valuation Machine: a glowing round pad between two cabinets with
	-- blinking lights, under a beam with a scrolling ticker and a screen with
	-- a little chart (both drawn by the client). The game stands companies on
	-- the invisible Pad.
	local machine = model(base, "Machine")
	local pad = place(machine, "Pad", Vector3.new(6, 1, 6), at(27, groundTop + 0.5, -11), BASE.MachinePad)
	pad.Transparency = 1
	for _, child in machine:GetChildren() do
		if child ~= pad then
			child:Destroy()
		end
	end
	column(machine, "PadBase", 0.8, 6.8, at(27, groundTop + 0.4, -11), BASE.Machine)
	column(machine, "PadGlow", 0.2, 5.8, at(27, groundTop + 0.88, -11), BASE.MachinePad, Enum.Material.Neon)
	for _, side in { -1, 1 } do
		local z = -11 + side * 4.4
		decor(machine, "Cabinet", Vector3.new(2.2, 8, 1.6), at(27, groundTop + 4, z), BASE.Machine)
		decor(machine, "Trim", Vector3.new(2.3, 0.3, 1.7), at(27, groundTop + 7.6, z), accent)
		for k = 1, 3 do
			local where = at(28.15, groundTop + 2 + k * 1.2, z)
			decor(machine, "Light", Vector3.new(0.2, 0.45, 0.45), where, Theme.Colours.Cash, Enum.Material.Neon)
		end
	end
	decor(machine, "Beam", Vector3.new(2.4, 1.4, 10.4), at(27, groundTop + 8.7, -11), BASE.Machine)
	decor(machine, "Ticker", Vector3.new(0.1, 0.9, 9.6), at(28.25, groundTop + 8.7, -11), Theme.Colours.Ink)
	decor(machine, "ScreenFrame", Vector3.new(0.3, 3.4, 7.4), at(26.9, groundTop + 11, -11), accent)
	decor(machine, "Screen", Vector3.new(0.2, 3, 7), at(27.1, groundTop + 11, -11), Theme.Colours.Ink)

	-- The lock button: a big round button on a pedestal (the client draws a
	-- padlock on it and presses it down when the base locks), over the
	-- invisible LockButton the game uses.
	local lockButton = place(base, "LockButton", Vector3.new(3, 1.2, 3), at(27, groundTop + 0.6, 11), BASE.LockCap)
	lockButton.Transparency = 1
	clearDecor(lockButton)
	column(lockButton, "Pedestal", 0.8, 2.8, at(27, groundTop + 0.4, 11), BASE.Machine)
	column(lockButton, "Rim", 0.12, 2.5, at(27, groundTop + 0.84, 11), BASE.LockCap, Enum.Material.Neon)
	column(lockButton, "Cap", 0.35, 2.2, at(27, groundTop + 0.975, 11), BASE.LockCap)

	-- The headquarters sign over the way in; the client writes the owner's
	-- name on its panel.
	local sign = freshModel(base, "Sign")
	for _, side in { -1, 1 } do
		column(sign, "Post", 10.4, 0.9, at(41.5, groundTop + 5.2, side * 16.8), accent)
		decor(
			sign,
			"PostCap",
			Vector3.new(1.3, 1.3, 1.3),
			at(41.5, groundTop + 10.65, side * 16.8),
			BASE.Post,
			nil,
			Enum.PartType.Ball
		)
	end
	decor(sign, "Board", Vector3.new(0.6, 3.4, 33.6), at(41.5, groundTop + 9.2, 0), accent)
	decor(sign, "Panel", Vector3.new(0.7, 2.6, 31.6), at(41.5, groundTop + 9.2, 0), BASE.SignPanel)

	-- The lock's force field across the way in, hidden until the base is
	-- locked (the client shows it). It stops nobody: the game moves people
	-- out of a locked base itself.
	local gate = freshModel(base, "Gate")
	local field = decor(
		gate,
		"Field",
		Vector3.new(0.3, 10, 35),
		at(42.6, groundTop + 5, 0),
		Theme.World.Locked,
		Enum.Material.ForceField
	)
	field.Transparency = 1
	field.CastShadow = false

	-- The hall: plots in pairs either side of the walkway from the front back
	-- (so they unlock front to back), each turned to face the walkway with
	-- its cash pad in front, then the pet slots behind them. Everything that
	-- belongs to an upper floor is in its Floor folder, so the game can show
	-- each floor only once the owner has opened it. Each plot is a display
	-- stand: a white top on a darker lip with a glow in the accent colour
	-- between them (the game turns locked ones to stone). Each pet slot is a
	-- cushioned bed on a short pedestal.
	local floors = folder(base, "Floors")
	for n = 1, 4 do
		local floor = folder(floors, "Floor" .. n)
		local top = tops[n]
		if n > 1 then
			local hallSize = Vector3.new(HALL_FRONT - HALL_BACK, 1, BASE_WIDTH)
			local platform =
				place(floor, "Platform", hallSize, at((HALL_FRONT + HALL_BACK) / 2, top - 0.5, 0), BASE.Floor)
			platform.Color = BASE.Floor
			platform.Material = Enum.Material.SmoothPlastic
		end
		local plots = folder(floor, "Plots")
		local pads = folder(floor, "CollectPads")
		for i = 1, 10 do
			local side = if (i - 1) % 2 == 0 then -1 else 1
			local plotX = HALL_FRONT - 4.5 - math.floor((i - 1) / 2) * 9
			local facing = if side < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.new()
			local plotAt = at(plotX, top, side * PLOT_Z) * facing
			local plot = place(plots, "Plot" .. i, Vector3.new(7, 0.4, 7), plotAt * CFrame.new(0, 0.2, 0), BASE.Plot)
			plot.Color = BASE.Plot
			plot.Material = Enum.Material.SmoothPlastic
			clearDecor(plot)
			decor(plot, "Lip", Vector3.new(7.4, 0.25, 7.4), plotAt * CFrame.new(0, 0.125, 0), BASE.PlotLip)
			local plotGlow = decor(
				plot,
				"Glow",
				Vector3.new(7.3, 0.3, 7.3),
				plotAt * CFrame.new(0, 0.15, 0),
				accent,
				Enum.Material.Neon
			)
			plotGlow.Transparency = 0.2
			place(pads, "Pad" .. i, Vector3.new(5, 0.2, 3.5), at(plotX, top + 0.1, side * PAD_Z) * facing, CASH)
		end
		local slots = folder(floor, "PetSlots")
		for slot = 1, 2 do
			local slotZ = (if slot == 1 then -1 else 1) * SLOT_Z
			local where = at(HALL_BACK + 4, top, slotZ)
			local slotPart =
				place(slots, "Slot" .. slot, Vector3.new(3, 0.4, 3), where * CFrame.new(0, 0.2, 0), BASE.Cushion)
			slotPart.Transparency = 1
			clearDecor(slotPart)
			column(slotPart, "Pedestal", 0.2, 2.6, where * CFrame.new(0, 0.1, 0), BASE.Pedestal)
			column(slotPart, "Bed", 0.22, 3.2, where * CFrame.new(0, 0.31, 0), light, Enum.Material.Fabric)
			local cushion = decor(
				slotPart,
				"Cushion",
				Vector3.new(2.5, 0.2, 2.5),
				where * CFrame.new(0, 0.4, 0),
				BASE.Cushion,
				Enum.Material.Fabric
			)
			local round = Instance.new("SpecialMesh")
			round.MeshType = Enum.MeshType.Sphere
			round.Parent = cushion
		end
	end
	if base:IsA("Model") then
		base.WorldPivot = at(0, groundTop, 0)
	end
	if conveyor:IsA("Model") then
		conveyor.WorldPivot = at(37, groundTop + 0.5, 0)
	end
	if machine:IsA("Model") then
		machine.WorldPivot = at(27, groundTop + 0.5, -11)
	end

	-- On every floor: the carpet down the walkway (from the street on the
	-- ground floor) with white edging and a row of diamonds in the hall,
	-- grout lines making large tiles between the plots, and on the upper
	-- floors a two-tone front edge and supports along the sides. The ground
	-- floor's are in Tidy, each upper floor's in its own Trim.
	local trim = freshModel(base, "Tidy")
	for n = 1, 4 do
		local parent = if n == 1 then trim else freshModel(folder(floors, "Floor" .. n), "Trim")
		local front = if n == 1 then halfDepth else HALL_FRONT
		local walkwaySize = Vector3.new(front - HALL_BACK, 0.1, WALKWAY)
		local walkway = newPart(parent, "Walkway", walkwaySize, at((front + HALL_BACK) / 2, tops[n] + 0.05, 0), carpet)
		walkway.Material = Enum.Material.Fabric
		walkway.CanCollide = false
		walkway.CanQuery = false
		walkway.CanTouch = false
		local edgeFront = if n == 1 then 33.5 else HALL_FRONT
		local edgeSize = Vector3.new(edgeFront - HALL_BACK, 0.12, 0.4)
		for _, side in { -1, 1 } do
			local where = at((edgeFront + HALL_BACK) / 2, tops[n] + 0.06, side * (WALKWAY / 2 - 0.2))
			decor(parent, "CarpetEdge", edgeSize, where, BASE.Post, Enum.Material.Fabric)
		end
		for x = 18, -28, -6 do
			local where = at(x, tops[n] + 0.13, 0) * CFrame.Angles(0, math.rad(45), 0)
			decor(parent, "Motif", Vector3.new(1, 0.06, 1), where, light, Enum.Material.Fabric)
		end
		for _, x in { 12, 3, -6, -15, -24 } do
			decor(parent, "Grout", Vector3.new(0.2, 0.04, BASE_WIDTH - 2), at(x, tops[n] + 0.02, 0), BASE.Grout)
		end
		for _, side in { -1, 1 } do
			local groutSize = Vector3.new(HALL_FRONT - HALL_BACK, 0.04, 0.2)
			decor(
				parent,
				"Grout",
				groutSize,
				at((HALL_FRONT + HALL_BACK) / 2, tops[n] + 0.02, side * 16.25),
				BASE.Grout
			)
		end
		if n > 1 then
			local fasciaWidth = BASE_WIDTH - 1
			decor(
				parent,
				"Fascia",
				Vector3.new(0.3, 0.45, fasciaWidth),
				at(HALL_FRONT + 0.15, tops[n] - 0.225, 0),
				accent
			)
			decor(
				parent,
				"Fascia",
				Vector3.new(0.3, 0.55, fasciaWidth),
				at(HALL_FRONT + 0.15, tops[n] - 0.725, 0),
				BASE.Edge
			)
			local supportHeight = tops[n] - tops[n - 1]
			for _, x in { HALL_FRONT - 0.5, (HALL_FRONT + HALL_BACK) / 2, HALL_BACK + 0.5, -halfDepth + 0.5 } do
				for _, side in { -1, 1 } do
					local where = at(x, tops[n - 1] + supportHeight / 2, side * (halfWidth - 0.5))
					newPart(parent, "Support", Vector3.new(1, supportHeight, 1), where, accent)
				end
			end
		end
	end
	for _, side in { -1, 1 } do
		local alongSize = Vector3.new(BASE_DEPTH, 0.1, 1)
		newPart(trim, "Border", alongSize, at(0, groundTop + 0.05, side * (halfWidth - 0.5)), accent).CanCollide = false
		local acrossSize = Vector3.new(1, 0.1, BASE_WIDTH - 2)
		newPart(trim, "Border", acrossSize, at(side * (halfDepth - 0.5), groundTop + 0.05, 0), accent).CanCollide =
			false
	end

	-- Glass walls along both sides and the back, from the front of the hall
	-- to the back of the stairs, so the only way in is from the front. Each
	-- floor has its own band of glass up to the next floor (the top floor's
	-- up to its railings): the ground floor's in Glass, each upper floor's in
	-- its Floor folder. Each band has a frame in the accent colour (Frames):
	-- posts along each wall and a strip along the bottom, and along the top
	-- of the highest band.
	for n = 1, 4 do
		local glassParent = if n == 1 then base else folder(floors, "Floor" .. n)
		local glassWalls = freshModel(glassParent, "Glass")
		local frames = freshModel(glassParent, "Frames")
		local glassTop = if n < 4 then tops[n + 1] else tops[4] + RAIL_HEIGHT
		local glassHeight = glassTop - tops[n]
		local glassY = tops[n] + glassHeight / 2
		local function glass(size: Vector3, cframe: CFrame)
			local pane = newPart(glassWalls, "Glass", size, cframe, BASE.Glass, 0.6)
			pane.Material = Enum.Material.Glass
			pane.Reflectance = 0.08
			pane.CastShadow = false
		end
		local strips: { number } = if n < 4 then { tops[n] + 0.2 } else { tops[n] + 0.2, glassTop - 0.2 }
		local sideLength = HALL_FRONT + halfDepth
		local sideX = (HALL_FRONT - halfDepth) / 2
		for _, side in { -1, 1 } do
			glass(Vector3.new(sideLength, glassHeight, 0.5), at(sideX, glassY, side * (halfWidth - 0.25)))
			local frameZ = side * (halfWidth - 0.3)
			for _, y in strips do
				decor(frames, "Frame", Vector3.new(sideLength, 0.4, 0.6), at(sideX, y, frameZ), accent)
			end
			for x = HALL_FRONT, -halfDepth, -16 do
				local postX = math.clamp(x, -halfDepth + 0.3, HALL_FRONT - 0.3)
				decor(frames, "Mullion", Vector3.new(0.6, glassHeight, 0.6), at(postX, glassY, frameZ), accent)
			end
		end
		glass(Vector3.new(0.5, glassHeight, BASE_WIDTH - 1), at(-halfDepth + 0.25, glassY, 0))
		for _, y in strips do
			decor(frames, "Frame", Vector3.new(0.6, 0.4, BASE_WIDTH), at(-halfDepth + 0.3, y, 0), accent)
		end
	end

	-- Stairs up to each floor behind the hall. Floors 2 and 4 go up one
	-- strip towards +z and floor 3 comes back up the other, each from a
	-- landing to a landing that meets the back of the floor it serves. Each
	-- step has a pale tread with a lip over its front edge, and both sides
	-- have a glass rail with a rounded handrail on posts.
	local landingX = (HALL_BACK - halfDepth) / 2
	local landingWidth = HALL_BACK + halfDepth
	local landingLength = halfWidth - LANDING_Z
	for n = 2, 4 do
		local floor = folder(floors, "Floor" .. n)
		local low, high = tops[n - 1], tops[n]
		local access = freshModel(floor, "Access")
		local dir = if n % 2 == 0 then 1 else -1
		local stairX = STAIRS_X[if n % 2 == 0 then 1 else 2]
		local rise = high - low
		local steps = math.max(1, math.floor(rise + 0.5))
		local stepRise, tread = rise / steps, RUN / steps
		local bottomZ = -LANDING_Z * dir
		for k = 1, steps do
			local stepTop = low + k * stepRise
			local z = bottomZ + dir * (k - 0.5) * tread
			if n == 2 then
				local height = stepTop - groundTop
				newPart(access, "Step", Vector3.new(6, height, tread), at(stairX, groundTop + height / 2, z), BASE.Step)
			else
				newPart(access, "Step", Vector3.new(6, 1, tread), at(stairX, stepTop - 0.5, z), BASE.Step)
			end
			local treadAt = at(stairX, stepTop + 0.05, z - dir * 0.075)
			decor(access, "Tread", Vector3.new(6, 0.1, tread + 0.15), treadAt, BASE.Tread)
		end
		-- The landing at the top, across both strips, with a trim where the
		-- stairs meet it; the glass walls guard its outside. Until the next
		-- floor is open there are no stairs on from it, so the other strip is
		-- railed off (TopOnly, which the game shows only on the highest open
		-- floor).
		local landingZ = dir * (LANDING_Z + halfWidth) / 2
		if n == 2 then
			local height = high - groundTop
			local size = Vector3.new(landingWidth, height, landingLength)
			newPart(access, "TopLanding", size, at(landingX, groundTop + height / 2, landingZ), BASE.Step)
		else
			local size = Vector3.new(landingWidth, 1, landingLength)
			newPart(access, "TopLanding", size, at(landingX, high - 0.5, landingZ), BASE.Floor)
		end
		local trimAt = at(landingX, high + 0.06, dir * (LANDING_Z + 0.15))
		decor(access, "LandingTrim", Vector3.new(landingWidth, 0.12, 0.3), trimAt, accent)
		local railY = high + RAIL_HEIGHT / 2
		local topOnly = freshModel(floor, "TopOnly")
		local across = at(STAIRS_X[if n % 2 == 0 then 2 else 1], railY, dir * (LANDING_Z + 0.25))
		local landingRail = newPart(topOnly, "LandingRail", Vector3.new(6, RAIL_HEIGHT, 0.5), across, BASE.Glass, 0.7)
		landingRail.Material = Enum.Material.Glass
		landingRail.CastShadow = false
		decor(
			topOnly,
			"RailTop",
			Vector3.new(6, BAR, BAR),
			across * CFrame.new(0, RAIL_HEIGHT / 2 - BAR / 2, 0),
			accent,
			nil,
			Enum.PartType.Cylinder
		)
		for _, postX in { -2.8, 2.8 } do
			column(topOnly, "Post", RAIL_HEIGHT, 0.3, across * CFrame.new(postX, 0, 0), BASE.Post)
		end
		-- Glass rails on both sides the full length of the stairs, standing
		-- on the line of the step edges, so they meet the landings with no
		-- gap, each with a handrail on five posts. Stairs off the ground get
		-- an underside.
		local length = math.sqrt(RUN * RUN + rise * rise)
		local tilt = -dir * math.atan2(rise, RUN)
		local slope = at(stairX, (low + high) / 2, bottomZ + dir * RUN / 2) * CFrame.Angles(tilt, 0, 0)
		for _, railX in { -2.75, 2.75 } do
			local cframe = slope * CFrame.new(railX, RAIL_HEIGHT / 2, 0)
			local panel = newPart(access, "Handrail", Vector3.new(0.5, RAIL_HEIGHT, length), cframe, BASE.Glass, 0.7)
			panel.Material = Enum.Material.Glass
			panel.CastShadow = false
			bar(access, "RailTop", length, slope * CFrame.new(railX, RAIL_HEIGHT - BAR / 2, 0), accent)
			for k = 0, 4 do
				local along = -length / 2 + 1 + k * (length - 2) / 4
				local foot = (slope * CFrame.new(railX, 0, along)).Position
				column(
					access,
					"Post",
					RAIL_HEIGHT,
					0.3,
					CFrame.new(foot + Vector3.new(0, RAIL_HEIGHT / 2, 0)) * frame.Rotation,
					BASE.Post
				)
			end
		end
		if n > 2 then
			newPart(access, "Underside", Vector3.new(6, 0.6, length - 1), slope * CFrame.new(0, -1.3, 0), BASE.Step)
		end
	end

	-- Railings along the front of the upper floors and at the back, open onto
	-- the landing each floor's stairs arrive at: glass with a rounded
	-- handrail on posts. The glass walls guard the sides.
	for n = 2, 4 do
		local floor = folder(floors, "Floor" .. n)
		local railings = freshModel(floor, "Railings")
		local y = tops[n] + RAIL_HEIGHT / 2
		local function rail(size: Vector3, railX: number, z: number)
			local panel = newPart(railings, "Rail", size, at(railX, y, z), BASE.Glass, 0.7)
			panel.Material = Enum.Material.Glass
			panel.CastShadow = false
			local length = size.Z
			bar(railings, "RailTop", length, at(railX, tops[n] + RAIL_HEIGHT - BAR / 2, z), accent)
			local posts = math.max(2, math.floor(length / 4.5) + 1)
			for k = 0, posts - 1 do
				local postZ = z - length / 2 + 0.2 + k * (length - 0.4) / (posts - 1)
				column(railings, "Post", RAIL_HEIGHT, 0.3, at(railX, y, postZ), BASE.Post)
			end
		end
		rail(Vector3.new(0.5, RAIL_HEIGHT, BASE_WIDTH - 1), HALL_FRONT - 0.25, 0)
		local dir = if n % 2 == 0 then 1 else -1
		local backLength = halfWidth + LANDING_Z
		rail(Vector3.new(0.5, RAIL_HEIGHT, backLength), HALL_BACK + 0.25, -dir * (halfWidth - backLength / 2))
	end
end

-- 3. The middle conveyor down the street, resting on the ground. It runs
-- into the hills at both ends; companies appear and disappear at the tunnels.
local shared = model(map, "SharedConveyor")
local beltColour = Color3.fromRGB(200, 160, 40)
place(shared, "Belt", Vector3.new(8, 2, BELT_LENGTH), CFrame.new(0, groundY + 1, 0), beltColour)
local beltEnd = PLAY_HALF_Z - 2
hide(place(shared, "Start", Vector3.new(1, 1, 1), CFrame.new(0, groundY + 2.5, -beltEnd), Color3.fromRGB(0, 255, 0)))
hide(place(shared, "End", Vector3.new(1, 1, 1), CFrame.new(0, groundY + 2.5, beltEnd), Color3.fromRGB(255, 0, 0)))
local edge = Color3.fromRGB(90, 70, 30)
place(shared, "TrimLeft", Vector3.new(0.6, 2.2, BELT_LENGTH), CFrame.new(-4.3, groundY + 1.1, 0), edge)
place(shared, "TrimRight", Vector3.new(0.6, 2.2, BELT_LENGTH), CFrame.new(4.3, groundY + 1.1, 0), edge)

-- 4. Keep any spawn pad off the middle conveyor.
for _, item in Workspace:GetDescendants() do
	if item:IsA("SpawnLocation") then
		local position = item.CFrame.Position
		if math.abs(position.X) < 10 and math.abs(position.Z) < BELT_LENGTH / 2 + 6 then
			item.CFrame = CFrame.new(18, position.Y, -40)
		end
	end
end

-- 5. The weapon and pet shops side by side at one end of the street and the
-- upgrade station at the other, each facing back along the street. They're
-- rebuilt each run, so they're always in the right place and turned the
-- right way.
type ShopStyle = {
	x: number,
	z: number,
	counter: Color3,
	prompt: Color3,
	promptMaterial: Enum.Material,
	wall: Color3,
	roof: Color3,
	sign: string,
	signColour: Color3,
}
local shopStyles: { [string]: ShopStyle } = {
	WeaponShop = {
		x = -20,
		z = -STATION_Z,
		counter = Color3.fromRGB(150, 95, 55),
		prompt = GOLD,
		promptMaterial = Enum.Material.Metal,
		wall = Color3.fromRGB(60, 60, 75),
		roof = Color3.fromRGB(230, 120, 40),
		sign = "WEAPONS",
		signColour = Color3.fromRGB(255, 220, 90),
	},
	PetShop = {
		x = 20,
		z = -STATION_Z,
		counter = Color3.fromRGB(240, 235, 225),
		prompt = Color3.fromRGB(190, 150, 255),
		promptMaterial = Enum.Material.Neon,
		wall = Color3.fromRGB(70, 60, 95),
		roof = Color3.fromRGB(60, 180, 170),
		sign = "PETS",
		signColour = Color3.fromRGB(190, 150, 255),
	},
	UpgradeStation = {
		x = -20,
		z = STATION_Z,
		counter = Color3.fromRGB(90, 110, 140),
		prompt = Color3.fromRGB(90, 230, 140),
		promptMaterial = Enum.Material.Neon,
		wall = Color3.fromRGB(45, 70, 60),
		roof = Color3.fromRGB(80, 170, 90),
		sign = "UPGRADES",
		signColour = Color3.fromRGB(140, 255, 170),
	},
}
local shops = folder(map, "Shops")
for name, style in shopStyles do
	local old = shops:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local newShop = Instance.new("Model")
	newShop.Name = name
	-- Built in its own frame with its front towards local -z, then turned so
	-- the front faces the middle of the street.
	local facing = if style.z < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.new()
	local frame = CFrame.new(style.x, groundY, style.z) * facing
	local function block(blockName: string, size: Vector3, bx: number, bottom: number, bz: number, colour: Color3)
		return newPart(newShop, blockName, size, frame * CFrame.new(bx, bottom + size.Y / 2, bz), colour)
	end
	block("Floor", Vector3.new(14, 0.4, 9), 0, 0, 0, Color3.fromRGB(95, 95, 105))
	block("Counter", Vector3.new(10, 3, 2), 0, 0.4, -2, style.counter)
	block("ShopPrompt", Vector3.new(2, 1, 1.2), 0, 3.4, -2, style.prompt).Material = style.promptMaterial
	block("BackWall", Vector3.new(14, 9, 1), 0, 0.4, 4, style.wall)
	block("PostLeft", Vector3.new(0.8, 8.4, 0.8), -6.5, 0.4, -4, Color3.fromRGB(230, 230, 235))
	block("PostRight", Vector3.new(0.8, 8.4, 0.8), 6.5, 0.4, -4, Color3.fromRGB(230, 230, 235))
	block("Roof", Vector3.new(15, 0.8, 10), 0, 8.8, 0, style.roof)
	local sign = block("Sign", Vector3.new(11, 2.2, 0.4), 0, 9.6, -4.6, Color3.fromRGB(35, 35, 45))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.BuilderSansBold
	text.TextScaled = true
	text.TextColor3 = style.signColour
	text.Text = style.sign
	text.Parent = gui
	-- Teleports arrive in front of the counter, from this pivot.
	newShop.WorldPivot = frame
	newShop.Parent = shops
end

-- 6. The leaderboards, two either side of the street in the gaps between the
-- middle bases, facing across it. The game writes the lists on each board's
-- front face.
local leaderboards = folder(map, "Leaderboards")
local stands = freshModel(leaderboards, "Stands")
local BOARD_X = STREET_HALF + 8
local boardSpots = {
	{ name = "IncomeBoard", x = -BOARD_X, z = -7 },
	{ name = "RebirthsBoard", x = -BOARD_X, z = 7 },
	{ name = "StealsBoard", x = BOARD_X, z = -7 },
	{ name = "KnockoutsBoard", x = BOARD_X, z = 7 },
}
for _, spot in boardSpots do
	-- Turned so the front face points across the street.
	local facing = CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, (if spot.x < 0 then -1 else 1) * math.pi / 2, 0)
	place(
		leaderboards,
		spot.name,
		Vector3.new(10, 12, 1),
		facing * CFrame.new(0, groundY + 8, 0),
		Color3.fromRGB(20, 22, 30)
	)
	newPart(stands, spot.name .. "Back", Vector3.new(11, 13, 0.6), facing * CFrame.new(0, groundY + 8.5, 0.8), GOLD)
	newPart(stands, spot.name .. "Plinth", Vector3.new(11, 2, 2.2), facing * CFrame.new(0, groundY + 1, 0.3), DARK)
end

-- 7. Hills all round the edge of the map, with invisible walls along the
-- edge so nobody can leave. The band of land the hills stand on is cleared
-- first, so running this again never piles more terrain on. The hills are
-- the same every time.
local border = freshModel(map, "Border")
local WALL_HEIGHT = 120
for _, wall in
	{
		{ size = Vector3.new(2, WALL_HEIGHT, 2 * PLAY_HALF_Z + 4), x = PLAY_HALF_X + 1, z = 0 },
		{ size = Vector3.new(2, WALL_HEIGHT, 2 * PLAY_HALF_Z + 4), x = -PLAY_HALF_X - 1, z = 0 },
		{ size = Vector3.new(2 * PLAY_HALF_X + 4, WALL_HEIGHT, 2), x = 0, z = PLAY_HALF_Z + 1 },
		{ size = Vector3.new(2 * PLAY_HALF_X + 4, WALL_HEIGHT, 2), x = 0, z = -PLAY_HALF_Z - 1 },
	}
do
	local part = newPart(border, "Wall", wall.size, CFrame.new(wall.x, groundY + WALL_HEIGHT / 2, wall.z), DARK, 1)
	part.CanQuery = false
	part.CanTouch = false
end
-- A stone arch where the conveyor meets the hills at each end, with a dark
-- back wall inside the tunnel.
local STONE = Color3.fromRGB(120, 115, 110)
for _, side in { -1, 1 } do
	local mouthZ = side * (PLAY_HALF_Z + 1)
	for _, postX in { -9, 9 } do
		newPart(border, "ArchPost", Vector3.new(2, 12, 2), CFrame.new(postX, groundY + 6, mouthZ), STONE)
	end
	newPart(border, "ArchTop", Vector3.new(20, 2, 2), CFrame.new(0, groundY + 13, mouthZ), STONE)
	local backZ = side * (PLAY_HALF_Z + TUNNEL + 0.5)
	newPart(border, "TunnelBack", Vector3.new(16, 12, 1), CFrame.new(0, groundY + 6, backZ), Color3.fromRGB(15, 15, 18))
end

local terrain = Workspace:FindFirstChildOfClass("Terrain")
if terrain then
	local bottom, height = groundY - 4, 90
	local outerX, outerZ = PLAY_HALF_X + HILLS, PLAY_HALF_Z + HILLS
	-- The band round the edge: the two ends (corners included), then the sides.
	local bands = {
		{ x = 0, z = (PLAY_HALF_Z + outerZ) / 2, sizeX = 2 * outerX, sizeZ = HILLS },
		{ x = 0, z = -(PLAY_HALF_Z + outerZ) / 2, sizeX = 2 * outerX, sizeZ = HILLS },
		{ x = (PLAY_HALF_X + outerX) / 2, z = 0, sizeX = HILLS, sizeZ = 2 * PLAY_HALF_Z },
		{ x = -(PLAY_HALF_X + outerX) / 2, z = 0, sizeX = HILLS, sizeZ = 2 * PLAY_HALF_Z },
	}
	for _, band in bands do
		local cframe = CFrame.new(band.x, bottom + height / 2, band.z)
		terrain:FillBlock(cframe, Vector3.new(band.sizeX, height, band.sizeZ), Enum.Material.Air)
	end
	-- A low grassy bank from the edge outwards.
	for _, band in bands do
		terrain:FillBlock(
			CFrame.new(band.x, groundY, band.z),
			Vector3.new(band.sizeX, 4, band.sizeZ),
			Enum.Material.Grass
		)
	end
	-- A row of grassy hills along the edge, some topped with rock, and a row of
	-- bigger ones behind. No hill's foot reaches more than a few studs past
	-- the edge.
	local random = Random.new(2026)
	local function hill(x: number, z: number, outward: Vector3, smallest: number, largest: number, away: number)
		local radius = random:NextNumber(smallest, largest)
		local reach = away + random:NextNumber(-4, 8)
		local centre = Vector3.new(x, groundY - radius * 0.35, z) + outward * (radius + reach)
		terrain:FillBall(centre, radius, Enum.Material.Grass)
		if random:NextNumber() < 0.4 then
			local rockRadius = radius * random:NextNumber(0.3, 0.5)
			local offset = Vector3.new(random:NextNumber(-4, 4), radius * 0.55, random:NextNumber(-4, 4))
			terrain:FillBall(centre + offset, rockRadius, Enum.Material.Rock)
		end
	end
	local SPACING = 16
	for _, side in { -1, 1 } do
		for x = -outerX, outerX, SPACING do
			hill(x, side * PLAY_HALF_Z, Vector3.new(0, 0, side), 16, 30, 0)
			hill(x, side * PLAY_HALF_Z, Vector3.new(0, 0, side), 24, 40, 30)
		end
		for z = -PLAY_HALF_Z, PLAY_HALF_Z, SPACING do
			hill(side * PLAY_HALF_X, z, Vector3.new(side, 0, 0), 16, 30, 0)
			hill(side * PLAY_HALF_X, z, Vector3.new(side, 0, 0), 24, 40, 30)
		end
	end
	-- The tunnels the conveyor runs through, cut last.
	for _, side in { -1, 1 } do
		local from, to = PLAY_HALF_Z - 4, PLAY_HALF_Z + TUNNEL + 4
		local cframe = CFrame.new(0, groundY + 6, side * (from + to) / 2)
		terrain:FillBlock(cframe, Vector3.new(16, 12, to - from), Enum.Material.Air)
	end
end

-- 8. Models the game copies: the Default company, the weapon Tools and the
-- Default pet. Any that already exist (including ones built by hand) are
-- left alone.
local assets = folder(ReplicatedStorage, "Assets")

local companies = folder(assets, "Companies")
if companies:FindFirstChild("Default") == nil then
	local box = Instance.new("Model")
	box.Name = "Default"
	box.PrimaryPart = newPart(box, "Box", Vector3.new(3, 3, 3), CFrame.new(0, 1.5, 0), Color3.fromRGB(70, 130, 255))
	box.Parent = companies
end

local weapons = folder(assets, "Weapons")
local function toolPart(
	tool: Tool,
	name: string,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	material: Enum.Material?,
	cylinder: boolean?
): Part
	local part = newPart(tool, name, size, cframe, colour)
	part.Material = material or Enum.Material.SmoothPlastic
	if cylinder then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	return part
end
local function makeTool(id: string, build: (Tool) -> ())
	if weapons:FindFirstChild(id) then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = id
	tool.CanBeDropped = false
	local handle = toolPart(tool, "Handle", Vector3.new(0.4, 0.4, 0.4), CFrame.new(), Color3.new(0, 0, 0))
	handle.Transparency = 1
	build(tool)
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") and child ~= handle then
			local weld = Instance.new("Weld")
			weld.Part0 = handle
			weld.Part1 = child
			weld.C0 = handle.CFrame:Inverse() * child.CFrame
			weld.Parent = child
		end
	end
	tool.Parent = weapons
end
local PAPER, BAND = Color3.fromRGB(235, 230, 215), Color3.fromRGB(120, 120, 125)
makeTool("Newspaper", function(tool)
	toolPart(tool, "Roll", Vector3.new(3, 0.6, 0.6), CFrame.new(0, 1, 0) * UPRIGHT, PAPER, nil, true)
	toolPart(tool, "BandLow", Vector3.new(0.15, 0.66, 0.66), CFrame.new(0, 0.2, 0) * UPRIGHT, BAND, nil, true)
	toolPart(tool, "BandHigh", Vector3.new(0.15, 0.66, 0.66), CFrame.new(0, 1.9, 0) * UPRIGHT, BAND, nil, true)
end)
makeTool("Briefcase", function(tool)
	toolPart(tool, "Grip", Vector3.new(1, 0.2, 0.25), CFrame.new(0, 0, 0), Color3.fromRGB(60, 40, 25))
	toolPart(tool, "Case", Vector3.new(2.2, 1.5, 0.6), CFrame.new(0, -0.95, 0), Color3.fromRGB(115, 75, 45))
	toolPart(tool, "Clasp", Vector3.new(0.4, 0.2, 0.66), CFrame.new(0, -0.35, 0), GOLD, Enum.Material.Metal)
end)
makeTool("StaplerGun", function(tool)
	local metal = Enum.Material.Metal
	toolPart(tool, "Grip", Vector3.new(0.45, 1, 0.6), CFrame.new(0, 0, 0), Color3.fromRGB(50, 50, 55))
	toolPart(tool, "Body", Vector3.new(0.8, 0.6, 2.2), CFrame.new(0, 0.75, -0.4), Color3.fromRGB(40, 110, 170))
	toolPart(tool, "Lever", Vector3.new(0.7, 0.25, 2), CFrame.new(0, 1.15, -0.3), Color3.fromRGB(185, 185, 195), metal)
	toolPart(tool, "Nozzle", Vector3.new(0.4, 0.3, 0.3), CFrame.new(0, 0.7, -1.6), Color3.fromRGB(150, 150, 160), metal)
end)
makeTool("Gavel", function(tool)
	local wood, metal = Enum.Material.Wood, Enum.Material.Metal
	toolPart(tool, "Shaft", Vector3.new(0.35, 2.6, 0.35), CFrame.new(0, 0.9, 0), Color3.fromRGB(140, 90, 50), wood)
	toolPart(tool, "Head", Vector3.new(1.8, 0.9, 0.9), CFrame.new(0, 2.3, 0), Color3.fromRGB(100, 60, 30), wood, true)
	toolPart(tool, "BandLeft", Vector3.new(0.15, 0.96, 0.96), CFrame.new(-0.6, 2.3, 0), GOLD, metal, true)
	toolPart(tool, "BandRight", Vector3.new(0.15, 0.96, 0.96), CFrame.new(0.6, 2.3, 0), GOLD, metal, true)
end)
makeTool("GoldenCalculator", function(tool)
	toolPart(tool, "Body", Vector3.new(1.3, 1.9, 0.35), CFrame.new(0, 0.9, 0), GOLD, Enum.Material.Foil)
	local screen = Color3.fromRGB(70, 100, 70)
	toolPart(tool, "Screen", Vector3.new(1, 0.45, 0.05), CFrame.new(0, 1.5, -0.2), screen, Enum.Material.Neon)
	for row = 0, 2 do
		for key = -1, 1 do
			local cframe = CFrame.new(key * 0.35, 1.05 - row * 0.32, -0.2)
			toolPart(tool, "Key", Vector3.new(0.22, 0.22, 0.06), cframe, Color3.fromRGB(250, 240, 205))
		end
	end
end)

local pets = folder(assets, "Pets")
if pets:FindFirstChild("Default") == nil then
	local pet = Instance.new("Model")
	pet.Name = "Default"
	-- Parts with RarityTint take the pet's rarity colour in game.
	local function ball(name: string, size: number, position: Vector3, colour: Color3, tint: boolean): Part
		local part = newPart(pet, name, Vector3.new(size, size, size), CFrame.new(position), colour)
		part.Shape = Enum.PartType.Ball
		part.CanCollide = false
		if tint then
			part:SetAttribute("RarityTint", true)
		end
		return part
	end
	local fur, eye = Color3.fromRGB(200, 200, 200), Color3.fromRGB(25, 25, 30)
	pet.PrimaryPart = ball("Body", 2.4, Vector3.new(0, 1.2, 0), fur, true)
	ball("Belly", 1.6, Vector3.new(0, 1, -0.55), Color3.fromRGB(250, 245, 235), false)
	ball("EarLeft", 0.8, Vector3.new(-0.75, 2.3, 0), fur, true)
	ball("EarRight", 0.8, Vector3.new(0.75, 2.3, 0), fur, true)
	ball("EyeLeft", 0.4, Vector3.new(-0.45, 1.65, -1.02), eye, false)
	ball("EyeRight", 0.4, Vector3.new(0.45, 1.65, -1.02), eye, false)
	pet.Parent = pets
end

print("Map built")
