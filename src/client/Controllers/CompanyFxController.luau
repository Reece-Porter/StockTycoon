--!strict
-- Effects on company models, kept on the client and kept cheap for phones
-- (docs/visual-pass.md, Phases 3 and 4). The server tags every company model
-- in the world "Company" (CompanyModels). Within CompanyLooks.EffectsDistance
-- of the camera:
--   - their particles play (Monopoly auras and variants); further away they
--     stop;
--   - Monopoly models (the Idle attribute) slowly spin and bob their Object,
--     the pun object and badge above the plinth;
--   - Rainbow variants turn their accent pieces (the Accent attribute,
--     VariantLayer) smoothly round the colour wheel;
--   - Glitched variants now and then flicker and show a red and cyan ghost
--     copy of their biggest pieces, offset sideways, for a moment.
-- Motion only runs while the model stands on a belt, a plot or the machine,
-- not while carried (welded to a character, not anchored). The spin is
-- worked out from the model's pivot each frame, so it follows a model
-- sliding along a belt.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CompanyLooks = require(ReplicatedStorage.Shared.Config.CompanyLooks)
local VariantLayer = require(ReplicatedStorage.Shared.VariantLayer)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)

local TAG = "Company"
local CHECK_SECONDS = 0.5
-- Flickering pieces go this see-through for a moment.
local FLICKER_TRANSPARENCY = 0.7
-- Ghosts are this see-through.
local GHOST_TRANSPARENCY = 0.5
local RAINBOW_SATURATION = 0.75

type GlitchLook = {
	every: { number },
	lasts: number,
	ghostColours: { Color3 },
	ghostOffset: number,
	ghostPieces: number,
}

type Ghost = { part: BasePart, source: BasePart, side: number }

type Glitch = {
	look: GlitchLook,
	-- The visible pieces that can flicker, and the biggest few, which get
	-- ghosts.
	pieces: { BasePart },
	sources: { BasePart },
	nextAt: number?,
	endsAt: number?,
	ghosts: { Ghost },
	-- Flickering pieces and how see-through they were.
	flickered: { [BasePart]: number },
}

type Tracked = {
	model: Model,
	emitters: { ParticleEmitter },
	near: boolean,
	-- Monopoly models only: the Object's parts and where each sits from the
	-- model's pivot when still.
	parts: { BasePart }?,
	rest: { CFrame }?,
	-- So models side by side don't move in step.
	phase: number,
	-- Rainbow: the accent pieces in order, and seconds once round the wheel.
	accents: { BasePart }?,
	cycleSeconds: number,
	glitch: Glitch?,
}

local function visiblePieces(model: Model): { BasePart }
	local holder: Instance = model:FindFirstChild("Object") or model
	local list = {}
	for _, descendant in holder:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			table.insert(list, descendant)
		end
	end
	table.sort(list, function(a, b)
		return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
	end)
	return list
end

-- The variant's motion, if it has any.
local function addVariantMotion(entry: Tracked)
	local model = entry.model
	local variantId = model:GetAttribute("Variant")
	local variant = if typeof(variantId) == "string" then Variants.byId[variantId] else nil
	if variant == nil then
		return
	end
	local look = variant.look
	if look.accents then
		local accents: { [number]: BasePart } = {}
		for _, descendant in model:GetDescendants() do
			local index = descendant:GetAttribute("Accent")
			if descendant:IsA("BasePart") and typeof(index) == "number" then
				accents[index] = descendant
			end
		end
		local ordered = {}
		for index = 1, #accents do
			table.insert(ordered, accents[index])
		end
		entry.accents = ordered
		entry.cycleSeconds = look.cycleSeconds or entry.cycleSeconds
	end
	local glitch = look.glitch
	if glitch then
		local pieces = visiblePieces(model)
		local sources = {}
		for index = 1, math.min(VariantLayer.ghostPieces(model, look), #pieces) do
			table.insert(sources, pieces[index])
		end
		entry.glitch = {
			look = glitch,
			pieces = pieces,
			sources = sources,
			ghosts = {},
			flickered = {},
		}
	end
end

local tracked: { [Model]: Tracked } = {}

local CompanyFxController = {}

local function track(instance: Instance)
	if not instance:IsA("Model") or tracked[instance] or not instance:IsDescendantOf(workspace) then
		return
	end
	local entry: Tracked = {
		model = instance,
		emitters = {},
		near = true,
		phase = math.random() * 2 * math.pi,
		cycleSeconds = 4,
	}
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			table.insert(entry.emitters, descendant)
		end
	end
	local object = instance:FindFirstChild("Object")
	if instance:GetAttribute("Idle") == true and object then
		local parts = {}
		for _, descendant in object:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
		entry.parts = parts
	end
	addVariantMotion(entry)
	tracked[instance] = entry
end

local function endGlitch(glitch: Glitch, now: number)
	for part, transparency in glitch.flickered do
		part.Transparency = transparency
	end
	table.clear(glitch.flickered)
	for _, ghost in glitch.ghosts do
		ghost.part:Destroy()
	end
	table.clear(glitch.ghosts)
	glitch.endsAt = nil
	local every = glitch.look.every
	glitch.nextAt = now + every[1] + math.random() * (every[2] - every[1])
end

local function startGlitch(model: Model, glitch: Glitch, now: number)
	glitch.endsAt = now + glitch.look.lasts
	-- About a third of the pieces flicker.
	for _, part in glitch.pieces do
		if math.random() < 0.35 then
			glitch.flickered[part] = part.Transparency
			part.Transparency = math.max(part.Transparency, FLICKER_TRANSPARENCY)
		end
	end
	-- A ghost of each big piece in each colour, one to each side.
	for _, source in glitch.sources do
		for index, colour in glitch.look.ghostColours do
			local ghost = source:Clone()
			for _, child in ghost:GetChildren() do
				if not child:IsA("SpecialMesh") then
					child:Destroy()
				end
			end
			ghost.Name = "GlitchGhost"
			ghost.Color = colour
			ghost.Material = Enum.Material.Neon
			ghost.Transparency = GHOST_TRANSPARENCY
			ghost.Anchored = true
			ghost.CanCollide = false
			ghost.CanTouch = false
			ghost.CanQuery = false
			ghost.CastShadow = false
			ghost.Parent = model
			table.insert(glitch.ghosts, { part = ghost, source = source, side = if index % 2 == 1 then -1 else 1 })
		end
	end
end

-- Rainbow and Glitched motion for this moment.
local function stepVariant(entry: Tracked, now: number, moving: boolean)
	local accents = entry.accents
	if accents and moving then
		for index, part in accents do
			local hue = (now / entry.cycleSeconds + (index - 1) / #accents) % 1
			part.Color = Color3.fromHSV(hue, RAINBOW_SATURATION, 1)
		end
	end
	local glitch = entry.glitch
	if glitch == nil then
		return
	end
	if glitch.endsAt then
		local endsAt = glitch.endsAt :: number
		if not moving or now >= endsAt then
			endGlitch(glitch, now)
			return
		end
		local right = entry.model:GetPivot().RightVector
		for _, ghost in glitch.ghosts do
			ghost.part.CFrame = CFrame.new(right * ghost.side * glitch.look.ghostOffset) * ghost.source.CFrame
		end
	elseif moving then
		local nextAt = glitch.nextAt
		if nextAt == nil then
			local every = glitch.look.every
			glitch.nextAt = now + every[1] + math.random() * (every[2] - every[1])
		elseif now >= nextAt then
			startGlitch(entry.model, glitch, now)
		end
	end
end

local function untrack(instance: Instance)
	if instance:IsA("Model") then
		tracked[instance] = nil
	end
end

-- Sparkles on or off by distance from the camera.
function CompanyFxController.check(cameraPosition: Vector3)
	local reach = CompanyLooks.EffectsDistance
	for model, entry in tracked do
		if model.Parent == nil then
			tracked[model] = nil
			continue
		end
		local near = (model:GetPivot().Position - cameraPosition).Magnitude <= reach
		if near ~= entry.near then
			entry.near = near
			for _, emitter in entry.emitters do
				emitter.Enabled = near
			end
		end
	end
end

-- Spins and bobs the near, standing Monopoly models, and moves the variants,
-- for this moment.
function CompanyFxController.step(now: number)
	local spinSpeed = math.rad(CompanyLooks.IdleSpinSpeed)
	local bobHeight = CompanyLooks.IdleBobHeight
	local bobSpeed = 2 * math.pi / CompanyLooks.IdleBobSeconds
	for model, entry in tracked do
		local root = model.PrimaryPart
		local moving = entry.near and root ~= nil and root.Anchored
		stepVariant(entry, now, moving)
		local parts = entry.parts
		if parts == nil or not moving then
			continue
		end
		local pivot = model:GetPivot()
		local rest = entry.rest
		if rest == nil then
			local still = {}
			for index, part in parts do
				still[index] = pivot:ToObjectSpace(part.CFrame)
			end
			rest = still
			entry.rest = still
		end
		local lift = (math.sin(now * bobSpeed + entry.phase) + 1) / 2 * bobHeight
		local frame = pivot * CFrame.new(0, lift, 0) * CFrame.Angles(0, now * spinSpeed + entry.phase, 0)
		local cframes = table.create(#parts)
		for index, still in rest :: { CFrame } do
			cframes[index] = frame * still
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function CompanyFxController:Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)
	for _, instance in CollectionService:GetTagged(TAG) do
		track(instance)
	end

	RunService.RenderStepped:Connect(function()
		CompanyFxController.step(os.clock())
	end)

	while true do
		local camera = workspace.CurrentCamera
		if camera then
			CompanyFxController.check(camera.CFrame.Position)
		end
		task.wait(CHECK_SECONDS)
	end
end

return CompanyFxController
