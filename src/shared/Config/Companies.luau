--!strict
-- The parody companies. Obvious pun names only: no real logos, wordmarks,
-- fonts or brand colours anywhere in their models.
--
-- Six companies a tier, cheapest first. priceScale and incomeScale vary each
-- company from its tier's numbers, between 0.55 and 1.75: the dearest in a
-- tier costs over two and a half times the cheapest, and the dearer ones pay
-- a little more for what they cost, so there's always a better one to save
-- for. Each company's look (its model's pieces, colours and logo badge) is
-- in Config/CompanyLooks under the same id; the server builds the models
-- from it when it starts. Adding a company means an
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
	{ id = "Snackchat", name = "Snackchat", tier = "Startup", priceScale = 0.6, incomeScale = 0.55 },
	{ id = "Kittygram", name = "Kittygram", tier = "Startup", priceScale = 0.8, incomeScale = 0.76 },
	{ id = "Duolinguini", name = "Duolinguini", tier = "Startup", priceScale = 1.0, incomeScale = 0.98 },
	{ id = "Reddish", name = "Reddish", tier = "Startup", priceScale = 1.15, incomeScale = 1.17 },
	{ id = "Pinterust", name = "Pinterust", tier = "Startup", priceScale = 1.35, incomeScale = 1.42 },
	{ id = "Ubber", name = "Ubber", tier = "Startup", priceScale = 1.6, incomeScale = 1.75 },

	-- Scale-up
	{ id = "Netflicks", name = "Netflicks", tier = "ScaleUp", priceScale = 0.6, incomeScale = 0.56 },
	{ id = "Spotifly", name = "Spotifly", tier = "ScaleUp", priceScale = 0.8, incomeScale = 0.77 },
	{ id = "Airbnbee", name = "Airbnbee", tier = "ScaleUp", priceScale = 1.0, incomeScale = 1.0 },
	{ id = "Discard", name = "Discard", tier = "ScaleUp", priceScale = 1.2, incomeScale = 1.24 },
	{ id = "Doordish", name = "Doordish", tier = "ScaleUp", priceScale = 1.4, incomeScale = 1.48 },
	{ id = "Zoomba", name = "Zoomba", tier = "ScaleUp", priceScale = 1.6, incomeScale = 1.75 },

	-- Unicorn
	{ id = "SpaceY", name = "SpaceY", tier = "Unicorn", priceScale = 0.6, incomeScale = 0.55 },
	{ id = "Stripey", name = "Stripey", tier = "Unicorn", priceScale = 0.8, incomeScale = 0.76 },
	{ id = "TikTock", name = "TikTock", tier = "Unicorn", priceScale = 1.0, incomeScale = 0.98 },
	{ id = "Slackers", name = "Slackers", tier = "Unicorn", priceScale = 1.15, incomeScale = 1.17 },
	{ id = "Robinhoodie", name = "Robinhoodie", tier = "Unicorn", priceScale = 1.35, incomeScale = 1.42 },
	{ id = "Canvaas", name = "Canvaas", tier = "Unicorn", priceScale = 1.6, incomeScale = 1.75 },

	-- Decacorn
	{ id = "Mojango", name = "Mojango", tier = "Decacorn", priceScale = 0.6, incomeScale = 0.56 },
	{ id = "EpicGnomes", name = "Epic Gnomes", tier = "Decacorn", priceScale = 0.8, incomeScale = 0.77 },
	{ id = "Bitedance", name = "Bitedance", tier = "Decacorn", priceScale = 1.0, incomeScale = 1.0 },
	{ id = "Snowfake", name = "Snowfake", tier = "Decacorn", priceScale = 1.2, incomeScale = 1.24 },
	{ id = "PayPail", name = "PayPail", tier = "Decacorn", priceScale = 1.4, incomeScale = 1.48 },
	{ id = "eBray", name = "eBray", tier = "Decacorn", priceScale = 1.6, incomeScale = 1.75 },

	-- Blue Chip
	{ id = "Pear", name = "Pear", tier = "BlueChip", priceScale = 0.6, incomeScale = 0.55 },
	{ id = "Macrohard", name = "Macrohard", tier = "BlueChip", priceScale = 0.8, incomeScale = 0.76 },
	{ id = "Amazin", name = "Amazin'", tier = "BlueChip", priceScale = 1.0, incomeScale = 0.98 },
	{ id = "Starbux", name = "Starbux", tier = "BlueChip", priceScale = 1.15, incomeScale = 1.17 },
	{ id = "Goggle", name = "Goggle", tier = "BlueChip", priceScale = 1.35, incomeScale = 1.42 },
	{ id = "ChocaCola", name = "Choca-Cola", tier = "BlueChip", priceScale = 1.6, incomeScale = 1.75 },

	-- Mega Cap
	{ id = "Sunny", name = "Sunny", tier = "MegaCap", priceScale = 0.6, incomeScale = 0.56 },
	{ id = "Leggo", name = "Leggo", tier = "MegaCap", priceScale = 0.8, incomeScale = 0.77 },
	{ id = "McDonuts", name = "McDonuts", tier = "MegaCap", priceScale = 1.0, incomeScale = 1.0 },
	{ id = "Teslug", name = "Teslug", tier = "MegaCap", priceScale = 1.2, incomeScale = 1.24 },
	{ id = "Nintendough", name = "Nintendough", tier = "MegaCap", priceScale = 1.4, incomeScale = 1.48 },
	{ id = "YouTuba", name = "YouTuba", tier = "MegaCap", priceScale = 1.6, incomeScale = 1.75 },

	-- Conglomerate (shared conveyor only)
	{ id = "Samsong", name = "Samsong", tier = "Conglomerate", priceScale = 0.6, incomeScale = 0.55 },
	{ id = "Disnee", name = "Disnee", tier = "Conglomerate", priceScale = 0.8, incomeScale = 0.76 },
	{ id = "Nestled", name = "Nestled", tier = "Conglomerate", priceScale = 1.0, incomeScale = 0.98 },
	{ id = "Hitachoo", name = "Hitachoo", tier = "Conglomerate", priceScale = 1.15, incomeScale = 1.17 },
	{ id = "Unileverage", name = "Unileverage", tier = "Conglomerate", priceScale = 1.35, incomeScale = 1.42 },
	{
		id = "BerkshireHatchaway",
		name = "Berkshire Hatchaway",
		tier = "Conglomerate",
		priceScale = 1.6,
		incomeScale = 1.75,
	},

	-- Monopoly (shared conveyor only)
	{ id = "AlphabetSoup", name = "Alphabet Soup", tier = "Monopoly", priceScale = 0.6, incomeScale = 0.56 },
	{ id = "Mehta", name = "Meh-ta", tier = "Monopoly", priceScale = 0.8, incomeScale = 0.77 },
	{ id = "Megamart", name = "Megamart", tier = "Monopoly", priceScale = 1.0, incomeScale = 1.0 },
	{ id = "Mastercart", name = "Mastercart", tier = "Monopoly", priceScale = 1.2, incomeScale = 1.24 },
	{ id = "Tencentury", name = "Tencentury", tier = "Monopoly", priceScale = 1.4, incomeScale = 1.48 },
	{ id = "EverythingInc", name = "Everything Inc.", tier = "Monopoly", priceScale = 1.6, incomeScale = 1.75 },
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
