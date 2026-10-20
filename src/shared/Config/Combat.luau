--!strict
-- Health, respawning and dropped companies. Starting assumptions from
-- docs/design.md. The weapons themselves are in Config/Weapons.

return {
	MaxHealth = 100,

	-- Seconds a knocked-out player lies ragdolled before respawning at their
	-- own base.
	RespawnSeconds = 3,

	-- Seconds after respawning that a player can't be hit. Attacking someone
	-- ends it early.
	SpawnProtectionSeconds = 10,

	-- Extra reach (in studs) the server allows on top of a weapon's range, for
	-- characters moving and network lag.
	RangeTolerance = 3,
	-- Leeway (in seconds) the server allows on a weapon's cooldown for lag.
	CooldownTolerance = 0.1,

	-- Upward speed (studs per second) added to every knockback so players
	-- leave the ground instead of sliding.
	KnockbackLift = 18,

	-- A company knocked out of someone's hands lies on the ground this long,
	-- for anyone to pick up, before going back where it belongs.
	DropReturnSeconds = 10,
	-- How close (in studs) a player must be to pick a dropped company up, and
	-- how much extra the server allows for lag.
	PickUpDistance = 8,
	PickUpDistanceTolerance = 6,

	-- How close (in studs) a player must be to the weapon shop to buy.
	ShopDistance = 12,
	ShopDistanceTolerance = 6,
}
