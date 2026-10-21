--!strict
-- Simple icons drawn from UI shapes, until real icon images exist (each is
-- listed in docs/ASSETS_NEEDED.md). Each is a square frame of the given size
-- in pixels, in one colour with a dark outline, except Cash, which keeps its
-- own colours.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Make = require(script.Parent.Make)

export type IconName =
	"Cash"
	| "Padlock"
	| "Tick"
	| "Cross"
	| "Plus"
	| "Arrow"
	| "Home"
	| "Dot"
	| "Gem"
	| "Box"
	| "Paw"
	| "Book"
	| "Gift"
	| "Rebirth"
	| "Weapon"
	| "Ticket"
	| "Bolt"

local Icons = {}

-- Every icon, for showing them all.
Icons.names = {} :: { IconName }
for _, name in
	{
		"Cash",
		"Padlock",
		"Tick",
		"Cross",
		"Plus",
		"Arrow",
		"Home",
		"Dot",
		"Gem",
		"Box",
		"Paw",
		"Book",
		"Gift",
		"Rebirth",
		"Weapon",
		"Ticket",
		"Bolt",
	}
do
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
-- fractions of the icon's size; width is a fraction too (0.16 if not given).
local function bar(
	parent: GuiObject,
	pixels: number,
	from: Vector2,
	to: Vector2,
	colour: Color3,
	outline: boolean,
	width: number?
)
	local a, b = from * pixels, to * pixels
	local delta = b - a
	local thickness = math.max(3, pixels * (width or 0.16))
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
	elseif name == "Box" then
		local body = shape(root, Vector2.new(0.5, 0.62), Vector2.new(0.72, 0.52), tint, lined)
		Make.corner(body, 2)
		local lid = shape(root, Vector2.new(0.5, 0.32), Vector2.new(0.84, 0.18), Theme.tint(tint, 0.25), lined)
		lid.ZIndex = 2
		Make.corner(lid, 2)
		local tape = shape(body, Vector2.new(0.5, 0.3), Vector2.new(0.16, 0.6), Theme.Colours.Ink, false)
		Make.corner(tape, 1)
	elseif name == "Paw" then
		local pad = shape(root, Vector2.new(0.5, 0.66), Vector2.new(0.46, 0.4), tint, lined)
		Make.corner(pad)
		for _, toe in
			{ Vector2.new(0.2, 0.42), Vector2.new(0.38, 0.24), Vector2.new(0.62, 0.24), Vector2.new(0.8, 0.42) }
		do
			local bean = shape(root, toe, Vector2.new(0.19, 0.21), tint, lined)
			Make.corner(bean)
		end
	elseif name == "Book" then
		local cover = shape(root, Vector2.new(0.54, 0.5), Vector2.new(0.6, 0.78), tint, lined)
		Make.corner(cover, 3)
		local spine = shape(root, Vector2.new(0.24, 0.5), Vector2.new(0.14, 0.78), Theme.shade(tint, 0.25), lined)
		Make.corner(spine, 2)
		local mark = shape(cover, Vector2.new(0.5, 0.42), Vector2.new(0.36, 0.26), Theme.Colours.Ink, false)
		mark.Rotation = 45
		Make.corner(mark, 2)
	elseif name == "Gift" then
		local body = shape(root, Vector2.new(0.5, 0.64), Vector2.new(0.72, 0.5), tint, lined)
		Make.corner(body, 2)
		local lid = shape(root, Vector2.new(0.5, 0.38), Vector2.new(0.84, 0.16), tint, lined)
		lid.ZIndex = 2
		Make.corner(lid, 2)
		local ribbon = shape(root, Vector2.new(0.5, 0.6), Vector2.new(0.14, 0.62), Theme.Colours.Ink, false)
		ribbon.ZIndex = 3
		for _, x in { 0.38, 0.62 } do
			local loop = shape(root, Vector2.new(x, 0.2), Vector2.new(0.2, 0.2), tint, false)
			loop.BackgroundTransparency = 1
			Make.corner(loop)
			Make.outline(loop, tint, math.max(2, pixels * 0.07))
		end
	elseif name == "Rebirth" then
		local ring = shape(root, Vector2.new(0.5, 0.52), Vector2.new(0.62, 0.62), tint, false)
		ring.BackgroundTransparency = 1
		Make.corner(ring)
		Make.outline(ring, tint, math.max(2, pixels * 0.12))
		bar(root, pixels, Vector2.new(0.66, 0.16), Vector2.new(0.84, 0.24), tint, lined)
		bar(root, pixels, Vector2.new(0.66, 0.16), Vector2.new(0.7, 0.36), tint, lined)
	elseif name == "Weapon" then
		bar(root, pixels, Vector2.new(0.24, 0.76), Vector2.new(0.76, 0.24), tint, lined, 0.28)
		bar(root, pixels, Vector2.new(0.28, 0.6), Vector2.new(0.4, 0.72), Theme.Colours.Ink, false, 0.07)
		bar(root, pixels, Vector2.new(0.6, 0.28), Vector2.new(0.72, 0.4), Theme.Colours.Ink, false, 0.07)
	elseif name == "Ticket" then
		local stub = shape(root, Vector2.new(0.5, 0.5), Vector2.new(0.86, 0.54), tint, lined)
		Make.corner(stub, 3)
		for _, x in { 0.04, 0.96 } do
			local notch = shape(stub, Vector2.new(x, 0.5), Vector2.new(0.14, 0.26), Theme.Colours.Ink, false)
			Make.corner(notch)
		end
		for _, y in { 0.22, 0.5, 0.78 } do
			local dash = shape(stub, Vector2.new(0.68, y), Vector2.new(0.05, 0.14), Theme.Colours.Ink, false)
			Make.corner(dash, 1)
		end
	elseif name == "Bolt" then
		bar(root, pixels, Vector2.new(0.62, 0.1), Vector2.new(0.36, 0.52), tint, lined, 0.18)
		bar(root, pixels, Vector2.new(0.36, 0.52), Vector2.new(0.66, 0.48), tint, lined, 0.18)
		bar(root, pixels, Vector2.new(0.66, 0.48), Vector2.new(0.4, 0.9), tint, lined, 0.18)
	end
	return root
end

return Icons
