--!strict
-- Base upgrades: one more plot on the top floor at a time, then the next floor
-- once it is full (see UpgradeMath). The client only asks; the server works
-- out the next upgrade, checks the player's Cash and that the plot or floor is
-- built on their base, then charges for it and saves it.
--
-- Publishes the next upgrade in the NextUpgrade (text) and NextUpgradeCost
-- player attributes. Once the base is fully upgraded, NextUpgrade says so and
-- NextUpgradeCost is cleared.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UpgradeMath = require(ReplicatedStorage.Shared.UpgradeMath)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local FULLY_UPGRADED = "Fully upgraded"

local limiter = RateLimiter.new(2, 4)

local UpgradeService = {}

local function publish(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	local upgrade = UpgradeMath.next(data.UnlockedPlots)
	player:SetAttribute("NextUpgrade", if upgrade then UpgradeMath.describe(upgrade) else FULLY_UPGRADED)
	player:SetAttribute("NextUpgradeCost", if upgrade then upgrade.cost else nil)
end

-- Whether the plot (or, for a new floor, its first plot) exists on the base.
local function isBuilt(base: BaseService.Base, upgrade: UpgradeMath.Upgrade): boolean
	local plot = if upgrade.kind == "plot" then upgrade.plot else 1
	return base.plotsByKey[`Floor{upgrade.floor}/Plot{plot}`] ~= nil
end

-- Returns the message to show the player.
local function buy(player: Player): string
	local data = DataService:GetData(player)
	if data == nil then
		return "Your data hasn't loaded yet."
	end
	local base = BaseService:GetBase(player)
	if base == nil then
		return "You don't have a base."
	end

	local upgrade = UpgradeMath.next(data.UnlockedPlots)
	if upgrade == nil then
		return "Your base is fully upgraded."
	end
	if not isBuilt(base, upgrade) then
		return if upgrade.kind == "floor"
			then `Floor {upgrade.floor} isn't built on this base yet.`
			else `Plot {upgrade.plot} on floor {upgrade.floor} isn't built on this base yet.`
	end
	if data.Cash < upgrade.cost or not DataService:SpendCash(player, upgrade.cost) then
		return `You need {Format.cash(upgrade.cost)} for that upgrade.`
	end

	DataService:SetUnlockedPlots(player, UpgradeMath.apply(data.UnlockedPlots, upgrade))
	return if upgrade.kind == "floor"
		then `Opened floor {upgrade.floor}!`
		else `Unlocked plot {upgrade.plot} on floor {upgrade.floor}!`
end

function UpgradeService:Start()
	DataService:OnDataLoaded(publish)
	DataService:OnDataChanged(publish)

	Remotes.BuyUpgrade.OnServerEvent:Connect(function(player: Player)
		if limiter:allow(player) then
			Remotes.Notify:FireClient(player, buy(player))
		end
	end)
end

return UpgradeService
