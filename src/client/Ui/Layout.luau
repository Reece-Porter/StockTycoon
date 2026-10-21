--!strict
-- How big the always-on-screen pieces are on this screen. They're designed
-- for a small phone and grow (up to MAX_SCALE) on bigger screens, so a tablet
-- or PC doesn't get tiny buttons. Also says whether the screen is portrait,
-- for the side menus, and how wide the middle of the screen between them is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)

local MIN_SCALE = 1
local MAX_SCALE = 1.3
-- The screen size the pieces are designed for.
local DESIGN_SIZE = Vector2.new(700, 400)

local Layout = {}

function Layout.viewport(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else DESIGN_SIZE
end

function Layout.scale(): number
	local size = Layout.viewport()
	local long, short = math.max(size.X, size.Y), math.min(size.X, size.Y)
	return math.clamp(math.min(long / DESIGN_SIZE.X, short / DESIGN_SIZE.Y), MIN_SCALE, MAX_SCALE)
end

function Layout.portrait(): boolean
	local size = Layout.viewport()
	return size.Y > size.X
end

-- The width (before scaling) the middle of the screen has for the teleports,
-- the guide's banner and notifications: between the side menus in
-- landscape, where the left menu (two across) sits at the top, and nearly
-- the whole width in portrait, where the side menus sit below them.
function Layout.centreWidth(): number
	local width = Layout.viewport().X / Layout.scale()
	if Layout.portrait() then
		return width - 2 * Theme.Layout.Margin
	end
	local menu = 2 * Theme.Layout.MenuButton + Theme.Layout.MenuGap
	return width - 2 * (menu + Theme.Layout.Margin + Theme.Layout.MenuGap)
end

-- Runs callback now and whenever the screen changes size (a phone turned
-- round, a window resized).
function Layout.watch(callback: () -> ())
	local connection: RBXScriptConnection? = nil
	local function attach()
		if connection then
			connection:Disconnect()
		end
		local camera = workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(callback)
		end
		callback()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attach)
	attach()
end

-- A UIScale on the frame that keeps it at this screen's scale.
function Layout.scaled(frame: GuiObject): UIScale
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	Layout.watch(function()
		scale.Scale = Layout.scale()
	end)
	return scale
end

return Layout
