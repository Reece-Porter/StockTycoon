--!strict
-- Admin-only debug panel: a "Debug" button in the top right corner of the
-- screen that opens a panel of live values. The server decides who sees it
-- (the IsAdmin attribute) and publishes each row as a "Debug_<name>"
-- attribute on the player, so rows added in later slices show up here without
-- client changes. A "UI kit" button at the top opens every UI kit piece on one
-- screen (Ui/Kit/Gallery), for checking the visual pass in the device
-- emulator.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Gallery = require(script.Parent.Parent.Ui.Kit.Gallery)
local Make = require(script.Parent.Parent.Ui.Kit.Make)

local PREFIX = "Debug_"
local TOGGLE_SIZE = UDim2.fromOffset(96, Theme.Size.Touch)
local MAX_PANEL_SIZE = Vector2.new(360, 520)

local player = Players.LocalPlayer

local DebugPanelController = {}

local function renderRows(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local names = {}
	for name in player:GetAttributes() do
		if string.sub(name, 1, #PREFIX) == PREFIX then
			table.insert(names, name)
		end
	end
	table.sort(names)

	for index, name in names do
		local label = Make.label(list, {
			text = `<b>{string.sub(name, #PREFIX + 1)}</b>  {tostring(player:GetAttribute(name))}`,
			size = Theme.TextSize.Small,
			colour = Theme.Colours.Text,
			alignX = Enum.TextXAlignment.Left,
			wrapped = true,
		})
		label.Name = name
		label.RichText = true
		label.LayoutOrder = index
		label.Size = UDim2.fromScale(1, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
	end
end

local function createPanel()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugPanel"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 100

	local toggle = Button.new({
		text = "Debug",
		colour = Theme.Colours.Ink,
		size = TOGGLE_SIZE,
		textSize = Theme.TextSize.Body,
	})
	toggle.Instance.AnchorPoint = Vector2.new(1, 0)
	toggle.Instance.Position = UDim2.new(1, -Theme.Layout.Margin, 0, Theme.Layout.TopGap)
	toggle.Instance.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -Theme.Layout.Margin, 0, Theme.Layout.TopGap + Theme.Size.Touch + Theme.Size.Gap)
	panel.Size = UDim2.new(1, -2 * Theme.Layout.Margin, 0.8, 0)
	panel.BackgroundColor3 = Theme.Colours.Panel
	panel.Active = true
	panel.Visible = false
	Make.corner(panel, Theme.Corner.Medium)
	Make.outline(panel, Theme.Colours.Ink, Theme.Stroke.Normal)
	panel.Parent = gui
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = MAX_PANEL_SIZE
	sizeLimit.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Theme.Colours.Ink
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	Make.padding(list, Theme.Size.Padding)
	Make.list(list, Enum.FillDirection.Vertical, 6)

	local kit = Button.new({
		text = "UI kit",
		colour = Theme.Colours.Purple,
		size = UDim2.new(1, 0, 0, Theme.Size.Touch),
		textSize = Theme.TextSize.Body,
		layoutOrder = 0,
	})
	kit.Instance.Parent = list
	kit.Activated:Connect(function()
		panel.Visible = false
		Gallery.open()
	end)

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	renderRows(list)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, #PREFIX) == PREFIX then
			renderRows(list)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function DebugPanelController:Start()
	if player:GetAttribute("IsAdmin") == true then
		createPanel()
		return
	end

	local connection: RBXScriptConnection? = nil
	connection = player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
		if player:GetAttribute("IsAdmin") == true and connection then
			connection:Disconnect()
			createPanel()
		end
	end)
end

return DebugPanelController
