--!strict
-- Game passes and developer products (docs/design.md, "Monetisation").
-- Starting assumptions.
--
-- Each one is made on the Creator Dashboard (the experience's Monetization
-- section: Passes, and Developer Products), where its Robux price is set.
-- Put its id here; anything with an id of 0 shows in the store as not on sale
-- yet and can't be bought.
--
-- Nothing here may touch the Valuation Machine, sell pet spins, or sell
-- weapons, damage or guard boosts.

local Rewards = require(script.Parent.Rewards)
local Theme = require(script.Parent.Parent.Theme)

export type PassName = "DoubleIncome" | "VIP" | "ExtraPetSlot"
export type Pass = {
	name: PassName,
	id: number,
	title: string,
	description: string,
}
export type ProductKind = "Cash" | "Lock"
export type Product = {
	key: string,
	id: number,
	title: string,
	description: string,
	kind: ProductKind,
	-- Cash packs: what they give, like a reward (Config/Rewards).
	grant: Rewards.Grant?,
}

local passes: { Pass } = {
	{
		name = "DoubleIncome",
		id = 0,
		title = "2x Income",
		description = "Every company you own earns twice as much, for good.",
	},
	{
		name = "VIP",
		id = 0,
		title = "VIP",
		description = "A gold VIP tag in chat and gold trim on your base.",
	},
	{
		name = "ExtraPetSlot",
		id = 0,
		title = "Extra Pet Slot",
		description = "Opens a second pet slot on every floor of your base.",
	},
}

-- Cash packs give some of the player's income (counted without reward
-- boosts), with a smallest amount for new players, so they stay worth having.
local products: { Product } = {
	{
		key = "CashSmall",
		id = 0,
		title = "Cash Pack",
		description = "15 minutes of your income.",
		kind = "Cash",
		grant = Rewards.cash(15 * 60, 5_000),
	},
	{
		key = "CashMedium",
		id = 0,
		title = "Big Cash Pack",
		description = "1 hour of your income.",
		kind = "Cash",
		grant = Rewards.cash(60 * 60, 25_000),
	},
	{
		key = "CashLarge",
		id = 0,
		title = "Huge Cash Pack",
		description = "4 hours of your income.",
		kind = "Cash",
		grant = Rewards.cash(4 * 60 * 60, 100_000),
	},
	{
		key = "LockNow",
		id = 0,
		title = "Lock Base Now",
		description = "Locks your base straight away, wherever you are (or adds to a lock already on).",
		kind = "Lock",
	},
}

return {
	Passes = passes,
	Products = products,
	-- What 2x Income multiplies income by.
	IncomeMultiplier = 2,
	-- Pet slots the Extra Pet Slot pass opens on each floor, on top of
	-- Config/Pets.SlotsPerFloor.
	ExtraPetSlots = 1,
	-- The VIP tag in chat and the trim on a VIP's base.
	VipColour = Theme.Colours.Gold,
	-- Receipts kept to stop a purchase being given twice (oldest dropped).
	ReceiptsKept = 100,
}
