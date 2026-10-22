--!strict
-- The photo booth's cameras (docs/visual-pass.md, Phase 10; Lib/PhotoBooth on
-- the server). When an admin types /boothcam icon, wide or base, the server
-- sets their BoothCamera attribute and this player's screen looks through
-- that camera in Workspace.Map.PhotoBooth.Cameras, at its field of view,
-- with the game's screens and Roblox's own menus hidden so the shot is
-- clean. /boothcam free only hides them, for shots anywhere in the map.
-- /boothcam off puts everything back.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local WAIT_SECONDS = 5
local DEFAULT_FIELD_OF_VIEW = 70

local player = Players.LocalPlayer
-- The screens hidden for the shot, to show again after.
local hidden: { ScreenGui } = {}
local looking = false

local PhotoBoothController = {}

local function setCoreGui(enabled: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, enabled)
	end)
end

-- Hides the game's screens and Roblox's menus, once.
function PhotoBoothController.hideScreens()
	if not looking then
		looking = true
		local playerGui = player:FindFirstChild("PlayerGui")
		if playerGui then
			for _, gui in playerGui:GetChildren() do
				if gui:IsA("ScreenGui") and gui.Enabled then
					gui.Enabled = false
					table.insert(hidden, gui)
				end
			end
		end
		setCoreGui(false)
	end
end

function PhotoBoothController.lookThrough(marker: BasePart)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = marker.CFrame
	local fieldOfView = marker:GetAttribute("FieldOfView")
	camera.FieldOfView = if typeof(fieldOfView) == "number" then fieldOfView else DEFAULT_FIELD_OF_VIEW
	PhotoBoothController.hideScreens()
end

function PhotoBoothController.stopLooking()
	if not looking then
		return
	end
	looking = false
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = DEFAULT_FIELD_OF_VIEW
	end
	for _, gui in hidden do
		gui.Enabled = true
	end
	table.clear(hidden)
	setCoreGui(true)
end

local function onChanged()
	local shot = player:GetAttribute("BoothCamera")
	if typeof(shot) ~= "string" then
		PhotoBoothController.stopLooking()
		return
	end
	if shot == "Free" then
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = DEFAULT_FIELD_OF_VIEW
		end
		PhotoBoothController.hideScreens()
		return
	end
	-- The booth is far away, so it may still be streaming in.
	local map = workspace:WaitForChild("Map", WAIT_SECONDS)
	local booth = map and map:WaitForChild("PhotoBooth", WAIT_SECONDS)
	local cameras = booth and booth:WaitForChild("Cameras", WAIT_SECONDS)
	local marker = cameras and cameras:WaitForChild(`Camera_{shot}`, WAIT_SECONDS)
	if marker and marker:IsA("BasePart") and player:GetAttribute("BoothCamera") == shot then
		PhotoBoothController.lookThrough(marker)
	end
end

function PhotoBoothController:Start()
	player:GetAttributeChangedSignal("BoothCamera"):Connect(onChanged)
	onChanged()
end

return PhotoBoothController
