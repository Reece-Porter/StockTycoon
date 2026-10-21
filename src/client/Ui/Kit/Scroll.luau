--!strict
-- Scrolling lists and grids for window bodies, with a little room round the
-- edge so outlines aren't cut off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Make = require(script.Parent.Make)

local EDGE_ROOM = 5

local Scroll = {}

local function frame(parent: Instance): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Theme.Colours.Ink
	scroll.ScrollBarImageTransparency = 0.4
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	Make.padding(scroll, EDGE_ROOM)
	scroll.Parent = parent
	return scroll
end

-- Children stacked top to bottom, in LayoutOrder.
function Scroll.list(parent: Instance, gap: number?): ScrollingFrame
	local scroll = frame(parent)
	local layout = Make.list(scroll, Enum.FillDirection.Vertical, gap or Theme.Size.Gap)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	return scroll
end

-- Children in a grid of cells this size, as many across as fit.
function Scroll.grid(parent: Instance, cellSize: UDim2, gap: number?): ScrollingFrame
	local scroll = frame(parent)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize
	grid.CellPadding = UDim2.fromOffset(gap or Theme.Size.Gap, gap or Theme.Size.Gap)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll
	return scroll
end

-- A heading inside a list.
function Scroll.heading(parent: Instance, text: string, order: number, colour: Color3?): TextLabel
	local label = Make.label(parent, {
		text = text,
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Body + 2,
		colour = colour or Theme.Colours.Text,
		alignX = Enum.TextXAlignment.Left,
	})
	label.Name = "Heading"
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, Theme.TextSize.Body + 12)
	if colour then
		Make.textOutline(label, Theme.Stroke.Thin)
	end
	return label
end

return Scroll
