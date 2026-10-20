--!strict
-- Offline earnings (docs/design.md, "Offline earnings"). When a player joins,
-- their companies earn Config/Offline.IncomeShare of the income they make now
-- for the time since they were last in the game, up to MaxSeconds (OfflineMath).
-- The player's OfflineEarnings attribute (JSON: away, counted and cash) tells
-- the client to show a "while you were away" popup.
--
-- LastSeen is saved when the player leaves (DataService) and every minute
-- while they play, so a server shutting down can't make time spent in the
-- game count as time away.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OfflineMath = require(ReplicatedStorage.Shared.OfflineMath)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)

local TOUCH_SECONDS = 60

-- Players whose offline earnings have been worked out this session. Only
-- these have LastSeen moved on, so it can't be overwritten before it's read.
local settled: { [Player]: true } = {}

local OfflineService = {}

local function settle(player: Player)
	local data = DataService:GetData(player)
	if data == nil or settled[player] then
		return
	end
	local lastSeen = data.LastSeen
	local now = os.time()
	DataService:SetLastSeen(player, now)
	settled[player] = true
	if lastSeen <= 0 then
		return
	end
	-- Income as it is now, without a reward boost (boosts only run in game).
	local away = now - lastSeen
	local cash, counted = OfflineMath.earnings(IncomeService:GetIncomePerSecond(player, true), away)
	if cash > 0 then
		DataService:AddCash(player, cash)
		player:SetAttribute("OfflineEarnings", HttpService:JSONEncode({ away = away, counted = counted, cash = cash }))
	end
end

function OfflineService:Start()
	DataService:OnDataLoaded(settle)
	Players.PlayerRemoving:Connect(function(player)
		settled[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TOUCH_SECONDS)
			for player in settled do
				DataService:SetLastSeen(player, os.time())
			end
		end
	end)
end

return OfflineService
