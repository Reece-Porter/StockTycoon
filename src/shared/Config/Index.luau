--!strict
-- The Index: every company a player has ever owned, bought or stolen, with
-- challenges for collecting them. Kept through rebirth, and the main way to
-- earn Gold besides the battle arena. Prizes are given like rewards (Config/
-- Rewards). Starting assumptions.
--   Milestones: so many different companies, any tier.
--   Challenges: every company of one tier, or so many different variants.

local Rewards = require(script.Parent.Rewards)

export type Milestone = { count: number, grants: { Rewards.Grant } }

export type Challenge = {
	-- Saved once claimed, so never rename one.
	id: string,
	kind: "tier" | "variants",
	-- Every company of this tier (kind "tier").
	tier: string?,
	-- This many different variants (kind "variants").
	count: number?,
	grants: { Rewards.Grant },
}

return {
	Milestones = {
		{ count = 5, grants = { Rewards.gold(10), Rewards.cash(120, 500) } },
		{ count = 10, grants = { Rewards.gold(20), Rewards.spins(1) } },
		{ count = 15, grants = { Rewards.gold(30), Rewards.cash(300, 2500), Rewards.boost(10) } },
		{ count = 20, grants = { Rewards.gold(50), Rewards.spins(2) } },
		{ count = 25, grants = { Rewards.gold(75), Rewards.cash(600, 10000), Rewards.boost(20) } },
		{ count = 30, grants = { Rewards.gold(120), Rewards.spins(3), Rewards.boost(30) } },
		{ count = 36, grants = { Rewards.gold(180), Rewards.cash(900, 50000) } },
		{ count = 42, grants = { Rewards.gold(250), Rewards.spins(4), Rewards.boost(30) } },
		{ count = 48, grants = { Rewards.gold(400), Rewards.spins(5), Rewards.boost(60) } },
	} :: { Milestone },

	Challenges = {
		{ id = "TierStartup", kind = "tier", tier = "Startup", grants = { Rewards.gold(15) } },
		{ id = "TierScaleUp", kind = "tier", tier = "ScaleUp", grants = { Rewards.gold(25) } },
		{ id = "TierUnicorn", kind = "tier", tier = "Unicorn", grants = { Rewards.gold(40) } },
		{ id = "TierDecacorn", kind = "tier", tier = "Decacorn", grants = { Rewards.gold(60) } },
		{ id = "TierBlueChip", kind = "tier", tier = "BlueChip", grants = { Rewards.gold(100) } },
		{ id = "TierMegaCap", kind = "tier", tier = "MegaCap", grants = { Rewards.gold(160) } },
		{ id = "TierConglomerate", kind = "tier", tier = "Conglomerate", grants = { Rewards.gold(250) } },
		{ id = "TierMonopoly", kind = "tier", tier = "Monopoly", grants = { Rewards.gold(400) } },
		{ id = "Variants1", kind = "variants", count = 1, grants = { Rewards.gold(10) } },
		{ id = "Variants3", kind = "variants", count = 3, grants = { Rewards.gold(30) } },
		{ id = "Variants6", kind = "variants", count = 6, grants = { Rewards.gold(100) } },
	} :: { Challenge },
}
