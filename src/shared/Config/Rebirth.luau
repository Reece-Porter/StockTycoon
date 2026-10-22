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

	-- Better Stock Spinner odds, so each rebirth brings better companies: the
	-- odds' growth is 1 + OddsGrowthPerRebirth x rebirths (counting up to
	-- MaxOddsRebirths), and each tier in Config/Spinner weighs that growth to
	-- the power of its place after the first. With 0.25: Scale-up x1.25,
	-- Unicorn x1.56 and Blue Chip x1.95 after one rebirth; x2, x4 and x8
	-- after four. The shared conveyor is the same for everyone.
	OddsGrowthPerRebirth = 0.25,
	MaxOddsRebirths = 20,
}
