--!strict
-- What a leaderboard shows on its board's front face (docs/visual-pass.md,
-- Phase 6), styled like a stock-exchange display board: a coloured header
-- strip with the board's title, a status line, then ranked rows on
-- alternating stripes, each with a round rank badge (gold, silver and bronze
-- for the top three), the player's name and their value in Cash green.
-- LeaderboardService fills it in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)

local PIXELS_PER_STUD = 40
local HEADER = 0.12
local STATUS = 0.07
local ROW_GAP = 0.004

export type Row = {
	frame: Frame,
	badge: Frame,
	rank: TextLabel,
	name: TextLabel,
	value: TextLabel,
}

export type Display = {
	gui: SurfaceGui,
	status: TextLabel,
	rows: { Row },
}

local BoardDisplay = {}

local function label(parent: Instance, font: Enum.Font, colour: Color3, align: Enum.TextXAlignment): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = font
	text.TextScaled = true
	text.TextColor3 = colour
	text.TextXAlignment = align
	text.Text = ""
	text.Parent = parent
	return text
end

local function corner(parent: Instance, radius: UDim)
	local round = Instance.new("UICorner")
	round.CornerRadius = radius
	round.Parent = parent
end

-- Builds the display on the part's front face, replacing any there.
function BoardDisplay.build(part: BasePart, title: string, entries: number): Display
	local old = part:FindFirstChild("LeaderboardGui")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.MaxDistance = 150

	local background = Instance.new("Frame")
	background.Name = "Board"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Theme.Street.Board
	background.BorderSizePixel = 0
	background.Parent = gui

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.fromScale(1, HEADER)
	header.BackgroundColor3 = Theme.Street.BoardHeader
	header.BorderSizePixel = 0
	header.Parent = background
	local titleLabel = label(header, Theme.Fonts.Display, Theme.Colours.TextOnColour, Enum.TextXAlignment.Center)
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.fromScale(0.05, 0.12)
	titleLabel.Size = UDim2.fromScale(0.9, 0.76)
	titleLabel.Text = string.upper(title)

	local status = label(background, Theme.Fonts.Body, Theme.Colours.TextMuted, Enum.TextXAlignment.Center)
	status.Name = "Status"
	status.Position = UDim2.fromScale(0.05, HEADER + 0.01)
	status.Size = UDim2.fromScale(0.9, STATUS - 0.02)

	local top = HEADER + STATUS
	local rowHeight = (1 - top - 0.02) / entries
	local rows = {}
	for rank = 1, entries do
		local frame = Instance.new("Frame")
		frame.Name = `Row{rank}`
		frame.Position = UDim2.fromScale(0.03, top + (rank - 1) * rowHeight)
		frame.Size = UDim2.fromScale(0.94, rowHeight - ROW_GAP)
		frame.BackgroundColor3 = Theme.Street.BoardRow
		frame.BackgroundTransparency = if rank % 2 == 1 then 0 else 0.5
		frame.BorderSizePixel = 0
		frame.Parent = background
		corner(frame, UDim.new(0.2, 0))

		local badgeColour: Color3? = Theme.Street.Ranks[rank]
		local badge = Instance.new("Frame")
		badge.Name = "Badge"
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.fromScale(0.015, 0.5)
		badge.Size = UDim2.fromScale(0.75, 0.75)
		badge.SizeConstraint = Enum.SizeConstraint.RelativeYY
		badge.BackgroundColor3 = badgeColour or Theme.Street.BoardFrame
		badge.BorderSizePixel = 0
		badge.Parent = frame
		corner(badge, UDim.new(0.5, 0))
		local rankLabel = label(
			badge,
			Theme.Fonts.Display,
			if badgeColour then Theme.Colours.Ink else Theme.Colours.TextMuted,
			Enum.TextXAlignment.Center
		)
		rankLabel.Name = "Rank"
		rankLabel.Position = UDim2.fromScale(0.15, 0.15)
		rankLabel.Size = UDim2.fromScale(0.7, 0.7)
		rankLabel.Text = tostring(rank)

		local name = label(
			frame,
			Theme.Fonts.Body,
			if badgeColour then badgeColour else Theme.Colours.TextOnColour,
			Enum.TextXAlignment.Left
		)
		name.Name = "PlayerName"
		name.Position = UDim2.fromScale(0.13, 0.15)
		name.Size = UDim2.fromScale(0.5, 0.7)
		local value = label(frame, Theme.Fonts.Display, Theme.Colours.Cash, Enum.TextXAlignment.Right)
		value.Name = "Value"
		value.Position = UDim2.fromScale(0.62, 0.15)
		value.Size = UDim2.fromScale(0.35, 0.7)
		table.insert(rows, { frame = frame, badge = badge, rank = rankLabel, name = name, value = value })
	end

	gui.Parent = part
	return { gui = gui, status = status, rows = rows }
end

-- Shows a player on a row, or clears it (name nil).
function BoardDisplay.setRow(row: Row, name: string?, value: string?)
	row.name.Text = name or ""
	row.value.Text = if name then value or "" else ""
	row.badge.Visible = name ~= nil
end

return BoardDisplay
