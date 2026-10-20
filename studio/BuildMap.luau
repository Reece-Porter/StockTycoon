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

-- Eight bases, four either side of the middle conveyor, all facing it. Each
-- is 60 studs square, with BASE_GAP between neighbours so a player pushed out
-- of a locked base (Config/Steal.LockPushMargin) lands clear of the next one.
-- The middle four come first, so they fill first; Base1 faces Base2.
local BASE_SIZE = 60
local BASE_GAP = 12
local BASE_STEP = BASE_SIZE + BASE_GAP
local BASE_SPOTS = {
	{ x = -60, z = -BASE_STEP / 2 },
	{ x = 60, z = -BASE_STEP / 2 },
	{ x = -60, z = BASE_STEP / 2 },
	{ x = 60, z = BASE_STEP / 2 },
	{ x = -60, z = -BASE_STEP * 1.5 },
	{ x = 60, z = -BASE_STEP * 1.5 },
	{ x = -60, z = BASE_STEP * 1.5 },
	{ x = 60, z = BASE_STEP * 1.5 },
}
-- From the middle of the map to the far edge of the end bases.
local ROW_HALF = BASE_STEP * 1.5 + BASE_SIZE / 2
-- The leaderboards stand across the end of the street between the bases.
local BOARDS_Z = -(ROW_HALF + 10)
local RISE = 12 -- height between floors
local RAIL_HEIGHT = 3
local RUN = 21 -- length of every staircase
local BELT_LENGTH = 192 -- the middle conveyor

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
-- down the middle between the two rows of bases, under the middle conveyor,
-- the shops and the leaderboards. It sits a tenth of a stud above the grass so
-- the two never flicker.
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
	Vector3.new(60, 1, 2 * math.max(BELT_LENGTH / 2 + 4, -BOARDS_Z + 4)),
	CFrame.new(0, groundY - 0.4, 0),
	Color3.fromRGB(196, 190, 178),
	Enum.Material.Pavement
)
plaza.Color = Color3.fromRGB(196, 190, 178)
plaza.Material = Enum.Material.Pavement

local bases = folder(map, "Bases")

-- 2. The bases. Each is laid out the same way in its own frame, where x
-- points towards the middle of the map: the conveyor on the near side, the
-- floors of plots on the far side, stairs in between.
for index, spot in BASE_SPOTS do
	local base = model(bases, "Base" .. index)
	local center = Vector3.new(spot.x, groundY + 0.5, spot.z)
	local turn = if center.X < 0 then CFrame.new() else CFrame.Angles(0, math.pi, 0)
	local frame = CFrame.new(center.X, 0, center.Z) * turn
	local function at(lx: number, ly: number, lz: number): CFrame
		return frame * CFrame.new(lx, ly, lz)
	end
	local accent = ACCENTS[(index - 1) % #ACCENTS + 1]
	local groundTop = groundY + 1
	local tops = { groundTop, groundTop + RISE, groundTop + 2 * RISE, groundTop + 3 * RISE }

	local floorPart = place(base, "Floor", Vector3.new(60, 1, 60), at(0, groundY + 0.5, 0), GROUND)
	floorPart.Color = GROUND
	floorPart.Material = Enum.Material.SmoothPlastic
	place(base, "Spawn", Vector3.new(6, 0.2, 6), at(0, groundTop + 0.1, 0), Color3.fromRGB(80, 200, 120))
	local conveyor = model(base, "Conveyor")
	place(conveyor, "Belt", Vector3.new(6, 1, 40), at(20, groundTop + 0.5, 0), Color3.fromRGB(60, 60, 60))
	hide(place(conveyor, "Start", Vector3.new(1, 1, 1), at(20, groundTop + 1.5, -20), Color3.fromRGB(0, 255, 0)))
	hide(place(conveyor, "End", Vector3.new(1, 1, 1), at(20, groundTop + 1.5, 20), Color3.fromRGB(255, 0, 0)))
	local machine = model(base, "Machine")
	local padColour = Color3.fromRGB(150, 80, 255)
	place(machine, "Pad", Vector3.new(6, 1, 6), at(6, groundTop + 0.5, -22), padColour, Enum.Material.Neon)
	place(machine, "PillarLeft", Vector3.new(1, 8, 1), at(2.5, groundTop + 4, -22), DARK)
	place(machine, "PillarRight", Vector3.new(1, 8, 1), at(9.5, groundTop + 4, -22), DARK)
	place(machine, "Top", Vector3.new(8, 1, 1), at(6, groundTop + 8.5, -22), DARK)
	local lockColour = Color3.fromRGB(220, 50, 50)
	place(base, "LockButton", Vector3.new(3, 1.2, 3), at(6, groundTop + 0.6, 12), lockColour, Enum.Material.Neon)

	local floors = folder(base, "Floors")
	for n = 1, 4 do
		local floor = folder(floors, "Floor" .. n)
		local top = tops[n]
		if n > 1 then
			local platform = place(floor, "Platform", Vector3.new(26, 1, 60), at(-17, top - 0.5, 0), PLATFORM)
			platform.Color = PLATFORM
			platform.Material = Enum.Material.SmoothPlastic
		end
		local plots = folder(floor, "Plots")
		for i = 1, 10 do
			local plotX = -22 + ((i - 1) % 2) * 9
			local plotZ = -18 + math.floor((i - 1) / 2) * 9
			place(plots, "Plot" .. i, Vector3.new(7, 0.4, 7), at(plotX, top + 0.2, plotZ), PLOT)
		end
		local slots = folder(floor, "PetSlots")
		for slot = 1, 2 do
			local slotColour = Color3.fromRGB(190, 150, 255)
			place(slots, "Slot" .. slot, Vector3.new(3, 0.4, 3), at(-6.5, top + 0.2, -18 + (slot - 1) * 9), slotColour)
		end
	end
	if base:IsA("Model") then
		base.WorldPivot = at(0, groundTop, 0)
	end
	if conveyor:IsA("Model") then
		conveyor.WorldPivot = at(20, groundTop + 0.5, 0)
	end
	if machine:IsA("Model") then
		machine.WorldPivot = at(6, groundTop + 0.5, -22)
	end

	-- A coloured border, and supports along the outside edge of the floors.
	local trim = freshModel(base, "Tidy")
	for _, side in { -1, 1 } do
		newPart(trim, "Border", Vector3.new(60, 0.1, 1), at(0, groundTop + 0.05, side * 29.5), accent).CanCollide =
			false
		newPart(trim, "Border", Vector3.new(1, 0.1, 58), at(side * 29.5, groundTop + 0.05, 0), accent).CanCollide =
			false
	end
	for _, z in { -29.5, 0, 29.5 } do
		local height = tops[4] - groundTop
		newPart(trim, "Support", Vector3.new(1, height, 1), at(-29.5, groundTop + height / 2, z), accent)
	end

	-- Stairs up to each floor, in the strip between the floors and the open
	-- part of the base. They alternate ends, so each staircase starts next to
	-- the floor below and finishes next to the floor it serves.
	for n = 2, 4 do
		local floor = folder(floors, "Floor" .. n)
		local low, high = tops[n - 1], tops[n]
		local access = freshModel(floor, "Access")
		local dir = if n % 2 == 0 then 1 else -1
		local rise = high - low
		local steps = math.max(1, math.floor(rise + 0.5))
		local stepRise, tread = rise / steps, RUN / steps
		local bottomZ = 4 * dir
		for k = 1, steps do
			local stepTop = low + k * stepRise
			local z = bottomZ + dir * (k - 0.5) * tread
			if n == 2 then
				local height = stepTop - groundTop
				newPart(access, "Step", Vector3.new(6, height, tread), at(-1, groundTop + height / 2, z), STEP)
			else
				newPart(access, "Step", Vector3.new(6, 1, tread), at(-1, stepTop - 0.5, z), STEP)
			end
		end
		-- Landings: at the bottom (upper floors only) and the top. A bottom
		-- landing runs from just past the middle of the base to the first
		-- step, with its end rail past the doorway onto the floor.
		if n > 2 then
			newPart(access, "BottomLanding", Vector3.new(6, 1, 4.5), at(-1, low - 0.5, 1.75 * dir), PLATFORM)
			local side = at(1.75, low + RAIL_HEIGHT / 2, 1.75 * dir)
			newPart(access, "LandingRail", Vector3.new(0.5, RAIL_HEIGHT, 4.5), side, accent, 0.35)
			local finish = at(-1, low + RAIL_HEIGHT / 2, -0.25 * dir)
			newPart(access, "LandingRail", Vector3.new(6, RAIL_HEIGHT, 0.5), finish, accent, 0.35)
		end
		local topStart = bottomZ + dir * RUN
		local topLength = 30 - math.abs(topStart)
		local topZ = topStart + dir * topLength / 2
		if n == 2 then
			local height = high - groundTop
			newPart(access, "TopLanding", Vector3.new(6, height, topLength), at(-1, groundTop + height / 2, topZ), STEP)
		else
			newPart(access, "TopLanding", Vector3.new(6, 1, topLength), at(-1, high - 0.5, topZ), PLATFORM)
		end
		local topSide = at(1.75, high + RAIL_HEIGHT / 2, topZ)
		newPart(access, "LandingRail", Vector3.new(0.5, RAIL_HEIGHT, topLength), topSide, accent, 0.35)
		local topEnd = at(-1, high + RAIL_HEIGHT / 2, 29.75 * dir)
		newPart(access, "LandingRail", Vector3.new(6, RAIL_HEIGHT, 0.5), topEnd, accent, 0.35)
		-- Sloping handrails on both sides, standing on the line of the step
		-- edges and stopping short of each end (more at the bottom, where
		-- they lean) so they never reach into a landing. Stairs off the ground
		-- get an underside.
		local length = math.sqrt(RUN * RUN + rise * rise)
		local tilt = -dir * math.atan2(rise, RUN)
		local slope = at(0, (low + high) / 2, bottomZ + dir * RUN / 2) * CFrame.Angles(tilt, 0, 0)
		for _, railX in { -3.75, 1.75 } do
			local cframe = slope * CFrame.new(railX, RAIL_HEIGHT / 2, 0.75 * dir)
			newPart(access, "Handrail", Vector3.new(0.5, RAIL_HEIGHT, length - 3.5), cframe, accent, 0.35)
		end
		if n > 2 then
			newPart(access, "Underside", Vector3.new(6, 0.6, length - 1), slope * CFrame.new(-1, -1.3, 0), STEP)
		end
	end

	-- Railings round the upper floors, with openings onto the stairs.
	for n = 2, 4 do
		local floor = folder(floors, "Floor" .. n)
		local railings = freshModel(floor, "Railings")
		local y = tops[n] + RAIL_HEIGHT / 2
		local function rail(size: Vector3, railX: number, z: number)
			newPart(railings, "Rail", size, at(railX, y, z), accent, 0.35)
		end
		rail(Vector3.new(0.5, RAIL_HEIGHT, 60), -29.75, 0)
		rail(Vector3.new(26, RAIL_HEIGHT, 0.5), -17, 29.75)
		rail(Vector3.new(26, RAIL_HEIGHT, 0.5), -17, -29.75)
		-- On the inside edge: openings where the stairs up to this floor
		-- arrive, and where the stairs to the next floor start.
		local arrive = if n % 2 == 0 then 1 else -1
		local openings = { { math.min(25 * arrive, 30 * arrive), math.max(25 * arrive, 30 * arrive) } }
		if n < 4 then
			local nextDir = if (n + 1) % 2 == 0 then 1 else -1
			table.insert(openings, { math.min(0, 4 * nextDir), math.max(0, 4 * nextDir) })
		end
		table.sort(openings, function(a, b)
			return a[1] < b[1]
		end)
		local from = -30
		for _, opening in openings do
			if opening[1] > from then
				rail(Vector3.new(0.5, RAIL_HEIGHT, opening[1] - from), -4.25, (from + opening[1]) / 2)
			end
			from = opening[2]
		end
		if from < 30 then
			rail(Vector3.new(0.5, RAIL_HEIGHT, 30 - from), -4.25, (from + 30) / 2)
		end
	end
end

-- 3. The middle conveyor between the bases, resting on the ground.
local shared = model(map, "SharedConveyor")
local beltColour = Color3.fromRGB(200, 160, 40)
place(shared, "Belt", Vector3.new(8, 2, BELT_LENGTH), CFrame.new(0, groundY + 1, 0), beltColour)
local beltEnd = BELT_LENGTH / 2 - 2
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

-- 5. The shops, either side of the middle conveyor. An existing shop is moved
-- into place; a missing one is built there.
type ShopStyle = {
	x: number,
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
		x = -18,
		counter = Color3.fromRGB(150, 95, 55),
		prompt = GOLD,
		promptMaterial = Enum.Material.Metal,
		wall = Color3.fromRGB(60, 60, 75),
		roof = Color3.fromRGB(230, 120, 40),
		sign = "WEAPONS",
		signColour = Color3.fromRGB(255, 220, 90),
	},
	PetShop = {
		x = 18,
		counter = Color3.fromRGB(240, 235, 225),
		prompt = Color3.fromRGB(190, 150, 255),
		promptMaterial = Enum.Material.Neon,
		wall = Color3.fromRGB(70, 60, 95),
		roof = Color3.fromRGB(60, 180, 170),
		sign = "PETS",
		signColour = Color3.fromRGB(190, 150, 255),
	},
}
local shops = folder(map, "Shops")
for name, style in shopStyles do
	local shop = shops:FindFirstChild(name)
	local shopFloor = shop and shop:FindFirstChild("Floor")
	if shop and shopFloor and shopFloor:IsA("BasePart") then
		local shift = Vector3.new(style.x, 0, 40) - shopFloor.CFrame.Position * Vector3.new(1, 0, 1)
		for _, part in shop:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = part.CFrame + shift
			end
		end
	else
		if shop then
			shop:Destroy()
		end
		local newShop = Instance.new("Model")
		newShop.Name = name
		local cx, cz, y = style.x, 40, groundY
		local function block(blockName: string, size: Vector3, bx: number, bottom: number, bz: number, colour: Color3)
			return newPart(newShop, blockName, size, CFrame.new(bx, bottom + size.Y / 2, bz), colour)
		end
		block("Floor", Vector3.new(14, 0.4, 9), cx, y, cz, Color3.fromRGB(95, 95, 105))
		block("Counter", Vector3.new(10, 3, 2), cx, y + 0.4, cz - 2, style.counter)
		block("ShopPrompt", Vector3.new(2, 1, 1.2), cx, y + 3.4, cz - 2, style.prompt).Material = style.promptMaterial
		block("BackWall", Vector3.new(14, 9, 1), cx, y + 0.4, cz + 4, style.wall)
		block("PostLeft", Vector3.new(0.8, 8.4, 0.8), cx - 6.5, y + 0.4, cz - 4, Color3.fromRGB(230, 230, 235))
		block("PostRight", Vector3.new(0.8, 8.4, 0.8), cx + 6.5, y + 0.4, cz - 4, Color3.fromRGB(230, 230, 235))
		block("Roof", Vector3.new(15, 0.8, 10), cx, y + 8.8, cz, style.roof)
		local sign = block("Sign", Vector3.new(11, 2.2, 0.4), cx, y + 9.6, cz - 4.6, Color3.fromRGB(35, 35, 45))
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
		newShop.Parent = shops
	end
end

-- 6. The leaderboards, in a row across the end of the street between the
-- bases, facing up it. The game writes the lists on each board's front face.
local leaderboards = folder(map, "Leaderboards")
local stands = freshModel(leaderboards, "Stands")
local boardSpots = {
	{ name = "IncomeBoard", x = -24 },
	{ name = "RebirthsBoard", x = -12 },
	{ name = "StealsBoard", x = 12 },
	{ name = "KnockoutsBoard", x = 24 },
}
for _, spot in boardSpots do
	-- Turned so the front face points at the middle of the map.
	local facing = CFrame.new(spot.x, groundY + 8, BOARDS_Z) * CFrame.Angles(0, math.pi, 0)
	place(leaderboards, spot.name, Vector3.new(10, 12, 1), facing, Color3.fromRGB(20, 22, 30))
	newPart(stands, spot.name .. "Back", Vector3.new(11, 13, 0.6), facing * CFrame.new(0, 0.5, 0.8), GOLD)
	newPart(
		stands,
		spot.name .. "Plinth",
		Vector3.new(11, 2, 2.2),
		CFrame.new(spot.x, groundY + 1, BOARDS_Z - 0.3),
		DARK
	)
end

-- 7. Models the game copies: the Default company, the weapon Tools and the
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
