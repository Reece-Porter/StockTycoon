--!strict
-- Pets in the world (docs/visual-pass.md, Phase 7): every model tagged Pet in
-- the Workspace (pets in slots, the pet shop's counter). Near the camera each
-- gently bobs and sways on the spot and its sparkles run; far away it stays
-- still and its sparkles stop. Looks only, on each player's device.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetLooks = require(ReplicatedStorage.Shared.Config.PetLooks)

local TAG = "Pet"
local CHECK_SECONDS = 0.5

type Tracked = {
	model: Model,
	rest: CFrame,
	parts: { BasePart },
	offsets: { CFrame },
	emitters: { ParticleEmitter },
	phase: number,
	near: boolean,
}

local tracked: { [Model]: Tracked } = {}

local PetFxController = {}

local function track(instance: Instance)
	if not instance:IsA("Model") or tracked[instance] or not instance:IsDescendantOf(workspace) then
		return
	end
	local model = instance
	local rest = model:GetPivot()
	local entry: Tracked = {
		model = model,
		rest = rest,
		parts = {},
		offsets = {},
		emitters = {},
		-- Each pet bobs in its own time.
		phase = (rest.Position.X * 0.37 + rest.Position.Z * 0.61) % (2 * math.pi),
		near = false,
	}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Anchored then
			table.insert(entry.parts, descendant)
			table.insert(entry.offsets, rest:ToObjectSpace(descendant.CFrame))
		elseif descendant:IsA("ParticleEmitter") then
			table.insert(entry.emitters, descendant)
		end
	end
	tracked[model] = entry
end

function PetFxController.check(cameraPosition: Vector3)
	for _, instance in CollectionService:GetTagged(TAG) do
		track(instance)
	end
	for model, entry in tracked do
		if model.Parent == nil then
			tracked[model] = nil
			continue
		end
		local near = (entry.rest.Position - cameraPosition).Magnitude <= PetLooks.EffectsDistance
		if near ~= entry.near then
			entry.near = near
			for _, emitter in entry.emitters do
				emitter.Enabled = near
			end
		end
	end
end

-- Where the pet's pivot is at this moment: a little up and down, and a
-- little turned one way and the other.
function PetFxController.pose(rest: CFrame, now: number, phase: number): CFrame
	local bob = (math.sin(now / PetLooks.BobSeconds * 2 * math.pi + phase) + 1) / 2 * PetLooks.BobHeight
	local sway = math.rad(PetLooks.SwayDegrees) * math.sin(now / PetLooks.SwaySeconds * 2 * math.pi + phase)
	return rest * CFrame.new(0, bob, 0) * CFrame.Angles(0, sway, 0)
end

function PetFxController.step(now: number)
	local parts, cframes = {}, {}
	for _, entry in tracked do
		if not entry.near then
			continue
		end
		local pose = PetFxController.pose(entry.rest, now, entry.phase)
		for index, part in entry.parts do
			table.insert(parts, part)
			table.insert(cframes, pose * entry.offsets[index])
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function PetFxController:Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	RunService.RenderStepped:Connect(function()
		PetFxController.step(os.clock())
	end)
	while true do
		local camera = workspace.CurrentCamera
		if camera then
			PetFxController.check(camera.CFrame.Position)
		end
		task.wait(CHECK_SECONDS)
	end
end

return PetFxController
