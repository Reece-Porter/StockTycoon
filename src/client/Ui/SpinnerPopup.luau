--!strict
-- The Stock Spinner pop-up on the player's own screen (docs/design.md,
-- "Stock Spinner") when they play their base's machine: a cabinet with the
-- machine's name, the player's Luck, a lever that pulls down, three reels
-- that roll and stop one by one on what the server rolled (Ui/Reels), each
-- flashing its tier's colour as it stops, and bulbs round the edge that
-- chase while it spins. Then it says the companies are on the belt, and
-- closes itself a few seconds later (or with a tap on Close). Looks only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local SpinnerMath = require(ReplicatedStorage.Shared.SpinnerMath)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)
local Button = require(script.Parent.Kit.Button)
local Layout = require(script.Parent.Layout)
local Make = require(script.Parent.Kit.Make)
local Reels = require(script.Parent.Reels)

-- Over the HUD and menus (40), under windows (60) and notifications (200).
local DISPLAY_ORDER = 50
local WIDTH, HEIGHT = 440, 300
local REEL_HEIGHT = 150
local BULBS = 12
local CHASE_STEPS = 10
-- How long it stays up once the reels have stopped.
local CLOSE_AFTER = 3
local LEVER_PULL = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local LEVER_BACK = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FLASH = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type Popup = {
	gui: ScreenGui,
	-- Draws it at this moment (server time); false once it's closed.
	step: (now: number) -> boolean,
	close: () -> (),
}

local SpinnerPopup = {}

local function tierColour(result: Reels.Result?): Color3
	local company = if result then Companies.byId[result.companyId] else nil
	local tier = if company then Tiers.byId[company.tier] else nil
	return if tier then tier.color else Theme.Colours.Gold
end

-- Opens the pop-up for this roll in playerGui.
function SpinnerPopup.open(playerGui: Instance, roll: Reels.Roll, luck: number): Popup
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpinnerPopup"
	gui.DisplayOrder = DISPLAY_ORDER
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Narrow enough for a phone held upright.
	local room = Layout.viewport().X / Layout.scale() - 2 * Theme.Layout.Margin
	local width = math.min(WIDTH, room)
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.45)
	panel.Size = UDim2.fromOffset(width, HEIGHT)
	panel.BackgroundColor3 = Theme.Base.Spinner
	Make.corner(panel, Theme.Corner.Large)
	Make.outline(panel, Theme.Colours.Ink, Theme.Stroke.Thick)
	Layout.scaled(panel)
	panel.Parent = gui

	local title = Make.label(panel, {
		text = "STOCK SPINNER",
		font = Theme.Fonts.Display,
		colour = Theme.Colours.Gold,
		outline = true,
	})
	title.Name = "Title"
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -150, 0, 34)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left

	local luckChip = Instance.new("Frame")
	luckChip.Name = "Luck"
	luckChip.AnchorPoint = Vector2.new(1, 0)
	luckChip.Position = UDim2.new(1, -16, 0, 12)
	luckChip.Size = UDim2.fromOffset(120, 30)
	luckChip.BackgroundColor3 = Theme.Colours.Gold
	Make.corner(luckChip)
	Make.outline(luckChip, Theme.Colours.Ink, Theme.Stroke.Normal)
	luckChip.Parent = panel
	local luckText = Make.label(luckChip, {
		text = `LUCK {SpinnerMath.luckText(luck)}`,
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Body,
		colour = Theme.Colours.Ink,
	})
	luckText.Name = "Text"

	-- The reels, each in a gold frame.
	local area = Instance.new("Frame")
	area.Name = "ReelArea"
	area.Position = UDim2.fromOffset(16, 56)
	area.Size = UDim2.new(1, -32, 0, REEL_HEIGHT)
	area.BackgroundTransparency = 1
	area.Parent = panel
	local reels = Reels.new(area, #roll.results, 10)
	local frames: { UIStroke } = {}
	for _, window in reels.windows do
		table.insert(frames, Make.outline(window, Theme.Colours.Gold, Theme.Stroke.Thick))
	end

	-- Bulbs along the top and bottom edges.
	local bulbs: { Frame } = {}
	for index = 1, BULBS do
		local bulb = Instance.new("Frame")
		bulb.Name = "Bulb"
		bulb.AnchorPoint = Vector2.new(0.5, 0.5)
		local along = (index - 1) % (BULBS / 2)
		local x = (along + 0.5) / (BULBS / 2)
		bulb.Position = if index <= BULBS / 2 then UDim2.new(x, 0, 0, 4) else UDim2.new(x, 0, 1, -4)
		bulb.Size = UDim2.fromOffset(10, 10)
		bulb.BackgroundColor3 = Theme.Base.Bulb
		Make.corner(bulb, 999)
		bulb.Parent = panel
		table.insert(bulbs, bulb)
	end

	-- The lever on the side, pulled as it opens.
	local lever = Instance.new("Frame")
	lever.Name = "Lever"
	lever.AnchorPoint = Vector2.new(0.5, 1)
	lever.Position = UDim2.new(1, 14, 0.5, 10)
	lever.Size = UDim2.fromOffset(8, 70)
	lever.BackgroundColor3 = Theme.Base.Roller
	Make.corner(lever)
	Make.outline(lever, Theme.Colours.Ink, Theme.Stroke.Normal)
	lever.Parent = panel
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0)
	knob.Size = UDim2.fromOffset(26, 26)
	knob.BackgroundColor3 = Theme.Colours.Danger
	Make.corner(knob, 999)
	Make.outline(knob, Theme.Colours.Ink, Theme.Stroke.Normal)
	knob.Parent = lever
	local pull = TweenService:Create(lever, LEVER_PULL, { Rotation = 150 })
	pull.Completed:Connect(function()
		TweenService:Create(lever, LEVER_BACK, { Rotation = 0 }):Play()
	end)
	pull:Play()

	local footer = Make.label(panel, {
		text = "Spinning...",
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Button,
		colour = Theme.Colours.TextOnColour,
		outline = true,
	})
	footer.Name = "Footer"
	footer.Position = UDim2.fromOffset(16, 56 + REEL_HEIGHT + 12)
	footer.Size = UDim2.new(1, -170, 0, 40)
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.TextWrapped = true

	local closeButton = Button.new({ text = "Close", colour = Theme.Colours.Cash, size = UDim2.fromOffset(130, 48) })
	closeButton.Instance.Name = "Close"
	closeButton.Instance.AnchorPoint = Vector2.new(1, 1)
	closeButton.Instance.Position = UDim2.new(1, -16, 1, -14)
	closeButton.Instance.Visible = false
	closeButton.Instance.Parent = panel

	gui.Parent = playerGui

	local open = true
	local stoppedBefore: { boolean } = {}
	local landedAt: number? = nil
	local popup: Popup

	local function close()
		if open then
			open = false
			gui:Destroy()
		end
	end
	closeButton.Activated:Connect(close)

	local function step(now: number): boolean
		if not open then
			return false
		end
		local stopped = reels:draw(roll, now)
		local allStopped = true
		for index, done in stopped do
			allStopped = allStopped and done
			if done and not stoppedBefore[index] then
				-- A reel stops: its frame flashes in its company's tier colour.
				local frame = frames[index]
				frame.Color = Theme.Colours.Card
				TweenService:Create(frame, FLASH, { Color = tierColour(roll.results[index]) }):Play()
			end
			stoppedBefore[index] = done
		end
		local chase = math.floor(now * CHASE_STEPS)
		for index, bulb in bulbs do
			local lit = allStopped or (chase + index) % 3 == 0
			bulb.BackgroundColor3 = if lit then Theme.Base.Bulb else Theme.Base.BulbOff
		end
		if allStopped and landedAt == nil then
			landedAt = now
			local special = 0
			for _, result in roll.results do
				if result.variant and Variants.byId[result.variant] then
					special += 1
				end
			end
			footer.Text = if special > 0 then "A variant! It's on your belt now." else "On your belt now!"
			footer.TextColor3 = Theme.tint(Theme.Colours.Cash, 0.2)
			closeButton.Instance.Visible = true
		end
		local since = if landedAt then now - landedAt else 0
		if landedAt and since >= CLOSE_AFTER then
			close()
		end
		return open
	end

	popup = { gui = gui, step = step, close = close }
	return popup
end

return SpinnerPopup
