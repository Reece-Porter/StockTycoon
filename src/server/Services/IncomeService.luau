--!strict
-- Pays every player the income of their placed companies, worked out with
-- IncomeMath. Each payout covers the exact time since the last one, so the rate
-- matches Config whatever the payout interval. Players earn only while in the
-- game (OfflineService pays for time away). The 2x Income game pass doubles
-- it (Lib/Passes).
--
-- Publishes the player's income per second in their IncomePerSecond attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local IncomeMath = require(ReplicatedStorage.Shared.IncomeMath)
local Monetisation = require(ReplicatedStorage.Shared.Config.Monetisation)
local PetMath = require(ReplicatedStorage.Shared.PetMath)
local RebirthMath = require(ReplicatedStorage.Shared.RebirthMath)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.Rewards)
local AnalyticsService = require(script.Parent.AnalyticsService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local Passes = require(script.Parent.Parent.Lib.Passes)

-- A payout never covers more than this many seconds, so a long server stall
-- can't hand out a sudden burst.
local MAX_PAYOUT_SECONDS = 10

local rates: { [Player]: number } = {}

local IncomeService = {}

-- Floor pets, rebirths and reward boosts count now. The game pass multiplier
-- arrives in a later slice; until then it is 1.
local function multipliersFor(player: Player, data: DataService.Data): IncomeMath.Multipliers
	local multipliers = IncomeMath.noMultipliers()
	multipliers.gamePass = if Passes.owns(player, "DoubleIncome") then Monetisation.IncomeMultiplier else 1
	multipliers.floorPet = PetMath.incomeMultipliers(data.Pets)
	multipliers.rebirth = RebirthMath.incomeMultiplier(data.Rebirths)
	multipliers.boost = if data.Rewards.BoostSeconds > 0 then RewardsConfig.BoostMultiplier else 1
	return multipliers
end

-- Income per second from the companies on their plots. A company being
-- carried off by a thief isn't on its plot, so it doesn't earn.
local function rateOf(player: Player, data: DataService.Data, withoutBoost: boolean?): number
	local placed = {}
	for plotKey, company in data.Placed do
		if not CarryService:IsPlotBeingStolen(player, plotKey) then
			placed[plotKey] = company
		end
	end
	local multipliers = multipliersFor(player, data)
	if withoutBoost then
		multipliers.boost = 1
	end
	return IncomeMath.total(placed, multipliers)
end

local function updateRate(player: Player)
	local data = DataService:GetData(player)
	if data == nil or player.Parent ~= Players then
		return
	end
	local rate = rateOf(player, data)
	rates[player] = rate
	player:SetAttribute("IncomePerSecond", rate)
end

-- Works the player's income out again, e.g. when a steal starts or ends.
function IncomeService:Refresh(player: Player)
	updateRate(player)
end

-- Everything multiplying the player's income, e.g. for showing one company's
-- income on its plot.
function IncomeService:GetMultipliers(player: Player): IncomeMath.Multipliers
	local data = DataService:GetData(player)
	return if data then multipliersFor(player, data) else IncomeMath.noMultipliers()
end

-- The player's income per second; withoutBoost leaves out a reward boost (so
-- a reward worth some seconds of income isn't doubled by another reward).
function IncomeService:GetIncomePerSecond(player: Player, withoutBoost: boolean?): number
	if withoutBoost then
		local data = DataService:GetData(player)
		return if data then rateOf(player, data, true) else 0
	end
	return rates[player] or 0
end

function IncomeService:Start()
	DataService:OnDataLoaded(updateRate)
	DataService:OnDataChanged(updateRate)
	Players.PlayerRemoving:Connect(function(player)
		rates[player] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Economy.IncomePayoutSeconds)
			local now = os.clock()
			local elapsed = math.min(now - last, MAX_PAYOUT_SECONDS)
			last = now
			for player, rate in rates do
				if rate > 0 and DataService:AddCash(player, rate * elapsed) then
					AnalyticsService:Earned(player, "Income", rate * elapsed)
				end
			end
		end
	end)
end

return IncomeService
