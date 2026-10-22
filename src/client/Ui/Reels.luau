--!strict
-- The Stock Spinner's reels (docs/design.md, "Stock Spinner"): a row of
-- windows, each a column of companies rolling past in their tiers' colours,
-- slowing to a stop on what was rolled, one reel after another, the last as
-- the roll lands, with a little bump as each one stops. Used for the pop-up
-- on the player's screen (Ui/SpinnerPopup) and for the screen on every
-- base's machine (SpinnerController). Looks only: the server has already
-- rolled the companies.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)
local Make = require(script.Parent.Kit.Make)

-- How many companies roll past on the first reel, and how many more on each
-- reel after it.
local ROLL_PAST = 16
local MORE_PER_REEL = 5
-- How long before the roll lands each reel stops (the last one stopping as
-- it lands), and the bump as it does.
local REEL_GAP = 0.45
local BUMP_SECONDS = 0.22
local BUMP = 0.12

export type Result = { companyId: string, variant: string? }

type Tile = { frame: Frame, name: TextLabel, line: TextLabel, shown: number? }

export type Roll = {
	-- Server time the reels started, or nil before the first roll.
	rolledAt: number?,
	landsAt: number,
	results: { Result },
	-- What the reels showed before this roll, to start rolling from.
	previous: { Result },
}

export type Reels = {
	frame: Frame,
	windows: { Frame },
	tiles: { { Tile } },
	draw: (self: Reels, roll: Roll, now: number) -> { boolean },
}

-- The companies that roll past: every one the spinner can give.
local fillers: { string } = {}
for _, company in Companies.list do
	local tier = Tiers.byId[company.tier]
	if tier and not tier.sharedOnly then
		table.insert(fillers, company.id)
	end
end

local Reels = {}

-- "Kittygram:Shiny,Megamart" into results, skipping anything unknown.
function Reels.parse(text: string): { Result }
	local results: { Result } = {}
	for _, entry in string.split(text, ",") do
		local companyId, variant = string.match(entry, "^([^:]+):?(.*)$")
		if companyId and Companies.byId[companyId] then
			table.insert(results, {
				companyId = companyId,
				variant = if variant and variant ~= "" and Variants.byId[variant] then variant else nil,
			})
		end
	end
	return results
end

local function easeOut(t: number): number
	return 1 - (1 - t) ^ 3
end

-- Where reel number reel (of count) is in its column at this moment, and
-- the place of the result: rolling from the previous result at the roll to
-- the new one at its stop, with a bump as it stops.
function Reels.placeOf(roll: Roll, reel: number, count: number, now: number): (number, number)
	local last = ROLL_PAST + (reel - 1) * MORE_PER_REEL
	local rolledAt = roll.rolledAt
	if rolledAt == nil then
		return last, last
	end
	local stopsAt = roll.landsAt - (count - reel) * REEL_GAP
	if now >= stopsAt then
		local since = now - stopsAt
		return if since < BUMP_SECONDS then last + BUMP * math.sin(math.pi * since / BUMP_SECONDS) else last, last
	end
	local t = math.clamp((now - rolledAt) / math.max(stopsAt - rolledAt, 0.01), 0, 1)
	return last * easeOut(t), last
end

-- What a reel shows at a place in its column: the previous result first,
-- the new one at the end (and nothing after it), and companies rolling past
-- in between, the same on every screen for the same roll.
local function resultAt(roll: Roll, reel: number, place: number, last: number): Result?
	if place == last then
		return roll.results[reel]
	elseif place > last then
		return nil
	elseif place <= 0 and roll.previous[reel] then
		return roll.previous[reel]
	end
	if #fillers == 0 then
		return nil
	end
	local seed = math.floor(roll.rolledAt or 0)
	return { companyId = fillers[(place * 7 + reel * 11 + seed) % #fillers + 1], variant = nil }
end

local function newTile(parent: Instance): Tile
	local frame = Instance.new("Frame")
	frame.Name = "Tile"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Theme.Base.SpinnerScreen
	frame.Parent = parent
	local name = Make.label(frame, {
		font = Theme.Fonts.Display,
		colour = Theme.Colours.TextOnColour,
		outline = true,
	})
	name.Name = "Company"
	name.Position = UDim2.fromScale(0.06, 0.12)
	name.Size = UDim2.fromScale(0.88, 0.5)
	name.TextScaled = true
	local line = Make.label(frame, {
		font = Theme.Fonts.Body,
		colour = Theme.Colours.TextOnColour,
		outline = true,
	})
	line.Name = "Line"
	line.Position = UDim2.fromScale(0.06, 0.64)
	line.Size = UDim2.fromScale(0.88, 0.24)
	line.TextScaled = true
	return { frame = frame, name = name, line = line, shown = nil }
end

local function showOnTile(tile: Tile, result: Result?, place: number)
	if tile.shown == place then
		return
	end
	tile.shown = place
	local company = if result then Companies.byId[result.companyId] else nil
	local tier = if company then Tiers.byId[company.tier] else nil
	local variant = if result and result.variant then Variants.byId[result.variant] else nil
	tile.frame.BackgroundColor3 = if tier then Theme.shade(tier.color, 0.15) else Theme.Base.SpinnerScreen
	tile.name.Text = if company then company.name else ""
	tile.line.Text = if variant and tier then `{variant.name} {tier.name}` elseif tier then tier.name else ""
	tile.line.TextColor3 = if variant then Theme.tint(variant.colour, 0.3) else Theme.Colours.TextOnColour
end

-- Draws the reels for this roll at this moment (server time), and returns
-- whether each has stopped.
local function draw(self: Reels, roll: Roll, now: number): { boolean }
	local stopped = {}
	for index, pair in self.tiles do
		local place, last = Reels.placeOf(roll, index, #self.tiles, now)
		local whole = math.floor(place)
		local along = place - whole
		showOnTile(pair[1], resultAt(roll, index, whole, last), whole)
		pair[1].frame.Position = UDim2.fromScale(0, -along)
		showOnTile(pair[2], resultAt(roll, index, whole + 1, last), whole + 1)
		pair[2].frame.Position = UDim2.fromScale(0, 1 - along)
		stopped[index] = roll.rolledAt == nil or now >= roll.landsAt - (#self.tiles - index) * REEL_GAP
	end
	return stopped
end

-- Makes count reels side by side, filling parent, with gap pixels between
-- them.
function Reels.new(parent: GuiObject, count: number, gap: number): Reels
	local frame = Instance.new("Frame")
	frame.Name = "Reels"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local layout = Make.list(frame, Enum.FillDirection.Horizontal, gap)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local windows, tiles = {}, {}
	for index = 1, count do
		local window = Instance.new("Frame")
		window.Name = `Reel{index}`
		window.LayoutOrder = index
		window.Size = UDim2.new(1 / count, -gap * (count - 1) / count, 1, 0)
		window.BackgroundColor3 = Theme.Base.SpinnerScreen
		window.ClipsDescendants = true
		Make.corner(window)
		window.Parent = frame
		table.insert(windows, window)
		table.insert(tiles, { newTile(window), newTile(window) })
	end
	local reels = { frame = frame, windows = windows, tiles = tiles, draw = draw }
	return reels
end

-- A new roll draws every tile afresh.
function Reels.reset(reels: Reels)
	for _, pair in reels.tiles do
		for _, tile in pair do
			tile.shown = nil
		end
	end
end

return Reels
