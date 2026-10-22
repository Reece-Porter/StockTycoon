--!strict
-- The upgrade station (docs/design.md, "Upgrade station"). Starting
-- assumptions.
--
-- Each upgrade has levels, bought one at a time with Gold at the station.
-- Each level adds perLevel to a multiplier that starts at 1 (0.06 = +6%). The
-- next level costs baseCost x costGrowth ^ (levels already bought), in Gold.
-- Levels are kept through rebirth, like Gold itself. Nothing here is ever
-- sold for Robux, and nothing touches the Valuation Machine.

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
		baseCost = 5,
		costGrowth = 1.3,
	},
	{
		id = "Damage",
		name = "Damage",
		description = "Your weapons hit harder.",
		perLevel = 0.1,
		maxLevel = 10,
		baseCost = 8,
		costGrowth = 1.3,
	},
	{
		id = "ConveyorLuck",
		-- Saved as ConveyorLuck from before the Stock Spinner replaced each
		-- base's own conveyor.
		name = "Spinner Luck",
		description = "More Luck: rarer tiers turn up more often in your Stock Spinner.",
		-- Multiplies the Luck rebirths give (SpinnerMath.luck), so up to x1.5.
		perLevel = 0.05,
		maxLevel = 10,
		baseCost = 10,
		costGrowth = 1.35,
	},
	{
		id = "Income",
		name = "Money Multiplier",
		description = "All your companies earn more.",
		perLevel = 0.1,
		maxLevel = 10,
		baseCost = 15,
		costGrowth = 1.4,
	},
	{
		id = "VariantChance",
		name = "Variant Chance",
		description = "Shiny, Galaxy and other variants turn up more often in your Stock Spinner.",
		perLevel = 0.15,
		maxLevel = 10,
		baseCost = 15,
		costGrowth = 1.4,
	},
}

local byId: { [string]: Perk } = {}
for _, perk in list do
	byId[perk.id] = perk
end

return {
	list = list,
	byId = byId,
	-- Levels are bought with Gold, which rebirth never takes, so rebirth keeps
	-- them too. (They used to cost Cash and go back to 0.)
	ResetOnRebirth = false,
	-- How close (in studs) a player must be to the upgrade station, plus the
	-- extra the server allows for lag.
	StationDistance = 12,
	StationDistanceTolerance = 6,
}
