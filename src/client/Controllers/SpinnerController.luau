--!strict
-- The Stock Spinner's reels on every base (docs/design.md, "Stock Spinner").
-- Looks only: SpinnerService on the server has already rolled the
-- companies and puts them on the belt. Each base's Spinner (studio/
-- BuildMap.luau) has a screen over each place a company stops (Reel1 to
-- Reel3), a Timer strip and gold Bulbs. From the base's SpinnerRolledAt,
-- SpinnerLandsAt, SpinnerNextRollAt and SpinnerResults attributes, this draws:
--   - on each reel, from both sides, a column of companies rolling past,
--     each in its tier's colour, slowing to a stop on what was rolled, one
--     reel after another, the last as the roll lands;
--   - on the timer, "ROLLING!" while the reels spin, then the time to the
--     next roll with a bar running down;
--   - the bulbs chasing while the reels spin;
--   - a pop over the reel when the player's own spinner lands a Blue Chip or
--     a variant.
-- Only bases near the camera move; the rest just show what they rolled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Format = require(ReplicatedStorage.Shared.Format)
local SpinnerConfig = require(ReplicatedStorage.Shared.Config.Spinner)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local WorldPop = require(script.Parent.Parent.Ui.WorldPop)

local CHECK_SECONDS = 0.5
-- A base is near while the camera is this close to its spawn.
local NEAR = 130
local PIXELS_PER_STUD = 30
local SCREEN_DISTANCE = 150
-- How many companies roll past on the first reel, and how many more on
-- each reel after it, and how long before the roll lands each reel stops
-- (the last one stopping as it lands).
local ROLL_PAST = 16
local MORE_PER_REEL = 5
local REEL_GAP = 0.35
-- The bulbs chase this many steps a second while the reels spin.
local CHASE_STEPS = 10
local POP_OFFSET = Vector3.new(0, 3.5, 0)
-- The best tier the spinner gives, popped when the player's own lands one.
local TOP_TIER = SpinnerConfig.Weights[#SpinnerConfig.Weights].tier

type Result = { companyId: string, variant: string? }

type Tile = { frame: Frame, name: TextLabel, line: TextLabel, shown: number? }

type Reel = {
	part: BasePart,
	-- Two tiles a side: the one showing and the one coming up under it.
	tiles: { { Tile } },
}

type SpinnerFx = {
	model: Model,
	reels: { Reel },
	timerLabels: { TextLabel },
	timerFills: { Frame },
	bulbs: { BasePart },
	near: boolean,
	rolledAt: number?,
	landsAt: number,
	nextRollAt: number,
	results: { Result },
	-- What the reels showed before this roll, to start rolling from.
	previous: { Result },
	-- The landing already popped (or there when first seen).
	poppedFor: number?,
}

local player = Players.LocalPlayer
local spinners: { [Model]: SpinnerFx } = {}
-- The companies that roll past: every one the spinner can give.
local fillers: { string } = {}
for _, company in Companies.list do
	local tier = Tiers.byId[company.tier]
	if tier and not tier.sharedOnly then
		table.insert(fillers, company.id)
	end
end

local SpinnerController = {}

local function numberAttribute(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

-- "Kittygram:Shiny,Megamart" into results.
function SpinnerController.parse(text: string): { Result }
	local results: { Result } = {}
	for _, entry in string.split(text, ",") do
		local companyId, variant = string.match(entry, "^([^:]+):?(.*)$")
		if companyId and Companies.byId[companyId] then
			table.insert(results, {
				companyId = companyId,
				variant = if variant and variant ~= "" and Variants.byId[variant] then variant else nil,
			})
		end
	end
	return results
end

local function newTile(parent: Instance): Tile
	local frame = Instance.new("Frame")
	frame.Name = "Tile"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local name = Make.label(frame, {
		font = Theme.Fonts.Display,
		colour = Theme.Colours.TextOnColour,
		outline = true,
	})
	name.Name = "Company"
	name.Position = UDim2.fromScale(0.05, 0.1)
	name.Size = UDim2.fromScale(0.9, 0.55)
	name.TextScaled = true
	local line = Make.label(frame, {
		font = Theme.Fonts.Body,
		colour = Theme.Colours.TextOnColour,
		outline = true,
	})
	line.Name = "Line"
	line.Position = UDim2.fromScale(0.05, 0.66)
	line.Size = UDim2.fromScale(0.9, 0.26)
	line.TextScaled = true
	return { frame = frame, name = name, line = line, shown = nil }
end

-- A reel's screen on one face of its part: a window that clips two tiles.
local function reelFace(part: BasePart, face: Enum.NormalId): { Tile }
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ReelScreen"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.MaxDistance = SCREEN_DISTANCE
	gui.LightInfluence = 0
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.Size = UDim2.fromScale(1, 1)
	window.BackgroundColor3 = Theme.Base.SpinnerScreen
	window.ClipsDescendants = true
	window.Parent = gui
	local tiles = { newTile(window), newTile(window) }
	gui.Parent = part
	return tiles
end

local function timerFace(part: BasePart, face: Enum.NormalId): (TextLabel, Frame)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TimerScreen"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.MaxDistance = SCREEN_DISTANCE
	gui.LightInfluence = 0
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Theme.Base.SpinnerScreen
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Theme.shade(Theme.Colours.Cash, 0.35)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local label = Make.label(back, {
		font = Theme.Fonts.Display,
		colour = Theme.Colours.TextOnColour,
		outline = true,
	})
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.ZIndex = 2
	gui.Parent = part
	return label, fill
end

-- What a reel shows at a place in its column: the previous result first,
-- the new one at the end, and companies rolling past in between, the same
-- on every screen for the same roll.
local function resultAt(fx: SpinnerFx, reel: number, place: number, last: number): Result?
	if place >= last then
		return fx.results[reel]
	end
	if place <= 0 then
		local before = fx.previous[reel]
		if before then
			return before
		end
	end
	if #fillers == 0 then
		return nil
	end
	local seed = math.floor(fx.rolledAt or 0)
	return { companyId = fillers[(place * 7 + reel * 11 + seed) % #fillers + 1], variant = nil }
end

local function showOnTile(tile: Tile, result: Result?, place: number)
	if tile.shown == place then
		return
	end
	tile.shown = place
	local company = if result then Companies.byId[result.companyId] else nil
	local tier = if company then Tiers.byId[company.tier] else nil
	local variant = if result and result.variant then Variants.byId[result.variant] else nil
	tile.frame.BackgroundColor3 = if tier then Theme.shade(tier.color, 0.15) else Theme.Base.SpinnerScreen
	tile.name.Text = if company then company.name else ""
	tile.line.Text = if variant and tier then `{variant.name} {tier.name}` elseif tier then tier.name else ""
	tile.line.TextColor3 = if variant then Theme.tint(variant.colour, 0.3) else Theme.Colours.TextOnColour
end

local function easeOut(t: number): number
	return 1 - (1 - t) ^ 3
end

-- Where a reel's column is (in places) at this moment: rolling from the
-- previous result at the roll to the new one at its stop.
function SpinnerController.placeOf(fx: SpinnerFx, reel: number, now: number): (number, number)
	local last = ROLL_PAST + (reel - 1) * MORE_PER_REEL
	local rolledAt = fx.rolledAt
	if rolledAt == nil then
		return last, last
	end
	local stopsAt = fx.landsAt - (#fx.reels - reel) * REEL_GAP
	local t = math.clamp((now - rolledAt) / math.max(stopsAt - rolledAt, 0.01), 0, 1)
	return last * easeOut(t), last
end

local function drawReels(fx: SpinnerFx, now: number)
	for index, reel in fx.reels do
		local place, last = SpinnerController.placeOf(fx, index, now)
		local whole = math.floor(place)
		local along = place - whole
		for _, face in reel.tiles do
			showOnTile(face[1], resultAt(fx, index, whole, last), whole)
			face[1].frame.Position = UDim2.fromScale(0, -along)
			showOnTile(face[2], resultAt(fx, index, whole + 1, last), whole + 1)
			face[2].frame.Position = UDim2.fromScale(0, 1 - along)
		end
	end
end

local function drawTimer(fx: SpinnerFx, now: number)
	local spinning = fx.rolledAt ~= nil and now < fx.landsAt
	local left = fx.nextRollAt - now
	local share = math.clamp(left / math.max(fx.nextRollAt - fx.landsAt, 0.01), 0, 1)
	for index, label in fx.timerLabels do
		label.Text = if fx.rolledAt == nil
			then "STOCK SPINNER"
			elseif spinning then "ROLLING!"
			else `NEXT ROLL {Format.duration(left)}`
		fx.timerFills[index].Size = UDim2.fromScale(if spinning or fx.rolledAt == nil then 0 else share, 1)
	end
end

local function drawBulbs(fx: SpinnerFx, now: number)
	local spinning = fx.rolledAt ~= nil and now < fx.landsAt
	local step = math.floor(now * CHASE_STEPS)
	for index, bulb in fx.bulbs do
		local lit = not spinning or (step + index) % 3 == 0
		bulb.Color = if lit then Theme.Base.Bulb else Theme.Base.BulbOff
	end
end

-- Pops over the reels when the player's own roll lands a Blue Chip or a
-- variant.
local function popLanding(fx: SpinnerFx, now: number)
	if fx.rolledAt == nil or now < fx.landsAt or fx.poppedFor == fx.landsAt then
		return
	end
	fx.poppedFor = fx.landsAt
	if fx.model:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	for index, result in fx.results do
		local reel = fx.reels[index]
		local company = Companies.byId[result.companyId]
		local variant = if result.variant then Variants.byId[result.variant] else nil
		if reel and company then
			local tier = Tiers.byId[company.tier]
			if variant then
				WorldPop.show(reel.part, POP_OFFSET, `{string.upper(variant.name)}!`, { colour = variant.colour })
			elseif tier and tier.id == TOP_TIER then
				WorldPop.show(reel.part, POP_OFFSET, `{string.upper(tier.name)}!`, { colour = tier.color })
			end
		end
	end
end

-- Takes in a new roll when the server's attributes change.
local function readRoll(fx: SpinnerFx, now: number)
	local rolledAt = numberAttribute(fx.model, "SpinnerRolledAt")
	if rolledAt == fx.rolledAt then
		return
	end
	local results = fx.model:GetAttribute("SpinnerResults")
	fx.previous = fx.results
	fx.results = if typeof(results) == "string" then SpinnerController.parse(results) else {}
	fx.rolledAt = rolledAt
	fx.landsAt = numberAttribute(fx.model, "SpinnerLandsAt") or now
	fx.nextRollAt = numberAttribute(fx.model, "SpinnerNextRollAt") or fx.landsAt
	for _, reel in fx.reels do
		for _, face in reel.tiles do
			for _, tile in face do
				tile.shown = nil
			end
		end
	end
	-- A roll that had already landed when first seen isn't popped.
	if fx.poppedFor == nil and now >= fx.landsAt then
		fx.poppedFor = fx.landsAt
	end
end

-- Finds the base's spinner once it's there (it can stream in), and sets
-- up its screens.
local function setUp(base: Model): SpinnerFx?
	local spinner = base:FindFirstChild("Spinner")
	local timer = spinner and spinner:FindFirstChild("Timer")
	if spinner == nil or timer == nil or not timer:IsA("BasePart") then
		return nil
	end
	local reels: { Reel } = {}
	for index = 1, SpinnerConfig.Results do
		local part = spinner:FindFirstChild(`Reel{index}`)
		if part == nil or not part:IsA("BasePart") then
			return nil
		end
		table.insert(reels, { part = part, tiles = {} })
	end
	local fx: SpinnerFx = {
		model = base,
		reels = reels,
		timerLabels = {},
		timerFills = {},
		bulbs = {},
		near = false,
		rolledAt = nil,
		landsAt = 0,
		nextRollAt = 0,
		results = {},
		previous = {},
		poppedFor = nil,
	}
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		for _, reel in reels do
			table.insert(reel.tiles, reelFace(reel.part, face))
		end
		local label, fill = timerFace(timer, face)
		table.insert(fx.timerLabels, label)
		table.insert(fx.timerFills, fill)
	end
	for _, child in spinner:GetChildren() do
		if child.Name == "Bulb" and child:IsA("BasePart") then
			table.insert(fx.bulbs, child)
		end
	end
	return fx
end

-- Draws one base's spinner at this moment (server time).
function SpinnerController.draw(fx: SpinnerFx, now: number)
	readRoll(fx, now)
	drawReels(fx, now)
	drawTimer(fx, now)
	popLanding(fx, now)
	if fx.near then
		drawBulbs(fx, now)
	end
end

-- Sets up any spinner not set up yet and works out which are near; the far
-- ones are drawn here, now and then, so they show what they rolled.
function SpinnerController.check(cameraPosition: Vector3, now: number)
	local map = workspace:FindFirstChild("Map")
	local bases = map and map:FindFirstChild("Bases")
	if bases then
		for _, base in bases:GetChildren() do
			if base:IsA("Model") and spinners[base] == nil then
				local fx = setUp(base)
				if fx then
					spinners[base] = fx
				end
			end
		end
	end
	for model, fx in spinners do
		if model.Parent == nil then
			spinners[model] = nil
			continue
		end
		local spawn = model:FindFirstChild("Spawn")
		local spot = if spawn and spawn:IsA("BasePart") then spawn.Position else model:GetPivot().Position
		fx.near = (spot - cameraPosition).Magnitude <= NEAR
		if not fx.near then
			SpinnerController.draw(fx, now)
		end
	end
end

-- Draws the near spinners for this frame.
function SpinnerController.step(now: number)
	for _, fx in spinners do
		if fx.near then
			SpinnerController.draw(fx, now)
		end
	end
end

function SpinnerController.get(base: Model): SpinnerFx?
	return spinners[base]
end

function SpinnerController:Start()
	RunService.RenderStepped:Connect(function()
		SpinnerController.step(workspace:GetServerTimeNow())
	end)
	while true do
		local camera = workspace.CurrentCamera
		if camera then
			SpinnerController.check(camera.CFrame.Position, workspace:GetServerTimeNow())
		end
		task.wait(CHECK_SECONDS)
	end
end

return SpinnerController
