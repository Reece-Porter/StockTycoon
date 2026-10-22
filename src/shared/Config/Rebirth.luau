--!strict
-- Rebirth: give up your Cash for a permanent income multiplier. Starting
-- assumptions from docs/design.md.
--
-- Only Cash goes (and any Cash waiting on cash pads). Companies, plots and
-- floors, pets (in their slots), weapons, upgrade station levels, Gold, the
-- Index and the rebirth count are all kept. Every rebirth also opens
-- Config/Base.PlotsPerRebirth more plots on the floors above the ones bought
-- with Cash.

export type TierStep = { from: number, tier: string }

return {
	-- Cash needed for the first rebirth; each rebirth after that needs this
	-- many times more. (Was 3 while rebirth also took every company and plot;
	-- now that a base is kept, doubling keeps 10 rebirths within reach.)
	BaseCashRequired = 1_000_000,
	CashRequiredGrowth = 2,

	-- A company of this tier or better must be owned (placed or in storage)
	-- for the rebirth with this number, from that rebirth on until the next
	-- step: a Startup for the first two, then a little rarer every few
	-- rebirths. Blue Chip covers rebirths 8 to 15 (any Stock Spinner can roll
	-- one, more often with every rebirth), then a Conglomerate from the shared
	-- conveyor. It isn't used up.
	RequiredTiers = {
		{ from = 1, tier = "Startup" },
		{ from = 3, tier = "ScaleUp" },
		{ from = 5, tier = "Unicorn" },
		{ from = 8, tier = "BlueChip" },
		{ from = 16, tier = "Conglomerate" },
	} :: { TierStep },

	-- Income multiplier: 1 + IncomePerRebirth x rebirths.
	IncomePerRebirth = 0.5,

	-- More Stock Spinner Luck, so each rebirth brings better companies: Luck
	-- from rebirths is 1 + OddsGrowthPerRebirth x rebirths (counting up to
	-- MaxOddsRebirths), and each tier in Config/Spinner weighs Luck to the
	-- power of its place after the first. With 0.25: Luck x1.25 after one
	-- rebirth (Scale-up x1.25, Unicorn x1.56, Blue Chip x1.95), x2 after four
	-- (x2, x4 and x8). The shared conveyor is the same for everyone.
	OddsGrowthPerRebirth = 0.25,
	MaxOddsRebirths = 20,
}
