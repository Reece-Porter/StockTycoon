--!strict
-- The Stock Spinner on every base (docs/design.md, "Stock Spinner";
-- SpinnerService on the server). The server rolls everything; this shows
-- it:
--   - On the player's own base, a Spin prompt on the machine's Console (the
--     start of the belt on a map from before the machine), shown while the
--     machine is ready. Pressing it asks the server to play (PlaySpinner).
--   - When the server says what the spin rolled (SpinnerRolled), the pop-up
--     with the reels (Ui/SpinnerPopup).
--   - On every base's machine, the same reels on its Screen from the base's
--     SpinnerRolledAt, SpinnerLandsAt, SpinnerReadyAt and SpinnerResults
--     attributes, with SPINNING!, READY or the time until it's ready under
--     them, and the bulbs chasing while it spins. Only machines near the
--     camera move; the rest just show what they rolled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpinnerConfig = require(ReplicatedStorage.Shared.Config.Spinner)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Reels = require(script.Parent.Parent.Ui.Reels)
local SpinnerPopup = require(script.Parent.Parent.Ui.SpinnerPopup)

local CHECK_SECONDS = 0.5
-- A machine is near while the camera is this close to its base's spawn.
local NEAR = 130
local PIXELS_PER_STUD = 40
local SCREEN_DISTANCE = 120
local CHASE_STEPS = 10

type Machine = {
	model: Model,
	reels: Reels.Reels,
	status: TextLabel,
	bulbs: { BasePart },
	roll: Reels.Roll,
	readyAt: number,
	near: boolean,
}

local player = Players.LocalPlayer
local machines: { [Model]: Machine } = {}
local popup: SpinnerPopup.Popup? = nil
local prompt: ProximityPrompt? = nil

local SpinnerController = {}

local function numberAttribute(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

local function myBase(): Model?
	local name = player:GetAttribute("BaseName")
	local map = workspace:FindFirstChild("Map")
	local bases = map and map:FindFirstChild("Bases")
	local base = if typeof(name) == "string" and bases then bases:FindFirstChild(name) else nil
	return if base and base:IsA("Model") then base else nil
end

-- Where the owner plays: the machine's Console, or the start of the belt.
local function consoleOf(base: Model): BasePart?
	local machine = base:FindFirstChild("Spinner")
	local console = machine and machine:FindFirstChild("Console")
	if console and console:IsA("BasePart") then
		return console
	end
	local conveyor = base:FindFirstChild("Conveyor")
	local start = conveyor and conveyor:FindFirstChild("Start")
	return if start and start:IsA("BasePart") then start else nil
end

-- Takes in a new roll when the base's attributes change.
local function readRoll(machine: Machine)
	local model = machine.model
	machine.readyAt = numberAttribute(model, "SpinnerReadyAt") or 0
	local rolledAt = numberAttribute(model, "SpinnerRolledAt")
	local roll = machine.roll
	if rolledAt == roll.rolledAt then
		return
	end
	local results = model:GetAttribute("SpinnerResults")
	roll.previous = roll.results
	roll.results = if typeof(results) == "string" then Reels.parse(results) else {}
	roll.rolledAt = rolledAt
	roll.landsAt = numberAttribute(model, "SpinnerLandsAt") or 0
	Reels.reset(machine.reels)
end

local function statusText(machine: Machine, now: number): string
	if machine.model:GetAttribute("OwnerUserId") == nil then
		return "STOCK SPINNER"
	elseif machine.roll.rolledAt and now < machine.roll.landsAt then
		return "SPINNING!"
	elseif now < machine.readyAt then
		return `READY IN {Format.duration(machine.readyAt - now)}`
	end
	return "READY"
end

-- Finds the base's machine once it's there (it can stream in), and puts
-- the reels on its screen.
local function setUp(base: Model): Machine?
	local spinner = base:FindFirstChild("Spinner")
	local screen = spinner and spinner:FindFirstChild("Screen")
	if spinner == nil or screen == nil or not screen:IsA("BasePart") then
		return nil
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SpinnerScreen"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.MaxDistance = SCREEN_DISTANCE
	gui.LightInfluence = 0
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Theme.Colours.Ink
	back.Parent = gui
	local area = Instance.new("Frame")
	area.Name = "ReelArea"
	area.Position = UDim2.fromScale(0.04, 0.06)
	area.Size = UDim2.fromScale(0.92, 0.66)
	area.BackgroundTransparency = 1
	area.Parent = back
	local reels = Reels.new(area, SpinnerConfig.Results, 8)
	local status = Make.label(back, {
		font = Theme.Fonts.Display,
		colour = Theme.Colours.Gold,
		outline = true,
	})
	status.Name = "Status"
	status.Position = UDim2.fromScale(0.04, 0.76)
	status.Size = UDim2.fromScale(0.92, 0.2)
	status.TextScaled = true
	gui.Parent = screen
	local bulbs = {}
	for _, child in spinner:GetChildren() do
		if child.Name == "Bulb" and child:IsA("BasePart") then
			table.insert(bulbs, child)
		end
	end
	return {
		model = base,
		reels = reels,
		status = status,
		bulbs = bulbs,
		roll = { rolledAt = nil, landsAt = 0, results = {}, previous = {} },
		readyAt = 0,
		near = false,
	}
end

-- Draws one machine at this moment (server time).
function SpinnerController.draw(machine: Machine, now: number)
	readRoll(machine)
	machine.reels:draw(machine.roll, now)
	machine.status.Text = statusText(machine, now)
	if machine.near then
		local spinning = machine.roll.rolledAt ~= nil and now < machine.roll.landsAt
		local chase = math.floor(now * CHASE_STEPS)
		for index, bulb in machine.bulbs do
			local lit = not spinning or (chase + index) % 3 == 0
			bulb.Color = if lit then Theme.Base.Bulb else Theme.Base.BulbOff
		end
	end
end

-- Shows the Spin prompt only while the player's machine is ready.
local function enablePrompt(now: number)
	local current = prompt
	local base = myBase()
	if current and base then
		local landsAt = numberAttribute(base, "SpinnerLandsAt") or 0
		local readyAt = numberAttribute(base, "SpinnerReadyAt") or 0
		current.Enabled = now >= landsAt and now >= readyAt
	end
end

-- The Spin prompt on the player's own machine, made once their base is
-- known (and again if it changes).
local function updatePrompt(now: number)
	local base = myBase()
	local console = if base then consoleOf(base) else nil
	local current = prompt
	if current and (console == nil or current.Parent ~= console) then
		current:Destroy()
		prompt = nil
		current = nil
	end
	if current == nil and console then
		local made = Instance.new("ProximityPrompt")
		made.Name = "SpinPrompt"
		made.ActionText = "Spin"
		made.ObjectText = "Stock Spinner"
		made.HoldDuration = 0
		made.MaxActivationDistance = SpinnerConfig.PlayDistance
		made.RequiresLineOfSight = false
		made.Triggered:Connect(function()
			Remotes.PlaySpinner:FireServer()
		end)
		made.Parent = console
		prompt = made
	end
	enablePrompt(now)
end

function SpinnerController.prompt(): ProximityPrompt?
	return prompt
end

-- The server's word on what this player's spin rolled: the pop-up.
function SpinnerController.rolled(text: string, rolledAt: number, landsAt: number, luck: number): SpinnerPopup.Popup?
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local open = popup
	if open then
		open.close()
	end
	-- The reels start from what the machine showed before.
	local base = myBase()
	local machine = if base then machines[base] else nil
	local previous = {}
	if machine then
		previous = if machine.roll.rolledAt == rolledAt then machine.roll.previous else machine.roll.results
	end
	local roll: Reels.Roll =
		{ rolledAt = rolledAt, landsAt = landsAt, results = Reels.parse(text), previous = previous }
	local made = SpinnerPopup.open(playerGui, roll, luck)
	popup = made
	return made
end

function SpinnerController.popup(): SpinnerPopup.Popup?
	return popup
end

-- Sets up any machine not set up yet, works out which are near (the far
-- ones are drawn here, now and then, so they show what they rolled) and
-- keeps the Spin prompt right.
function SpinnerController.check(cameraPosition: Vector3, now: number)
	local map = workspace:FindFirstChild("Map")
	local bases = map and map:FindFirstChild("Bases")
	if bases then
		for _, base in bases:GetChildren() do
			if base:IsA("Model") and machines[base] == nil then
				local machine = setUp(base)
				if machine then
					machines[base] = machine
				end
			end
		end
	end
	for model, machine in machines do
		if model.Parent == nil then
			machines[model] = nil
			continue
		end
		local spawn = model:FindFirstChild("Spawn")
		local spot = if spawn and spawn:IsA("BasePart") then spawn.Position else model:GetPivot().Position
		machine.near = (spot - cameraPosition).Magnitude <= NEAR
		if not machine.near then
			SpinnerController.draw(machine, now)
		end
	end
	updatePrompt(now)
end

-- Draws the near machines and the pop-up for this frame.
function SpinnerController.step(now: number)
	for _, machine in machines do
		if machine.near then
			SpinnerController.draw(machine, now)
		end
	end
	local open = popup
	if open and not open.step(now) then
		popup = nil
	end
	enablePrompt(now)
end

function SpinnerController.get(base: Model): Machine?
	return machines[base]
end

function SpinnerController:Start()
	Remotes.SpinnerRolled.OnClientEvent:Connect(
		function(text: unknown, rolledAt: unknown, landsAt: unknown, luck: unknown)
			if
				typeof(text) == "string"
				and typeof(rolledAt) == "number"
				and typeof(landsAt) == "number"
				and typeof(luck) == "number"
			then
				SpinnerController.rolled(text, rolledAt, landsAt, luck)
			end
		end
	)
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
