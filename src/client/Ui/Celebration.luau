--!strict
-- The rebirth celebration on this player's screen (docs/visual-pass.md,
-- Phase 9): a burst of light from the middle, confetti falling, and a big
-- banner with a title and a line under it. About three seconds. Also the
-- start of a Hostile Takeover, in red and without the confetti. It sits
-- under the menus, windows and notifications (a lower DisplayOrder), so it
-- never covers the HUD, and it never takes a tap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Make = require(script.Parent.Kit.Make)

-- Below the menus (40), windows (60) and notifications (200).
local DISPLAY_ORDER = 30
local SECONDS = 3
local CONFETTI = 36
local RAYS = 14
local CENTRE = UDim2.fromScale(0.5, 0.36)
local POP_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FALL = TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local AWAY_SECONDS = 0.3
local AWAY = TweenInfo.new(AWAY_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

export type Style = {
	-- The banner and burst colour; the rebirth colour if not given.
	colour: Color3?,
	confetti: boolean?,
}

local Celebration = {}

local function burst(gui: ScreenGui, colour: Color3)
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.AnchorPoint = Vector2.new(0.5, 0.5)
	flash.Position = CENTRE
	flash.Size = UDim2.fromOffset(60, 60)
	flash.BackgroundColor3 = colour
	flash.BackgroundTransparency = 0.2
	flash.BorderSizePixel = 0
	Make.corner(flash, 999)
	flash.Parent = gui
	TweenService:Create(flash, FADE, { Size = UDim2.fromOffset(700, 700), BackgroundTransparency = 1 }):Play()
	for index = 1, RAYS do
		local ray = Instance.new("Frame")
		ray.Name = "Ray"
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = CENTRE
		ray.Size = UDim2.fromOffset(10, 420)
		ray.Rotation = index * 180 / RAYS
		ray.BackgroundColor3 = Theme.tint(colour, 0.4)
		ray.BackgroundTransparency = 0.4
		ray.BorderSizePixel = 0
		ray.Parent = gui
		TweenService:Create(ray, FADE, { BackgroundTransparency = 1, Rotation = ray.Rotation + 30 }):Play()
	end
end

local function confetti(gui: ScreenGui)
	local colours = {
		Theme.Colours.Gold,
		Theme.Colours.Primary,
		Theme.Colours.Cash,
		Theme.Colours.Purple,
		Theme.Colours.Danger,
	}
	for index = 1, CONFETTI do
		local bit = Instance.new("Frame")
		bit.Name = "Confetti"
		bit.AnchorPoint = Vector2.new(0.5, 0.5)
		local x = (index - 0.5) / CONFETTI + (math.random() - 0.5) * 0.05
		bit.Position = UDim2.fromScale(x, -0.05 - math.random() * 0.25)
		bit.Size = UDim2.fromOffset(10, 6)
		bit.Rotation = math.random(0, 180)
		bit.BackgroundColor3 = colours[index % #colours + 1]
		bit.BorderSizePixel = 0
		bit.Parent = gui
		local drift = (math.random() - 0.5) * 0.15
		TweenService:Create(bit, FALL, {
			Position = UDim2.fromScale(x + drift, 1.1),
			Rotation = bit.Rotation + math.random(180, 540),
		}):Play()
	end
end

-- Plays the celebration in playerGui with this title and line, and returns
-- its ScreenGui (gone by itself after a few seconds).
function Celebration.play(playerGui: Instance, title: string, line: string, style: Style?): ScreenGui
	local colour = if style and style.colour then style.colour else Theme.Menu.Rebirth
	local gui = Instance.new("ScreenGui")
	gui.Name = "Celebration"
	gui.DisplayOrder = DISPLAY_ORDER
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	burst(gui, if style and style.colour then colour else Theme.Colours.Gold)
	if not style or style.confetti ~= false then
		confetti(gui)
	end

	-- The banner: a ribbon with the title, and the line under it.
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = CENTRE
	banner.Size = UDim2.fromOffset(420, 120)
	banner.BackgroundColor3 = colour
	banner.ZIndex = 5
	Make.corner(banner, Theme.Corner.Large)
	Make.outline(banner, Theme.Colours.Ink, Theme.Stroke.Thick)
	banner.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = banner
	local titleLabel = Make.label(banner, {
		text = title,
		font = Theme.Fonts.Display,
		colour = Theme.Colours.TextOnColour,
		outline = true,
	})
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.fromScale(0.05, 0.08)
	titleLabel.Size = UDim2.fromScale(0.9, 0.55)
	titleLabel.TextScaled = true
	titleLabel.ZIndex = 6
	local lineLabel = Make.label(banner, {
		text = line,
		colour = Theme.Colours.TextOnColour,
		size = Theme.TextSize.Body,
		outline = true,
	})
	lineLabel.Name = "Line"
	lineLabel.Position = UDim2.fromScale(0.05, 0.64)
	lineLabel.Size = UDim2.fromScale(0.9, 0.28)
	lineLabel.TextScaled = true
	lineLabel.ZIndex = 6

	gui.Parent = playerGui
	TweenService:Create(scale, POP_IN, { Scale = 1 }):Play()
	task.delay(SECONDS - AWAY_SECONDS, function()
		TweenService:Create(scale, AWAY, { Scale = 0 }):Play()
	end)
	task.delay(SECONDS, function()
		gui:Destroy()
	end)
	return gui
end

return Celebration
