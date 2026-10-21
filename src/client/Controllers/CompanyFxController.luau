--!strict
-- Effects on company models, kept on the client and kept cheap for phones
-- (docs/visual-pass.md, Phase 3). The server tags every company model in the
-- world "Company" (CompanyModels). Within CompanyLooks.EffectsDistance of the
-- camera:
--   - their sparkles play (Monopoly auras and variant effects); further away
--     they stop;
--   - Monopoly models (the Idle attribute) slowly spin and bob their Object,
--     the pun object and badge above the plinth, while they stand on a belt,
--     a plot or the machine. Not while carried: those are welded to a
--     character, not anchored.
-- The spin is worked out from the model's pivot each frame, so it follows a
-- model sliding along a belt.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CompanyLooks = require(ReplicatedStorage.Shared.Config.CompanyLooks)

local TAG = "Company"
local CHECK_SECONDS = 0.5

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
}

local tracked: { [Model]: Tracked } = {}

local CompanyFxController = {}

local function track(instance: Instance)
	if not instance:IsA("Model") or tracked[instance] or not instance:IsDescendantOf(workspace) then
		return
	end
	local entry: Tracked = { model = instance, emitters = {}, near = true, phase = math.random() * 2 * math.pi }
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
	tracked[instance] = entry
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

-- Spins and bobs the near, standing Monopoly models for this moment.
function CompanyFxController.step(now: number)
	local spinSpeed = math.rad(CompanyLooks.IdleSpinSpeed)
	local bobHeight = CompanyLooks.IdleBobHeight
	local bobSpeed = 2 * math.pi / CompanyLooks.IdleBobSeconds
	for model, entry in tracked do
		local parts = entry.parts
		local plinth = model.PrimaryPart
		if parts == nil or not entry.near or plinth == nil or not plinth.Anchored then
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
