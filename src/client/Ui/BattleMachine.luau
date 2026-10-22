--!strict
-- The battle's Valuation Machine on the player's own screen (docs/design.md,
-- "Battle arena"): their total, the multiplier very large and what the
-- total would be at it, a chart that draws in as it goes (green rising, red
-- falling) with a gold line at 1.0x, and one big Take button. Drawn from the
-- run the server sent (MachinePath); Take sends only the request, and the
-- server decides the value from its own clock. No countdown, as at home.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattleMath = require(ReplicatedStorage.Shared.BattleMath)
local Format = require(ReplicatedStorage.Shared.Format)
local MachinePath = require(ReplicatedStorage.Shared.MachinePath)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Button = require(script.Parent.Kit.Button)
local Layout = require(script.Parent.Layout)
local Make = require(script.Parent.Kit.Make)

local DISPLAY_ORDER = 55
local WIDTH, HEIGHT = 460, 360
local SAMPLE_SECONDS = 0.25
local MIN_WINDOW_SECONDS = 6
local LINE_THICKNESS = 4

export type Run = MachinePath.Params & { startedAt: number, total: number }

export type Screen = {
	gui: ScreenGui,
	step: (now: number) -> boolean,
	close: () -> (),
	-- What the server locked (or nil if it isn't known yet).
	locked: (multiplier: number?) -> (),
}

local BattleMachine = {}

local function formatMultiplier(value: number): string
	return string.format("%.2fx", value)
end

function BattleMachine.open(playerGui: Instance, run: Run, onTake: () -> ()): Screen
	local gui = Instance.new("ScreenGui")
	gui.Name = "BattleMachine"
	gui.DisplayOrder = DISPLAY_ORDER
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local room = Layout.viewport().X / Layout.scale() - 2 * Theme.Layout.Margin
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.48)
	panel.Size = UDim2.fromOffset(math.min(WIDTH, room), HEIGHT)
	panel.BackgroundColor3 = Theme.Colours.Card
	Make.corner(panel, Theme.Corner.Large)
	Make.outline(panel, Theme.Colours.Ink, Theme.Stroke.Thick)
	Layout.scaled(panel)
	panel.Parent = gui

	local title = Make.label(panel, {
		text = `VALUATION MACHINE  ·  {Format.cash(run.total)}`,
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Button,
		colour = Theme.Colours.Text,
	})
	title.Name = "Title"
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 28)

	local multiplier = Make.label(panel, {
		text = formatMultiplier(MachinePath.START),
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Huge,
		colour = Theme.Chart.Rising,
		outline = true,
	})
	multiplier.Name = "Multiplier"
	multiplier.Position = UDim2.fromOffset(0, 36)
	multiplier.Size = UDim2.new(1, 0, 0, 56)

	local worth = Make.label(panel, {
		text = `= {Format.cash(run.total)}`,
		size = Theme.TextSize.Body,
		colour = Theme.Colours.TextMuted,
	})
	worth.Name = "Worth"
	worth.Position = UDim2.fromOffset(0, 92)
	worth.Size = UDim2.new(1, 0, 0, 20)

	local chart = Instance.new("Frame")
	chart.Name = "Chart"
	chart.Position = UDim2.fromOffset(12, 118)
	chart.Size = UDim2.new(1, -24, 1, -118 - 84)
	chart.BackgroundColor3 = Theme.Chart.Background
	chart.ClipsDescendants = true
	Make.corner(chart, Theme.Corner.Medium)
	Make.outline(chart, Theme.Colours.Ink, Theme.Stroke.Normal)
	chart.Parent = panel
	local par = Instance.new("Frame")
	par.Name = "Par"
	par.AnchorPoint = Vector2.new(0, 0.5)
	par.Size = UDim2.new(1, 0, 0, 2)
	par.BackgroundColor3 = Theme.Colours.Gold
	par.BackgroundTransparency = 0.4
	par.BorderSizePixel = 0
	par.Parent = chart

	local take = Button.new({
		text = "TAKE",
		colour = Theme.Colours.Cash,
		size = UDim2.new(1, -24, 0, 64),
		textSize = Theme.TextSize.Big,
	})
	take.Instance.Name = "Take"
	take.Instance.AnchorPoint = Vector2.new(0.5, 1)
	take.Instance.Position = UDim2.new(0.5, 0, 1, -12)
	take.Instance.Parent = panel

	gui.Parent = playerGui

	local open = true
	local done = false
	local samples: { number } = {}
	local segments: { Frame } = {}

	local function close()
		if open then
			open = false
			gui:Destroy()
		end
	end

	local function locked(value: number?)
		done = true
		take.setEnabled(false)
		if value then
			multiplier.Text = formatMultiplier(value)
			worth.Text = `= {Format.cash(BattleMath.afterMachine(run.total, value))}`
			take.setText("Locked in")
		else
			take.setText("Locking in...")
		end
	end

	take.Activated:Connect(function()
		if not done then
			locked(nil)
			onTake()
		end
	end)

	local function segment(index: number): Frame
		local existing = segments[index]
		if existing then
			return existing
		end
		local line = Instance.new("Frame")
		line.Name = "Line"
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.Parent = chart
		segments[index] = line
		return line
	end

	local function step(now: number): boolean
		if not open then
			return false
		end
		if done then
			return open
		end
		local elapsed = math.clamp(now - run.startedAt, 0, run.duration)
		while #samples * SAMPLE_SECONDS <= elapsed do
			table.insert(samples, MachinePath.value(run, #samples * SAMPLE_SECONDS))
		end
		local value = MachinePath.value(run, elapsed)
		multiplier.Text = formatMultiplier(value)
		local previous = samples[#samples] or MachinePath.START
		multiplier.TextColor3 = if value >= previous then Theme.Chart.Rising else Theme.Chart.Falling
		worth.Text = `= {Format.cash(BattleMath.afterMachine(run.total, value))}`

		local points = table.clone(samples)
		local times = {}
		for index in points do
			times[index] = (index - 1) * SAMPLE_SECONDS
		end
		table.insert(points, value)
		table.insert(times, elapsed)
		local highest = MachinePath.START
		for _, point in points do
			highest = math.max(highest, point)
		end
		local floor = MachinePath.FLOOR
		local top = math.max(1.5, floor + (highest - floor) * 1.25)
		local window = math.max(elapsed, MIN_WINDOW_SECONDS)
		local size = chart.AbsoluteSize
		par.Position = UDim2.fromScale(0, 1 - (MachinePath.START - floor) / (top - floor))
		local function toPixels(index: number): Vector2
			return Vector2.new(
				times[index] / window * size.X,
				size.Y - (points[index] - floor) / (top - floor) * size.Y
			)
		end
		for index = 1, #points - 1 do
			local from, to = toPixels(index), toPixels(index + 1)
			local delta = to - from
			local line = segment(index)
			line.Visible = true
			line.BackgroundColor3 = if to.Y <= from.Y then Theme.Chart.Rising else Theme.Chart.Falling
			line.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
			line.Size = UDim2.fromOffset(delta.Magnitude + LINE_THICKNESS, LINE_THICKNESS)
			line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		end
		if elapsed >= run.duration then
			locked(MachinePath.lock(MachinePath.value(run, run.duration)))
		end
		return open
	end

	return { gui = gui, step = step, close = close, locked = locked }
end

return BattleMachine
