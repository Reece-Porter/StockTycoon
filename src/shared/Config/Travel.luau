--!strict
-- Teleport buttons (docs/design.md, "Teleports"). Starting assumptions.

export type Place = "Home" | "Upgrades" | "Weapons"

return {
	-- The buttons, in order: Home is the player's own base, Upgrades the
	-- upgrade station, Weapons the weapon shop (next to the pet shop).
	Places = { "Home", "Upgrades", "Weapons" } :: { Place },
	-- Seconds between teleports.
	CooldownSeconds = 5,
	-- Players arrive this far in front of a station's counter, and this high
	-- above the ground they land on.
	StationDistance = 9,
	ArriveHeight = 3,
}
