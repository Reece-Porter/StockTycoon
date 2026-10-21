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

local Theme = require(script.Parent.Parent.Theme)

export type Variant = {
	id: string,
	name: string,
	multiplier: number,
	oneIn: number,
	-- From Theme.Variants: the badge and name colour.
	colour: Color3,
	-- How it looks: particles in these colours, plus flames or a glow.
	particleColours: { Color3 },
	fire: boolean?,
	light: boolean?,
}

local list: { Variant } = {
	{
		id = "Shiny",
		name = "Shiny",
		multiplier = 1.5,
		oneIn = 20,
		colour = Theme.Variants.Shiny,
		particleColours = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 230, 120) },
	},
	{
		id = "Pixel",
		name = "Pixel",
		multiplier = 2,
		oneIn = 50,
		colour = Theme.Variants.Pixel,
		particleColours = { Color3.fromRGB(80, 220, 80), Color3.fromRGB(40, 160, 255) },
	},
	{
		id = "Molten",
		name = "Molten",
		multiplier = 3,
		oneIn = 120,
		colour = Theme.Variants.Molten,
		particleColours = { Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 60, 30) },
		fire = true,
		light = true,
	},
	{
		id = "Galaxy",
		name = "Galaxy",
		multiplier = 5,
		oneIn = 300,
		colour = Theme.Variants.Galaxy,
		particleColours = { Color3.fromRGB(150, 90, 255), Color3.fromRGB(90, 160, 255), Color3.fromRGB(255, 255, 255) },
		light = true,
	},
	{
		id = "Rainbow",
		name = "Rainbow",
		multiplier = 7,
		oneIn = 600,
		colour = Theme.Variants.Rainbow,
		particleColours = {
			Color3.fromRGB(255, 80, 80),
			Color3.fromRGB(255, 200, 60),
			Color3.fromRGB(80, 220, 120),
			Color3.fromRGB(80, 160, 255),
			Color3.fromRGB(200, 100, 255),
		},
		light = true,
	},
	{
		id = "Glitched",
		name = "Glitched",
		multiplier = 10,
		oneIn = 1500,
		colour = Theme.Variants.Glitched,
		particleColours = { Color3.fromRGB(255, 0, 200), Color3.fromRGB(0, 255, 230), Color3.fromRGB(20, 20, 20) },
		light = true,
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
