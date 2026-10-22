--!strict
-- The Stock Spinner on each base (docs/design.md, "Stock Spinner";
-- Config/Spinner), which fills the base's own belt. While a base has an
-- owner, every RollSeconds its spinner rolls Results different companies
-- with the owner's odds: Config/Spinner's after their rebirths
-- (RebirthMath) and Spinner Luck (PerkMath), with variants as likely as their
-- Variant Chance makes them. The reels spin for SpinSeconds, then the roll
-- lands: whatever the last roll brought that's still on the belt goes, and
-- the new companies come out onto the belt one after another
-- (ConveyorService) and stop at their places along it. Only the owner can
-- buy them (PurchaseService), until the next roll lands.
--
-- Each base model gets attributes for the reels on the client
-- (SpinnerController), all times in server time: SpinnerRolledAt,
-- SpinnerLandsAt, SpinnerNextRollAt, and SpinnerResults, each company's id
-- (with ":" and its variant's id for a variant), comma separated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PerkMath = require(ReplicatedStorage.Shared.PerkMath)
local RebirthMath = require(ReplicatedStorage.Shared.RebirthMath)
local SpinnerConfig = require(ReplicatedStorage.Shared.Config.Spinner)
local SpinnerMath = require(ReplicatedStorage.Shared.SpinnerMath)
local VariantMath = require(ReplicatedStorage.Shared.VariantMath)
local BaseService = require(script.Parent.BaseService)
local ConveyorService = require(script.Parent.ConveyorService)
local DataService = require(script.Parent.DataService)

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
	nextRollAt: number?,
	roll: Roll?,
	-- What the last roll to land put on the belt.
	itemIds: { string },
}

local spinners: { [BaseService.Base]: Spinner } = {}
local random = Random.new()

local SpinnerService = {}

-- Odds after these rebirths and this much Spinner Luck, or the plain odds
-- with no data.
local function weightsFor(data: DataService.Data?): { SpinnerConfig.WeightEntry }
	if data == nil then
		return SpinnerConfig.Weights
	end
	local weights = RebirthMath.spinnerWeights(SpinnerConfig.Weights, data.Rebirths)
	local luck = PerkMath.multiplier("ConveyorLuck", PerkMath.level(data.Perks, "ConveyorLuck"))
	return PerkMath.luckyWeights(weights, luck)
end

local function variantChanceFor(data: DataService.Data?): number
	return if data then PerkMath.multiplier("VariantChance", PerkMath.level(data.Perks, "VariantChance")) else 1
end

local function ownerData(spinner: Spinner): DataService.Data?
	local owner = spinner.base.owner
	return if owner then DataService:GetData(owner) else nil
end

local function beltEnds(base: BaseService.Base): (Vector3, Vector3)
	return ConveyorService:Surface(base.conveyorStart), ConveyorService:Surface(base.conveyorEnd)
end

local function clearItems(spinner: Spinner)
	for _, itemId in spinner.itemIds do
		ConveyorService:RemoveItem(itemId)
	end
	table.clear(spinner.itemIds)
end

local function publish(spinner: Spinner)
	local model = spinner.base.model
	local roll = spinner.roll
	local results = {}
	if roll then
		for _, pick in roll.picks do
			table.insert(results, if pick.variant then `{pick.companyId}:{pick.variant}` else pick.companyId)
		end
	end
	model:SetAttribute("SpinnerRolledAt", if roll then roll.rolledAt else nil)
	model:SetAttribute("SpinnerLandsAt", if roll then roll.landsAt else nil)
	model:SetAttribute("SpinnerResults", if roll then table.concat(results, ",") else nil)
	model:SetAttribute("SpinnerNextRollAt", spinner.nextRollAt)
end

-- Starts a roll: the companies are picked now and land after SpinSeconds.
-- For admin testing, firstTier and firstVariant ("regular" for none) set the
-- first company's; otherwise they're rolled as usual.
local function roll(spinner: Spinner, data: DataService.Data, now: number, firstTier: string?, firstVariant: string?)
	local results = SpinnerMath.pick(weightsFor(data), SpinnerConfig.Results, function()
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
	local from, to = beltEnds(spinner.base)
	local landsAt = now + SpinnerConfig.SpinSeconds
	spinner.roll = {
		rolledAt = now,
		landsAt = landsAt,
		picks = picks,
		exits = SpinnerMath.exits(landsAt, #picks, (to - from).Magnitude),
		out = 0,
	}
	spinner.nextRollAt = now + SpinnerConfig.RollSeconds
	publish(spinner)
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

local function step(spinner: Spinner, now: number)
	-- Not until the owner's data is in, so the odds are theirs.
	local data = ownerData(spinner)
	if data == nil then
		return
	end
	local due = spinner.nextRollAt
	if due == nil or now >= due then
		roll(spinner, data, now)
	end
	local current = spinner.roll
	while current and current.out < #current.picks and now >= current.exits[current.out + 1].comesOutAt do
		-- The roll lands: what the last one brought makes way.
		if current.out == 0 then
			clearItems(spinner)
		end
		current.out += 1
		comeOut(spinner, current.picks[current.out], current.exits[current.out])
	end
end

local function reset(spinner: Spinner)
	clearItems(spinner)
	spinner.roll = nil
	spinner.nextRollAt = nil
	publish(spinner)
end

-- This player's spinner odds: after their rebirths and Spinner Luck.
function SpinnerService:GetWeights(player: Player): { SpinnerConfig.WeightEntry }
	return weightsFor(DataService:GetData(player))
end

-- How much more likely variants are in this player's spinner.
function SpinnerService:GetVariantChance(player: Player): number
	return variantChanceFor(DataService:GetData(player))
end

-- Rolls this player's spinner straight away, for admin testing. firstTier
-- and firstVariant ("regular" for none) set the first company's. Returns
-- false if they have no base or their data isn't in.
function SpinnerService:RollNow(player: Player, firstTier: string?, firstVariant: string?): boolean
	local base = BaseService:GetBase(player)
	local spinner = if base then spinners[base] else nil
	local data = DataService:GetData(player)
	if spinner == nil or data == nil then
		return false
	end
	roll(spinner, data, workspace:GetServerTimeNow(), firstTier, firstVariant)
	return true
end

function SpinnerService:Start()
	for _, base in BaseService:GetBases() do
		spinners[base] = { base = base, nextRollAt = nil, roll = nil, itemIds = {} }
	end
	BaseService:OnBaseFreed(function(_player, base)
		local spinner = spinners[base]
		if spinner then
			reset(spinner)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, spinner in spinners do
			step(spinner, now)
		end
	end)
end

return SpinnerService
