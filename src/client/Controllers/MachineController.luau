--!strict
-- The Valuation Machine on this player's screen.
--
-- A "Put in machine" prompt sits on the machine's Pad at their own base while
-- they carry a company that hasn't been valued. While a run is going, the
-- machine screen shows a live line chart, the current multiplier in large text
-- and one big Take button, and no countdown (CLAUDE.md). The chart's height
-- follows the highest value seen so far and its width grows with time, so it
-- never gives away the peak or how long is left.
--
-- The path is drawn from the parameters the server sends in the MachineRun
-- attribute, using the same MachinePath maths. Take sends nothing but the
-- request; the server decides the value from its own clock and reports it.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local MachineConfig = require(ReplicatedStorage.Shared.Config.Machine)
local MachinePath = require(ReplicatedStorage.Shared.MachinePath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CompanyLabel = require(script.Parent.Parent.Ui.CompanyLabel)

type Run = MachinePath.Params & { startedAt: number, companyId: string }

local SAMPLE_SECONDS = 0.25
local MIN_WINDOW_SECONDS = 8
local REDRAW_SECONDS = 1 / 30
local CLOSE_AFTER_SECONDS = 4
local LINE_THICKNESS = 3
local LINE_COLOUR = Color3.fromRGB(110, 230, 140)
local BACKGROUND = Color3.fromRGB(20, 20, 25)
local PANEL_MAX_SIZE = Vector2.new(560, 460)

local player = Players.LocalPlayer

local MachineController = {}

local function readRun(): Run?
	local json = player:GetAttribute("MachineRun")
	if typeof(json) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and typeof(decoded) == "table" then decoded else nil
end

local function formatMultiplier(value: number): string
	return string.format("%.2fx", value)
end

local function text(parent: Instance, size: number, bold: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = if bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium
	label.TextSize = size
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = parent
	return label
end

local function buildScreen()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Machine"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 150
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.94, 0.8)
	panel.BackgroundColor3 = BACKGROUND
	panel.BackgroundTransparency = 0.05
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = PANEL_MAX_SIZE
	sizeLimit.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = text(panel, 18, true)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, 22)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(200, 200, 210)

	local multiplier = text(panel, 56, true)
	multiplier.Position = UDim2.fromOffset(16, 34)
	multiplier.Size = UDim2.new(1, -32, 0, 62)
	multiplier.TextColor3 = LINE_COLOUR

	local note = text(panel, 15, false)
	note.Position = UDim2.fromOffset(16, 96)
	note.Size = UDim2.new(1, -32, 0, 18)
	note.TextColor3 = Color3.fromRGB(180, 180, 190)

	local chart = Instance.new("Frame")
	chart.Position = UDim2.fromOffset(16, 118)
	chart.Size = UDim2.new(1, -32, 1, -202)
	chart.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	chart.ClipsDescendants = true
	chart.Parent = panel

	local floorLabel = text(chart, 13, false)
	floorLabel.AnchorPoint = Vector2.new(0, 1)
	floorLabel.Position = UDim2.new(0, 6, 1, -4)
	floorLabel.Size = UDim2.fromOffset(60, 16)
	floorLabel.TextXAlignment = Enum.TextXAlignment.Left
	floorLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
	floorLabel.Text = formatMultiplier(MachinePath.FLOOR)

	local take = Instance.new("TextButton")
	take.AnchorPoint = Vector2.new(0.5, 1)
	take.Position = UDim2.new(0.5, 0, 1, -12)
	take.Size = UDim2.new(1, -32, 0, 64)
	take.BackgroundColor3 = Color3.fromRGB(60, 170, 90)
	take.Font = Enum.Font.BuilderSansBold
	take.TextSize = 30
	take.TextColor3 = Color3.new(1, 1, 1)
	take.Text = "Take"
	take.Parent = panel

	local takeCorner = Instance.new("UICorner")
	takeCorner.CornerRadius = UDim.new(0, 10)
	takeCorner.Parent = take

	gui.Parent = player:WaitForChild("PlayerGui")
	return {
		gui = gui,
		title = title,
		multiplier = multiplier,
		note = note,
		chart = chart,
		take = take,
	}
end

local function setUpPrompt(pad: BasePart)
	if pad:FindFirstChild("MachinePrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MachinePrompt"
	prompt.ActionText = "Put in machine"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = MachineConfig.UseDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local function refresh()
		local carrying = player:GetAttribute("CarryingCompanyId")
		local company = if typeof(carrying) == "string" then Companies.byId[carrying] else nil
		local valued = player:GetAttribute("CarryingValued") == true
		prompt.ObjectText = if company then company.name else ""
		prompt.Enabled = company ~= nil and not valued and player:GetAttribute("MachineRun") == nil
	end
	prompt.Triggered:Connect(function()
		Remotes.StartValuation:FireServer()
	end)
	player:GetAttributeChangedSignal("CarryingCompanyId"):Connect(refresh)
	player:GetAttributeChangedSignal("CarryingValued"):Connect(refresh)
	player:GetAttributeChangedSignal("MachineRun"):Connect(refresh)
	refresh()
end

-- The Pad streams in and out with distance, so watch the Machine for it.
local function watchMachine(baseName: string)
	local base = workspace:WaitForChild("Map"):WaitForChild("Bases"):WaitForChild(baseName)
	local machine = base:WaitForChild("Machine")
	local function check(child: Instance)
		if child.Name == "Pad" and child:IsA("BasePart") then
			setUpPrompt(child)
		end
	end
	machine.ChildAdded:Connect(check)
	for _, child in machine:GetChildren() do
		check(child)
	end
end

function MachineController:Start()
	local screen = buildScreen()
	local segments: { Frame } = {}
	local samples: { number } = {}
	local run: Run? = nil
	local finished = false
	local seenAtPress: number? = nil
	local lastDraw = 0

	local function segment(index: number): Frame
		local existing: Frame? = segments[index]
		if existing then
			return existing
		end
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = LINE_COLOUR
		line.BorderSizePixel = 0
		line.Parent = screen.chart
		segments[index] = line
		return line
	end

	local function draw(current: Run, elapsed: number)
		while (#samples * SAMPLE_SECONDS) <= elapsed do
			table.insert(samples, MachinePath.value(current, #samples * SAMPLE_SECONDS))
		end
		local value = MachinePath.value(current, elapsed)
		screen.multiplier.Text = formatMultiplier(value)

		local points = table.clone(samples)
		local times = {}
		for index in points do
			times[index] = (index - 1) * SAMPLE_SECONDS
		end
		table.insert(points, value)
		table.insert(times, elapsed)

		local highest = MachinePath.FLOOR
		for _, point in points do
			highest = math.max(highest, point)
		end
		local top = math.max(1.5, MachinePath.FLOOR + (highest - MachinePath.FLOOR) * 1.25)
		local window = math.max(elapsed, MIN_WINDOW_SECONDS)
		local size = screen.chart.AbsoluteSize

		local function toPixels(index: number): Vector2
			local x = times[index] / window * size.X
			local y = size.Y - (points[index] - MachinePath.FLOOR) / (top - MachinePath.FLOOR) * size.Y
			return Vector2.new(x, y)
		end

		for index = 1, #points - 1 do
			local from, to = toPixels(index), toPixels(index + 1)
			local middle = (from + to) / 2
			local delta = to - from
			local line = segment(index)
			line.Visible = true
			line.Position = UDim2.fromOffset(middle.X, middle.Y)
			line.Size = UDim2.fromOffset(delta.Magnitude + 1, LINE_THICKNESS)
			line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		end
		for index = #points, #segments do
			segments[index].Visible = false
		end
	end

	local function open(newRun: Run)
		run = newRun
		finished = false
		seenAtPress = nil
		table.clear(samples)
		for _, line in segments do
			line.Visible = false
		end
		local company = Companies.byId[newRun.companyId]
		screen.title.Text = `Valuation Machine  ·  {if company then company.name else newRun.companyId}`
		screen.note.Text = "Press Take to lock in the multiplier."
		screen.multiplier.Text = formatMultiplier(MachinePath.FLOOR)
		screen.take.Visible = true
		screen.take.Active = true
		screen.take.Text = "Take"
		screen.gui.Enabled = true
	end

	screen.take.Activated:Connect(function()
		local current = run
		if current == nil or finished or not screen.take.Active then
			return
		end
		seenAtPress = MachinePath.value(current, workspace:GetServerTimeNow() - current.startedAt)
		screen.take.Active = false
		screen.take.Text = "Locking in..."
		Remotes.TakeValuation:FireServer()
	end)

	Remotes.ValuationFinished.OnClientEvent:Connect(function(value: number, timedOut: boolean)
		finished = true
		run = nil
		screen.multiplier.Text = `{formatMultiplier(value)} locked`
		screen.take.Visible = false
		local note = if timedOut then "Time ran out, so it kept the final value." else "Locked in."
		if player:GetAttribute("IsAdmin") == true and seenAtPress then
			note ..= `  (Admin: you pressed at {formatMultiplier(seenAtPress)})`
		end
		screen.note.Text = note
		task.delay(CLOSE_AFTER_SECONDS, function()
			if finished then
				screen.gui.Enabled = false
			end
		end)
	end)

	player:GetAttributeChangedSignal("MachineRun"):Connect(function()
		local newRun = readRun()
		if newRun then
			open(newRun)
		end
	end)
	local existing = readRun()
	if existing then
		open(existing)
	end

	RunService.RenderStepped:Connect(function()
		local current = run
		local now = os.clock()
		if current == nil or finished or now - lastDraw < REDRAW_SECONDS then
			return
		end
		lastDraw = now
		local elapsed = math.clamp(workspace:GetServerTimeNow() - current.startedAt, 0, current.duration)
		draw(current, elapsed)
	end)

	-- Labels for companies sitting in machines, on any base.
	local inMachines = workspace:WaitForChild("MachineCompanies")
	local function label(model: Instance)
		local companyId = model:GetAttribute("CompanyId")
		local tierId = model:GetAttribute("Tier")
		if model:IsA("Model") and typeof(companyId) == "string" and typeof(tierId) == "string" then
			CompanyLabel.attach(model, companyId, tierId, "In the machine")
		end
	end
	inMachines.ChildAdded:Connect(label)
	for _, model in inMachines:GetChildren() do
		label(model)
	end

	local function onBaseName()
		local baseName = player:GetAttribute("BaseName")
		if typeof(baseName) == "string" then
			task.spawn(watchMachine, baseName)
		end
	end
	player:GetAttributeChangedSignal("BaseName"):Connect(onBaseName)
	onBaseName()
end

return MachineController
