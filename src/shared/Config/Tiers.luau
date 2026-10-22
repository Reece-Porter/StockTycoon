--!strict
-- Company tiers: base price, base income per second, and where they spawn.
-- Starting assumptions from docs/design.md. Each tier costs 6 to 7.5 times
-- the one before and pays about 5 times as much, so a rarer tier earns more
-- but takes a little longer to pay for itself (25 seconds of its income for
-- a Startup, about 90 for a Monopoly). Individual companies vary their price
-- and income from these a lot (see Config/Companies).

local Theme = require(script.Parent.Parent.Theme)

export type TierId =
	"Startup"
	| "ScaleUp"
	| "Unicorn"
	| "Decacorn"
	| "BlueChip"
	| "MegaCap"
	| "Conglomerate"
	| "Monopoly"

export type Tier = {
	id: TierId,
	name: string,
	price: number,
	income: number,
	-- Only spawns on the shared conveyor in the middle of the map.
	sharedOnly: boolean,
	-- From Theme.Tiers.
	color: Color3,
}

local list: { Tier } = {
	{
		id = "Startup",
		name = "Startup",
		price = 50,
		income = 2,
		sharedOnly = false,
		color = Theme.Tiers.Startup,
	},
	{
		id = "ScaleUp",
		name = "Scale-up",
		price = 300,
		income = 10,
		sharedOnly = false,
		color = Theme.Tiers.ScaleUp,
	},
	{
		id = "Unicorn",
		name = "Unicorn",
		price = 2_000,
		income = 55,
		sharedOnly = false,
		color = Theme.Tiers.Unicorn,
	},
	{
		id = "Decacorn",
		name = "Decacorn",
		price = 12_000,
		income = 280,
		sharedOnly = false,
		color = Theme.Tiers.Decacorn,
	},
	{
		id = "BlueChip",
		name = "Blue Chip",
		price = 75_000,
		income = 1_450,
		sharedOnly = false,
		color = Theme.Tiers.BlueChip,
	},
	{
		id = "MegaCap",
		name = "Mega Cap",
		price = 450_000,
		income = 7_200,
		sharedOnly = false,
		color = Theme.Tiers.MegaCap,
	},
	{
		id = "Conglomerate",
		name = "Conglomerate",
		price = 3_000_000,
		income = 40_000,
		sharedOnly = true,
		color = Theme.Tiers.Conglomerate,
	},
	{
		id = "Monopoly",
		name = "Monopoly",
		price = 20_000_000,
		income = 220_000,
		sharedOnly = true,
		color = Theme.Tiers.Monopoly,
	},
}

local byId: { [string]: Tier } = {}
for _, tier in list do
	byId[tier.id] = tier
end

return {
	list = list,
	byId = byId,
}
