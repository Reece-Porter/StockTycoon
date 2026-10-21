--!strict
-- The Codes menu button (right side, under Store) and its window: type a code
-- and press Redeem. The server checks the code (CodesService) and says what it
-- gave or why not.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)

local MAX_CODE_LENGTH = 32
local BOX_HEIGHT = 52

local CodesController = {}

function CodesController:Start()
	local window = Menu.window({
		title = "Codes",
		colour = Theme.Menu.Codes,
		maxSize = Vector2.new(440, 260),
	})
	local hint = Make.label(window.Body, {
		text = "Got a code? Type it here.",
		size = Theme.TextSize.Body,
		colour = Theme.Colours.TextMuted,
		alignX = Enum.TextXAlignment.Left,
	})
	hint.Size = UDim2.new(1, 0, 0, 24)

	local box = Instance.new("TextBox")
	box.Name = "Code"
	box.Position = UDim2.fromOffset(0, 32)
	box.Size = UDim2.new(1, 0, 0, BOX_HEIGHT)
	box.BackgroundColor3 = Theme.Colours.Card
	box.Font = Theme.Fonts.Display
	box.TextSize = Theme.TextSize.Button
	box.TextColor3 = Theme.Colours.Text
	box.PlaceholderText = "Enter a code"
	box.PlaceholderColor3 = Theme.Colours.Locked
	box.Text = ""
	box.ClearTextOnFocus = false
	Make.corner(box, Theme.Corner.Medium)
	Make.outline(box, Theme.Colours.Ink, Theme.Stroke.Normal)
	box.Parent = window.Body

	local redeem = Button.new({
		text = "Redeem",
		icon = "Ticket",
		colour = Theme.Colours.Cash,
		size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
	})
	redeem.Instance.Position = UDim2.fromOffset(0, 32 + BOX_HEIGHT + Theme.Size.Gap + 4)
	redeem.Instance.Parent = window.Body

	local function send()
		if box.Text ~= "" then
			Remotes.RedeemCode:FireServer(string.sub(box.Text, 1, MAX_CODE_LENGTH))
			box.Text = ""
		end
	end
	redeem.Activated:Connect(send)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			send()
		end
	end)

	local menuButton = Menu.button({
		name = "Codes",
		text = "Codes",
		icon = "Ticket",
		colour = Theme.Menu.Codes,
		order = 3,
		side = "Right",
	})
	menuButton.Activated:Connect(function()
		Menu.toggle(window)
	end)
end

return CodesController
