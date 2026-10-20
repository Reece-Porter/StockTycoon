--!strict
-- Conveyor timing, odds and buying range. Starting assumptions from
-- docs/design.md.

export type WeightEntry = { tier: string, weight: number }

return {
	-- Seconds a company takes to travel from the belt's Start to its End,
	-- after which it disappears if nobody bought it.
	TravelSeconds = 20,

	Personal = {
		SpawnSeconds = 3,
		-- Out of 100. Rebirths will shift some weight to higher tiers; that
		-- rule gets agreed in the rebirth slice.
		Weights = {
			{ tier = "Startup", weight = 70 },
			{ tier = "ScaleUp", weight = 22 },
			{ tier = "Unicorn", weight = 7 },
			{ tier = "BlueChip", weight = 1 },
		} :: { WeightEntry },
	},

	-- How close (in studs) a player must be to buy, and how much extra the
	-- server allows for the company moving and for network lag.
	BuyDistance = 10,
	BuyDistanceTolerance = 8,
}
