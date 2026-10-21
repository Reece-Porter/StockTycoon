--!strict
-- Company variants (docs/design.md, "Variants"). Starting assumptions.
--
-- Any company can turn up as a variant on either conveyor. A variant earns its
-- multiplier times the company's normal income, and the bigger the
-- multiplier, the rarer it is (oneIn: about one company in this many). The
-- Variant Chance upgrade makes them all more likely on the player's own
-- conveyor. A variant costs the same as a regular company, keeps its variant
-- for good (through the Valuation Machine and stealing), and has nothing to
-- do with the machine's multiplier.
--
-- Each variant's look (docs/visual-pass.md, Phase 4) is a layer
-- VariantLayer puts over any company model's copy: recolours, shapes, seams
-- and particles here; the Rainbow and Glitched motion runs on the client
-- (CompanyFxController). Variants add no lights: the light budget is one per
-- model, on Conglomerate and Monopoly only.

local Theme = require(script.Parent.Parent.Theme)

export type Particles = {
	colours: { Color3 },
	-- Particles a second (a few: the brief's budget is about 10 a model).
	rate: number,
	-- Seconds each lasts, and studs a second it moves: { lowest, highest }.
	lifetime: { number },
	speed: { number },
	-- Starting size in studs, shrinking away (or, twinkling, growing then
	-- shrinking).
	size: number,
	twinkle: boolean?,
	-- Floats upwards, like embers: upward pull in studs a second squared.
	rise: number?,
	-- Square particles (no texture), for the retro and glitchy looks.
	square: boolean?,
	lightEmission: number,
}

-- How a variant changes a company model's pun object (VariantLayer). Every
-- field is optional; each variant uses a few.
export type Look = {
	-- "brighten": lighter by amount. "palette": each colour snapped to the
	-- nearest in palette. "ramp": shades from ramp[1] (dark) to ramp[2]
	-- (light), by how light each piece was.
	recolour: string?,
	amount: number?,
	palette: { Color3 }?,
	ramp: { Color3 }?,
	material: Enum.Material?,
	reflectance: number?,
	-- Balls, cylinders and stretched balls become blocks.
	blocky: boolean?,
	-- Pieces are pulled this far towards these colours, taking turns.
	tints: { Color3 }?,
	tintAmount: number?,
	-- Glowing Neon seams round this many of the biggest pieces.
	cracks: number?,
	-- Neon pieces (and seams) glow this colour.
	glow: Color3?,
	-- Up to this many small accent pieces take colours round the colour
	-- wheel, which the client keeps turning (once round every cycleSeconds).
	accents: number?,
	cycleSeconds: number?,
	-- Brief flickers and a ghost copy of the biggest pieces in each colour,
	-- offset sideways (client): every lowest to highest seconds.
	glitch: {
		every: { number },
		lasts: number,
		ghostColours: { Color3 },
		ghostOffset: number,
		ghostPieces: number,
	}?,
	particles: Particles?,
}

export type Variant = {
	id: string,
	name: string,
	multiplier: number,
	oneIn: number,
	-- From Theme.Variants: the badge and name colour.
	colour: Color3,
	look: Look,
}

local hex = Theme.hex
local WHITE = hex("#FFFFFF")
local GHOST_RED = hex("#FF2A6D")
local GHOST_CYAN = Theme.Variants.Glitched

local list: { Variant } = {
	{
		id = "Shiny",
		name = "Shiny",
		multiplier = 1.5,
		oneIn = 20,
		colour = Theme.Variants.Shiny,
		look = {
			recolour = "brighten",
			amount = 0.35,
			reflectance = 0.3,
			particles = {
				colours = { WHITE, hex("#FFF1B8") },
				rate = 3,
				lifetime = { 1.2, 1.8 },
				speed = { 0.2, 0.6 },
				size = 0.3,
				twinkle = true,
				lightEmission = 1,
			},
		},
	},
	{
		id = "Pixel",
		name = "Pixel",
		multiplier = 2,
		oneIn = 50,
		colour = Theme.Variants.Pixel,
		look = {
			recolour = "palette",
			-- A small retro palette of our own.
			palette = {
				hex("#1D1A2F"),
				hex("#F4F4F4"),
				hex("#8B9BB4"),
				hex("#E43B44"),
				hex("#F77622"),
				hex("#FEE761"),
				hex("#63C74D"),
				hex("#2CE8F5"),
				hex("#2D63D8"),
				hex("#8A4FD8"),
				hex("#FF77A8"),
				hex("#8F563B"),
			},
			material = Enum.Material.SmoothPlastic,
			blocky = true,
			particles = {
				colours = { hex("#63C74D"), hex("#FEE761"), hex("#2CE8F5") },
				rate = 4,
				lifetime = { 0.8, 1.2 },
				speed = { 0.5, 1 },
				size = 0.2,
				square = true,
				lightEmission = 0.3,
			},
		},
	},
	{
		id = "Molten",
		name = "Molten",
		multiplier = 3,
		oneIn = 120,
		colour = Theme.Variants.Molten,
		look = {
			recolour = "ramp",
			ramp = { hex("#211A18"), hex("#4E3B33") },
			material = Enum.Material.Basalt,
			cracks = 3,
			glow = Theme.Variants.Molten,
			particles = {
				colours = { hex("#FFB347"), hex("#FF4D1A") },
				rate = 5,
				lifetime = { 1.2, 1.8 },
				speed = { 1, 2 },
				size = 0.15,
				rise = 1.5,
				lightEmission = 1,
			},
		},
	},
	{
		id = "Galaxy",
		name = "Galaxy",
		multiplier = 5,
		oneIn = 300,
		colour = Theme.Variants.Galaxy,
		look = {
			recolour = "ramp",
			ramp = { hex("#140B33"), hex("#4B2A8F") },
			tints = { hex("#FF5FB0"), hex("#3D8BFF") },
			tintAmount = 0.22,
			reflectance = 0.1,
			glow = hex("#CFC4FF"),
			particles = {
				colours = { WHITE, hex("#CFC4FF") },
				rate = 5,
				lifetime = { 0.6, 1.2 },
				speed = { 0, 0.1 },
				size = 0.22,
				twinkle = true,
				lightEmission = 1,
			},
		},
	},
	{
		id = "Rainbow",
		name = "Rainbow",
		multiplier = 7,
		oneIn = 600,
		colour = Theme.Variants.Rainbow,
		look = {
			accents = 8,
			cycleSeconds = 4,
		},
	},
	{
		id = "Glitched",
		name = "Glitched",
		multiplier = 10,
		oneIn = 1500,
		colour = Theme.Variants.Glitched,
		look = {
			tints = { GHOST_RED, GHOST_CYAN },
			tintAmount = 0.2,
			glitch = {
				every = { 1.5, 4 },
				lasts = 0.25,
				ghostColours = { GHOST_RED, GHOST_CYAN },
				ghostOffset = 0.3,
				ghostPieces = 2,
			},
			particles = {
				colours = { GHOST_RED, GHOST_CYAN, WHITE },
				rate = 5,
				lifetime = { 0.3, 0.6 },
				speed = { 0, 0.4 },
				size = 0.2,
				square = true,
				lightEmission = 0.6,
			},
		},
	},
}

local byId: { [string]: Variant } = {}
for _, variant in list do
	byId[variant.id] = variant
end

return {
	list = list,
	byId = byId,
	-- Variants this rare or rarer are announced to everyone when they turn up
	-- on the shared conveyor.
	AnnounceOneIn = 300,
}
