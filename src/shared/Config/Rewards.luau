--!strict
-- Playtime rewards, the daily login streak and the 2x income boosts they
-- give. Starting assumptions from docs/design.md. The Index prizes (Config/
-- Index) are given the same way.
--
-- A reward is a list of grants:
--   cash: incomeSeconds of the player's income at claim time (not counting a
--         boost), and at least minimum Cash;
--   boost: seconds of 2x income, added to any boost already banked;
--   spins: free pet spin tokens, used at the pet shop;
--   gold: an amount of Gold (kept through rebirth, spent at the upgrade
--         station).

export type Grant = {
	kind: "cash" | "boost" | "spins" | "gold",
	incomeSeconds: number?,
	minimum: number?,
	seconds: number?,
	count: number?,
}

export type Milestone = { minutes: number, grants: { Grant } }

local function cash(incomeSeconds: number, minimum: number): Grant
	return { kind = "cash", incomeSeconds = incomeSeconds, minimum = minimum }
end
-- An exact amount of Cash, whatever the player's income.
local function fixedCash(amount: number): Grant
	return { kind = "cash", incomeSeconds = 0, minimum = amount }
end
local function boost(minutes: number): Grant
	return { kind = "boost", seconds = minutes * 60 }
end
local function spins(count: number): Grant
	return { kind = "spins", count = count }
end
local function gold(amount: number): Grant
	return { kind = "gold", count = amount }
end

return {
	-- Minutes of play today (UTC) for each reward. Playtime and unclaimed
	-- rewards reset at 00:00 UTC; leaving and rejoining keeps them.
	Playtime = {
		{ minutes = 5, grants = { cash(60, 100) } },
		{ minutes = 10, grants = { cash(120, 250) } },
		{ minutes = 15, grants = { boost(5) } },
		{ minutes = 30, grants = { cash(300, 1000) } },
		{ minutes = 60, grants = { spins(1) } },
		{ minutes = 90, grants = { boost(15) } },
		{ minutes = 120, grants = { cash(900, 5000), boost(15) } },
	} :: { Milestone },

	-- One claim per UTC day, Day 1 to Day 7 and round again. Missing a day
	-- starts again at Day 1. The design gives no minimum Cash for these; the
	-- minimums here match the playtime rewards' so new players get something.
	Daily = {
		{ cash(120, 250) },
		{ boost(10) },
		{ cash(300, 1000) },
		{ spins(1) },
		{ cash(600, 2500) },
		{ boost(20) },
		{ spins(2), boost(30) },
	} :: { { Grant } },

	-- Reward boosts multiply all income. A new boost adds its time to the one
	-- banked, up to MaxBoostSeconds; boosts never stack their multipliers.
	-- Boost time only runs down while the player is in the game.
	BoostMultiplier = 2,
	MaxBoostSeconds = 60 * 60,

	-- Helpers for Config/Index and the server's Config/Codes.
	cash = cash,
	fixedCash = fixedCash,
	boost = boost,
	spins = spins,
	gold = gold,
}
