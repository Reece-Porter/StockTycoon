--!strict
-- The battle's pick pop-up (docs/design.md, "Battle arena"): the round
-- number, three reels (Ui/Reels) that spin and stop on this round's stocks,
-- then a Pick button under each with what it's worth, and a bar running
-- down to when picks close. Picking one lights its reel and greys the rest.
-- Looks only: the server rolled the stocks and decides the pick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattleMath = require(ReplicatedStorage.Shared.BattleMath)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Button = require(script.Parent.Kit.Button)
local Layout = require(script.Parent.Layout)
local Make = require(script.Parent.Kit.Make)
local Reels = require(script.Parent.Reels)

-- Over the HUD and menus (40), under windows (60) and notifications (200).
local DISPLAY_ORDER = 50
local WIDTH, HEIGHT = 460, 330
local REEL_HEIGHT = 140
local BUTTON_HEIGHT = 50

export type Popup = {
	gui: ScreenGui,
	-- Draws it at this moment (server time); false once it's closed.
	step: (now: number) -> boolean,
	close: () -> (),
	-- The pick the server took (shown as picked).
	picked: (index: number) -> (),
}

local BattlePick = {}

-- Opens the pop-up for this round. onPick is called with the reel number
-- the player picks.
function BattlePick.open(
	playerGui: Instance,
	round: number,
	rounds: number,
	roll: Reels.Roll,
	pickBy: number,
	onPick: (number) -> ()
): Popup
	local gui = Instance.new("ScreenGui")
	gui.Name = "BattlePick"
	gui.DisplayOrder = DISPLAY_ORDER
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local room = Layout.viewport().X / Layout.scale() - 2 * Theme.Layout.Margin
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.48)
	panel.Size = UDim2.fromOffset(math.min(WIDTH, room), HEIGHT)
	panel.BackgroundColor3 = Theme.Base.Spinner
	Make.corner(panel, Theme.Corner.Large)
	Make.outline(panel, Theme.Colours.Ink, Theme.Stroke.Thick)
	Layout.scaled(panel)
	panel.Parent = gui

	local title = Make.label(panel, {
		text = `ROUND {round} OF {rounds}`,
		font = Theme.Fonts.Display,
		colour = Theme.Colours.Gold,
		outline = true,
	})
	title.Name = "Title"
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, 34)
	title.TextScaled = true

	local area = Instance.new("Frame")
	area.Name = "ReelArea"
	area.Position = UDim2.fromOffset(16, 52)
	area.Size = UDim2.new(1, -32, 0, REEL_HEIGHT)
	area.BackgroundTransparency = 1
	area.Parent = panel
	local reels = Reels.new(area, #roll.results, 10)
	local frames: { UIStroke } = {}
	for _, window in reels.windows do
		table.insert(frames, Make.outline(window, Theme.Colours.Gold, Theme.Stroke.Normal))
	end

	-- A Pick button under each reel, with what it's worth.
	local row = Instance.new("Frame")
	row.Name = "Picks"
	row.Position = UDim2.fromOffset(16, 52 + REEL_HEIGHT + 10)
	row.Size = UDim2.new(1, -32, 0, BUTTON_HEIGHT)
	row.BackgroundTransparency = 1
	row.Parent = panel
	local rowLayout = Make.list(row, Enum.FillDirection.Horizontal, 10)
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local count = #roll.results
	local buttons: { Button.Button } = {}
	local chosen: number? = nil

	local function showPicked(index: number)
		chosen = index
		for other, button in buttons do
			button.setEnabled(false)
			button.setText(if other == index then "Picked!" else "")
			button.Instance.Visible = other == index
			frames[other].Color = if other == index then Theme.Colours.Gold else Theme.Base.BulbOff
			frames[other].Thickness = if other == index then Theme.Stroke.Thick * 1.5 else Theme.Stroke.Thin
		end
	end

	for index, result in roll.results do
		local button = Button.new({
			text = `Pick {Format.cash(BattleMath.value(result.companyId, result.variant))}`,
			colour = Theme.Colours.Cash,
			size = UDim2.new(1 / count, -10 * (count - 1) / count, 1, 0),
			textSize = Theme.TextSize.Body,
			layoutOrder = index,
		})
		button.Instance.Name = `Pick{index}`
		button.Instance.Visible = false
		button.Instance.Parent = row
		button.Activated:Connect(function()
			if chosen == nil then
				showPicked(index)
				onPick(index)
			end
		end)
		table.insert(buttons, button)
	end

	local footer = Make.label(panel, {
		text = "Spinning...",
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Button,
		colour = Theme.Colours.TextOnColour,
		outline = true,
	})
	footer.Name = "Footer"
	footer.Position = UDim2.fromOffset(16, HEIGHT - 58)
	footer.Size = UDim2.new(1, -32, 0, 28)

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.new(0, 16, 1, -22)
	track.Size = UDim2.new(1, -32, 0, 8)
	track.BackgroundColor3 = Theme.Base.SpinnerScreen
	Make.corner(track)
	track.Parent = panel
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Theme.Colours.Gold
	Make.corner(fill)
	fill.Parent = track

	gui.Parent = playerGui

	local open = true
	local function close()
		if open then
			open = false
			gui:Destroy()
		end
	end

	local function step(now: number): boolean
		if not open then
			return false
		end
		local stopped = reels:draw(roll, now)
		local allStopped = true
		for _, done in stopped do
			allStopped = allStopped and done
		end
		if allStopped and chosen == nil then
			for _, button in buttons do
				button.Instance.Visible = true
			end
			footer.Text = "Pick one!"
		elseif chosen then
			footer.Text = "Picked! Waiting for the others..."
		end
		local window = math.max(pickBy - roll.landsAt, 0.01)
		fill.Size = UDim2.fromScale(math.clamp((pickBy - math.max(now, roll.landsAt)) / window, 0, 1), 1)
		return open
	end

	return {
		gui = gui,
		step = step,
		close = close,
		picked = function(index: number)
			if chosen == nil and buttons[index] then
				showPicked(index)
			end
		end,
	}
end

return BattlePick
