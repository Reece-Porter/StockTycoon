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
local DataService = require(script.Parent.DataService)

-- A payout never covers more than this many seconds, so a long server stall
-- can't hand out a sudden burst.
local MAX_PAYOUT_SECONDS = 10

local rates: { [Player]: number } = {}

local IncomeService = {}

-- Pet, rebirth, boost and game pass multipliers arrive in later slices; until
-- then they are all 1.
local function multipliersFor(_player: Player): IncomeMath.Multipliers
	return IncomeMath.noMultipliers()
end

local function updateRate(player: Player)
	local data = DataService:GetData(player)
	if data == nil or player.Parent ~= Players then
		return
	end
	local rate = IncomeMath.total(data.Placed, multipliersFor(player))
	rates[player] = rate
	player:SetAttribute("IncomePerSecond", rate)
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
