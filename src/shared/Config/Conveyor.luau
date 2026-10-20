--!strict
-- Conveyor timing, odds and buying range. Starting assumptions from
-- docs/design.md.

export type WeightEntry = { tier: string, weight: number }

return {
	-- Each base's own conveyor; only the owner can buy from it.
	Personal = {
		SpawnSeconds = 6,
		-- How fast companies move along the belt. A company disappears at the
		-- End if nobody bought it, so a belt's length sets how long that takes
		-- (a 40-stud belt: 20 seconds).
		StudsPerSecond = 2,
		-- Out of 100, with no rebirths. Each rebirth makes the tiers above
		-- Startup more likely (Config/Rebirth).
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
		-- 30% fewer companies than the 4 seconds it was, now the belt is
		-- 4 times longer.
		SpawnSeconds = 5.7,
		-- The same pace as before; a 192-stud belt takes 80 seconds.
		StudsPerSecond = 2.4,
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
