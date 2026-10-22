--!strict
-- The battle arena (docs/design.md, "Battle arena"; Config/Battle).
--
-- Players at the arena join the next battle at its podium (BattleJoin; they
-- can leave again before it starts). Once MinPlayers have joined, a
-- countdown starts, and when it runs out up to MaxPlayers play. A player
-- alone can start a practice match instead (BattlePractice), which gives no
-- reward. A match is:
--   1. Rounds rounds. Each round the server rolls Choices different stocks
--      for each player with the same odds for everyone (SpinnerMath at Luck
--      x1, with variants), and sends each their own (BattleOffer). The reels
--      spin on their screen, then they pick one (BattlePick) before the
--      round closes; whoever doesn't gets the most valuable of their three.
--      A stock's value is its price times its variant's multiplier
--      (BattleMath). After each round the board shows everyone's pick, total
--      and place.
--   2. Each player chooses (BattleChoose) to keep their total or put it
--      through the arena's Valuation Machine: the server makes each a run
--      (MachinePath, 0.5x to 5x, shorter than at home) and sends it to draw
--      (BattleMachine); the player sends only "take" (BattleTake) and the
--      server works the multiplier out from its own clock, or they get the
--      value when time runs out.
--   3. Final standings by value, and Cash for each place (Config/Battle,
--      scaled to the player's income) and Gold (more with more rebirths,
--      BattleMath.gold) when it wasn't a practice.
-- A player who leaves the game drops out. Everything is decided here; the
-- client only asks. The board and every screen read the match from the
-- State attribute (JSON) on ReplicatedStorage.Battle.
--
-- Admins can add test bots, which play by themselves, and skip phases.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BattleConfig = require(ReplicatedStorage.Shared.Config.Battle)
local BattleMath = require(ReplicatedStorage.Shared.BattleMath)
local Format = require(ReplicatedStorage.Shared.Format)
local MachinePath = require(ReplicatedStorage.Shared.MachinePath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardMath = require(ReplicatedStorage.Shared.RewardMath)
local SpinnerConfig = require(ReplicatedStorage.Shared.Config.Spinner)
local SpinnerMath = require(ReplicatedStorage.Shared.SpinnerMath)
local VariantMath = require(ReplicatedStorage.Shared.VariantMath)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local Arena = require(script.Parent.Parent.Lib.Arena)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

export type Phase = "Idle" | "Countdown" | "Spin" | "Results" | "Choose" | "Machine" | "Final"

type Pick = { companyId: string, variant: string?, value: number }

type Entry = {
	-- nil for an admin's test bot.
	player: Player?,
	name: string,
	userId: number,
	order: number,
	picks: { Pick },
	offer: { Pick }?,
	picked: boolean,
	total: number,
	-- The total the board shows: as of the last round that closed, so a
	-- pick isn't given away before then.
	shownTotal: number,
	choice: string?,
	run: MachinePath.Params?,
	runStartedAt: number,
	multiplier: number?,
	final: number?,
	place: number?,
	reward: number?,
	gold: number?,
	left: boolean,
	-- When a bot does its next thing.
	botAt: number?,
}

-- The stock odds every player spins with.
local WEIGHTS = SpinnerMath.weights(SpinnerConfig.Weights, 1)
local CHECK_SECONDS = 0.1

local phase: Phase = "Idle"
local phaseEndsAt = 0
local round = 0
local practice = false
local lobby: { Entry } = {}
local entries: { Entry } = {}
local nextOrder = 0
local bots = 0
local stateFolder: Folder
local random = Random.new()
local joinLimiter = RateLimiter.new(3, 4)
local pickLimiter = RateLimiter.new(4, 4)
local chooseLimiter = RateLimiter.new(3, 4)
local takeLimiter = RateLimiter.new(3, 4)

local BattleService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function notify(player: Player?, message: string)
	if player and player.Parent == Players then
		Remotes.Notify:FireClient(player, message)
	end
end

local function pickText(pick: Pick?): string?
	if pick == nil then
		return nil
	end
	return if pick.variant then `{pick.companyId}:{pick.variant}` else pick.companyId
end

local function offerText(offer: { Pick }): string
	local texts = {}
	for _, pick in offer do
		table.insert(texts, pickText(pick) :: string)
	end
	return table.concat(texts, ",")
end

local function playing(): { Entry }
	local list = {}
	for _, entry in entries do
		if not entry.left then
			table.insert(list, entry)
		end
	end
	return list
end

local function shownValue(entry: Entry): number
	return entry.final or entry.shownTotal
end

-- Everyone still in, by what the board shows (their final value at the
-- end), with their places.
local function standings(): { Entry }
	local list = playing()
	table.sort(list, function(a, b)
		return BattleMath.above(shownValue(a), a.order, shownValue(b), b.order)
	end)
	for place, entry in list do
		entry.place = place
	end
	return list
end

-- What the board and every screen show (ReplicatedStorage.Battle's State).
local function publish()
	local revealPicks = phase ~= "Spin"
	local revealRuns = phase == "Final"
	local players: { { [string]: any } } = {}
	for _, entry in standings() do
		local shownPicks = if revealPicks then #entry.picks elseif entry.picked then #entry.picks - 1 else #entry.picks
		table.insert(players, {
			name = entry.name,
			userId = entry.userId,
			place = entry.place,
			total = entry.shownTotal,
			last = pickText(entry.picks[shownPicks]),
			picks = shownPicks,
			picked = entry.picked,
			choice = if phase == "Machine" or revealRuns then entry.choice else nil,
			chosen = entry.choice ~= nil,
			multiplier = if revealRuns then entry.multiplier else nil,
			final = if revealRuns then entry.final else nil,
			reward = if revealRuns then entry.reward else nil,
			gold = if revealRuns then entry.gold else nil,
		})
	end
	for _, entry in entries do
		if entry.left then
			table.insert(players, { name = entry.name, userId = entry.userId, total = entry.shownTotal, left = true })
		end
	end
	local waiting, waitingIds = {}, {}
	for _, entry in lobby do
		table.insert(waiting, entry.name)
		table.insert(waitingIds, entry.userId)
	end
	stateFolder:SetAttribute(
		"State",
		HttpService:JSONEncode({
			phase = phase,
			round = round,
			rounds = BattleConfig.Rounds,
			endsAt = phaseEndsAt,
			practice = practice,
			lobby = waiting,
			lobbyIds = waitingIds,
			players = players,
		})
	)
end

local function setPhase(newPhase: Phase, seconds: number)
	phase = newPhase
	phaseEndsAt = now() + seconds
end

local function rollOffer(): { Pick }
	local results = SpinnerMath.pick(WEIGHTS, BattleConfig.Choices, function()
		return random:NextNumber()
	end)
	local offer = {}
	for _, result in results do
		local variant = VariantMath.roll(random:NextNumber(), 1)
		table.insert(offer, {
			companyId = result.companyId,
			variant = variant,
			value = BattleMath.value(result.companyId, variant),
		})
	end
	return offer
end

local function bestIndex(offer: { Pick }): number
	local best = 1
	for index, pick in offer do
		if pick.value > offer[best].value then
			best = index
		end
	end
	return best
end

local function choosePick(entry: Entry, index: number)
	local offer = entry.offer
	if offer == nil or entry.picked or offer[index] == nil then
		return
	end
	entry.picked = true
	table.insert(entry.picks, offer[index])
	entry.total += offer[index].value
end

-- A new round: everyone's three stocks.
local function startRound()
	round += 1
	local rolledAt = now()
	local landsAt = rolledAt + BattleConfig.SpinSeconds
	local pickBy = landsAt + BattleConfig.PickSeconds
	for _, entry in playing() do
		local offer = rollOffer()
		entry.offer = offer
		entry.picked = false
		local player = entry.player
		if player then
			Remotes.BattleOffer:FireClient(player, round, offerText(offer), rolledAt, landsAt, pickBy)
		else
			entry.botAt = landsAt + random:NextNumber(0.5, 4)
		end
	end
	phase = "Spin"
	phaseEndsAt = pickBy
	publish()
end

local function endRound()
	for _, entry in playing() do
		if not entry.picked and entry.offer then
			choosePick(entry, bestIndex(entry.offer :: { Pick }))
		end
		entry.offer = nil
		entry.shownTotal = entry.total
	end
	setPhase("Results", BattleConfig.RoundResultsSeconds)
	publish()
end

local function startChoosing()
	for _, entry in playing() do
		if entry.player == nil then
			entry.botAt = now() + random:NextNumber(1, 5)
		else
			notify(entry.player, "Keep your value, or put it through the machine?")
		end
	end
	setPhase("Choose", BattleConfig.ChooseSeconds)
	publish()
end

local function settleRun(entry: Entry, elapsed: number?)
	local run = entry.run
	if run == nil or entry.multiplier ~= nil then
		return
	end
	local at = if elapsed and elapsed < run.duration then elapsed else run.duration
	entry.multiplier = MachinePath.lock(MachinePath.value(run, at))
	entry.final = BattleMath.afterMachine(entry.total, entry.multiplier :: number)
end

local function startMachines()
	local longest = 0
	local startedAt = math.round(now() * 1000) / 1000
	for _, entry in playing() do
		if entry.choice == "machine" then
			local run = MachinePath.generate(function()
				return random:NextNumber()
			end, { minDuration = BattleConfig.MachineMinDuration, maxDuration = BattleConfig.MachineMaxDuration })
			entry.run = run
			entry.runStartedAt = startedAt
			longest = math.max(longest, run.duration)
			local player = entry.player
			if player then
				Remotes.BattleMachine:FireClient(
					player,
					HttpService:JSONEncode({
						seed = run.seed,
						duration = run.duration,
						peak = run.peak,
						peakTime = run.peakTime,
						startedAt = startedAt,
						total = entry.total,
					})
				)
			else
				entry.botAt = startedAt + run.duration * random:NextNumber(0.2, 0.9)
			end
		else
			entry.choice = "keep"
			entry.multiplier = 1
			entry.final = entry.total
		end
	end
	setPhase("Machine", longest)
	publish()
end

local function finish()
	local ranked = standings()
	local rewarded = not practice
	for place, entry in ranked do
		local player = entry.player
		local value = entry.final or entry.total
		if rewarded and player then
			-- Worth some seconds of their income, without reward boosts.
			local reward = BattleMath.reward(place)
			local amount = RewardMath.cashValue(
				{ kind = "cash", incomeSeconds = reward.incomeSeconds, minimum = reward.minimum },
				IncomeService:GetIncomePerSecond(player, true)
			)
			if DataService:AddCash(player, amount) then
				AnalyticsService:Earned(player, "Battle", amount)
				entry.reward = amount
			end
			-- And Gold, more for players with more rebirths.
			local data = DataService:GetData(player)
			local gold = BattleMath.gold(place, if data then data.Rebirths else 0)
			if gold > 0 and DataService:AddGold(player, gold) then
				AnalyticsService:EarnedGold(player, "Battle", gold)
				entry.gold = gold
			end
			notify(
				player,
				`You came {BattleMath.ordinal(place)} with {Format.cash(value)}! +{Format.cash(amount)} and +{Format.gold(
					gold
				)}`
			)
		elseif player then
			notify(player, `Practice over: you finished with {Format.cash(value)}.`)
		end
	end
	setPhase("Final", BattleConfig.FinalSeconds)
	publish()
end

local function reset()
	entries = {}
	round = 0
	practice = false
	setPhase("Idle", 0)
	publish()
end

local function realPlayers(list: { Entry }): number
	local count = 0
	for _, entry in list do
		if entry.player and not entry.left then
			count += 1
		end
	end
	return count
end

-- Starts a match with the lobby (up to MaxPlayers; the rest wait for the
-- next one). With fewer than MinPlayers real players it's a practice.
local function startMatch()
	entries = {}
	while #lobby > 0 and #entries < BattleConfig.MaxPlayers do
		table.insert(entries, table.remove(lobby, 1) :: Entry)
	end
	practice = realPlayers(entries) < BattleConfig.MinPlayers
	round = 0
	for _, entry in entries do
		notify(
			entry.player,
			if practice
				then `Practice battle! {BattleConfig.Rounds} rounds, no reward.`
				else `The battle starts! {BattleConfig.Rounds} rounds: pick the best stock each time.`
		)
	end
	startRound()
end

local function newEntry(player: Player?, name: string, userId: number): Entry
	nextOrder += 1
	return {
		player = player,
		name = name,
		userId = userId,
		order = nextOrder,
		picks = {},
		offer = nil,
		picked = false,
		total = 0,
		shownTotal = 0,
		choice = nil,
		run = nil,
		runStartedAt = 0,
		multiplier = nil,
		final = nil,
		place = nil,
		reward = nil,
		gold = nil,
		left = false,
		botAt = nil,
	}
end

local function find(list: { Entry }, player: Player): Entry?
	for _, entry in list do
		if entry.player == player then
			return entry
		end
	end
	return nil
end

local function isNear(player: Player, part: BasePart?, reach: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return part ~= nil
		and root ~= nil
		and root:IsA("BasePart")
		and (root.Position - part.Position).Magnitude <= reach + BattleConfig.DistanceTolerance
end

-- Returns the message for the player.
local function join(player: Player): string
	if find(lobby, player) then
		return "You're already in for the next battle."
	end
	if find(entries, player) and phase ~= "Idle" and phase ~= "Final" then
		return "You're in this battle already."
	end
	local podium = Arena.part("Join")
	if podium == nil then
		return "The battle arena isn't built yet."
	end
	if not isNear(player, podium, BattleConfig.JoinDistance) then
		return "Go to the podium in the middle of the arena to join."
	end
	if #lobby >= BattleConfig.MaxPlayers then
		return "The next battle is full. Try the one after."
	end
	table.insert(lobby, newEntry(player, player.DisplayName, player.UserId))
	publish()
	if #lobby < BattleConfig.MinPlayers then
		return "You're in! Waiting for another player, or start a practice game alone."
	end
	return "You're in! The battle starts soon."
end

local function leave(player: Player)
	for index, entry in lobby do
		if entry.player == player then
			table.remove(lobby, index)
			publish()
			return
		end
	end
end

local function step()
	local time = now()
	if phase == "Idle" then
		if #lobby >= BattleConfig.MinPlayers then
			setPhase("Countdown", BattleConfig.CountdownSeconds)
			for _, entry in lobby do
				notify(entry.player, `The battle starts in {BattleConfig.CountdownSeconds} seconds!`)
			end
			publish()
		end
		return
	end
	if phase == "Countdown" then
		if #lobby < BattleConfig.MinPlayers then
			setPhase("Idle", 0)
			publish()
		elseif time >= phaseEndsAt then
			startMatch()
		end
		return
	end
	if phase == "Final" then
		if time >= phaseEndsAt then
			reset()
		end
		return
	end
	-- Everyone left: the match is over.
	if realPlayers(entries) == 0 then
		reset()
		return
	end
	-- The bots play.
	for _, entry in playing() do
		local botAt = entry.botAt
		if entry.player == nil and botAt and time >= botAt then
			entry.botAt = nil
			if phase == "Spin" and entry.offer then
				choosePick(entry, random:NextInteger(1, #(entry.offer :: { Pick })))
			elseif phase == "Choose" then
				entry.choice = if random:NextNumber() < 0.5 then "machine" else "keep"
			elseif phase == "Machine" then
				settleRun(entry, time - entry.runStartedAt)
			end
			publish()
		end
	end
	if phase == "Spin" then
		local allPicked = true
		for _, entry in playing() do
			allPicked = allPicked and entry.picked
		end
		if time >= phaseEndsAt or allPicked and time >= phaseEndsAt - BattleConfig.PickSeconds then
			endRound()
		end
	elseif phase == "Results" then
		if time >= phaseEndsAt then
			if round < BattleConfig.Rounds then
				startRound()
			else
				startChoosing()
			end
		end
	elseif phase == "Choose" then
		local allChosen = true
		for _, entry in playing() do
			allChosen = allChosen and entry.choice ~= nil
		end
		if time >= phaseEndsAt or allChosen then
			startMachines()
		end
	elseif phase == "Machine" then
		local allDone = true
		for _, entry in playing() do
			if entry.run and entry.multiplier == nil then
				if time - entry.runStartedAt >= (entry.run :: MachinePath.Params).duration then
					settleRun(entry, nil)
				else
					allDone = false
				end
			end
		end
		if allDone then
			finish()
		end
	end
end

function BattleService:GetPhase(): Phase
	return phase
end

-- Whether this player is playing the match going on.
function BattleService:IsPlaying(player: Player): boolean
	local entry = find(entries, player)
	return entry ~= nil and not entry.left and phase ~= "Idle" and phase ~= "Final"
end

-- Admin testing: adds test bots to the next battle, which play by
-- themselves. Returns how many were added.
function BattleService:AddBots(count: number): number
	local added = 0
	while added < count and #lobby < BattleConfig.MaxPlayers do
		bots += 1
		table.insert(lobby, newEntry(nil, `Bot {bots}`, -bots))
		added += 1
	end
	publish()
	return added
end

-- Admin testing: starts the match now with whoever has joined, or moves the
-- one going on to its next phase. Returns what it did.
function BattleService:Skip(): string
	if phase == "Idle" or phase == "Countdown" then
		if #lobby == 0 then
			return "Nobody has joined."
		end
		startMatch()
		return "Started the battle."
	end
	phaseEndsAt = now()
	if phase == "Machine" then
		for _, entry in playing() do
			settleRun(entry, nil)
		end
	end
	step()
	return `Skipped to {phase}.`
end

function BattleService:Init()
	local existing = ReplicatedStorage:FindFirstChild("Battle")
	if existing and existing:IsA("Folder") then
		stateFolder = existing
	else
		stateFolder = Instance.new("Folder")
		stateFolder.Name = "Battle"
		stateFolder.Parent = ReplicatedStorage
	end
end

function BattleService:Start()
	publish()
	Remotes.BattleJoin.OnServerEvent:Connect(function(player: Player)
		if joinLimiter:allow(player) then
			notify(player, join(player))
		end
	end)
	Remotes.BattleLeave.OnServerEvent:Connect(function(player: Player)
		if joinLimiter:allow(player) and find(lobby, player) then
			leave(player)
			notify(player, "You left the queue.")
		end
	end)
	Remotes.BattlePractice.OnServerEvent:Connect(function(player: Player)
		if not joinLimiter:allow(player) then
			return
		end
		if phase ~= "Idle" or #lobby ~= 1 or lobby[1].player ~= player then
			notify(player, "Join at the podium first. Practice is only for when you're the only one waiting.")
			return
		end
		startMatch()
	end)
	Remotes.BattlePick.OnServerEvent:Connect(function(player: Player, choice: unknown)
		if not pickLimiter:allow(player) or phase ~= "Spin" or typeof(choice) ~= "number" then
			return
		end
		local entry = find(entries, player)
		if entry and not entry.left and choice == math.floor(choice) then
			choosePick(entry, choice)
			publish()
		end
	end)
	Remotes.BattleChoose.OnServerEvent:Connect(function(player: Player, choice: unknown)
		if not chooseLimiter:allow(player) or phase ~= "Choose" then
			return
		end
		local entry = find(entries, player)
		if entry and not entry.left and (choice == "keep" or choice == "machine") then
			entry.choice = choice :: string
			publish()
		end
	end)
	Remotes.BattleTake.OnServerEvent:Connect(function(player: Player)
		if not takeLimiter:allow(player) or phase ~= "Machine" then
			return
		end
		local entry = find(entries, player)
		if entry and not entry.left then
			settleRun(entry, now() - entry.runStartedAt)
			publish()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		local entry = find(entries, player)
		if entry then
			entry.left = true
			publish()
		end
	end)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		sinceCheck += deltaTime
		if sinceCheck >= CHECK_SECONDS then
			sinceCheck = 0
			step()
		end
	end)
end

return BattleService
