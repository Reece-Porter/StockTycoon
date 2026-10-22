--!strict
-- Base upgrades. The plots a player has bought with Cash are kept as how many
-- are open on each floor, e.g. { 10, 7 } means Floor 1 is full and Floor 2
-- has 7 plots open. Only floors up to Config/Base.CashFloors are bought, and
-- there is only ever one next upgrade: another plot on the top floor until it
-- is full, then the next floor. The floors above open with rebirths instead
-- (UpgradeMath.open). Rebirth keeps every plot. Pure functions, so the server
-- and tests share them.

local BaseConfig = require(script.Parent.Config.Base)

export type Upgrade = {
	kind: "plot" | "floor",
	floor: number,
	-- The plot being unlocked, for a plot upgrade.
	plot: number?,
	cost: number,
}

local UpgradeMath = {}

-- The next upgrade to buy with Cash, or nil once the Cash floors are open
-- and full.
function UpgradeMath.next(unlockedPlots: { number }): Upgrade?
	local floor = #unlockedPlots
	if floor > BaseConfig.CashFloors then
		return nil
	end
	local open = unlockedPlots[floor] or 0

	if open < BaseConfig.PlotsPerFloor then
		local plot = open + 1
		local stepsPastStart = plot - BaseConfig.StartingPlots - 1
		return {
			kind = "plot",
			floor = floor,
			plot = plot,
			cost = BaseConfig.FirstExtraPlotCost[floor] * BaseConfig.PlotCostGrowth ^ stepsPastStart,
		}
	end

	if floor < BaseConfig.CashFloors then
		return { kind = "floor", floor = floor + 1, plot = nil, cost = BaseConfig.FloorCost[floor + 1] }
	end
	return nil
end

-- The base after buying an upgrade from UpgradeMath.next. Returns a new table.
function UpgradeMath.apply(unlockedPlots: { number }, upgrade: Upgrade): { number }
	local result = table.clone(unlockedPlots)
	if upgrade.kind == "plot" then
		result[upgrade.floor] = upgrade.plot :: number
	else
		result[upgrade.floor] = BaseConfig.StartingPlots
	end
	return result
end

-- Whether every plot on the Cash floors has been bought.
function UpgradeMath.cashFloorsFull(unlockedPlots: { number }): boolean
	local floors = BaseConfig.CashFloors
	return #unlockedPlots > floors or (unlockedPlots[floors] or 0) >= BaseConfig.PlotsPerFloor
end

-- How many plots on the floors above the Cash floors there are in all.
local function rebirthFloorPlots(): number
	return (BaseConfig.MaxFloors - BaseConfig.CashFloors) * BaseConfig.PlotsPerFloor
end

-- The plots this many rebirths open above the Cash floors.
function UpgradeMath.rebirthPlots(rebirths: number): number
	return math.min(math.max(0, math.floor(rebirths)) * BaseConfig.PlotsPerRebirth, rebirthFloorPlots())
end

-- The plots open on each floor of a base: the ones bought with Cash, then,
-- once the Cash floors are full, the rebirths' plots on the floors above,
-- filled from the bottom. (A save from before plots came from rebirths may
-- have bought some up there; it keeps whichever is more.) Returns a new
-- table.
function UpgradeMath.open(unlockedPlots: { number }, rebirths: number): { number }
	local result = {}
	for floor = 1, math.min(#unlockedPlots, BaseConfig.MaxFloors) do
		result[floor] = unlockedPlots[floor]
	end
	if UpgradeMath.cashFloorsFull(unlockedPlots) then
		local left = UpgradeMath.rebirthPlots(rebirths)
		for floor = BaseConfig.CashFloors + 1, BaseConfig.MaxFloors do
			if left <= 0 then
				break
			end
			local here = math.min(BaseConfig.PlotsPerFloor, left)
			result[floor] = math.max(result[floor] or 0, here)
			left -= here
		end
	end
	return result
end

-- The rebirth count that next opens a plot above the Cash floors, or nil once
-- they're all open. A base still buying its Cash floors gets the rebirths'
-- plots as soon as those are full.
function UpgradeMath.nextRebirthPlot(unlockedPlots: { number }, rebirths: number): number?
	local open = UpgradeMath.open(unlockedPlots, rebirths)
	local above = 0
	for floor = BaseConfig.CashFloors + 1, BaseConfig.MaxFloors do
		above += open[floor] or 0
	end
	if above >= rebirthFloorPlots() or BaseConfig.PlotsPerRebirth <= 0 then
		return nil
	end
	local count = math.max(0, math.floor(rebirths)) + 1
	while UpgradeMath.rebirthPlots(count) <= above do
		count += 1
	end
	return count
end

-- Whether a plot is open on a base described by open (from UpgradeMath.open).
function UpgradeMath.isUnlocked(open: { number }, floor: number, plot: number): boolean
	local count = open[floor]
	return count ~= nil and plot <= count
end

-- A short description for the Upgrade button, e.g. "+1 plot" or "Floor 2".
function UpgradeMath.describe(upgrade: Upgrade): string
	return if upgrade.kind == "plot" then "+1 plot" else `Floor {upgrade.floor}`
end

return UpgradeMath
