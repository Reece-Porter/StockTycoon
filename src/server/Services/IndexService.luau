--!strict
-- The Index (Config/Index): every kind of company a player has ever owned,
-- with prizes for collecting so many different ones. A company counts once it
-- is in the player's save in any way (storage, a plot, their hands or the
-- Valuation Machine), so buying and completing a steal both count. The Index
-- and its claimed prizes are kept through rebirth. Prizes are given by
-- RewardsService; the client only asks to claim.
--
-- Players get IndexDiscovered and IndexClaimed attributes (JSON lists) for
-- the Index screen.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local IndexConfig = require(ReplicatedStorage.Shared.Config.Index)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local RewardsService = require(script.Parent.RewardsService)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local claimLimiter = RateLimiter.new(2, 4)

local IndexService = {}

local function notify(player: Player, message: string)
	if player.Parent == Players then
		Remotes.Notify:FireClient(player, message)
	end
end

-- How many of the game's companies the player has discovered.
local function discoveredCount(data: DataService.Data): number
	local count = 0
	for _, company in Companies.list do
		if data.Index.Discovered[company.id] then
			count += 1
		end
	end
	return count
end

local function publish(player: Player)
	local data = DataService:GetData(player)
	if data == nil or player.Parent ~= Players then
		return
	end
	local discovered = {}
	for _, company in Companies.list do
		if data.Index.Discovered[company.id] then
			table.insert(discovered, company.id)
		end
	end
	player:SetAttribute("IndexDiscovered", HttpService:JSONEncode(discovered))
	player:SetAttribute("IndexClaimed", HttpService:JSONEncode(data.Index.Claimed))
end

-- Adds any company the player owns now that isn't in their Index yet.
local function scan(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	local found = {}
	local function check(companyId: string)
		if Companies.byId[companyId] and not data.Index.Discovered[companyId] and not table.find(found, companyId) then
			table.insert(found, companyId)
		end
	end
	for _, company in data.Storage do
		check(company.companyId)
	end
	for _, company in data.Placed do
		check(company.companyId)
	end
	if data.Carrying then
		check(data.Carrying.companyId)
	end
	if data.Machine then
		check(data.Machine.company.companyId)
	end
	if #found == 0 then
		publish(player)
		return
	end
	-- Discover fires a data change, which publishes the new list.
	local added = DataService:Discover(player, found)
	local total = discoveredCount(data)
	for _, companyId in added do
		notify(player, `New in your Index: {Companies.byId[companyId].name}! ({total}/{#Companies.list})`)
	end
end

-- Returns the message for the player.
local function claim(player: Player, count: number): string
	local milestone = nil
	for _, candidate in IndexConfig.Milestones do
		if candidate.count == count then
			milestone = candidate
		end
	end
	local data = DataService:GetData(player)
	if milestone == nil or data == nil then
		return "That isn't an Index prize."
	end
	local have = discoveredCount(data)
	if have < count then
		return `Collect {count - have} more companies for that prize.`
	end
	if not DataService:ClaimIndex(player, count) then
		return "You've already claimed that prize."
	end
	return `Index prize for {count} companies: {RewardsService:Grant(player, milestone.grants)}!`
end

-- Admin testing: discovers up to this many companies the player hasn't found
-- yet, at random.
function IndexService:DiscoverRandom(player: Player, count: number): number
	local data = DataService:GetData(player)
	if data == nil then
		return 0
	end
	local missing = {}
	for _, company in Companies.list do
		if not data.Index.Discovered[company.id] then
			table.insert(missing, company.id)
		end
	end
	local chosen = {}
	for _ = 1, math.min(count, #missing) do
		table.insert(chosen, table.remove(missing, math.random(#missing)) :: string)
	end
	return #DataService:Discover(player, chosen)
end

function IndexService:GetDiscoveredCount(player: Player): number
	local data = DataService:GetData(player)
	return if data then discoveredCount(data) else 0
end

function IndexService:Start()
	DataService:OnDataLoaded(scan)
	DataService:OnDataChanged(scan)

	Remotes.ClaimIndex.OnServerEvent:Connect(function(player: Player, count: unknown)
		if claimLimiter:allow(player) and typeof(count) == "number" then
			notify(player, claim(player, count))
		end
	end)
end

return IndexService
