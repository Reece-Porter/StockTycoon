--!strict
-- The Valuation Machine's multiplier over time: a pure, deterministic function
-- of the run's parameters and the time into the run, so the server and the
-- client's chart always agree. The server generates the parameters when a run
-- starts and works out the result from its own clock.
--
-- The path starts at 1.0x, rises to a hidden peak, then falls back past 1.0x
-- towards the floor (0.5x), with a small seeded wobble so the peak isn't
-- obvious. It never goes below the floor or above the peak, and a run never
-- lasts more than 45 seconds (CLAUDE.md, non-negotiable).
--
-- The wobble uses integer hashing (bit32) rather than math.random, so every
-- device produces exactly the same numbers from the same seed.

local MachineConfig = require(script.Parent.Config.Machine)
local Tiers = require(script.Parent.Config.Tiers)

export type Params = {
	seed: number,
	duration: number,
	peak: number,
	peakTime: number,
}

-- Hard limits from CLAUDE.md. Config can tune inside these, never past them.
local LOWEST = 0.5
local MAX_DURATION = 45
-- Every run starts here.
local START = 1
local FLOOR = math.clamp(MachineConfig.Floor, LOWEST, START)

-- Seconds over which the wobble fades in at the start and out at the end.
local NOISE_FADE = 1.5
local WAVES = 3
local TWO_PI = 2 * math.pi

local MachinePath = {}

MachinePath.FLOOR = FLOOR
MachinePath.START = START
MachinePath.MAX_DURATION = MAX_DURATION

-- Optional run lengths for generate (the battle arena's shorter runs).
export type Limits = { minDuration: number, maxDuration: number }

-- Multiplies two 32-bit unsigned integers modulo 2^32, exactly.
local function mul32(a: number, b: number): number
	local aLow, aHigh = bit32.band(a, 0xFFFF), bit32.rshift(a, 16)
	local bLow, bHigh = bit32.band(b, 0xFFFF), bit32.rshift(b, 16)
	local cross = bit32.band(aHigh * bLow + aLow * bHigh, 0xFFFF)
	return (aLow * bLow + bit32.lshift(cross, 16)) % 4294967296
end

-- A well-mixed 32-bit hash (MurmurHash3's finaliser).
local function hash(value: number): number
	value = bit32.bxor(value, bit32.rshift(value, 16))
	value = mul32(value, 0x85EBCA6B)
	value = bit32.bxor(value, bit32.rshift(value, 13))
	value = mul32(value, 0xC2B2AE35)
	return bit32.bxor(value, bit32.rshift(value, 16))
end

-- A number from 0 up to (not including) 1, fixed for a given seed and index.
local function unit(seed: number, index: number): number
	return hash(bit32.bxor(seed, mul32(index + 1, 0x9E3779B1))) / 4294967296
end

-- Rounds to three decimal places, so parameters survive being sent to the
-- client as JSON exactly.
local function round3(value: number): number
	return math.round(value * 1000) / 1000
end

-- Eases from 0 to 1 smoothly at both ends.
local function smooth(x: number): number
	return (1 - math.cos(math.pi * math.clamp(x, 0, 1))) / 2
end

-- A new run's parameters. roll returns a number from 0 up to 1 (the server
-- passes Random:NextNumber). limits sets the run's length instead of
-- Config/Machine's (never past 45 seconds).
function MachinePath.generate(roll: () -> number, limits: Limits?): Params
	local maxDuration = math.min(if limits then limits.maxDuration else MachineConfig.MaxDuration, MAX_DURATION)
	local minDuration = math.min(if limits then limits.minDuration else MachineConfig.MinDuration, maxDuration)
	local duration = minDuration + (maxDuration - minDuration) * roll()

	local peak = MachineConfig.MinPeak
		+ (MachineConfig.MaxPeak - MachineConfig.MinPeak) * roll() ^ MachineConfig.PeakSkew
	local peakShare = MachineConfig.PeakTimeMin + (MachineConfig.PeakTimeMax - MachineConfig.PeakTimeMin) * roll()

	duration = math.min(round3(duration), MAX_DURATION)
	return {
		seed = math.floor(roll() * 2147483647),
		duration = duration,
		peak = math.max(round3(peak), START),
		peakTime = round3(duration * peakShare),
	}
end

-- The smooth rise from 1.0x to the peak and the fall towards the floor,
-- before the wobble.
local function shape(params: Params, t: number): number
	if t <= params.peakTime then
		return START + (params.peak - START) * smooth(t / params.peakTime)
	end
	local drop = params.peak - FLOOR
	local endValue = FLOOR + drop * MachineConfig.EndShare
	local fall = smooth((t - params.peakTime) / (params.duration - params.peakTime))
	return params.peak - (params.peak - endValue) * fall
end

-- The seeded wobble, between -1 and 1.
local function wobble(seed: number, t: number): number
	local total, weightSum = 0, 0
	for wave = 1, WAVES do
		local frequency = 0.3 + 1.2 * unit(seed, wave * 2)
		local phase = TWO_PI * unit(seed, wave * 2 + 1)
		local weight = 1 / wave
		total += weight * math.sin(TWO_PI * frequency * t + phase)
		weightSum += weight
	end
	return total / weightSum
end

-- The multiplier t seconds into the run. Times past the end give the final
-- value: what a player gets if they never press Take.
function MachinePath.value(params: Params, t: number): number
	t = math.clamp(t, 0, params.duration)
	local fade = math.min(1, t / NOISE_FADE, (params.duration - t) / NOISE_FADE)
	local noise = wobble(params.seed, t) * MachineConfig.NoiseShare * (params.peak - START) * fade
	return math.clamp(shape(params, t) + noise, FLOOR, params.peak)
end

-- The multiplier a company keeps: rounded down to two decimal places, so it is
-- never above what the path reached and never below the floor.
function MachinePath.lock(value: number): number
	return math.max(FLOOR, math.floor(value * 100 + 1e-9) / 100)
end

-- What running an already-valued company through again costs, by its tier.
function MachinePath.respinCost(tierId: string): number
	local tier = Tiers.byId[tierId]
	return if tier then math.floor(tier.price * MachineConfig.RespinPriceShare + 0.5) else 0
end

return MachinePath
