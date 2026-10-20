--!strict
-- Company tiers: base price, base income per second, and where they spawn.
-- Starting assumptions from docs/design.md. Individual companies vary their
-- price and income from these by up to +/-20% (see Config/Companies).

export type TierId = "Startup" | "ScaleUp" | "Unicorn" | "BlueChip" | "Conglomerate" | "Monopoly"

export type Tier = {
	id: TierId,
	name: string,
	price: number,
	income: number,
	-- Only spawns on the shared conveyor in the middle of the map.
	sharedOnly: boolean,
	color: Color3,
}

local list: { Tier } = {
	{
		id = "Startup",
		name = "Startup",
		price = 50,
		income = 2,
		sharedOnly = false,
		color = Color3.fromRGB(140, 210, 140),
	},
	{
		id = "ScaleUp",
		name = "Scale-up",
		price = 500,
		income = 15,
		sharedOnly = false,
		color = Color3.fromRGB(110, 170, 255),
	},
	{
		id = "Unicorn",
		name = "Unicorn",
		price = 5_000,
		income = 120,
		sharedOnly = false,
		color = Color3.fromRGB(220, 130, 255),
	},
	{
		id = "BlueChip",
		name = "Blue Chip",
		price = 50_000,
		income = 900,
		sharedOnly = false,
		color = Color3.fromRGB(80, 200, 255),
	},
	{
		id = "Conglomerate",
		name = "Conglomerate",
		price = 500_000,
		income = 7_000,
		sharedOnly = true,
		color = Color3.fromRGB(255, 190, 70),
	},
	{
		id = "Monopoly",
		name = "Monopoly",
		price = 5_000_000,
		income = 50_000,
		sharedOnly = true,
		color = Color3.fromRGB(255, 90, 90),
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
