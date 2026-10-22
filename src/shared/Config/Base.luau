--!strict
-- Base numbers. Starting assumptions from docs/design.md.

return {
	-- The build of the map the game expects (studio/BuildMap.luau sets it on
	-- Workspace.Map as the MapVersion attribute). An older map gets a warning
	-- in the Output and the admin debug panel, and a notice for admins.
	MapVersion = 5,

	-- Unplaced companies a player can keep.
	StorageCapacity = 5,

	-- Plots open on a floor when it is first opened (Floor 1 for a new player).
	StartingPlots = 6,
	PlotsPerFloor = 10,
	MaxFloors = 4,

	-- Upgrade costs. Extra plots unlock one at a time: the first extra plot
	-- (Plot7) on each floor costs FirstExtraPlotCost[floor], and each one after
	-- costs PlotCostGrowth times the one before. A full floor lets the player
	-- open the next floor for FloorCost[floor]; Floor 1 is open from the start.
	FirstExtraPlotCost = { 250, 12_000, 250_000, 4_000_000 },
	PlotCostGrowth = 2,
	FloorCost = { 0, 8_000, 150_000, 3_000_000 },

	-- How close (in studs) a player must be to use a plot, and how much extra
	-- the server allows for network lag.
	PlotDistance = 10,
	PlotDistanceTolerance = 6,

	-- Cash pads: a player counts as standing on a pad while their character
	-- is within this many studs of its edges and no more than PadHeight above
	-- it. Each collect takes at least MinCollect Cash, so standing on a pad
	-- doesn't collect a sliver every moment.
	PadReach = 1,
	PadHeight = 7,
	MinCollect = 1,
}
