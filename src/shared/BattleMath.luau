--!strict
-- Battle arena maths (Config/Battle). Pure functions, so the server, the
-- board and tests share them.

local BattleConfig = require(script.Parent.Config.Battle)
local CompanyStats = require(script.Parent.CompanyStats)
local VariantMath = require(script.Parent.VariantMath)

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

-- Whether a player with total a (who joined order aOrder) is placed above
-- one with total b: the higher total, and on a tie whoever joined first.
function BattleMath.above(a: number, aOrder: number, b: number, bOrder: number): boolean
	if a ~= b then
		return a > b
	end
	return aOrder < bOrder
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
