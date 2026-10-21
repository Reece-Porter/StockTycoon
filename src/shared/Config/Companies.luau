--!strict
-- The parody companies. Obvious pun names only: no real logos, wordmarks,
-- fonts or brand colours anywhere in their models.
--
-- priceScale and incomeScale vary each company from its tier's numbers and
-- must stay between 0.8 and 1.2. Each company's look (its model's pieces,
-- colours and logo badge) is in Config/CompanyLooks under the same id; the
-- server builds the models from it when it starts. Adding a company means an
-- entry here and one there (without one there it gets a plain box).

export type Company = {
	id: string,
	name: string,
	tier: string,
	priceScale: number,
	incomeScale: number,
}

local list: { Company } = {
	-- Startup
	{ id = "Snackchat", name = "Snackchat", tier = "Startup", priceScale = 0.85, incomeScale = 0.9 },
	{ id = "Kittygram", name = "Kittygram", tier = "Startup", priceScale = 0.95, incomeScale = 1.0 },
	{ id = "Duolinguini", name = "Duolinguini", tier = "Startup", priceScale = 1.0, incomeScale = 0.95 },
	{ id = "Pinterust", name = "Pinterust", tier = "Startup", priceScale = 1.1, incomeScale = 1.15 },
	{ id = "Ubber", name = "Ubber", tier = "Startup", priceScale = 1.2, incomeScale = 1.2 },

	-- Scale-up
	{ id = "Netflicks", name = "Netflicks", tier = "ScaleUp", priceScale = 0.8, incomeScale = 0.85 },
	{ id = "Spotifly", name = "Spotifly", tier = "ScaleUp", priceScale = 0.95, incomeScale = 1.0 },
	{ id = "Airbnbee", name = "Airbnbee", tier = "ScaleUp", priceScale = 1.0, incomeScale = 1.05 },
	{ id = "Discard", name = "Discard", tier = "ScaleUp", priceScale = 1.1, incomeScale = 1.0 },
	{ id = "Zoomba", name = "Zoomba", tier = "ScaleUp", priceScale = 1.15, incomeScale = 1.2 },

	-- Unicorn
	{ id = "SpaceY", name = "SpaceY", tier = "Unicorn", priceScale = 0.85, incomeScale = 0.9 },
	{ id = "Stripey", name = "Stripey", tier = "Unicorn", priceScale = 0.9, incomeScale = 0.95 },
	{ id = "TikTock", name = "TikTock", tier = "Unicorn", priceScale = 1.0, incomeScale = 1.0 },
	{ id = "Robinhoodie", name = "Robinhoodie", tier = "Unicorn", priceScale = 1.1, incomeScale = 1.15 },
	{ id = "Canvaas", name = "Canvaas", tier = "Unicorn", priceScale = 1.2, incomeScale = 1.15 },

	-- Blue Chip
	{ id = "Pear", name = "Pear", tier = "BlueChip", priceScale = 0.85, incomeScale = 0.85 },
	{ id = "Macrohard", name = "Macrohard", tier = "BlueChip", priceScale = 0.95, incomeScale = 1.0 },
	{ id = "Amazin", name = "Amazin'", tier = "BlueChip", priceScale = 1.0, incomeScale = 1.05 },
	{ id = "Goggle", name = "Goggle", tier = "BlueChip", priceScale = 1.1, incomeScale = 1.1 },
	{ id = "ChocaCola", name = "Choca-Cola", tier = "BlueChip", priceScale = 1.2, incomeScale = 1.2 },

	-- Conglomerate (shared conveyor only)
	{ id = "Samsong", name = "Samsong", tier = "Conglomerate", priceScale = 0.85, incomeScale = 0.9 },
	{ id = "Disnee", name = "Disnee", tier = "Conglomerate", priceScale = 0.95, incomeScale = 0.95 },
	{ id = "Nestled", name = "Nestled", tier = "Conglomerate", priceScale = 1.0, incomeScale = 1.05 },
	{ id = "Unileverage", name = "Unileverage", tier = "Conglomerate", priceScale = 1.1, incomeScale = 1.1 },
	{
		id = "BerkshireHatchaway",
		name = "Berkshire Hatchaway",
		tier = "Conglomerate",
		priceScale = 1.2,
		incomeScale = 1.2,
	},

	-- Monopoly (shared conveyor only)
	{ id = "AlphabetSoup", name = "Alphabet Soup", tier = "Monopoly", priceScale = 0.85, incomeScale = 0.9 },
	{ id = "Mehta", name = "Meh-ta", tier = "Monopoly", priceScale = 0.95, incomeScale = 0.95 },
	{ id = "Megamart", name = "Megamart", tier = "Monopoly", priceScale = 1.0, incomeScale = 1.0 },
	{ id = "Tencentury", name = "Tencentury", tier = "Monopoly", priceScale = 1.1, incomeScale = 1.1 },
	{ id = "EverythingInc", name = "Everything Inc.", tier = "Monopoly", priceScale = 1.2, incomeScale = 1.2 },
}

local byId: { [string]: Company } = {}
local byTier: { [string]: { Company } } = {}
for _, company in list do
	byId[company.id] = company
	local tierList = byTier[company.tier]
	if tierList == nil then
		tierList = {}
		byTier[company.tier] = tierList
	end
	table.insert(tierList, company)
end

return {
	list = list,
	byId = byId,
	byTier = byTier,
}
