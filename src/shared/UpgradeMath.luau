--!strict
-- Base upgrades. A base is described by how many plots are open on each floor,
-- e.g. { 10, 7 } means Floor 1 is full and Floor 2 has 7 plots open. There is
-- only ever one next upgrade: another plot on the top floor until it is full,
-- then the next floor. Pure functions, so the server and tests share them.

local BaseConfig = require(script.Parent.Config.Base)

export type Upgrade = {
	kind: "plot" | "floor",
	floor: number,
	-- The plot being unlocked, for a plot upgrade.
	plot: number?,
	cost: number,
}

local UpgradeMath = {}

-- The next upgrade, or nil when every floor is open and full.
function UpgradeMath.next(unlockedPlots: { number }): Upgrade?
	local floor = #unlockedPlots
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

	if floor < BaseConfig.MaxFloors then
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

-- Whether a plot is open on a base described by unlockedPlots.
function UpgradeMath.isUnlocked(unlockedPlots: { number }, floor: number, plot: number): boolean
	local open = unlockedPlots[floor]
	return open ~= nil and plot <= open
end

-- A short description for the Upgrade button, e.g. "+1 plot" or "Floor 2".
function UpgradeMath.describe(upgrade: Upgrade): string
	return if upgrade.kind == "plot" then "+1 plot" else `Floor {upgrade.floor}`
end

return UpgradeMath
