--!strict
-- Days, the daily streak, banking boost time and what a reward is worth. Pure
-- functions: times are Unix seconds (UTC) passed in, so the server, the
-- rewards screen and tests all share them.

local Format = require(script.Parent.Format)
local IndexConfig = require(script.Parent.Config.Index)
local RewardsConfig = require(script.Parent.Config.Rewards)

local DAY_SECONDS = 24 * 60 * 60

export type DailyState = {
	-- Whether a daily reward can be claimed today.
	claimable: boolean,
	-- The day of the 7-day track the next claim gives (1 to 7).
	nextDay: number,
	-- The streak as it stands: 0 once a day has been missed.
	streak: number,
}

local RewardMath = {}

-- The UTC day a moment falls on, counted from 1 January 1970.
function RewardMath.day(time: number): number
	return math.floor(time / DAY_SECONDS)
end

-- Seconds until the next 00:00 UTC.
function RewardMath.secondsToNextDay(time: number): number
	return DAY_SECONDS - time % DAY_SECONDS
end

-- The daily streak on day today, given the day of the last claim (0 if never)
-- and the track day claimed then.
function RewardMath.daily(lastDay: number, streak: number, today: number): DailyState
	local length = #RewardsConfig.Daily
	if lastDay == today then
		return { claimable = false, nextDay = streak % length + 1, streak = streak }
	elseif lastDay == today - 1 then
		return { claimable = true, nextDay = streak % length + 1, streak = streak }
	end
	return { claimable = true, nextDay = 1, streak = 0 }
end

-- Adds boost time to what is banked. Returns the new total, capped at
-- Config/Rewards.MaxBoostSeconds, and how much didn't fit.
function RewardMath.addBoost(banked: number, seconds: number): (number, number)
	local total = banked + seconds
	local cap = RewardsConfig.MaxBoostSeconds
	return math.min(total, cap), math.max(0, total - cap)
end

-- The Cash a cash grant is worth at this income (Cash per second).
function RewardMath.cashValue(grant: RewardsConfig.Grant, incomePerSecond: number): number
	return math.max(grant.minimum or 0, math.floor(incomePerSecond * (grant.incomeSeconds or 0)))
end

-- Playtime milestones (in minutes) reached but not claimed yet.
function RewardMath.readyPlaytime(playtimeSeconds: number, claimed: { number }): { number }
	local ready = {}
	for _, milestone in RewardsConfig.Playtime do
		if playtimeSeconds >= milestone.minutes * 60 and not table.find(claimed, milestone.minutes) then
			table.insert(ready, milestone.minutes)
		end
	end
	return ready
end

-- Index prizes (counts of companies) reached but not claimed yet.
function RewardMath.readyIndex(discovered: number, claimed: { number }): { number }
	local ready = {}
	for _, milestone in IndexConfig.Milestones do
		if discovered >= milestone.count and not table.find(claimed, milestone.count) then
			table.insert(ready, milestone.count)
		end
	end
	return ready
end

local function minutes(seconds: number): string
	return `{math.floor(seconds / 60 + 0.5)} min`
end

-- What a grant gives, e.g. "60s of income (at least $100)", "2x income for
-- 5 min" or "1 free pet spin".
function RewardMath.describe(grant: RewardsConfig.Grant): string
	if grant.kind == "cash" then
		local text = `{grant.incomeSeconds or 0}s of income`
		local minimum = grant.minimum
		return if minimum and minimum > 0 then `{text} (at least {Format.cash(minimum)})` else text
	elseif grant.kind == "boost" then
		return `{RewardsConfig.BoostMultiplier}x income for {minutes(grant.seconds or 0)}`
	end
	local count = grant.count or 0
	return if count == 1 then "1 free pet spin" else `{count} free pet spins`
end

function RewardMath.describeAll(grants: { RewardsConfig.Grant }): string
	local parts = {}
	for _, grant in grants do
		table.insert(parts, RewardMath.describe(grant))
	end
	return table.concat(parts, " + ")
end

return RewardMath
