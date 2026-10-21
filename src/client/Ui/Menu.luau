--!strict
-- The pieces always on screen, in one ScreenGui, and the windows they open:
--   Top: a stack down the middle of the top of the screen (Cash, the teleport
--     buttons, the guide's banner). Notification toasts start just below it.
--   Left: a grid of square menu buttons, clear of the thumbstick: at the top
--     left in landscape, below the top stack in portrait.
--   Right: a column (Store, Codes), clear of the jump button.
-- Only one window is open at a time: opening one closes the others.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Button = require(script.Parent.Kit.Button)
local Icons = require(script.Parent.Kit.Icons)
local Make = require(script.Parent.Kit.Make)
local Toasts = require(script.Parent.Kit.Toasts)
local Window = require(script.Parent.Kit.Window)
local Layout = require(script.Parent.Layout)

export type Side = "Left" | "Right"

export type Props = {
	name: string,
	text: string,
	icon: Icons.IconName,
	colour: Color3,
	-- Position in its menu, top to bottom (then left to right).
	order: number,
	side: Side,
	-- A slow shine across it, for the Store.
	shine: boolean?,
}

export type MenuButton = {
	Instance: Frame,
	Activated: RBXScriptSignal,
	-- A red dot in the corner when something new is waiting.
	setDot: (on: boolean) -> (),
	setText: (text: string) -> (),
}

local DOT_SIZE = 18
-- The Store's shine: seconds to cross, then seconds before the next.
local SHINE_SECONDS = 0.9
local SHINE_PAUSE = 2.5

type Areas = { top: Frame, left: Frame, right: Frame }

local areas: Areas? = nil
local windows: { Window.Window } = {}

local Menu = {}

local function getAreas(): Areas
	if areas then
		return areas
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Menu"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 40

	local margin = Theme.Layout.Margin
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, Theme.Layout.TopGap)
	top.AutomaticSize = Enum.AutomaticSize.XY
	top.BackgroundTransparency = 1
	top.Parent = gui
	local topLayout = Make.list(top, Enum.FillDirection.Vertical, Theme.Layout.TopGap)
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Layout.scaled(top)

	local function side(name: string): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.AutomaticSize = Enum.AutomaticSize.XY
		frame.BackgroundTransparency = 1
		frame.Parent = gui
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(Theme.Layout.MenuButton, Theme.Layout.MenuButton)
		grid.CellPadding = UDim2.fromOffset(Theme.Layout.MenuGap, Theme.Layout.MenuGap)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.FillDirection = Enum.FillDirection.Horizontal
		grid.Parent = frame
		Layout.scaled(frame)
		return frame
	end
	local left = side("Left")
	local right = side("Right")

	-- Three across in landscape, at the top left so it stays well clear of
	-- the thumbstick; two across in portrait (where the screen is narrow),
	-- below the top stack. Notifications keep to the middle between them.
	Layout.watch(function()
		local portrait = Layout.portrait()
		local leftGrid = left:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		leftGrid.FillDirectionMaxCells = if portrait then 2 else 3
		local rightGrid = right:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		rightGrid.FillDirectionMaxCells = 1
		if portrait then
			local sideTop = Theme.Layout.PortraitSideTop * Layout.scale()
			left.AnchorPoint = Vector2.new(0, 0)
			left.Position = UDim2.fromOffset(margin, sideTop)
			right.AnchorPoint = Vector2.new(1, 0)
			right.Position = UDim2.new(1, -margin, 0, sideTop)
		else
			left.AnchorPoint = Vector2.new(0, 0)
			left.Position = UDim2.fromOffset(margin, Theme.Layout.TopGap)
			right.AnchorPoint = Vector2.new(1, 0.5)
			right.Position = UDim2.new(1, -margin, 0.45, 0)
		end
		Toasts.setWidth(Layout.centreWidth() * Layout.scale())
	end)

	-- Toasts start just below the top stack, however tall it is.
	local function placeToasts()
		Toasts.setTop(Theme.Layout.TopGap + top.AbsoluteSize.Y + Theme.Layout.TopGap)
	end
	top:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeToasts)
	placeToasts()

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local made: Areas = { top = top, left = left, right = right }
	areas = made
	return made
end

-- Puts a frame in the stack at the top of the screen (lowest order first).
function Menu.addTop(frame: GuiObject, order: number)
	frame.LayoutOrder = order
	frame.Parent = getAreas().top
end

-- A square menu button on the left or right.
function Menu.button(props: Props): MenuButton
	local made = Button.new({
		text = props.text,
		icon = props.icon,
		colour = props.colour,
		stacked = true,
		layoutOrder = props.order,
	})
	local holder = made.Instance
	holder.Name = props.name

	local dot = Icons.make("Dot", DOT_SIZE)
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -4, 0, 4)
	dot.ZIndex = 5
	dot.Visible = false
	dot.Parent = holder

	if props.shine then
		local face = holder:FindFirstChild("Face") :: GuiObject
		local sweep = Instance.new("Frame")
		sweep.Name = "Shine"
		sweep.Size = UDim2.fromScale(1, 1)
		sweep.BackgroundColor3 = Theme.Colours.Card
		sweep.ZIndex = 4
		Make.corner(sweep, Theme.Corner.Medium)
		local band = Instance.new("UIGradient")
		band.Rotation = 20
		band.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		band.Offset = Vector2.new(-1, 0)
		band.Parent = sweep
		sweep.Parent = face
		task.spawn(function()
			local across = TweenInfo.new(SHINE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			while sweep.Parent do
				band.Offset = Vector2.new(-1, 0)
				TweenService:Create(band, across, { Offset = Vector2.new(1, 0) }):Play()
				task.wait(SHINE_SECONDS + SHINE_PAUSE)
			end
		end)
	end

	local parent = getAreas()
	holder.Parent = if props.side == "Left" then parent.left else parent.right

	return {
		Instance = holder,
		Activated = made.Activated,
		setDot = function(on: boolean)
			dot.Visible = on
		end,
		setText = made.setText,
	}
end

-- Opens a window, closing any other.
function Menu.open(window: Window.Window)
	if not table.find(windows, window) then
		table.insert(windows, window)
	end
	for _, other in windows do
		if other ~= window and other.isOpen() then
			other.close()
		end
	end
	window.open()
end

-- Opens the window, or closes it if it's open.
function Menu.toggle(window: Window.Window)
	if window.isOpen() then
		window.close()
	else
		Menu.open(window)
	end
end

-- A window made with the kit, parented to the player's screen and known to
-- the menu.
function Menu.window(props: Window.Props): Window.Window
	local window = Window.new(props)
	window.Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(windows, window)
	return window
end

return Menu
