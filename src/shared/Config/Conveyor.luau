--!strict
-- Conveyor timing, odds and buying range. Starting assumptions from
-- docs/design.md.

export type WeightEntry = { tier: string, weight: number }

return {
	-- Seconds a company takes to travel from the belt's Start to its End,
	-- after which it disappears if nobody bought it.
	TravelSeconds = 20,

	-- Each base's own conveyor; only the owner can buy from it.
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

	-- The conveyor in the middle of the map; anyone can buy, first come first
	-- served. Better odds, plus the two tiers found nowhere else.
	Shared = {
		SpawnSeconds = 2,
		-- Out of 100.
		Weights = {
			{ tier = "Startup", weight = 55 },
			{ tier = "ScaleUp", weight = 28 },
			{ tier = "Unicorn", weight = 12 },
			{ tier = "BlueChip", weight = 4 },
			{ tier = "Conglomerate", weight = 0.9 },
			{ tier = "Monopoly", weight = 0.1 },
		} :: { WeightEntry },
		-- Spawns of these tiers are announced to the whole server.
		AnnounceTiers = { Conglomerate = true, Monopoly = true } :: { [string]: boolean },
	},

	-- How close (in studs) a player must be to buy, and how much extra the
	-- server allows for the company moving and for network lag.
	BuyDistance = 10,
	BuyDistanceTolerance = 8,
}
