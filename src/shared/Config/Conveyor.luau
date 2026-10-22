--!strict
-- The shared conveyor's timing and odds, and the buying range for anything
-- on a belt. Starting assumptions from docs/design.md. Each base's own belt
-- is fed by its Stock Spinner instead (Config/Spinner).

export type WeightEntry = { tier: string, weight: number }

return {
	-- The conveyor in the middle of the map; anyone can buy, first come first
	-- served. Better odds, plus the two tiers found nowhere else.
	Shared = {
		-- 35% fewer companies than the 5.7 seconds it was (itself 30% fewer
		-- than the original 4), for more space between them.
		SpawnSeconds = 8.8,
		-- The belt runs the length of the map, 316 studs between the tunnels,
		-- so at this pace a company takes about 2 minutes 10 seconds to cross.
		StudsPerSecond = 2.4,
		-- Out of 100.
		Weights = {
			{ tier = "Startup", weight = 48 },
			{ tier = "ScaleUp", weight = 26 },
			{ tier = "Unicorn", weight = 14 },
			{ tier = "Decacorn", weight = 7 },
			{ tier = "BlueChip", weight = 3 },
			{ tier = "MegaCap", weight = 1.3 },
			{ tier = "Conglomerate", weight = 0.6 },
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
