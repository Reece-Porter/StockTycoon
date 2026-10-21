--!strict
-- How each weapon looks and swings (docs/visual-pass.md, Phase 7), next to
-- its entry in Config/Weapons. WeaponBuilder (server/Lib) turns these into
-- Tools when the server starts; a Tool in ReplicatedStorage.Assets.Weapons
-- with a HandMade attribute is used instead.
--
-- Cartoon office kit, nothing realistic. Positions are in studs from the
-- grip (where the hand holds it, the Tool's Handle), as the earlier Tools
-- had them (see Pieces). Part budget: 12 per weapon, the Handle included.
--
-- swing is the hold-and-swing the default character animation plays
-- ("Slash" or "Lunge"); the client adds the effect: a whoosh in the
-- weapon's colour for the melee ones, a recoil and puff for the Stapler Gun.

local Pieces = require(script.Parent.Parent.Pieces)
local Theme = require(script.Parent.Parent.Theme)

export type Look = {
	pieces: { Pieces.Piece },
	swing: "Slash" | "Lunge",
	-- The whoosh's colour, or the puff's.
	trail: Color3,
	-- Fires: a recoil and a puff at the tip instead of a whoosh.
	shoots: boolean,
	-- Where the tip is, for the puff.
	tip: Pieces.Vec,
}

local block, ball, wedge = Pieces.block, Pieces.ball, Pieces.wedge
local rod, can = Pieces.rod, Pieces.can
local hex = Theme.hex

local GOLD = Theme.Colours.Gold
local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood

local looks: { [string]: Look } = {}

-- A rolled-up newspaper with print stripes, a rubber band and a page corner
-- sticking out.
local PAPER = hex("#EBE6D7")
looks.Newspaper = {
	swing = "Slash",
	trail = Theme.Colours.Card,
	shoots = false,
	tip = { 0, 2.5, 0 },
	pieces = {
		can(3, 0.62, { 0, 1, 0 }, PAPER),
		can(0.1, 0.64, { 0, 0.55, 0 }, hex("#8D99AE")),
		can(0.1, 0.64, { 0, 1.55, 0 }, hex("#8D99AE")),
		can(0.16, 0.66, { 0, 0.05, 0 }, hex("#E8473B")), -- rubber band
		wedge({ 0.04, 0.7, 0.5 }, { 0.34, 2.1, 0 }, PAPER, { turn = { 0, 90, 0 } }), -- page corner
	},
}

-- A chunky briefcase with gold clasps.
local LEATHER = hex("#8B5A2B")
looks.Briefcase = {
	swing = "Lunge",
	trail = hex("#C9A27A"),
	shoots = false,
	tip = { 0, -1.7, 0 },
	pieces = {
		block({ 1, 0.22, 0.26 }, { 0, 0, 0 }, hex("#4A2E16")), -- the grip
		block({ 0.16, 0.3, 0.2 }, { -0.42, -0.2, 0 }, GOLD, { material = METAL }),
		block({ 0.16, 0.3, 0.2 }, { 0.42, -0.2, 0 }, GOLD, { material = METAL }),
		block({ 2.2, 1.5, 0.6 }, { 0, -0.95, 0 }, LEATHER),
		block({ 2.24, 0.12, 0.64 }, { 0, -1.1, 0 }, hex("#6E4520")), -- seam
		block({ 0.28, 0.2, 0.66 }, { -0.6, -0.35, 0 }, GOLD, { material = METAL }), -- clasps
		block({ 0.28, 0.2, 0.66 }, { 0.6, -0.35, 0 }, GOLD, { material = METAL }),
	},
}

-- A cartoon stapler blown up into a staple gun.
local STAPLER = hex("#3D8BFF")
local STEEL = hex("#C9CED6")
looks.StaplerGun = {
	swing = "Slash",
	trail = STAPLER,
	shoots = true,
	tip = { 0, 0.7, -1.8 },
	pieces = {
		block({ 0.45, 1, 0.6 }, { 0, 0, 0 }, hex("#2B2D42")), -- the grip
		block({ 0.15, 0.4, 0.15 }, { 0, 0.25, -0.38 }, hex("#E8473B")), -- trigger
		block({ 0.8, 0.6, 2.2 }, { 0, 0.75, -0.4 }, STAPLER),
		block({ 0.82, 0.12, 1.6 }, { 0, 0.52, -0.5 }, GOLD), -- stripe
		block({ 0.7, 0.25, 2 }, { 0, 1.15, -0.3 }, STEEL, { material = METAL }), -- the top arm
		rod(0.86, 0.3, { 0, 1.0, 0.66 }, STEEL, { material = METAL }), -- hinge
		block({ 0.4, 0.3, 0.3 }, { 0, 0.7, -1.62 }, STEEL, { material = METAL }), -- nozzle
	},
}

-- A judge's gavel with gold bands.
local WOOD_LIGHT = hex("#B07A4A")
local WOOD_DARK = hex("#6E4520")
looks.Gavel = {
	swing = "Lunge",
	trail = hex("#FFC83D"),
	shoots = false,
	tip = { 0, 2.3, 0 },
	pieces = {
		can(2.6, 0.35, { 0, 0.9, 0 }, WOOD_LIGHT, { material = WOOD }), -- shaft
		ball(0.45, { 0, -0.42, 0 }, GOLD, { material = METAL }), -- pommel
		rod(1.8, 0.9, { 0, 2.3, 0 }, WOOD_DARK, { material = WOOD }), -- head
		rod(0.15, 0.96, { -0.6, 2.3, 0 }, GOLD, { material = METAL }),
		rod(0.15, 0.96, { 0.6, 2.3, 0 }, GOLD, { material = METAL }),
		rod(0.08, 0.7, { -0.93, 2.3, 0 }, GOLD, { material = METAL }), -- end caps
		rod(0.08, 0.7, { 0.93, 2.3, 0 }, GOLD, { material = METAL }),
	},
}

-- A golden calculator with a glowing screen.
local KEY = hex("#FFF1D6")
local calculator = {
	block({ 1.3, 1.9, 0.35 }, { 0, 0.9, 0 }, GOLD, { material = Enum.Material.Foil }),
	block({ 1.0, 0.45, 0.05 }, { 0, 1.5, -0.19 }, Theme.Chart.Rising, { material = Enum.Material.Neon }),
}
for row = 0, 2 do
	for column = -1, 1 do
		local colour = if row == 2 and column == 1 then hex("#FF8A3D") else KEY
		table.insert(calculator, block({ 0.22, 0.22, 0.06 }, { column * 0.35, 1.05 - row * 0.32, -0.19 }, colour))
	end
end
looks.GoldenCalculator = {
	swing = "Slash",
	trail = GOLD,
	shoots = false,
	tip = { 0, 1.8, 0 },
	pieces = calculator,
}

return {
	looks = looks,
	MaxParts = 12,
	-- The Handle every weapon is held by.
	HandleSize = 0.4,
}
