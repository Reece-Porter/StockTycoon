--!strict
-- Screens drawn on parts in the world, only for looks (docs/visual-pass.md,
-- Phases 5 and 6, and the stock theme): a little line chart that keeps
-- moving (green going up, red going down) and a ticker of parody company
-- names sliding past with an up or down arrow and a percentage, both with
-- made-up numbers; and a base's quote board with its owner's real Cash per
-- second. Used on the Valuation Machine (MachineDisplayController), the
-- street (StreetFxController) and the market screens on bases and the
-- skyline (MarketScreensController). Each is built once, then stepped only
-- while the camera is near.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Icons = require(script.Parent.Kit.Icons)

local PIXELS_PER_STUD = 40
local MAX_DISTANCE = 70
local POINTS = 18
-- Seconds between new points on the chart.
local CHART_STEP = 0.6
local LINE_THICKNESS = 3
local TICKER_ITEMS = 8
local TICKER_ITEM_WIDTH = 150
-- Pixels a second the ticker slides.
local TICKER_SPEED = 40

export type Chart = {
	-- The chart's values (0 to 1), its line segments and its size in pixels.
	values: { number },
	segments: { Frame },
	canvas: Vector2,
	nextPoint: number,
}

export type Ticker = { holder: Frame, items: { Frame }, offset: number }

export type Quote = {
	symbol: TextLabel,
	price: TextLabel,
	change: TextLabel,
	chart: Chart,
}

-- How far away a screen is still drawn, if not MAX_DISTANCE.
export type Options = { distance: number? }

local WorldScreens = {}

-- The size in studs of one face of a part.
local function faceSize(part: BasePart, face: Enum.NormalId): Vector2
	local size = part.Size
	if face == Enum.NormalId.Right or face == Enum.NormalId.Left then
		return Vector2.new(size.Z, size.Y)
	elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
		return Vector2.new(size.X, size.Z)
	end
	return Vector2.new(size.X, size.Y)
end

local function surface(part: BasePart, face: Enum.NormalId, options: Options?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.MaxDistance = if options and options.distance then options.distance else MAX_DISTANCE
	gui.LightInfluence = 0
	gui.Parent = part
	return gui
end

-- The next value on the chart: a small step, a bit more often up than down,
-- kept on the screen.
local function nextValue(last: number): number
	return math.clamp(last + (math.random() - 0.45) * 0.18, 0.08, 0.92)
end

local function drawChart(chart: Chart)
	local width, height = chart.canvas.X, chart.canvas.Y
	local stepX = width / (POINTS - 1)
	for index, segment in chart.segments do
		local a, b = chart.values[index], chart.values[index + 1]
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

-- A chart filling a frame of this size in pixels.
local function chartIn(parent: Instance, canvas: Vector2): Chart
	local chart: Chart = {
		values = {},
		segments = {},
		canvas = canvas,
		nextPoint = 0,
	}
	local area = Instance.new("Frame")
	area.Name = "Chart"
	area.Size = UDim2.fromOffset(canvas.X, canvas.Y)
	area.BackgroundColor3 = Theme.Colours.Ink
	area.BorderSizePixel = 0
	area.ClipsDescendants = true
	area.Parent = parent
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
		table.insert(chart.values, value)
	end
	for _ = 1, POINTS - 1 do
		local segment = Instance.new("Frame")
		segment.Name = "Line"
		segment.AnchorPoint = Vector2.new(0.5, 0.5)
		segment.BorderSizePixel = 0
		segment.Parent = area
		table.insert(chart.segments, segment)
	end
	drawChart(chart)
	return chart
end

-- A chart on one face of the part.
function WorldScreens.chart(part: BasePart, face: Enum.NormalId, options: Options?): Chart
	local gui = surface(part, face, options)
	return chartIn(gui, faceSize(part, face) * PIXELS_PER_STUD)
end

-- Moves the chart on a point when it's time.
function WorldScreens.stepChart(chart: Chart, now: number)
	if now < chart.nextPoint then
		return
	end
	chart.nextPoint = now + CHART_STEP
	table.remove(chart.values, 1)
	table.insert(chart.values, nextValue(chart.values[#chart.values]))
	drawChart(chart)
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

-- A ticker on one face of the part, with enough companies to fill it.
function WorldScreens.ticker(part: BasePart, face: Enum.NormalId, options: Options?): Ticker
	local gui = surface(part, face, options)
	local count = math.max(TICKER_ITEMS, math.ceil(faceSize(part, face).X * PIXELS_PER_STUD / TICKER_ITEM_WIDTH) + 1)
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Theme.Colours.Ink
	back.BorderSizePixel = 0
	back.ClipsDescendants = true
	back.Parent = gui
	local holder = Instance.new("Frame")
	holder.Name = "Items"
	holder.Size = UDim2.new(0, count * TICKER_ITEM_WIDTH, 1, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = back
	local height = faceSize(part, face).Y * PIXELS_PER_STUD
	local items = {}
	for index = 1, count do
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
	return { holder = holder, items = items, offset = 0 }
end

-- Slides the ticker on by delta seconds. An item that has slid off the left
-- goes round to the end with a new company.
function WorldScreens.stepTicker(ticker: Ticker, delta: number)
	ticker.offset -= TICKER_SPEED * delta
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

-- A base's quote board on one face of the part: the owner's ticker symbol
-- and Cash per second along the top with how it has moved, and a line of
-- its recent values underneath.
function WorldScreens.quote(part: BasePart, face: Enum.NormalId, options: Options?): Quote
	local gui = surface(part, face, options)
	local size = faceSize(part, face) * PIXELS_PER_STUD
	local back = Instance.new("Frame")
	back.Name = "Quote"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Theme.Colours.Ink
	back.BorderSizePixel = 0
	back.Parent = gui
	local rowHeight = math.floor(size.Y * 0.36)
	local function label(name: string, x: number, width: number, font: Enum.Font, align: Enum.TextXAlignment)
		local text = Instance.new("TextLabel")
		text.Name = name
		text.Position = UDim2.fromOffset(math.floor(size.X * x), 4)
		text.Size = UDim2.fromOffset(math.floor(size.X * width), rowHeight)
		text.BackgroundTransparency = 1
		text.Font = font
		text.TextScaled = true
		text.TextXAlignment = align
		text.TextColor3 = Theme.Colours.TextOnColour
		text.Text = ""
		text.Parent = back
		return text
	end
	local symbol = label("Symbol", 0.03, 0.3, Theme.Fonts.Display, Enum.TextXAlignment.Left)
	local price = label("Price", 0.34, 0.38, Theme.Fonts.Display, Enum.TextXAlignment.Left)
	price.TextColor3 = Theme.Colours.Cash
	local change = label("Change", 0.73, 0.25, Theme.Fonts.Body, Enum.TextXAlignment.Right)
	local chartHolder = Instance.new("Frame")
	chartHolder.Name = "Line"
	chartHolder.Position = UDim2.fromOffset(math.floor(size.X * 0.03), rowHeight + 10)
	chartHolder.BackgroundTransparency = 1
	chartHolder.Parent = back
	local canvas = Vector2.new(math.floor(size.X * 0.94), math.floor(size.Y - rowHeight - 16))
	chartHolder.Size = UDim2.fromOffset(canvas.X, canvas.Y)
	return { symbol = symbol, price = price, change = change, chart = chartIn(chartHolder, canvas) }
end

-- Shows a quote: values are the owner's recent Cash per second, oldest
-- first. With no owner, the board says the base is free.
function WorldScreens.setQuote(quote: Quote, symbol: string?, values: { number })
	local latest = values[#values]
	if symbol == nil or latest == nil then
		quote.symbol.Text = if symbol then symbol else "FREE"
		quote.price.Text = if symbol then "..." else "Base for grabs"
		quote.change.Text = ""
		for _, segment in quote.chart.segments do
			segment.Visible = false
		end
		return
	end
	quote.symbol.Text = symbol
	quote.price.Text = `${Format.number(latest)}/s`
	local first = values[1]
	local up = latest >= first
	local percent = if first > 0 then (latest - first) / first * 100 else 0
	quote.change.Text = `{if up then "+" else "-"}{string.format("%.1f", math.abs(percent))}%`
	quote.change.TextColor3 = if up then Theme.Chart.Rising else Theme.Chart.Falling
	-- The line, scaled so its lowest and highest values fill the board.
	local chart = quote.chart
	local low, high = math.huge, -math.huge
	for _, value in values do
		low = math.min(low, value)
		high = math.max(high, value)
	end
	local span = high - low
	table.clear(chart.values)
	for index = 1, POINTS do
		local source = values[math.clamp(#values - POINTS + index, 1, #values)]
		table.insert(chart.values, if span > 0 then 0.1 + 0.8 * (source - low) / span else 0.5)
	end
	for _, segment in chart.segments do
		segment.Visible = true
	end
	drawChart(chart)
end

return WorldScreens
