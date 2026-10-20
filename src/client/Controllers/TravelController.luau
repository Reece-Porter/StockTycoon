--!strict
-- The teleport buttons along the top of the screen (Config/Travel): Home,
-- Upgrades and Weapons. The server checks each teleport (TravelService); the
-- buttons go grey while the player is carrying a company or waiting for the
-- next teleport.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TravelConfig = require(ReplicatedStorage.Shared.Config.Travel)

local BUTTON_SIZE = Vector2.new(88, 40)
local GAP = 6
-- Above the notifications at the top of the screen.
local TOP_OFFSET = 8
local READY = Color3.fromRGB(50, 120, 200)
local WAITING = Color3.fromRGB(70, 70, 80)
local UPDATE_SECONDS = 0.25

local player = Players.LocalPlayer

local TravelController = {}

function TravelController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Travel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40

	local row = Instance.new("Frame")
	row.Name = "Buttons"
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, TOP_OFFSET)
	row.Size = UDim2.fromOffset(#TravelConfig.Places * BUTTON_SIZE.X + (#TravelConfig.Places - 1) * GAP, BUTTON_SIZE.Y)
	row.BackgroundTransparency = 1
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local buttons: { [string]: TextButton } = {}
	for order, place in TravelConfig.Places do
		local button = Instance.new("TextButton")
		button.LayoutOrder = order
		button.Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y)
		button.BackgroundColor3 = READY
		button.BackgroundTransparency = 0.1
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = 16
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Text = place
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button
		button.Parent = row
		button.Activated:Connect(function()
			Remotes.Travel:FireServer(place)
		end)
		buttons[place] = button
	end
	gui.Parent = player:WaitForChild("PlayerGui")

	while true do
		local readyAt = player:GetAttribute("TravelReadyAt")
		local left = if typeof(readyAt) == "number" then readyAt - workspace:GetServerTimeNow() else 0
		local carrying = player:GetAttribute("CarryingCompanyId") ~= nil
		for place, button in buttons do
			button.BackgroundColor3 = if carrying or left > 0 then WAITING else READY
			button.Text = if left > 0 then `{place} {math.ceil(left)}s` else place
		end
		task.wait(UPDATE_SECONDS)
	end
end

return TravelController
