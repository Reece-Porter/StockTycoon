--!strict
-- The Stock Spinner's Luck, odds, rolls and timing (Config/Spinner). Pure
-- functions: the caller passes in its source of random numbers (each from 0
-- up to, not including, 1), so the same code runs in the game and in tests.

local Companies = require(script.Parent.Config.Companies)
local PerkMath = require(script.Parent.PerkMath)
local RebirthMath = require(script.Parent.RebirthMath)
local SpawnRoll = require(script.Parent.SpawnRoll)
local SpinnerConfig = require(script.Parent.Config.Spinner)

export type Result = { companyId: string, tier: string }

-- When one of a roll's companies comes out, where along the belt it stops
-- (0 to 1), and how long it takes to get there.
export type Exit = { comesOutAt: number, stop: number, travelSeconds: number }

local SpinnerMath = {}

-- A player's Luck: what their rebirths give, times their Spinner Luck
-- upgrade (saved as ConveyorLuck).
function SpinnerMath.luck(rebirths: number, luckLevel: number): number
	return RebirthMath.luck(rebirths) * PerkMath.multiplier("ConveyorLuck", luckLevel)
end

-- "x1", "x1.25" or "x2.4": Luck as players see it.
function SpinnerMath.luckText(luck: number): string
	local text = string.format("%.2f", math.floor(luck * 100 + 0.5) / 100)
	text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	return `x{text}`
end

-- The spinner's odds at this Luck: each tier after the first weighs Luck to
-- the power of its place after the first. Returns a new list.
function SpinnerMath.weights(weights: { SpinnerConfig.WeightEntry }, luck: number): { SpinnerConfig.WeightEntry }
	local result = {}
	for index, entry in weights do
		table.insert(result, { tier = entry.tier, weight = entry.weight * luck ^ (index - 1) })
	end
	return result
end

-- Each tier's chance (0 to 100) with these weights.
function SpinnerMath.percents(weights: { SpinnerConfig.WeightEntry }): { [string]: number }
	local total = 0
	for _, entry in weights do
		total += entry.weight
	end
	local percents = {}
	for _, entry in weights do
		percents[entry.tier] = if total > 0 then entry.weight / total * 100 else 0
	end
	return percents
end

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
