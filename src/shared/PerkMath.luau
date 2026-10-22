--!strict
-- Upgrade station maths (Config/Perks). Pure functions.

local Perks = require(script.Parent.Config.Perks)
local SpinnerConfig = require(script.Parent.Config.Spinner)

export type Levels = { [string]: number }

local PerkMath = {}

-- The level of one upgrade, 0 if never bought.
function PerkMath.level(levels: Levels?, perkId: Perks.PerkId): number
	return if levels then levels[perkId] or 0 else 0
end

-- What the upgrade multiplies by at this level, e.g. 1.3 for +30%.
function PerkMath.multiplier(perkId: Perks.PerkId, level: number): number
	local perk = Perks.byId[perkId]
	return 1 + perk.perLevel * math.clamp(level, 0, perk.maxLevel)
end

-- What the next level costs after this many, or nil at the top level.
function PerkMath.cost(perkId: Perks.PerkId, level: number): number?
	local perk = Perks.byId[perkId]
	if level >= perk.maxLevel then
		return nil
	end
	return math.floor(perk.baseCost * perk.costGrowth ^ level + 0.5)
end

-- Stock Spinner odds with Spinner Luck: every tier but the first (most
-- common) weighs luck times more. Returns a new list.
function PerkMath.luckyWeights(weights: { SpinnerConfig.WeightEntry }, luck: number): { SpinnerConfig.WeightEntry }
	local result = {}
	for index, entry in weights do
		table.insert(result, { tier = entry.tier, weight = if index == 1 then entry.weight else entry.weight * luck })
	end
	return result
end

return PerkMath
