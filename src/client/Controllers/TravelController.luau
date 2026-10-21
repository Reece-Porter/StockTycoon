--!strict
-- The teleport buttons at the top of the screen, first in the top stack
-- (Config/Travel): Home, Upgrades and Weapons. The server checks each
-- teleport (TravelService); the buttons grey out while the player is
-- carrying a company or waiting for the next teleport.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local TravelConfig = require(ReplicatedStorage.Shared.Config.Travel)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)

-- Three fit between the side menus on a small phone.
local BUTTON_SIZE = UDim2.fromOffset(88, Theme.Size.Touch)
local GAP = 4
local UPDATE_SECONDS = 0.25

local LOOKS: { [string]: { icon: Icons.IconName, colour: Color3 } } = {
	Home = { icon = "Home", colour = Theme.Colours.Primary },
	Upgrades = { icon = "Arrow", colour = Theme.Menu.Upgrades },
	Weapons = { icon = "Weapon", colour = Theme.Menu.Weapons },
}

local player = Players.LocalPlayer

local TravelController = {}

function TravelController:Start()
	local row = Instance.new("Frame")
	row.Name = "Teleports"
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.BackgroundTransparency = 1
	Make.list(row, Enum.FillDirection.Horizontal, GAP)

	local buttons: { [string]: Button.Button } = {}
	for order, place in TravelConfig.Places do
		local look = LOOKS[place] or { icon = "Arrow" :: Icons.IconName, colour = Theme.Colours.Primary }
		local button = Button.new({
			text = place,
			icon = look.icon,
			colour = look.colour,
			size = BUTTON_SIZE,
			textSize = Theme.TextSize.Small,
			layoutOrder = order,
		})
		button.Instance.Parent = row
		button.Activated:Connect(function()
			Remotes.Travel:FireServer(place)
		end)
		buttons[place] = button
	end
	Menu.addTop(row, 1)

	while true do
		local readyAt = player:GetAttribute("TravelReadyAt")
		local left = if typeof(readyAt) == "number" then readyAt - workspace:GetServerTimeNow() else 0
		local carrying = player:GetAttribute("CarryingCompanyId") ~= nil
		for place, button in buttons do
			button.setEnabled(not carrying and left <= 0)
			button.setText(if left > 0 then `{math.ceil(left)}s` else place)
		end
		task.wait(UPDATE_SECONDS)
	end
end

return TravelController
