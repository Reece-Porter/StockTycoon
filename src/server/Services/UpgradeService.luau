--!strict
-- Base upgrades: one more plot on the top floor at a time, then the next floor
-- once it is full, up to Config/Base.CashFloors (see UpgradeMath). The floors
-- above open with rebirths, not Cash. The client only asks; the server works
-- out the next upgrade, checks the player's Cash and that the plot or floor is
-- built on their base, then charges for it and saves it.
--
-- Publishes the next upgrade in the NextUpgrade (text) and NextUpgradeCost
-- player attributes. Once the Cash floors are full, NextUpgradeCost is
-- cleared and NextUpgradeRebirth is the rebirth count that opens the next
-- plot (until they're all open, when NextUpgrade says the base is fully
-- upgraded). PlotsWaiting is how many plots the player's rebirths have
-- earned that wait for the Cash floors to be full.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.Shared.Config.Base)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UpgradeMath = require(ReplicatedStorage.Shared.UpgradeMath)
local AnalyticsService = require(script.Parent.AnalyticsService)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local FULLY_UPGRADED = "Fully upgraded"

local limiter = RateLimiter.new(2, 4)

local UpgradeService = {}

-- The floor the next rebirth plot opens on.
local function rebirthFloor(data: DataService.Data): number
	local open = UpgradeMath.open(data.UnlockedPlots, data.Rebirths)
	for floor = BaseConfig.CashFloors + 1, BaseConfig.MaxFloors do
		if (open[floor] or 0) < BaseConfig.PlotsPerFloor then
			return floor
		end
	end
	return BaseConfig.MaxFloors
end

local function publish(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	local upgrade = UpgradeMath.next(data.UnlockedPlots)
	local rebirth = if upgrade then nil else UpgradeMath.nextRebirthPlot(data.UnlockedPlots, data.Rebirths)
	local label = if upgrade
		then UpgradeMath.describe(upgrade)
		elseif rebirth then `Floor {rebirthFloor(data)}`
		else FULLY_UPGRADED
	player:SetAttribute("NextUpgrade", label)
	player:SetAttribute("NextUpgradeCost", if upgrade then upgrade.cost else nil)
	player:SetAttribute("NextUpgradeRebirth", rebirth)
	local waiting = if UpgradeMath.cashFloorsFull(data.UnlockedPlots)
		then 0
		else UpgradeMath.rebirthPlots(data.Rebirths)
	player:SetAttribute("PlotsWaiting", waiting)
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
		local rebirth = UpgradeMath.nextRebirthPlot(data.UnlockedPlots, data.Rebirths)
		return if rebirth
			then `More plots open with rebirths now: the next at rebirth {rebirth}.`
			else "Your base is fully upgraded."
	end
	if not isBuilt(base, upgrade) then
		return if upgrade.kind == "floor"
			then `Floor {upgrade.floor} isn't built on this base yet.`
			else `Plot {upgrade.plot} on floor {upgrade.floor} isn't built on this base yet.`
	end
	if data.Cash < upgrade.cost or not DataService:SpendCash(player, upgrade.cost) then
		return `You need {Format.cash(upgrade.cost)} for that upgrade.`
	end

	local unlocked = UpgradeMath.apply(data.UnlockedPlots, upgrade)
	DataService:SetUnlockedPlots(player, unlocked)
	AnalyticsService:Spent(player, "Upgrade", upgrade.cost, upgrade.kind)
	local message = if upgrade.kind == "floor"
		then `Opened floor {upgrade.floor}!`
		else `Unlocked plot {upgrade.plot} on floor {upgrade.floor}!`
	-- Filling the Cash floors opens the plots the player's rebirths earned.
	local earned = UpgradeMath.rebirthPlots(data.Rebirths)
	if UpgradeMath.cashFloorsFull(unlocked) and earned > 0 then
		message ..= ` Your rebirths opened {earned} more plots above it.`
	end
	return message
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
