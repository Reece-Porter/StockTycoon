--!strict
-- Admin-only debug panel: a "Debug" button at the top of the screen that opens
-- a small window of live values. The server decides who sees it (the IsAdmin
-- attribute) and publishes each row as a "Debug_<name>" attribute on the
-- player, so rows added in later slices show up here without client changes.

local Players = game:GetService("Players")

local PREFIX = "Debug_"
local MARGIN = 8
local BUTTON_HEIGHT = 44
local MAX_PANEL_WIDTH = 360

local player = Players.LocalPlayer

local DebugPanelController = {}

local function addCorner(parent: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = parent
end

local function renderRows(panel: Frame)
	for _, child in panel:GetChildren() do
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
		local label = Instance.new("TextLabel")
		label.Name = name
		label.LayoutOrder = index
		label.Size = UDim2.fromScale(1, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.BuilderSans
		label.TextSize = 16
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = `{string.sub(name, #PREFIX + 1)}: {tostring(player:GetAttribute(name))}`
		label.Parent = panel
	end
end

local function createPanel()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100

	local toggle = Instance.new("TextButton")
	toggle.Name = "Toggle"
	toggle.AnchorPoint = Vector2.new(0.5, 0)
	toggle.Position = UDim2.new(0.5, 0, 0, MARGIN)
	toggle.Size = UDim2.fromOffset(96, BUTTON_HEIGHT)
	toggle.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	toggle.BackgroundTransparency = 0.2
	toggle.Font = Enum.Font.BuilderSansBold
	toggle.TextSize = 18
	toggle.TextColor3 = Color3.new(1, 1, 1)
	toggle.Text = "Debug"
	addCorner(toggle)
	toggle.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, MARGIN + BUTTON_HEIGHT + MARGIN)
	panel.Size = UDim2.new(1, -2 * MARGIN, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	addCorner(panel)
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(MAX_PANEL_WIDTH, math.huge)
	sizeLimit.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	renderRows(panel)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, #PREFIX) == PREFIX then
			renderRows(panel)
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
