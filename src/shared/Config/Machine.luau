--!strict
-- Valuation Machine tuning. The rules in CLAUDE.md are non-negotiable, and
-- MachinePath enforces the hard limits (floor 1.0x, at most 45 seconds)
-- whatever is set here.

return {
	-- How long a run lasts, in seconds.
	MinDuration = 10,
	MaxDuration = 45,

	-- The hidden peak multiplier.
	MinPeak = 1.2,
	MaxPeak = 5,
	-- How strongly peaks cluster at the low end: 1 would be even, higher
	-- means more low peaks and rarer high ones.
	PeakSkew = 2.5,

	-- When the peak comes, as a share of the run.
	PeakTimeMin = 0.2,
	PeakTimeMax = 0.7,

	-- How far back towards the 1.0x floor the multiplier falls by the end of a
	-- run, as a share of the way from the floor to the peak (0 = all the way).
	EndShare = 0.05,

	-- Size of the random wobble on the path, as a share of (peak - 1).
	NoiseShare = 0.08,

	-- How close (in studs) a player must be to the machine to use it, and how
	-- much extra the server allows for network lag.
	UseDistance = 10,
	UseDistanceTolerance = 6,
}
