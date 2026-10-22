--!strict
-- The Stock Spinner at each base (docs/design.md, "Stock Spinner"). Starting
-- assumptions.
--
-- The spinner is a machine at the start of the base's belt. Its owner walks
-- up to it and presses Spin: a pop-up spins three reels, which stop one by
-- one on Results different companies rolled with the owner's Luck. Then
-- those companies come out onto the belt one after another and stop along
-- it, where only the owner can buy them, until the machine is played again.
-- Playing is free. Nothing here is sold for Robux.

export type WeightEntry = { tier: string, weight: number }

return {
	-- How long the reels spin before the companies come out.
	SpinSeconds = 3,
	-- The shortest time from one play to the next.
	CooldownSeconds = 10,
	-- Different companies each play.
	Results = 3,
	-- How close (in studs) the owner must be to the machine's Console to
	-- play, and how much extra the server allows for lag.
	PlayDistance = 10,
	PlayDistanceTolerance = 6,
	-- Where each one stops along the belt (0 at its Start, inside the
	-- machine, to 1 at its End). The first out goes furthest, so they never
	-- pass each other.
	Stops = { 0.86, 0.56, 0.26 } :: { number },
	-- How fast they come out along the belt, and the gap between one coming
	-- out and the next.
	SlideStudsPerSecond = 10,
	StaggerSeconds = 0.7,

	-- Out of 100, at Luck x1. A player's Luck (from their rebirths,
	-- Config/Rebirth, and the Spinner Luck upgrade, Config/Perks) multiplies
	-- each tier after the first by Luck to the power of its place after the
	-- first, so the rarer a tier, the more Luck helps it. Conglomerate and
	-- Monopoly are only ever on the shared conveyor.
	Weights = {
		{ tier = "Startup", weight = 60 },
		{ tier = "ScaleUp", weight = 25 },
		{ tier = "Unicorn", weight = 10 },
		{ tier = "Decacorn", weight = 3.5 },
		{ tier = "BlueChip", weight = 1.2 },
		{ tier = "MegaCap", weight = 0.3 },
	} :: { WeightEntry },
}
