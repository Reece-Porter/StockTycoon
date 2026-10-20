--!strict
-- A company's price and base income per second, worked out from its tier and
-- its own scales in Config/Companies.

local Companies = require(script.Parent.Config.Companies)
local Tiers = require(script.Parent.Config.Tiers)

local CompanyStats = {}

local function company(companyId: string): Companies.Company
	local found = Companies.byId[companyId]
	assert(found, `Unknown company "{companyId}"`)
	return found
end

-- Whole Cash.
function CompanyStats.price(companyId: string): number
	local found = company(companyId)
	return math.round(Tiers.byId[found.tier].price * found.priceScale)
end

-- Cash per second, to one decimal place.
function CompanyStats.income(companyId: string): number
	local found = company(companyId)
	return math.round(Tiers.byId[found.tier].income * found.incomeScale * 10) / 10
end

return CompanyStats
