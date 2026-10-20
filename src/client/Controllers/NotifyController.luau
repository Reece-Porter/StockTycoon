--!strict
-- Shows short messages from the server to this player, such as a reply to an
-- admin command, as a toast near the top of the screen that fades after a few
-- seconds. A new message replaces the one showing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SHOW_SECONDS = 3
local FADE = TweenInfo.new(0.3)
local TOP_OFFSET = 60
local MAX_WIDTH = 420
local BACKGROUND_TRANSPARENCY = 0.15

local player = Players.LocalPlayer

local NotifyController = {}

local function createToast(): TextLabel
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notifications"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 200

	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, TOP_OFFSET)
	toast.Size = UDim2.new(1, -16, 0, 0)
	toast.AutomaticSize = Enum.AutomaticSize.Y
	toast.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	toast.Font = Enum.Font.BuilderSansBold
	toast.TextSize = 18
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.TextWrapped = true
	toast.Visible = false
	toast.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(MAX_WIDTH, math.huge)
	sizeLimit.Parent = toast

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = toast

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = toast

	gui.Parent = player:WaitForChild("PlayerGui")
	return toast
end

function NotifyController:Start()
	local toast = createToast()
	local messageCount = 0
	local fade: Tween? = nil

	Remotes.Notify.OnClientEvent:Connect(function(message: string)
		messageCount += 1
		local thisMessage = messageCount

		if fade then
			fade:Cancel()
		end
		toast.Text = message
		toast.TextTransparency = 0
		toast.BackgroundTransparency = BACKGROUND_TRANSPARENCY
		toast.Visible = true

		task.delay(SHOW_SECONDS, function()
			if messageCount ~= thisMessage then
				return
			end
			local tween = TweenService:Create(toast, FADE, { TextTransparency = 1, BackgroundTransparency = 1 })
			fade = tween
			tween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and messageCount == thisMessage then
					toast.Visible = false
				end
			end)
			tween:Play()
		end)
	end)
end

return NotifyController
