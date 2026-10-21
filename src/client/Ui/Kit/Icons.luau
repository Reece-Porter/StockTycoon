--!strict
-- Simple icons drawn from UI shapes, until real icon images exist (each is
-- listed in docs/ASSETS_NEEDED.md). Each is a square frame of the given size
-- in pixels, in one colour with a dark outline, except Cash, which keeps its
-- own colours.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Make = require(script.Parent.Make)

export type IconName = "Cash" | "Padlock" | "Tick" | "Cross" | "Plus" | "Arrow" | "Home" | "Dot" | "Gem"

local Icons = {}

-- Every icon, for showing them all.
Icons.names = {} :: { IconName }
for _, name in { "Cash", "Padlock", "Tick", "Cross", "Plus", "Arrow", "Home", "Dot", "Gem" } do
	table.insert(Icons.names, name :: any)
end

local function shape(parent: GuiObject, centre: Vector2, size: Vector2, colour: Color3, outline: boolean): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(centre.X, centre.Y)
	frame.Size = UDim2.fromScale(size.X, size.Y)
	frame.BackgroundColor3 = colour
	frame.BorderSizePixel = 0
	if outline then
		Make.outline(frame, Theme.Colours.Ink, Theme.Stroke.Thin)
	end
	frame.Parent = parent
	return frame
end

-- A thick line with round ends from one point to another, both given as
-- fractions of the icon's size.
local function bar(parent: GuiObject, pixels: number, from: Vector2, to: Vector2, colour: Color3, outline: boolean)
	local a, b = from * pixels, to * pixels
	local delta = b - a
	local thickness = math.max(3, pixels * 0.16)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	frame.Size = UDim2.fromOffset(delta.Magnitude + thickness, thickness)
	frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	frame.BackgroundColor3 = colour
	frame.BorderSizePixel = 0
	Make.corner(frame)
	if outline then
		Make.outline(frame, Theme.Colours.Ink, Theme.Stroke.Thin)
	end
	frame.Parent = parent
end

-- The icon, pixels across, in colour (white if not given). Outlined unless
-- outline is false.
function Icons.make(name: IconName, pixels: number, colour: Color3?, outline: boolean?): Frame
	local tint = colour or Theme.Colours.TextOnColour
	local lined = outline ~= false
	local root = Instance.new("Frame")
	root.Name = `{name}Icon`
	root.Size = UDim2.fromOffset(pixels, pixels)
	root.BackgroundTransparency = 1

	if name == "Tick" then
		bar(root, pixels, Vector2.new(0.2, 0.55), Vector2.new(0.42, 0.76), tint, lined)
		bar(root, pixels, Vector2.new(0.42, 0.76), Vector2.new(0.82, 0.28), tint, lined)
	elseif name == "Cross" then
		bar(root, pixels, Vector2.new(0.25, 0.25), Vector2.new(0.75, 0.75), tint, lined)
		bar(root, pixels, Vector2.new(0.75, 0.25), Vector2.new(0.25, 0.75), tint, lined)
	elseif name == "Plus" then
		bar(root, pixels, Vector2.new(0.5, 0.2), Vector2.new(0.5, 0.8), tint, lined)
		bar(root, pixels, Vector2.new(0.2, 0.5), Vector2.new(0.8, 0.5), tint, lined)
	elseif name == "Arrow" then
		bar(root, pixels, Vector2.new(0.5, 0.82), Vector2.new(0.5, 0.24), tint, lined)
		bar(root, pixels, Vector2.new(0.5, 0.2), Vector2.new(0.24, 0.46), tint, lined)
		bar(root, pixels, Vector2.new(0.5, 0.2), Vector2.new(0.76, 0.46), tint, lined)
	elseif name == "Home" then
		local body = shape(root, Vector2.new(0.5, 0.66), Vector2.new(0.52, 0.42), tint, lined)
		Make.corner(body, 2)
		local door = shape(body, Vector2.new(0.5, 0.72), Vector2.new(0.3, 0.56), Theme.Colours.Ink, false)
		Make.corner(door, 2)
		bar(root, pixels, Vector2.new(0.12, 0.5), Vector2.new(0.5, 0.16), tint, lined)
		bar(root, pixels, Vector2.new(0.5, 0.16), Vector2.new(0.88, 0.5), tint, lined)
	elseif name == "Dot" then
		local dot = shape(root, Vector2.new(0.5, 0.5), Vector2.new(1, 1), colour or Theme.Colours.Danger, lined)
		Make.corner(dot)
	elseif name == "Gem" then
		local gem = shape(root, Vector2.new(0.5, 0.5), Vector2.new(0.62, 0.62), tint, lined)
		gem.Rotation = 45
		Make.corner(gem, 3)
		local shine = shape(gem, Vector2.new(0.35, 0.35), Vector2.new(0.3, 0.3), Theme.tint(tint, 0.6), false)
		Make.corner(shine, 2)
	elseif name == "Padlock" then
		-- The shackle is a thick round outline, mostly hidden behind the body.
		local shackle = shape(root, Vector2.new(0.5, 0.36), Vector2.new(0.48, 0.56), tint, false)
		shackle.BackgroundTransparency = 1
		Make.corner(shackle)
		Make.outline(shackle, tint, math.max(2, pixels * 0.11))
		local body = shape(root, Vector2.new(0.5, 0.68), Vector2.new(0.74, 0.5), tint, lined)
		-- In front of the shackle.
		body.ZIndex = 2
		Make.corner(body, math.max(2, math.floor(pixels * 0.1)))
		local keyhole = shape(body, Vector2.new(0.5, 0.45), Vector2.new(0.18, 0.3), Theme.Colours.Ink, false)
		Make.corner(keyhole)
	elseif name == "Cash" then
		local note = shape(root, Vector2.new(0.5, 0.5), Vector2.new(0.92, 0.62), Theme.Colours.Cash, true)
		Make.corner(note, math.max(2, math.floor(pixels * 0.12)))
		local sign = Make.label(note, {
			text = "$",
			font = Theme.Fonts.Display,
			colour = Theme.Colours.TextOnColour,
			outline = true,
		})
		sign.TextScaled = true
	end
	return root
end

return Icons
