--!strict
-- The weapons sold in the weapon shop. Cartoon style only: knockback and
-- stuns, no blood and nothing realistic. Bought with Cash only, kept through
-- rebirth, one equipped at a time. Starting assumptions from docs/design.md.
--
-- range is in studs between the two characters. A weapon with
-- projectileSpeed fires a short ranged projectile; the rest hit up close.
-- knockback is the push speed in studs per second.
--
-- The Tool for each weapon lives in ReplicatedStorage.Assets.Weapons, named by
-- id; until one exists, the "Default" Tool is used.

export type Weapon = {
	id: string,
	name: string,
	description: string,
	price: number,
	damage: number,
	range: number,
	cooldown: number,
	knockback: number,
	stunSeconds: number?,
	projectileSpeed: number?,
}

local list: { Weapon } = {
	{
		id = "Newspaper",
		name = "Rolled-up Newspaper",
		description = "Free. Short reach, fast swings.",
		price = 0,
		damage = 10,
		range = 6,
		cooldown = 0.5,
		knockback = 10,
	},
	{
		id = "Briefcase",
		name = "Briefcase",
		description = "Solid hits with a good shove.",
		price = 2500,
		damage = 20,
		range = 6.5,
		cooldown = 1,
		knockback = 45,
	},
	{
		id = "StaplerGun",
		name = "Stapler Gun",
		description = "Fires staples from a distance.",
		price = 25000,
		damage = 12,
		range = 30,
		cooldown = 0.6,
		knockback = 8,
		projectileSpeed = 120,
	},
	{
		id = "Gavel",
		name = "Gavel",
		description = "Slow swings, huge knockback.",
		price = 250000,
		damage = 35,
		range = 7,
		cooldown = 1.8,
		knockback = 80,
	},
	{
		id = "GoldenCalculator",
		name = "Golden Calculator",
		description = "Stuns whoever it hits for a second.",
		price = 2500000,
		damage = 30,
		range = 7,
		cooldown = 1.5,
		knockback = 20,
		stunSeconds = 1,
	},
}

local byId: { [string]: Weapon } = {}
for _, weapon in list do
	byId[weapon.id] = weapon
end

return {
	-- Every player owns this one from the start.
	Starter = "Newspaper",
	list = list,
	byId = byId,
}
