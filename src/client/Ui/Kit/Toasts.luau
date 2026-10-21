--!strict
-- Notification toasts: each slides in from the top with a coloured left edge
-- for its kind, stays Theme.ToastSeconds and fades away. At most
-- Theme.MaxToasts show at once (the oldest goes first), and the same message
-- twice in a row just stays up longer instead of stacking.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Make = require(script.Parent.Make)

export type Kind = "Info" | "Success" | "Warning" | "Error"

-- Below the teleport buttons along the top of the screen.
local TOP_OFFSET = 56
local MAX_WIDTH = 420
local EDGE_WIDTH = 8
local SLIDE = 24

type Toast = {
	holder: Frame,
	body: CanvasGroup,
	message: string,
	shownUntil: number,
	leaving: boolean,
}

local stack: Frame? = nil
local toasts: { Toast } = {}
local order = 0

local Toasts = {}

local function getStack(): Frame
	if stack then
		return stack
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Toasts"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 200
	local frame = Instance.new("Frame")
	frame.Name = "Stack"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, TOP_OFFSET)
	frame.Size = UDim2.new(1, -24, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(MAX_WIDTH, math.huge)
	limit.Parent = frame
	local layout = Make.list(frame, Enum.FillDirection.Vertical, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	stack = frame
	return frame
end

local function remove(toast: Toast)
	if toast.leaving then
		return
	end
	toast.leaving = true
	local index = table.find(toasts, toast)
	if index then
		table.remove(toasts, index)
	end
	local fade = TweenService:Create(
		toast.body,
		TweenInfo.new(Theme.Tween.Toast, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ GroupTransparency = 1, Position = UDim2.fromOffset(0, -SLIDE) }
	)
	fade.Completed:Connect(function()
		toast.holder:Destroy()
	end)
	fade:Play()
end

-- Shows a message; kind sets the colour of its left edge (Info if not given).
function Toasts.show(message: string, kind: Kind?)
	local newest = toasts[#toasts]
	if newest and newest.message == message then
		newest.shownUntil = os.clock() + Theme.ToastSeconds
		return
	end
	while #toasts >= Theme.MaxToasts do
		remove(toasts[1])
	end

	order += 1
	local holder = Instance.new("Frame")
	holder.Name = "Toast"
	holder.LayoutOrder = order
	holder.Size = UDim2.fromScale(1, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1

	local body = Instance.new("CanvasGroup")
	body.Size = UDim2.fromScale(1, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, -SLIDE)
	body.GroupTransparency = 1
	body.Parent = holder

	-- Inset by the outline, so the CanvasGroup doesn't cut it off.
	local inset = math.ceil(Theme.Stroke.Normal)
	local card = Instance.new("Frame")
	card.Position = UDim2.fromOffset(inset, inset)
	card.Size = UDim2.new(1, -2 * inset, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Theme.Colours.Card
	Make.corner(card, Theme.Corner.Medium)
	Make.outline(card, Theme.Colours.Ink, Theme.Stroke.Normal)
	card.Parent = body
	-- Room below the card for the outline too.
	local spacer = Instance.new("UIPadding")
	spacer.PaddingBottom = UDim.new(0, inset)
	spacer.Parent = body

	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.Size = UDim2.new(0, EDGE_WIDTH, 1, 0)
	edge.BackgroundColor3 = Theme.Toasts[kind or "Info"]
	edge.BorderSizePixel = 0
	Make.corner(edge, Theme.Corner.Small)
	edge.Parent = card

	local text = Make.label(card, {
		text = message,
		size = Theme.TextSize.Body,
		colour = Theme.Colours.Text,
		alignX = Enum.TextXAlignment.Left,
		wrapped = true,
	})
	text.Position = UDim2.fromOffset(EDGE_WIDTH + 10, 0)
	text.Size = UDim2.new(1, -(EDGE_WIDTH + 20), 0, 0)
	text.AutomaticSize = Enum.AutomaticSize.Y
	Make.padding(text, 10, 0)

	holder.Parent = getStack()
	local toast: Toast = {
		holder = holder,
		body = body,
		message = message,
		shownUntil = os.clock() + Theme.ToastSeconds,
		leaving = false,
	}
	table.insert(toasts, toast)
	TweenService:Create(
		body,
		TweenInfo.new(Theme.Tween.Toast, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }
	):Play()

	task.spawn(function()
		while not toast.leaving and os.clock() < toast.shownUntil do
			task.wait(toast.shownUntil - os.clock())
		end
		remove(toast)
	end)
end

return Toasts
