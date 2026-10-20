--!strict
-- Rebirth: start again with Cash, companies and base upgrades wiped, for a
-- permanent income multiplier. Starting assumptions from docs/design.md.
--
-- Kept through rebirth: the rebirth count, weapons and pets (pets go back to
-- the Pets window, ready to put in their slots again).

return {
	-- Cash needed for the first rebirth; each rebirth after that needs this
	-- many times more.
	BaseCashRequired = 1_000_000,
	CashRequiredGrowth = 3,

	-- A company of this tier or better must be owned (placed or in storage).
	RequiredTier = "BlueChip",

	-- Income multiplier: 1 + IncomePerRebirth x rebirths.
	IncomePerRebirth = 0.5,

	-- Better personal conveyor odds: every tier above the most common one
	-- weighs this much more per rebirth (0.1 = +10%), up to MaxOddsBoost
	-- (1 = double). The shared conveyor is the same for everyone.
	OddsBoostPerRebirth = 0.1,
	MaxOddsBoost = 1,
}
