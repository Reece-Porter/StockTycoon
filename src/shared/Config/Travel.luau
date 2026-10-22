--!strict
-- Teleport buttons (docs/design.md, "Teleports"). Starting assumptions.

export type Place = "Home" | "Upgrades" | "Weapons" | "Arena"

return {
	-- The buttons, in order: Home is the player's own base, Upgrades the
	-- upgrade station, Weapons the weapon shop (next to the pet shop).
	Places = { "Home", "Upgrades", "Weapons" } :: { Place },
	-- Places with no button, reached from a teleporter in the world: the
	-- battle arena, from its gates in the middle of the street.
	Gates = { "Arena" } :: { Place },
	-- Seconds between teleports.
	CooldownSeconds = 5,
	-- Players arrive this far in front of a station's counter, and this high
	-- above the ground they land on.
	StationDistance = 9,
	ArriveHeight = 3,
}
