--!strict
-- Playtime rewards, the daily login streak, and the boosts and free pet spins
-- they give (docs/design.md, "Playtime and daily rewards"). Everything is
-- timed with the server's clock and checked here; the client only asks to
-- claim.
--
-- Playtime counts every second a player is in the game (AFK included) towards
-- today's total. At 00:00 UTC it starts again from zero and any unclaimed
-- playtime rewards are gone. It is saved, so leaving and rejoining keeps it.
-- The daily reward can be claimed once per UTC day; missing a day starts the
-- 7-day track again (RewardMath.daily).
--
-- A boost doubles all income. New boost time is added to what's banked (up
-- to Config/Rewards.MaxBoostSeconds) and only runs down while the player is in
-- the game. Free pet spins are kept as tokens for the pet shop.
--
-- Players get attributes for the rewards screen: PlaytimeSeconds (as of the
-- server time PlaytimeAt), PlaytimeDay, ClaimedPlaytime (JSON), DailyStreak,
-- LastDailyDay, BoostEndsAt (server time, while a boost runs) and SpinTokens.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RewardMath = require(ReplicatedStorage.Shared.RewardMath)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.Rewards)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local PlotService = require(script.Parent.PlotService)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local TICK_SECONDS = 1
-- A tick never counts more than this, so a long server stall can't hand out
-- a burst of playtime.
local MAX_TICK_SECONDS = 5
-- Playtime is re-sent to the client this often to keep its count exact.
local PUBLISH_SECONDS = 30

local lastTick: { [Player]: number } = {}
local lastPublish: { [Player]: number } = {}
local playtimeLimiter = RateLimiter.new(4, 8)
local dailyLimiter = RateLimiter.new(2, 4)

local RewardsService = {}

local function notify(player: Player, message: string)
	if player.Parent == Players then
		Remotes.Notify:FireClient(player, message)
	end
end

local function today(): number
	return RewardMath.day(os.time())
end

-- Starts a new day's playtime if the UTC day has changed. Returns whether it did.
local function rollOver(rewards: Types.RewardsState, day: number): boolean
	if rewards.PlaytimeDay == day then
		return false
	end
	rewards.PlaytimeDay = day
	rewards.PlaytimeSeconds = 0
	table.clear(rewards.ClaimedPlaytime)
	return true
end

local function publish(player: Player)
	local data = DataService:GetData(player)
	if data == nil or player.Parent ~= Players then
		return
	end
	local rewards = data.Rewards
	local now = workspace:GetServerTimeNow()
	lastPublish[player] = os.clock()
	player:SetAttribute("PlaytimeSeconds", rewards.PlaytimeSeconds)
	player:SetAttribute("PlaytimeAt", now)
	player:SetAttribute("PlaytimeDay", rewards.PlaytimeDay)
	player:SetAttribute("ClaimedPlaytime", HttpService:JSONEncode(rewards.ClaimedPlaytime))
	player:SetAttribute("DailyStreak", rewards.DailyStreak)
	player:SetAttribute("LastDailyDay", rewards.LastDailyDay)
	player:SetAttribute("BoostEndsAt", if rewards.BoostSeconds > 0 then now + rewards.BoostSeconds else nil)
	player:SetAttribute("SpinTokens", rewards.SpinTokens)
end

-- Income and the plot labels change when a boost starts or ends.
local function refreshIncome(player: Player)
	IncomeService:Refresh(player)
	PlotService:Refresh(player)
end

-- Gives a reward and returns what was given, e.g. "$1.2K + 1 free pet spin".
-- source is what it's for, for analytics.
function RewardsService:Grant(player: Player, grants: { RewardsConfig.Grant }, source: AnalyticsService.Source): string
	local given = {}
	for _, grant in grants do
		if grant.kind == "cash" then
			local amount = RewardMath.cashValue(grant, IncomeService:GetIncomePerSecond(player, true))
			if DataService:AddCash(player, amount) then
				AnalyticsService:Earned(player, source, amount)
			end
			table.insert(given, Format.cash(amount))
		elseif grant.kind == "boost" then
			local startedNow, wasted = false, 0
			DataService:UpdateRewards(player, function(rewards)
				startedNow = rewards.BoostSeconds <= 0
				rewards.BoostSeconds, wasted = RewardMath.addBoost(rewards.BoostSeconds, grant.seconds or 0)
			end)
			if startedNow then
				refreshIncome(player)
			end
			local text = RewardMath.describe(grant)
			if wasted > 0 then
				local cap = math.floor(RewardsConfig.MaxBoostSeconds / 60)
				text ..= ` ({cap} min is the most you can bank)`
			end
			table.insert(given, text)
		else
			DataService:UpdateRewards(player, function(rewards)
				rewards.SpinTokens += grant.count or 0
			end)
			table.insert(given, RewardMath.describe(grant))
		end
	end
	publish(player)
	return table.concat(given, " + ")
end

-- Uses one free pet spin if the player has any. Returns whether one was used.
function RewardsService:UseSpinToken(player: Player): boolean
	local used = false
	DataService:UpdateRewards(player, function(rewards)
		if rewards.SpinTokens > 0 then
			rewards.SpinTokens -= 1
			used = true
		end
	end)
	if used then
		publish(player)
	end
	return used
end

-- Gives back a free pet spin that couldn't be used after all.
function RewardsService:ReturnSpinToken(player: Player)
	DataService:UpdateRewards(player, function(rewards)
		rewards.SpinTokens += 1
	end)
	publish(player)
end

-- Admin testing: adds minutes to today's playtime.
function RewardsService:SkipPlaytime(player: Player, minutes: number): boolean
	local day = today()
	local ok = DataService:UpdateRewards(player, function(rewards)
		rollOver(rewards, day)
		rewards.PlaytimeSeconds += minutes * 60
	end)
	publish(player)
	return ok
end

-- Admin testing: acts as if this many days have passed since the player's
-- playtime day and last daily claim, so the daily reset and the streak can be
-- checked without waiting.
function RewardsService:ShiftDays(player: Player, days: number): boolean
	local ok = DataService:UpdateRewards(player, function(rewards)
		rewards.PlaytimeDay -= days
		if rewards.LastDailyDay > 0 then
			rewards.LastDailyDay -= days
		end
	end)
	publish(player)
	return ok
end

-- Returns the message for the player.
local function claimPlaytime(player: Player, minutes: number): string
	local milestone = nil
	for _, candidate in RewardsConfig.Playtime do
		if candidate.minutes == minutes then
			milestone = candidate
		end
	end
	if milestone == nil then
		return "That isn't a playtime reward."
	end
	local day = today()
	local result = "Your data hasn't loaded yet."
	local claimed = false
	DataService:UpdateRewards(player, function(rewards)
		rollOver(rewards, day)
		if table.find(rewards.ClaimedPlaytime, minutes) then
			result = "You've already claimed that today."
		elseif rewards.PlaytimeSeconds < minutes * 60 then
			local left = minutes * 60 - rewards.PlaytimeSeconds
			result = `Play for {Format.duration(left)} more to claim that.`
		else
			table.insert(rewards.ClaimedPlaytime, minutes)
			claimed = true
		end
	end)
	if not claimed then
		publish(player)
		return result
	end
	return `{minutes} minutes played: {RewardsService:Grant(player, milestone.grants, "Playtime")}!`
end

local function claimDaily(player: Player): string
	local day = today()
	local track = 0
	local claimed = false
	DataService:UpdateRewards(player, function(rewards)
		local state = RewardMath.daily(rewards.LastDailyDay, rewards.DailyStreak, day)
		if state.claimable then
			rewards.DailyStreak = state.nextDay
			rewards.LastDailyDay = day
			track = state.nextDay
			claimed = true
		end
	end)
	if not claimed then
		if DataService:GetData(player) == nil then
			return "Your data hasn't loaded yet."
		end
		local wait = RewardMath.secondsToNextDay(os.time())
		return `You've claimed today's reward. Come back in {Format.duration(wait)}.`
	end
	return `Day {track}: {RewardsService:Grant(player, RewardsConfig.Daily[track], "Daily")}!`
end

local function tick()
	local now = os.clock()
	local day = today()
	for _, player in Players:GetPlayers() do
		if DataService:GetData(player) == nil then
			continue
		end
		local elapsed = math.min(now - (lastTick[player] or now), MAX_TICK_SECONDS)
		lastTick[player] = now
		local rolledOver, boostEnded = false, false
		DataService:UpdateRewards(player, function(rewards)
			rolledOver = rollOver(rewards, day)
			rewards.PlaytimeSeconds += elapsed
			if rewards.BoostSeconds > 0 then
				rewards.BoostSeconds = math.max(0, rewards.BoostSeconds - elapsed)
				boostEnded = rewards.BoostSeconds == 0
			end
		end)
		if boostEnded then
			refreshIncome(player)
			notify(player, "Your 2x income boost has run out.")
		end
		if rolledOver then
			notify(player, "A new day has started: playtime rewards are back, and a daily reward is waiting.")
		end
		if rolledOver or boostEnded or now - (lastPublish[player] or 0) >= PUBLISH_SECONDS then
			publish(player)
		end
	end
end

function RewardsService:Start()
	DataService:OnDataLoaded(function(player)
		DataService:UpdateRewards(player, function(rewards)
			rollOver(rewards, today())
		end)
		publish(player)
		-- A boost saved from last time counts again now they're back.
		refreshIncome(player)
	end)
	DataService:OnDataChanged(publish)
	Players.PlayerRemoving:Connect(function(player)
		lastTick[player] = nil
		lastPublish[player] = nil
	end)

	Remotes.ClaimPlaytime.OnServerEvent:Connect(function(player: Player, minutes: unknown)
		if playtimeLimiter:allow(player) and typeof(minutes) == "number" then
			notify(player, claimPlaytime(player, minutes))
		end
	end)
	Remotes.ClaimDaily.OnServerEvent:Connect(function(player: Player)
		if dailyLimiter:allow(player) then
			notify(player, claimDaily(player))
		end
	end)

	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			tick()
		end
	end)
end

return RewardsService
