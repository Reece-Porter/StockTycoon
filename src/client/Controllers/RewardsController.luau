--!strict
-- The Rewards menu button (with a dot while anything is ready to claim) and
-- its window, in two tabs:
--   Playtime: today's playtime rewards, each with a Claim button or the time
--     still to play, plus any boost time and free pet spins banked.
--   Daily: the 7-day streak as a row of day cards and a Claim button.
-- The server times everything and checks every claim; this works out what to
-- show from the attributes it sends (see RewardsService) and the shared
-- server clock.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardMath = require(ReplicatedStorage.Shared.RewardMath)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.Rewards)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)
local Row = require(script.Parent.Parent.Ui.Kit.Row)
local Scroll = require(script.Parent.Parent.Ui.Kit.Scroll)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)

local ROW_HEIGHT = 76
local ACTION_WIDTH = 116
local DAY_HEIGHT = 84
local UPDATE_SECONDS = 0.5

local player = Players.LocalPlayer

local RewardsController = {}

local function numberAttribute(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function claimedToday(today: number): { number }
	if numberAttribute("PlaytimeDay") ~= today then
		return {}
	end
	local json = player:GetAttribute("ClaimedPlaytime")
	if typeof(json) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

-- Today's playtime, counted on from the last figure the server sent.
local function playtimeNow(now: number, today: number): number
	if numberAttribute("PlaytimeDay") ~= today then
		return 0
	end
	return numberAttribute("PlaytimeSeconds") + math.max(0, now - numberAttribute("PlaytimeAt"))
end

local function boostLeft(now: number): number
	return math.max(0, numberAttribute("BoostEndsAt") - now)
end

-- A short label for a day card, e.g. "Cash" or "2x 10m".
local function shortLabel(grants: { RewardsConfig.Grant }): string
	local parts = {}
	for _, grant in grants do
		if grant.kind == "cash" then
			table.insert(parts, "Cash")
		elseif grant.kind == "boost" then
			table.insert(parts, `{RewardsConfig.BoostMultiplier}x {math.floor((grant.seconds or 0) / 60)}m`)
		else
			local count = grant.count or 0
			table.insert(parts, if count == 1 then "1 spin" else `{count} spins`)
		end
	end
	return table.concat(parts, "\n")
end

-- What the cash in a reward would come to now, e.g. " (about $1.2K)".
local function cashHint(grants: { RewardsConfig.Grant }, now: number): string
	local income = numberAttribute("IncomePerSecond")
	if boostLeft(now) > 0 then
		income /= RewardsConfig.BoostMultiplier
	end
	for _, grant in grants do
		if grant.kind == "cash" then
			return ` (about {Format.cash(RewardMath.cashValue(grant, income))})`
		end
	end
	return ""
end

local function grantsFor(minutes: number): { RewardsConfig.Grant }
	for _, milestone in RewardsConfig.Playtime do
		if milestone.minutes == minutes then
			return milestone.grants
		end
	end
	return {}
end

type PlaytimeRow = { minutes: number, row: Row.Row, button: Button.Button }
type DayCard = { frame: Frame, label: TextLabel, tick: Frame }

function RewardsController:Start()
	local pages: { [string]: GuiObject } = {}
	local window = Menu.window({
		title = "Rewards",
		colour = Theme.Menu.Rewards,
		tabs = { "Playtime", "Daily" },
		onTab = function(name)
			for pageName, page in pages do
				page.Visible = pageName == name
			end
		end,
	})
	local function page(name: string): ScrollingFrame
		local scroll = Scroll.list(window.Body)
		scroll.Name = name
		scroll.Visible = false
		pages[name] = scroll
		return scroll
	end

	-- Playtime.
	local playtime = page("Playtime")
	local playtimeTitle = Scroll.heading(playtime, "", 1)
	playtimeTitle.TextWrapped = true
	playtimeTitle.Size = UDim2.new(1, 0, 0, 44)
	local banked = Make.label(playtime, {
		size = Theme.TextSize.Small,
		colour = Theme.shade(Theme.Colours.Gold, 0.35),
		alignX = Enum.TextXAlignment.Left,
		wrapped = true,
	})
	banked.LayoutOrder = 2
	banked.Size = UDim2.new(1, 0, 0, 40)
	local rows: { PlaytimeRow } = {}
	for index, milestone in RewardsConfig.Playtime do
		local row = Row.new({
			title = `{milestone.minutes} min`,
			icon = "Gift",
			accent = Theme.Menu.Rewards,
			height = ROW_HEIGHT,
			actionWidth = ACTION_WIDTH,
			layoutOrder = 10 + index,
		})
		row.Instance.Parent = playtime
		local button = Button.new({
			text = "",
			colour = Theme.Colours.Cash,
			size = UDim2.fromScale(1, 1),
			textSize = Theme.TextSize.Body,
		})
		button.Instance.Parent = row.Action
		local minutes = milestone.minutes
		button.Activated:Connect(function()
			Remotes.ClaimPlaytime:FireServer(minutes)
		end)
		table.insert(rows, { minutes = minutes, row = row, button = button })
	end

	-- Daily.
	local daily = page("Daily")
	local dailyTitle = Scroll.heading(daily, "", 1)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.LayoutOrder = 2
	track.Size = UDim2.new(1, 0, 0, DAY_HEIGHT)
	track.BackgroundTransparency = 1
	track.Parent = daily
	Make.list(track, Enum.FillDirection.Horizontal, 4)
	local days = #RewardsConfig.Daily
	local cards: { DayCard } = {}
	for day, grants in RewardsConfig.Daily do
		local card = Instance.new("Frame")
		card.LayoutOrder = day
		card.Size = UDim2.new(1 / days, -4, 1, 0)
		card.BackgroundColor3 = Theme.Colours.Card
		Make.corner(card, Theme.Corner.Small)
		Make.outline(card, Theme.Colours.Ink, Theme.Stroke.Normal)
		card.Parent = track
		local label = Make.label(card, {
			text = `Day {day}\n{shortLabel(grants)}`,
			font = Theme.Fonts.Display,
			size = Theme.TextSize.Small,
			colour = Theme.Colours.Text,
			wrapped = true,
		})
		label.TextScaled = true
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = Theme.TextSize.Small
		fit.MinTextSize = 9
		fit.Parent = label
		Make.padding(label, 4)
		local tick = Icons.make("Tick", 22)
		tick.AnchorPoint = Vector2.new(1, 0)
		tick.Position = UDim2.new(1, 2, 0, -6)
		tick.Visible = false
		tick.Parent = card
		table.insert(cards, { frame = card, label = label, tick = tick })
	end
	local dailyDetail = Make.label(daily, {
		size = Theme.TextSize.Small,
		colour = Theme.Colours.TextMuted,
		alignX = Enum.TextXAlignment.Left,
		wrapped = true,
	})
	dailyDetail.LayoutOrder = 3
	dailyDetail.Size = UDim2.new(1, 0, 0, 40)
	local dailyButton = Button.new({ text = "", colour = Theme.Colours.Cash, size = UDim2.new(1, 0, 0, 56) })
	dailyButton.Instance.LayoutOrder = 4
	dailyButton.Instance.Parent = daily
	dailyButton.Activated:Connect(function()
		Remotes.ClaimDaily:FireServer()
	end)

	local menuButton = Menu.button({
		name = "Rewards",
		text = "Rewards",
		icon = "Gift",
		colour = Theme.Menu.Rewards,
		order = 7,
		side = "Left",
	})
	menuButton.Activated:Connect(function()
		Menu.toggle(window)
	end)

	local function refresh()
		local now = workspace:GetServerTimeNow()
		local today = RewardMath.day(now)
		local played = playtimeNow(now, today)
		local claimed = claimedToday(today)
		local ready = RewardMath.readyPlaytime(played, claimed)
		local streak = RewardMath.daily(numberAttribute("LastDailyDay"), numberAttribute("DailyStreak"), today)
		menuButton.setDot(#ready > 0 or streak.claimable)
		if not window.isOpen() then
			return
		end

		local status = {}
		local boost = boostLeft(now)
		if boost > 0 then
			table.insert(status, `{RewardsConfig.BoostMultiplier}x income: {Format.duration(boost)} left`)
		end
		local tokens = numberAttribute("SpinTokens")
		if tokens > 0 then
			table.insert(status, `Free pet spins: {tokens} (use them at the pet shop)`)
		end
		banked.Text = table.concat(status, "\n")
		banked.Visible = #status > 0

		local resetsIn = Format.duration(RewardMath.secondsToNextDay(now))
		playtimeTitle.Text = `Played today: {Format.duration(played)}  ·  resets in {resetsIn}`
		for _, entry in rows do
			local grants = grantsFor(entry.minutes)
			entry.row.setDetail(`{RewardMath.describeAll(grants)}{cashHint(grants, now)}`)
			if table.find(claimed, entry.minutes) then
				entry.button.setText("Claimed")
				entry.button.setEnabled(false)
			elseif table.find(ready, entry.minutes) then
				entry.button.setText("Claim")
				entry.button.setEnabled(true)
			else
				entry.button.setText(Format.duration(entry.minutes * 60 - played))
				entry.button.setEnabled(false)
			end
		end

		dailyTitle.Text = `Daily streak: {streak.streak} day{if streak.streak == 1 then "" else "s"}`
		-- Days already claimed in this run of the track are ticked; today's
		-- claim, if it's waiting, is gold.
		for day, card in cards do
			local done = if streak.claimable then day < streak.nextDay else day <= streak.streak
			local isToday = streak.claimable and day == streak.nextDay
			card.frame.BackgroundColor3 = if isToday
				then Theme.Colours.Gold
				elseif done then Theme.tint(Theme.Colours.Cash, 0.55)
				else Theme.Colours.Card
			card.tick.Visible = done
		end
		local nextGrants = RewardsConfig.Daily[streak.nextDay]
		local when = if streak.claimable then "Today" else "Tomorrow"
		local nextText = `{RewardMath.describeAll(nextGrants)}{cashHint(nextGrants, now)}`
		dailyDetail.Text = `{when}, Day {streak.nextDay}: {nextText}. Miss a day and it starts again at Day 1.`
		if streak.claimable then
			dailyButton.setText(`Claim Day {streak.nextDay}`)
			dailyButton.setEnabled(true)
		else
			dailyButton.setText(`Come back in {resetsIn}`)
			dailyButton.setEnabled(false)
		end
	end

	player.AttributeChanged:Connect(function(name)
		if
			name == "ClaimedPlaytime"
			or name == "PlaytimeSeconds"
			or name == "LastDailyDay"
			or name == "SpinTokens"
			or name == "BoostEndsAt"
		then
			refresh()
		end
	end)
	refresh()
	while true do
		task.wait(UPDATE_SECONDS)
		refresh()
	end
end

return RewardsController
