--!strict
-- Number formatting for the UI: 950, 1.2K, 34.5M, 120B. Always rounds down,
-- so the game never shows more Cash than a player really has.

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

local Format = {}

-- Rounded down to one decimal place, without a trailing ".0".
local function oneDecimal(value: number): string
	local text = string.format("%.1f", math.floor(value * 10) / 10)
	return (string.gsub(text, "%.0$", ""))
end

function Format.number(value: number): string
	if value < 1000 then
		return oneDecimal(value)
	end

	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end

	local text = if value < 100 then oneDecimal(value) else tostring(math.floor(value))
	return text .. SUFFIXES[index]
end

-- A length of time as minutes and seconds, e.g. 3:07.
function Format.duration(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- A longer length of time in words, e.g. "2h 13m", "13m" or "45s".
function Format.longDuration(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	local hours, minutes = whole // 3600, (whole % 3600) // 60
	if hours > 0 then
		return if minutes > 0 then `{hours}h {minutes}m` else `{hours}h`
	elseif minutes > 0 then
		return `{minutes}m`
	end
	return `{whole}s`
end

function Format.cash(value: number): string
	return `${Format.number(value)}`
end

function Format.income(value: number): string
	return `+${Format.number(value)}/s`
end

return Format
