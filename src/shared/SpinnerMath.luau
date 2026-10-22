--!strict
-- The Stock Spinner's rolls and timing (Config/Spinner). Pure functions: the
-- caller passes in its source of random numbers (each from 0 up to, not
-- including, 1), so the same code runs in the game and in tests.

local Companies = require(script.Parent.Config.Companies)
local SpawnRoll = require(script.Parent.SpawnRoll)
local SpinnerConfig = require(script.Parent.Config.Spinner)

export type Result = { companyId: string, tier: string }

-- When one of a roll's companies comes out, where along the belt it stops
-- (0 to 1), and how long it takes to get there.
export type Exit = { comesOutAt: number, stop: number, travelSeconds: number }

local SpinnerMath = {}

-- Rolls count different companies: each one's tier with these odds (the
-- first one's is firstTier instead, if given), then any company of that
-- tier not already picked.
function SpinnerMath.pick(
	weights: { SpinnerConfig.WeightEntry },
	count: number,
	nextNumber: () -> number,
	firstTier: string?
): { Result }
	local results: { Result } = {}
	local taken: { [string]: boolean } = {}
	for index = 1, count do
		local tier = if index == 1 and firstTier then firstTier else SpawnRoll.pickTier(weights, nextNumber())
		local choices = {}
		local ofTier = Companies.byTier[tier]
		if ofTier then
			for _, company in ofTier do
				if not taken[company.id] then
					table.insert(choices, company)
				end
			end
		end
		if #choices > 0 then
			local company = choices[SpawnRoll.pickIndex(#choices, nextNumber())]
			taken[company.id] = true
			table.insert(results, { companyId = company.id, tier = tier })
		end
	end
	return results
end

-- When each of count companies comes out after a roll lands at landAt, one
-- after another, and how long each takes to reach its stop on a belt this
-- long (in studs).
function SpinnerMath.exits(landAt: number, count: number, beltLength: number): { Exit }
	local stops = SpinnerConfig.Stops
	local exits: { Exit } = {}
	for index = 1, count do
		local stop = stops[math.min(index, #stops)]
		table.insert(exits, {
			comesOutAt = landAt + (index - 1) * SpinnerConfig.StaggerSeconds,
			stop = stop,
			travelSeconds = math.max(beltLength * stop / SpinnerConfig.SlideStudsPerSecond, 0.1),
		})
	end
	return exits
end

return SpinnerMath
