--!strict
-- Base numbers. Starting assumptions from docs/design.md.

return {
	-- Unplaced companies a player can keep.
	StorageCapacity = 5,

	-- Plots a new player can use on Floor 1. Upgrades unlock the rest
	-- (base upgrades slice).
	StartingPlots = 6,

	-- How close (in studs) a player must be to use a plot, and how much extra
	-- the server allows for network lag.
	PlotDistance = 10,
	PlotDistanceTolerance = 6,

	-- Transparency for plots the owner hasn't unlocked yet.
	LockedPlotTransparency = 0.75,
}
