--!strict
-- Where the battle arena is (studio/BuildMap.luau builds it far out past the
-- city as Workspace.Map.Arena, with teleporter gates in the middle of the
-- street, Workspace.Map.ArenaGates): its parts by name, whether a point is
-- in it (no fighting there), and where its gates' pads are.

local Arena = {}

local box: { cframe: CFrame, half: Vector3 }? = nil

function Arena.model(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Arena")
end

-- One of the arena's parts (Join, Arrive, Exit, Board), or nil.
function Arena.part(name: string): BasePart?
	local arena = Arena.model()
	local part = arena and arena:FindFirstChild(name, true)
	return if part and part:IsA("BasePart") then part else nil
end

-- Whether a point is in the arena (anywhere over its floor, up to its
-- walls' height and a little above).
function Arena.contains(position: Vector3): boolean
	local arena = Arena.model()
	if arena == nil or not arena:IsA("Model") then
		return false
	end
	local found = box
	if found == nil then
		local cframe, size = arena:GetBoundingBox()
		found = { cframe = cframe, half = size / 2 + Vector3.new(0, 20, 0) }
		box = found
	end
	local offset = found.cframe:PointToObjectSpace(position)
	return math.abs(offset.X) <= found.half.X
		and math.abs(offset.Y) <= found.half.Y
		and math.abs(offset.Z) <= found.half.Z
end

-- The pads of the teleporter gates to the arena.
function Arena.gatePads(): { BasePart }
	local map = workspace:FindFirstChild("Map")
	local gates = map and map:FindFirstChild("ArenaGates")
	local pads = {}
	if gates then
		for _, gate in gates:GetChildren() do
			local pad = gate:FindFirstChild("Pad")
			if pad and pad:IsA("BasePart") then
				table.insert(pads, pad)
			end
		end
	end
	return pads
end

return Arena
