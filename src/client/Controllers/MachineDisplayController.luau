--!strict
-- The Valuation Machine's displays in each base's front yard
-- (docs/visual-pass.md, Phase 5), drawn on each player's device for the
-- machines near the camera. Looks only, with made-up numbers: the machine's
-- real runs are on the player's own machine screen (MachineController).
--   - Screen: a little line chart that keeps moving, green going up and red
--     going down.
--   - Ticker: parody company names sliding past with an up or down arrow and
--     a percentage.
--   - Light: the cabinets' lights chase each other.
-- The parts are from studio/BuildMap.luau (each base's Machine).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)

local CHECK_SECONDS = 0.5
-- A machine is near while the camera is this close to its pad.
local NEAR = 80
local PIXELS_PER_STUD = 40
local SCREEN_DISTANCE = 70
local POINTS = 18
-- Seconds between new points on the chart, and between light steps.
local CHART_STEP = 0.6
local LIGHT_STEP = 0.35
local LINE_THICKNESS = 3
local TICKER_ITEMS = 8
local TICKER_ITEM_WIDTH = 150
-- Pixels a second the ticker slides.
local TICKER_SPEED = 40

type Ticker = { holder: Frame, items: { Frame }, offset: number }

type Display = {
	machine: Instance,
	pad: BasePart?,
	near: boolean,
	-- The chart: its values (0 to 1), segments and canvas size in pixels.
	values: { number },
	segments: { Frame },
	canvas: Vector2,
	nextPoint: number,
	ticker: Ticker?,
	lights: { BasePart },
	nextLight: number,
	lightStep: number,
}

local displays: { [Instance]: Display } = {}

local MachineDisplayController = {}

local function surface(part: BasePart, face: Enum.NormalId): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.MaxDistance = SCREEN_DISTANCE
	gui.LightInfluence = 0
	gui.Parent = part
	return gui
end

-- The next value on the chart: a small step, a bit more often up than down,
-- kept on the screen.
local function nextValue(last: number): number
	return math.clamp(last + (math.random() - 0.45) * 0.18, 0.08, 0.92)
end

local function drawChart(display: Display)
	local width, height = display.canvas.X, display.canvas.Y
	local stepX = width / (POINTS - 1)
	for index, segment in display.segments do
		local a, b = display.values[index], display.values[index + 1]
		local from = Vector2.new((index - 1) * stepX, height * (1 - a))
		local to = Vector2.new(index * stepX, height * (1 - b))
		local middle = (from + to) / 2
		local length = (to - from).Magnitude
		segment.Position = UDim2.fromOffset(middle.X, middle.Y)
		segment.Size = UDim2.fromOffset(length + 1, LINE_THICKNESS)
		segment.Rotation = math.deg(math.atan2(to.Y - from.Y, to.X - from.X))
		segment.BackgroundColor3 = if b >= a then Theme.Chart.Rising else Theme.Chart.Falling
	end
end

local function makeChart(display: Display, screen: BasePart)
	local gui = surface(screen, Enum.NormalId.Right)
	display.canvas = Vector2.new(screen.Size.Z, screen.Size.Y) * PIXELS_PER_STUD
	local area = Instance.new("Frame")
	area.Name = "Chart"
	area.Size = UDim2.fromScale(1, 1)
	area.BackgroundColor3 = Theme.Colours.Ink
	area.BorderSizePixel = 0
	area.ClipsDescendants = true
	area.Parent = gui
	for line = 1, 3 do
		local grid = Instance.new("Frame")
		grid.Name = "Grid"
		grid.Position = UDim2.fromScale(0, line / 4)
		grid.Size = UDim2.new(1, 0, 0, 1)
		grid.BackgroundColor3 = Theme.Colours.TextMuted
		grid.BackgroundTransparency = 0.6
		grid.BorderSizePixel = 0
		grid.Parent = area
	end
	local value = 0.5
	for _ = 1, POINTS do
		value = nextValue(value)
		table.insert(display.values, value)
	end
	for _ = 1, POINTS - 1 do
		local segment = Instance.new("Frame")
		segment.Name = "Line"
		segment.AnchorPoint = Vector2.new(0.5, 0.5)
		segment.BorderSizePixel = 0
		segment.Parent = area
		table.insert(display.segments, segment)
	end
	drawChart(display)
end

local function fillTickerItem(item: Frame)
	local company = Companies.list[math.random(1, #Companies.list)]
	local change = math.floor((math.random() * 11.8 - 4.9) * 10 + 0.5) / 10
	local up = change >= 0
	local colour = if up then Theme.Chart.Rising else Theme.Chart.Falling
	local name = item:FindFirstChild("Name")
	local percent = item:FindFirstChild("Change")
	local arrow = item:FindFirstChild("ArrowIcon")
	if name and name:IsA("TextLabel") then
		name.Text = company.name
	end
	if percent and percent:IsA("TextLabel") then
		percent.Text = `{if up then "+" else ""}{change}%`
		percent.TextColor3 = colour
	end
	if arrow and arrow:IsA("Frame") then
		arrow.Rotation = if up then 0 else 180
		for _, piece in arrow:GetDescendants() do
			if piece:IsA("Frame") and piece.BackgroundTransparency < 1 then
				piece.BackgroundColor3 = colour
			end
		end
	end
end

local function makeTicker(display: Display, tickerPart: BasePart)
	local gui = surface(tickerPart, Enum.NormalId.Right)
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Theme.Colours.Ink
	back.BorderSizePixel = 0
	back.ClipsDescendants = true
	back.Parent = gui
	local holder = Instance.new("Frame")
	holder.Name = "Items"
	holder.Size = UDim2.new(0, TICKER_ITEMS * TICKER_ITEM_WIDTH, 1, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = back
	local height = tickerPart.Size.Y * PIXELS_PER_STUD
	local items = {}
	for index = 1, TICKER_ITEMS do
		local item = Instance.new("Frame")
		item.Name = "Item"
		item.Position = UDim2.fromOffset((index - 1) * TICKER_ITEM_WIDTH, 0)
		item.Size = UDim2.new(0, TICKER_ITEM_WIDTH, 1, 0)
		item.BackgroundTransparency = 1
		item.Parent = holder
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.Position = UDim2.fromOffset(6, 0)
		name.Size = UDim2.new(0, 78, 1, 0)
		name.BackgroundTransparency = 1
		name.Font = Theme.Fonts.Display
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = Theme.Colours.TextOnColour
		name.Parent = item
		local arrow = Icons.make("Arrow", math.floor(height * 0.6), Theme.Chart.Rising, false)
		arrow.Name = "ArrowIcon"
		arrow.AnchorPoint = Vector2.new(0, 0.5)
		arrow.Position = UDim2.new(0, 86, 0.5, 0)
		arrow.Parent = item
		local change = Instance.new("TextLabel")
		change.Name = "Change"
		change.Position = UDim2.fromOffset(86 + math.floor(height * 0.6) + 4, 0)
		change.Size = UDim2.new(0, 50, 1, 0)
		change.BackgroundTransparency = 1
		change.Font = Theme.Fonts.Body
		change.TextScaled = true
		change.TextXAlignment = Enum.TextXAlignment.Left
		change.Parent = item
		fillTickerItem(item)
		table.insert(items, item)
	end
	display.ticker = { holder = holder, items = items, offset = 0 }
end

local function setUp(machine: Instance)
	local display = displays[machine]
	if display == nil then
		display = {
			machine = machine,
			near = false,
			values = {},
			segments = {},
			canvas = Vector2.zero,
			nextPoint = 0,
			lights = {},
			nextLight = 0,
			lightStep = 0,
		}
		displays[machine] = display
	end
	if display.pad == nil then
		local pad = machine:FindFirstChild("Pad")
		if pad and pad:IsA("BasePart") then
			display.pad = pad
		end
	end
	if #display.segments == 0 then
		local screen = machine:FindFirstChild("Screen")
		if screen and screen:IsA("BasePart") then
			makeChart(display, screen)
		end
	end
	if display.ticker == nil then
		local tickerPart = machine:FindFirstChild("Ticker")
		if tickerPart and tickerPart:IsA("BasePart") then
			makeTicker(display, tickerPart)
		end
	end
	if #display.lights == 0 then
		for _, child in machine:GetChildren() do
			if child.Name == "Light" and child:IsA("BasePart") then
				table.insert(display.lights, child)
			end
		end
	end
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
	end
end

function MachineDisplayController.step(now: number, delta: number)
	for _, display in displays do
		if not display.near then
			continue
		end
		if #display.segments > 0 and now >= display.nextPoint then
			display.nextPoint = now + CHART_STEP
			table.remove(display.values, 1)
			table.insert(display.values, nextValue(display.values[#display.values]))
			drawChart(display)
		end
		local ticker = display.ticker
		if ticker then
			ticker.offset -= TICKER_SPEED * delta
			-- An item that has slid off the left goes round to the end with a
			-- new company.
			while ticker.offset <= -TICKER_ITEM_WIDTH do
				ticker.offset += TICKER_ITEM_WIDTH
				local first = table.remove(ticker.items, 1) :: Frame
				fillTickerItem(first)
				table.insert(ticker.items, first)
				for index, item in ticker.items do
					item.Position = UDim2.fromOffset((index - 1) * TICKER_ITEM_WIDTH, 0)
				end
			end
			ticker.holder.Position = UDim2.fromOffset(math.floor(ticker.offset), 0)
		end
		if #display.lights > 0 and now >= display.nextLight then
			display.nextLight = now + LIGHT_STEP
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
