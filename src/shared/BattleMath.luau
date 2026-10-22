--!strict
-- Battle arena maths (Config/Battle). Pure functions, so the server, the
-- board and tests share them.

local BattleConfig = require(script.Parent.Config.Battle)
local CompanyStats = require(script.Parent.CompanyStats)
local VariantMath = require(script.Parent.VariantMath)

export type Standing = { total: number, order: number }

local BattleMath = {}

-- What a stock is worth in a battle: its price, times its variant's
-- multiplier.
function BattleMath.value(companyId: string, variant: string?): number
	return CompanyStats.price(companyId) * VariantMath.multiplier(variant)
end

-- The value after the machine, rounded to the nearest Cash.
function BattleMath.afterMachine(total: number, multiplier: number): number
	return math.floor(total * multiplier + 0.5)
end

-- Sorts players by total, highest first; ties go to whoever joined first
-- (the lower order). Returns a new list.
function BattleMath.rank<T>(standings: { T & Standing }): { T & Standing }
	local sorted = table.clone(standings)
	table.sort(sorted, function(a, b)
		if a.total ~= b.total then
			return a.total > b.total
		end
		return a.order < b.order
	end)
	return sorted
end

-- The reward for finishing in this place (1 for first).
function BattleMath.reward(place: number): BattleConfig.Reward
	return BattleConfig.Rewards[place] or BattleConfig.OtherReward
end

-- "1st", "2nd", "3rd", "4th" ... "11th", "12th", "13th", "21st".
function BattleMath.ordinal(place: number): string
	local lastTwo = place % 100
	if lastTwo >= 11 and lastTwo <= 13 then
		return `{place}th`
	end
	local last = place % 10
	local suffix = if last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th"
	return `{place}{suffix}`
end

return BattleMath
