--!strict
-- Small builders the UI kit shares: corners, outlines, padding, gradients and
-- text, all styled from Theme.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)

local Make = {}

-- Rounded corners; radius in pixels, or a fully round pill or circle with nil.
function Make.corner(parent: GuiObject, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(0.5, 0)
	corner.Parent = parent
	return corner
end

-- An outline round the edge of a frame or button.
function Make.outline(parent: GuiObject, colour: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = colour or Theme.Colours.Ink
	stroke.Thickness = thickness or Theme.Stroke.Normal
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = parent
	return stroke
end

-- A dark outline round the letters of some text.
function Make.textOutline(label: TextLabel | TextButton, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Theme.Colours.Ink
	stroke.Thickness = thickness or Theme.Stroke.Normal
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return stroke
end

function Make.padding(parent: GuiObject, pixels: number, horizontal: number?): UIPadding
	local padding = Instance.new("UIPadding")
	local across = horizontal or pixels
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.PaddingLeft = UDim.new(0, across)
	padding.PaddingRight = UDim.new(0, across)
	padding.Parent = parent
	return padding
end

-- Lighter at the top and a little darker at the bottom, over the frame's own
-- colour.
function Make.shine(parent: GuiObject): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = Theme.Shine
	gradient.Parent = parent
	return gradient
end

export type LabelProps = {
	text: string?,
	font: Enum.Font?,
	size: number?,
	colour: Color3?,
	-- An outline round the letters (for light text on colour).
	outline: boolean?,
	alignX: Enum.TextXAlignment?,
	wrapped: boolean?,
}

-- A see-through text label filling its parent unless sized otherwise.
function Make.label(parent: Instance, props: LabelProps): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = props.font or Theme.Fonts.Body
	label.TextSize = props.size or Theme.TextSize.Body
	label.TextColor3 = props.colour or Theme.Colours.Text
	label.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	label.TextWrapped = props.wrapped == true
	label.Text = props.text or ""
	if props.outline then
		Make.textOutline(label)
	end
	label.Parent = parent
	return label
end

-- A list layout for the frame's children.
function Make.list(parent: Instance, direction: Enum.FillDirection, gap: number?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap or Theme.Size.Gap)
	layout.Parent = parent
	return layout
end

return Make
