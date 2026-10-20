--!strict
-- Turning "YYYY-MM-DD" dates into Unix times (UTC), for code expiry dates.

local Dates = {}

-- Days from 1970-01-01 to the given date (proleptic Gregorian calendar).
local function daysFromCivil(year: number, month: number, day: number): number
	local y = if month <= 2 then year - 1 else year
	local era = y // 400
	local yearOfEra = y - era * 400
	local monthFromMarch = (month + 9) % 12
	local dayOfYear = (153 * monthFromMarch + 2) // 5 + day - 1
	local dayOfEra = yearOfEra * 365 + yearOfEra // 4 - yearOfEra // 100 + dayOfYear
	return era * 146097 + dayOfEra - 719468
end

-- The Unix time of the last second of the date (23:59:59 UTC), or nil if it
-- isn't a valid "YYYY-MM-DD" date.
function Dates.endOfDay(date: string): number?
	local year, month, day = string.match(date, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	local y, m, d = tonumber(year), tonumber(month), tonumber(day)
	if y == nil or m == nil or d == nil or m < 1 or m > 12 or d < 1 or d > 31 then
		return nil
	end
	return daysFromCivil(y, m, d) * 86400 + 86399
end

return Dates
