--!strict
-- Weighted picks for conveyor spawns. Pure functions: the caller passes in the
-- random roll, a number from 0 up to (not including) 1, so the same code runs
-- in the game and in tests.

export type WeightEntry = { tier: string, weight: number }

local SpawnRoll = {}

-- Picks a tier, where each tier's chance is its weight divided by the total.
function SpawnRoll.pickTier(weights: { WeightEntry }, roll: number): string
	local total = 0
	for _, entry in weights do
		total += entry.weight
	end

	local target = roll * total
	for _, entry in weights do
		if target < entry.weight then
			return entry.tier
		end
		target -= entry.weight
	end
	return weights[#weights].tier
end

-- Picks a position in a list of count items, each equally likely.
function SpawnRoll.pickIndex(count: number, roll: number): number
	return math.clamp(math.floor(roll * count) + 1, 1, count)
end

return SpawnRoll
