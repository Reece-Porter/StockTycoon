--!strict
-- The Valuation Machine on this player's screen.
--
-- A "Put in machine" prompt sits on the machine's Pad at their own base while
-- they carry a company; for one that has been valued before it's a respin,
-- with its price and the multiplier it has now. While a run is going, the
-- machine screen shows a live line chart that draws in as it goes (green
-- where the value rises, red where it falls), the current multiplier very
-- large with a gentle pulse, one huge Take button, and no countdown
-- (CLAUDE.md). The chart's height follows the highest value seen so far and
-- its width grows with time, so it never gives away the peak or how long is
-- left.
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
local Format = require(ReplicatedStorage.Shared.Format)
local MachinePath = require(ReplicatedStorage.Shared.MachinePath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local CompanyLabel = require(script.Parent.Parent.Ui.CompanyLabel)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Make = require(script.Parent.Parent.Ui.Kit.Make)

type Run = MachinePath.Params & { startedAt: number, companyId: string }

local SAMPLE_SECONDS = 0.25
local MIN_WINDOW_SECONDS = 8
local REDRAW_SECONDS = 1 / 30
local CLOSE_AFTER_SECONDS = 4
local LINE_THICKNESS = 5
local PANEL_MAX_SIZE = Vector2.new(580, 480)
local TAKE_HEIGHT = 76
local GRID_LINES = 4
-- The multiplier's pulse: how much it grows and how fast.
local PULSE_SIZE = 0.04
local PULSE_SPEED = 5

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

local function buildScreen()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Machine"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 150
	gui.Enabled = false

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Theme.Colours.Dim
	dim.BackgroundTransparency = Theme.DimTransparency
	dim.Active = true
	dim.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.94, 0.88)
	panel.BackgroundColor3 = Theme.Colours.Panel
	panel.Active = true
	Make.corner(panel, Theme.Corner.Large)
	Make.outline(panel, Theme.Colours.Ink, Theme.Stroke.Thick)
	panel.Parent = gui
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = PANEL_MAX_SIZE
	sizeLimit.Parent = panel

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, Theme.Size.HeaderHeight)
	header.BackgroundColor3 = Theme.Colours.Purple
	Make.corner(header, Theme.Corner.Large)
	header.Parent = panel
	local square = Instance.new("Frame")
	square.Position = UDim2.fromScale(0, 0.5)
	square.Size = UDim2.fromScale(1, 0.5)
	square.BackgroundColor3 = Theme.Colours.Purple
	square.BorderSizePixel = 0
	square.Parent = header
	local title = Make.label(header, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Button,
		colour = Theme.Colours.TextOnColour,
		outline = true,
		alignX = Enum.TextXAlignment.Left,
	})
	title.Position = UDim2.fromOffset(Theme.Size.Padding + 4, 0)
	title.Size = UDim2.new(1, -2 * Theme.Size.Padding, 1, 0)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.ZIndex = 2

	local top = Theme.Size.HeaderHeight + 4
	local multiplier = Make.label(panel, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Huge,
		colour = Theme.Chart.Rising,
		outline = true,
	})
	multiplier.Position = UDim2.fromOffset(0, top)
	multiplier.Size = UDim2.new(1, 0, 0, 64)
	local pulse = Instance.new("UIScale")
	pulse.Parent = multiplier

	local note = Make.label(panel, {
		size = Theme.TextSize.Small,
		colour = Theme.Colours.TextMuted,
	})
	note.Position = UDim2.fromOffset(0, top + 64)
	note.Size = UDim2.new(1, 0, 0, 20)

	local chartTop = top + 88
	local chart = Instance.new("Frame")
	chart.Position = UDim2.fromOffset(Theme.Size.Padding, chartTop)
	chart.Size = UDim2.new(1, -2 * Theme.Size.Padding, 1, -(chartTop + TAKE_HEIGHT + 2 * Theme.Size.Padding))
	chart.BackgroundColor3 = Theme.Chart.Background
	chart.ClipsDescendants = true
	Make.corner(chart, Theme.Corner.Medium)
	Make.outline(chart, Theme.Colours.Ink, Theme.Stroke.Normal)
	chart.Parent = panel
	for line = 1, GRID_LINES - 1 do
		local grid = Instance.new("Frame")
		grid.Position = UDim2.fromScale(0, line / GRID_LINES)
		grid.Size = UDim2.new(1, 0, 0, 1)
		grid.BackgroundColor3 = Theme.Chart.Grid
		grid.BorderSizePixel = 0
		grid.Parent = chart
	end

	local floorLabel = Make.label(chart, {
		text = formatMultiplier(MachinePath.FLOOR),
		size = Theme.TextSize.Small,
		colour = Theme.Colours.TextMuted,
		alignX = Enum.TextXAlignment.Left,
	})
	floorLabel.AnchorPoint = Vector2.new(0, 1)
	floorLabel.Position = UDim2.new(0, 6, 1, -4)
	floorLabel.Size = UDim2.fromOffset(60, 16)

	-- A line at 1.0x, where every run starts: below it, the company is
	-- worth less than before.
	local par = Instance.new("Frame")
	par.Name = "Par"
	par.AnchorPoint = Vector2.new(0, 0.5)
	par.Size = UDim2.new(1, 0, 0, 2)
	par.BackgroundColor3 = Theme.Colours.Gold
	par.BackgroundTransparency = 0.4
	par.BorderSizePixel = 0
	par.Parent = chart
	local parLabel = Make.label(par, {
		text = formatMultiplier(MachinePath.START),
		size = Theme.TextSize.Small,
		colour = Theme.Colours.Gold,
		alignX = Enum.TextXAlignment.Right,
	})
	parLabel.AnchorPoint = Vector2.new(1, 1)
	parLabel.Position = UDim2.new(1, -6, 0, -2)
	parLabel.Size = UDim2.fromOffset(60, 16)

	local take = Button.new({
		text = "TAKE",
		colour = Theme.Colours.Cash,
		size = UDim2.new(1, -2 * Theme.Size.Padding, 0, TAKE_HEIGHT),
		textSize = Theme.TextSize.Big,
	})
	take.Instance.AnchorPoint = Vector2.new(0.5, 1)
	take.Instance.Position = UDim2.new(0.5, 0, 1, -Theme.Size.Padding)
	take.Instance.Parent = panel

	gui.Parent = player:WaitForChild("PlayerGui")
	return {
		gui = gui,
		title = title,
		multiplier = multiplier,
		pulse = pulse,
		note = note,
		chart = chart,
		par = par,
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
		local multiplier = player:GetAttribute("CarryingMultiplier")
		if company and valued then
			-- Again, for Cash: the new multiplier replaces this one.
			prompt.ActionText = `Respin {Format.cash(MachinePath.respinCost(company.tier))}`
			prompt.ObjectText = if typeof(multiplier) == "number"
				then `{company.name} ({formatMultiplier(multiplier)} now)`
				else company.name
		else
			prompt.ActionText = "Put in machine"
			prompt.ObjectText = if company then company.name else ""
		end
		local stolen = player:GetAttribute("CarryingStolen") == true
		prompt.Enabled = company ~= nil and not stolen and player:GetAttribute("MachineRun") == nil
	end
	prompt.Triggered:Connect(function()
		Remotes.StartValuation:FireServer()
	end)
	player:GetAttributeChangedSignal("CarryingCompanyId"):Connect(refresh)
	player:GetAttributeChangedSignal("CarryingValued"):Connect(refresh)
	player:GetAttributeChangedSignal("CarryingMultiplier"):Connect(refresh)
	player:GetAttributeChangedSignal("CarryingStolen"):Connect(refresh)
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
	local taking = false
	local lastDraw = 0

	local function segment(index: number): Frame
		local existing: Frame? = segments[index]
		if existing then
			return existing
		end
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = Theme.Chart.Rising
		line.BorderSizePixel = 0
		Make.corner(line)
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
		local previous = samples[#samples] or MachinePath.START
		screen.multiplier.TextColor3 = if value >= previous then Theme.Chart.Rising else Theme.Chart.Falling

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

		screen.par.Position =
			UDim2.new(0, 0, 1 - (MachinePath.START - MachinePath.FLOOR) / (top - MachinePath.FLOOR), 0)

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
			-- Screen y grows downwards, so a rise goes up the screen.
			line.BackgroundColor3 = if to.Y <= from.Y then Theme.Chart.Rising else Theme.Chart.Falling
			line.Position = UDim2.fromOffset(middle.X, middle.Y)
			line.Size = UDim2.fromOffset(delta.Magnitude + LINE_THICKNESS, LINE_THICKNESS)
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
		screen.multiplier.Text = formatMultiplier(MachinePath.START)
		screen.multiplier.TextColor3 = Theme.Chart.Rising
		screen.take.Instance.Visible = true
		screen.take.setEnabled(true)
		screen.take.setText("TAKE")
		taking = false
		screen.gui.Enabled = true
	end

	screen.take.Activated:Connect(function()
		local current = run
		if current == nil or finished or taking then
			return
		end
		seenAtPress = MachinePath.value(current, workspace:GetServerTimeNow() - current.startedAt)
		taking = true
		screen.take.setEnabled(false)
		screen.take.setText("Locking in...")
		Remotes.TakeValuation:FireServer()
	end)

	Remotes.ValuationFinished.OnClientEvent:Connect(function(value: number, timedOut: boolean)
		finished = true
		run = nil
		screen.multiplier.Text = `{formatMultiplier(value)} locked`
		screen.multiplier.TextColor3 = Theme.Chart.Rising
		screen.pulse.Scale = 1
		screen.take.Instance.Visible = false
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
		if current and not finished then
			screen.pulse.Scale = 1 + math.sin(now * PULSE_SPEED) * PULSE_SIZE
		end
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
