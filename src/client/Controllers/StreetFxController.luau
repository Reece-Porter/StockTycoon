--!strict
-- The middle street comes alive on each player's device (docs/visual-pass.md,
-- Phase 6), near the camera only. Looks only; the parts are from
-- studio/BuildMap.luau.
--   - The shared conveyor: chevrons run along the red carpet the way it
--     moves, and the little lights on its rails chase each other.
--   - The chart screens on stands (Street.Kiosk) and the ticker posts
--     (Street.TickerPost) and leaderboard tickers (Leaderboards.Stands) run
--     the same charts and tickers as the Valuation Machine (Ui/WorldScreens).
--   - Each shop's Shopkeeper breathes, looks around, blinks and now and then
--     waves.
-- The chevrons are made here, in a ChevronFx folder in the SharedConveyor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ConveyorConfig = require(ReplicatedStorage.Shared.Config.Conveyor)
local Theme = require(ReplicatedStorage.Shared.Theme)
local WorldScreens = require(script.Parent.Parent.Ui.WorldScreens)

local STREET = Theme.Street
local CHECK_SECONDS = 0.5
-- How close the camera must be for things to move.
local BELT_NEAR = 90
local SCREEN_NEAR = 70
local KEEPER_NEAR = 80
-- Chevrons: how many run near the camera, and how far apart.
local CHEVRONS = 14
local CHEVRON_SPACING = 6
local CHEVRON_ARM = Vector3.new(0.3, 0.05, 2)
-- Rail lights within this far along the belt of the camera chase; one in
-- LIGHT_EVERY is lit, moving on a light every LIGHT_STEP seconds.
local LIGHT_REACH = 70
local LIGHT_EVERY = 4
local LIGHT_STEP = 0.15
-- Shopkeepers: breathing, looking around, blinking and waving.
local BREATH_HEIGHT = 0.05
local LOOK_ANGLE = math.rad(14)
local BLINK_EVERY = 3.7
local BLINK_SECONDS = 0.14
local WAVE_EVERY = 7
local WAVE_SECONDS = 1.8
local WAVE_ANGLE = math.rad(145)
-- The pieces that turn with the head.
local HEAD_PIECES = { Head = true, EyeLeft = true, EyeRight = true, Smile = true, Hat = true, HatBrim = true }

type Chevron = { left: Part, right: Part }

type Belt = {
	from: Vector3,
	direction: Vector3,
	length: number,
	chevrons: { Chevron },
	lights: { BasePart },
	near: boolean,
	lightStep: number,
	nextLight: number,
}

type Screen = {
	part: BasePart,
	charts: { WorldScreens.Chart },
	tickers: { WorldScreens.Ticker },
	near: boolean,
}

-- A shopkeeper's part, where it rests in the keeper's frame.
type Piece = { part: BasePart, rest: CFrame, size: Vector3 }

type Keeper = {
	model: Instance,
	frame: CFrame,
	pieces: { [string]: { Piece } },
	-- The middle of the head, and the right arm's shoulder, in the frame.
	headCentre: Vector3,
	shoulder: Vector3,
	phase: number,
	near: boolean,
}

local belt: Belt? = nil
local screens: { [BasePart]: Screen } = {}
local keepers: { [Instance]: Keeper } = {}

local StreetFxController = {}

local function lookPart(parent: Instance, name: string, size: Vector3, colour: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = colour
	part.Material = Enum.Material.Neon
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function findBelt(map: Instance)
	if belt then
		return
	end
	local conveyor = map:FindFirstChild("SharedConveyor")
	local beltPart = conveyor and conveyor:FindFirstChild("Belt")
	local startPart = conveyor and conveyor:FindFirstChild("Start")
	local endPart = conveyor and conveyor:FindFirstChild("End")
	if conveyor == nil or beltPart == nil or startPart == nil or endPart == nil then
		return
	end
	if not (beltPart:IsA("BasePart") and startPart:IsA("BasePart") and endPart:IsA("BasePart")) then
		return
	end
	local top = beltPart.Position.Y + beltPart.Size.Y / 2 + 0.03
	local from = Vector3.new(startPart.Position.X, top, startPart.Position.Z)
	local to = Vector3.new(endPart.Position.X, top, endPart.Position.Z)
	if (to - from).Magnitude < 1 then
		return
	end
	local found: Belt = {
		from = from,
		direction = (to - from).Unit,
		length = (to - from).Magnitude,
		chevrons = {},
		lights = {},
		near = false,
		lightStep = 0,
		nextLight = 0,
	}
	local folder = Instance.new("Folder")
	folder.Name = "ChevronFx"
	folder.Parent = conveyor
	local colour = STREET.LightOn
	for _ = 1, CHEVRONS do
		table.insert(found.chevrons, {
			left = lookPart(folder, "Chevron", CHEVRON_ARM, colour),
			right = lookPart(folder, "Chevron", CHEVRON_ARM, colour),
		})
	end
	local look = conveyor:FindFirstChild("Look")
	if look then
		for _, child in look:GetChildren() do
			if child.Name == "Light" and child:IsA("BasePart") then
				table.insert(found.lights, child)
			end
		end
	end
	-- Ordered along the belt, so the chase runs along it.
	table.sort(found.lights, function(a, b)
		return (a.Position - from):Dot(found.direction) < (b.Position - from):Dot(found.direction)
	end)
	belt = found
end

local function addScreen(part: Instance, kind: "Chart" | "Ticker", faces: { Enum.NormalId })
	if not part:IsA("BasePart") or screens[part] then
		return
	end
	local screen: Screen = { part = part, charts = {}, tickers = {}, near = false }
	for _, face in faces do
		if kind == "Chart" then
			table.insert(screen.charts, WorldScreens.chart(part, face))
		else
			table.insert(screen.tickers, WorldScreens.ticker(part, face))
		end
	end
	screens[part] = screen
end

local function findScreens(map: Instance)
	local street = map:FindFirstChild("Street")
	if street then
		for _, child in street:GetChildren() do
			if child.Name == "Kiosk" then
				local screen = child:FindFirstChild("Screen")
				if screen then
					addScreen(screen, "Chart", { Enum.NormalId.Right })
				end
			elseif child.Name == "TickerPost" then
				local ticker = child:FindFirstChild("Ticker")
				if ticker then
					addScreen(ticker, "Ticker", { Enum.NormalId.Right, Enum.NormalId.Left })
				end
			end
		end
	end
	local boards = map:FindFirstChild("Leaderboards")
	local stands = boards and boards:FindFirstChild("Stands")
	if stands then
		for _, stand in stands:GetChildren() do
			local ticker = stand:FindFirstChild("Ticker")
			if ticker then
				addScreen(ticker, "Ticker", { Enum.NormalId.Front })
			end
		end
	end
end

local function findKeepers(map: Instance)
	local shops = map:FindFirstChild("Shops")
	if shops == nil then
		return
	end
	for _, shop in shops:GetChildren() do
		local model = shop:FindFirstChild("Shopkeeper")
		if model == nil or keepers[model] or not shop:IsA("Model") then
			continue
		end
		local frame = shop.WorldPivot
		local keeper: Keeper = {
			model = model,
			frame = frame,
			pieces = {},
			headCentre = Vector3.zero,
			shoulder = Vector3.zero,
			phase = #shop.Name,
			near = false,
		}
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") then
				local list = keeper.pieces[part.Name] or {}
				local rest = frame:ToObjectSpace(part.CFrame)
				table.insert(list, { part = part, rest = rest, size = part.Size })
				keeper.pieces[part.Name] = list
				if part.Name == "Head" then
					keeper.headCentre = rest.Position
				elseif part.Name == "ArmRight" then
					keeper.shoulder = rest.Position + Vector3.new(0, part.Size.Y / 2 - part.Size.X / 2, 0)
				end
			end
		end
		keepers[model] = keeper
	end
end

function StreetFxController.check(cameraPosition: Vector3)
	local map = workspace:FindFirstChild("Map")
	if map then
		findBelt(map)
		findScreens(map)
		findKeepers(map)
	end
	local found = belt
	if found then
		local wasNear = found.near
		found.near = math.abs(cameraPosition.X - found.from.X) <= BELT_NEAR
		if wasNear and not found.near then
			for _, chevron in found.chevrons do
				chevron.left.Transparency = 1
				chevron.right.Transparency = 1
			end
		end
	end
	for part, screen in screens do
		if part.Parent == nil then
			screens[part] = nil
		else
			screen.near = (part.Position - cameraPosition).Magnitude <= SCREEN_NEAR
		end
	end
	for model, keeper in keepers do
		if model.Parent == nil then
			keepers[model] = nil
		else
			keeper.near = (keeper.frame.Position - cameraPosition).Magnitude <= KEEPER_NEAR
		end
	end
end

local function stepBelt(found: Belt, now: number, cameraPosition: Vector3)
	-- Chevrons in a window round the camera, moving along with the belt.
	local speed = ConveyorConfig.Shared.StudsPerSecond
	local cameraAlong = (cameraPosition - found.from):Dot(found.direction)
	local shift = (now * speed) % CHEVRON_SPACING
	local first = math.floor(cameraAlong / CHEVRON_SPACING) - math.floor(CHEVRONS / 2)
	local parts, cframes = {}, {}
	for index, chevron in found.chevrons do
		local along = (first + index - 1) * CHEVRON_SPACING + shift
		local onBelt = along >= 0 and along <= found.length
		chevron.left.Transparency = if onBelt then 0.2 else 1
		chevron.right.Transparency = if onBelt then 0.2 else 1
		local spot = found.from + found.direction * math.clamp(along, 0, found.length)
		local basis = CFrame.lookAt(spot, spot + found.direction)
		for _, side in { -1, 1 } do
			table.insert(parts, if side < 0 then chevron.left else chevron.right)
			table.insert(cframes, basis * CFrame.new(side * 0.7, 0, 0) * CFrame.Angles(0, side * math.rad(40), 0))
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

	if now >= found.nextLight then
		found.nextLight = now + LIGHT_STEP
		found.lightStep += 1
		for index, light in found.lights do
			if math.abs((light.Position - cameraPosition):Dot(found.direction)) <= LIGHT_REACH then
				local lit = (index + found.lightStep) % LIGHT_EVERY == 0
				light.Color = if lit then STREET.LightOn else STREET.LightOff
			end
		end
	end
end

local function stepKeeper(keeper: Keeper, now: number)
	local t = now + keeper.phase
	local breath = Vector3.new(0, BREATH_HEIGHT * math.sin(t * 2), 0)
	local look = CFrame.Angles(0, LOOK_ANGLE * math.sin(t * 0.7), 0)
	local head = CFrame.new(keeper.headCentre + breath) * look * CFrame.new(-keeper.headCentre)
	local waveTime = t % WAVE_EVERY
	local raise = 0
	if waveTime < WAVE_SECONDS then
		raise = math.min(waveTime / 0.3, 1, (WAVE_SECONDS - waveTime) / 0.3)
	end
	local wave = raise * (WAVE_ANGLE + math.rad(18) * math.sin(waveTime * 12))
	local shoulder = keeper.shoulder
	local arm = CFrame.new(shoulder + breath) * CFrame.Angles(0, 0, wave) * CFrame.new(-shoulder)
	local blinking = (t % BLINK_EVERY) < BLINK_SECONDS
	for name, list in keeper.pieces do
		for _, piece in list do
			local moved: CFrame
			if name == "LegLeft" or name == "LegRight" then
				continue
			elseif HEAD_PIECES[name] then
				moved = head * piece.rest
			elseif name == "ArmRight" then
				moved = arm * piece.rest
			else
				moved = piece.rest + breath
			end
			piece.part.CFrame = keeper.frame * moved
			if name == "EyeLeft" or name == "EyeRight" then
				local size = piece.size
				piece.part.Size = if blinking then Vector3.new(size.X, size.Y * 0.15, size.Z) else size
			end
		end
	end
end

function StreetFxController.step(now: number, delta: number, cameraPosition: Vector3)
	local found = belt
	if found and found.near then
		stepBelt(found, now, cameraPosition)
	end
	for _, screen in screens do
		if screen.near then
			for _, chart in screen.charts do
				WorldScreens.stepChart(chart, now)
			end
			for _, ticker in screen.tickers do
				WorldScreens.stepTicker(ticker, delta)
			end
		end
	end
	for _, keeper in keepers do
		if keeper.near then
			stepKeeper(keeper, now)
		end
	end
end

function StreetFxController:Start()
	local last = os.clock()
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local now = os.clock()
		if camera then
			StreetFxController.step(now, now - last, camera.CFrame.Position)
		end
		last = now
	end)
	while true do
		local camera = workspace.CurrentCamera
		if camera then
			StreetFxController.check(camera.CFrame.Position)
		end
		task.wait(CHECK_SECONDS)
	end
end

return StreetFxController
