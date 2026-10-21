--!strict
-- Builds a pet's model from its look in Config/PetLooks, for PetModels
-- (docs/visual-pass.md, Phase 7). One builder for every pet:
--
--   <pet id> (Model; PrimaryPart Root; tagged Pet)
--     Root: an invisible upright box at the pet's feet, so Roblox measures
--       the model's box upright and it stands on a slot by its feet.
--     The look's pieces.
--     By rarity (PetLooks.auras): AuraGlow, a Neon disc under the pet in the
--       rarity's colour, with sparkles (an Aura attachment) from Rare up and
--       a soft light from Legendary.
--
-- Everything is anchored and can't be walked into, touched or hit by a
-- raycast. PetFxController bobs and sways the pet and turns the sparkles off
-- far from the camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetLooks = require(ReplicatedStorage.Shared.Config.PetLooks)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Pieces = require(ReplicatedStorage.Shared.Pieces)
local Theme = require(ReplicatedStorage.Shared.Theme)

local TAG = "Pet"
local ROOT_SIZE = Vector3.new(1, 0.2, 1)
-- Stands a cylinder (which lies along x) up.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local PetBuilder = {}

local function addAura(model: Model, root: BasePart, aura: PetLooks.Aura, colour: Color3)
	local glow = Pieces.newPart(
		model,
		"AuraGlow",
		Enum.PartType.Cylinder,
		Vector3.new(PetLooks.GlowHeight, PetLooks.GlowDiameter, PetLooks.GlowDiameter),
		CFrame.new(0, PetLooks.GlowHeight / 2, 0) * UPRIGHT,
		colour
	)
	glow.Material = Enum.Material.Neon
	glow.Transparency = aura.glow
	glow.CastShadow = false
	if aura.light then
		local light = Instance.new("PointLight")
		light.Color = colour
		light.Range = PetLooks.LightRange
		light.Brightness = PetLooks.LightBrightness
		light.Shadows = false
		light.Parent = glow
	end
	if aura.sparkles > 0 then
		local holder = Instance.new("Attachment")
		holder.Name = "Aura"
		holder.Position = Vector3.new(0, 1.2, 0)
		holder.Parent = root
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Rate = aura.sparkles
		sparkles.Lifetime = NumberRange.new(1, 1.6)
		sparkles.Speed = NumberRange.new(0.8, 1.6)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Drag = 1.5
		sparkles.Acceleration = Vector3.new(0, 0.6, 0)
		sparkles.LightEmission = 0.7
		sparkles.Color = ColorSequence.new(Theme.tint(colour, 0.4), Theme.Colours.Card)
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
		sparkles.Parent = holder
	end
end

-- A plain round critter in the rarity's colour, for a pet with no look yet.
local function plainLook(colour: Color3): PetLooks.Look
	return {
		pieces = {
			Pieces.ball(1.8, { 0, 0.9, 0 }, colour),
			Pieces.ball(0.4, { -0.35, 1.15, -0.78 }, Theme.Colours.Ink),
			Pieces.ball(0.4, { 0.35, 1.15, -0.78 }, Theme.Colours.Ink),
		},
	}
end

-- Whether the pet has its own look in Config/PetLooks.
function PetBuilder.hasLook(petId: string): boolean
	return PetLooks.looks[petId] ~= nil
end

-- The pet's model, named by its id, not yet parented.
function PetBuilder.build(pet: Pets.Pet): Model
	local colour = Theme.Rarities[pet.rarity] or Theme.Colours.Locked
	local model = Instance.new("Model")
	model.Name = pet.id
	local root =
		Pieces.newPart(model, "Root", Enum.PartType.Block, ROOT_SIZE, CFrame.new(0, ROOT_SIZE.Y / 2, 0), colour)
	root.Transparency = 1
	root.CastShadow = false
	model.PrimaryPart = root

	local look = PetLooks.looks[pet.id] or plainLook(colour)
	for index, piece in look.pieces do
		Pieces.make(model, `{piece.shape}{index}`, piece, CFrame.new())
	end
	local aura = PetLooks.auras[pet.rarity]
	if aura then
		addAura(model, root, aura, colour)
	end

	model:SetAttribute("Built", true)
	model:SetAttribute("PetId", pet.id)
	model:SetAttribute("Rarity", pet.rarity)
	model:AddTag(TAG)
	return model
end

return PetBuilder
