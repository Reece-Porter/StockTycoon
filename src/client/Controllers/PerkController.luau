--!strict
-- The Upgrades window, opened from the prompt at the upgrade station
-- (Workspace.Map.Shops.UpgradeStation.ShopPrompt). One row per upgrade
-- (Config/Perks): its level, what it does now and at the next level, and a
-- button with the next level's cost. The server checks every purchase
-- (PerkService) and sends the levels in the PerkLevels attribute.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local PerkMath = require(ReplicatedStorage.Shared.PerkMath)
local Perks = require(ReplicatedStorage.Shared.Config.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PANEL_MAX_SIZE = Vector2.new(420, 560)
local ROW_HEIGHT = 76
local BACKGROUND = Color3.fromRGB(20, 20, 25)
local BUTTON_COLOUR = Color3.fromRGB(45, 45, 55)
local BUY = Color3.fromRGB(70, 150, 90)
local CANT_AFFORD = Color3.fromRGB(70, 70, 80)
local MAXED = Color3.fromRGB(60, 110, 70)

local player = Players.LocalPlayer

type Row = { perk: Perks.Perk, detail: TextLabel, action: TextButton }

local PerkController = {}

local function corner(parent: Instance, radius: number?)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius or 8)
	uiCorner.Parent = parent
end

local function button(text: string, colour: Color3): TextButton
	local newButton = Instance.new("TextButton")
	newButton.BackgroundColor3 = colour
	newButton.Font = Enum.Font.BuilderSansBold
	newButton.TextSize = 16
	newButton.TextColor3 = Color3.new(1, 1, 1)
	newButton.Text = text
	newButton.AutoButtonColor = true
	corner(newButton)
	return newButton
end

local function watchChild(parent: Instance, name: string, callback: (Instance) -> ())
	parent.ChildAdded:Connect(function(child)
		if child.Name == name then
			callback(child)
		end
	end)
	local existing = parent:FindFirstChild(name)
	if existing then
		callback(existing)
	end
end

local function levels(): { [string]: number }
	local json = player:GetAttribute("PerkLevels")
	if typeof(json) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

-- "+30%" for a multiplier of 1.3.
local function percent(multiplier: number): string
	return `+{math.floor((multiplier - 1) * 100 + 0.5)}%`
end

function PerkController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Upgrades"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 55

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.85)
	panel.BackgroundColor3 = BACKGROUND
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	corner(panel)
	panel.Parent = gui
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = PANEL_MAX_SIZE
	sizeLimit.Parent = panel

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.new(1, -80, 0, 44)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = 22
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Upgrades"
	title.Parent = panel

	local close = button("X", BUTTON_COLOUR)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(44, 44)
	close.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 56)
	list.Size = UDim2.new(1, -24, 1, -68)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	local rows: { Row } = {}
	for order, perk in Perks.list do
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
		row.BackgroundColor3 = BUTTON_COLOUR
		corner(row)
		row.Parent = list
		local detail = Instance.new("TextLabel")
		detail.Position = UDim2.fromOffset(10, 0)
		detail.Size = UDim2.new(1, -130, 1, 0)
		detail.BackgroundTransparency = 1
		detail.Font = Enum.Font.BuilderSansMedium
		detail.TextSize = 14
		detail.TextColor3 = Color3.new(1, 1, 1)
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.TextWrapped = true
		detail.RichText = true
		detail.Parent = row
		local action = button("", BUY)
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Position = UDim2.new(1, -8, 0.5, 0)
		action.Size = UDim2.fromOffset(108, 48)
		action.Parent = row
		action.Activated:Connect(function()
			Remotes.BuyPerk:FireServer(perk.id)
		end)
		table.insert(rows, { perk = perk, detail = detail, action = action })
	end

	local function refresh()
		local current = levels()
		local stats = player:FindFirstChild("leaderstats")
		local cashValue = stats and stats:FindFirstChild("Cash")
		local cash = if cashValue and cashValue:IsA("IntValue") then cashValue.Value else nil
		for _, row in rows do
			local perk = row.perk
			local level = current[perk.id] or 0
			local now = PerkMath.multiplier(perk.id, level)
			local cost = PerkMath.cost(perk.id, level)
			local effect = if cost
				then `{percent(now)} now, {percent(PerkMath.multiplier(perk.id, level + 1))} next`
				else `{percent(now)}, the most there is`
			row.detail.Text = `<b>{perk.name}</b>  Level {level}/{perk.maxLevel}\n{perk.description}\n{effect}`
			if cost == nil then
				row.action.Text = "Maxed"
				row.action.BackgroundColor3 = MAXED
				row.action.AutoButtonColor = false
			else
				local affordable = cash == nil or cash >= cost
				row.action.Text = Format.cash(cost)
				row.action.BackgroundColor3 = if affordable then BUY else CANT_AFFORD
				row.action.AutoButtonColor = true
			end
		end
	end

	close.Activated:Connect(function()
		panel.Visible = false
	end)
	player:GetAttributeChangedSignal("PerkLevels"):Connect(refresh)
	refresh()
	gui.Parent = player:WaitForChild("PlayerGui")
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.Visible then
				refresh()
			end
		end
	end)

	-- The station's prompt. The station is built by hand and streams in and
	-- out with distance, so watch for it rather than wait.
	local function addPrompt(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("UpgradeStationPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "UpgradeStationPrompt"
		prompt.ActionText = "Open"
		prompt.ObjectText = "Upgrades"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Perks.StationDistance
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			refresh()
			panel.Visible = true
		end)
		prompt.PromptHidden:Connect(function()
			panel.Visible = false
		end)
		prompt.Parent = part
	end
	watchChild(workspace:WaitForChild("Map"), "Shops", function(shops)
		watchChild(shops, "UpgradeStation", function(upgradeStation)
			watchChild(upgradeStation, "ShopPrompt", addPrompt)
		end)
	end)
end

return PerkController
