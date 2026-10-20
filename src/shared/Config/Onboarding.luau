--!strict
-- The guide for new players (docs/design.md, "Onboarding"): a line to
-- follow and a hint near the bottom of the screen for each step. Players who joined before the
-- guide existed don't see it.

local Steps = {
	Buy = 1,
	Place = 2,
	Machine = 3,
	Lock = 4,
	Middle = 5,
	Done = 6,
}

return {
	Steps = Steps,

	-- What each step asks the player to do.
	Hints = {
		[Steps.Buy] = "Buy a company from your conveyor",
		[Steps.Place] = "Carry it to a free plot on your base and place it",
		[Steps.Machine] = "Put your next company in the Valuation Machine before you place it",
		[Steps.Lock] = "Press the red lock button on your base. While it's locked, nobody can steal from you",
		[Steps.Middle] = "Rarer companies come down the middle conveyor. Anyone can buy them!",
	} :: { [number]: string },

	-- Seconds of play this session before pointing at the middle conveyor.
	ExploreAfterSeconds = 120,
	-- How close (in studs) to the middle conveyor counts as a visit.
	VisitDistance = 20,
	-- The middle conveyor step finishes on its own after this long, so nobody
	-- gets stuck on it.
	ExploreStepSeconds = 90,
	-- Placing this many companies without trying the machine moves the guide on.
	MachineSkipAfterPlaced = 3,
}
