--!strict
-- The Stock Spinner on each base (docs/design.md, "Stock Spinner";
-- Config/Spinner), which fills the base's own belt. The owner walks up to the
-- machine's Console and presses Spin (PlaySpinner). The server checks they're
-- the owner, close enough, and the machine isn't spinning or cooling down,
-- then rolls Results different companies with the owner's Luck (SpinnerMath:
-- their rebirths and Spinner Luck), with variants as likely as their Variant
-- Chance makes them. Whatever the last play left on the belt goes, and the
-- owner's screen shows the reels spinning in a pop-up (SpinnerRolled). When
-- they stop, after SpinSeconds, the new companies come out onto the belt one
-- after another (ConveyorService) and stop along it, where only the owner
-- can buy them (PurchaseService) until the machine is played again.
--
-- Each base model gets attributes for every player's screen (SpinnerController),
-- times in server time: SpinnerRolledAt, SpinnerLandsAt, SpinnerReadyAt,
-- SpinnerResults (each company's id, with ":" and its variant's id for a
-- variant, comma separated) and OwnerLuck (the owner's Luck, for the sign).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PerkMath = require(ReplicatedStorage.Shared.PerkMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpinnerConfig = require(ReplicatedStorage.Shared.Config.Spinner)
local SpinnerMath = require(ReplicatedStorage.Shared.SpinnerMath)
local VariantMath = require(ReplicatedStorage.Shared.VariantMath)
local BaseService = require(script.Parent.BaseService)
local ConveyorService = require(script.Parent.ConveyorService)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

-- How often each owner's Luck is checked for the sign.
local LUCK_CHECK_SECONDS = 1

-- One of a roll's companies.
type Pick = { companyId: string, tier: string, variant: string? }

type Roll = {
	rolledAt: number,
	landsAt: number,
	picks: { Pick },
	exits: { SpinnerMath.Exit },
	-- How many of its companies have come out so far.
	out: number,
}

type Spinner = {
	base: BaseService.Base,
	roll: Roll?,
	readyAt: number,
	-- What the last play put on the belt.
	itemIds: { string },
}

local spinners: { [BaseService.Base]: Spinner } = {}
local random = Random.new()
local playLimiter = RateLimiter.new(2, 3)

local SpinnerService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function luckFor(data: DataService.Data?): number
	return if data then SpinnerMath.luck(data.Rebirths, PerkMath.level(data.Perks, "ConveyorLuck")) else 1
end

local function variantChanceFor(data: DataService.Data?): number
	return if data then PerkMath.multiplier("VariantChance", PerkMath.level(data.Perks, "VariantChance")) else 1
end

local function beltEnds(base: BaseService.Base): (Vector3, Vector3)
	return ConveyorService:Surface(base.conveyorStart), ConveyorService:Surface(base.conveyorEnd)
end

-- The part the owner plays the machine at: its Console, or (on a map from
-- before the machine) the start of the belt.
local function consoleOf(base: BaseService.Base): BasePart
	local machine = base.model:FindFirstChild("Spinner")
	local console = machine and machine:FindFirstChild("Console")
	return if console and console:IsA("BasePart") then console else base.conveyorStart
end

local function clearItems(spinner: Spinner)
	for _, itemId in spinner.itemIds do
		ConveyorService:RemoveItem(itemId)
	end
	table.clear(spinner.itemIds)
end

local function resultsText(roll: Roll): string
	local results = {}
	for _, pick in roll.picks do
		table.insert(results, if pick.variant then `{pick.companyId}:{pick.variant}` else pick.companyId)
	end
	return table.concat(results, ",")
end

local function publish(spinner: Spinner)
	local model = spinner.base.model
	local roll = spinner.roll
	model:SetAttribute("SpinnerRolledAt", if roll then roll.rolledAt else nil)
	model:SetAttribute("SpinnerLandsAt", if roll then roll.landsAt else nil)
	model:SetAttribute("SpinnerResults", if roll then resultsText(roll) else nil)
	model:SetAttribute("SpinnerReadyAt", if spinner.base.owner then spinner.readyAt else nil)
end

-- Rolls the companies and starts the reels: what the last play left on the
-- belt goes now, and the new ones come out when the reels stop. For admin
-- testing, firstTier and firstVariant ("regular" for none) set the first
-- company's; otherwise they're rolled as usual.
local function play(spinner: Spinner, player: Player, data: DataService.Data, firstTier: string?, firstVariant: string?)
	local time = now()
	local luck = luckFor(data)
	local weights = SpinnerMath.weights(SpinnerConfig.Weights, luck)
	local results = SpinnerMath.pick(weights, SpinnerConfig.Results, function()
		return random:NextNumber()
	end, firstTier)
	local chance = variantChanceFor(data)
	local picks: { Pick } = {}
	for index, result in results do
		local variant = if index == 1 and firstVariant == "regular"
			then nil
			elseif index == 1 and firstVariant then firstVariant
			else VariantMath.roll(random:NextNumber(), chance)
		table.insert(picks, { companyId = result.companyId, tier = result.tier, variant = variant })
	end
	clearItems(spinner)
	local from, to = beltEnds(spinner.base)
	local landsAt = time + SpinnerConfig.SpinSeconds
	local roll: Roll = {
		rolledAt = time,
		landsAt = landsAt,
		picks = picks,
		exits = SpinnerMath.exits(landsAt, #picks, (to - from).Magnitude),
		out = 0,
	}
	spinner.roll = roll
	spinner.readyAt = time + SpinnerConfig.CooldownSeconds
	publish(spinner)
	Remotes.SpinnerRolled:FireClient(player, resultsText(roll), roll.rolledAt, roll.landsAt, luck)
end

-- Returns why the player can't play now, or nil once they've played.
local function tryToPlay(player: Player): string?
	local base = BaseService:GetBase(player)
	local spinner = if base then spinners[base] else nil
	local data = DataService:GetData(player)
	if base == nil or spinner == nil then
		return "You don't have a base."
	end
	if data == nil then
		return "Your data hasn't loaded yet."
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local reach = SpinnerConfig.PlayDistance + SpinnerConfig.PlayDistanceTolerance
	if root == nil or not root:IsA("BasePart") or (root.Position - consoleOf(base).Position).Magnitude > reach then
		return "Get closer to your Stock Spinner."
	end
	local roll = spinner.roll
	if roll and now() < roll.landsAt then
		return "It's already spinning!"
	end
	if now() < spinner.readyAt then
		return `Your Stock Spinner is ready in {math.ceil(spinner.readyAt - now())}s.`
	end
	play(spinner, player, data)
	return nil
end

local function comeOut(spinner: Spinner, pick: Pick, exit: SpinnerMath.Exit)
	local owner = spinner.base.owner
	if owner == nil then
		return
	end
	local from, to = beltEnds(spinner.base)
	local item = ConveyorService:AddItem({
		companyId = pick.companyId,
		variant = pick.variant,
		ownerUserId = owner.UserId,
		base = spinner.base,
		from = from,
		to = from:Lerp(to, exit.stop),
		travelSeconds = exit.travelSeconds,
		expiresAt = nil,
	})
	if item then
		table.insert(spinner.itemIds, item.id)
	end
end

local function step(spinner: Spinner, time: number)
	local roll = spinner.roll
	while roll and roll.out < #roll.picks and time >= roll.exits[roll.out + 1].comesOutAt do
		roll.out += 1
		comeOut(spinner, roll.picks[roll.out], roll.exits[roll.out])
	end
end

-- Keeps each base's OwnerLuck attribute up to date (rebirths and upgrades
-- change it).
local function showLuck()
	for base, _ in spinners do
		local owner = base.owner
		local data = if owner then DataService:GetData(owner) else nil
		local luck = if data then math.floor(luckFor(data) * 100 + 0.5) / 100 else nil
		if base.model:GetAttribute("OwnerLuck") ~= luck then
			base.model:SetAttribute("OwnerLuck", luck)
		end
	end
end

-- This player's spinner odds at their Luck.
function SpinnerService:GetWeights(player: Player): { SpinnerConfig.WeightEntry }
	return SpinnerMath.weights(SpinnerConfig.Weights, luckFor(DataService:GetData(player)))
end

function SpinnerService:GetLuck(player: Player): number
	return luckFor(DataService:GetData(player))
end

-- How much more likely variants are in this player's spinner.
function SpinnerService:GetVariantChance(player: Player): number
	return variantChanceFor(DataService:GetData(player))
end

-- Plays this player's spinner straight away, from anywhere and with no wait,
-- for admin testing. firstTier and firstVariant ("regular" for none) set the
-- first company's. Returns false if they have no base or their data isn't
-- in.
function SpinnerService:RollNow(player: Player, firstTier: string?, firstVariant: string?): boolean
	local base = BaseService:GetBase(player)
	local spinner = if base then spinners[base] else nil
	local data = DataService:GetData(player)
	if spinner == nil or data == nil then
		return false
	end
	play(spinner, player, data, firstTier, firstVariant)
	return true
end

function SpinnerService:Start()
	for _, base in BaseService:GetBases() do
		spinners[base] = { base = base, roll = nil, readyAt = 0, itemIds = {} }
	end
	BaseService:OnBaseAssigned(function(_player, base)
		local spinner = spinners[base]
		if spinner then
			publish(spinner)
		end
	end)
	BaseService:OnBaseFreed(function(_player, base)
		local spinner = spinners[base]
		if spinner then
			clearItems(spinner)
			spinner.roll = nil
			spinner.readyAt = 0
			publish(spinner)
		end
		base.model:SetAttribute("OwnerLuck", nil)
	end)

	Remotes.PlaySpinner.OnServerEvent:Connect(function(player: Player)
		if not playLimiter:allow(player) then
			return
		end
		local problem = tryToPlay(player)
		if problem then
			Remotes.Notify:FireClient(player, problem)
		end
	end)

	local sinceLuck = LUCK_CHECK_SECONDS
	RunService.Heartbeat:Connect(function(deltaTime)
		local time = now()
		for _, spinner in spinners do
			step(spinner, time)
		end
		sinceLuck += deltaTime
		if sinceLuck >= LUCK_CHECK_SECONDS then
			sinceLuck = 0
			showLuck()
		end
	end)
end

return SpinnerService
