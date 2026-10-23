--!strict
-- Rebirth requirements and rewards. Pure functions, so the server, the rebirth
-- screen and tests share them.

local RebirthConfig = require(script.Parent.Config.Rebirth)
local Types = require(script.Parent.Types)

local RebirthMath = {}

-- Cash needed for the next rebirth after this many.
function RebirthMath.cashRequired(rebirths: number): number
	return RebirthConfig.BaseCashRequired * RebirthConfig.CashRequiredGrowth ^ rebirths
end

function RebirthMath.incomeMultiplier(rebirths: number): number
	return 1 + RebirthConfig.IncomePerRebirth * rebirths
end

-- The companies (ids) the next rebirth, after this many, needs: one or two,
-- or none past the end of Config/Rebirth.RequiredCompanies.
function RebirthMath.requiredCompanies(rebirths: number): { string }
	return RebirthConfig.RequiredCompanies[rebirths + 1] or {}
end

-- Whether these companies include every one the next rebirth (after this
-- many) needs, any variant, and which of them are there.
function RebirthMath.hasRequired(
	companies: { Types.CompanyInstance },
	rebirths: number
): (boolean, { [string]: boolean })
	local owned: { [string]: boolean } = {}
	for _, company in companies do
		owned[company.companyId] = true
	end
	local found: { [string]: boolean } = {}
	local all = true
	for _, companyId in RebirthMath.requiredCompanies(rebirths) do
		found[companyId] = owned[companyId] == true
		all = all and found[companyId]
	end
	return all, found
end

-- The Luck rebirths give the Stock Spinner (SpinnerMath): 1, then
-- OddsGrowthPerRebirth more for each rebirth, counted up to MaxOddsRebirths.
function RebirthMath.luck(rebirths: number): number
	return 1 + RebirthConfig.OddsGrowthPerRebirth * math.clamp(rebirths, 0, RebirthConfig.MaxOddsRebirths)
end

return RebirthMath
