--!strict
-- Rebirth: give up your Cash for a permanent income multiplier. Starting
-- assumptions from docs/design.md.
--
-- Only Cash goes (and any Cash waiting on cash pads). Companies, plots and
-- floors, pets (in their slots), weapons, upgrade station levels, Gold, the
-- Index and the rebirth count are all kept. Every rebirth also opens
-- Config/Base.PlotsPerRebirth more plots on the floors above the ones bought
-- with Cash.

return {
	-- Cash needed for the first rebirth; each rebirth after that needs this
	-- many times more. (Doubling was enough while Blue Chip was the best
	-- spinner tier; with Mega Caps paying five times as much, 2.5 keeps the
	-- next rebirth a real goal: about 4 billion for the tenth.)
	BaseCashRequired = 1_000_000,
	CashRequiredGrowth = 2.5,

	-- The companies each rebirth needs, by its number: one or two particular
	-- companies, owned (placed or in storage, any variant). They aren't used
	-- up. Every other rebirth or so asks for a slightly rarer tier, from a
	-- Startup for the first to Monopolies from the 19th (the rarest one asked
	-- for never drops back); the first 14 only need tiers every Stock Spinner
	-- rolls (more often with each rebirth's Luck).
	-- Past the end of the list, rebirths only need Cash.
	RequiredCompanies = {
		{ "Kittygram" }, -- 1: a Startup
		{ "Snackchat", "Ubber" }, -- 2: two Startups
		{ "Spotifly" }, -- 3: a Scale-up
		{ "Netflicks", "Zoomba" }, -- 4
		{ "TikTock" }, -- 5: a Unicorn
		{ "SpaceY", "Canvaas" }, -- 6
		{ "Mojango" }, -- 7: a Decacorn
		{ "EpicGnomes", "Bitedance" }, -- 8
		{ "Pear" }, -- 9: a Blue Chip
		{ "Goggle", "Starbux" }, -- 10
		{ "Sunny" }, -- 11: a Mega Cap
		{ "Leggo", "McDonuts" }, -- 12
		{ "Teslug", "PayPail" }, -- 13
		{ "Nintendough", "ChocaCola" }, -- 14
		{ "Samsong" }, -- 15: a Conglomerate (shared conveyor)
		{ "Disnee", "YouTuba" }, -- 16
		{ "Nestled", "Snowfake" }, -- 17
		{ "Hitachoo", "Macrohard" }, -- 18
		{ "AlphabetSoup" }, -- 19: a Monopoly (shared conveyor)
		{ "Mehta", "Unileverage" }, -- 20
		{ "Megamart", "eBray" }, -- 21
		{ "Mastercart", "BerkshireHatchaway" }, -- 22
		{ "Tencentury", "Amazin" }, -- 23
		{ "EverythingInc" }, -- 24
	} :: { { string } },

	-- Income multiplier: 1 + IncomePerRebirth x rebirths.
	IncomePerRebirth = 0.5,

	-- More Stock Spinner Luck, so each rebirth brings better companies: Luck
	-- from rebirths is 1 + OddsGrowthPerRebirth x rebirths (counting up to
	-- MaxOddsRebirths), and each tier in Config/Spinner weighs Luck to the
	-- power of its place after the first. With 0.25: Luck x1.25 after one
	-- rebirth (Scale-up x1.25 ... Mega Cap x3.05), x2 after four (x2 ... x32).
	-- The shared conveyor is the same for everyone.
	OddsGrowthPerRebirth = 0.25,
	MaxOddsRebirths = 20,
}
