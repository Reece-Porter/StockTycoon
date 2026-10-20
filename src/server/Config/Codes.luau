--!strict
-- Codes players type into the Rewards window, for social media and update
-- announcements. This lives on the server only, so players can't read the
-- list. A new code is one line here.
--
-- code: what players type (any capitals; spaces at the ends are ignored).
-- grants: what it gives, like a reward (Config/Rewards): Cash, a 2x boost or
--   free pet spins.
-- expires: the last day it works, "YYYY-MM-DD" in UTC, or leave it out for a
--   code that never expires.
-- Each code works once per player.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)

export type Code = { code: string, grants: { Rewards.Grant }, expires: string? }

return {
	{ code = "STOCKS", grants = { Rewards.fixedCash(5000), Rewards.boost(10) } },
	{ code = "BULLMARKET", grants = { Rewards.spins(1) }, expires = "2026-12-31" },
} :: { Code }
