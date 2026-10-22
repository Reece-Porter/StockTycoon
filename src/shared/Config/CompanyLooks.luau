--!strict
-- How each parody company looks (docs/visual-pass.md, Phase 3): its logo
-- badge and the pieces of its pun object, next to its entry in
-- Config/Companies. CompanyBuilder (server/Lib) turns these into models when
-- the server starts. Original designs only: obvious puns and made-up colours,
-- never a real logo, wordmark, font or brand colour scheme.
--
-- Every model has the same structure: a plinth in its tier's colour (grander
-- each tier up, see Plinths), the pun object on top, a floating badge and a
-- nameplate on the plinth's front. A company with no look here still gets
-- the plinth, badge and nameplate, with a plain box on top.
--
-- Positions are in studs from the centre of the top of the plinth: x to the
-- right, y up, and the front (towards the walkway on a plot, the way it
-- travels on a belt) is -z. turn is in degrees about x, then y, then z.
-- Cylinders lie along x; can() stands one up and disc() turns one to face
-- the front. Part budget: 30 parts per model, plinth included.

local Pieces = require(script.Parent.Parent.Pieces)
local Theme = require(script.Parent.Parent.Theme)

export type Vec = Pieces.Vec
export type Text = Pieces.Text
export type Piece = Pieces.Piece

export type Badge = {
	-- Two or three letters in an original badge, never a real logo.
	text: string,
	colour: Color3,
	ink: Color3,
	-- Where it floats, if not just above the object.
	at: Vec?,
}

export type Look = {
	badge: Badge,
	-- Turns the whole object about the top of the plinth.
	tilt: Vec?,
	pieces: { Piece },
}

export type Plinth = {
	diameter: number,
	height: number,
	-- A light ring round the top edge.
	trim: boolean,
	-- A wider, lower ring at the bottom.
	step: boolean,
	-- A gold ring round the top edge instead of the light one.
	gold: boolean,
	-- A gentle Neon glow ring with the model's one PointLight.
	glow: boolean,
	-- A few slow sparkles (ParticleEmitter, client turns it off far away).
	aura: boolean,
	-- The object slowly spins and bobs (on the client).
	idle: boolean,
}

local block, ball, ellipsoid, wedge = Pieces.block, Pieces.ball, Pieces.ellipsoid, Pieces.wedge
local rod, can, disc = Pieces.rod, Pieces.can, Pieces.disc

local hex = Theme.hex
local NEON = Enum.Material.Neon
local GLASS_MATERIAL = Enum.Material.Glass
local METAL = Enum.Material.Metal

local INK = Theme.Colours.Ink
local WHITE = Theme.Colours.Card
local GOLD = Theme.Colours.Gold
local CREAM = hex("#FFF1D6")
local SILVER = hex("#C9CED6")
local STEEL = hex("#8D99AE")
local GLASS = hex("#BFE6FF")
local STEAM = hex("#FFFFFF")
local TYRE = hex("#3A3A4A")
local DARK = hex("#2B2D42")

local looks: { [string]: Look } = {}

---------------------------------------------------------------------------
-- Startup

-- A chatty sandwich with a speech bubble.
local BREAD = hex("#E8B567")
looks.Snackchat = {
	badge = { text = "Sc", colour = hex("#E8473B"), ink = WHITE },
	pieces = {
		block({ 2.2, 0.35, 1.8 }, { 0, 0.18, 0 }, BREAD),
		block({ 2.35, 0.12, 1.95 }, { 0, 0.41, 0 }, hex("#7BC043")), -- lettuce
		block({ 2.1, 0.14, 1.75 }, { 0, 0.54, 0 }, hex("#E8473B")), -- tomato
		block({ 2.25, 0.08, 1.9 }, { 0, 0.65, 0 }, hex("#FFB547"), { turn = { 0, 8, 0 } }), -- cheese
		block({ 2.2, 0.45, 1.8 }, { 0, 0.92, 0 }, BREAD),
		ball(0.42, { -0.4, 0.95, -0.92 }, WHITE),
		ball(0.42, { 0.4, 0.95, -0.92 }, WHITE),
		ball(0.2, { -0.4, 0.95, -1.12 }, INK),
		ball(0.2, { 0.4, 0.95, -1.12 }, INK),
		ellipsoid({ 1.4, 0.95, 0.3 }, { 0.75, 1.95, 0 }, WHITE), -- speech bubble
		block({ 0.32, 0.32, 0.2 }, { 0.4, 1.5, 0 }, WHITE, { turn = { 0, 0, 45 } }),
		ball(0.18, { 0.42, 1.95, -0.16 }, INK),
		ball(0.18, { 0.75, 1.95, -0.16 }, INK),
		ball(0.18, { 1.08, 1.95, -0.16 }, INK),
	},
}

-- A cat sitting on a kitchen scale, reading grams.
local CAT = hex("#F28C28")
local CAT_LIGHT = hex("#FFF3E0")
looks.Kittygram = {
	badge = { text = "Kg", colour = CREAM, ink = hex("#D9731A") },
	pieces = {
		block({ 2.4, 0.5, 2.0 }, { 0, 0.25, 0 }, hex("#F5F3EE")), -- the scale
		block({ 2.2, 0.12, 1.8 }, { 0, 0.56, 0.05 }, SILVER),
		block({ 1.0, 0.32, 0.06 }, { 0, 0.25, -1.02 }, DARK, {
			text = { text = "500g", face = "Front", colour = hex("#9BF6A3") },
		}),
		ellipsoid({ 1.3, 1.2, 1.1 }, { 0, 1.2, 0.15 }, CAT),
		ellipsoid({ 0.6, 0.6, 0.2 }, { 0, 1.2, -0.38 }, CAT_LIGHT), -- chest
		ball(1.0, { 0, 2.05, -0.05 }, CAT),
		block({ 0.3, 0.3, 0.12 }, { -0.3, 2.48, -0.05 }, CAT, { turn = { 0, 0, 45 } }),
		block({ 0.3, 0.3, 0.12 }, { 0.3, 2.48, -0.05 }, CAT, { turn = { 0, 0, 45 } }),
		ball(0.18, { -0.2, 2.12, -0.5 }, INK),
		ball(0.18, { 0.2, 2.12, -0.5 }, INK),
		ball(0.13, { 0, 1.98, -0.55 }, hex("#FF8FA3")),
		ball(0.32, { -0.3, 0.72, -0.42 }, CAT_LIGHT), -- paws
		ball(0.32, { 0.3, 0.72, -0.42 }, CAT_LIGHT),
		rod(1.0, 0.22, { 0.72, 1.2, 0.5 }, hex("#D9731A"), { turn = { 0, 0, 60 } }), -- tail
	},
}

-- A steaming bowl of linguine with a tiny made-up flag on the fork.
local PASTA = hex("#F6D98B")
local NAVY = hex("#3D5A80")
looks.Duolinguini = {
	badge = { text = "Dl", colour = NAVY, ink = WHITE },
	pieces = {
		can(0.2, 1.6, { 0, 0.1, 0 }, WHITE),
		can(0.9, 2.4, { 0, 0.6, 0 }, WHITE), -- the bowl
		can(0.15, 2.55, { 0, 1.0, 0 }, NAVY), -- its rim
		ellipsoid({ 2.1, 0.7, 2.1 }, { 0, 1.05, 0 }, PASTA),
		rod(1.6, 0.1, { 0.15, 1.2, -0.35 }, PASTA, { turn = { 0, 30, 12 } }),
		rod(1.4, 0.1, { -0.25, 1.22, 0.25 }, PASTA, { turn = { 0, -40, -8 } }),
		ellipsoid({ 1.2, 0.35, 1.2 }, { 0, 1.35, 0 }, hex("#D7372E")), -- sauce
		ball(0.55, { 0.1, 1.55, -0.05 }, hex("#7A4A2B")), -- meatball
		can(1.6, 0.1, { -0.45, 2.0, 0.15 }, SILVER), -- the fork
		block({ 0.55, 0.36, 0.04 }, { -0.15, 2.58, 0.15 }, hex("#FF7A1A")), -- its flag
		block({ 0.55, 0.12, 0.05 }, { -0.15, 2.58, 0.15 }, WHITE),
		ball(0.35, { 0.55, 2.0, -0.25 }, STEAM, { transparency = 0.5 }),
		ball(0.25, { 0.7, 2.4, -0.15 }, STEAM, { transparency = 0.6 }),
	},
}

-- An oversized rusty drawing pin.
local RUST = hex("#B4532A")
local RUST_LIGHT = hex("#CF7A3E")
local RUST_DARK = hex("#7A3B1A")
looks.Pinterust = {
	badge = { text = "Pt", colour = RUST, ink = CREAM },
	tilt = { -8, 0, 12 },
	pieces = {
		can(1.3, 0.18, { 0, 0.55, 0 }, SILVER), -- the point, stuck in the plinth
		can(0.2, 2.2, { 0, 1.3, 0 }, RUST),
		can(1.0, 1.2, { 0, 1.9, 0 }, RUST_LIGHT),
		can(0.12, 1.3, { 0, 1.9, 0 }, RUST_DARK),
		can(0.25, 1.6, { 0, 2.5, 0 }, RUST),
		ellipsoid({ 0.4, 0.12, 0.3 }, { 0.55, 1.4, -0.55 }, RUST_DARK), -- rust spots
		ellipsoid({ 0.3, 0.12, 0.35 }, { -0.7, 1.4, 0.2 }, RUST_DARK),
		ellipsoid({ 0.35, 0.1, 0.3 }, { 0.25, 2.62, -0.3 }, RUST_DARK),
		ellipsoid({ 0.25, 0.1, 0.25 }, { -0.35, 2.62, 0.35 }, RUST_DARK),
		ellipsoid({ 0.12, 0.3, 0.3 }, { -0.6, 2.0, -0.05 }, RUST_DARK),
	},
}

-- A squishy rubber car.
local RUBBER = hex("#FF7EB6")
looks.Ubber = {
	badge = { text = "Ub", colour = RUBBER, ink = INK },
	pieces = {
		ellipsoid({ 1.7, 0.9, 2.6 }, { 0, 0.75, 0 }, RUBBER),
		ellipsoid({ 1.35, 0.9, 1.5 }, { 0, 1.2, 0.2 }, hex("#FFA8CF")), -- the cabin
		block({ 1.0, 0.38, 0.06 }, { 0, 1.32, -0.48 }, GLASS, { turn = { 35, 0, 0 }, transparency = 0.2 }),
		rod(0.35, 0.7, { -0.78, 0.35, -0.8 }, TYRE),
		rod(0.35, 0.7, { 0.78, 0.35, -0.8 }, TYRE),
		rod(0.35, 0.7, { -0.78, 0.35, 0.8 }, TYRE),
		rod(0.35, 0.7, { 0.78, 0.35, 0.8 }, TYRE),
		ball(0.36, { -0.42, 0.85, -1.18 }, WHITE), -- headlight eyes
		ball(0.36, { 0.42, 0.85, -1.18 }, WHITE),
		ball(0.16, { -0.42, 0.85, -1.35 }, INK),
		ball(0.16, { 0.42, 0.85, -1.35 }, INK),
		ellipsoid({ 1.4, 0.28, 0.3 }, { 0, 0.5, -1.22 }, WHITE), -- bumper
	},
}

-- A radish with cartoon eyes and a little antenna on top.
local RADISH = hex("#D63A6E")
local RADISH_ROOT = hex("#FFF1E8")
local RADISH_LEAF = hex("#5DBB63")
looks.Reddish = {
	badge = { text = "Rd", colour = RADISH, ink = WHITE },
	pieces = {
		ellipsoid({ 0.32, 0.45, 0.32 }, { 0, 0.22, 0 }, RADISH_ROOT), -- root tip
		ellipsoid({ 0.95, 0.75, 0.95 }, { 0, 0.5, 0 }, RADISH),
		ball(1.7, { 0, 1.2, 0 }, RADISH),
		ellipsoid({ 0.32, 0.5, 0.08 }, { -0.42, 1.45, -0.72 }, WHITE, { turn = { 0, -25, 0 }, transparency = 0.4 }),
		ball(0.42, { -0.3, 1.3, -0.72 }, WHITE),
		ball(0.42, { 0.3, 1.3, -0.72 }, WHITE),
		ball(0.2, { -0.3, 1.3, -0.92 }, INK),
		ball(0.2, { 0.3, 1.3, -0.92 }, INK),
		block({ 0.4, 0.07, 0.05 }, { 0, 0.92, -0.8 }, INK), -- smile
		ellipsoid({ 0.35, 0.9, 0.12 }, { -0.3, 2.35, 0 }, RADISH_LEAF, { turn = { 0, 0, 25 } }), -- leaves
		ellipsoid({ 0.35, 1.0, 0.12 }, { 0.05, 2.45, 0.05 }, RADISH_LEAF, { turn = { 0, 40, -5 } }),
		ellipsoid({ 0.35, 0.85, 0.12 }, { 0.35, 2.3, 0 }, RADISH_LEAF, { turn = { 0, 0, -28 } }),
		rod(0.75, 0.07, { 0.42, 2.3, -0.3 }, INK, { turn = { 0, 0, 70 } }), -- antenna
		ball(0.26, { 0.55, 2.68, -0.3 }, RADISH),
	},
}

---------------------------------------------------------------------------
-- Scale-up

-- A popcorn bucket with a film strip flicking out of it.
local POPCORN = hex("#FFF3C4")
local BUCKET = hex("#2B6FD6")
local FILM = DARK
local FRAME = hex("#9AD1FF")
looks.Netflicks = {
	badge = { text = "Nf", colour = POPCORN, ink = BUCKET },
	pieces = {
		can(0.4, 1.9, { 0, 0.2, 0 }, WHITE),
		can(0.4, 1.92, { 0, 0.6, 0 }, BUCKET),
		can(0.4, 1.94, { 0, 1.0, 0 }, WHITE),
		can(0.4, 1.96, { 0, 1.4, 0 }, BUCKET),
		can(0.12, 2.06, { 0, 1.64, 0 }, WHITE),
		ball(0.95, { 0, 1.85, 0 }, POPCORN),
		ball(0.6, { 0.5, 1.8, 0.3 }, POPCORN),
		ball(0.6, { -0.5, 1.8, -0.2 }, POPCORN),
		ball(0.55, { 0.2, 2.2, -0.3 }, POPCORN),
		ball(0.55, { -0.3, 2.25, 0.3 }, POPCORN),
		ball(0.5, { 0.5, 1.95, -0.45 }, POPCORN),
		block({ 0.5, 0.45, 0.06 }, { 0.92, 1.94, -0.2 }, FILM, { turn = { 0, 0, 75 } }),
		block({ 0.5, 0.45, 0.06 }, { 1.16, 2.36, -0.2 }, FILM, { turn = { 0, 0, 45 } }),
		block({ 0.5, 0.45, 0.06 }, { 1.57, 2.6, -0.2 }, FILM, { turn = { 0, 0, 15 } }),
		block({ 0.3, 0.27, 0.07 }, { 0.92, 1.94, -0.2 }, FRAME, { turn = { 0, 0, 75 } }),
		block({ 0.3, 0.27, 0.07 }, { 1.16, 2.36, -0.2 }, FRAME, { turn = { 0, 0, 45 } }),
		block({ 0.3, 0.27, 0.07 }, { 1.57, 2.6, -0.2 }, FRAME, { turn = { 0, 0, 15 } }),
	},
}

-- A fly wearing big headphones on a record.
local FLY = hex("#66758A")
local RECORD_LABEL = hex("#FF5FB0")
looks.Spotifly = {
	badge = { text = "Sf", colour = RECORD_LABEL, ink = INK },
	pieces = {
		can(0.1, 2.8, { 0, 0.05, 0 }, hex("#18181E")), -- the record
		can(0.14, 2.0, { 0, 0.07, 0 }, hex("#34343F")),
		can(0.18, 0.9, { 0, 0.09, 0 }, RECORD_LABEL),
		can(0.3, 0.12, { 0, 0.2, 0 }, SILVER),
		ellipsoid({ 0.95, 0.85, 1.35 }, { 0, 0.62, 0.15 }, FLY),
		ball(0.72, { 0, 0.9, -0.6 }, FLY),
		ball(0.42, { -0.25, 1.0, -0.8 }, hex("#B23A48")),
		ball(0.42, { 0.25, 1.0, -0.8 }, hex("#B23A48")),
		ellipsoid({ 0.9, 0.08, 0.5 }, { -0.5, 1.05, 0.35 }, GLASS, { turn = { 0, 20, 20 }, transparency = 0.35 }),
		ellipsoid({ 0.9, 0.08, 0.5 }, { 0.5, 1.05, 0.35 }, GLASS, { turn = { 0, -20, -20 }, transparency = 0.35 }),
		block({ 0.86, 0.12, 0.16 }, { 0, 1.36, -0.6 }, GOLD), -- headphones
		block({ 0.1, 0.36, 0.14 }, { -0.42, 1.2, -0.6 }, GOLD),
		block({ 0.1, 0.36, 0.14 }, { 0.42, 1.2, -0.6 }, GOLD),
		rod(0.18, 0.42, { -0.42, 0.92, -0.6 }, GOLD),
		rod(0.18, 0.42, { 0.42, 0.92, -0.6 }, GOLD),
	},
}

-- A bee with a tiny house on its back.
local BEE = hex("#FFD23F")
looks.Airbnbee = {
	badge = { text = "Ab", colour = BEE, ink = INK },
	pieces = {
		ellipsoid({ 1.25, 1.1, 1.8 }, { 0, 0.85, 0.05 }, BEE),
		ellipsoid({ 1.32, 1.16, 0.28 }, { 0, 0.85, 0.15 }, INK), -- stripes
		ellipsoid({ 1.1, 0.97, 0.26 }, { 0, 0.85, 0.55 }, INK),
		ball(0.25, { 0, 0.82, 0.98 }, INK), -- stinger
		ball(0.8, { 0, 1.0, -0.95 }, DARK),
		ball(0.26, { -0.2, 1.1, -1.28 }, WHITE),
		ball(0.26, { 0.2, 1.1, -1.28 }, WHITE),
		ball(0.12, { -0.2, 1.1, -1.4 }, INK),
		ball(0.12, { 0.2, 1.1, -1.4 }, INK),
		rod(0.45, 0.06, { -0.18, 1.55, -1.05 }, INK, { turn = { 0, 0, 115 } }), -- antennae
		rod(0.45, 0.06, { 0.18, 1.55, -1.05 }, INK, { turn = { 0, 0, 65 } }),
		ellipsoid({ 0.9, 0.08, 0.55 }, { -0.75, 1.35, 0.15 }, GLASS, { turn = { 0, 0, 25 }, transparency = 0.35 }),
		ellipsoid({ 0.9, 0.08, 0.55 }, { 0.75, 1.35, 0.15 }, GLASS, { turn = { 0, 0, -25 }, transparency = 0.35 }),
		block({ 0.72, 0.5, 0.62 }, { 0, 1.6, 0.25 }, CREAM), -- the house
		block({ 0.6, 0.6, 0.72 }, { 0, 1.88, 0.25 }, hex("#3D7DD8"), { turn = { 0, 0, 45 } }),
		block({ 0.2, 0.3, 0.05 }, { 0, 1.5, -0.07 }, hex("#8B5A2B")),
	},
}

-- A playing card mid-toss into a bin.
local BIN = hex("#2A9D8F")
looks.Discard = {
	badge = { text = "Dc", colour = BIN, ink = WHITE },
	pieces = {
		can(1.4, 1.7, { 0, 0.7, 0.25 }, BIN),
		can(0.14, 1.86, { 0, 1.4, 0.25 }, hex("#21867A")),
		can(0.04, 1.5, { 0, 1.46, 0.25 }, hex("#1D3D3A")), -- the opening
		block({ 0.7, 1.0, 0.05 }, { -0.2, 1.65, 0.35 }, WHITE, { turn = { 10, 20, 15 } }),
		block({ 0.7, 1.0, 0.05 }, { 0.3, 1.6, 0.15 }, WHITE, { turn = { -10, -30, -10 } }),
		block({ 0.8, 1.1, 0.05 }, { -0.85, 2.35, -0.6 }, WHITE, {
			turn = { 0, 15, 35 },
			text = { text = "A", face = "Front", colour = hex("#E63946") },
		}),
		rod(0.5, 0.06, { -1.3, 2.75, -0.6 }, WHITE, { turn = { 0, 0, -30 }, transparency = 0.4 }),
		rod(0.4, 0.06, { -1.35, 2.5, -0.6 }, WHITE, { turn = { 0, 0, -30 }, transparency = 0.4 }),
	},
}

-- A speedy vacuum puck with racing stripes.
local PUCK = hex("#E63946")
local DUST = hex("#CFC6B8")
looks.Zoomba = {
	badge = { text = "Zm", colour = PUCK, ink = WHITE },
	pieces = {
		can(0.5, 2.4, { 0, 0.3, 0 }, PUCK),
		can(0.08, 2.0, { 0, 0.57, 0 }, hex("#B5202E")),
		block({ 0.26, 0.06, 1.8 }, { -0.26, 0.62, 0 }, WHITE), -- racing stripes
		block({ 0.26, 0.06, 1.8 }, { 0.26, 0.62, 0 }, WHITE),
		ellipsoid({ 1.7, 0.36, 0.34 }, { 0, 0.28, -1.12 }, TYRE), -- bumper
		can(0.1, 0.24, { 0, 0.64, 0.6 }, WHITE),
		block({ 0.1, 0.46, 0.1 }, { -0.6, 0.78, 0.85 }, INK), -- spoiler
		block({ 0.1, 0.46, 0.1 }, { 0.6, 0.78, 0.85 }, INK),
		block({ 1.7, 0.08, 0.45 }, { 0, 1.03, 0.92 }, WHITE, { turn = { -10, 0, 0 } }),
		ball(0.45, { 0.45, 0.3, 1.4 }, DUST, { transparency = 0.25 }), -- dust
		ball(0.35, { -0.25, 0.25, 1.5 }, DUST, { transparency = 0.3 }),
		ball(0.28, { 0.15, 0.4, 1.62 }, DUST, { transparency = 0.35 }),
	},
}

-- A front door with a covered dish waiting on the doormat.
local DOOR = hex("#2FA4A0")
local DOOR_PANEL = hex("#24807C")
local DOOR_FRAME = hex("#F4F1E8")
looks.Doordish = {
	badge = { text = "Dd", colour = DOOR, ink = WHITE },
	pieces = {
		block({ 1.8, 2.6, 0.25 }, { 0, 1.3, 0.45 }, DOOR),
		block({ 2.15, 0.2, 0.4 }, { 0, 2.7, 0.45 }, DOOR_FRAME), -- frame
		block({ 0.18, 2.7, 0.4 }, { -1.0, 1.35, 0.45 }, DOOR_FRAME),
		block({ 0.18, 2.7, 0.4 }, { 1.0, 1.35, 0.45 }, DOOR_FRAME),
		block({ 1.2, 0.8, 0.05 }, { 0, 1.85, 0.31 }, DOOR_PANEL), -- panels
		block({ 1.2, 0.8, 0.05 }, { 0, 0.8, 0.31 }, DOOR_PANEL),
		ball(0.22, { 0.62, 1.3, 0.28 }, GOLD), -- knob
		block({ 0.42, 0.26, 0.04 }, { 0, 2.38, 0.3 }, WHITE, {
			text = { text = "12", face = "Front", colour = INK },
		}),
		block({ 1.9, 0.06, 0.95 }, { 0, 0.03, -0.45 }, hex("#B07A4A")), -- doormat
		can(0.06, 1.1, { 0, 0.09, -0.5 }, WHITE), -- plate
		ellipsoid({ 0.9, 0.8, 0.9 }, { 0, 0.12, -0.5 }, SILVER, { material = METAL }), -- the cover
		ball(0.18, { 0, 0.58, -0.5 }, SILVER, { material = METAL }),
		ball(0.32, { -0.25, 0.95, -0.55 }, STEAM, { transparency = 0.45 }), -- steam
		ball(0.24, { -0.1, 1.25, -0.6 }, STEAM, { transparency = 0.55 }),
	},
}

---------------------------------------------------------------------------
-- Unicorn

-- A chunky rocket with Y-shaped fins.
local FIN = hex("#7B4AE2")
local ROCKET_NOSE = hex("#E63946")
looks.SpaceY = {
	badge = { text = "SY", colour = ROCKET_NOSE, ink = WHITE, at = { -1.15, 2.4, 0 } },
	pieces = {
		ellipsoid({ 0.6, 0.85, 0.6 }, { 0, 0.3, 0 }, hex("#FF9F1C"), { material = NEON }), -- flame
		ellipsoid({ 0.35, 0.55, 0.35 }, { 0, 0.35, 0 }, hex("#FFE66D"), { material = NEON }),
		can(0.25, 0.7, { 0, 0.62, 0 }, STEEL),
		can(1.9, 1.0, { 0, 1.7, 0 }, hex("#F4F6FB")),
		ellipsoid({ 1.0, 1.4, 1.0 }, { 0, 2.65, 0 }, ROCKET_NOSE),
		can(0.16, 1.04, { 0, 1.35, 0 }, FIN),
		disc(0.06, 0.56, { 0, 2.05, -0.49 }, SILVER), -- window
		disc(0.08, 0.44, { 0, 2.05, -0.51 }, GLASS),
		wedge({ 0.12, 0.95, 0.7 }, { 0, 1.15, 0.85 }, FIN, { turn = { 0, 180, 0 } }), -- three fins in a Y
		wedge({ 0.12, 0.95, 0.7 }, { 0.736, 1.15, -0.425 }, FIN, { turn = { 0, 300, 0 } }),
		wedge({ 0.12, 0.95, 0.7 }, { -0.736, 1.15, -0.425 }, FIN, { turn = { 0, 60, 0 } }),
	},
}

-- A stripy piggy bank.
local PIG = hex("#FF9EC4")
local PIG_DARK = hex("#F27BAA")
local PIG_STRIPE = hex("#2EC4B6")
looks.Stripey = {
	badge = { text = "St", colour = PIG_STRIPE, ink = WHITE },
	pieces = {
		can(0.4, 0.35, { -0.45, 0.2, -0.55 }, PIG_DARK), -- legs
		can(0.4, 0.35, { 0.45, 0.2, -0.55 }, PIG_DARK),
		can(0.4, 0.35, { -0.45, 0.2, 0.55 }, PIG_DARK),
		can(0.4, 0.35, { 0.45, 0.2, 0.55 }, PIG_DARK),
		ellipsoid({ 1.6, 1.5, 2.2 }, { 0, 1.05, 0 }, PIG),
		ellipsoid({ 1.64, 1.54, 0.3 }, { 0, 1.05, 0.15 }, PIG_STRIPE),
		ellipsoid({ 1.54, 1.44, 0.3 }, { 0, 1.05, -0.4 }, PIG_STRIPE),
		ellipsoid({ 1.3, 1.22, 0.3 }, { 0, 1.05, 0.7 }, PIG_STRIPE),
		disc(0.3, 0.62, { 0, 1.0, -1.15 }, PIG_DARK), -- snout
		ball(0.13, { -0.12, 1.0, -1.3 }, hex("#C2185B")),
		ball(0.13, { 0.12, 1.0, -1.3 }, hex("#C2185B")),
		ball(0.2, { -0.32, 1.38, -0.86 }, INK),
		ball(0.2, { 0.32, 1.38, -0.86 }, INK),
		block({ 0.32, 0.32, 0.1 }, { -0.42, 1.72, -0.55 }, PIG_DARK, { turn = { 0, 0, 45 } }), -- ears
		block({ 0.32, 0.32, 0.1 }, { 0.42, 1.72, -0.55 }, PIG_DARK, { turn = { 0, 0, 45 } }),
		block({ 0.55, 0.06, 0.14 }, { 0, 1.8, 0.1 }, INK), -- coin slot
		disc(0.08, 0.6, { 0, 2.0, 0.1 }, GOLD),
		ball(0.22, { 0, 1.15, 1.12 }, PIG_DARK),
	},
}

-- A dancing alarm clock.
local CLOCK = hex("#FF8C1A")
looks.TikTock = {
	badge = { text = "Tt", colour = CLOCK, ink = WHITE },
	tilt = { 0, 0, -8 },
	pieces = {
		rod(0.62, 0.15, { -0.425, 0.42, 0 }, INK, { turn = { 0, 0, 76 } }), -- legs, mid-dance
		rod(0.6, 0.15, { 0.6, 0.56, 0 }, INK, { turn = { 0, 0, -33 } }),
		ellipsoid({ 0.38, 0.18, 0.48 }, { -0.52, 0.09, -0.05 }, INK),
		ellipsoid({ 0.38, 0.18, 0.48 }, { 0.92, 0.37, -0.05 }, INK, { turn = { 0, 0, -33 } }),
		disc(0.6, 1.8, { 0, 1.55, 0 }, CLOCK),
		disc(0.04, 1.5, { 0, 1.55, -0.31 }, hex("#FFF6E0")),
		block({ 0.08, 0.5, 0.04 }, { 0, 1.77, -0.34 }, INK), -- hands
		block({ 0.45, 0.08, 0.04 }, { 0.2, 1.55, -0.34 }, INK),
		ball(0.14, { 0, 1.55, -0.35 }, INK),
		ball(0.6, { -0.55, 2.42, 0 }, GOLD), -- bells
		ball(0.6, { 0.55, 2.42, 0 }, GOLD),
		block({ 0.1, 0.32, 0.1 }, { 0, 2.6, 0 }, INK),
		rod(0.6, 0.13, { -1.05, 2.08, 0 }, INK, { turn = { 0, 0, 132 } }), -- arms
		rod(0.54, 0.13, { 1.07, 1.1, 0 }, INK, { turn = { 0, 0, -33 } }),
		ball(0.26, { -1.27, 2.32, 0 }, WHITE),
		ball(0.26, { 1.32, 0.94, 0 }, WHITE),
	},
}

-- A hoodie wearing a feathered archer's cap.
local HOODIE = hex("#E2582B")
local CAP = hex("#8B5A2B")
looks.Robinhoodie = {
	badge = { text = "Rh", colour = CAP, ink = CREAM },
	pieces = {
		ellipsoid({ 1.7, 1.5, 1.1 }, { 0, 0.75, 0 }, HOODIE),
		ellipsoid({ 0.9, 0.36, 0.08 }, { 0, 0.5, -0.52 }, hex("#B8441F")), -- pocket
		ball(1.15, { 0, 1.75, 0.05 }, HOODIE), -- hood
		ellipsoid({ 0.74, 0.8, 0.3 }, { 0, 1.72, -0.42 }, DARK),
		ball(0.16, { -0.15, 1.8, -0.57 }, WHITE),
		ball(0.16, { 0.15, 1.8, -0.57 }, WHITE),
		can(0.4, 0.06, { -0.15, 1.15, -0.5 }, WHITE), -- drawstrings
		can(0.4, 0.06, { 0.15, 1.15, -0.5 }, WHITE),
		rod(0.9, 0.42, { -0.8, 0.7, -0.05 }, HOODIE, { turn = { 0, 0, 70 } }), -- sleeves
		rod(0.9, 0.42, { 0.8, 0.7, -0.05 }, HOODIE, { turn = { 0, 0, -70 } }),
		ellipsoid({ 1.05, 0.3, 1.3 }, { 0, 2.3, 0.05 }, CAP), -- the cap
		wedge({ 0.8, 0.4, 0.6 }, { 0, 2.55, -0.25 }, CAP),
		wedge({ 0.8, 0.4, 0.6 }, { 0, 2.55, 0.35 }, CAP, { turn = { 0, 180, 0 } }),
		ellipsoid({ 0.12, 0.9, 0.26 }, { 0.38, 2.85, 0.15 }, WHITE, { turn = { 0, 0, -25 } }), -- feather
	},
}

-- A painter's canvas on an easel with paint splats.
local WOOD = hex("#B07A45")
looks.Canvaas = {
	badge = { text = "Ca", colour = GOLD, ink = INK },
	pieces = {
		block({ 0.12, 2.5, 0.12 }, { -0.62, 1.2, -0.15 }, WOOD, { turn = { 6, 0, -10 } }), -- easel
		block({ 0.12, 2.5, 0.12 }, { 0.62, 1.2, -0.15 }, WOOD, { turn = { 6, 0, 10 } }),
		block({ 0.12, 2.6, 0.12 }, { 0, 1.15, 0.55 }, WOOD, { turn = { -22, 0, 0 } }),
		block({ 1.8, 0.1, 0.32 }, { 0, 0.85, -0.45 }, WOOD),
		block({ 1.6, 1.3, 0.1 }, { 0, 1.6, -0.35 }, hex("#FFFDF7")),
		ellipsoid({ 0.5, 0.42, 0.05 }, { -0.4, 1.85, -0.41 }, hex("#FF4D5E")), -- splats
		ellipsoid({ 0.42, 0.36, 0.05 }, { 0.35, 1.95, -0.41 }, hex("#3D8BFF")),
		ellipsoid({ 0.56, 0.46, 0.05 }, { -0.05, 1.4, -0.41 }, GOLD),
		ellipsoid({ 0.36, 0.3, 0.05 }, { 0.45, 1.3, -0.41 }, hex("#7ED957")),
		block({ 0.06, 0.3, 0.05 }, { -0.4, 1.58, -0.41 }, hex("#FF4D5E")), -- a drip
		ellipsoid({ 0.75, 0.06, 0.55 }, { 0.75, 0.03, -0.95 }, hex("#E3C08D")), -- palette
		rod(0.7, 0.07, { -0.55, 0.94, -0.5 }, hex("#6B4226"), { turn = { 0, 0, 12 } }), -- brush
		ball(0.13, { -0.89, 0.87, -0.5 }, hex("#FF4D5E")),
	},
}

-- A sloth fast asleep in a hammock.
local HAMMOCK = hex("#FF8C69")
local HAMMOCK_STRIPE = hex("#FFF1D6")
local SLOTH = hex("#8B6B4A")
local SLOTH_FACE = hex("#E8D8B8")
local POST = hex("#9C6B3F")
looks.Slackers = {
	badge = { text = "Sl", colour = HAMMOCK, ink = WHITE },
	pieces = {
		block({ 0.2, 2.2, 0.2 }, { -1.45, 1.1, 0 }, POST), -- posts
		block({ 0.2, 2.2, 0.2 }, { 1.45, 1.1, 0 }, POST),
		rod(0.62, 0.06, { -1.2, 1.7, 0 }, HAMMOCK_STRIPE, { turn = { 0, 0, -32 } }), -- ropes
		rod(0.62, 0.06, { 1.2, 1.7, 0 }, HAMMOCK_STRIPE, { turn = { 0, 0, 32 } }),
		ellipsoid({ 2.4, 0.5, 1.0 }, { 0, 1.2, 0 }, HAMMOCK),
		ellipsoid({ 2.0, 0.14, 1.04 }, { 0, 1.12, 0 }, HAMMOCK_STRIPE),
		ellipsoid({ 1.35, 0.55, 0.78 }, { 0.15, 1.52, 0 }, SLOTH), -- body
		ball(0.78, { -0.72, 1.7, -0.08 }, SLOTH), -- head
		ellipsoid({ 0.58, 0.5, 0.2 }, { -0.76, 1.68, -0.38 }, SLOTH_FACE),
		ellipsoid({ 0.2, 0.12, 0.06 }, { -0.9, 1.74, -0.48 }, DARK, { turn = { 0, 0, 20 } }), -- sleepy eyes
		ellipsoid({ 0.2, 0.12, 0.06 }, { -0.62, 1.74, -0.48 }, DARK, { turn = { 0, 0, -20 } }),
		block({ 0.18, 0.04, 0.04 }, { -0.76, 1.56, -0.5 }, INK), -- smile
		ellipsoid({ 0.2, 0.62, 0.2 }, { 0.35, 1.1, -0.42 }, SLOTH, { turn = { 0, 0, 8 } }), -- an arm hanging out
		block({ 0.55, 0.4, 0.05 }, { -0.35, 2.5, -0.2 }, WHITE, {
			turn = { 0, 0, 8 },
			text = { text = "Zzz", face = "Front", colour = DARK },
		}),
	},
}

---------------------------------------------------------------------------
-- Decacorn

-- A mango with a blocky face and a pixel pickaxe.
local MANGO = hex("#FFB830")
local MANGO_BLUSH = hex("#FF8A3D")
local PICK = hex("#4FD1C5")
local PICK_HANDLE = hex("#8A5A36")
looks.Mojango = {
	badge = { text = "Mj", colour = MANGO, ink = INK },
	pieces = {
		ellipsoid({ 1.6, 2.0, 1.4 }, { -0.1, 1.0, 0 }, MANGO, { turn = { 0, 0, -10 } }),
		ellipsoid({ 0.8, 0.95, 0.5 }, { 0.3, 1.35, -0.48 }, MANGO_BLUSH, { turn = { 0, 0, -10 } }),
		rod(0.35, 0.12, { -0.25, 2.05, 0 }, PICK_HANDLE, { turn = { 0, 0, 80 } }), -- stem
		ellipsoid({ 0.6, 0.08, 0.3 }, { 0.05, 2.15, 0 }, hex("#4CAF50"), { turn = { 0, 0, 20 } }), -- leaf
		block({ 0.2, 0.2, 0.05 }, { -0.42, 1.2, -0.7 }, INK), -- blocky face
		block({ 0.2, 0.2, 0.05 }, { 0.12, 1.2, -0.72 }, INK),
		block({ 0.45, 0.1, 0.05 }, { -0.15, 0.85, -0.7 }, INK),
		rod(1.8, 0.14, { 0.95, 1.2, -0.45 }, PICK_HANDLE, { turn = { 0, 0, 62 } }), -- pickaxe
		block({ 1.1, 0.22, 0.22 }, { 1.38, 2.0, -0.45 }, PICK, { turn = { 0, 0, -28 } }),
		block({ 0.22, 0.22, 0.22 }, { 0.92, 1.95, -0.45 }, PICK),
		block({ 0.22, 0.22, 0.22 }, { 1.82, 1.72, -0.45 }, PICK),
	},
}

-- A garden gnome playing on a game controller.
local GNOME_HAT = hex("#E63946")
local GNOME_COAT = hex("#3D7BFF")
local SKIN = hex("#F1C27D")
looks.EpicGnomes = {
	badge = { text = "Eg", colour = GNOME_HAT, ink = WHITE },
	pieces = {
		can(1.0, 1.1, { 0, 0.5, 0 }, GNOME_COAT), -- body
		can(0.15, 1.14, { 0, 0.75, 0 }, INK), -- belt
		block({ 0.26, 0.18, 0.05 }, { 0, 0.75, -0.58 }, GOLD),
		ball(0.85, { 0, 1.38, 0 }, SKIN), -- head
		ellipsoid({ 0.9, 0.85, 0.5 }, { 0, 1.08, -0.3 }, WHITE), -- beard
		ball(0.28, { 0, 1.4, -0.43 }, hex("#F4A582")), -- nose
		ball(0.12, { -0.18, 1.55, -0.36 }, INK), -- eyes
		ball(0.12, { 0.18, 1.55, -0.36 }, INK),
		ellipsoid({ 0.95, 1.5, 0.95 }, { 0, 2.25, 0.05 }, GNOME_HAT, { turn = { -12, 0, 0 } }), -- hat
		block({ 0.9, 0.18, 0.42 }, { 0, 0.95, -0.78 }, DARK), -- controller
		ellipsoid({ 0.32, 0.22, 0.45 }, { -0.45, 0.9, -0.74 }, DARK),
		ellipsoid({ 0.32, 0.22, 0.45 }, { 0.45, 0.9, -0.74 }, DARK),
		ball(0.12, { 0.22, 1.06, -0.86 }, hex("#FF4D5E")), -- buttons
		ball(0.12, { 0.36, 1.06, -0.76 }, hex("#3CCB5A")),
		block({ 0.2, 0.05, 0.06 }, { -0.28, 1.06, -0.82 }, SILVER), -- d-pad
		block({ 0.06, 0.05, 0.2 }, { -0.28, 1.06, -0.82 }, SILVER),
		ball(0.26, { -0.5, 0.98, -0.62 }, SKIN), -- hands
		ball(0.26, { 0.5, 0.98, -0.62 }, SKIN),
	},
}

-- A dancing cookie with a bite out of it.
local COOKIE = hex("#D9A066")
local COOKIE_EDGE = hex("#C4874E")
local CHIP = hex("#5C3B24")
local DANCE_SHOE = hex("#FF5FB0")
looks.Bitedance = {
	badge = { text = "Bd", colour = COOKIE, ink = CHIP },
	pieces = {
		disc(0.3, 1.8, { -0.1, 1.55, 0 }, COOKIE), -- two rounds make it lumpy, bitten at the top right
		disc(0.3, 1.25, { 0.3, 1.1, 0.02 }, COOKIE),
		disc(0.32, 0.5, { 0.62, 2.05, 0 }, COOKIE_EDGE), -- the bitten edge
		ball(0.14, { 0.95, 2.4, -0.1 }, COOKIE), -- crumbs
		ball(0.1, { 1.1, 2.2, -0.05 }, COOKIE),
		ball(0.18, { -0.55, 1.85, -0.17 }, CHIP), -- chips
		ball(0.15, { 0.35, 0.9, -0.18 }, CHIP),
		ball(0.16, { -0.6, 1.15, -0.17 }, CHIP),
		ball(0.32, { -0.3, 1.7, -0.18 }, WHITE), -- eyes
		ball(0.32, { 0.12, 1.7, -0.18 }, WHITE),
		ball(0.15, { -0.3, 1.7, -0.32 }, INK),
		ball(0.15, { 0.12, 1.7, -0.32 }, INK),
		ellipsoid({ 0.45, 0.2, 0.08 }, { -0.1, 1.35, -0.18 }, CHIP), -- smile
		rod(0.8, 0.12, { -0.35, 0.42, 0 }, INK, { turn = { 0, 0, 70 } }), -- legs
		rod(0.8, 0.12, { 0.4, 0.42, 0 }, INK, { turn = { 0, 0, 115 } }),
		ellipsoid({ 0.36, 0.18, 0.45 }, { -0.5, 0.09, -0.1 }, DANCE_SHOE),
		ellipsoid({ 0.36, 0.18, 0.45 }, { 0.58, 0.09, -0.1 }, DANCE_SHOE),
		rod(0.8, 0.1, { -1.2, 1.75, 0 }, INK, { turn = { 0, 0, -40 } }), -- arms up
		rod(0.8, 0.1, { 1.1, 1.95, 0 }, INK, { turn = { 0, 0, 45 } }),
		ball(0.26, { 1.3, 2.65, -0.15 }, hex("#7B4AE2")), -- a music note
		block({ 0.06, 0.5, 0.06 }, { 1.42, 2.88, -0.15 }, hex("#7B4AE2")),
	},
}

-- A snowman in a fake glasses-and-moustache disguise.
local SNOW = hex("#F7FBFF")
local SCARF = hex("#FF8C42")
local DISGUISE = hex("#2B2D42")
looks.Snowfake = {
	badge = { text = "Sw", colour = hex("#E8F0FF"), ink = DISGUISE },
	pieces = {
		ball(1.5, { 0, 0.72, 0 }, SNOW),
		ball(1.1, { 0, 1.62, 0 }, SNOW),
		ball(0.85, { 0, 2.27, 0 }, SNOW),
		can(0.2, 0.92, { 0, 1.98, 0 }, SCARF), -- scarf
		block({ 0.22, 0.6, 0.08 }, { 0.3, 1.7, -0.5 }, SCARF, { turn = { 0, 0, -10 } }),
		ball(0.14, { 0, 1.72, -0.54 }, INK), -- buttons
		ball(0.14, { 0, 1.45, -0.52 }, INK),
		disc(0.06, 0.3, { -0.17, 2.36, -0.41 }, DISGUISE), -- the disguise
		disc(0.06, 0.3, { 0.17, 2.36, -0.41 }, DISGUISE),
		block({ 0.12, 0.05, 0.05 }, { 0, 2.38, -0.43 }, DISGUISE),
		ball(0.24, { 0, 2.24, -0.45 }, hex("#FF9BB3")), -- fake nose
		ellipsoid({ 0.52, 0.13, 0.13 }, { 0, 2.1, -0.42 }, hex("#5C3B24")), -- fake moustache
		can(0.08, 0.95, { 0, 2.66, 0 }, DISGUISE), -- hat
		can(0.45, 0.62, { 0, 2.9, 0 }, DISGUISE),
		rod(0.9, 0.08, { -0.95, 1.8, 0 }, hex("#6B4226"), { turn = { 0, 0, -25 } }), -- twig arms
		rod(0.9, 0.08, { 0.95, 1.8, 0 }, hex("#6B4226"), { turn = { 0, 0, 25 } }),
	},
}

-- A bucket full to the brim with coins.
local PAIL = hex("#E63946")
local PAIL_RIM = hex("#C92A3A")
local PAIL_COIN = hex("#E0A93B")
looks.PayPail = {
	badge = { text = "PP", colour = PAIL, ink = WHITE },
	pieces = {
		can(1.4, 1.5, { 0, 0.7, 0 }, PAIL),
		can(0.12, 1.62, { 0, 1.38, 0 }, PAIL_RIM),
		block({ 0.6, 0.42, 0.04 }, { 0, 0.72, -0.76 }, CREAM, {
			text = { text = "$", face = "Front", colour = PAIL },
		}),
		ellipsoid({ 1.35, 0.55, 1.35 }, { 0, 1.45, 0 }, GOLD), -- coins
		disc(0.08, 0.45, { 0.3, 1.78, -0.25 }, GOLD, { turn = { 35, 20, 0 } }),
		disc(0.08, 0.45, { -0.35, 1.72, 0.1 }, PAIL_COIN, { turn = { -30, 0, 20 } }),
		rod(0.72, 0.08, { -0.8, 1.75, 0 }, SILVER, { turn = { 0, 0, 80 } }), -- handle
		rod(0.72, 0.08, { 0.8, 1.75, 0 }, SILVER, { turn = { 0, 0, 100 } }),
		rod(1.5, 0.08, { 0, 2.1, 0 }, SILVER),
		can(0.08, 0.5, { -1.1, 0.04, -0.8 }, GOLD), -- spilled coins
		can(0.08, 0.45, { 1.0, 0.04, -0.95 }, PAIL_COIN),
		disc(0.08, 0.5, { 1.15, 0.25, -0.45 }, GOLD, { turn = { 0, 30, 0 } }),
	},
}

-- A donkey braying with a "SOLD!" tag.
local DONKEY = hex("#9E9AA8")
local DONKEY_DARK = hex("#6E6A78")
local MUZZLE = hex("#EDE3D3")
looks.eBray = {
	badge = { text = "eB", colour = DONKEY, ink = WHITE },
	pieces = {
		can(0.7, 0.25, { -0.3, 0.35, -0.45 }, DONKEY_DARK), -- legs
		can(0.7, 0.25, { 0.3, 0.35, -0.45 }, DONKEY_DARK),
		can(0.7, 0.25, { -0.3, 0.35, 0.55 }, DONKEY_DARK),
		can(0.7, 0.25, { 0.3, 0.35, 0.55 }, DONKEY_DARK),
		ellipsoid({ 1.0, 0.95, 1.7 }, { 0, 1.05, 0.05 }, DONKEY), -- body
		ellipsoid({ 0.65, 0.75, 0.9 }, { 0, 1.75, -0.78 }, DONKEY, { turn = { -30, 0, 0 } }), -- head, up to bray
		ellipsoid({ 0.55, 0.45, 0.5 }, { 0, 1.98, -1.15 }, MUZZLE),
		ellipsoid({ 0.36, 0.13, 0.2 }, { 0, 1.88, -1.38 }, INK), -- open mouth
		ball(0.14, { -0.2, 2.12, -0.88 }, INK), -- eyes
		ball(0.14, { 0.2, 2.12, -0.88 }, INK),
		ellipsoid({ 0.18, 0.62, 0.12 }, { -0.2, 2.42, -0.6 }, DONKEY, { turn = { -10, 0, 15 } }), -- ears
		ellipsoid({ 0.18, 0.62, 0.12 }, { 0.2, 2.42, -0.6 }, DONKEY, { turn = { -10, 0, -15 } }),
		block({ 0.12, 0.3, 0.7 }, { 0, 1.8, -0.22 }, DARK), -- mane
		block({ 0.08, 0.5, 0.08 }, { 0, 1.15, 0.95 }, DARK, { turn = { 30, 0, 0 } }), -- tail
		block({ 0.85, 0.4, 0.05 }, { 0.85, 2.55, -0.6 }, WHITE, {
			turn = { 0, 0, -10 },
			text = { text = "SOLD!", face = "Front", colour = hex("#7B4AE2") },
		}),
	},
}

---------------------------------------------------------------------------
-- Blue Chip

-- A glossy cartoon pear with one leaf, no bite.
local PEAR = hex("#9BCB3C")
looks.Pear = {
	badge = { text = "Pr", colour = PEAR, ink = INK },
	pieces = {
		ball(1.8, { 0, 0.9, 0 }, PEAR, { reflectance = 0.08 }),
		ball(1.35, { 0, 1.75, 0 }, PEAR, { reflectance = 0.08 }),
		ball(0.95, { 0, 2.35, 0 }, PEAR, { reflectance = 0.08 }),
		rod(0.5, 0.12, { 0.05, 2.95, 0 }, hex("#6B4226"), { turn = { 0, 0, 80 } }), -- stem
		ellipsoid({ 0.6, 0.06, 0.32 }, { 0.38, 3.02, 0 }, hex("#4CAF50"), { turn = { 0, 0, 25 } }), -- leaf
		ellipsoid({ 0.26, 0.48, 0.08 }, { -0.43, 1.1, -0.76 }, WHITE, { turn = { 0, -30, 0 }, transparency = 0.35 }),
	},
}

-- A giant hard hat.
local HAT = GOLD
local HAT_DARK = hex("#E8B23A")
looks.Macrohard = {
	badge = { text = "Mh", colour = HAT, ink = INK },
	pieces = {
		can(0.14, 3.2, { 0, 0.07, 0 }, HAT_DARK), -- brim
		ellipsoid({ 1.5, 0.14, 0.9 }, { 0, 0.1, -1.55 }, HAT_DARK), -- peak
		ellipsoid({ 2.6, 0.3, 2.8 }, { 0, 0.85, 0 }, hex("#E8ECF2")), -- band
		ellipsoid({ 2.6, 2.2, 2.8 }, { 0, 0.5, 0 }, HAT),
		ellipsoid({ 0.4, 2.36, 2.94 }, { 0, 0.5, 0 }, hex("#FFD966")), -- ridge
		disc(0.22, 0.62, { 0, 1.05, -1.32 }, hex("#5B6178")), -- lamp
		disc(0.08, 0.46, { 0, 1.05, -1.44 }, hex("#FFF5B8"), { material = NEON }),
	},
}

-- A cardboard parcel bursting open with a ta-da sparkle.
local CARDBOARD = hex("#C69C6D")
local FLAP = hex("#B5895A")
local SPARKLE = hex("#FFE66D")
looks.Amazin = {
	badge = { text = "Az", colour = CARDBOARD, ink = INK },
	pieces = {
		block({ 2.0, 1.5, 2.0 }, { 0, 0.75, 0 }, CARDBOARD),
		block({ 0.36, 1.5, 0.04 }, { 0, 0.75, -1.01 }, hex("#E3C08D")), -- tape
		block({ 1.86, 0.02, 1.86 }, { 0, 1.51, 0 }, hex("#5C4033")), -- the open top
		block({ 2.0, 0.05, 0.9 }, { 0, 1.76, -1.37 }, FLAP, { turn = { 35, 0, 0 } }), -- flaps
		block({ 2.0, 0.05, 0.9 }, { 0, 1.76, 1.37 }, FLAP, { turn = { -35, 0, 0 } }),
		block({ 0.9, 0.05, 2.0 }, { -1.37, 1.76, 0 }, FLAP, { turn = { 0, 0, -35 } }),
		block({ 0.9, 0.05, 2.0 }, { 1.37, 1.76, 0 }, FLAP, { turn = { 0, 0, 35 } }),
		ball(0.7, { 0, 1.7, 0 }, hex("#FFF5B8"), { material = NEON, transparency = 0.15 }),
		block({ 0.1, 0.8, 0.1 }, { 0, 2.55, 0 }, SPARKLE, { material = NEON }), -- sparkles
		block({ 0.8, 0.1, 0.1 }, { 0, 2.55, 0 }, SPARKLE, { material = NEON }),
		block({ 0.08, 0.5, 0.08 }, { -0.7, 2.15, -0.3 }, SPARKLE, { material = NEON, turn = { 0, 0, 45 } }),
		block({ 0.5, 0.08, 0.08 }, { -0.7, 2.15, -0.3 }, SPARKLE, { material = NEON, turn = { 0, 0, 45 } }),
		block({ 0.08, 0.55, 0.08 }, { 0.72, 2.3, 0.15 }, SPARKLE, { material = NEON }),
		block({ 0.55, 0.08, 0.08 }, { 0.72, 2.3, 0.15 }, SPARKLE, { material = NEON }),
	},
}

-- A giant pair of swimming goggles.
local GOGGLE_FRAME = hex("#FF8C42")
local STRAP = hex("#7B4AE2")
local LENS = hex("#9AD8FF")
local BUBBLE = hex("#CFEFFF")
looks.Goggle = {
	badge = { text = "Gg", colour = STRAP, ink = WHITE },
	pieces = {
		disc(0.35, 1.3, { -0.72, 0.7, 0 }, GOGGLE_FRAME),
		disc(0.35, 1.3, { 0.72, 0.7, 0 }, GOGGLE_FRAME),
		disc(0.37, 1.04, { -0.72, 0.7, 0 }, LENS, { material = GLASS_MATERIAL, transparency = 0.35 }),
		disc(0.37, 1.04, { 0.72, 0.7, 0 }, LENS, { material = GLASS_MATERIAL, transparency = 0.35 }),
		block({ 0.36, 0.16, 0.2 }, { 0, 0.78, 0 }, GOGGLE_FRAME), -- bridge
		block({ 0.15, 0.32, 1.1 }, { -1.38, 0.7, 0.6 }, STRAP),
		block({ 0.15, 0.32, 1.1 }, { 1.38, 0.7, 0.6 }, STRAP),
		block({ 2.9, 0.32, 0.15 }, { 0, 0.7, 1.12 }, STRAP),
		ellipsoid({ 0.16, 0.32, 0.05 }, { -0.95, 0.95, -0.2 }, WHITE, { transparency = 0.2, turn = { 0, 0, -30 } }),
		ellipsoid({ 0.16, 0.32, 0.05 }, { 0.49, 0.95, -0.2 }, WHITE, { transparency = 0.2, turn = { 0, 0, -30 } }),
		ball(0.3, { 1.0, 1.75, -0.2 }, BUBBLE, { material = GLASS_MATERIAL, transparency = 0.4 }),
		ball(0.2, { 1.2, 2.1, -0.15 }, BUBBLE, { material = GLASS_MATERIAL, transparency = 0.4 }),
		ball(0.14, { 0.95, 2.35, -0.1 }, BUBBLE, { material = GLASS_MATERIAL, transparency = 0.4 }),
	},
}

-- A chocolate drink bottle in brown and cream with a melting drip.
local CHOC = hex("#6F3B1E")
local CHOC_DARK = hex("#4A2511")
local CHOC_CREAM = hex("#F3E5C8")
looks.ChocaCola = {
	badge = { text = "CC", colour = CHOC_CREAM, ink = CHOC },
	pieces = {
		ellipsoid({ 1.1, 0.07, 0.75 }, { 0.35, 0.02, -0.65 }, CHOC_DARK), -- puddle
		can(1.6, 1.2, { 0, 0.8, 0 }, CHOC),
		can(0.6, 1.24, { 0, 0.9, 0 }, CHOC_CREAM),
		ellipsoid({ 1.2, 0.9, 1.2 }, { 0, 1.6, 0 }, CHOC), -- shoulder
		can(0.85, 0.5, { 0, 2.2, 0 }, CHOC), -- neck
		can(0.16, 0.56, { 0, 2.42, 0 }, CHOC_CREAM),
		can(0.22, 0.62, { 0, 2.72, 0 }, GOLD), -- cap
		ellipsoid({ 0.32, 0.7, 0.14 }, { 0.25, 1.3, -0.58 }, CHOC_DARK), -- drips
		ball(0.26, { 0.25, 0.95, -0.6 }, CHOC_DARK),
		ellipsoid({ 0.24, 0.45, 0.12 }, { -0.3, 1.45, -0.55 }, CHOC_DARK),
	},
}

-- A takeaway coffee cup with a shining gold star on the lid.
local CUP = hex("#F7F3EC")
local SLEEVE = hex("#A9774F")
local LID = hex("#5C3B24")
looks.Starbux = {
	badge = { text = "Sb", colour = SLEEVE, ink = CREAM },
	pieces = {
		can(1.8, 1.2, { 0, 0.9, 0 }, CUP),
		can(0.7, 1.25, { 0, 0.95, 0 }, SLEEVE),
		block({ 0.5, 0.42, 0.05 }, { 0, 0.95, -0.64 }, CREAM, {
			text = { text = "$", face = "Front", colour = LID },
		}),
		can(0.2, 1.32, { 0, 1.9, 0 }, LID),
		can(0.14, 1.0, { 0, 2.07, 0 }, LID),
		ball(0.32, { 0, 2.65, 0 }, GOLD, { material = METAL }), -- the star
		block({ 0.16, 1.1, 0.12 }, { 0, 2.65, 0 }, GOLD, { material = METAL }),
		block({ 1.1, 0.16, 0.12 }, { 0, 2.65, 0 }, GOLD, { material = METAL }),
		block({ 0.12, 0.7, 0.12 }, { 0, 2.65, 0 }, GOLD, { material = METAL, turn = { 0, 0, 45 } }),
		block({ 0.7, 0.12, 0.12 }, { 0, 2.65, 0 }, GOLD, { material = METAL, turn = { 0, 0, 45 } }),
		ball(0.3, { -0.45, 2.45, 0.1 }, STEAM, { transparency = 0.45 }), -- steam
		ball(0.22, { -0.55, 2.8, 0.15 }, STEAM, { transparency = 0.55 }),
	},
}

---------------------------------------------------------------------------
-- Mega Cap

-- A smiling sun wearing big headphones.
local SUN = hex("#FFB020")
local SUN_RAY = hex("#FFD36B")
local PHONES = hex("#2B2D42")
local CUSHION = hex("#5B6178")
looks.Sunny = {
	badge = { text = "Sn", colour = SUN, ink = INK },
	pieces = {
		ball(1.9, { 0, 1.55, 0 }, SUN),
		block({ 0.24, 0.55, 0.24 }, { 0, 2.82, 0 }, SUN_RAY), -- rays
		block({ 0.24, 0.55, 0.24 }, { -0.95, 2.48, 0 }, SUN_RAY, { turn = { 0, 0, 45 } }),
		block({ 0.24, 0.55, 0.24 }, { 0.95, 2.48, 0 }, SUN_RAY, { turn = { 0, 0, -45 } }),
		block({ 0.24, 0.55, 0.24 }, { -0.95, 0.62, 0 }, SUN_RAY, { turn = { 0, 0, -45 } }),
		block({ 0.24, 0.55, 0.24 }, { 0.95, 0.62, 0 }, SUN_RAY, { turn = { 0, 0, 45 } }),
		block({ 0.24, 0.55, 0.24 }, { 0, 0.28, -0.6 }, SUN_RAY, { turn = { 60, 0, 0 } }),
		ball(0.22, { -0.35, 1.7, -0.86 }, INK), -- eyes
		ball(0.22, { 0.35, 1.7, -0.86 }, INK),
		ellipsoid({ 0.65, 0.22, 0.12 }, { 0, 1.25, -0.88 }, INK), -- smile
		rod(0.42, 0.78, { -1.0, 1.55, 0 }, PHONES), -- headphones
		rod(0.42, 0.78, { 1.0, 1.55, 0 }, PHONES),
		rod(0.12, 0.62, { -0.82, 1.55, 0 }, CUSHION),
		rod(0.12, 0.62, { 0.82, 1.55, 0 }, CUSHION),
		rod(1.0, 0.14, { 0, 2.55, 0 }, PHONES),
		rod(0.72, 0.14, { -0.82, 2.2, 0 }, PHONES, { turn = { 0, 0, -60 } }),
		rod(0.72, 0.14, { 0.82, 2.2, 0 }, PHONES, { turn = { 0, 0, 60 } }),
	},
}

-- A toy building brick running on its own two legs.
local BRICK = hex("#2FBFA8")
local SHOE = hex("#FF8C42")
looks.Leggo = {
	badge = { text = "Lg", colour = BRICK, ink = WHITE },
	pieces = {
		block({ 2.0, 1.1, 1.0 }, { 0, 1.4, 0 }, BRICK),
		can(0.25, 0.4, { -0.5, 2.07, -0.25 }, BRICK), -- studs
		can(0.25, 0.4, { 0.5, 2.07, -0.25 }, BRICK),
		can(0.25, 0.4, { -0.5, 2.07, 0.25 }, BRICK),
		can(0.25, 0.4, { 0.5, 2.07, 0.25 }, BRICK),
		ball(0.34, { -0.4, 1.5, -0.52 }, WHITE), -- eyes
		ball(0.34, { 0.4, 1.5, -0.52 }, WHITE),
		ball(0.16, { -0.4, 1.5, -0.68 }, INK),
		ball(0.16, { 0.4, 1.5, -0.68 }, INK),
		block({ 0.5, 0.07, 0.05 }, { 0, 1.18, -0.52 }, INK), -- smile
		block({ 0.26, 0.85, 0.26 }, { -0.45, 0.48, 0.1 }, DARK, { turn = { 22, 0, 0 } }), -- legs mid-stride
		block({ 0.26, 0.85, 0.26 }, { 0.45, 0.48, -0.05 }, DARK, { turn = { -22, 0, 0 } }),
		block({ 0.36, 0.2, 0.55 }, { -0.45, 0.1, 0.3 }, SHOE),
		block({ 0.36, 0.2, 0.55 }, { 0.45, 0.1, -0.28 }, SHOE),
		rod(0.7, 0.13, { -1.25, 1.45, 0 }, DARK, { turn = { 0, 0, 30 } }), -- arms
		rod(0.7, 0.13, { 1.25, 1.45, 0 }, DARK, { turn = { 0, 0, -30 } }),
	},
}

-- A stack of three iced donuts with sprinkles and a cherry on top.
local DOUGH = hex("#E3B27A")
local ICING_PINK = hex("#FF8FC8")
local ICING_CHOC = hex("#6F3B1E")
local ICING_MINT = hex("#7FE0C2")
local HOLE = hex("#7A4A2A")
looks.McDonuts = {
	badge = { text = "Md", colour = ICING_PINK, ink = DARK },
	pieces = {
		can(0.5, 1.9, { 0, 0.25, 0 }, DOUGH), -- bottom donut
		can(0.12, 1.92, { 0, 0.5, 0 }, ICING_CHOC),
		can(0.5, 1.75, { 0.08, 0.85, 0.05 }, DOUGH), -- middle
		can(0.12, 1.77, { 0.08, 1.1, 0.05 }, ICING_MINT),
		can(0.5, 1.6, { -0.05, 1.45, -0.03 }, DOUGH), -- top
		can(0.12, 1.62, { -0.05, 1.7, -0.03 }, ICING_PINK),
		can(0.04, 0.5, { -0.05, 1.77, -0.03 }, HOLE), -- the hole
		block({ 0.2, 0.05, 0.05 }, { -0.5, 1.78, -0.35 }, hex("#3D8BFF"), { turn = { 0, 30, 0 } }), -- sprinkles
		block({ 0.2, 0.05, 0.05 }, { 0.45, 1.78, -0.3 }, hex("#FFE66D"), { turn = { 0, -40, 0 } }),
		block({ 0.2, 0.05, 0.05 }, { 0.3, 1.78, 0.4 }, WHITE, { turn = { 0, 70, 0 } }),
		block({ 0.2, 0.05, 0.05 }, { -0.4, 1.78, 0.35 }, hex("#3CCB5A"), { turn = { 0, -10, 0 } }),
		ball(0.42, { -0.05, 2.0, -0.03 }, hex("#C2185B")), -- cherry
		rod(0.4, 0.05, { 0.05, 2.32, -0.03 }, hex("#4CAF50"), { turn = { 0, 0, 70 } }),
	},
}

-- A sleek slug with a windscreen and wheels, plugged in to charge.
local SLUG = hex("#8BD450")
local SLUG_GLASS = hex("#3A4A66")
local CABLE = hex("#3A3D4D")
local BOLT = hex("#FFE66D")
looks.Teslug = {
	badge = { text = "Ts", colour = SLUG, ink = INK },
	pieces = {
		ellipsoid({ 1.3, 0.8, 2.8 }, { 0, 0.55, 0.1 }, SLUG, { reflectance = 0.1 }),
		ball(0.95, { 0, 0.85, -0.95 }, SLUG, { reflectance = 0.1 }),
		ellipsoid({ 0.95, 0.5, 0.9 }, { 0, 1.08, -0.3 }, SLUG_GLASS, { reflectance = 0.3 }), -- windscreen
		rod(0.6, 0.08, { -0.22, 1.5, -1.15 }, SLUG, { turn = { 0, 0, 70 } }), -- eye stalks
		rod(0.6, 0.08, { 0.22, 1.5, -1.15 }, SLUG, { turn = { 0, 0, 110 } }),
		ball(0.24, { -0.32, 1.8, -1.15 }, WHITE),
		ball(0.24, { 0.32, 1.8, -1.15 }, WHITE),
		ball(0.11, { -0.32, 1.82, -1.27 }, INK),
		ball(0.11, { 0.32, 1.82, -1.27 }, INK),
		rod(0.2, 0.42, { -0.62, 0.21, -0.75 }, TYRE), -- wheels
		rod(0.2, 0.42, { 0.62, 0.21, -0.75 }, TYRE),
		rod(0.2, 0.42, { -0.62, 0.21, 0.85 }, TYRE),
		rod(0.2, 0.42, { 0.62, 0.21, 0.85 }, TYRE),
		block({ 0.1, 0.42, 0.05 }, { -0.66, 0.7, 0.2 }, BOLT, { material = NEON, turn = { 0, 90, 25 } }), -- bolt
		block({ 0.1, 0.42, 0.05 }, { -0.66, 0.5, 0.35 }, BOLT, { material = NEON, turn = { 0, 90, -25 } }),
		rod(0.95, 0.1, { 0.4, 0.06, 1.45 }, CABLE, { turn = { 0, 20, 0 } }), -- the charging cable
		block({ 0.32, 0.2, 0.22 }, { 0.95, 0.1, 1.28 }, CABLE),
	},
}

-- A ball of bread dough kneaded into a handheld game, with a rolling pin.
local BREAD_DOUGH = hex("#F2D8A7")
local BOARD = hex("#D9B07A")
local PIN = hex("#B07A4A")
looks.Nintendough = {
	badge = { text = "Nd", colour = BREAD_DOUGH, ink = INK },
	pieces = {
		block({ 2.6, 0.15, 1.8 }, { 0, 0.075, 0 }, BOARD), -- board
		ellipsoid({ 1.2, 0.05, 0.8 }, { 0.6, 0.17, 0.45 }, WHITE, { transparency = 0.2 }), -- flour
		ellipsoid({ 2.1, 1.25, 0.72 }, { 0, 1.0, 0.1 }, BREAD_DOUGH),
		block({ 0.9, 0.62, 0.05 }, { 0, 1.05, -0.24 }, DARK, {
			text = { text = ":)", face = "Front", colour = hex("#9BF6A3") },
		}),
		block({ 0.3, 0.09, 0.05 }, { -0.72, 1.0, -0.2 }, INK), -- d-pad
		block({ 0.09, 0.3, 0.05 }, { -0.72, 1.0, -0.2 }, INK),
		ball(0.15, { 0.66, 1.08, -0.2 }, hex("#3D8BFF")), -- buttons
		ball(0.15, { 0.82, 0.94, -0.18 }, hex("#3CCB5A")),
		rod(1.6, 0.3, { 0.4, 0.32, -0.62 }, PIN, { turn = { 0, 20, 0 } }), -- rolling pin
		rod(0.35, 0.13, { 1.3, 0.32, -0.95 }, hex("#8A5A36"), { turn = { 0, 20, 0 } }),
		rod(0.35, 0.13, { -0.5, 0.32, -0.3 }, hex("#8A5A36"), { turn = { 0, 20, 0 } }),
	},
}

-- A shiny brass tuba playing music notes.
local BRASS = hex("#E0B84A")
local BRASS_DARK = hex("#B88A2A")
local TUBA_NOTE = hex("#7B4AE2")
looks.YouTuba = {
	badge = { text = "Yt", colour = BRASS, ink = hex("#5C3B10") },
	pieces = {
		ellipsoid({ 1.1, 0.65, 0.95 }, { 0, 0.42, 0 }, BRASS, { material = METAL, reflectance = 0.15 }), -- the bow
		can(1.7, 0.9, { 0, 1.3, 0 }, BRASS, { material = METAL, reflectance = 0.15 }),
		can(0.35, 1.25, { 0.12, 2.2, 0 }, BRASS, { material = METAL, reflectance = 0.15 }), -- bell
		can(0.25, 1.75, { 0.15, 2.45, 0 }, BRASS, { material = METAL, reflectance = 0.15 }),
		can(0.05, 1.45, { 0.15, 2.58, 0 }, hex("#5C3B10")),
		can(0.55, 0.16, { -0.2, 1.55, -0.48 }, SILVER, { material = METAL }), -- valves
		can(0.55, 0.16, { 0, 1.55, -0.5 }, SILVER, { material = METAL }),
		can(0.55, 0.16, { 0.2, 1.55, -0.48 }, SILVER, { material = METAL }),
		ball(0.2, { -0.2, 1.88, -0.48 }, BRASS_DARK),
		ball(0.2, { 0, 1.88, -0.5 }, BRASS_DARK),
		ball(0.2, { 0.2, 1.88, -0.48 }, BRASS_DARK),
		rod(1.0, 0.14, { -0.75, 1.05, -0.2 }, BRASS, { material = METAL, turn = { 0, 0, -30 } }), -- mouthpiece
		ball(0.22, { -1.2, 1.3, -0.2 }, SILVER, { material = METAL }),
		ball(0.26, { 1.25, 2.75, -0.2 }, TUBA_NOTE), -- notes
		block({ 0.06, 0.5, 0.06 }, { 1.37, 2.98, -0.2 }, TUBA_NOTE),
		ball(0.22, { -0.85, 2.45, -0.1 }, TUBA_NOTE),
		block({ 0.06, 0.42, 0.06 }, { -0.75, 2.65, -0.1 }, TUBA_NOTE),
	},
}

---------------------------------------------------------------------------
-- Conglomerate

-- A smartphone singing with music notes.
local PHONE = DARK
local NOTE = hex("#FFD95A")
looks.Samsong = {
	badge = { text = "Sg", colour = PHONE, ink = NOTE },
	pieces = {
		block({ 1.4, 2.6, 0.25 }, { 0, 1.4, 0 }, PHONE),
		block({ 0.4, 1.0, 0.08 }, { 0, 0.55, 0.42 }, PHONE, { turn = { -30, 0, 0 } }), -- kickstand
		block({ 1.22, 2.3, 0.04 }, { 0, 1.42, -0.135 }, hex("#E8F4FF")), -- screen
		ellipsoid({ 0.2, 0.32, 0.04 }, { -0.28, 1.95, -0.16 }, INK),
		ellipsoid({ 0.2, 0.32, 0.04 }, { 0.28, 1.95, -0.16 }, INK),
		ellipsoid({ 0.48, 0.55, 0.04 }, { 0, 1.25, -0.16 }, hex("#7A1F3D")), -- singing mouth
		ellipsoid({ 0.3, 0.16, 0.03 }, { 0, 1.12, -0.17 }, hex("#FF8FA3")),
		ellipsoid({ 0.24, 0.15, 0.03 }, { -0.42, 1.55, -0.16 }, hex("#FFB3C6")),
		ellipsoid({ 0.24, 0.15, 0.03 }, { 0.42, 1.55, -0.16 }, hex("#FFB3C6")),
		ball(0.12, { 0, 2.63, -0.13 }, INK), -- camera
		ellipsoid({ 0.32, 0.24, 0.12 }, { 0.98, 2.35, -0.1 }, NOTE, { turn = { 0, 0, 20 } }), -- notes
		block({ 0.06, 0.5, 0.06 }, { 1.12, 2.6, -0.1 }, NOTE),
		ellipsoid({ 0.28, 0.22, 0.12 }, { 1.3, 1.75, -0.1 }, NOTE, { turn = { 0, 0, 20 } }),
		block({ 0.06, 0.45, 0.06 }, { 1.43, 1.98, -0.1 }, NOTE),
		ellipsoid({ 0.3, 0.22, 0.12 }, { -1.05, 2.2, -0.1 }, NOTE, { turn = { 0, 0, 20 } }),
		block({ 0.06, 0.48, 0.06 }, { -0.92, 2.44, -0.1 }, NOTE),
	},
}

-- A spotlit theatre stage with curtains.
local STAGE_GOLD = hex("#E0A93B")
local CURTAIN = hex("#C0263A")
looks.Disnee = {
	badge = { text = "Dn", colour = CURTAIN, ink = NOTE, at = { 0, 3.62, -0.78 } },
	pieces = {
		block({ 2.9, 0.4, 1.9 }, { 0, 0.2, 0 }, hex("#8B5A2B")), -- stage
		block({ 2.95, 0.1, 0.1 }, { 0, 0.36, -0.96 }, STAGE_GOLD),
		block({ 2.6, 2.3, 0.1 }, { 0, 1.55, 0.85 }, hex("#3B1F4A")), -- backdrop
		block({ 0.26, 2.5, 0.26 }, { -1.36, 1.65, -0.78 }, STAGE_GOLD),
		block({ 0.26, 2.5, 0.26 }, { 1.36, 1.65, -0.78 }, STAGE_GOLD),
		block({ 2.98, 0.4, 0.28 }, { 0, 2.95, -0.78 }, STAGE_GOLD),
		can(2.2, 0.36, { -1.05, 1.55, -0.6 }, CURTAIN), -- curtains
		can(2.2, 0.36, { -0.76, 1.55, -0.56 }, CURTAIN),
		can(2.2, 0.36, { 0.76, 1.55, -0.56 }, CURTAIN),
		can(2.2, 0.36, { 1.05, 1.55, -0.6 }, CURTAIN),
		block({ 2.5, 0.4, 0.16 }, { 0, 2.52, -0.62 }, CURTAIN),
		can(0.03, 1.0, { 0, 0.415, -0.15 }, hex("#FFF5B8"), { material = NEON, transparency = 0.25 }), -- spotlight
		can(1.0, 0.05, { 0, 0.9, -0.15 }, INK), -- microphone
		ball(0.2, { 0, 1.45, -0.15 }, SILVER),
		rod(0.4, 0.3, { -1.0, 3.25, -0.95 }, DARK, { turn = { 0, 0, -40 } }), -- the lamp
	},
}

-- A set of nesting dolls.
local DOLL_FACE = hex("#FFE8D1")
looks.Nestled = {
	badge = { text = "Ns", colour = hex("#D7263D"), ink = DOLL_FACE },
	pieces = {
		ellipsoid({ 1.3, 1.5, 1.2 }, { 0, 0.75, 0.25 }, hex("#D7263D")),
		ellipsoid({ 0.9, 1.05, 0.5 }, { 0, 0.68, -0.15 }, hex("#FFD95A")),
		ball(1.0, { 0, 1.85, 0.25 }, hex("#D7263D")),
		ellipsoid({ 0.72, 0.62, 0.3 }, { 0, 1.83, -0.15 }, DOLL_FACE),
		ball(0.1, { -0.15, 1.9, -0.29 }, INK),
		ball(0.1, { 0.15, 1.9, -0.29 }, INK),
		ellipsoid({ 0.91, 1.05, 0.84 }, { -1.05, 0.525, -0.35 }, hex("#FF8C1A")),
		ellipsoid({ 0.63, 0.74, 0.35 }, { -1.05, 0.48, -0.63 }, CREAM),
		ball(0.7, { -1.05, 1.295, -0.35 }, hex("#FF8C1A")),
		ellipsoid({ 0.5, 0.43, 0.21 }, { -1.05, 1.28, -0.63 }, DOLL_FACE),
		ball(0.07, { -1.15, 1.32, -0.73 }, INK),
		ball(0.07, { -0.95, 1.32, -0.73 }, INK),
		ellipsoid({ 0.65, 0.75, 0.6 }, { 1.0, 0.375, -0.5 }, hex("#3CB371")),
		ellipsoid({ 0.45, 0.52, 0.25 }, { 1.0, 0.34, -0.7 }, hex("#FFD95A")),
		ball(0.5, { 1.0, 0.925, -0.5 }, hex("#3CB371")),
		ellipsoid({ 0.36, 0.3, 0.15 }, { 1.0, 0.91, -0.69 }, DOLL_FACE),
	},
}

-- A giant lever lifting a stack of soap bars.
looks.Unileverage = {
	badge = { text = "Ul", colour = hex("#B5EAD7"), ink = INK },
	pieces = {
		block({ 0.8, 0.8, 0.9 }, { 0.2, 0.12, 0 }, STEEL, { turn = { 0, 0, 45 } }), -- fulcrum
		block({ 3.0, 0.15, 0.42 }, { 0.18, 0.76, 0 }, hex("#B0B7C3"), { material = METAL, turn = { 0, 0, 15 } }),
		ball(0.6, { -1.05, 0.81, 0 }, hex("#5B6178")), -- weight
		block({ 0.9, 0.3, 0.62 }, { 1.09, 1.24, 0 }, hex("#FFB5C8"), { turn = { 0, 0, 15 } }), -- soap
		block({ 0.9, 0.3, 0.62 }, { 1.01, 1.53, 0 }, hex("#B5EAD7"), { turn = { 0, 8, 12 } }),
		block({ 0.9, 0.3, 0.62 }, { 0.93, 1.82, 0 }, hex("#CDB4DB"), { turn = { 0, -6, 18 } }),
		ellipsoid({ 0.6, 0.2, 0.4 }, { 0.87, 2.06, 0 }, WHITE), -- foam
		ball(0.4, { 0.55, 2.35, -0.2 }, hex("#DFF6FF"), { material = GLASS_MATERIAL, transparency = 0.4 }), -- bubbles
		ball(0.3, { 1.4, 2.3, 0.2 }, hex("#DFF6FF"), { material = GLASS_MATERIAL, transparency = 0.4 }),
		ball(0.25, { 1.05, 2.75, 0 }, hex("#DFF6FF"), { material = GLASS_MATERIAL, transparency = 0.4 }),
		ball(0.2, { 0.3, 2.0, 0.3 }, hex("#DFF6FF"), { material = GLASS_MATERIAL, transparency = 0.4 }),
	},
}

-- An egg hatching out of an upside-down top hat.
local EGG = hex("#FFF8EE")
looks.BerkshireHatchaway = {
	badge = { text = "BH", colour = INK, ink = STAGE_GOLD },
	pieces = {
		can(1.4, 1.6, { 0, 0.7, 0 }, INK), -- the hat
		can(0.3, 1.64, { 0, 1.1, 0 }, STAGE_GOLD),
		can(0.1, 2.5, { 0, 1.45, 0 }, INK),
		can(0.03, 1.45, { 0, 1.515, 0 }, hex("#5C2A6E")), -- lining
		ellipsoid({ 1.0, 1.3, 1.0 }, { 0, 1.85, 0 }, EGG),
		ball(0.62, { 0, 2.52, 0 }, hex("#FFD23F")), -- chick
		ball(0.09, { -0.11, 2.6, -0.27 }, INK),
		ball(0.09, { 0.11, 2.6, -0.27 }, INK),
		ball(0.14, { 0, 2.5, -0.31 }, hex("#FF8C1A")),
		ellipsoid({ 0.95, 0.55, 0.95 }, { 0.22, 2.95, 0.05 }, EGG, { turn = { 0, 0, -22 } }), -- shell cap
	},
}

-- A tissue box mid-sneeze, a tissue flying off.
local TISSUE_BOX = hex("#8EC5FF")
looks.Hitachoo = {
	badge = { text = "Hc", colour = TISSUE_BOX, ink = INK },
	pieces = {
		block({ 2.0, 1.25, 1.4 }, { 0, 0.62, 0 }, TISSUE_BOX),
		block({ 2.02, 0.25, 1.42 }, { 0, 0.92, 0 }, WHITE), -- stripe
		block({ 1.0, 0.04, 0.3 }, { 0, 1.26, 0 }, INK), -- the slot
		ellipsoid({ 0.8, 1.0, 0.12 }, { -0.05, 1.72, 0 }, WHITE, { turn = { 0, 0, 15 } }), -- tissues
		ellipsoid({ 0.6, 0.8, 0.1 }, { 0.15, 1.65, 0.05 }, WHITE, { turn = { 0, 0, -20 } }),
		block({ 0.26, 0.05, 0.04 }, { -0.4, 0.62, -0.72 }, INK, { turn = { 0, 0, 20 } }), -- screwed-up eyes
		block({ 0.26, 0.05, 0.04 }, { 0.4, 0.62, -0.72 }, INK, { turn = { 0, 0, -20 } }),
		ellipsoid({ 0.36, 0.3, 0.05 }, { 0, 0.35, -0.71 }, INK), -- mouth
		ball(0.55, { 0, 0.5, -1.25 }, STEAM, { transparency = 0.35 }), -- the sneeze
		ball(0.42, { -0.38, 0.68, -1.5 }, STEAM, { transparency = 0.4 }),
		ball(0.36, { 0.38, 0.42, -1.55 }, STEAM, { transparency = 0.45 }),
		ellipsoid({ 0.5, 0.6, 0.06 }, { 1.15, 2.3, -0.3 }, WHITE, { turn = { 20, 0, 35 } }), -- one flying away
	},
}

---------------------------------------------------------------------------
-- Monopoly

-- A bowl of letter soup.
local SOUP = hex("#F28C28")
looks.AlphabetSoup = {
	badge = { text = "As", colour = SOUP, ink = WHITE },
	pieces = {
		can(0.25, 1.9, { 0, 0.125, 0 }, WHITE),
		can(0.95, 2.8, { 0, 0.7, 0 }, WHITE),
		can(0.14, 2.96, { 0, 1.18, 0 }, hex("#1B3A6B")),
		can(0.05, 2.6, { 0, 1.24, 0 }, SOUP, { text = { text = "A B C\nX Y Z", face = "Top", colour = CREAM } }),
		ellipsoid({ 0.55, 0.14, 0.38 }, { 0.42, 1.28, 0.1 }, SILVER), -- spoon
		rod(1.6, 0.12, { 0.86, 1.92, 0.1 }, SILVER, { turn = { 0, 0, 55 } }),
		block({ 0.4, 0.45, 0.08 }, { 0.6, 2.25, -0.4 }, CREAM, {
			turn = { 0, 0, 12 },
			text = { text = "A", face = "Front", colour = SOUP },
		}),
		block({ 0.4, 0.45, 0.08 }, { -0.85, 2.05, -0.5 }, CREAM, {
			turn = { 0, 0, -15 },
			text = { text = "Z", face = "Front", colour = SOUP },
		}),
		ball(0.5, { -0.4, 1.75, 0 }, STEAM, { transparency = 0.5 }), -- steam
		ball(0.4, { -0.2, 2.2, 0.1 }, STEAM, { transparency = 0.55 }),
		ball(0.3, { -0.45, 2.6, -0.1 }, STEAM, { transparency = 0.6 }),
	},
}

-- A headset with a bored "meh" face.
local HEADSET = hex("#E8ECF2")
local HEADSET_STRAP = hex("#5B6178")
looks.Mehta = {
	badge = { text = "Mt", colour = HEADSET, ink = INK },
	pieces = {
		can(0.75, 0.22, { 0, 0.375, 0.3 }, HEADSET_STRAP), -- stand
		block({ 2.0, 1.3, 1.1 }, { 0, 1.35, 0 }, HEADSET),
		can(1.3, 1.1, { -1.0, 1.35, 0 }, HEADSET),
		can(1.3, 1.1, { 1.0, 1.35, 0 }, HEADSET),
		block({ 2.1, 0.95, 0.05 }, { 0, 1.35, -0.57 }, INK, { reflectance = 0.2 }), -- visor
		block({ 0.45, 0.08, 0.04 }, { -0.5, 1.5, -0.61 }, HEADSET, { material = NEON, turn = { 0, 0, 6 } }),
		block({ 0.45, 0.08, 0.04 }, { 0.5, 1.5, -0.61 }, HEADSET, { material = NEON, turn = { 0, 0, -6 } }),
		block({ 0.62, 0.07, 0.04 }, { 0, 1.1, -0.61 }, HEADSET, { material = NEON }), -- flat mouth
		block({ 0.15, 0.36, 0.95 }, { -1.45, 1.35, 0.875 }, HEADSET_STRAP),
		block({ 0.15, 0.36, 0.95 }, { 1.45, 1.35, 0.875 }, HEADSET_STRAP),
		block({ 3.05, 0.36, 0.15 }, { 0, 1.35, 1.35 }, HEADSET_STRAP),
		ellipsoid({ 0.38, 0.26, 0.62 }, { -1.15, 0.13, -1.05 }, SILVER, { turn = { 0, 20, 0 } }), -- controllers
		ellipsoid({ 0.38, 0.26, 0.62 }, { 1.15, 0.13, -1.05 }, SILVER, { turn = { 0, -20, 0 } }),
		ball(0.45, { 1.25, 2.4, -0.3 }, STEAM, { transparency = 0.25 }), -- a sigh
		ball(0.3, { 1.05, 2.05, -0.4 }, STEAM, { transparency = 0.3 }),
	},
}

-- An overflowing oversized shopping trolley.
local TROLLEY_RED = hex("#E63946")
looks.Megamart = {
	badge = { text = "Mm", colour = WHITE, ink = TROLLEY_RED },
	pieces = {
		block({ 1.6, 0.1, 2.2 }, { 0, 0.42, 0 }, STEEL), -- chassis
		rod(0.16, 0.36, { -0.75, 0.18, -0.95 }, TYRE),
		rod(0.16, 0.36, { 0.75, 0.18, -0.95 }, TYRE),
		rod(0.16, 0.36, { -0.75, 0.18, 0.95 }, TYRE),
		rod(0.16, 0.36, { 0.75, 0.18, 0.95 }, TYRE),
		block({ 1.5, 0.5, 0.08 }, { 0, 0.68, -0.95 }, STEEL),
		block({ 1.5, 0.5, 0.08 }, { 0, 0.68, 0.95 }, STEEL),
		block({ 1.8, 1.0, 2.4 }, { 0, 1.4, 0 }, SILVER, { material = METAL }), -- basket
		block({ 1.9, 0.1, 2.5 }, { 0, 1.92, 0 }, TROLLEY_RED),
		block({ 0.08, 0.6, 0.08 }, { -0.88, 2.17, 1.33 }, STEEL, { turn = { 16, 0, 0 } }), -- handle
		block({ 0.08, 0.6, 0.08 }, { 0.88, 2.17, 1.33 }, STEEL, { turn = { 16, 0, 0 } }),
		rod(1.9, 0.18, { 0, 2.43, 1.4 }, TROLLEY_RED),
		block({ 0.8, 0.8, 0.8 }, { -0.4, 2.15, -0.45 }, hex("#FF8C42"), { turn = { 0, 15, 10 } }), -- shopping
		can(1.0, 0.36, { 0.5, 2.3, 0.25 }, hex("#3CB371")),
		ball(0.7, { 0.38, 2.1, -0.6 }, hex("#FF5FB0")),
		rod(1.3, 0.32, { -0.35, 2.25, 0.55 }, hex("#E3B27A"), { turn = { 0, 30, 25 } }),
		block({ 0.62, 1.0, 0.26 }, { 0.05, 2.45, 0.85 }, hex("#A66CFF"), { turn = { -10, 0, 5 } }),
		ellipsoid({ 0.75, 0.62, 0.95 }, { -0.5, 2.6, -0.05 }, hex("#5DBB63"), { turn = { 0, 30, 0 } }),
	},
}

-- A clock tower built from stacked coins.
local COIN_DARK = hex("#E0A93B")
local TOWER_ROOF = hex("#7B4AE2")
looks.Tencentury = {
	badge = { text = "Tc", colour = TOWER_ROOF, ink = GOLD },
	pieces = {
		can(0.22, 1.6, { 0, 0.11, 0 }, GOLD), -- coins
		can(0.22, 1.6, { 0.04, 0.33, 0 }, COIN_DARK),
		can(0.22, 1.6, { -0.03, 0.55, 0 }, GOLD),
		can(0.22, 1.6, { 0.02, 0.77, 0 }, COIN_DARK),
		can(0.22, 1.15, { 0, 0.99, 0 }, GOLD),
		can(0.22, 1.15, { -0.03, 1.21, 0 }, COIN_DARK),
		can(0.22, 1.15, { 0.02, 1.43, 0 }, GOLD),
		block({ 1.0, 0.9, 1.0 }, { 0, 1.99, 0 }, CREAM), -- clock
		disc(0.06, 0.78, { 0, 2.0, -0.52 }, WHITE),
		block({ 0.06, 0.3, 0.03 }, { 0, 2.12, -0.56 }, INK),
		block({ 0.26, 0.06, 0.03 }, { 0.1, 2.0, -0.56 }, INK),
		ellipsoid({ 1.2, 1.25, 1.2 }, { 0, 2.44, 0 }, TOWER_ROOF),
		ball(0.26, { 0, 3.12, 0 }, GOLD),
		can(0.1, 0.7, { 1.3, 0.05, -0.75 }, GOLD), -- loose coins
		disc(0.1, 0.7, { -1.3, 0.35, -0.6 }, COIN_DARK, { turn = { 0, 30, 0 } }),
	},
}

-- A small globe with tiny things orbiting it.
local LAND = hex("#7ED957")
looks.EverythingInc = {
	badge = { text = "Ev", colour = GOLD, ink = INK },
	pieces = {
		can(0.12, 1.0, { 0, 0.06, 0 }, GOLD), -- stand
		can(0.55, 0.24, { 0, 0.39, 0 }, GOLD),
		ball(1.9, { 0, 1.55, 0 }, hex("#3D8BFF")), -- globe
		ball(0.9, { -0.23, 1.72, -0.5 }, LAND),
		ball(0.8, { 0.32, 1.36, -0.51 }, LAND),
		ball(0.9, { 0.18, 2.02, 0.29 }, LAND),
		ball(0.85, { -0.49, 1.43, 0.34 }, LAND),
		ball(0.7, { 0.63, 1.7, 0.22 }, LAND),
		ellipsoid({ 0.7, 0.2, 0.7 }, { 0, 2.47, 0 }, WHITE), -- ice cap
		can(0.06, 3.0, { 0, 1.55, 0 }, GOLD, { turn = { 20, 0, 0 }, transparency = 0.1 }), -- ring
		block({ 0.32, 0.2, 0.42 }, { 0.95, 1.5, 1.0 }, hex("#E63946")), -- a tiny car
		disc(0.06, 0.32, { -0.95, 1.5, 1.0 }, NOTE), -- a coin
		block({ 0.18, 0.32, 0.05 }, { -0.95, 2.16, -0.85 }, DARK), -- a phone
		ball(0.3, { 0.95, 2.16, -0.85 }, hex("#FF5FB0")), -- a ball
	},
}

-- A golden go-kart with a credit card for a spoiler.
local KART_SEAT = hex("#3A2A5E")
local CARD = hex("#5B3FB8")
looks.Mastercart = {
	badge = { text = "Mk", colour = GOLD, ink = INK },
	pieces = {
		block({ 1.5, 0.32, 2.4 }, { 0, 0.5, 0 }, GOLD, { material = METAL, reflectance = 0.1 }), -- chassis
		wedge({ 1.4, 0.4, 0.75 }, { 0, 0.86, -0.95 }, GOLD, { material = METAL, reflectance = 0.1 }), -- nose
		rod(0.4, 0.75, { -0.95, 0.38, -0.8 }, TYRE), -- wheels
		rod(0.4, 0.75, { 0.95, 0.38, -0.8 }, TYRE),
		rod(0.4, 0.75, { -0.95, 0.38, 0.8 }, TYRE),
		rod(0.4, 0.75, { 0.95, 0.38, 0.8 }, TYRE),
		rod(0.42, 0.32, { -0.95, 0.38, -0.8 }, SILVER),
		rod(0.42, 0.32, { 0.95, 0.38, -0.8 }, SILVER),
		rod(0.42, 0.32, { -0.95, 0.38, 0.8 }, SILVER),
		rod(0.42, 0.32, { 0.95, 0.38, 0.8 }, SILVER),
		block({ 0.9, 0.2, 0.8 }, { 0, 0.76, 0.25 }, KART_SEAT), -- seat
		block({ 0.9, 0.75, 0.2 }, { 0, 1.1, 0.62 }, KART_SEAT, { turn = { -15, 0, 0 } }),
		block({ 0.08, 0.45, 0.08 }, { 0, 0.95, -0.32 }, STEEL, { turn = { -30, 0, 0 } }), -- steering
		disc(0.08, 0.5, { 0, 1.15, -0.42 }, INK, { turn = { -30, 0, 0 } }),
		block({ 0.1, 0.65, 0.1 }, { -0.6, 1.0, 1.1 }, STEEL), -- spoiler supports
		block({ 0.1, 0.65, 0.1 }, { 0.6, 1.0, 1.1 }, STEEL),
		block({ 1.75, 1.05, 0.06 }, { 0, 1.75, 1.15 }, CARD), -- the card
		block({ 0.32, 0.24, 0.03 }, { -0.45, 1.85, 1.11 }, GOLD), -- its chip
		block({ 1.5, 0.08, 0.03 }, { 0, 1.5, 1.11 }, SILVER),
	},
}

---------------------------------------------------------------------------

-- Plinths by tier: bigger and grander each tier up. Mega Cap and up slowly
-- spin and bob; Conglomerate and Monopoly also glow (each with the model's
-- one light), and Monopoly sparkles.
local plinths: { [string]: Plinth } = {
	Startup = {
		diameter = 3.2,
		height = 0.5,
		trim = false,
		step = false,
		gold = false,
		glow = false,
		aura = false,
		idle = false,
	},
	ScaleUp = {
		diameter = 3.35,
		height = 0.58,
		trim = true,
		step = false,
		gold = false,
		glow = false,
		aura = false,
		idle = false,
	},
	Unicorn = {
		diameter = 3.5,
		height = 0.66,
		trim = true,
		step = true,
		gold = false,
		glow = false,
		aura = false,
		idle = false,
	},
	Decacorn = {
		diameter = 3.65,
		height = 0.74,
		trim = true,
		step = true,
		gold = false,
		glow = false,
		aura = false,
		idle = false,
	},
	BlueChip = {
		diameter = 3.8,
		height = 0.82,
		trim = false,
		step = true,
		gold = true,
		glow = false,
		aura = false,
		idle = false,
	},
	MegaCap = {
		diameter = 3.95,
		height = 0.9,
		trim = false,
		step = true,
		gold = true,
		glow = false,
		aura = false,
		idle = true,
	},
	Conglomerate = {
		diameter = 4.08,
		height = 0.97,
		trim = false,
		step = true,
		gold = true,
		glow = true,
		aura = false,
		idle = true,
	},
	Monopoly = {
		diameter = 4.2,
		height = 1.05,
		trim = false,
		step = true,
		gold = true,
		glow = true,
		aura = true,
		idle = true,
	},
}

return {
	looks = looks,
	plinths = plinths,

	-- At most this many parts in a model, plinth and badge included.
	MaxParts = 30,
	-- Pieces whose longest side is shorter than this cast no shadow.
	SmallPiece = 1.2,

	-- The plinth's rings, in studs.
	StepHeight = 0.18,
	StepWidth = 0.5,
	RingHeight = 0.12,
	RingWidth = 0.14,
	GlowHeight = 0.1,
	GlowWidth = 0.24,

	-- The floating badge: its size and gap above the object, in studs, and
	-- how far away it still shows.
	BadgeSize = 1.0,
	BadgeGap = 0.3,
	BadgeDistance = 60,

	-- The nameplate on the plinth and any text on pieces: sharpness
	-- (kept low for phones) and how far away they still show.
	NameplatePixelsPerStud = 50,
	TextPixelsPerStud = 40,
	TextDistance = 40,

	-- The one light on Conglomerate and Monopoly models.
	LightRange = 7,
	LightBrightness = 0.8,

	-- Monopoly sparkles: a few at a time, short-lived.
	AuraRate = 5,
	AuraLifetime = { 1.2, 1.8 },

	-- Idle motion (client, Mega Cap and up): degrees per second, bob height in
	-- studs and seconds per bob.
	IdleSpinSpeed = 20,
	IdleBobHeight = 0.12,
	IdleBobSeconds = 3,
	-- Sparkles and idle motion stop beyond this many studs from the camera.
	EffectsDistance = 60,
}
