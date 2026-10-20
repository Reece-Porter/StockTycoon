--!strict
-- Pets and the pet shop. Starting assumptions from docs/design.md.
--
-- One spin gives one random pet: first a rarity by weight, then one of that
-- rarity's pets, each equally likely. Spins cost Cash only and are rolled on
-- the server. Pets go in a floor's pet slot and change that floor only:
-- income pets add to the income of every company on it, guard pets add to the
-- time a thief must hold the prompt to steal from it. Pets on the same floor
-- add together. Pets never affect the Valuation Machine.
--
-- The model for each pet lives in ReplicatedStorage.Assets.Pets, named by id;
-- until one exists, the "Default" model is used, coloured by rarity.

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type Kind = "income" | "guard"

export type Rarity = {
	id: RarityId,
	name: string,
	-- Out of 100.
	weight: number,
	-- Added to the income multiplier of the pet's floor (0.05 = +5%).
	income: number,
	-- Seconds added to the steal hold time on the pet's floor.
	guard: number,
	color: Color3,
}

export type Pet = {
	id: string,
	name: string,
	rarity: RarityId,
	kind: Kind,
}

local rarities: { Rarity } = {
	{ id = "Common", name = "Common", weight = 60, income = 0.05, guard = 0.5, color = Color3.fromRGB(190, 190, 190) },
	{
		id = "Uncommon",
		name = "Uncommon",
		weight = 25,
		income = 0.1,
		guard = 1,
		color = Color3.fromRGB(110, 200, 110),
	},
	{ id = "Rare", name = "Rare", weight = 10, income = 0.2, guard = 1.5, color = Color3.fromRGB(80, 150, 255) },
	{ id = "Epic", name = "Epic", weight = 4, income = 0.35, guard = 2, color = Color3.fromRGB(170, 90, 230) },
	{
		id = "Legendary",
		name = "Legendary",
		weight = 0.9,
		income = 0.6,
		guard = 3,
		color = Color3.fromRGB(255, 170, 40),
	},
	{ id = "Mythic", name = "Mythic", weight = 0.1, income = 1, guard = 4, color = Color3.fromRGB(255, 80, 140) },
}

local list: { Pet } = {
	{ id = "PaperclipPup", name = "Paperclip Pup", rarity = "Common", kind = "income" },
	{ id = "StickyNoteSnail", name = "Sticky Note Snail", rarity = "Common", kind = "guard" },
	{ id = "CoffeeCat", name = "Coffee Cat", rarity = "Uncommon", kind = "income" },
	{ id = "FilingCabinetCrab", name = "Filing Cabinet Crab", rarity = "Uncommon", kind = "guard" },
	{ id = "SpreadsheetSloth", name = "Spreadsheet Sloth", rarity = "Rare", kind = "income" },
	{ id = "ShredderShark", name = "Shredder Shark", rarity = "Rare", kind = "guard" },
	{ id = "BullMarketBull", name = "Bull Market Bull", rarity = "Epic", kind = "income" },
	{ id = "SecurityBadger", name = "Security Badger", rarity = "Epic", kind = "guard" },
	{ id = "GoldenGoose", name = "Golden Goose", rarity = "Legendary", kind = "income" },
	{ id = "VaultTortoise", name = "Vault Tortoise", rarity = "Legendary", kind = "guard" },
	{ id = "DividendDragon", name = "Dividend Dragon", rarity = "Mythic", kind = "income" },
	{ id = "FirewallPhoenix", name = "Firewall Phoenix", rarity = "Mythic", kind = "guard" },
}

local rarityById: { [string]: Rarity } = {}
for _, rarity in rarities do
	rarityById[rarity.id] = rarity
end
local byId: { [string]: Pet } = {}
local byRarity: { [string]: { Pet } } = {}
for _, pet in list do
	byId[pet.id] = pet
	local rarityList = byRarity[pet.rarity]
	if rarityList == nil then
		rarityList = {}
		byRarity[pet.rarity] = rarityList
	end
	table.insert(rarityList, pet)
end

return {
	rarities = rarities,
	rarityById = rarityById,
	list = list,
	byId = byId,
	byRarity = byRarity,

	-- Cash per spin with no rebirths. Each rebirth adds SpinCostPerRebirth of
	-- it (0.5 = +50%), in step with the rebirth income multiplier.
	SpinCost = 10_000,
	SpinCostPerRebirth = 0.5,
	-- Most pets a player can own, placed or not. Extra pets can be deleted.
	InventoryCap = 50,
	-- Pet slots open on every opened floor. Slot2 is for later (bought, or a
	-- game pass).
	SlotsPerFloor = 1,

	-- How close (in studs) a player must be to a pet slot, and to the pet
	-- shop, plus the extra the server allows for lag.
	SlotDistance = 10,
	SlotDistanceTolerance = 6,
	ShopDistance = 12,
	ShopDistanceTolerance = 6,

	-- Spins of these rarities are announced to the whole server.
	AnnounceRarities = { Legendary = true, Mythic = true } :: { [string]: boolean },
}
