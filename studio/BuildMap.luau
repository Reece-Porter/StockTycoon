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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ACCENTS = {
	Color3.fromRGB(70, 140, 230),
	Color3.fromRGB(235, 120, 60),
	Color3.fromRGB(90, 190, 110),
	Color3.fromRGB(190, 100, 220),
	Color3.fromRGB(230, 190, 60),
	Color3.fromRGB(60, 190, 190),
	Color3.fromRGB(230, 90, 120),
	Color3.fromRGB(150, 150, 160),
}
local GROUND = Color3.fromRGB(215, 215, 222)
local PLATFORM = Color3.fromRGB(232, 232, 238)
local STEP = Color3.fromRGB(190, 190, 200)
local PLOT = Color3.fromRGB(150, 170, 200)
local DARK = Color3.fromRGB(60, 60, 70)
local GOLD = Color3.fromRGB(225, 185, 60)
local GLASS = Color3.fromRGB(185, 225, 245)
local CASH = Color3.fromRGB(60, 203, 90)

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
-- constants at the top).
for index, spot in BASE_SPOTS do
	local base = model(bases, "Base" .. index)
	local center = Vector3.new(spot.x, groundY + 0.5, spot.z)
	local turn = if center.X < 0 then CFrame.new() else CFrame.Angles(0, math.pi, 0)
	local frame = CFrame.new(center.X, 0, center.Z) * turn
	local function at(lx: number, ly: number, lz: number): CFrame
		return frame * CFrame.new(lx, ly, lz)
	end
	local accent = ACCENTS[(index - 1) % #ACCENTS + 1]
	local carpet = accent:Lerp(Color3.new(0, 0, 0), 0.3)
	local groundTop = groundY + 1
	local tops = { groundTop, groundTop + RISE, groundTop + 2 * RISE, groundTop + 3 * RISE }
	local halfWidth, halfDepth = BASE_WIDTH / 2, BASE_DEPTH / 2

	local floorPart = place(base, "Floor", Vector3.new(BASE_DEPTH, 1, BASE_WIDTH), at(0, groundY + 0.5, 0), GROUND)
	floorPart.Color = GROUND
	floorPart.Material = Enum.Material.SmoothPlastic

	-- The front yard.
	place(base, "Spawn", Vector3.new(6, 0.2, 6), at(27, groundTop + 0.1, 0), Color3.fromRGB(80, 200, 120))
	local conveyor = model(base, "Conveyor")
	place(conveyor, "Belt", Vector3.new(6, 1, 32), at(37, groundTop + 0.5, 0), Color3.fromRGB(60, 60, 60))
	hide(place(conveyor, "Start", Vector3.new(1, 1, 1), at(37, groundTop + 1.5, -16), Color3.fromRGB(0, 255, 0)))
	hide(place(conveyor, "End", Vector3.new(1, 1, 1), at(37, groundTop + 1.5, 16), Color3.fromRGB(255, 0, 0)))
	local machine = model(base, "Machine")
	local padColour = Color3.fromRGB(150, 80, 255)
	place(machine, "Pad", Vector3.new(6, 1, 6), at(27, groundTop + 0.5, -11), padColour, Enum.Material.Neon)
	place(machine, "PillarLeft", Vector3.new(1, 8, 1), at(23.5, groundTop + 4, -11), DARK)
	place(machine, "PillarRight", Vector3.new(1, 8, 1), at(30.5, groundTop + 4, -11), DARK)
	place(machine, "Top", Vector3.new(8, 1, 1), at(27, groundTop + 8.5, -11), DARK)
	local lockColour = Color3.fromRGB(220, 50, 50)
	place(base, "LockButton", Vector3.new(3, 1.2, 3), at(27, groundTop + 0.6, 11), lockColour, Enum.Material.Neon)

	-- The hall: plots in pairs either side of the walkway from the front back
	-- (so they unlock front to back), each turned to face the walkway with
	-- its cash pad in front, then the pet slots behind them. Everything that
	-- belongs to an upper floor is in its Floor folder, so the game can show
	-- each floor only once the owner has opened it.
	local floors = folder(base, "Floors")
	for n = 1, 4 do
		local floor = folder(floors, "Floor" .. n)
		local top = tops[n]
		if n > 1 then
			local hallSize = Vector3.new(HALL_FRONT - HALL_BACK, 1, BASE_WIDTH)
			local platform =
				place(floor, "Platform", hallSize, at((HALL_FRONT + HALL_BACK) / 2, top - 0.5, 0), PLATFORM)
			platform.Color = PLATFORM
			platform.Material = Enum.Material.SmoothPlastic
		end
		local plots = folder(floor, "Plots")
		local pads = folder(floor, "CollectPads")
		for i = 1, 10 do
			local side = if (i - 1) % 2 == 0 then -1 else 1
			local plotX = HALL_FRONT - 4.5 - math.floor((i - 1) / 2) * 9
			local facing = if side < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.new()
			place(plots, "Plot" .. i, Vector3.new(7, 0.4, 7), at(plotX, top + 0.2, side * PLOT_Z) * facing, PLOT)
			place(pads, "Pad" .. i, Vector3.new(5, 0.2, 3.5), at(plotX, top + 0.1, side * PAD_Z) * facing, CASH)
		end
		local slots = folder(floor, "PetSlots")
		for slot = 1, 2 do
			local slotColour = Color3.fromRGB(190, 150, 255)
			local slotZ = (if slot == 1 then -1 else 1) * SLOT_Z
			place(slots, "Slot" .. slot, Vector3.new(3, 0.4, 3), at(HALL_BACK + 4, top + 0.2, slotZ), slotColour)
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

	-- The walkway on every floor (from the street on the ground floor), a
	-- coloured border, and supports along the sides under each upper floor.
	-- The ground floor's are in Tidy, each upper floor's in its own Trim.
	local trim = freshModel(base, "Tidy")
	for n = 1, 4 do
		local parent = if n == 1 then trim else freshModel(folder(floors, "Floor" .. n), "Trim")
		local front = if n == 1 then halfDepth else HALL_FRONT
		local walkwaySize = Vector3.new(front - HALL_BACK, 0.1, WALKWAY)
		local walkway = newPart(parent, "Walkway", walkwaySize, at((front + HALL_BACK) / 2, tops[n] + 0.05, 0), carpet)
		walkway.Material = Enum.Material.Fabric
		walkway.CanCollide = false
		if n > 1 then
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
	-- its Floor folder.
	for n = 1, 4 do
		local glassParent = if n == 1 then base else folder(floors, "Floor" .. n)
		local glassWalls = freshModel(glassParent, "Glass")
		local glassTop = if n < 4 then tops[n + 1] else tops[4] + RAIL_HEIGHT
		local glassHeight = glassTop - tops[n]
		local glassY = tops[n] + glassHeight / 2
		local function glass(size: Vector3, cframe: CFrame)
			local pane = newPart(glassWalls, "Glass", size, cframe, GLASS, 0.6)
			pane.Material = Enum.Material.Glass
			pane.CastShadow = false
		end
		for _, side in { -1, 1 } do
			local length = HALL_FRONT + halfDepth
			glass(
				Vector3.new(length, glassHeight, 0.5),
				at((HALL_FRONT - halfDepth) / 2, glassY, side * (halfWidth - 0.25))
			)
		end
		glass(Vector3.new(0.5, glassHeight, BASE_WIDTH - 1), at(-halfDepth + 0.25, glassY, 0))
	end

	-- Stairs up to each floor behind the hall. Floors 2 and 4 go up one
	-- strip towards +z and floor 3 comes back up the other, each from a
	-- landing to a landing that meets the back of the floor it serves.
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
				newPart(access, "Step", Vector3.new(6, height, tread), at(stairX, groundTop + height / 2, z), STEP)
			else
				newPart(access, "Step", Vector3.new(6, 1, tread), at(stairX, stepTop - 0.5, z), STEP)
			end
		end
		-- The landing at the top, across both strips; the glass walls guard
		-- its outside. Until the next floor is open there are no stairs on
		-- from it, so the other strip is railed off (TopOnly, which the game
		-- shows only on the highest open floor).
		local landingZ = dir * (LANDING_Z + halfWidth) / 2
		if n == 2 then
			local height = high - groundTop
			local size = Vector3.new(landingWidth, height, landingLength)
			newPart(access, "TopLanding", size, at(landingX, groundTop + height / 2, landingZ), STEP)
		else
			local size = Vector3.new(landingWidth, 1, landingLength)
			newPart(access, "TopLanding", size, at(landingX, high - 0.5, landingZ), PLATFORM)
		end
		local railY = high + RAIL_HEIGHT / 2
		local topOnly = freshModel(floor, "TopOnly")
		local across = at(STAIRS_X[if n % 2 == 0 then 2 else 1], railY, dir * (LANDING_Z + 0.25))
		newPart(topOnly, "LandingRail", Vector3.new(6, RAIL_HEIGHT, 0.5), across, accent, 0.35)
		-- Sloping handrails on both sides the full length of the stairs,
		-- standing on the line of the step edges, so they meet the landings
		-- with no gap. Stairs off the ground get an underside.
		local length = math.sqrt(RUN * RUN + rise * rise)
		local tilt = -dir * math.atan2(rise, RUN)
		local slope = at(stairX, (low + high) / 2, bottomZ + dir * RUN / 2) * CFrame.Angles(tilt, 0, 0)
		for _, railX in { -2.75, 2.75 } do
			local cframe = slope * CFrame.new(railX, RAIL_HEIGHT / 2, 0)
			newPart(access, "Handrail", Vector3.new(0.5, RAIL_HEIGHT, length), cframe, accent, 0.35)
		end
		if n > 2 then
			newPart(access, "Underside", Vector3.new(6, 0.6, length - 1), slope * CFrame.new(0, -1.3, 0), STEP)
		end
	end

	-- Railings along the front of the upper floors and at the back, open onto
	-- the landing each floor's stairs arrive at. The glass walls guard the
	-- sides.
	for n = 2, 4 do
		local floor = folder(floors, "Floor" .. n)
		local railings = freshModel(floor, "Railings")
		local y = tops[n] + RAIL_HEIGHT / 2
		local function rail(size: Vector3, railX: number, z: number)
			newPart(railings, "Rail", size, at(railX, y, z), accent, 0.35)
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
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder up
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
		for column = -1, 1 do
			local cframe = CFrame.new(column * 0.35, 1.05 - row * 0.32, -0.2)
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
