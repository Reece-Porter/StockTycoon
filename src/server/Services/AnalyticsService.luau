--!strict
-- Reports to Roblox analytics (docs/design.md, "Analytics";
-- server/Config/Analytics), so balance can be tuned from real play. The
-- results show in the Creator Dashboard.
--
--   The new-player funnel: each step once per player, the first time they do
--     it. The steps sent are saved, so a step is never sent twice.
--   Cash earned by source and spent by sink. Income arrives every second, so
--     it's added up and sent every Config/Analytics.IncomeReportSeconds and
--     when the player leaves.
--   Custom events: MachineResult (the multiplier, and whether the player
--     pressed Take, let it run out or left), StealStarted (from a plot or the
--     ground), StealCompleted, and Rebirth (minutes played since the last
--     rebirth, or since analytics began for the first).
--
-- Admin commands aren't reported. Every report goes through pcall, so
-- analytics can never break the game, and the last few are kept for the
-- /analytics admin command.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxAnalytics = game:GetService("AnalyticsService")

local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local AnalyticsConfig = require(script.Parent.Parent.Config.Analytics)

local CHECK_SECONDS = 10
local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

export type FunnelStep = AnalyticsConfig.FunnelStep
export type Event = AnalyticsConfig.Event
export type Source = AnalyticsConfig.Source
export type Sink = AnalyticsConfig.Sink
type Report = { player: string, text: string }

-- Income earned but not reported yet, and os.clock() when each player's
-- income and play time were last reported or saved.
local pendingIncome: { [Player]: number } = {}
local incomeReportedAt: { [Player]: number } = {}
local playSavedAt: { [Player]: number } = {}
local recent: { Report } = {}
local counts: { [string]: number } = {}

local AnalyticsService = {}

-- Sends one report, keeping it (and whether it failed) for /analytics.
local function send(player: Player, kind: string, text: string, report: () -> ())
	local problem: string? = nil
	xpcall(report, function(message)
		problem = tostring(message)
	end)
	counts[kind] = (counts[kind] or 0) + 1
	table.insert(recent, 1, { player = player.Name, text = if problem then `{text} FAILED: {problem}` else text })
	if #recent > AnalyticsConfig.RecentCount then
		table.remove(recent)
	end
end

local function customFields(values: { string }?): { [string]: string }?
	if values == nil then
		return nil
	end
	local result = {}
	for index, value in values do
		local key = FIELD_KEYS[index]
		if key then
			result[key] = value
		end
	end
	return result
end

local function economy(
	player: Player,
	flow: Enum.AnalyticsEconomyFlowType,
	transaction: string,
	amount: number,
	sku: string
)
	local data = DataService:GetData(player)
	local rounded = math.round(amount)
	if data == nil or rounded <= 0 then
		return
	end
	local balance = math.round(data.Cash)
	local text = `{flow.Name} {Format.cash(rounded)} {sku} (now {Format.cash(balance)})`
	send(player, "Economy", text, function()
		RobloxAnalytics:LogEconomyEvent(player, flow, AnalyticsConfig.Currency, rounded, balance, transaction, sku)
	end)
end

local function reportIncome(player: Player)
	local amount = pendingIncome[player] or 0
	pendingIncome[player] = 0
	incomeReportedAt[player] = os.clock()
	local source: Source = "Income"
	economy(player, Enum.AnalyticsEconomyFlowType.Source, AnalyticsConfig.Sources[source], amount, source)
end

local function savePlaytime(player: Player)
	local savedAt = playSavedAt[player]
	if savedAt == nil then
		return
	end
	local now = os.clock()
	playSavedAt[player] = now
	DataService:UpdateAnalytics(player, function(analytics)
		analytics.PlaySeconds += now - savedAt
	end)
end

-- Reports a new-player funnel step, if this player hasn't reached it before.
function AnalyticsService:Funnel(player: Player, stepName: FunnelStep)
	local step = table.find(AnalyticsConfig.FunnelSteps, stepName)
	if step == nil then
		return
	end
	local isNew = false
	DataService:UpdateAnalytics(player, function(analytics)
		if not table.find(analytics.Funnel, step) then
			table.insert(analytics.Funnel, step)
			isNew = true
		end
	end)
	if isNew then
		send(player, "Funnel", `Funnel step {step} {stepName}`, function()
			RobloxAnalytics:LogOnboardingFunnelStepEvent(player, step, stepName)
		end)
	end
end

-- Reports Cash the player has just been given.
function AnalyticsService:Earned(player: Player, source: AnalyticsConfig.Source, amount: number)
	if source == "Income" then
		pendingIncome[player] = (pendingIncome[player] or 0) + amount
		return
	end
	economy(player, Enum.AnalyticsEconomyFlowType.Source, AnalyticsConfig.Sources[source], amount, source)
end

-- Reports Cash the player has just spent. item narrows it down, e.g. the
-- company's tier or the weapon.
function AnalyticsService:Spent(player: Player, sink: AnalyticsConfig.Sink, amount: number, item: string?)
	local sku = if item then `{sink}_{item}` else sink
	economy(player, Enum.AnalyticsEconomyFlowType.Sink, AnalyticsConfig.Sinks[sink], amount, sku)
end

-- Reports a custom event with up to three labels, e.g. whether a machine run
-- was taken or ran out.
function AnalyticsService:Event(player: Player, name: Event, value: number, labels: { string }?)
	local text = `{name} {value}` .. if labels then ` {table.concat(labels, " ")}` else ""
	send(player, "Event", text, function()
		RobloxAnalytics:LogCustomEvent(player, name, value, customFields(labels))
	end)
end

-- Reports how long this rebirth took: minutes played since the last one.
function AnalyticsService:Rebirthed(player: Player, rebirths: number)
	savePlaytime(player)
	local seconds = 0
	DataService:UpdateAnalytics(player, function(analytics)
		seconds = analytics.PlaySeconds - analytics.RebirthPlaySeconds
		analytics.RebirthPlaySeconds = analytics.PlaySeconds
	end)
	local label = if rebirths > AnalyticsConfig.RebirthLabelCap
		then `{AnalyticsConfig.RebirthLabelCap}+`
		else tostring(rebirths)
	AnalyticsService:Event(player, "Rebirth", math.round(seconds / 60), { label })
end

-- Admin testing: what's been reported on this server, newest first.
function AnalyticsService:GetReport(): string
	local lines = {
		`Sent on this server: {counts.Funnel or 0} funnel, {counts.Economy or 0} economy, {counts.Event or 0} events.`,
	}
	for _, report in recent do
		table.insert(lines, `{report.player}: {report.text}`)
	end
	if #recent == 0 then
		table.insert(lines, "Nothing yet.")
	end
	return table.concat(lines, "\n")
end

function AnalyticsService:Start()
	DataService:OnDataLoaded(function(player)
		local now = os.clock()
		playSavedAt[player] = now
		incomeReportedAt[player] = now
		pendingIncome[player] = 0
		AnalyticsService:Funnel(player, "Joined")
	end)
	DataService:OnPlayerLeaving(function(player)
		reportIncome(player)
		savePlaytime(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- After the report above, which runs when the save is let go.
		task.defer(function()
			pendingIncome[player] = nil
			incomeReportedAt[player] = nil
			playSavedAt[player] = nil
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			local now = os.clock()
			for player, reportedAt in incomeReportedAt do
				if now - reportedAt >= AnalyticsConfig.IncomeReportSeconds then
					reportIncome(player)
				end
			end
			for player, savedAt in playSavedAt do
				if now - savedAt >= AnalyticsConfig.PlaytimeSaveSeconds then
					savePlaytime(player)
				end
			end
		end
	end)
end

return AnalyticsService
