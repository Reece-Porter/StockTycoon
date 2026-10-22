--!strict
-- The guide for new players (docs/design.md, "Onboarding"): a line to
-- follow and a hint near the bottom of the screen for each step. Players who joined before the
-- guide existed don't see it.

local Steps = {
	Buy = 1,
	Place = 2,
	Collect = 3,
	Machine = 4,
	Lock = 5,
	Middle = 6,
	Done = 7,
}

return {
	Steps = Steps,

	-- What each step asks the player to do.
	Hints = {
		[Steps.Buy] = "Your Stock Spinner rolls new companies onto your belt. Buy one!",
		[Steps.Place] = "Carry it to a free plot on your base and place it",
		[Steps.Collect] = "Your company makes Cash on the green pad in front of it. Walk over the pad to collect it",
		[Steps.Machine] = "Put your next company in the Valuation Machine before you place it",
		[Steps.Lock] = "Press the red lock button on your base. In a Hostile Takeover, a locked base can't be stolen from",
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
