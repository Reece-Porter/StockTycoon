--!strict
-- Builds a company's model from its look in Config/CompanyLooks, for
-- CompanyModels (docs/visual-pass.md, Phase 3). One builder for every
-- company, so they all have the same structure:
--
--   <company id> (Model; PrimaryPart Root)
--     Root: an invisible upright box filling the plinth. Roblox measures a
--       model's bounding box along its PrimaryPart's axes, and the plinth is
--       a cylinder turned on its side, so the PrimaryPart is this instead.
--       The pivot is its centre, and prompts and labels attach to it.
--     Plinth, and by tier: Step, Trim or a gold Edge, and Glow (a Neon ring
--       with the model's one PointLight)
--     Nameplate: a plaque on the plinth's front with the company's name
--     Object (Model): the pun object's pieces, and Badge, an invisible part
--       holding the floating logo badge (a BillboardGui, so it reads from
--       any side and from above)
--
-- Everything is anchored and can't be walked into, touched or hit by a
-- raycast; small, see-through and Neon pieces cast no shadow. Monopoly
-- models also get a few sparkles (Aura) and an Idle attribute, and
-- CompanyFxController spins and bobs their Object on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local CompanyLooks = require(ReplicatedStorage.Shared.Config.CompanyLooks)
local Theme = require(ReplicatedStorage.Shared.Theme)

local CompanyBuilder = {}

-- Stands a cylinder (which lies along x) up.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- How a cylinder is turned before its own turn, by the way it points.
local AXES: { [string]: CFrame } = {
	x = CFrame.new(),
	y = UPRIGHT,
	z = CFrame.Angles(0, math.rad(90), 0),
}

-- Which of the part's own faces ends up at the front or on top, by the way
-- a cylinder points.
local FACES: { [string]: { [string]: Enum.NormalId } } = {
	x = { Front = Enum.NormalId.Front, Top = Enum.NormalId.Top },
	y = { Front = Enum.NormalId.Front, Top = Enum.NormalId.Right },
	z = { Front = Enum.NormalId.Right, Top = Enum.NormalId.Top },
}

local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
	Wedge = Enum.PartType.Wedge,
	-- A block with a sphere mesh, which stretches with the part.
	Ellipsoid = Enum.PartType.Block,
}

-- How wide the nameplate is, as a share of the plinth's width, and its
-- tallest.
local NAMEPLATE_WIDTH = 0.55
local NAMEPLATE_HEIGHT = 0.42

-- The top ring sits this far below the plinth's top, so the two top faces
-- never flicker against each other.
local RING_DROP = 0.03

local function vector(values: { number }): Vector3
	return Vector3.new(values[1] or 0, values[2] or 0, values[3] or 0)
end

local function angles(degrees: { number }?): CFrame
	if degrees == nil then
		return CFrame.new()
	end
	return CFrame.Angles(math.rad(degrees[1] or 0), math.rad(degrees[2] or 0), math.rad(degrees[3] or 0))
end

local function newPart(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	colour: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	-- Shape first: a Ball keeps its sides equal.
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = math.max(size.X, size.Y, size.Z) >= CompanyLooks.SmallPiece
	part.Parent = parent
	return part
end

-- A cylinder standing up, centred at height y.
local function ring(parent: Instance, name: string, height: number, diameter: number, y: number, colour: Color3): Part
	return newPart(
		parent,
		name,
		Enum.PartType.Cylinder,
		Vector3.new(height, diameter, diameter),
		CFrame.new(0, y, 0) * UPRIGHT,
		colour
	)
end

local function corner(parent: GuiObject)
	local rounding = Instance.new("UICorner")
	rounding.CornerRadius = UDim.new(0.5, 0)
	rounding.Parent = parent
end

-- Text across one face of a part, kept low-resolution for phones and hidden
-- far away.
local function addText(part: BasePart, face: Enum.NormalId, text: string, colour: Color3, pixelsPerStud: number)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.MaxDistance = CompanyLooks.TextDistance
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.9, 0.85)
	label.BackgroundTransparency = 1
	label.Font = Theme.Fonts.Display
	label.TextScaled = true
	label.TextColor3 = colour
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

-- The floating logo badge: the company's letters in a ringed circle, always
-- facing the camera, sized in studs so it shrinks with distance like the
-- model.
local function addBadge(anchor: BasePart, badge: CompanyLooks.Badge)
	local size = CompanyLooks.BadgeSize
	local gui = Instance.new("BillboardGui")
	gui.Name = "Badge"
	gui.Size = UDim2.fromScale(size, size)
	gui.LightInfluence = 0
	gui.MaxDistance = CompanyLooks.BadgeDistance

	local circle = Instance.new("Frame")
	circle.Name = "Circle"
	circle.Size = UDim2.fromScale(1, 1)
	circle.BackgroundColor3 = badge.colour
	corner(circle)
	local outline = Instance.new("UIStroke")
	outline.Color = Theme.Colours.Ink
	outline.Thickness = Theme.Stroke.Normal
	outline.Parent = circle
	circle.Parent = gui

	local inner = Instance.new("Frame")
	inner.Name = "Ring"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.8, 0.8)
	inner.BackgroundTransparency = 1
	corner(inner)
	local ringLine = Instance.new("UIStroke")
	ringLine.Color = badge.ink
	ringLine.Transparency = 0.6
	ringLine.Thickness = Theme.Stroke.Thin
	ringLine.Parent = inner
	inner.Parent = circle

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Position = UDim2.fromScale(0.2, 0.12)
	shine.Size = UDim2.fromScale(0.3, 0.16)
	shine.BackgroundColor3 = Theme.Colours.Card
	shine.BackgroundTransparency = 0.55
	shine.Rotation = -20
	corner(shine)
	shine.Parent = circle

	local letters = Instance.new("TextLabel")
	letters.Name = "Letters"
	letters.AnchorPoint = Vector2.new(0.5, 0.5)
	letters.Position = UDim2.fromScale(0.5, 0.52)
	letters.Size = UDim2.fromScale(0.68, 0.5)
	letters.BackgroundTransparency = 1
	letters.Font = Theme.Fonts.Display
	letters.TextScaled = true
	letters.TextColor3 = badge.ink
	letters.Text = badge.text
	letters.Parent = circle

	gui.Parent = anchor
end

-- A few slow sparkles rising off the top of the plinth.
local function addAura(plinth: BasePart, top: number, colour: Color3)
	local holder = Instance.new("Attachment")
	holder.Name = "Aura"
	-- Upright at the top of the plinth, whatever way the cylinder is turned.
	holder.CFrame = plinth.CFrame:ToObjectSpace(CFrame.new(0, top, 0))
	holder.Parent = plinth

	local lifetime = CompanyLooks.AuraLifetime
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Rate = CompanyLooks.AuraRate
	sparkles.Lifetime = NumberRange.new(lifetime[1], lifetime[2])
	sparkles.Speed = NumberRange.new(1.5, 2.5)
	sparkles.SpreadAngle = Vector2.new(55, 55)
	sparkles.Drag = 1.5
	sparkles.Acceleration = Vector3.new(0, 0.5, 0)
	sparkles.LightEmission = 0.6
	sparkles.Color = ColorSequence.new(Theme.tint(colour, 0.5), Theme.Colours.Gold)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	sparkles.Parent = holder
end

-- The plinth in the tier's colour, with the tier's rings and the nameplate.
-- Returns its height.
local function buildPlinth(model: Model, company: Companies.Company): number
	local spec = CompanyLooks.plinths[company.tier] or CompanyLooks.plinths.Startup
	local colour = Theme.Tiers[company.tier] or Theme.Colours.Locked
	local diameter, height = spec.diameter, spec.height

	local root = newPart(
		model,
		"Root",
		Enum.PartType.Block,
		Vector3.new(diameter, height, diameter),
		CFrame.new(0, height / 2, 0),
		colour
	)
	root.Transparency = 1
	root.CastShadow = false
	model.PrimaryPart = root
	local plinth = ring(model, "Plinth", height, diameter, height / 2, colour)

	-- The plain band of the plinth's side, between its rings.
	local bandBottom, bandTop = 0, height
	if spec.step then
		local stepHeight = CompanyLooks.StepHeight
		ring(model, "Step", stepHeight, diameter + CompanyLooks.StepWidth, stepHeight / 2, Theme.shade(colour, 0.2))
		bandBottom = stepHeight
	end
	if spec.glow then
		local glowHeight = CompanyLooks.GlowHeight
		local glow = ring(
			model,
			"Glow",
			glowHeight,
			diameter + CompanyLooks.GlowWidth,
			bandBottom + glowHeight / 2,
			Theme.tint(colour, 0.35)
		)
		glow.Material = Enum.Material.Neon
		glow.CastShadow = false
		local light = Instance.new("PointLight")
		light.Color = colour
		light.Range = CompanyLooks.LightRange
		light.Brightness = CompanyLooks.LightBrightness
		light.Shadows = false
		light.Parent = glow
		bandBottom += glowHeight
	end
	if spec.gold or spec.trim then
		local ringHeight = CompanyLooks.RingHeight
		local gold = Theme.Colours.Gold
		-- On a gold plinth the edge is a deeper gold, so it still shows.
		local onGold = math.abs(colour.R - gold.R) + math.abs(colour.G - gold.G) + math.abs(colour.B - gold.B) < 0.1
		ring(
			model,
			if spec.gold then "Edge" else "Trim",
			ringHeight,
			diameter + CompanyLooks.RingWidth,
			height - RING_DROP - ringHeight / 2,
			if not spec.gold then Theme.tint(colour, 0.5) elseif onGold then Theme.shade(gold, 0.25) else gold
		)
		bandTop -= ringHeight + RING_DROP
	end
	if spec.aura then
		addAura(plinth, height, colour)
	end

	-- The nameplate: flat, so thick enough that its sides sink into the
	-- round plinth while its face stands just proud of it.
	local radius = diameter / 2
	local width = diameter * NAMEPLATE_WIDTH
	local plateHeight = math.min(NAMEPLATE_HEIGHT, (bandTop - bandBottom) * 0.8)
	local sag = radius - math.sqrt(radius * radius - (width / 2) ^ 2)
	local thickness = sag + 0.06
	local plate = newPart(
		model,
		"Nameplate",
		Enum.PartType.Block,
		Vector3.new(width, plateHeight, thickness),
		CFrame.new(0, (bandBottom + bandTop) / 2, -radius - 0.02 + thickness / 2),
		Theme.Colours.Card
	)
	addText(plate, Enum.NormalId.Front, company.name, Theme.Colours.Ink, CompanyLooks.NameplatePixelsPerStud)

	return height
end

-- The pun object's pieces on top of the plinth, and the badge floating over
-- them (or where the look says).
local function buildObject(model: Model, look: CompanyLooks.Look, top: number)
	local object = Instance.new("Model")
	object.Name = "Object"
	local base = CFrame.new(0, top, 0) * angles(look.tilt)
	local highest = top

	for index, piece in look.pieces do
		local shape: Enum.PartType? = SHAPES[piece.shape]
		local axis = piece.axis or "x"
		local turned: CFrame? = AXES[axis]
		if shape == nil or turned == nil then
			error(`[CompanyBuilder] {model.Name} piece {index}: unknown shape {piece.shape} or axis {axis}`)
		end
		local size = vector(piece.size)
		local cframe = base * CFrame.new(vector(piece.at)) * angles(piece.turn) * turned
		local part = newPart(object, `{piece.shape}{index}`, shape, size, cframe, piece.colour)
		if piece.shape == "Ellipsoid" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		part.Material = piece.material or Enum.Material.SmoothPlastic
		part.Transparency = piece.transparency or 0
		part.Reflectance = piece.reflectance or 0
		if part.Transparency > 0 or part.Material == Enum.Material.Neon then
			part.CastShadow = false
		end
		local text = piece.text
		if text then
			local face = FACES[axis][text.face] or Enum.NormalId.Front
			addText(part, face, text.text, text.colour, CompanyLooks.TextPixelsPerStud)
		end

		-- How high the piece reaches, turned.
		local reach = math.abs(cframe.RightVector.Y) * size.X / 2
			+ math.abs(cframe.UpVector.Y) * size.Y / 2
			+ math.abs(cframe.LookVector.Y) * size.Z / 2
		highest = math.max(highest, cframe.Position.Y + reach)
	end

	local size = CompanyLooks.BadgeSize
	local at = look.badge.at
	local badgeCFrame = if at
		then CFrame.new(0, top, 0) * CFrame.new(vector(at))
		else CFrame.new(0, highest + CompanyLooks.BadgeGap + size / 2, 0)
	local anchor =
		newPart(object, "Badge", Enum.PartType.Block, Vector3.new(size, size, 0.1), badgeCFrame, look.badge.colour)
	anchor.Transparency = 1
	anchor.CastShadow = false
	addBadge(anchor, look.badge)

	object.Parent = model
end

-- A plain box in the tier's colour, for a company with no look yet.
local function plainLook(company: Companies.Company): CompanyLooks.Look
	local colour = Theme.Tiers[company.tier] or Theme.Colours.Primary
	return {
		badge = { text = string.sub(company.name, 1, 2), colour = colour, ink = Theme.Colours.TextOnColour },
		pieces = {
			{ shape = "Block", size = { 1.8, 1.8, 1.8 }, at = { 0, 0.9, 0 }, colour = Theme.tint(colour, 0.3) },
		},
	}
end

-- Whether the company has its own look in Config/CompanyLooks.
function CompanyBuilder.hasLook(companyId: string): boolean
	return CompanyLooks.looks[companyId] ~= nil
end

-- The company's model, named by its id, not yet parented.
function CompanyBuilder.build(company: Companies.Company): Model
	local model = Instance.new("Model")
	model.Name = company.id
	local look = CompanyLooks.looks[company.id] or plainLook(company)
	local top = buildPlinth(model, company)
	buildObject(model, look, top)

	local spec = CompanyLooks.plinths[company.tier]
	model:SetAttribute("Built", true)
	if spec and spec.idle then
		model:SetAttribute("Idle", true)
	end
	return model
end

return CompanyBuilder
