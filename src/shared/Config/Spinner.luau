--!strict
-- The Stock Spinner at each base (docs/design.md, "Stock Spinner"). Starting
-- assumptions.
--
-- The spinner is the board over the base's belt. Every RollSeconds it rolls
-- Results different companies with its owner's odds, the reels spin for
-- SpinSeconds, and then the companies come out onto the belt one after
-- another and stop under their reels. Only the owner can buy them, until the
-- next roll lands and takes their place. Nothing here is sold for Robux.

export type WeightEntry = { tier: string, weight: number }

return {
	-- A new roll this often while the base has an owner, so what one roll
	-- brings stays on the belt this long.
	RollSeconds = 20,
	-- How long the reels spin before the companies come out.
	SpinSeconds = 3,
	-- Different companies each roll.
	Results = 3,
	-- Where each one stops along the belt (0 at its Start, 1 at its End). The
	-- first out goes furthest, so they never pass each other.
	Stops = { 0.84, 0.52, 0.2 } :: { number },
	-- How fast they come out along the belt, and the gap between one coming
	-- out and the next.
	SlideStudsPerSecond = 10,
	StaggerSeconds = 0.7,

	-- Out of 100, with no rebirths. Rebirths (Config/Rebirth) and the Spinner
	-- Luck upgrade (Config/Perks) make the tiers after the first more likely.
	-- Conglomerate and Monopoly are only ever on the shared conveyor.
	Weights = {
		{ tier = "Startup", weight = 70 },
		{ tier = "ScaleUp", weight = 22 },
		{ tier = "Unicorn", weight = 7 },
		{ tier = "BlueChip", weight = 1 },
	} :: { WeightEntry },
}
