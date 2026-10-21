--!strict
-- The Valuation Machine's displays in each base's front yard
-- (docs/visual-pass.md, Phase 5), drawn on each player's device for the
-- machines near the camera. Looks only, with made-up numbers: the machine's
-- real runs are on the player's own machine screen (MachineController).
--   - Screen: a little line chart that keeps moving (Ui/WorldScreens).
--   - Ticker: parody company names sliding past (Ui/WorldScreens).
--   - Light: the pillars' lights chase each other.
--   - While the base owner's machine run is going (their MachineRun
--     attribute), a scanner sweeps up and down the glass tube, the gauges'
--     needles swing, the lights chase faster and the beacon on top flashes.
--     Otherwise the needles just tick over.
-- The parts are from studio/BuildMap.luau (each base's Machine).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.Shared.Theme)
local WorldScreens = require(script.Parent.Parent.Ui.WorldScreens)

local CHECK_SECONDS = 0.5
-- A machine is near while the camera is this close to its pad.
local NEAR = 80
-- Seconds between light steps.
local LIGHT_STEP = 0.35
local RUNNING_LIGHT_STEP = 0.12
-- The scanner sweeps this high up the tube and back, in this many seconds.
local SCAN_HEIGHT = 6.3
local SCAN_SECONDS = 2.4
local SCANNER_TRANSPARENCY = 0.45
-- Needle angles in degrees: resting with a small tick, or swinging.
local NEEDLE_REST = -40
local NEEDLE_TICK = 6
local NEEDLE_SWING = 70
local BEACON_SECONDS = 0.5

type Needle = { part: BasePart, hub: CFrame, half: number }

type Display = {
	machine: Instance,
	base: Instance?,
	pad: BasePart?,
	near: boolean,
	running: boolean,
	chart: WorldScreens.Chart?,
	ticker: WorldScreens.Ticker?,
	lights: { BasePart },
	nextLight: number,
	lightStep: number,
	scanner: BasePart?,
	scannerRest: CFrame?,
	needles: { Needle },
	beacon: BasePart?,
}

local displays: { [Instance]: Display } = {}

local MachineDisplayController = {}

local function setUp(machine: Instance)
	local display = displays[machine]
	if display == nil then
		display = {
			machine = machine,
			base = machine.Parent,
			near = false,
			running = false,
			lights = {},
			nextLight = 0,
			lightStep = 0,
			needles = {},
		}
		displays[machine] = display
	end
	if display.pad == nil then
		local pad = machine:FindFirstChild("Pad")
		if pad and pad:IsA("BasePart") then
			display.pad = pad
		end
	end
	if display.chart == nil then
		local screen = machine:FindFirstChild("Screen")
		if screen and screen:IsA("BasePart") then
			display.chart = WorldScreens.chart(screen, Enum.NormalId.Right)
		end
	end
	if display.ticker == nil then
		local tickerPart = machine:FindFirstChild("Ticker")
		if tickerPart and tickerPart:IsA("BasePart") then
			display.ticker = WorldScreens.ticker(tickerPart, Enum.NormalId.Right)
		end
	end
	if #display.lights == 0 then
		for _, child in machine:GetChildren() do
			if child.Name == "Light" and child:IsA("BasePart") then
				table.insert(display.lights, child)
			end
		end
	end
	if display.scanner == nil then
		local scanner = machine:FindFirstChild("Scanner")
		if scanner and scanner:IsA("BasePart") then
			display.scanner = scanner
			display.scannerRest = scanner.CFrame
		end
	end
	if #display.needles == 0 then
		for _, child in machine:GetChildren() do
			if child.Name == "Needle" and child:IsA("BasePart") then
				local half = child.Size.Y / 2
				table.insert(
					display.needles,
					{ part = child, hub = child.CFrame * CFrame.new(0, -half, 0), half = half }
				)
			end
		end
	end
	if display.beacon == nil then
		local beacon = machine:FindFirstChild("Beacon")
		if beacon and beacon:IsA("BasePart") then
			display.beacon = beacon
		end
	end
end

-- Whether the base's owner has a run going in this machine.
local function isRunning(display: Display): boolean
	local base = display.base
	local ownerId = base and base:GetAttribute("OwnerUserId")
	local owner = if typeof(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
	return owner ~= nil and owner:GetAttribute("MachineRun") ~= nil
end

local function setNeedle(needle: Needle, degrees: number)
	needle.part.CFrame = needle.hub * CFrame.Angles(0, 0, math.rad(degrees)) * CFrame.new(0, needle.half, 0)
end

function MachineDisplayController.check(cameraPosition: Vector3)
	local map = workspace:FindFirstChild("Map")
	local bases = map and map:FindFirstChild("Bases")
	if bases then
		for _, base in bases:GetChildren() do
			local machine = base:FindFirstChild("Machine")
			if machine then
				setUp(machine)
			end
		end
	end
	for machine, display in displays do
		if machine.Parent == nil then
			displays[machine] = nil
			continue
		end
		local pad = display.pad
		display.near = pad ~= nil and (pad.Position - cameraPosition).Magnitude <= NEAR
		local running = display.near and isRunning(display)
		if running ~= display.running then
			display.running = running
			local scanner, rest = display.scanner, display.scannerRest
			if scanner and rest and not running then
				scanner.Transparency = 1
				scanner.CFrame = rest
			end
			if display.beacon then
				display.beacon.Color = if running then Theme.Colours.Cash else Theme.shade(Theme.Colours.Cash, 0.6)
			end
		end
	end
end

function MachineDisplayController.step(now: number, delta: number)
	for _, display in displays do
		if not display.near then
			continue
		end
		if display.chart then
			WorldScreens.stepChart(display.chart, now)
		end
		if display.ticker then
			WorldScreens.stepTicker(display.ticker, delta)
		end
		local running = display.running
		local scanner, rest = display.scanner, display.scannerRest
		if running and scanner and rest then
			local height = (0.5 - 0.5 * math.cos(now / SCAN_SECONDS * 2 * math.pi)) * SCAN_HEIGHT
			scanner.Transparency = SCANNER_TRANSPARENCY
			scanner.CFrame = rest + Vector3.new(0, height, 0)
		end
		for index, needle in display.needles do
			local degrees = if running
				then math.sin(now * 3 + index) * NEEDLE_SWING
				else NEEDLE_REST + math.sin(now * 0.8 + index * 2) * NEEDLE_TICK
			setNeedle(needle, degrees)
		end
		local beacon = display.beacon
		if running and beacon then
			local on = math.floor(now / BEACON_SECONDS) % 2 == 0
			beacon.Color = if on then Theme.Colours.Cash else Theme.shade(Theme.Colours.Cash, 0.6)
		end
		if #display.lights > 0 and now >= display.nextLight then
			display.nextLight = now + (if running then RUNNING_LIGHT_STEP else LIGHT_STEP)
			display.lightStep += 1
			for index, light in display.lights do
				local lit = (index + display.lightStep) % 3 == 0
				light.Color = if lit then Theme.Colours.Cash else Theme.shade(Theme.Colours.Cash, 0.6)
			end
		end
	end
end

function MachineDisplayController:Start()
	local last = os.clock()
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		MachineDisplayController.step(now, now - last)
		last = now
	end)
	while true do
		local camera = workspace.CurrentCamera
		if camera then
			MachineDisplayController.check(camera.CFrame.Position)
		end
		task.wait(CHECK_SECONDS)
	end
end

return MachineDisplayController
