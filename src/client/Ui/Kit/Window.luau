--!strict
-- The window every screen uses: a centred panel with a coloured header, its
-- title, a round red close button top right, a light body and optional tabs.
-- It pops open with a quick scale-and-fade and dims the screen behind it;
-- tapping the dimmed part closes it. Parent Gui to the PlayerGui after making
-- it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Icons = require(script.Parent.Icons)
local Make = require(script.Parent.Make)

local CLOSE_SIZE = 40
local TAB_HEIGHT = Theme.Size.Touch
-- Room inside the panel's edge for its outline.
local EDGE = math.ceil(Theme.Stroke.Thick)

export type Props = {
	title: string,
	-- The header colour.
	colour: Color3?,
	-- The largest the panel gets, in pixels; on small screens it fills most
	-- of the screen instead.
	maxSize: Vector2?,
	tabs: { string }?,
	displayOrder: number?,
	-- Runs when a tab is chosen (and for the first tab when it opens).
	onTab: ((name: string) -> ())?,
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
}

export type Window = {
	Gui: ScreenGui,
	-- Where the window's contents go.
	Body: Frame,
	Title: TextLabel,
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	selectTab: (name: string) -> (),
	-- The tab showing, if it has tabs.
	tab: () -> string?,
	setTitle: (title: string) -> (),
}

local Window = {}

function Window.new(props: Props): Window
	local colour = props.colour or Theme.Colours.Primary
	local maxSize = props.maxSize or Vector2.new(560, 480)

	local gui = Instance.new("ScreenGui")
	gui.Name = props.title
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = props.displayOrder or 60
	gui.Enabled = false

	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Theme.Colours.Dim
	dim.BackgroundTransparency = 1
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.Parent = gui

	-- The panel is a CanvasGroup so the whole thing can fade together.
	local panel = Instance.new("CanvasGroup")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.92, 0.84)
	panel.BackgroundTransparency = 1
	-- Above the dimmed background, and taps on it stay on it (they'd close
	-- the window if they reached the background).
	panel.ZIndex = 2
	panel.Active = true
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = maxSize
	limit.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local surface = Instance.new("Frame")
	surface.Name = "Surface"
	surface.Position = UDim2.fromOffset(EDGE, EDGE)
	surface.Size = UDim2.new(1, -2 * EDGE, 1, -2 * EDGE)
	surface.BackgroundColor3 = Theme.Colours.Panel
	surface.Active = true
	Make.corner(surface, Theme.Corner.Large)
	Make.outline(surface, Theme.Colours.Ink, Theme.Stroke.Thick)
	surface.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, Theme.Size.HeaderHeight)
	header.BackgroundColor3 = colour
	Make.corner(header, Theme.Corner.Large)
	header.Parent = surface
	-- Squares off the header's bottom corners.
	local square = Instance.new("Frame")
	square.Position = UDim2.fromScale(0, 0.5)
	square.Size = UDim2.fromScale(1, 0.5)
	square.BackgroundColor3 = colour
	square.BorderSizePixel = 0
	square.Parent = header
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.AnchorPoint = Vector2.new(0, 1)
	line.Position = UDim2.fromScale(0, 1)
	line.Size = UDim2.new(1, 0, 0, EDGE)
	line.BackgroundColor3 = Theme.Colours.Ink
	line.BorderSizePixel = 0
	line.Parent = header

	local title = Make.label(header, {
		text = props.title,
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Title,
		colour = Theme.Colours.TextOnColour,
		outline = true,
		alignX = Enum.TextXAlignment.Left,
	})
	title.Position = UDim2.fromOffset(Theme.Size.Padding + 4, 0)
	title.Size = UDim2.new(1, -(CLOSE_SIZE + 3 * Theme.Size.Padding), 1, 0)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	-- Above the strip that squares off the header.
	title.ZIndex = 2

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -Theme.Size.Padding, 0.5, 0)
	close.Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE)
	close.BackgroundColor3 = Theme.Colours.Danger
	close.AutoButtonColor = false
	close.Text = ""
	close.ZIndex = 2
	Make.corner(close)
	Make.outline(close, Theme.Colours.Ink, Theme.Stroke.Normal)
	Make.shine(close)
	local cross = Icons.make("Cross", math.floor(CLOSE_SIZE * 0.7))
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	cross.Parent = close
	close.Parent = header

	local top = Theme.Size.HeaderHeight
	local tabButtons: { [string]: TextButton } = {}
	local tabNames: { string } = props.tabs or {}
	if #tabNames > 0 then
		local row = Instance.new("Frame")
		row.Name = "Tabs"
		row.Position = UDim2.fromOffset(Theme.Size.Padding, top + Theme.Size.Gap)
		row.Size = UDim2.new(1, -2 * Theme.Size.Padding, 0, TAB_HEIGHT)
		row.BackgroundTransparency = 1
		row.Parent = surface
		Make.list(row, Enum.FillDirection.Horizontal, Theme.Size.Gap)
		local count = #tabNames
		for order, name in tabNames do
			local tab = Instance.new("TextButton")
			tab.Name = name
			tab.LayoutOrder = order
			tab.Size = UDim2.new(1 / count, -Theme.Size.Gap * (count - 1) / count, 1, 0)
			tab.AutoButtonColor = false
			tab.Font = Theme.Fonts.Display
			tab.TextSize = Theme.TextSize.Body
			tab.Text = name
			Make.corner(tab, Theme.Corner.Small)
			Make.outline(tab, Theme.Colours.Ink, Theme.Stroke.Normal)
			tab.Parent = row
			tabButtons[name] = tab
		end
		top += Theme.Size.Gap + TAB_HEIGHT
	end

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, top)
	body.Size = UDim2.new(1, 0, 1, -top)
	body.BackgroundTransparency = 1
	body.Parent = surface
	Make.padding(body, Theme.Size.Padding)

	local isOpen = false
	local currentTab: string? = nil

	local function selectTab(name: string)
		if not tabButtons[name] then
			return
		end
		currentTab = name
		for tabName, tab in tabButtons do
			local selected = tabName == name
			tab.BackgroundColor3 = if selected then colour else Theme.Colours.Card
			tab.TextColor3 = if selected then Theme.Colours.TextOnColour else Theme.Colours.Text
		end
		if props.onTab then
			props.onTab(name)
		end
	end
	for name, tab in tabButtons do
		tab.Activated:Connect(function()
			selectTab(name)
		end)
	end

	local function open()
		if isOpen then
			return
		end
		isOpen = true
		gui.Enabled = true
		if currentTab == nil and #tabNames > 0 then
			selectTab(tabNames[1])
		end
		if props.onOpen then
			props.onOpen()
		end
		scale.Scale = Theme.Tween.OpenScale
		panel.GroupTransparency = 1
		dim.BackgroundTransparency = 1
		local pop = TweenInfo.new(Theme.Tween.Open, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local fade = TweenInfo.new(Theme.Tween.Open, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(scale, pop, { Scale = 1 }):Play()
		TweenService:Create(panel, fade, { GroupTransparency = 0 }):Play()
		TweenService:Create(dim, fade, { BackgroundTransparency = Theme.DimTransparency }):Play()
	end

	local function closeWindow()
		if not isOpen then
			return
		end
		isOpen = false
		local shrink = TweenInfo.new(Theme.Tween.Open * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(scale, shrink, { Scale = Theme.Tween.OpenScale }):Play()
		TweenService:Create(dim, shrink, { BackgroundTransparency = 1 }):Play()
		local fade = TweenService:Create(panel, shrink, { GroupTransparency = 1 })
		fade.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not isOpen then
				gui.Enabled = false
			end
		end)
		fade:Play()
		if props.onClose then
			props.onClose()
		end
	end

	close.Activated:Connect(closeWindow)
	dim.Activated:Connect(closeWindow)

	return {
		Gui = gui,
		Body = body,
		Title = title,
		open = open,
		close = closeWindow,
		isOpen = function()
			return isOpen
		end,
		selectTab = selectTab,
		tab = function()
			return currentTab
		end,
		setTitle = function(text: string)
			title.Text = text
		end,
	}
end

return Window
