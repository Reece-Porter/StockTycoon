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

-- Which build of the map this script makes. The game warns admins when the
-- map in the place is from an older build (Config/Base.MapVersion), so bump
-- both together whenever this file changes what it builds.
local MAP_VERSION = 3

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
local BASE_WIDTH = 42
local BASE_DEPTH = 96
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
-- has the conveyor, the Valuation Machine and the spawn. In the hall behind
-- it a walkway runs straight back down the middle of every floor, with five
-- plots either side near the walls, each with a cash pad in front of it by
-- the walkway, and a lock button in the middle of the walkway. The stairs
-- zigzag up behind the hall in two strips, meeting landings at either side.
local HALL_FRONT = 24
local HALL_BACK = -36
local WALKWAY = 10
local PLOT_STEP = 10 -- between pairs of plots along the walkway
local PLOT_Z = 14 -- plots either side of the walkway, near the walls
local PAD_Z = 7.5 -- cash pads, between the walkway and the plots
local SLOT_Z = 13 -- pet slots at the back of the hall
local LOCK_X = (HALL_FRONT + HALL_BACK) / 2 -- the lock button, between the middle plots
local STAIRS_X = { -39, -45 } -- floors 2 and 4 go up one strip, floor 3 the other
local LANDING_Z = 10.5 -- where every staircase starts and ends
-- The front yard: the spawn on the walkway with the machine to one side,
-- and the personal conveyor across the front.
local YARD_X = 31
local MACHINE_Z = -12
local BELT_X = BASE_DEPTH / 2 - 6
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

-- A decorative stretched ball: a block with a sphere mesh, since a Ball
-- part is always round.
local function ellipsoid(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	colour: Color3,
	material: Enum.Material?
): Part
	local part = decor(parent, name, size, cframe, colour, material)
	local round = Instance.new("SpecialMesh")
	round.MeshType = Enum.MeshType.Sphere
	round.Parent = part
	return part
end

-- Marks a part as a market screen the client draws on (MarketScreensController):
-- a ticker of companies sliding past, a moving chart, or a base owner's quote.
-- faces lists the part's faces it shows on; distance is how near the camera
-- must be for it to move.
local SCREEN_TAG = "MarketScreen"
local function screen(part: BasePart, kind: "Ticker" | "Chart" | "Quote" | "Ad", faces: string, distance: number)
	part:SetAttribute("ScreenKind", kind)
	part:SetAttribute("ScreenFaces", faces)
	part:SetAttribute("ScreenDistance", distance)
	part:AddTag(SCREEN_TAG)
end

-- Fixed words on one face of a part, in the game's display font.
local function caption(part: BasePart, face: Enum.NormalId, text: string, colour: Color3, pixelsPerStud: number)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Caption"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Theme.Fonts.Display
	label.TextScaled = true
	label.TextColor3 = colour
	label.Text = text
	label.Parent = gui
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
	local spawn = place(base, "Spawn", Vector3.new(6, 0.2, 6), at(YARD_X, groundTop + 0.1, 0), BASE.Plot)
	spawn.Transparency = 1
	clearDecor(spawn)
	column(spawn, "SpawnRing", 0.14, 6.6, at(YARD_X, groundTop + 0.07, 0), accent, Enum.Material.Neon)
	column(spawn, "SpawnDisc", 0.2, 6, at(YARD_X, groundTop + 0.1, 0), BASE.Plot)
	local spawnGlow = column(spawn, "SpawnGlow", 4, 5, at(YARD_X, groundTop + 2.2, 0), accent, Enum.Material.Neon)
	spawnGlow.Transparency = 0.88
	spawnGlow.CastShadow = false

	-- The personal conveyor: the belt between side rails with a roller at
	-- the far end, and a hatch over the start whose door the client opens
	-- when a company comes out. The client also runs chevrons along it.
	local conveyor = model(base, "Conveyor")
	local belt = place(conveyor, "Belt", Vector3.new(6, 1, 32), at(BELT_X, groundTop + 0.5, 0), BASE.Belt)
	belt.Color = BASE.Belt
	belt.Material = Enum.Material.SmoothPlastic
	hide(place(conveyor, "Start", Vector3.new(1, 1, 1), at(BELT_X, groundTop + 1.5, -16), Color3.fromRGB(0, 255, 0)))
	hide(place(conveyor, "End", Vector3.new(1, 1, 1), at(BELT_X, groundTop + 1.5, 16), Color3.fromRGB(255, 0, 0)))
	local beltLook = freshModel(conveyor, "Look")
	for _, side in { -1, 1 } do
		decor(
			beltLook,
			"Rail",
			Vector3.new(0.4, 1.3, 32),
			at(BELT_X + side * 3.2, groundTop + 0.65, 0),
			Theme.shade(accent, 0.2)
		)
	end
	decor(
		beltLook,
		"Roller",
		Vector3.new(6.4, 1.1, 1.1),
		at(BELT_X, groundTop + 0.55, 16),
		BASE.Roller,
		nil,
		Enum.PartType.Cylinder
	)
	local hatch = freshModel(conveyor, "Hatch")
	decor(hatch, "Back", Vector3.new(7.2, 6.6, 0.4), at(BELT_X, groundTop + 3.3, -17.8), BASE.Housing)
	for _, side in { -1, 1 } do
		local sideAt = at(BELT_X + side * 3.4, groundTop + 3.3, -16.6)
		decor(hatch, "Side", Vector3.new(0.4, 6.6, 2.4), sideAt, BASE.Housing)
	end
	decor(hatch, "Roof", Vector3.new(7.2, 0.5, 2.8), at(BELT_X, groundTop + 6.85, -16.6), BASE.Housing)
	local stripeAt = at(BELT_X, groundTop + 6.5, -15.25)
	decor(hatch, "Stripe", Vector3.new(7.3, 0.25, 0.2), stripeAt, accent, Enum.Material.Neon)
	decor(hatch, "Door", Vector3.new(6.2, 5.6, 0.2), at(BELT_X, groundTop + 3.8, -15.3), Theme.shade(accent, 0.15))

	-- The Valuation Machine, facing the walkway: a round stage under a glass
	-- tube where the company stands (on the invisible Pad the game uses),
	-- between two pillars with gauges and lights, under an arch with the
	-- machine's name and a ticker, topped by a big screen. The client draws
	-- the chart and the ticker and chases the lights, and while the owner's
	-- run is going it sweeps a scanner up and down the tube, swings the
	-- gauges and flashes the beacon.
	local machine = model(base, "Machine")
	local pad = place(machine, "Pad", Vector3.new(6, 1, 6), at(YARD_X, groundTop + 0.5, MACHINE_Z), BASE.MachinePad)
	pad.Transparency = 1
	for _, child in machine:GetChildren() do
		if child ~= pad then
			child:Destroy()
		end
	end
	local function onMachine(lx: number, ly: number, lz: number): CFrame
		return at(YARD_X + lx, groundTop + ly, MACHINE_Z + lz)
	end
	-- Turns a part so its Right face looks at the walkway, for the screens
	-- the client draws on and the gauges.
	local toWalkway = CFrame.Angles(0, -math.pi / 2, 0)
	local glow: Color3 = BASE.MachinePad
	column(machine, "Stage", 0.8, 8, onMachine(0, 0.4, 0), BASE.Machine)
	column(machine, "StageTrim", 0.16, 8.3, onMachine(0, 0.72, 0), accent, Enum.Material.Neon)
	column(machine, "PadGlow", 0.2, 5.6, onMachine(0, 0.88, 0), glow, Enum.Material.Neon)
	local tube = column(machine, "Tube", 7.2, 6.2, onMachine(0, 4.6, 0), BASE.Glass, Enum.Material.Glass)
	tube.Transparency = 0.82
	tube.CastShadow = false
	column(machine, "TubeRing", 0.2, 6.5, onMachine(0, 8.1, 0), glow, Enum.Material.Neon)
	column(machine, "TubeCap", 0.8, 6.9, onMachine(0, 8.6, 0), BASE.Machine)
	column(machine, "Neck", 0.6, 2.2, onMachine(0, 9.3, 0), accent)
	local scanner = column(machine, "Scanner", 0.06, 5.9, onMachine(0, 1.3, 0), glow, Enum.Material.Neon)
	scanner.Transparency = 1
	scanner.CastShadow = false
	for _, side in { -1, 1 } do
		local x = side * 5
		decor(machine, "Pillar", Vector3.new(1.6, 9.6, 2.4), onMachine(x, 4.8, 0), BASE.Machine)
		for _, y in { 1.2, 8.4 } do
			decor(machine, "Band", Vector3.new(1.7, 0.3, 2.5), onMachine(x, y, 0), accent)
		end
		for k = 1, 3 do
			local where = onMachine(x, 2.6 + k * 1.1, 1.25)
			decor(machine, "Light", Vector3.new(0.5, 0.5, 0.2), where, Theme.Colours.Cash, Enum.Material.Neon)
		end
		-- A gauge with a needle the client swings.
		local bezel = onMachine(x, 7.1, 1.21) * toWalkway
		decor(machine, "Bezel", Vector3.new(0.1, 1.5, 1.5), bezel, accent, nil, Enum.PartType.Cylinder)
		local face = onMachine(x, 7.1, 1.26) * toWalkway
		decor(machine, "Gauge", Vector3.new(0.12, 1.3, 1.3), face, BASE.Post, nil, Enum.PartType.Cylinder)
		decor(machine, "Needle", Vector3.new(0.08, 0.55, 0.06), onMachine(x, 7.375, 1.36), Theme.Colours.Ink)
	end
	decor(machine, "Arch", Vector3.new(11.6, 2, 2.6), onMachine(0, 10.6, 0), BASE.Machine)
	decor(machine, "ArchTrim", Vector3.new(11.8, 0.25, 2.7), onMachine(0, 9.65, 0), accent)
	local header =
		decor(machine, "Header", Vector3.new(0.1, 1.1, 10.6), onMachine(0, 11, 1.32) * toWalkway, BASE.Machine)
	local headerGui = Instance.new("SurfaceGui")
	headerGui.Name = "Name"
	headerGui.Face = Enum.NormalId.Right
	headerGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	headerGui.PixelsPerStud = 30
	headerGui.LightInfluence = 0
	headerGui.MaxDistance = 120
	headerGui.Parent = header
	local headerText = Instance.new("TextLabel")
	headerText.Size = UDim2.fromScale(1, 1)
	headerText.BackgroundTransparency = 1
	headerText.Font = Theme.Fonts.Display
	headerText.TextScaled = true
	headerText.TextColor3 = Theme.Colours.Gold
	headerText.Text = "VALUATION MACHINE"
	headerText.Parent = headerGui
	decor(machine, "Ticker", Vector3.new(0.1, 0.65, 10.6), onMachine(0, 10.05, 1.32) * toWalkway, Theme.Colours.Ink)
	decor(machine, "ScreenFrame", Vector3.new(0.4, 5, 10), onMachine(0, 14.1, 0) * toWalkway, accent)
	decor(machine, "Screen", Vector3.new(0.2, 4.4, 9.4), onMachine(0, 14.1, 0.15) * toWalkway, Theme.Colours.Ink)
	decor(
		machine,
		"Beacon",
		Vector3.new(1, 1, 1),
		onMachine(0, 17, 0),
		Theme.shade(Theme.Colours.Cash, 0.6),
		Enum.Material.Neon,
		Enum.PartType.Ball
	)

	-- Across the yard from the machine, the base's stock quote: a board the
	-- client fills with the owner's ticker symbol, their Cash per second and
	-- how it has moved lately, facing the walkway.
	local oldPlanter = base:FindFirstChild("Planter")
	if oldPlanter then
		oldPlanter:Destroy()
	end
	local quote = freshModel(base, "Quote")
	local quoteAt = at(YARD_X, groundTop, 13)
	local quoteScreen =
		decor(quote, "QuoteScreen", Vector3.new(6.4, 3.6, 0.2), quoteAt * CFrame.new(0, 4.4, 0), Theme.Colours.Ink)
	screen(quoteScreen, "Quote", "Front", 90)
	decor(quote, "QuoteFrame", Vector3.new(6.9, 4.1, 0.3), quoteAt * CFrame.new(0, 4.4, 0.2), accent)
	local headerAt = quoteAt * CFrame.new(0, 6.85, 0.2)
	local quoteHeader = decor(quote, "QuoteHeader", Vector3.new(6.9, 0.8, 0.35), headerAt, BASE.Machine)
	caption(quoteHeader, Enum.NormalId.Front, "SHARE PRICE", Theme.Colours.Gold, 30)
	for _, side in { -1, 1 } do
		decor(quote, "QuoteLeg", Vector3.new(0.35, 2.6, 0.35), quoteAt * CFrame.new(side * 2.6, 1.3, 0.2), BASE.Machine)
		decor(quote, "QuoteFoot", Vector3.new(1.2, 0.2, 1.2), quoteAt * CFrame.new(side * 2.6, 0.1, 0.2), BASE.Machine)
	end

	-- The headquarters sign over the way in; the client writes the owner's
	-- name on its panel.
	local signX = halfDepth - 1.5
	local signPostZ = halfWidth - 1.2
	local sign = freshModel(base, "Sign")
	for _, side in { -1, 1 } do
		column(sign, "Post", 10.4, 0.9, at(signX, groundTop + 5.2, side * signPostZ), accent)
		decor(
			sign,
			"PostCap",
			Vector3.new(1.3, 1.3, 1.3),
			at(signX, groundTop + 10.65, side * signPostZ),
			BASE.Post,
			nil,
			Enum.PartType.Ball
		)
	end
	decor(sign, "Board", Vector3.new(0.6, 3.4, 2 * signPostZ), at(signX, groundTop + 9.2, 0), accent)
	decor(sign, "Panel", Vector3.new(0.7, 2.6, 2 * signPostZ - 2), at(signX, groundTop + 9.2, 0), BASE.SignPanel)
	-- A ticker of companies sliding past under the sign, both ways.
	local signTicker = decor(
		sign,
		"Ticker",
		Vector3.new(0.6, 0.8, 2 * signPostZ - 1.6),
		at(signX, groundTop + 7, 0),
		Theme.Colours.Ink
	)
	screen(signTicker, "Ticker", "Right,Left", 150)

	-- The lock's force field across the way in, hidden until the base is
	-- locked (the client shows it, with the time left). It stops nobody: the
	-- game moves people out of a locked base itself.
	local gate = freshModel(base, "Gate")
	local field = decor(
		gate,
		"Field",
		Vector3.new(0.3, 10, BASE_WIDTH - 1),
		at(halfDepth - 0.4, groundTop + 5, 0),
		Theme.World.Locked,
		Enum.Material.ForceField
	)
	field.Transparency = 1
	field.CastShadow = false

	-- The lock button used to stand in the yard; it's on every floor now.
	local oldButton = base:FindFirstChild("LockButton")
	if oldButton then
		oldButton:Destroy()
	end

	-- The hall: plots in pairs either side of the walkway from the front back
	-- (so they unlock front to back), each turned to face the walkway with
	-- its cash pad in front, then the pet slots behind them. Everything that
	-- belongs to an upper floor is in its Floor folder, so the game can show
	-- each floor only once the owner has opened it. Each plot is a display
	-- stand: a white top on a darker lip with a glow in the accent colour
	-- between them (the game turns locked ones to stone). Each pet slot is a
	-- cushioned bed on a short pedestal. Each floor's lock button stands on a
	-- podium in the middle of the walkway, over the invisible LockButton the
	-- game uses (the client labels the podium, draws a padlock on the cap and
	-- holds it down while the base is locked).
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
			local plotX = HALL_FRONT - 5 - math.floor((i - 1) / 2) * PLOT_STEP
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
		local lockAt = at(LOCK_X, top, 0)
		-- As tall as the railings, so the top floor's stays inside the base.
		local buttonSize = Vector3.new(2.4, RAIL_HEIGHT, 2.4)
		local buttonAt = lockAt * CFrame.new(0, RAIL_HEIGHT / 2, 0)
		local lockButton = place(floor, "LockButton", buttonSize, buttonAt, BASE.LockCap)
		lockButton.Transparency = 1
		lockButton.CanCollide = true
		clearDecor(lockButton)
		column(lockButton, "Foot", 0.25, 3, lockAt * CFrame.new(0, 0.125, 0), BASE.Machine)
		decor(lockButton, "Pillar", Vector3.new(1.6, 2.1, 1.6), lockAt * CFrame.new(0, 1.3, 0), BASE.Housing)
		local stripeSize = Vector3.new(1.7, 0.2, 1.7)
		decor(lockButton, "Stripe", stripeSize, lockAt * CFrame.new(0, 2.2, 0), accent, Enum.Material.Neon)
		column(lockButton, "Plate", 0.25, 2.6, lockAt * CFrame.new(0, 2.475, 0), BASE.Machine)
		column(lockButton, "Rim", 0.12, 2.3, lockAt * CFrame.new(0, 2.66, 0), BASE.LockCap, Enum.Material.Neon)
		column(lockButton, "Cap", 0.35, 2, lockAt * CFrame.new(0, 2.775, 0), BASE.LockCap)
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
			local cushionAt = where * CFrame.new(0, 0.4, 0)
			ellipsoid(slotPart, "Cushion", Vector3.new(2.5, 0.2, 2.5), cushionAt, BASE.Cushion, Enum.Material.Fabric)
		end
	end
	if base:IsA("Model") then
		base.WorldPivot = at(0, groundTop, 0)
	end
	if conveyor:IsA("Model") then
		conveyor.WorldPivot = at(BELT_X, groundTop + 0.5, 0)
	end
	if machine:IsA("Model") then
		machine.WorldPivot = at(YARD_X, groundTop + 0.5, MACHINE_Z)
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
		local edgeFront = if n == 1 then BELT_X - 3.5 else HALL_FRONT
		local edgeSize = Vector3.new(edgeFront - HALL_BACK, 0.12, 0.4)
		for _, side in { -1, 1 } do
			local where = at((edgeFront + HALL_BACK) / 2, tops[n] + 0.06, side * (WALKWAY / 2 - 0.2))
			decor(parent, "CarpetEdge", edgeSize, where, BASE.Post, Enum.Material.Fabric)
		end
		-- A candlestick chart along the carpet, climbing from the front to
		-- the back (the same on every base, different on each floor), with a
		-- gap round the lock button.
		local seed = n * 7919
		local function nextRandom(): number
			seed = (seed * 48271) % 2147483647
			return seed / 2147483647
		end
		local price = -2.4
		for x = HALL_FRONT - 3, HALL_BACK + 3, -3.5 do
			local open = price
			price = math.clamp(price + (nextRandom() - 0.3) * 1.3, -3.2, 3.2)
			if math.abs(x - LOCK_X) < 2.5 then
				continue
			end
			local low, high = math.min(open, price), math.max(open, price)
			if high - low < 0.5 then
				high = low + 0.5
			end
			local colour = if price >= open then Theme.Chart.Rising else Theme.Chart.Falling
			local wickLength = high - low + 0.9
			local wickAt = at(x, tops[n] + 0.11, (low + high) / 2)
			decor(parent, "Wick", Vector3.new(0.14, 0.05, wickLength), wickAt, Theme.shade(colour, 0.25))
			local bodyAt = at(x, tops[n] + 0.13, (low + high) / 2)
			decor(parent, "Candle", Vector3.new(0.8, 0.06, high - low), bodyAt, colour)
		end
		-- Across the floor between the pairs of plots, each side of the carpet.
		local groutLength = halfWidth - 1 - WALKWAY / 2
		for pair = 1, 5 do
			local x = HALL_FRONT - 5 - (pair - 0.5) * PLOT_STEP
			for _, side in { -1, 1 } do
				local where = at(x, tops[n] + 0.02, side * (WALKWAY / 2 + groutLength / 2))
				decor(parent, "Grout", Vector3.new(0.2, 0.04, groutLength), where, BASE.Grout)
			end
		end
		for _, side in { -1, 1 } do
			local groutSize = Vector3.new(HALL_FRONT - HALL_BACK, 0.04, 0.2)
			decor(
				parent,
				"Grout",
				groutSize,
				at((HALL_FRONT + HALL_BACK) / 2, tops[n] + 0.02, side * (PLOT_Z + 4.75)),
				BASE.Grout
			)
		end
		-- A trading screen at the back of the walkway, with a moving chart
		-- (drawn by the client) under a header. Not on the top floor, which is
		-- open to the sky and would stick up past its railings.
		if n < 4 then
			local backX = HALL_BACK + 0.85
			local tradingScreen = decor(
				parent,
				"TradingScreen",
				Vector3.new(0.2, 4, 7.2),
				at(backX + 0.15, tops[n] + 4.6, 0),
				Theme.Colours.Ink
			)
			screen(tradingScreen, "Chart", "Right", 90)
			decor(parent, "TradingFrame", Vector3.new(0.2, 4.4, 7.6), at(backX, tops[n] + 4.6, 0), accent)
			local tradingHeader =
				decor(parent, "TradingHeader", Vector3.new(0.25, 0.8, 7.6), at(backX, tops[n] + 7.2, 0), BASE.Machine)
			caption(tradingHeader, Enum.NormalId.Right, "MARKET WATCH", Theme.Colours.Gold, 30)
			for _, side in { -1, 1 } do
				decor(
					parent,
					"TradingLeg",
					Vector3.new(0.3, 2.4, 0.3),
					at(backX, tops[n] + 1.2, side * 3.2),
					BASE.Machine
				)
			end
		end
		if n > 1 then
			-- An LED ticker across the floor's front edge, facing the street.
			local frontTicker = decor(
				parent,
				"Ticker",
				Vector3.new(0.12, 0.85, BASE_WIDTH - 4),
				at(HALL_FRONT + 0.36, tops[n] - 0.5, 0),
				Theme.Colours.Ink
			)
			screen(frontTicker, "Ticker", "Right", 150)
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

-- 3. The middle conveyor down the street, resting on the ground: a red
-- carpet between gold rails, with roller ends along the outside of the rails
-- and a row of small lights on each (the client chases the lights and runs
-- chevrons along the carpet, near the camera only). It runs into the hills at
-- both ends; companies appear and disappear at the tunnels.
local STREET = Theme.Street
local shared = model(map, "SharedConveyor")
local sharedBelt = place(shared, "Belt", Vector3.new(8, 2, BELT_LENGTH), CFrame.new(0, groundY + 1, 0), STREET.Carpet)
sharedBelt.Color = STREET.Carpet
sharedBelt.Material = Enum.Material.Fabric
local beltEnd = PLAY_HALF_Z - 2
hide(place(shared, "Start", Vector3.new(1, 1, 1), CFrame.new(0, groundY + 2.5, -beltEnd), Color3.fromRGB(0, 255, 0)))
hide(place(shared, "End", Vector3.new(1, 1, 1), CFrame.new(0, groundY + 2.5, beltEnd), Color3.fromRGB(255, 0, 0)))
for _, side in { -1, 1 } do
	local name = if side < 0 then "TrimLeft" else "TrimRight"
	local rail =
		place(shared, name, Vector3.new(0.6, 2.2, BELT_LENGTH), CFrame.new(side * 4.3, groundY + 1.1, 0), STREET.Rail)
	rail.Color = STREET.Rail
	rail.Material = Enum.Material.Metal
end
do
	local sharedLook = freshModel(shared, "Look")
	for _, side in { -1, 1 } do
		for z = -PLAY_HALF_Z + 6, PLAY_HALF_Z - 6, 12 do
			local where = CFrame.new(side * 4.85, groundY + 1, z)
			decor(
				sharedLook,
				"Roller",
				Vector3.new(0.5, 1.3, 1.3),
				where,
				STREET.Roller,
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			)
		end
		for z = -PLAY_HALF_Z + 3, PLAY_HALF_Z - 3, 8 do
			local where = CFrame.new(side * 4.66, groundY + 1.5, z)
			decor(sharedLook, "Light", Vector3.new(0.12, 0.45, 0.45), where, STREET.LightOff, Enum.Material.Neon)
		end
	end
end

-- The street either side of the conveyor, all only for looks and rebuilt each
-- run: a road lane each side with a dashed line, zebra crossings in front of
-- each row of bases, kerbs, then the pavement with street lamps, benches and
-- planters in the gaps between bases, ticker posts by the crossings and
-- little chart screens on stands (the client draws both), and a gold bull at
-- the far end of the street.
local KERB_X = 12
local ROAD_INNER = 4.6
local CROSSINGS = { -BASE_STEP * 1.5, -BASE_STEP / 2, BASE_STEP / 2, BASE_STEP * 1.5 }
local GAPS = { -BASE_STEP, 0, BASE_STEP }
do
	local street = freshModel(map, "Street")
	local streetTop = groundY + 0.1
	local function flat(name: string, size: Vector3, x: number, z: number, colour: Color3, material: Enum.Material?)
		local part = decor(street, name, size, CFrame.new(x, streetTop + size.Y / 2, z), colour, material)
		part.CastShadow = false
		return part
	end
	local roadWidth = KERB_X - ROAD_INNER
	local laneX = (ROAD_INNER + KERB_X) / 2
	for _, side in { -1, 1 } do
		flat("Road", Vector3.new(roadWidth, 0.06, 2 * PLAY_HALF_Z), side * laneX, 0, STREET.Road, Enum.Material.Asphalt)
		flat("EdgeLine", Vector3.new(0.25, 0.08, 2 * PLAY_HALF_Z), side * (KERB_X - 0.6), 0, STREET.Line)
		for z = -PLAY_HALF_Z + 8, PLAY_HALF_Z - 8, 10 do
			local nearCrossing = false
			for _, crossing in CROSSINGS do
				nearCrossing = nearCrossing or math.abs(z - crossing) < 6
			end
			if not nearCrossing then
				flat("Dash", Vector3.new(0.25, 0.08, 4), side * laneX, z, STREET.Line)
			end
		end
		for _, crossing in CROSSINGS do
			for stripe = 0, 4 do
				local x = side * (ROAD_INNER + 0.9 + stripe * 1.4)
				flat("Crossing", Vector3.new(0.8, 0.08, 4), x, crossing, STREET.Line)
			end
		end
		local kerb = flat("Kerb", Vector3.new(0.6, 0.3, 2 * PLAY_HALF_Z), side * KERB_X, 0, STREET.Kerb)
		kerb.Material = Enum.Material.Concrete
	end

	-- Street lamps along the kerbs, their arms over the road. The bulbs only
	-- glow (no lights), to keep phones fast.
	for _, side in { -1, 1 } do
		for z = -140, 140, 28 do
			local lamp = Instance.new("Model")
			lamp.Name = "Lamp"
			lamp.Parent = street
			local x = side * (KERB_X + 1.6)
			column(lamp, "LampBase", 0.5, 1.2, CFrame.new(x, streetTop + 0.25, z), STREET.LampPole)
			column(lamp, "Pole", 9, 0.4, CFrame.new(x, streetTop + 4.75, z), STREET.LampPole)
			local armX = x - side * 1.1
			decor(lamp, "Arm", Vector3.new(2.4, 0.25, 0.25), CFrame.new(armX, streetTop + 9.1, z), STREET.LampPole)
			local headX = x - side * 2.2
			decor(lamp, "Head", Vector3.new(1.4, 0.4, 0.9), CFrame.new(headX, streetTop + 8.95, z), STREET.LampPole)
			local bulb =
				decor(lamp, "Bulb", Vector3.new(1.1, 0.12, 0.7), CFrame.new(headX, streetTop + 8.7, z), STREET.Bulb)
			bulb.Material = Enum.Material.Neon
		end
	end

	-- In each gap between bases, on both pavements: a bench facing the
	-- conveyor between two planters, and a little chart screen on a stand.
	for _, gap in GAPS do
		for _, side in { -1, 1 } do
			local bench = Instance.new("Model")
			bench.Name = "Bench"
			bench.Parent = street
			local x = side * 30
			decor(
				bench,
				"Seat",
				Vector3.new(1.4, 0.25, 4.4),
				CFrame.new(x, streetTop + 1.4, gap),
				STREET.Wood,
				Enum.Material.Wood
			)
			local backX = x + side * 0.65
			decor(
				bench,
				"Back",
				Vector3.new(0.2, 1.1, 4.4),
				CFrame.new(backX, streetTop + 2.2, gap),
				STREET.Wood,
				Enum.Material.Wood
			)
			for _, end_ in { -1, 1 } do
				local legAt = CFrame.new(x + side * 0.1, streetTop + 0.65, gap + end_ * 1.9)
				decor(bench, "Leg", Vector3.new(1.4, 1.3, 0.25), legAt, STREET.Metal)
			end
			for _, offset in { -6.5, 6.5 } do
				local planter = Instance.new("Model")
				planter.Name = "Planter"
				planter.Parent = street
				local z = gap + offset
				decor(planter, "Box", Vector3.new(3, 1.2, 3), CFrame.new(x, streetTop + 0.6, z), STREET.Planter)
				decor(
					planter,
					"Soil",
					Vector3.new(2.6, 0.1, 2.6),
					CFrame.new(x, streetTop + 1.2, z),
					STREET.Soil,
					Enum.Material.Grass
				)
				local bushSize = Vector3.new(2.6, 2.2, 2.6)
				ellipsoid(
					planter,
					"Bush",
					bushSize,
					CFrame.new(x, streetTop + 2.2, z),
					STREET.Leaf,
					Enum.Material.Grass
				)
				local topSize = Vector3.new(1.6, 1.6, 1.6)
				local topAt = CFrame.new(x - side * 0.3, streetTop + 3.2, z + 0.3)
				decor(
					planter,
					"Bush",
					topSize,
					topAt,
					Theme.tint(STREET.Leaf, 0.15),
					Enum.Material.Grass,
					Enum.PartType.Ball
				)
			end
			-- The screen faces the conveyor (its Right face, which the client
			-- draws on).
			local kiosk = Instance.new("Model")
			kiosk.Name = "Kiosk"
			kiosk.Parent = street
			local kioskX = side * 22
			local toBelt = CFrame.Angles(0, if side < 0 then 0 else math.pi, 0)
			decor(kiosk, "Stand", Vector3.new(0.6, 3.2, 0.6), CFrame.new(kioskX, streetTop + 1.6, gap), STREET.Metal)
			decor(kiosk, "Foot", Vector3.new(1.6, 0.2, 1.6), CFrame.new(kioskX, streetTop + 0.1, gap), STREET.Metal)
			local screenAt = CFrame.new(kioskX, streetTop + 4.2, gap) * toBelt
			decor(kiosk, "ScreenFrame", Vector3.new(0.3, 2.4, 3.6), screenAt, STREET.Metal)
			decor(kiosk, "Screen", Vector3.new(0.1, 2, 3.2), screenAt * CFrame.new(0.15, 0, 0), Theme.Colours.Ink)
		end
	end

	-- Ticker posts beside each crossing, with a sign the client scrolls
	-- company names along (on both faces).
	for _, crossing in CROSSINGS do
		for _, side in { -1, 1 } do
			local post = Instance.new("Model")
			post.Name = "TickerPost"
			post.Parent = street
			local x, z = side * (KERB_X + 3.5), crossing + 4.5
			column(post, "Pole", 6, 0.35, CFrame.new(x, streetTop + 3, z), STREET.LampPole)
			local signAt = CFrame.new(x, streetTop + 6.6, z) * CFrame.Angles(0, if side < 0 then 0 else math.pi, 0)
			decor(post, "Housing", Vector3.new(0.4, 1.1, 5.2), signAt, STREET.Metal)
			decor(post, "Ticker", Vector3.new(0.5, 0.8, 4.9), signAt, Theme.Colours.Ink)
		end
	end

	-- A cartoon gold bull on a marble plinth, across from the upgrade
	-- station.
	local bull = Instance.new("Model")
	bull.Name = "Bull"
	bull.Parent = street
	local bullAt = CFrame.new(20, streetTop, STATION_Z) * CFrame.Angles(0, math.rad(-20), 0)
	local function onBull(lx: number, ly: number, lz: number): CFrame
		return bullAt * CFrame.new(lx, ly, lz)
	end
	decor(bull, "Plinth", Vector3.new(6, 1.6, 9), onBull(0, 0.8, 0), STREET.Marble, Enum.Material.Marble)
	decor(bull, "PlinthTrim", Vector3.new(6.3, 0.3, 9.3), onBull(0, 1.45, 0), STREET.Gold, Enum.Material.Metal)
	local gold, foil = STREET.Gold, Enum.Material.Foil
	ellipsoid(bull, "Body", Vector3.new(3, 2.6, 5.4), onBull(0, 4.2, 0.3), gold, foil)
	ellipsoid(bull, "Head", Vector3.new(2, 1.9, 2.2), onBull(0, 4.9, -2.9), gold, foil)
	ellipsoid(bull, "Snout", Vector3.new(1.4, 0.9, 0.8), onBull(0, 4.4, -3.9), Theme.shade(gold, 0.15), foil)
	for _, side in { -1, 1 } do
		local hornAt = onBull(side * 1.2, 5.8, -2.9) * CFrame.Angles(0, 0, side * math.rad(-30))
		decor(bull, "Horn", Vector3.new(1.4, 0.35, 0.35), hornAt, STREET.Marble, nil, Enum.PartType.Cylinder)
		for _, along in { -1.6, 2 } do
			decor(bull, "Leg", Vector3.new(0.7, 2.6, 0.7), onBull(side * 0.9, 2.9, along), gold, foil)
		end
	end
	local tailAt = onBull(0, 4.6, 3.1) * CFrame.Angles(math.rad(-35), 0, 0)
	decor(bull, "Tail", Vector3.new(0.25, 1.6, 0.25), tailAt, gold, foil)
end

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
-- upgrade station at the other, each facing back along the street. Each is a
-- storefront: an open front under a striped awning, a sign with an emblem,
-- a counter with the till (the ShopPrompt the game uses) and a friendly
-- shopkeeper behind it (the client gives them an idle animation). The goods
-- on display are added in section 9, once the weapon and pet models exist.
-- They're rebuilt each run, so they're always in the right place and turned
-- the right way.
type ShopStyle = {
	x: number,
	z: number,
	prompt: Color3,
	promptMaterial: Enum.Material,
	sign: string,
	-- The shopkeeper: skin tone (Theme.Street.Skin), and a hat.
	skin: number,
	hat: "Cap" | "Ears" | "HardHat",
}
local shopStyles: { [string]: ShopStyle } = {
	WeaponShop = {
		x = -20,
		z = -STATION_Z,
		prompt = GOLD,
		promptMaterial = Enum.Material.Metal,
		sign = "WEAPONS",
		skin = 1,
		hat = "Cap",
	},
	PetShop = {
		x = 20,
		z = -STATION_Z,
		prompt = Color3.fromRGB(190, 150, 255),
		promptMaterial = Enum.Material.Neon,
		sign = "PETS",
		skin = 2,
		hat = "Ears",
	},
	UpgradeStation = {
		x = -20,
		z = STATION_Z,
		prompt = Color3.fromRGB(90, 230, 140),
		promptMaterial = Enum.Material.Neon,
		sign = "UPGRADES",
		skin = 3,
		hat = "HardHat",
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
	local main: Color3 = STREET.Shops[name]
	-- Built in its own frame with its front towards local -z, then turned so
	-- the front faces the middle of the street.
	local facing = if style.z < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.new()
	local frame = CFrame.new(style.x, groundY, style.z) * facing
	local function block(blockName: string, size: Vector3, bx: number, bottom: number, bz: number, colour: Color3)
		return newPart(newShop, blockName, size, frame * CFrame.new(bx, bottom + size.Y / 2, bz), colour)
	end
	local look = Instance.new("Model")
	look.Name = "Look"
	look.Parent = newShop
	local function trim(
		trimName: string,
		size: Vector3,
		cframe: CFrame,
		colour: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	): Part
		return decor(look, trimName, size, frame * cframe, colour, material, shape)
	end

	-- The building: floor, walls and roof.
	block("Floor", Vector3.new(14, 0.4, 9), 0, 0, 0, STREET.ShopFloor)
	block("BackWall", Vector3.new(14, 9, 1), 0, 0.4, 4, STREET.ShopWall)
	block("PostLeft", Vector3.new(0.8, 8.4, 9), -6.6, 0.4, 0, main)
	block("PostRight", Vector3.new(0.8, 8.4, 9), 6.6, 0.4, 0, main)
	block("Roof", Vector3.new(15, 0.8, 10), 0, 8.8, 0, STREET.ShopWall)
	trim("Step", Vector3.new(14, 0.2, 1), CFrame.new(0, 0.1, -5), STREET.Kerb, Enum.Material.Concrete)
	trim("RoofTrim", Vector3.new(15.2, 0.3, 0.3), CFrame.new(0, 9.45, -5.05), main)
	for _, side in { -1, 1 } do
		trim("WallStripe", Vector3.new(0.85, 0.5, 9.05), CFrame.new(side * 6.6, 3.2, 0), STREET.Awning)
	end

	-- A striped awning sloping down over the front, with a scalloped edge.
	local awningTilt = math.atan2(1.2, 2.6)
	for stripe = 0, 6 do
		local stripeColour = if stripe % 2 == 0 then main else STREET.Awning
		local x = -6 + stripe * 2
		local slope = CFrame.new(x, 8.6, -6.3) * CFrame.Angles(-awningTilt, 0, 0)
		trim("Awning", Vector3.new(2, 0.15, 2.9), slope, stripeColour, Enum.Material.Fabric)
		local scallop = CFrame.new(x, 7.75, -7.62) * CFrame.Angles(0, math.rad(90), 0)
		trim("Scallop", Vector3.new(0.1, 0.9, 1.9), scallop, stripeColour, Enum.Material.Fabric, Enum.PartType.Cylinder)
	end

	-- The sign on the roof: the shop's name, with a round emblem on the left.
	local sign = block("Sign", Vector3.new(11, 2.2, 0.4), 0, 9.6, -4.6, main)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Position = UDim2.fromScale(0.04, 0.08)
	text.Size = UDim2.fromScale(0.72, 0.84)
	text.BackgroundTransparency = 1
	text.Font = Theme.Fonts.Display
	text.TextScaled = true
	text.TextColor3 = Theme.Colours.TextOnColour
	text.Text = style.sign
	text.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Color = Theme.Colours.Ink
	outline.Thickness = 3
	outline.Parent = text
	trim("SignFrame", Vector3.new(11.4, 2.6, 0.3), CFrame.new(0, 10.7, -4.4), STREET.ShopWall)
	-- Turned so the discs face the street; the rim sits just behind the disc.
	local badgeAt = CFrame.new(-4.1, 10.7, -4.9) * CFrame.Angles(0, math.rad(90), 0)
	trim("Emblem", Vector3.new(0.2, 2.6, 2.6), badgeAt, STREET.Awning, nil, Enum.PartType.Cylinder)
	trim(
		"EmblemRim",
		Vector3.new(0.15, 2.9, 2.9),
		badgeAt * CFrame.new(-0.05, 0, 0),
		STREET.ShopWall,
		nil,
		Enum.PartType.Cylinder
	)
	-- The emblem's picture, in front of the disc.
	local front = -5.05
	if name == "WeaponShop" then
		-- A gavel.
		local gavel = CFrame.new(-4.1, 10.75, front) * CFrame.Angles(0, 0, math.rad(35))
		trim("EmblemHandle", Vector3.new(0.25, 1.6, 0.15), gavel * CFrame.new(0, -0.3, 0), STREET.Wood)
		trim("EmblemHead", Vector3.new(1.3, 0.55, 0.15), gavel * CFrame.new(0, 0.55, 0), main)
	elseif name == "PetShop" then
		-- A paw print.
		ellipsoid(look, "EmblemPad", Vector3.new(1, 0.8, 0.15), frame * CFrame.new(-4.1, 10.45, front), main)
		for toe = -1.5, 1.5 do
			local toeAt = CFrame.new(-4.1 + toe * 0.42, 11.1 + (if math.abs(toe) < 1 then 0.12 else 0), front)
			ellipsoid(look, "EmblemToe", Vector3.new(0.38, 0.38, 0.15), frame * toeAt, main)
		end
	else
		-- An arrow pointing up.
		trim("EmblemShaft", Vector3.new(0.5, 0.9, 0.15), CFrame.new(-4.1, 10.4, front), main)
		for _, side in { -1, 1 } do
			local headAt = CFrame.new(-4.1 + side * 0.28, 11.05, front) * CFrame.Angles(0, 0, side * math.rad(45))
			trim("EmblemHead", Vector3.new(0.3, 0.95, 0.15), headAt, main)
		end
	end

	-- The counter, with the till on top.
	block("Counter", Vector3.new(10, 3, 2), 0, 0.4, -2, STREET.Counter).Material = Enum.Material.Wood
	trim("CounterTop", Vector3.new(10.4, 0.25, 2.4), CFrame.new(0, 3.525, -2), STREET.CounterTop, Enum.Material.Marble)
	trim("CounterStripe", Vector3.new(10.05, 0.4, 0.1), CFrame.new(0, 2.6, -3.02), main)
	local till = block("ShopPrompt", Vector3.new(2, 1, 1.2), 0, 3.65, -2, style.prompt)
	till.Material = style.promptMaterial
	trim(
		"TillScreen",
		Vector3.new(1.4, 0.5, 0.1),
		CFrame.new(0, 4.35, -2.3) * CFrame.Angles(math.rad(-20), 0, 0),
		Theme.Colours.Ink
	)

	-- The shopkeeper, standing behind the counter facing the street. The
	-- client finds them by name (Shopkeeper) and their parts by name.
	local keeper = Instance.new("Model")
	keeper.Name = "Shopkeeper"
	keeper.Parent = newShop
	local skin: Color3 = STREET.Skin[style.skin]
	local function piece(
		partName: string,
		size: Vector3,
		lx: number,
		ly: number,
		lz: number,
		colour: Color3,
		shape: Enum.PartType?
	)
		return decor(keeper, partName, size, frame * CFrame.new(lx, ly, lz), colour, nil, shape)
	end
	local keeperZ = 1
	for _, side in { -1, 1 } do
		piece(
			if side < 0 then "LegLeft" else "LegRight",
			Vector3.new(0.7, 1.9, 0.7),
			side * 0.45,
			1.35,
			keeperZ,
			STREET.Trousers
		)
	end
	piece("Body", Vector3.new(1.9, 2, 1.1), 0, 3.3, keeperZ, main)
	piece("Apron", Vector3.new(1.5, 1.7, 0.1), 0, 3.05, keeperZ - 0.6, STREET.Awning)
	for _, side in { -1, 1 } do
		piece(
			if side < 0 then "ArmLeft" else "ArmRight",
			Vector3.new(0.55, 1.8, 0.55),
			side * 1.25,
			3.25,
			keeperZ,
			main
		)
	end
	piece("Head", Vector3.new(1.5, 1.5, 1.5), 0, 5.05, keeperZ, skin, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		piece(
			if side < 0 then "EyeLeft" else "EyeRight",
			Vector3.new(0.2, 0.28, 0.1),
			side * 0.3,
			5.2,
			keeperZ - 0.72,
			STREET.Eye
		)
	end
	piece("Smile", Vector3.new(0.5, 0.1, 0.1), 0, 4.75, keeperZ - 0.7, STREET.Eye)
	if style.hat == "Cap" then
		piece("Hat", Vector3.new(1.55, 0.5, 1.55), 0, 5.75, keeperZ, main)
		piece("HatBrim", Vector3.new(1.4, 0.12, 0.8), 0, 5.55, keeperZ - 0.95, main)
	elseif style.hat == "Ears" then
		for _, side in { -1, 1 } do
			ellipsoid(keeper, "Hat", Vector3.new(0.5, 0.6, 0.3), frame * CFrame.new(side * 0.5, 5.85, keeperZ), skin)
		end
		piece("HatBrim", Vector3.new(1.55, 0.15, 0.3), 0, 5.65, keeperZ, main)
	else
		ellipsoid(keeper, "Hat", Vector3.new(1.65, 0.9, 1.65), frame * CFrame.new(0, 5.75, keeperZ), Theme.Colours.Gold)
		local brimAt = CFrame.new(0, 5.45, keeperZ) * UPRIGHT
		decor(
			keeper,
			"HatBrim",
			Vector3.new(0.12, 2, 2),
			frame * brimAt,
			Theme.Colours.Gold,
			nil,
			Enum.PartType.Cylinder
		)
	end

	-- Teleports arrive in front of the counter, from this pivot.
	newShop.WorldPivot = frame
	newShop.Parent = shops
end

-- 6. The leaderboards, two either side of the street in the gaps between the
-- middle bases, facing across it, styled as stock-exchange display boards: a
-- dark board in a frame under a coloured header with a ticker strip, legs
-- down to a plinth, and a soft glow behind. The game writes the lists on each
-- board's front face.
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
	local board =
		place(leaderboards, spot.name, Vector3.new(10, 12, 1), facing * CFrame.new(0, groundY + 8, 0), STREET.Board)
	board.Color = STREET.Board
	local stand = Instance.new("Model")
	stand.Name = spot.name .. "Stand"
	stand.Parent = stands
	local function piece(
		pieceName: string,
		size: Vector3,
		lx: number,
		ly: number,
		lz: number,
		colour: Color3,
		material: Enum.Material?
	)
		return decor(stand, pieceName, size, facing * CFrame.new(lx, groundY + ly, lz), colour, material)
	end
	piece("Header", Vector3.new(11, 1.8, 1.4), 0, 14.9, 0.1, STREET.BoardHeader)
	piece("HeaderTrim", Vector3.new(11.2, 0.25, 1.5), 0, 14, 0.1, STREET.Gold, Enum.Material.Metal)
	piece("Ticker", Vector3.new(10, 0.7, 0.1), 0, 14.95, -0.62, Theme.Colours.Ink)
	for _, side in { -1, 1 } do
		piece("FrameSide", Vector3.new(0.5, 12.4, 1.3), side * 5.25, 8, 0.1, STREET.BoardFrame)
		piece("Leg", Vector3.new(0.6, 2, 0.6), side * 4, 1, 0.3, STREET.BoardFrame)
	end
	piece("FrameBottom", Vector3.new(11, 0.5, 1.3), 0, 1.95, 0.1, STREET.BoardFrame)
	local glow = piece("Glow", Vector3.new(11.6, 13.6, 0.2), 0, 8.3, 0.85, STREET.BoardGlow, Enum.Material.Neon)
	glow.Transparency = 0.6
	glow.CastShadow = false
	piece("Plinth", Vector3.new(11, 0.4, 2.2), 0, 0.2, 0.3, STREET.Metal)
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
-- A stock-exchange gateway where the conveyor meets the hills at each end:
-- marble columns on plinths, a frieze with the game's name, a cornice and a
-- pediment with a gold medallion, all only for looks. Behind it, a dark wall
-- closes the tunnel.
for _, side in { -1, 1 } do
	local gateway = Instance.new("Model")
	gateway.Name = "Gateway"
	gateway.Parent = border
	-- Its front, local -z, faces back along the street.
	local frame = CFrame.new(0, groundY, side * (PLAY_HALF_Z - 1.5))
		* CFrame.Angles(0, if side > 0 then 0 else math.pi, 0)
	local function piece(
		pieceName: string,
		size: Vector3,
		cframe: CFrame,
		colour: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	): Part
		return decor(gateway, pieceName, size, frame * cframe, colour, material, shape)
	end
	local marble = Enum.Material.Marble
	for _, x in { -15.5, -9.5, 9.5, 15.5 } do
		piece("Plinth", Vector3.new(3, 0.8, 3), CFrame.new(x, 0.4, 0), STREET.MarbleShade, marble)
		column(gateway, "Column", 11.4, 2, frame * CFrame.new(x, 6.5, 0), STREET.Marble, marble)
		column(gateway, "ColumnBase", 0.5, 2.5, frame * CFrame.new(x, 1.05, 0), STREET.Marble, marble)
		piece("Capital", Vector3.new(2.8, 0.6, 2.8), CFrame.new(x, 12.5, 0), STREET.MarbleShade, marble)
	end
	piece("Architrave", Vector3.new(36, 1.2, 3), CFrame.new(0, 13.4, 0), STREET.Marble, marble)
	local frieze = piece("Frieze", Vector3.new(34, 2.4, 0.3), CFrame.new(0, 15.2, -1.2), STREET.Frieze)
	piece("FriezeBack", Vector3.new(36, 2.4, 2.6), CFrame.new(0, 15.2, 0.2), STREET.Marble, marble)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Name"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = frieze
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Theme.Fonts.Display
	title.TextScaled = true
	title.TextColor3 = STREET.Gold
	title.Text = "STOCK TYCOON"
	title.Parent = gui
	piece("Cornice", Vector3.new(37, 0.6, 3.4), CFrame.new(0, 16.7, 0), STREET.MarbleShade, marble)
	-- The pediment: two wedges, each rising to the middle.
	for _, half in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Pediment"
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanTouch = false
		wedge.CanQuery = false
		wedge.Color = STREET.Marble
		wedge.Material = marble
		wedge.TopSurface = Enum.SurfaceType.Smooth
		wedge.BottomSurface = Enum.SurfaceType.Smooth
		-- A wedge is tallest at its back (+z), so its z axis points to the
		-- middle and its x axis back into the gateway.
		wedge.Size = Vector3.new(2.6, 4, 18)
		local middle = Vector3.new(half * 9, 19, 0.2)
		local axes = CFrame.fromMatrix(middle, Vector3.new(0, 0, half), Vector3.new(0, 1, 0), Vector3.new(-half, 0, 0))
		wedge.CFrame = frame * axes
		wedge.Parent = gateway
	end
	local medallion = frame * CFrame.new(0, 18.6, -1.15) * CFrame.Angles(0, math.rad(90), 0)
	decor(
		gateway,
		"Medallion",
		Vector3.new(0.3, 2.6, 2.6),
		medallion,
		STREET.Gold,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	decor(
		gateway,
		"MedallionRim",
		Vector3.new(0.2, 3.1, 3.1),
		medallion * CFrame.new(-0.03, 0, 0),
		STREET.MarbleShade,
		nil,
		Enum.PartType.Cylinder
	)
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

-- 7b. The skyline: a financial district standing beyond the hills all round,
-- low detail and only for looks (nothing collides or casts a shadow). Glass
-- towers with lit floors, a landmark exchange tower behind each gateway with
-- a ticker across it, and billboards facing the map: parody company ads, big
-- charts and slogans (the client draws the ads, charts and tickers).
do
	local SKYLINE = Theme.Skyline
	local SLOGANS = { "BUY LOW, SELL HIGH", "TO THE MOON" }
	local skyline = freshModel(map, "Skyline")
	local random = Random.new(1929)
	local bodies: { Color3 } = SKYLINE.Towers
	local function tower(position: Vector3, width: number, depth: number, height: number): CFrame
		local bottom = groundY - 10
		local total = height + 10
		local towerModel = Instance.new("Model")
		towerModel.Name = "Tower"
		towerModel.Parent = skyline
		-- Turned to face the middle of the map.
		local facing = CFrame.lookAt(Vector3.new(position.X, 0, position.Z), Vector3.new(0, 0, 0))
		local function at(y: number): CFrame
			return CFrame.new(position.X, y, position.Z) * facing.Rotation
		end
		local colour = bodies[math.floor(random:NextNumber(1, #bodies + 0.999))]
		local body = decor(towerModel, "Body", Vector3.new(width, total, depth), at(bottom + total / 2), colour)
		body.Reflectance = 0.1
		body.CastShadow = false
		-- Lit floors: a few bands round the tower.
		local bands = math.max(2, math.floor(height / 45))
		for band = 1, bands do
			local y = groundY + height * band / (bands + 1)
			local strip = decor(
				towerModel,
				"Windows",
				Vector3.new(width + 0.4, 1.6, depth + 0.4),
				at(y),
				SKYLINE.Windows,
				Enum.Material.Neon
			)
			strip.Transparency = 0.45
			strip.CastShadow = false
		end
		local cap = decor(
			towerModel,
			"Roof",
			Vector3.new(width * 0.7, 4, depth * 0.7),
			at(groundY + height + 2),
			Theme.shade(colour, 0.25)
		)
		cap.CastShadow = false
		if height > 150 then
			local mast = decor(towerModel, "Mast", Vector3.new(0.8, 18, 0.8), at(groundY + height + 13), SKYLINE.Mast)
			mast.CastShadow = false
			local beacon = decor(
				towerModel,
				"MastLight",
				Vector3.new(1.4, 1.4, 1.4),
				at(groundY + height + 22.5),
				SKYLINE.Beacon,
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			beacon.CastShadow = false
		end
		return at(0)
	end
	-- A billboard on a tower's face towards the map.
	local function billboard(face: CFrame, frontOffset: number, y: number, width: number, height: number): Part
		local board = decor(
			skyline,
			"Billboard",
			Vector3.new(width, height, 1),
			face * CFrame.new(0, y, -frontOffset - 0.6),
			Theme.Colours.Ink
		)
		board.CastShadow = false
		local frame = decor(
			skyline,
			"BillboardFrame",
			Vector3.new(width + 2, height + 2, 0.8),
			face * CFrame.new(0, y, -frontOffset - 0.1),
			SKYLINE.Frame
		)
		frame.CastShadow = false
		return board
	end

	-- Rows of towers behind the hills on all four sides, with a billboard
	-- on some.
	local sideX = PLAY_HALF_X + HILLS + 30
	local endZ = PLAY_HALF_Z + HILLS + 30
	local spots: { { position: Vector3, board: string? } } = {}
	for _, side in { -1, 1 } do
		for k = 0, 11 do
			local z = -300 + k * 55 + random:NextNumber(-12, 12)
			local x = side * (sideX + random:NextNumber(0, 70))
			local board = if k == 3 or k == 8 then "Ad" elseif k == 6 then "Slogan" else nil
			table.insert(spots, { position = Vector3.new(x, 0, z), board = board })
		end
		for k = 0, 7 do
			local x = -240 + k * 68 + random:NextNumber(-12, 12)
			if math.abs(x) < 45 then
				-- The landmark stands here.
				continue
			end
			local z = side * (endZ + random:NextNumber(0, 70))
			table.insert(spots, { position = Vector3.new(x, 0, z), board = if k == 2 then "Chart" else nil })
		end
	end
	local slogans = 0
	for _, spot in spots do
		local width = random:NextNumber(18, 34)
		local depth = random:NextNumber(18, 34)
		local height = random:NextNumber(80, 210)
		local face = tower(spot.position, width, depth, height)
		if spot.board == "Slogan" then
			-- A slogan in fixed words.
			slogans += 1
			local board = billboard(face, depth / 2, groundY + height * 0.62, 46, 16)
			caption(board, Enum.NormalId.Front, SLOGANS[(slogans - 1) % #SLOGANS + 1], Theme.Colours.Gold, 6)
		elseif spot.board then
			local board = billboard(face, depth / 2, groundY + height * 0.62, 40, 20)
			screen(board, spot.board :: any, "Front", 1500)
		end
	end
	-- The landmark exchange towers behind the gateways, with a ticker across
	-- them facing down the street.
	for _, side in { -1, 1 } do
		local face = tower(Vector3.new(0, 0, side * (endZ + 50)), 44, 36, 240)
		local ticker = decor(
			skyline,
			"Ticker",
			Vector3.new(44.4, 6, 1),
			face * CFrame.new(0, groundY + 150, -18.6),
			Theme.Colours.Ink
		)
		ticker.CastShadow = false
		screen(ticker, "Ticker", "Front", 1500)
		local nameBoard = billboard(face, 18, groundY + 205, 40, 10)
		caption(nameBoard, Enum.NormalId.Front, "STOCK EXCHANGE", Theme.Colours.Gold, 6)
	end
end

-- 8. Models the game copies, if they're missing: the Default company and the
-- Default pet (for anything without its own; the game builds the real ones
-- when the server starts). Any that already exist are left alone.
local assets = folder(ReplicatedStorage, "Assets")

local companies = folder(assets, "Companies")
if companies:FindFirstChild("Default") == nil then
	local box = Instance.new("Model")
	box.Name = "Default"
	box.PrimaryPart = newPart(box, "Box", Vector3.new(3, 3, 3), CFrame.new(0, 1.5, 0), Color3.fromRGB(70, 130, 255))
	box.Parent = companies
end

-- The weapons are built by the game when the server starts (Lib/WeaponModels).
folder(assets, "Weapons")

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

-- 9. The goods on display in each shop, only for looks: a pegboard with a hook
-- for each weapon in the weapon shop, pet eggs on shelves and two seats on
-- the counter in the pet shop, and glowing arrows with a level meter in the
-- upgrade station. The game hangs the weapons on the hooks and stands real
-- pets on the seats when the server starts, from the same models it uses
-- everywhere else.
do
	local function shopFrame(shop: Instance): CFrame?
		return if shop:IsA("Model") then shop.WorldPivot else nil
	end

	local weaponShop = shops:FindFirstChild("WeaponShop")
	local weaponFrame = weaponShop and shopFrame(weaponShop)
	if weaponShop and weaponFrame then
		local goods = freshModel(weaponShop, "Goods")
		decor(goods, "Pegboard", Vector3.new(12, 5, 0.2), weaponFrame * CFrame.new(0, 5.6, 3.4), STREET.Metal)
		local order = { "Newspaper", "Briefcase", "StaplerGun", "Gavel", "GoldenCalculator" }
		for index, id in order do
			local x = -5 + (index - 1) * 2.5
			local hookAt = weaponFrame * CFrame.new(x, 5.6, 2.7)
			decor(goods, "Hook", Vector3.new(0.15, 0.15, 0.6), hookAt * CFrame.new(0, 1.6, 0.35), STREET.Rail)
			local hook = decor(goods, "WeaponHook", Vector3.new(0.2, 0.2, 0.2), hookAt, STREET.Rail)
			hook.Transparency = 1
			hook:SetAttribute("WeaponId", id)
		end
	end

	local petShop = shops:FindFirstChild("PetShop")
	local petFrame = petShop and shopFrame(petShop)
	if petShop and petFrame then
		local goods = freshModel(petShop, "Goods")
		local eggColours = {
			Theme.Rarities.Common,
			Theme.Rarities.Uncommon,
			Theme.Rarities.Rare,
			Theme.Rarities.Epic,
			Theme.Rarities.Legendary,
			Theme.Rarities.Mythic,
		}
		for shelf = 0, 1 do
			local y = 4.6 + shelf * 2.4
			decor(
				goods,
				"Shelf",
				Vector3.new(11, 0.25, 1.2),
				petFrame * CFrame.new(0, y, 2.9),
				STREET.Wood,
				Enum.Material.Wood
			)
			for slot = 0, 2 do
				local colour = eggColours[shelf * 3 + slot + 1]
				local eggAt = petFrame * CFrame.new(-3.6 + slot * 3.6, y + 0.75, 2.9)
				ellipsoid(goods, "Egg", Vector3.new(0.95, 1.25, 0.95), eggAt, colour)
				ellipsoid(goods, "EggBand", Vector3.new(1, 0.22, 1), eggAt * CFrame.new(0, 0.05, 0), Theme.Colours.Card)
			end
		end
		for seat, side in { -1, 1 } do
			local seatAt = petFrame * CFrame.new(side * 3.9, 3.7, -2)
			local seatPart = decor(goods, "PlushSeat", Vector3.new(1.6, 0.1, 1.6), seatAt, STREET.Wood)
			seatPart.Transparency = 1
			seatPart:SetAttribute("Seat", seat)
		end
	end

	local station = shops:FindFirstChild("UpgradeStation")
	local stationFrame = station and shopFrame(station)
	if station and stationFrame then
		local goods = freshModel(station, "Goods")
		local green = STREET.Shops.UpgradeStation
		for index, height in { 1.6, 2.6, 3.6 } do
			local x = -4.5 + (index - 1) * 2.4
			local base = 4.4
			local shaftAt = stationFrame * CFrame.new(x, base + height / 2, 3.35)
			decor(goods, "ArrowShaft", Vector3.new(0.7, height, 0.2), shaftAt, green, Enum.Material.Neon)
			for _, side in { -1, 1 } do
				local headAt = stationFrame
					* CFrame.new(x + side * 0.38, base + height + 0.05, 3.35)
					* CFrame.Angles(0, 0, side * math.rad(45))
				decor(goods, "ArrowHead", Vector3.new(0.4, 1.3, 0.2), headAt, green, Enum.Material.Neon)
			end
		end
		decor(goods, "Meter", Vector3.new(4, 4.4, 0.2), stationFrame * CFrame.new(3.6, 6, 3.4), STREET.Metal)
		for level = 0, 4 do
			local height = 0.6 + level * 0.75
			local barAt = stationFrame * CFrame.new(2.2 + level * 0.7, 4.2 + height / 2, 3.28)
			local colour = if level < 4 then green else Theme.Colours.Gold
			decor(goods, "MeterBar", Vector3.new(0.5, height, 0.1), barAt, colour, Enum.Material.Neon)
		end
	end
end

-- Set last, so a run that stops part way still counts as out of date.
map:SetAttribute("MapVersion", MAP_VERSION)

print("Map built")
