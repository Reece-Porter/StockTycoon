--!strict
-- Hostile Takeovers on this player's screen (docs/design.md, "Stealing";
-- TakeoverService on the server). A chip above the Cash pill counts down to
-- the next one (in gold for the last few minutes), and while one is on it
-- turns red with the time left and a bar running down. When one starts, a
-- red banner across the screen says so. Reads Workspace's TakeoverEndsAt and
-- TakeoverNextAt attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local StealConfig = require(ReplicatedStorage.Shared.Config.Steal)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Celebration = require(script.Parent.Parent.Ui.Celebration)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)

local CHIP_HEIGHT = 36
local BAR_HEIGHT = 4
local UPDATE_SECONDS = 0.25
-- The chip turns gold this long before a takeover starts.
local SOON_SECONDS = StealConfig.Takeover.WarnSeconds[1] or 300

local player = Players.LocalPlayer

local TakeoverController = {}

local chip: Frame
local text: TextLabel
-- The outline round the letters, only on a coloured chip.
local letters: UIStroke
local fill: Frame
local track: Frame
local wasOn = false

local function numberAttribute(name: string): number?
	local value = workspace:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

local function build()
	chip = Instance.new("Frame")
	chip.Name = "Takeover"
	chip.Size = UDim2.fromOffset(0, CHIP_HEIGHT)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundColor3 = Theme.Colours.Card
	chip.Visible = false
	Make.corner(chip)
	Make.outline(chip, Theme.Colours.Ink, Theme.Stroke.Thick)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.fromScale(0, 1)
	content.AutomaticSize = Enum.AutomaticSize.X
	content.BackgroundTransparency = 1
	Make.padding(content, 0, 10)
	content.Parent = chip
	local layout = Make.list(content, Enum.FillDirection.Horizontal, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local icon = Icons.make("Padlock", 22)
	icon.LayoutOrder = 1
	icon.Parent = content
	text = Make.label(content, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Small,
		colour = Theme.Colours.Text,
	})
	text.Name = "Text"
	letters = Make.textOutline(text)
	text.LayoutOrder = 2
	text.Size = UDim2.fromScale(0, 1)
	text.AutomaticSize = Enum.AutomaticSize.X
	track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -3)
	track.Size = UDim2.new(1, -20, 0, BAR_HEIGHT)
	track.BackgroundColor3 = Theme.shade(Theme.Colours.Danger, 0.4)
	track.Visible = false
	Make.corner(track)
	track.Parent = chip
	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Theme.Colours.Card
	Make.corner(fill)
	fill.Parent = track
	Menu.addBottomLeft(chip, 0)
end

-- Shows the chip as it is at this moment (server time).
function TakeoverController.render(now: number)
	local endsAt = numberAttribute("TakeoverEndsAt")
	local nextAt = numberAttribute("TakeoverNextAt")
	local on = endsAt ~= nil and endsAt > now
	chip.Visible = on or nextAt ~= nil
	track.Visible = on
	if on and endsAt then
		chip.BackgroundColor3 = Theme.Colours.Danger
		text.TextColor3 = Theme.Colours.TextOnColour
		text.Text = `TAKEOVER!  {Format.duration(endsAt - now)}`
		local length = StealConfig.Takeover.DurationSeconds
		fill.Size = UDim2.fromScale(math.clamp((endsAt - now) / length, 0, 1), 1)
	elseif nextAt then
		local left = nextAt - now
		local soon = left <= SOON_SECONDS
		chip.BackgroundColor3 = if soon then Theme.Colours.Gold else Theme.Colours.Card
		text.TextColor3 = if soon then Theme.Colours.TextOnColour else Theme.Colours.Text
		text.Text = `Takeover in {Format.duration(left)}`
	end
	letters.Enabled = text.TextColor3 == Theme.Colours.TextOnColour
end

-- The banner when a takeover starts (not when the player joins during one).
function TakeoverController.changed(now: number): ScreenGui?
	local endsAt = numberAttribute("TakeoverEndsAt")
	local on = endsAt ~= nil and endsAt > now
	local started = on and not wasOn
	wasOn = on
	TakeoverController.render(now)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not started or endsAt == nil or playerGui == nil then
		return nil
	end
	return Celebration.play(
		playerGui,
		"HOSTILE TAKEOVER!",
		`Steal from other bases for {Format.longDuration(endsAt - now + 0.5)}!`,
		{ colour = Theme.Colours.Danger, confetti = false }
	)
end

function TakeoverController:Start()
	build()
	local endsAt = numberAttribute("TakeoverEndsAt")
	wasOn = endsAt ~= nil and endsAt > workspace:GetServerTimeNow()
	workspace:GetAttributeChangedSignal("TakeoverEndsAt"):Connect(function()
		TakeoverController.changed(workspace:GetServerTimeNow())
	end)
	while true do
		TakeoverController.render(workspace:GetServerTimeNow())
		task.wait(UPDATE_SECONDS)
	end
end

return TakeoverController
