--!strict
-- Pays every player the income of their placed companies, worked out with
-- IncomeMath. Each payout covers the exact time since the last one, so the rate
-- matches Config whatever the payout interval. Players earn only while in the
-- game; offline earnings come in a later slice.
--
-- Publishes the player's income per second in their IncomePerSecond attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local IncomeMath = require(ReplicatedStorage.Shared.IncomeMath)
local PetMath = require(ReplicatedStorage.Shared.PetMath)
local RebirthMath = require(ReplicatedStorage.Shared.RebirthMath)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)

-- A payout never covers more than this many seconds, so a long server stall
-- can't hand out a sudden burst.
local MAX_PAYOUT_SECONDS = 10

local rates: { [Player]: number } = {}

local IncomeService = {}

-- Floor pets and rebirths count now. Boost and game pass multipliers arrive
-- in later slices; until then they are 1.
local function multipliersFor(data: DataService.Data): IncomeMath.Multipliers
	local multipliers = IncomeMath.noMultipliers()
	multipliers.floorPet = PetMath.incomeMultipliers(data.Pets)
	multipliers.rebirth = RebirthMath.incomeMultiplier(data.Rebirths)
	return multipliers
end

local function updateRate(player: Player)
	local data = DataService:GetData(player)
	if data == nil or player.Parent ~= Players then
		return
	end
	-- A company being carried off by a thief isn't on its plot, so it doesn't earn.
	local placed = {}
	for plotKey, company in data.Placed do
		if not CarryService:IsPlotBeingStolen(player, plotKey) then
			placed[plotKey] = company
		end
	end
	local rate = IncomeMath.total(placed, multipliersFor(data))
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
	return if data then multipliersFor(data) else IncomeMath.noMultipliers()
end

function IncomeService:GetIncomePerSecond(player: Player): number
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
				if rate > 0 then
					DataService:AddCash(player, rate * elapsed)
				end
			end
		end
	end)
end

return IncomeService
