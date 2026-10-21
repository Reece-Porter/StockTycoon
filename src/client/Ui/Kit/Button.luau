--!strict
-- The chunky button every screen uses: rounded, thick dark outline, lighter
-- at the top, a darker shadow underneath, white text with a dark outline and
-- an optional icon to the left of the label. It squashes a little when
-- pressed and, with a mouse, grows a little on hover.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Icons = require(script.Parent.Icons)
local Make = require(script.Parent.Make)

export type Props = {
	text: string?,
	colour: Color3?,
	icon: Icons.IconName?,
	-- Defaults to a touch-friendly size.
	size: UDim2?,
	textSize: number?,
	layoutOrder: number?,
	-- The icon above a smaller label, for square menu buttons.
	stacked: boolean?,
}

export type Button = {
	-- The whole button, to position and parent.
	Instance: Frame,
	-- Fires when it's clicked or tapped (not while disabled).
	Activated: RBXScriptSignal,
	Label: TextLabel,
	setText: (text: string) -> (),
	setColour: (colour: Color3) -> (),
	setEnabled: (enabled: boolean) -> (),
}

local Button = {}

function Button.new(props: Props): Button
	local colour = props.colour or Theme.Colours.Primary
	local depth = Theme.Size.ShadowDepth

	local holder = Instance.new("Frame")
	holder.Name = "Button"
	holder.Size = props.size or UDim2.fromOffset(160, Theme.Size.ButtonHeight)
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = props.layoutOrder or 0
	local scale = Instance.new("UIScale")
	scale.Parent = holder

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Position = UDim2.fromOffset(0, depth)
	shadow.Size = UDim2.new(1, 0, 1, -depth)
	shadow.BackgroundColor3 = Theme.shade(colour, 0.35)
	shadow.ZIndex = 1
	Make.corner(shadow, Theme.Corner.Medium)
	Make.outline(shadow, Theme.Colours.Ink, Theme.Stroke.Thick)
	shadow.Parent = holder

	local face = Instance.new("TextButton")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -depth)
	face.BackgroundColor3 = colour
	face.AutoButtonColor = false
	face.Text = ""
	face.ZIndex = 2
	Make.corner(face, Theme.Corner.Medium)
	Make.outline(face, Theme.Colours.Ink, Theme.Stroke.Thick)
	Make.shine(face)
	face.Parent = holder

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.ZIndex = 3
	content.Parent = face
	local stacked = props.stacked == true
	local layout = Make.list(
		content,
		if stacked then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
		if stacked then 0 else 6
	)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	local textSize = props.textSize or (if stacked then Theme.TextSize.Small else Theme.TextSize.Button)
	if props.icon then
		local icon = Icons.make(props.icon, math.floor(textSize * (if stacked then 2 else 1.3)))
		icon.LayoutOrder = 1
		icon.Parent = content
	end
	local label = Make.label(content, {
		text = props.text,
		font = Theme.Fonts.Display,
		size = textSize,
		colour = Theme.Colours.TextOnColour,
		outline = true,
	})
	label.LayoutOrder = 2
	label.ZIndex = 3
	if stacked then
		label.Size = UDim2.new(1, -4, 0, textSize + 2)
		label.TextScaled = true
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = textSize
		fit.MinTextSize = 9
		fit.Parent = label
	else
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromScale(0, 1)
	end

	local enabled = true
	local hovering = false
	local function scaleTo(target: number, seconds: number)
		TweenService:Create(scale, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = target,
		}):Play()
	end
	local function rest()
		scaleTo(if hovering and enabled then Theme.Tween.HoverScale else 1, Theme.Tween.Press)
	end
	face.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if enabled and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
			scaleTo(Theme.Tween.PressScale, Theme.Tween.Press)
		end
	end)
	face.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			rest()
		end
	end)
	face.MouseEnter:Connect(function()
		hovering = true
		rest()
	end)
	face.MouseLeave:Connect(function()
		hovering = false
		rest()
	end)

	local current = colour
	local function paint()
		local shown = if enabled then current else Theme.Colours.Locked
		face.BackgroundColor3 = shown
		shadow.BackgroundColor3 = Theme.shade(shown, 0.35)
	end

	return {
		Instance = holder,
		Activated = face.Activated,
		Label = label,
		setText = function(text: string)
			label.Text = text
		end,
		setColour = function(newColour: Color3)
			current = newColour
			paint()
		end,
		setEnabled = function(isEnabled: boolean)
			enabled = isEnabled
			face.Interactable = isEnabled
			paint()
			rest()
		end,
	}
end

return Button
