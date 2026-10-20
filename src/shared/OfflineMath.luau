--!strict
-- What a player's companies earn while they're away (Config/Offline). A pure
-- function, shared by the server and tests.

local OfflineConfig = require(script.Parent.Config.Offline)

local OfflineMath = {}

-- Returns the Cash earned for being away awaySeconds at incomePerSecond, and
-- the seconds that counted.
function OfflineMath.earnings(incomePerSecond: number, awaySeconds: number): (number, number)
	if awaySeconds < OfflineConfig.MinSeconds or incomePerSecond <= 0 then
		return 0, 0
	end
	local counted = math.min(awaySeconds, OfflineConfig.MaxSeconds)
	return math.floor(incomePerSecond * counted * OfflineConfig.IncomeShare), counted
end

return OfflineMath
