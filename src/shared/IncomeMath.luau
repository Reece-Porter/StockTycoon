--!strict
-- Income per second, as set out in CLAUDE.md, with the variant and Money
-- Multiplier upgrade added since:
--
--   baseIncome x variant multiplier x valuationMultiplier x floor pet modifier
--   x rebirth multiplier x active reward boost x game pass multiplier
--   x Money Multiplier upgrade
--
-- Pure functions, so the server's payouts and any display use the same maths
-- and tests can check it.

local Types = require(script.Parent.Types)
local VariantMath = require(script.Parent.VariantMath)

type Company = Types.CompanyInstance

export type Multipliers = {
	-- Pet modifier for each floor number; floors not listed count as 1.
	floorPet: { [number]: number },
	rebirth: number,
	boost: number,
	gamePass: number,
	-- The Money Multiplier upgrade (PerkMath).
	upgrade: number,
}

local IncomeMath = {}

-- No pets, rebirths, boosts, game passes or upgrades.
function IncomeMath.noMultipliers(): Multipliers
	return { floorPet = {}, rebirth = 1, boost = 1, gamePass = 1, upgrade = 1 }
end

-- The floor number in a plot key such as "Floor2/Plot5".
function IncomeMath.floorOf(plotKey: string): number?
	return tonumber((string.match(plotKey, "^Floor(%d+)/")))
end

-- One company's income per second on the given floor.
function IncomeMath.company(company: Company, floor: number, multipliers: Multipliers): number
	return company.baseIncome
		* VariantMath.multiplier(company.variant)
		* company.valuationMultiplier
		* (multipliers.floorPet[floor] or 1)
		* multipliers.rebirth
		* multipliers.boost
		* multipliers.gamePass
		* multipliers.upgrade
end

-- Total income per second from every placed company, keyed by plot key.
function IncomeMath.total(placed: { [string]: Company }, multipliers: Multipliers): number
	local total = 0
	for plotKey, company in placed do
		total += IncomeMath.company(company, IncomeMath.floorOf(plotKey) or 1, multipliers)
	end
	return total
end

return IncomeMath
