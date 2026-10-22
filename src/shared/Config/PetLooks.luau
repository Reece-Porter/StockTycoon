--!strict
-- How each pet looks (docs/visual-pass.md, Phase 7), next to its entry in
-- Config/Pets. PetBuilder (server/Lib) turns these into models when the
-- server starts; a model built by hand in ReplicatedStorage.Assets.Pets and
-- named by the pet's id is used instead.
--
-- Chunky chibi proportions (a big head on a small body) and big glossy eyes,
-- each pet recognisable from its name alone. Positions are in studs from
-- the ground under the pet's middle, with its face towards -z (see Pieces).
-- Part budget: 25 per pet, aura included.
--
-- The aura grows with rarity: Common has none, then a glow under the pet
-- that gets stronger, sparkles from Rare up, and from Legendary a soft light
-- (the one light a pet may have).

local Pieces = require(script.Parent.Parent.Pieces)
local Theme = require(script.Parent.Parent.Theme)

export type Look = { pieces: { Pieces.Piece } }

export type Aura = {
	-- How see-through the glow under the pet is (0 = solid).
	glow: number,
	-- Sparkles a second (0 for none). At most 10.
	sparkles: number,
	light: boolean,
}

local block, ball, ellipsoid, wedge = Pieces.block, Pieces.ball, Pieces.ellipsoid, Pieces.wedge
local rod, can, disc = Pieces.rod, Pieces.can, Pieces.disc
local hex = Theme.hex

local INK = Theme.Colours.Ink
local WHITE = Theme.Colours.Card
local GOLD = Theme.Colours.Gold
local CREAM = hex("#FFF1D6")
local SILVER = hex("#C9CED6")
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon

-- Big glossy eyes: a shiny dark ball each side with a white highlight up and
-- in front of it.
local function eyes(spacing: number, y: number, z: number, size: number): { Pieces.Piece }
	local list = {}
	for _, side in { -1, 1 } do
		table.insert(list, ball(size, { side * spacing, y, z }, INK, { reflectance = 0.25 }))
		local shine = { side * spacing - size * 0.14, y + size * 0.16, z - size * 0.36 }
		table.insert(list, ball(size * 0.36, shine, WHITE))
	end
	return list
end

-- One list from several.
local function join(...: { Pieces.Piece }): { Pieces.Piece }
	local all = {}
	for _, list in { ... } do
		for _, piece in list do
			table.insert(all, piece)
		end
	end
	return all
end

local looks: { [string]: Look } = {}

---------------------------------------------------------------------------
-- Common

-- A puppy with paperclip ears and a paperclip tail.
local PUP = hex("#E8C79A")
looks.PaperclipPup = {
	pieces = join({
		ellipsoid({ 1.3, 1.1, 1.5 }, { 0, 0.8, 0.15 }, PUP),
		ball(1.7, { 0, 2.0, -0.2 }, PUP),
		ellipsoid({ 0.8, 0.55, 0.5 }, { 0, 1.78, -0.98 }, CREAM), -- snout
		ball(0.26, { 0, 1.92, -1.22 }, INK), -- nose
		can(0.14, 1.0, { 0, 1.32, -0.2 }, hex("#E8473B")), -- collar
		-- Paperclip ears: two thin silver rods each, like a bent clip.
		rod(0.95, 0.09, { -0.78, 2.55, -0.2 }, SILVER, { turn = { 0, 0, 115 }, material = METAL }),
		rod(0.75, 0.09, { -0.62, 2.5, -0.2 }, SILVER, { turn = { 0, 0, 115 }, material = METAL }),
		rod(0.95, 0.09, { 0.78, 2.55, -0.2 }, SILVER, { turn = { 0, 0, 65 }, material = METAL }),
		rod(0.75, 0.09, { 0.62, 2.5, -0.2 }, SILVER, { turn = { 0, 0, 65 }, material = METAL }),
		rod(0.8, 0.09, { 0, 1.15, 1.0 }, SILVER, { turn = { 0, 90, 55 }, material = METAL }), -- tail
		rod(0.6, 0.09, { 0, 1.12, 0.88 }, SILVER, { turn = { 0, 90, 55 }, material = METAL }),
		can(0.45, 0.36, { -0.38, 0.22, -0.3 }, PUP), -- legs
		can(0.45, 0.36, { 0.38, 0.22, -0.3 }, PUP),
		can(0.45, 0.36, { -0.38, 0.22, 0.55 }, PUP),
		can(0.45, 0.36, { 0.38, 0.22, 0.55 }, PUP),
	}, eyes(0.34, 2.15, -0.9, 0.38)),
}

-- A snail whose shell is a stack of sticky notes.
local SLUG = hex("#9BD36A")
looks.StickyNoteSnail = {
	pieces = join({
		ellipsoid({ 1.0, 0.6, 2.4 }, { 0, 0.3, 0 }, SLUG),
		ellipsoid({ 0.9, 1.3, 0.9 }, { 0, 1.0, -0.95 }, SLUG),
		can(0.6, 0.12, { -0.24, 1.85, -1.0 }, SLUG, { turn = { 0, 0, 12 } }), -- eye stalks
		can(0.6, 0.12, { 0.24, 1.85, -1.0 }, SLUG, { turn = { 0, 0, -12 } }),
		block({ 0.32, 0.06, 0.05 }, { 0, 0.92, -1.4 }, INK), -- smile
		-- The shell: sticky notes in a slightly twisted stack.
		block({ 1.5, 0.12, 1.5 }, { 0, 0.7, 0.35 }, hex("#FFE45C"), { turn = { -10, 0, 0 } }),
		block({ 1.45, 0.12, 1.45 }, { 0, 0.84, 0.36 }, hex("#FF8FC7"), { turn = { -10, 15, 0 } }),
		block({ 1.4, 0.12, 1.4 }, { 0, 0.98, 0.37 }, hex("#7FD1FF"), { turn = { -10, 30, 0 } }),
		block({ 1.35, 0.12, 1.35 }, { 0, 1.12, 0.38 }, hex("#A6E36B"), { turn = { -10, 45, 0 } }),
		block({ 1.3, 0.12, 1.3 }, { 0, 1.26, 0.39 }, hex("#FFE45C"), { turn = { -10, 60, 0 } }),
		wedge({ 0.4, 0.12, 0.4 }, { 0.35, 1.38, 0.6 }, hex("#F2D13F"), { turn = { -10, 60, 0 } }), -- curled corner
	}, eyes(0.3, 2.22, -1.04, 0.42)),
}

---------------------------------------------------------------------------
-- Uncommon

-- A cat sitting in a coffee mug.
local CAT = hex("#F28C28")
looks.CoffeeCat = {
	pieces = join({
		can(1.4, 1.7, { 0, 0.7, 0 }, WHITE), -- the mug
		can(0.25, 1.75, { 0, 0.95, 0 }, hex("#E8473B")),
		can(0.06, 1.5, { 0, 1.38, 0 }, hex("#6F4E37")), -- coffee
		ellipsoid({ 0.25, 0.9, 0.7 }, { 0.95, 0.75, 0 }, WHITE), -- handle
		ball(1.5, { 0, 1.95, -0.05 }, CAT),
		block({ 0.35, 0.35, 0.15 }, { -0.42, 2.62, -0.05 }, CAT, { turn = { 0, 0, 45 } }), -- ears
		block({ 0.35, 0.35, 0.15 }, { 0.42, 2.62, -0.05 }, CAT, { turn = { 0, 0, 45 } }),
		ellipsoid({ 0.6, 0.35, 0.2 }, { 0, 1.75, -0.68 }, CREAM), -- cheeks
		ball(0.15, { 0, 1.9, -0.8 }, hex("#FF8FA3")), -- nose
		ball(0.36, { -0.36, 1.45, -0.72 }, hex("#FFB86B")), -- paws on the rim
		ball(0.36, { 0.36, 1.45, -0.72 }, hex("#FFB86B")),
		rod(0.9, 0.2, { -0.5, 1.6, 0.75 }, CAT, { turn = { 0, 0, 60 } }), -- tail
		ball(0.4, { 0.5, 2.9, 0.05 }, WHITE, { transparency = 0.5 }), -- steam
		ball(0.3, { 0.75, 3.25, 0.12 }, WHITE, { transparency = 0.6 }),
	}, eyes(0.3, 2.05, -0.66, 0.36)),
}

-- A crab whose body is a two-drawer filing cabinet.
local CRAB = hex("#E8473B")
local CABINET = hex("#9AA5B1")
looks.FilingCabinetCrab = {
	pieces = join({
		block({ 1.6, 1.3, 1.1 }, { 0, 1.05, 0 }, CABINET, { material = METAL }),
		block({ 1.4, 0.05, 0.05 }, { 0, 1.05, -0.56 }, hex("#5C6677")), -- drawer line
		block({ 0.36, 0.08, 0.06 }, { 0, 1.38, -0.57 }, SILVER, { material = METAL }), -- handles
		block({ 0.36, 0.08, 0.06 }, { 0, 0.78, -0.57 }, SILVER, { material = METAL }),
		rod(0.85, 0.14, { -1.0, 0.45, -0.3 }, CRAB, { turn = { 0, 0, -35 } }), -- legs
		rod(0.85, 0.14, { -1.0, 0.45, 0.05 }, CRAB, { turn = { 0, 0, -35 } }),
		rod(0.85, 0.14, { -1.0, 0.45, 0.4 }, CRAB, { turn = { 0, 0, -35 } }),
		rod(0.85, 0.14, { 1.0, 0.45, -0.3 }, CRAB, { turn = { 0, 0, 35 } }),
		rod(0.85, 0.14, { 1.0, 0.45, 0.05 }, CRAB, { turn = { 0, 0, 35 } }),
		rod(0.85, 0.14, { 1.0, 0.45, 0.4 }, CRAB, { turn = { 0, 0, 35 } }),
		rod(0.7, 0.16, { -0.95, 1.2, -0.35 }, CRAB, { turn = { 0, 30, 20 } }), -- arms
		rod(0.7, 0.16, { 0.95, 1.2, -0.35 }, CRAB, { turn = { 0, -30, -20 } }),
		ellipsoid({ 0.7, 0.5, 0.6 }, { -1.25, 1.35, -0.6 }, CRAB), -- claws
		ellipsoid({ 0.7, 0.5, 0.6 }, { 1.25, 1.35, -0.6 }, CRAB),
		can(0.5, 0.1, { -0.3, 1.95, -0.3 }, CRAB), -- eye stalks
		can(0.5, 0.1, { 0.3, 1.95, -0.3 }, CRAB),
	}, eyes(0.3, 2.3, -0.34, 0.38)),
}

---------------------------------------------------------------------------
-- Rare

-- A sloth hugging a spreadsheet.
local SLOTH = hex("#A07A55")
local SHEET = hex("#2E9E5B")
looks.SpreadsheetSloth = {
	pieces = join({
		ellipsoid({ 1.4, 1.3, 1.2 }, { 0, 0.9, 0.1 }, SLOTH),
		ball(1.6, { 0, 2.1, -0.05 }, SLOTH),
		ellipsoid({ 1.2, 0.9, 0.3 }, { 0, 2.0, -0.7 }, hex("#E8D3B0")), -- face
		ellipsoid({ 0.5, 0.32, 0.12 }, { -0.32, 2.1, -0.82 }, hex("#5A3E2B"), { turn = { 0, 0, 20 } }),
		ellipsoid({ 0.5, 0.32, 0.12 }, { 0.32, 2.1, -0.82 }, hex("#5A3E2B"), { turn = { 0, 0, -20 } }),
		ellipsoid({ 0.22, 0.14, 0.1 }, { 0, 1.88, -0.9 }, INK), -- nose
		block({ 0.25, 0.05, 0.05 }, { 0, 1.76, -0.88 }, INK), -- smile
		block({ 1.3, 1.0, 0.1 }, { 0, 1.0, -0.78 }, SHEET, { turn = { -15, 0, 0 } }), -- the spreadsheet
		block({ 1.2, 0.05, 0.03 }, { 0, 1.1, -0.84 }, WHITE, { turn = { -15, 0, 0 } }),
		block({ 0.05, 0.9, 0.03 }, { -0.25, 1.0, -0.84 }, WHITE, { turn = { -15, 0, 0 } }),
		block({ 0.05, 0.9, 0.03 }, { 0.25, 1.0, -0.84 }, WHITE, { turn = { -15, 0, 0 } }),
		rod(1.0, 0.32, { -0.55, 1.15, -0.55 }, SLOTH, { turn = { 0, 60, -20 } }), -- arms round it
		rod(1.0, 0.32, { 0.55, 1.15, -0.55 }, SLOTH, { turn = { 0, -60, 20 } }),
		ball(0.42, { -0.4, 0.2, -0.3 }, SLOTH), -- feet
		ball(0.42, { 0.4, 0.2, -0.3 }, SLOTH),
	}, eyes(0.3, 2.12, -0.9, 0.3)),
}

-- A shark with a paper shredder for a mouth.
local SHARK = hex("#5B7FA6")
looks.ShredderShark = {
	pieces = join({
		ellipsoid({ 1.4, 1.4, 2.4 }, { 0, 1.2, 0.1 }, SHARK),
		ellipsoid({ 1.0, 0.9, 1.8 }, { 0, 0.95, -0.15 }, hex("#E8EEF4")), -- belly
		wedge({ 0.15, 0.9, 0.9 }, { 0, 2.1, 0.35 }, SHARK), -- dorsal fin
		wedge({ 0.15, 1.0, 0.8 }, { 0, 1.75, 1.45 }, SHARK, { turn = { -30, 0, 0 } }), -- tail
		wedge({ 0.15, 0.7, 0.6 }, { 0, 0.85, 1.4 }, SHARK, { turn = { 30, 0, 0 } }),
		wedge({ 0.6, 0.12, 0.6 }, { -0.78, 0.85, -0.1 }, SHARK, { turn = { 0, 0, 30 } }), -- side fins
		wedge({ 0.6, 0.12, 0.6 }, { 0.78, 0.85, -0.1 }, SHARK, { turn = { 0, 0, -30 } }),
		block({ 0.9, 0.14, 0.2 }, { 0, 0.98, -0.95 }, INK), -- the shredder slot
		block({ 0.12, 0.5, 0.03 }, { -0.25, 0.68, -1.02 }, WHITE, { turn = { 0, 0, 6 } }), -- paper strips
		block({ 0.12, 0.6, 0.03 }, { 0, 0.64, -1.03 }, WHITE),
		block({ 0.12, 0.45, 0.03 }, { 0.25, 0.7, -1.02 }, WHITE, { turn = { 0, 0, -6 } }),
	}, eyes(0.35, 1.45, -0.8, 0.38)),
}

---------------------------------------------------------------------------
-- Epic

-- A bull with a gold nose ring and a green "up" flag on its back.
local BULL = hex("#8B5A2B")
local UP = Theme.Chart.Rising
looks.BullMarketBull = {
	pieces = join({
		ellipsoid({ 1.5, 1.3, 1.8 }, { 0, 1.0, 0.2 }, BULL),
		ball(1.6, { 0, 2.05, -0.55 }, BULL),
		ellipsoid({ 1.0, 0.65, 0.55 }, { 0, 1.75, -1.25 }, hex("#E8B8A0")), -- muzzle
		ball(0.13, { -0.18, 1.82, -1.52 }, INK), -- nostrils
		ball(0.13, { 0.18, 1.82, -1.52 }, INK),
		disc(0.08, 0.45, { 0, 1.48, -1.5 }, GOLD, { material = METAL }), -- nose ring
		rod(0.8, 0.22, { -0.75, 2.72, -0.55 }, CREAM, { turn = { 0, 0, -35 } }), -- horns
		rod(0.8, 0.22, { 0.75, 2.72, -0.55 }, CREAM, { turn = { 0, 0, 35 } }),
		ellipsoid({ 0.45, 0.2, 0.3 }, { -0.85, 2.3, -0.45 }, BULL), -- ears
		ellipsoid({ 0.45, 0.2, 0.3 }, { 0.85, 2.3, -0.45 }, BULL),
		can(0.5, 0.42, { -0.42, 0.25, -0.35 }, hex("#5A3A1C")), -- legs
		can(0.5, 0.42, { 0.42, 0.25, -0.35 }, hex("#5A3A1C")),
		can(0.5, 0.42, { -0.42, 0.25, 0.75 }, hex("#5A3A1C")),
		can(0.5, 0.42, { 0.42, 0.25, 0.75 }, hex("#5A3A1C")),
		can(1.0, 0.08, { 0, 2.1, 0.55 }, SILVER), -- the flag's pole
		block({ 0.12, 0.5, 0.06 }, { 0.25, 2.4, 0.55 }, UP), -- the up arrow
		block({ 0.12, 0.3, 0.06 }, { 0.17, 2.66, 0.55 }, UP, { turn = { 0, 0, -45 } }),
		block({ 0.12, 0.3, 0.06 }, { 0.33, 2.66, 0.55 }, UP, { turn = { 0, 0, 45 } }),
	}, eyes(0.33, 2.15, -1.12, 0.36)),
}

-- A badger in a security guard's cap with a gold badge.
local BADGER = hex("#6E7380")
local NAVY = hex("#2D3A6B")
looks.SecurityBadger = {
	pieces = join({
		ellipsoid({ 1.5, 1.2, 1.6 }, { 0, 0.9, 0.15 }, BADGER),
		ellipsoid({ 1.0, 0.8, 0.3 }, { 0, 0.9, -0.6 }, SILVER), -- belly
		ball(1.6, { 0, 2.0, -0.1 }, BADGER),
		ellipsoid({ 0.35, 1.1, 0.3 }, { 0, 2.15, -0.74 }, WHITE), -- face stripe
		ellipsoid({ 0.5, 0.35, 0.12 }, { -0.35, 2.05, -0.78 }, hex("#3A3D4D")), -- mask
		ellipsoid({ 0.5, 0.35, 0.12 }, { 0.35, 2.05, -0.78 }, hex("#3A3D4D")),
		ball(0.22, { 0, 1.82, -0.9 }, INK), -- nose
		can(0.4, 1.5, { 0, 2.85, -0.05 }, NAVY), -- cap
		block({ 1.1, 0.08, 0.5 }, { 0, 2.68, -0.75 }, NAVY), -- its peak
		disc(0.05, 0.3, { 0, 2.88, -0.81 }, GOLD, { material = METAL }), -- cap badge
		disc(0.06, 0.42, { 0.32, 1.2, -0.76 }, GOLD, { material = METAL }), -- chest badge
		ball(0.4, { -0.75, 2.5, -0.05 }, BADGER), -- ears
		ball(0.4, { 0.75, 2.5, -0.05 }, BADGER),
		ball(0.45, { -0.42, 0.22, -0.35 }, hex("#4A4E5A")), -- feet
		ball(0.45, { 0.42, 0.22, -0.35 }, hex("#4A4E5A")),
		ball(0.45, { -0.42, 0.22, 0.6 }, hex("#4A4E5A")),
		ball(0.45, { 0.42, 0.22, 0.6 }, hex("#4A4E5A")),
	}, eyes(0.35, 2.07, -0.86, 0.3)),
}

---------------------------------------------------------------------------
-- Legendary

-- A shiny gold goose with its golden egg.
local GOOSE = hex("#FFC83D")
local GOOSE_DARK = hex("#E0A82A")
local BEAK = hex("#FF8A3D")
looks.GoldenGoose = {
	pieces = join({
		ellipsoid({ 1.4, 1.3, 1.8 }, { 0, 1.0, 0.25 }, GOOSE, { material = Enum.Material.Foil }),
		can(1.0, 0.45, { 0, 1.8, -0.45 }, GOOSE, { material = Enum.Material.Foil }), -- neck
		ball(1.0, { 0, 2.5, -0.55 }, GOOSE, { material = Enum.Material.Foil }),
		wedge({ 0.4, 0.25, 0.5 }, { 0, 2.42, -1.15 }, BEAK), -- beak
		ellipsoid({ 0.3, 0.8, 1.2 }, { -0.72, 1.15, 0.3 }, GOOSE_DARK, { turn = { 0, 0, 10 } }), -- wings
		ellipsoid({ 0.3, 0.8, 1.2 }, { 0.72, 1.15, 0.3 }, GOOSE_DARK, { turn = { 0, 0, -10 } }),
		wedge({ 0.8, 0.5, 0.5 }, { 0, 1.45, 1.15 }, GOOSE_DARK), -- tail
		can(0.4, 0.14, { -0.35, 0.3, 0 }, BEAK), -- legs
		can(0.4, 0.14, { 0.35, 0.3, 0 }, BEAK),
		ellipsoid({ 0.45, 0.12, 0.55 }, { -0.35, 0.06, -0.15 }, BEAK), -- feet
		ellipsoid({ 0.45, 0.12, 0.55 }, { 0.35, 0.06, -0.15 }, BEAK),
		ellipsoid({ 0.75, 0.95, 0.75 }, { 1.0, 0.48, -0.75 }, GOLD, { material = METAL, reflectance = 0.25 }), -- the egg
	}, eyes(0.24, 2.6, -0.92, 0.26)),
}

-- A tortoise whose shell is a round bank vault door.
local TORTOISE = hex("#8FBF6A")
local VAULT = hex("#8D99AE")
looks.VaultTortoise = {
	pieces = join({
		ellipsoid({ 2.1, 1.2, 2.3 }, { 0, 1.0, 0.1 }, VAULT, { material = METAL }),
		can(0.18, 2.2, { 0, 0.6, 0.1 }, hex("#5C6677"), { material = METAL }), -- shell rim
		disc(0.15, 1.2, { 0, 1.38, -0.8 }, SILVER, { turn = { 40, 0, 0 }, material = METAL }), -- the door
		rod(0.9, 0.08, { 0, 1.42, -0.88 }, GOLD, { turn = { 40, 0, 0 }, material = METAL }), -- its wheel
		rod(0.9, 0.08, { 0, 1.42, -0.88 }, GOLD, { turn = { 40, 0, 60 }, material = METAL }),
		rod(0.9, 0.08, { 0, 1.42, -0.88 }, GOLD, { turn = { 40, 0, 120 }, material = METAL }),
		disc(0.1, 0.25, { 0, 1.44, -0.9 }, GOLD, { turn = { 40, 0, 0 }, material = METAL }),
		ball(1.0, { 0, 0.95, -1.35 }, TORTOISE), -- head
		block({ 0.25, 0.05, 0.05 }, { 0, 0.8, -1.82 }, INK), -- smile
		can(0.6, 0.5, { -0.75, 0.3, -0.55 }, TORTOISE), -- legs
		can(0.6, 0.5, { 0.75, 0.3, -0.55 }, TORTOISE),
		can(0.6, 0.5, { -0.75, 0.3, 0.75 }, TORTOISE),
		can(0.6, 0.5, { 0.75, 0.3, 0.75 }, TORTOISE),
		wedge({ 0.2, 0.2, 0.4 }, { 0, 0.6, 1.3 }, TORTOISE, { turn = { 0, 180, 0 } }), -- tail
	}, eyes(0.22, 1.08, -1.72, 0.26)),
}

---------------------------------------------------------------------------
-- Mythic

-- A little dragon sitting on a stack of gold coins.
local DRAGON = hex("#7B4FD6")
local DRAGON_LIGHT = hex("#9B76E6")
looks.DividendDragon = {
	pieces = join({
		can(0.18, 1.8, { 0, 0.09, 0 }, GOLD, { material = METAL }), -- the coins
		can(0.18, 1.7, { 0.05, 0.27, 0 }, GOLD, { material = METAL }),
		can(0.18, 1.75, { -0.05, 0.45, 0 }, GOLD, { material = METAL }),
		disc(0.08, 0.5, { 1.0, 0.3, -0.7 }, GOLD, { turn = { 0, 30, 0 }, material = METAL }),
		ellipsoid({ 1.4, 1.4, 1.5 }, { 0, 1.25, 0.2 }, DRAGON),
		ellipsoid({ 0.9, 1.0, 0.3 }, { 0, 1.2, -0.48 }, hex("#FFD98A")), -- belly
		ball(1.6, { 0, 2.55, -0.3 }, DRAGON),
		ellipsoid({ 0.9, 0.6, 0.6 }, { 0, 2.35, -1.05 }, DRAGON_LIGHT), -- snout
		ball(0.12, { -0.15, 2.45, -1.34 }, INK), -- nostrils
		ball(0.12, { 0.15, 2.45, -1.34 }, INK),
		rod(0.7, 0.18, { -0.4, 3.35, -0.15 }, GOLD, { turn = { 0, 0, 110 } }), -- horns
		rod(0.7, 0.18, { 0.4, 3.35, -0.15 }, GOLD, { turn = { 0, 0, 70 } }),
		wedge({ 0.12, 1.0, 1.1 }, { -0.85, 2.0, 0.55 }, hex("#B48CFF"), { turn = { 0, 35, 20 } }), -- wings
		wedge({ 0.12, 1.0, 1.1 }, { 0.85, 2.0, 0.55 }, hex("#B48CFF"), { turn = { 0, -35, -20 } }),
		rod(1.0, 0.3, { 0, 0.85, 1.15 }, DRAGON, { turn = { 0, 90, -25 } }), -- tail
		wedge({ 0.12, 0.4, 0.4 }, { 0, 1.0, 1.65 }, GOLD, { turn = { 0, 180, 0 } }), -- its tip
	}, eyes(0.36, 2.7, -0.95, 0.38)),
}

-- A phoenix with brick firewall wings and a crest of glowing flames.
local PHOENIX = hex("#E8473B")
local FLAME = hex("#FFD23F")
looks.FirewallPhoenix = {
	pieces = join({
		ellipsoid({ 1.2, 1.4, 1.3 }, { 0, 1.3, 0.1 }, PHOENIX),
		ellipsoid({ 0.8, 0.9, 0.3 }, { 0, 1.25, -0.5 }, hex("#FF8A3D")), -- chest
		ball(1.2, { 0, 2.4, -0.15 }, PHOENIX),
		wedge({ 0.3, 0.22, 0.45 }, { 0, 2.3, -0.85 }, GOLD), -- beak
		wedge({ 0.12, 0.6, 0.4 }, { 0, 3.1, -0.05 }, hex("#FF8A3D"), { material = NEON }), -- crest
		wedge({ 0.12, 0.45, 0.35 }, { -0.18, 3.0, 0.05 }, FLAME, { turn = { 0, 0, 15 }, material = NEON }),
		wedge({ 0.12, 0.45, 0.35 }, { 0.18, 3.0, 0.05 }, FLAME, { turn = { 0, 0, -15 }, material = NEON }),
		-- Wings like brick walls, with flames along the top.
		block({ 0.15, 0.5, 1.0 }, { -0.75, 1.6, 0.2 }, hex("#B03A2E"), { turn = { 0, 0, 15 } }),
		block({ 0.15, 0.5, 1.0 }, { -0.82, 1.1, 0.35 }, hex("#E2603F"), { turn = { 0, 0, 15 } }),
		block({ 0.15, 0.5, 1.0 }, { 0.75, 1.6, 0.2 }, hex("#B03A2E"), { turn = { 0, 0, -15 } }),
		block({ 0.15, 0.5, 1.0 }, { 0.82, 1.1, 0.35 }, hex("#E2603F"), { turn = { 0, 0, -15 } }),
		wedge({ 0.12, 0.5, 0.4 }, { -0.68, 2.05, 0.3 }, FLAME, { turn = { 0, 0, 15 }, material = NEON }),
		wedge({ 0.12, 0.5, 0.4 }, { 0.68, 2.05, 0.3 }, FLAME, { turn = { 0, 0, -15 }, material = NEON }),
		wedge({ 0.5, 0.6, 0.9 }, { 0, 0.9, 0.95 }, hex("#FF8A3D"), { turn = { 20, 0, 0 } }), -- tail
		wedge({ 0.3, 0.45, 0.7 }, { 0, 0.75, 1.3 }, FLAME, { turn = { 30, 0, 0 }, material = NEON }),
		can(0.5, 0.12, { -0.25, 0.4, -0.05 }, GOLD), -- legs
		can(0.5, 0.12, { 0.25, 0.4, -0.05 }, GOLD),
		ellipsoid({ 0.35, 0.1, 0.45 }, { -0.25, 0.05, -0.15 }, GOLD), -- feet
		ellipsoid({ 0.35, 0.1, 0.45 }, { 0.25, 0.05, -0.15 }, GOLD),
	}, eyes(0.26, 2.5, -0.62, 0.3)),
}

-- The aura by rarity.
local auras: { [string]: Aura } = {
	Uncommon = { glow = 0.75, sparkles = 0, light = false },
	Rare = { glow = 0.62, sparkles = 2, light = false },
	Epic = { glow = 0.5, sparkles = 4, light = false },
	Legendary = { glow = 0.4, sparkles = 6, light = true },
	Mythic = { glow = 0.3, sparkles = 9, light = true },
}

return {
	looks = looks,
	auras = auras,

	MaxParts = 25,
	-- The glow under a pet, and its light.
	GlowDiameter = 2.6,
	GlowHeight = 0.06,
	LightRange = 7,
	LightBrightness = 0.8,
	-- The gentle bob and sway on the client, and how near the camera must be
	-- for it (and the sparkles).
	BobHeight = 0.15,
	BobSeconds = 2.4,
	SwayDegrees = 6,
	SwaySeconds = 3.6,
	EffectsDistance = 60,
	-- The plush pets on the pet shop's counter.
	ShopDisplay = { "CoffeeCat", "GoldenGoose" },
}
