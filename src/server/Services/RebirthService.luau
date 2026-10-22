--!strict
-- Rebirth (docs/design.md, "Rebirth"). A player with enough Cash
-- (RebirthMath.cashRequired, x2 each time) who owns a company of the tier
-- their next rebirth needs (RebirthMath.requiredTier: a Startup at first, a
-- little rarer every few rebirths) gives up their Cash for a permanent income
-- multiplier (RebirthMath.incomeMultiplier), more Stock Spinner Luck
-- (RebirthMath.luck) and Config/Base.PlotsPerRebirth more plots on the floors
-- above the ones bought with Cash (UpgradeMath.open). Everything else is
-- kept (DataService:Rebirth), and the company isn't used up. The client only
-- asks; every requirement is checked here, and the save is written straight
-- away.
--
-- Players get Rebirths, RebirthCost, RebirthTier (the tier id the next one
-- needs) and RebirthHasTier attributes for the rebirth screen, and a Rebirths
-- column in the player list.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.Shared.Config.Base)
local Format = require(ReplicatedStorage.Shared.Format)
local RebirthMath = require(ReplicatedStorage.Shared.RebirthMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Types = require(ReplicatedStorage.Shared.Types)
local UpgradeMath = require(ReplicatedStorage.Shared.UpgradeMath)
local AnalyticsService = require(script.Parent.AnalyticsService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local rebirthLimiter = RateLimiter.new(0.5, 2)

local RebirthService = {}

local function notify(player: Player, message: string)
	if player.Parent == Players then
		Remotes.Notify:FireClient(player, message)
	end
end

-- Every company the player owns that counts for the tier requirement: placed
-- or in storage.
local function ownedCompanies(data: DataService.Data): { Types.CompanyInstance }
	local companies = table.clone(data.Storage)
	for _, company in data.Placed do
		table.insert(companies, company)
	end
	return companies
end

local function publish(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("RebirthCost", RebirthMath.cashRequired(data.Rebirths))
	player:SetAttribute("RebirthTier", RebirthMath.requiredTier(data.Rebirths))
	player:SetAttribute("RebirthHasTier", RebirthMath.hasRequiredTier(ownedCompanies(data), data.Rebirths))

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local value = leaderstats:FindFirstChild("Rebirths")
		if value == nil then
			local newValue = Instance.new("IntValue")
			newValue.Name = "Rebirths"
			newValue.Parent = leaderstats
			value = newValue
		end
		if value and value:IsA("IntValue") then
			value.Value = data.Rebirths
		end
	end
end

-- What the rebirth did for the player's plots: where new ones opened, or
-- that they're waiting for the Cash floors to be bought.
local function plotsMessage(data: DataService.Data, before: { number }, after: { number }): string
	local opened = {}
	for floor = BaseConfig.CashFloors + 1, BaseConfig.MaxFloors do
		local added = (after[floor] or 0) - (before[floor] or 0)
		if added > 0 then
			table.insert(opened, `{added} on floor {floor}`)
		end
	end
	if #opened > 0 then
		return `New plots: {table.concat(opened, " and ")}!`
	end
	local waiting = UpgradeMath.rebirthPlots(data.Rebirths)
	if waiting > 0 and not UpgradeMath.cashFloorsFull(data.UnlockedPlots) then
		return `{waiting} plots above floor {BaseConfig.CashFloors} are waiting: they open once floor {BaseConfig.CashFloors} is full.`
	end
	return "Your base is kept."
end

-- Returns the message for the player.
local function rebirth(player: Player): string
	local data = DataService:GetData(player)
	if data == nil then
		return "Your data hasn't loaded yet."
	end
	local required = RebirthMath.cashRequired(data.Rebirths)
	if data.Cash < required then
		return `You need {Format.cash(required)} to rebirth.`
	end
	if not RebirthMath.hasRequiredTier(ownedCompanies(data), data.Rebirths) then
		local tier = Tiers.byId[RebirthMath.requiredTier(data.Rebirths)]
		return `You need a {tier.name} company or better, placed or in storage.`
	end
	if CarryService:IsCarrying(player) then
		return "Put down what you're carrying first."
	end
	if data.Machine then
		return "Wait for your Valuation Machine run to finish."
	end

	local openBefore = UpgradeMath.open(data.UnlockedPlots, data.Rebirths)
	if not DataService:Rebirth(player) then
		return "Your data hasn't loaded yet."
	end
	local rebirths = data.Rebirths
	local openAfter = UpgradeMath.open(data.UnlockedPlots, rebirths)
	AnalyticsService:Rebirthed(player, rebirths)
	DataService:SaveNow(player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			notify(other, `{player.Name} rebirthed! (Rebirth {rebirths})`)
		end
	end
	local multiplier = RebirthMath.incomeMultiplier(rebirths)
	return `Rebirth {rebirths}! Your income is now x{multiplier}. {plotsMessage(data, openBefore, openAfter)}`
end

function RebirthService:Start()
	DataService:OnDataLoaded(publish)
	DataService:OnDataChanged(publish)

	Remotes.Rebirth.OnServerEvent:Connect(function(player: Player)
		if rebirthLimiter:allow(player) then
			notify(player, rebirth(player))
		end
	end)
end

return RebirthService
