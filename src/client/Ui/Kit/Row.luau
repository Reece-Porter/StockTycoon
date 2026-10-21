--!strict
-- A row for lists of things to read and act on (rewards, prizes, upgrades,
-- store items): a white card with a coloured edge, a title, a line or two of
-- detail, and a slot on the right for its button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Icons = require(script.Parent.Icons)
local Make = require(script.Parent.Make)

local EDGE_WIDTH = 8
local TITLE_HEIGHT = 24

export type Props = {
	title: string,
	detail: string?,
	accent: Color3?,
	icon: Icons.IconName?,
	-- Defaults to room for two lines of detail.
	height: number?,
	-- Width kept on the right for a button (put it in Action).
	actionWidth: number?,
	layoutOrder: number?,
}

export type Row = {
	Instance: Frame,
	Action: Frame,
	setTitle: (text: string) -> (),
	setDetail: (text: string) -> (),
	setAccent: (colour: Color3) -> (),
}

local Row = {}

function Row.new(props: Props): Row
	local accent = props.accent or Theme.Colours.Primary
	local actionWidth = props.actionWidth or 120
	local height = props.height or 72

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundColor3 = Theme.Colours.Card
	row.LayoutOrder = props.layoutOrder or 0
	Make.corner(row, Theme.Corner.Medium)
	Make.outline(row, Theme.Colours.Ink, Theme.Stroke.Normal)

	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.Size = UDim2.new(0, EDGE_WIDTH, 1, 0)
	edge.BackgroundColor3 = accent
	edge.BorderSizePixel = 0
	Make.corner(edge, Theme.Corner.Small)
	edge.Parent = row

	local left = EDGE_WIDTH + 10
	if props.icon then
		local icon = Icons.make(props.icon, 36, accent)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, left, 0.5, 0)
		icon.Parent = row
		left += 44
	end

	local title = Make.label(row, {
		text = props.title,
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Body + 2,
		colour = Theme.Colours.Text,
		alignX = Enum.TextXAlignment.Left,
	})
	title.Position = UDim2.fromOffset(left, 6)
	title.Size = UDim2.new(1, -(left + actionWidth + 12), 0, TITLE_HEIGHT)
	title.TextTruncate = Enum.TextTruncate.AtEnd

	local detail = Make.label(row, {
		text = props.detail,
		size = Theme.TextSize.Small,
		colour = Theme.Colours.TextMuted,
		alignX = Enum.TextXAlignment.Left,
		wrapped = true,
	})
	detail.RichText = true
	detail.TextYAlignment = Enum.TextYAlignment.Top
	detail.Position = UDim2.fromOffset(left, 6 + TITLE_HEIGHT)
	detail.Size = UDim2.new(1, -(left + actionWidth + 12), 1, -(TITLE_HEIGHT + 10))

	local action = Instance.new("Frame")
	action.Name = "Action"
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.new(1, -8, 0.5, 0)
	action.Size = UDim2.fromOffset(actionWidth, math.min(height - 12, Theme.Size.ButtonHeight))
	action.BackgroundTransparency = 1
	action.Parent = row

	return {
		Instance = row,
		Action = action,
		setTitle = function(text: string)
			title.Text = text
		end,
		setDetail = function(text: string)
			detail.Text = text
		end,
		setAccent = function(colour: Color3)
			edge.BackgroundColor3 = colour
		end,
	}
end

return Row
