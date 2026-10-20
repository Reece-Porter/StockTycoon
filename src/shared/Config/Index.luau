--!strict
-- The Index: every company a player has ever owned, bought or stolen, with
-- prizes for collecting so many different ones. Kept through rebirth.
-- Prizes are given like rewards (Config/Rewards).

local Rewards = require(script.Parent.Rewards)

export type Milestone = { count: number, grants: { Rewards.Grant } }

return {
	Milestones = {
		{ count = 5, grants = { Rewards.cash(120, 500) } },
		{ count = 10, grants = { Rewards.spins(1) } },
		{ count = 15, grants = { Rewards.cash(300, 2500), Rewards.boost(10) } },
		{ count = 20, grants = { Rewards.spins(2) } },
		{ count = 25, grants = { Rewards.cash(600, 10000), Rewards.boost(20) } },
		{ count = 30, grants = { Rewards.spins(3), Rewards.boost(30) } },
	} :: { Milestone },
}
