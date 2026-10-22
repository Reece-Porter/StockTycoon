--!strict
-- The battle arena (docs/design.md, "Battle arena"). Starting assumptions.
--
-- 2 to 8 players play a match: five rounds where each spins three random
-- stocks and picks one, then each keeps their total value or puts it
-- through the arena's Valuation Machine (0.5x to 5x, MachinePath). The
-- higher a player finishes, the more Cash and Gold they get, and the more
-- rebirths they have, the more Gold. Everyone spins with the
-- same odds (Luck x1), so rebirths don't decide it. One player can play a
-- practice match alone, with no reward. Nothing here is sold for Robux.

export type Reward = { incomeSeconds: number, minimum: number }

return {
	MinPlayers = 2,
	MaxPlayers = 8,
	-- Once enough players have joined, the match starts after this long (more
	-- can join until then).
	CountdownSeconds = 20,

	Rounds = 5,
	-- Stocks to choose from each round.
	Choices = 3,
	-- How long the reels spin, then how long players have to pick (whoever
	-- hasn't picked gets the most valuable of their three), then how long
	-- the board shows the round before the next.
	SpinSeconds = 3,
	PickSeconds = 12,
	RoundResultsSeconds = 4,

	-- After the last round: how long players have to choose to keep their
	-- value or put it through the machine (keeping it if they don't
	-- choose), and how long the machine runs (seconds, never past 45).
	ChooseSeconds = 12,
	MachineMinDuration = 8,
	MachineMaxDuration = 20,
	-- How long the final standings stay up before the arena is free again.
	FinalSeconds = 15,

	-- Cash by place, worth some seconds of the player's income (without
	-- reward boosts), with a minimum: 1st, 2nd, 3rd, then everyone else.
	-- Only when 2 or more players finish.
	Rewards = {
		{ incomeSeconds = 600, minimum = 5_000 },
		{ incomeSeconds = 360, minimum = 3_000 },
		{ incomeSeconds = 240, minimum = 2_000 },
	} :: { Reward },
	OtherReward = { incomeSeconds = 120, minimum = 1_000 } :: Reward,

	-- Gold by place too, the same way (1st, 2nd, 3rd, then everyone else),
	-- times 1 + GoldPerRebirth x the player's rebirths: so 1st place is 25
	-- Gold at first, 50 after five rebirths and 75 after ten.
	GoldRewards = { 25, 15, 10 } :: { number },
	OtherGold = 5,
	GoldPerRebirth = 0.2,

	-- How close (in studs) a player must be to the arena's join podium to
	-- join, and to a street teleporter to go to the arena, with leeway for
	-- lag.
	JoinDistance = 14,
	GateDistance = 12,
	DistanceTolerance = 6,
}
