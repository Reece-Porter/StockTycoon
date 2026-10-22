--!strict
-- Rebirth requirements and rewards. Pure functions, so the server, the rebirth
-- screen and tests share them.

local RebirthConfig = require(script.Parent.Config.Rebirth)
local Tiers = require(script.Parent.Config.Tiers)
local Types = require(script.Parent.Types)

local RebirthMath = {}

-- Cash needed for the next rebirth after this many.
function RebirthMath.cashRequired(rebirths: number): number
	return RebirthConfig.BaseCashRequired * RebirthConfig.CashRequiredGrowth ^ rebirths
end

function RebirthMath.incomeMultiplier(rebirths: number): number
	return 1 + RebirthConfig.IncomePerRebirth * rebirths
end

local function tierRank(tierId: string): number
	for index, tier in Tiers.list do
		if tier.id == tierId then
			return index
		end
	end
	return 0
end

-- Whether any of these companies is of Config/Rebirth.RequiredTier or better.
function RebirthMath.hasRequiredTier(companies: { Types.CompanyInstance }): boolean
	local needed = tierRank(RebirthConfig.RequiredTier)
	for _, company in companies do
		if tierRank(company.tier) >= needed then
			return true
		end
	end
	return false
end

-- The Luck rebirths give the Stock Spinner (SpinnerMath): 1, then
-- OddsGrowthPerRebirth more for each rebirth, counted up to MaxOddsRebirths.
function RebirthMath.luck(rebirths: number): number
	return 1 + RebirthConfig.OddsGrowthPerRebirth * math.clamp(rebirths, 0, RebirthConfig.MaxOddsRebirths)
end

return RebirthMath
