--!strict
-- Hostile Takeovers (docs/design.md, "Stealing"; Config/Steal.Takeover): the
-- only time anyone can steal from a base (StealService asks IsActive). One
-- runs for DurationSeconds every EverySeconds, at the same time in every
-- server (TakeoverClock). Everyone is told a few minutes before, when it
-- starts and when it's over. Workspace's TakeoverEndsAt attribute (while one
-- is on) and TakeoverNextAt (server time) drive the countdown and banner on
-- each player's screen (TakeoverController). Admins can start or stop one for
-- testing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StealConfig = require(ReplicatedStorage.Shared.Config.Steal)
local TakeoverClock = require(ReplicatedStorage.Shared.TakeoverClock)

local CHECK_SECONDS = 0.25

-- An admin's takeover runs until this; nil if none.
local forcedEndsAt: number? = nil
-- A scheduled takeover an admin stopped doesn't count until this.
local stoppedUntil = 0
local wasActive = false
-- The start time each warning (by seconds before) was last given for.
local warnedFor: { [number]: number } = {}

local TakeoverService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Whether a takeover is on at this time, when it ends if so, and when the
-- next one starts.
local function state(time: number): (boolean, number?, number)
	local startsAt, endsAt = TakeoverClock.window(time)
	local scheduled = startsAt <= time and time >= stoppedUntil
	local forced = forcedEndsAt ~= nil and time < forcedEndsAt
	if scheduled or forced then
		local ends = math.max(if scheduled then endsAt else time, forcedEndsAt or time)
		return true, ends, TakeoverClock.nextStart(ends)
	end
	return false, nil, if startsAt > time then startsAt else TakeoverClock.nextStart(time)
end

local function tellEveryone(message: string)
	Remotes.Notify:FireAllClients(message)
end

-- Warns everyone once for each of WarnSeconds before the next one, with
-- one message if a few are due at once (a server started just before).
local function warnAhead(time: number, nextAt: number)
	local left = nextAt - time
	local due = false
	for _, seconds in StealConfig.Takeover.WarnSeconds do
		if left <= seconds and warnedFor[seconds] ~= nextAt then
			warnedFor[seconds] = nextAt
			due = true
		end
	end
	if due then
		tellEveryone(
			`A Hostile Takeover starts in {Format.longDuration(left + 0.5)}! Anyone can steal from any base then, so get home to guard yours.`
		)
	end
end

local function check()
	local time = now()
	local active, endsAt, nextAt = state(time)
	if workspace:GetAttribute("TakeoverEndsAt") ~= endsAt then
		workspace:SetAttribute("TakeoverEndsAt", endsAt)
	end
	if workspace:GetAttribute("TakeoverNextAt") ~= nextAt then
		workspace:SetAttribute("TakeoverNextAt", nextAt)
	end
	if active and not wasActive and endsAt then
		tellEveryone(
			`HOSTILE TAKEOVER! For {Format.longDuration(endsAt - time + 0.5)} you can steal from other bases, and they can steal from yours.`
		)
	elseif not active and wasActive then
		tellEveryone(
			`The Hostile Takeover is over. Bases are safe until the next one, in {Format.longDuration(nextAt - time)}.`
		)
	end
	wasActive = active
	if not active then
		warnAhead(time, nextAt)
	end
end

function TakeoverService:IsActive(): boolean
	return (state(now()))
end

-- When the takeover going on ends, or nil if none is.
function TakeoverService:GetEndsAt(): number?
	local _, endsAt = state(now())
	return endsAt
end

-- When the next takeover starts.
function TakeoverService:GetNextAt(): number
	local _, _, nextAt = state(now())
	return nextAt
end

-- What a thief is told when no takeover is on.
function TakeoverService:ClosedMessage(): string
	return `You can only steal from bases in a Hostile Takeover. The next one starts in {Format.longDuration(
		TakeoverService:GetNextAt() - now()
	)}.`
end

-- Admin testing: a takeover from now for this many seconds.
function TakeoverService:StartNow(seconds: number)
	forcedEndsAt = now() + seconds
	check()
end

-- Admin testing: ends the takeover going on, if any.
function TakeoverService:StopNow()
	local time = now()
	forcedEndsAt = nil
	local startsAt, endsAt = TakeoverClock.window(time)
	if startsAt <= time then
		stoppedUntil = endsAt
	end
	check()
end

function TakeoverService:Start()
	check()
	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		sinceCheck += deltaTime
		if sinceCheck >= CHECK_SECONDS then
			sinceCheck = 0
			check()
		end
	end)
end

return TakeoverService
