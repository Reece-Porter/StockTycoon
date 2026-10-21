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

local Theme = require(script.Parent.Parent.Theme)

export type Vec = { number }

export type Text = {
	text: string,
	-- "Front" or "Top", of the piece before it is turned.
	face: string,
	colour: Color3,
}

export type Piece = {
	-- "Block", "Ball", "Cylinder", "Wedge" or "Ellipsoid".
	shape: string,
	size: Vec,
	at: Vec,
	turn: Vec?,
	-- The way a cylinder points before it is turned: "x", "y" (standing up)
	-- or "z" (facing the front).
	axis: string?,
	colour: Color3,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	text: Text?,
}

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

type Options = {
	turn: Vec?,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	text: Text?,
}

local function piece(shape: string, size: Vec, at: Vec, colour: Color3, options: Options?, axis: string?): Piece
	local extra: Options = options or {}
	return {
		shape = shape,
		size = size,
		at = at,
		turn = extra.turn,
		axis = axis,
		colour = colour,
		material = extra.material,
		transparency = extra.transparency,
		reflectance = extra.reflectance,
		text = extra.text,
	}
end

local function block(size: Vec, at: Vec, colour: Color3, options: Options?): Piece
	return piece("Block", size, at, colour, options)
end

local function ball(diameter: number, at: Vec, colour: Color3, options: Options?): Piece
	return piece("Ball", { diameter, diameter, diameter }, at, colour, options)
end

-- A stretched ball.
local function ellipsoid(size: Vec, at: Vec, colour: Color3, options: Options?): Piece
	return piece("Ellipsoid", size, at, colour, options)
end

-- A ramp: full height at the back (+z), sloping down to the front.
local function wedge(size: Vec, at: Vec, colour: Color3, options: Options?): Piece
	return piece("Wedge", size, at, colour, options)
end

-- A cylinder lying along x (before any turn).
local function rod(length: number, diameter: number, at: Vec, colour: Color3, options: Options?): Piece
	return piece("Cylinder", { length, diameter, diameter }, at, colour, options, "x")
end

-- A cylinder standing up.
local function can(height: number, diameter: number, at: Vec, colour: Color3, options: Options?): Piece
	return piece("Cylinder", { height, diameter, diameter }, at, colour, options, "y")
end

-- A cylinder facing the front, like a coin held up.
local function disc(thickness: number, diameter: number, at: Vec, colour: Color3, options: Options?): Piece
	return piece("Cylinder", { thickness, diameter, diameter }, at, colour, options, "z")
end

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

---------------------------------------------------------------------------

-- Plinths by tier: bigger and grander each tier up.
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
		diameter = 3.4,
		height = 0.6,
		trim = true,
		step = false,
		gold = false,
		glow = false,
		aura = false,
		idle = false,
	},
	Unicorn = {
		diameter = 3.6,
		height = 0.75,
		trim = true,
		step = true,
		gold = false,
		glow = false,
		aura = false,
		idle = false,
	},
	BlueChip = {
		diameter = 3.8,
		height = 0.85,
		trim = false,
		step = true,
		gold = true,
		glow = false,
		aura = false,
		idle = false,
	},
	Conglomerate = {
		diameter = 4.0,
		height = 0.95,
		trim = false,
		step = true,
		gold = true,
		glow = true,
		aura = false,
		idle = false,
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

	-- Monopoly idle motion (client): degrees per second, bob height in studs
	-- and seconds per bob.
	IdleSpinSpeed = 20,
	IdleBobHeight = 0.12,
	IdleBobSeconds = 3,
	-- Sparkles and idle motion stop beyond this many studs from the camera.
	EffectsDistance = 60,
}
