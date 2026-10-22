--!strict
-- When the Hostile Takeovers are (Config/Steal.Takeover). Pure functions of
-- the server clock (workspace:GetServerTimeNow(), seconds since 1970 in
-- UTC), so every server has them at the same time.

local StealConfig = require(script.Parent.Config.Steal)

local TakeoverClock = {}

-- When the scheduled takeover going on at this time starts and ends, or the
-- next one's if none is.
function TakeoverClock.window(time: number): (number, number)
	local settings = StealConfig.Takeover
	local phase = (time - settings.OffsetSeconds) % settings.EverySeconds
	local startsAt = time - phase
	if phase >= settings.DurationSeconds then
		startsAt += settings.EverySeconds
	end
	return startsAt, startsAt + settings.DurationSeconds
end

-- When the first scheduled takeover that starts after this time starts.
function TakeoverClock.nextStart(time: number): number
	local settings = StealConfig.Takeover
	local phase = (time - settings.OffsetSeconds) % settings.EverySeconds
	return time - phase + settings.EverySeconds
end

return TakeoverClock
