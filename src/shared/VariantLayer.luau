--!strict
-- A company variant's look, as a layer over a copy of any company model
-- (docs/visual-pass.md, Phase 4). One function, apply, changes only the copy
-- it's given, never the stored model: the server uses it on every copy in
-- the world (CompanyModels) and the client on card pictures. Each variant's
-- look is in Config/Variants:
--   - the pun object's colours, material and shine, and round pieces made
--     blocky;
--   - glowing Neon seams round the biggest pieces;
--   - small accent pieces marked (an Accent attribute) for the client's hue
--     cycle;
--   - a few particles from an invisible box round the object (VariantFx);
--   - the floating badge's ring in the variant's colour.
-- Built models change only their Object, so the plinth keeps its tier
-- colour; a hand-made model without one changes all its visible parts. The
-- Rainbow and Glitched motion runs on the client (CompanyFxController). The
-- layer never adds a light, and keeps within the model's part budget.

local CompanyLooks = require(script.Parent.Config.CompanyLooks)
local Theme = require(script.Parent.Theme)
local Variants = require(script.Parent.Config.Variants)

local VariantLayer = {}

local SEAM_THICKNESS = 0.06
-- How far a seam stands out of its piece, as a share of the piece's size.
local SEAM_GROWTH = 1.04
-- Pieces shorter than this get no seam.
local SEAM_SMALLEST = 0.8
-- Room round the object for the particle box, in studs.
local FX_PADDING = 0.2
-- The biggest pieces up to this share of the object are its body; the rest
-- are accents.
local BODY_SHARE = 0.5

local function volume(part: BasePart): number
	return part.Size.X * part.Size.Y * part.Size.Z
end

local function sphereMesh(part: BasePart): SpecialMesh?
	local mesh = part:FindFirstChildWhichIsA("SpecialMesh")
	return if mesh and mesh.MeshType == Enum.MeshType.Sphere then mesh else nil
end

-- "Ball", "Cylinder", "Ellipsoid", "Block", "Wedge" and so on, or "Mesh".
local function shapeOf(part: BasePart): string
	if not part:IsA("Part") then
		return "Mesh"
	end
	if sphereMesh(part) then
		return "Ellipsoid"
	end
	return part.Shape.Name
end

-- The visible pieces the layer changes, biggest first: the Object of a built
-- model, or every visible part of a hand-made one.
local function targets(model: Model): { BasePart }
	local holder: Instance = model:FindFirstChild("Object") or model
	local list = {}
	for _, descendant in holder:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			table.insert(list, descendant)
		end
	end
	table.sort(list, function(a, b)
		return volume(a) > volume(b)
	end)
	return list
end

local function partCount(model: Model): number
	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

local function lightness(colour: Color3): number
	return 0.299 * colour.R + 0.587 * colour.G + 0.114 * colour.B
end

local function nearest(colour: Color3, palette: { Color3 }): Color3
	local best, bestDistance = colour, math.huge
	for _, candidate in palette do
		local distance = (colour.R - candidate.R) ^ 2 + (colour.G - candidate.G) ^ 2 + (colour.B - candidate.B) ^ 2
		if distance < bestDistance then
			best, bestDistance = candidate, distance
		end
	end
	return best
end

local function recoloured(colour: Color3, look: Variants.Look): Color3
	local palette, ramp = look.palette, look.ramp
	if look.recolour == "brighten" then
		return Theme.tint(colour, look.amount or 0.3)
	elseif look.recolour == "palette" and palette then
		return nearest(colour, palette)
	elseif look.recolour == "ramp" and ramp then
		return ramp[1]:Lerp(ramp[2], lightness(colour))
	end
	return colour
end

-- Balls, cylinders and stretched balls become blocks the same size.
local function makeBlocky(part: BasePart)
	if not part:IsA("Part") then
		return
	end
	local mesh = sphereMesh(part)
	if mesh then
		mesh:Destroy()
	end
	if part.Shape == Enum.PartType.Ball or part.Shape == Enum.PartType.Cylinder then
		local size, cframe = part.Size, part.CFrame
		part.Shape = Enum.PartType.Block
		part.Size = size
		part.CFrame = cframe
	end
end

local function plainPart(name: string, shape: Enum.PartType, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- A thin glowing ring round a piece (a crack in the rock), standing just
-- proud of its surface. Nil for pieces too small or of a shape it can't
-- follow.
local function seam(part: BasePart, index: number, colour: Color3): BasePart?
	local size = part.Size
	if math.max(size.X, size.Y, size.Z) < SEAM_SMALLEST then
		return nil
	end
	local shape = shapeOf(part)
	local crack: Part
	if shape == "Ball" then
		local diameter = size.X * SEAM_GROWTH
		local tilt = CFrame.Angles(math.rad(15 * index), 0, math.rad(25))
		crack = plainPart(
			"VariantSeam",
			Enum.PartType.Cylinder,
			Vector3.new(SEAM_THICKNESS, diameter, diameter),
			part.CFrame * tilt
		)
	elseif shape == "Ellipsoid" then
		crack = plainPart(
			"VariantSeam",
			Enum.PartType.Block,
			Vector3.new(size.X * SEAM_GROWTH, SEAM_THICKNESS, size.Z * SEAM_GROWTH),
			part.CFrame
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = crack
	elseif shape == "Cylinder" then
		crack = plainPart(
			"VariantSeam",
			Enum.PartType.Cylinder,
			Vector3.new(SEAM_THICKNESS, size.Y * SEAM_GROWTH, size.Z * SEAM_GROWTH),
			part.CFrame * CFrame.new(size.X * 0.15, 0, 0)
		)
	elseif shape == "Block" or shape == "Wedge" then
		crack = plainPart(
			"VariantSeam",
			Enum.PartType.Block,
			Vector3.new(size.X * 1.02, SEAM_THICKNESS, size.Z * 1.02),
			part.CFrame * CFrame.Angles(0, 0, math.rad(10))
		)
	else
		return nil
	end
	crack.Material = Enum.Material.Neon
	crack.Color = colour
	crack.Parent = part.Parent
	return crack
end

-- The pieces beyond the biggest ones that make up half the object, up to
-- wanted of them (or the smallest piece, if the object is all body).
local function chooseAccents(parts: { BasePart }, wanted: number): { BasePart }
	local total = 0
	for _, part in parts do
		total += volume(part)
	end
	local accents, body = {}, 0
	for _, part in parts do
		if body < total * BODY_SHARE then
			body += volume(part)
		elseif #accents < wanted and part.Material ~= Enum.Material.Neon then
			table.insert(accents, part)
		end
	end
	if #accents == 0 and #parts > 0 then
		table.insert(accents, parts[#parts])
	end
	return accents
end

local function sequence(colours: { Color3 }): ColorSequence
	if #colours == 1 then
		return ColorSequence.new(colours[1])
	end
	local keypoints = {}
	for index, colour in colours do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colours - 1), colour))
	end
	return ColorSequence.new(keypoints)
end

-- An invisible box round the pieces, for the particles to come out of.
local function particleBox(parts: { BasePart }): Part
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, part in parts do
		local half = part.Size / 2
		for _, corner in
			{
				Vector3.new(-1, -1, -1),
				Vector3.new(-1, -1, 1),
				Vector3.new(-1, 1, -1),
				Vector3.new(-1, 1, 1),
				Vector3.new(1, -1, -1),
				Vector3.new(1, -1, 1),
				Vector3.new(1, 1, -1),
				Vector3.new(1, 1, 1),
			}
		do
			local point = part.CFrame * (half * corner)
			low = low:Min(point)
			high = high:Max(point)
		end
	end
	local padding = Vector3.new(FX_PADDING, FX_PADDING, FX_PADDING) * 2
	local box = plainPart("VariantFx", Enum.PartType.Block, high - low + padding, CFrame.new((low + high) / 2))
	box.Transparency = 1
	return box
end

local function addParticles(box: BasePart, spec: Variants.Particles)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "VariantParticles"
	emitter.Color = sequence(spec.colours)
	emitter.Rate = spec.rate
	emitter.Lifetime = NumberRange.new(spec.lifetime[1], spec.lifetime[2])
	emitter.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
	emitter.LightEmission = spec.lightEmission
	if spec.rise then
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.SpreadAngle = Vector2.new(20, 20)
		emitter.Acceleration = Vector3.new(0, spec.rise, 0)
	else
		emitter.SpreadAngle = Vector2.new(180, 180)
	end
	if spec.twinkle then
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, spec.size),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new(0.2)
	else
		emitter.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.size), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	end
	if spec.square then
		-- No texture draws plain squares (a pixel texture would be better:
		-- docs/ASSETS_NEEDED.md).
		emitter.Texture = ""
		emitter.Rotation = NumberRange.new(0, 0)
	end
	emitter.Parent = box
end

-- The floating badge's ring in the variant's colour (a rainbow for Rainbow).
local function ringBadge(model: Model, variantId: string, colour: Color3)
	local object = model:FindFirstChild("Object")
	local anchor = object and object:FindFirstChild("Badge")
	local circle = anchor and anchor:FindFirstChild("Circle", true)
	local outline = circle and circle:FindFirstChildOfClass("UIStroke")
	if outline == nil then
		return
	end
	outline.Color = if variantId == "Rainbow" then Theme.Colours.Card else colour
	outline.Thickness = Theme.Stroke.Thick
	if variantId == "Rainbow" then
		local gradient = Instance.new("UIGradient")
		gradient.Color = Theme.RainbowGradient
		gradient.Parent = outline
	end
end

-- How many parts a variant may still add to this model and stay in budget.
local function room(model: Model, look: Variants.Look): number
	local spare = CompanyLooks.MaxParts - partCount(model)
	if look.particles then
		spare -= 1
	end
	local glitch = look.glitch
	if glitch then
		spare -= glitch.ghostPieces * #glitch.ghostColours
	end
	return math.max(spare, 0)
end

-- How many pieces the client may ghost at once, in budget.
function VariantLayer.ghostPieces(model: Model, look: Variants.Look): number
	local glitch = look.glitch
	if glitch == nil then
		return 0
	end
	local spare = CompanyLooks.MaxParts - partCount(model)
	return math.clamp(math.floor(spare / #glitch.ghostColours), 0, glitch.ghostPieces)
end

-- Puts the variant's look over this copy of a company model. False if there
-- is no such variant.
function VariantLayer.apply(model: Model, variantId: string): boolean
	local variant = Variants.byId[variantId]
	if variant == nil then
		return false
	end
	local look = variant.look
	model:SetAttribute("Variant", variantId)
	local parts = targets(model)
	local spare = room(model, look)

	local tints = look.tints
	for index, part in parts do
		local neon = part.Material == Enum.Material.Neon
		part.Color = if neon and look.glow then look.glow else recoloured(part.Color, look)
		if tints and #tints > 0 then
			part.Color = part.Color:Lerp(tints[(index - 1) % #tints + 1], look.tintAmount or 0.2)
		end
		if not neon then
			if look.material then
				part.Material = look.material
			end
			if look.reflectance then
				part.Reflectance = look.reflectance
			end
		end
		if look.blocky then
			makeBlocky(part)
		end
	end

	local glow = look.glow or variant.colour
	local seams = math.min(look.cracks or 0, spare)
	local added = 0
	for index, part in parts do
		if added >= seams then
			break
		end
		if part.Material ~= Enum.Material.Neon and part.Transparency == 0 and seam(part, index, glow) then
			added += 1
		end
	end

	if look.accents then
		local accents = chooseAccents(parts, look.accents)
		for index, part in accents do
			part:SetAttribute("Accent", index)
			part.Color = Color3.fromHSV((index - 1) / #accents, 0.75, 1)
		end
	end

	local particles = look.particles
	if particles and #parts > 0 then
		local box = particleBox(parts)
		addParticles(box, particles)
		box.Parent = model
	end

	ringBadge(model, variantId, variant.colour)
	return true
end

return VariantLayer
