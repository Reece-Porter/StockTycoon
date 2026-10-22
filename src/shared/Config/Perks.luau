--!strict
-- The upgrade station (docs/design.md, "Upgrade station"). Starting
-- assumptions.
--
-- Each upgrade has levels, bought one at a time with Cash at the station.
-- Each level adds perLevel to a multiplier that starts at 1 (0.06 = +6%). The
-- next level costs baseCost x costGrowth ^ (levels already bought). Nothing
-- here is ever sold for Robux, and nothing touches the Valuation Machine.

export type PerkId = "WalkSpeed" | "Damage" | "ConveyorLuck" | "Income" | "VariantChance"
export type Perk = {
	id: PerkId,
	name: string,
	description: string,
	perLevel: number,
	maxLevel: number,
	baseCost: number,
	costGrowth: number,
}

local list: { Perk } = {
	{
		id = "WalkSpeed",
		name = "Walk Speed",
		description = "Walk and run faster.",
		perLevel = 0.06,
		maxLevel = 10,
		baseCost = 300,
		costGrowth = 1.8,
	},
	{
		id = "Damage",
		name = "Damage",
		description = "Your weapons hit harder.",
		perLevel = 0.1,
		maxLevel = 10,
		baseCost = 500,
		costGrowth = 1.8,
	},
	{
		id = "ConveyorLuck",
		-- Saved as ConveyorLuck from before the Stock Spinner replaced each
		-- base's own conveyor.
		name = "Spinner Luck",
		description = "Rarer tiers turn up more often in your Stock Spinner.",
		perLevel = 0.1,
		maxLevel = 10,
		baseCost = 1_000,
		costGrowth = 2,
	},
	{
		id = "Income",
		name = "Money Multiplier",
		description = "All your companies earn more.",
		perLevel = 0.1,
		maxLevel = 10,
		baseCost = 2_000,
		costGrowth = 2.1,
	},
	{
		id = "VariantChance",
		name = "Variant Chance",
		description = "Shiny, Galaxy and other variants turn up more often in your Stock Spinner.",
		perLevel = 0.15,
		maxLevel = 10,
		baseCost = 2_500,
		costGrowth = 2.1,
	},
}

local byId: { [string]: Perk } = {}
for _, perk in list do
	byId[perk.id] = perk
end

return {
	list = list,
	byId = byId,
	-- Rebirth sets every upgrade back to level 0, like base upgrades.
	ResetOnRebirth = true,
	-- How close (in studs) a player must be to the upgrade station, plus the
	-- extra the server allows for lag.
	StationDistance = 12,
	StationDistanceTolerance = 6,
}
