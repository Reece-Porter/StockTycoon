--!strict
-- Economy numbers. These are starting assumptions from docs/design.md and are
-- meant to be tuned.

return {
	-- Enough for one Startup even at the top of its +/-20% price range (50 x 1.2).
	StartingCash = 60,

	-- How often placed companies pay out. Each payout covers the time since
	-- the last one, so income per second is the same whatever this is.
	IncomePayoutSeconds = 1,
}
