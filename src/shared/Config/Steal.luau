--!strict
-- Stealing and base locks. Starting assumptions from docs/design.md.

return {
	-- How long a thief holds the prompt to pick up a placed company, and the
	-- leeway the server allows for network lag when timing it.
	HoldSeconds = 1.5,
	HoldTolerance = 0.25,

	-- How close (in studs) a thief must be to the plot to pick it up, and how
	-- much extra the server allows for lag.
	StealDistance = 10,
	StealDistanceTolerance = 6,

	-- How close (in studs) an owner must get to a thief carrying one of their
	-- companies to tag them and get it back.
	TagDistance = 6,

	-- New players can't be stolen from for this long after first joining.
	NewPlayerProtectionSeconds = 300,

	-- How long a base lock lasts. Owners press the button again to renew it.
	LockSeconds = 60,
	-- How close (in studs) the owner must be to the lock button.
	LockButtonDistance = 10,
	LockButtonDistanceTolerance = 6,
	-- How far outside a locked base (in studs) anyone else inside is moved.
	LockPushMargin = 6,
}
