--!strict
-- The Rewards button (bottom left, with a badge counting rewards ready to
-- claim) and its window: today's playtime rewards, the 7-day daily streak, any
-- boost time and free pet spins banked, and a box for codes. The server times everything and
-- checks every claim; this works out what to show from the attributes it sends
-- (see RewardsService) and the shared server clock.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardMath = require(ReplicatedStorage.Shared.RewardMath)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.Rewards)

-- Under the Weapons button, at the bottom of the stack on the left edge.
local BUTTON_POSITION = UDim2.new(0, 12, 0.5, 104)
local BUTTON_SIZE = UDim2.fromOffset(76, 48)
local PANEL_MAX_SIZE = Vector2.new(420, 560)
local ROW_HEIGHT = 56
local BACKGROUND = Color3.fromRGB(20, 20, 25)
local BUTTON_COLOUR = Color3.fromRGB(45, 45, 55)
local CLAIM = Color3.fromRGB(70, 150, 90)
local WAITING = Color3.fromRGB(70, 70, 80)
local TODAY = Color3.fromRGB(205, 150, 40)
local DONE = Color3.fromRGB(60, 110, 70)
local BADGE = Color3.fromRGB(230, 60, 60)
local UPDATE_SECONDS = 0.5

local player = Players.LocalPlayer

local RewardsController = {}

local function corner(parent: Instance, radius: number?)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius or 8)
	uiCorner.Parent = parent
end

local function button(text: string, colour: Color3): TextButton
	local newButton = Instance.new("TextButton")
	newButton.BackgroundColor3 = colour
	newButton.Font = Enum.Font.BuilderSansBold
	newButton.TextSize = 18
	newButton.TextColor3 = Color3.new(1, 1, 1)
	newButton.Text = text
	newButton.AutoButtonColor = true
	corner(newButton)
	return newButton
end

local function text(parent: Instance, order: number, size: number, bold: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, size + 10)
	label.BackgroundTransparency = 1
	label.Font = if bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium
	label.TextSize = size
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.RichText = true
	label.Parent = parent
	return label
end

local function numberAttribute(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function claimedToday(today: number): { number }
	if numberAttribute("PlaytimeDay") ~= today then
		return {}
	end
	local json = player:GetAttribute("ClaimedPlaytime")
	if typeof(json) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

-- Today's playtime, counted on from the last figure the server sent.
local function playtimeNow(now: number, today: number): number
	if numberAttribute("PlaytimeDay") ~= today then
		return 0
	end
	return numberAttribute("PlaytimeSeconds") + math.max(0, now - numberAttribute("PlaytimeAt"))
end

local function boostLeft(now: number): number
	return math.max(0, numberAttribute("BoostEndsAt") - now)
end

-- A short label for a day on the streak track, e.g. "Cash" or "2x 10m".
local function shortLabel(grants: { RewardsConfig.Grant }): string
	local parts = {}
	for _, grant in grants do
		if grant.kind == "cash" then
			table.insert(parts, "Cash")
		elseif grant.kind == "boost" then
			table.insert(parts, `{RewardsConfig.BoostMultiplier}x {math.floor((grant.seconds or 0) / 60)}m`)
		else
			local count = grant.count or 0
			table.insert(parts, if count == 1 then "1 spin" else `{count} spins`)
		end
	end
	return table.concat(parts, "\n")
end

-- What the cash in a reward would come to now, e.g. " (about $1.2K)".
local function cashHint(grants: { RewardsConfig.Grant }, now: number): string
	local income = numberAttribute("IncomePerSecond")
	if boostLeft(now) > 0 then
		income /= RewardsConfig.BoostMultiplier
	end
	for _, grant in grants do
		if grant.kind == "cash" then
			return ` (about {Format.cash(RewardMath.cashValue(grant, income))})`
		end
	end
	return ""
end

type PlaytimeRow = { minutes: number, detail: TextLabel, action: TextButton }
type DayBox = { frame: Frame, label: TextLabel }

function RewardsController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Rewards"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local openButton = button("Rewards", BACKGROUND)
	openButton.Name = "Open"
	openButton.BackgroundTransparency = 0.2
	openButton.Position = BUTTON_POSITION
	openButton.Size = BUTTON_SIZE
	openButton.TextSize = 16
	openButton.Parent = gui

	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -4, 0, 4)
	badge.Size = UDim2.fromOffset(22, 22)
	badge.BackgroundColor3 = BADGE
	badge.Font = Enum.Font.BuilderSansBold
	badge.TextSize = 14
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Visible = false
	corner(badge, 11)
	badge.Parent = openButton

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
	title.Text = "Rewards"
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

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local banked = text(list, nextOrder(), 16, false)
	local playtimeTitle = text(list, nextOrder(), 18, true)

	-- One row per playtime reward.
	local rows: { PlaytimeRow } = {}
	for _, milestone in RewardsConfig.Playtime do
		local row = Instance.new("Frame")
		row.LayoutOrder = nextOrder()
		row.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
		row.BackgroundColor3 = BUTTON_COLOUR
		row.BackgroundTransparency = 0.3
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

		local action = button("", WAITING)
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Position = UDim2.new(1, -8, 0.5, 0)
		action.Size = UDim2.fromOffset(110, 42)
		action.TextSize = 16
		action.Parent = row
		local minutes = milestone.minutes
		action.Activated:Connect(function()
			Remotes.ClaimPlaytime:FireServer(minutes)
		end)
		table.insert(rows, { minutes = minutes, detail = detail, action = action })
	end

	-- The daily streak: the whole 7-day track, then a claim button.
	local dailyTitle = text(list, nextOrder(), 18, true)
	local track = Instance.new("Frame")
	track.LayoutOrder = nextOrder()
	track.Size = UDim2.new(1, -6, 0, 64)
	track.BackgroundTransparency = 1
	track.Parent = list
	local trackLayout = Instance.new("UIListLayout")
	trackLayout.FillDirection = Enum.FillDirection.Horizontal
	trackLayout.Padding = UDim.new(0, 4)
	trackLayout.Parent = track
	local days = #RewardsConfig.Daily
	local boxes: { DayBox } = {}
	for day, grants in RewardsConfig.Daily do
		local box = Instance.new("Frame")
		box.LayoutOrder = day
		box.Size = UDim2.new(1 / days, -4, 1, 0)
		box.BackgroundColor3 = BUTTON_COLOUR
		corner(box, 6)
		box.Parent = track
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.BuilderSansBold
		label.TextSize = 12
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextWrapped = true
		label.Text = `Day {day}\n{shortLabel(grants)}`
		label.Parent = box
		table.insert(boxes, { frame = box, label = label })
	end
	local dailyDetail = text(list, nextOrder(), 14, false)
	local dailyButton = button("", WAITING)
	dailyButton.LayoutOrder = nextOrder()
	dailyButton.Size = UDim2.new(1, -6, 0, 48)
	dailyButton.Parent = list
	dailyButton.Activated:Connect(function()
		Remotes.ClaimDaily:FireServer()
	end)

	-- Codes: type one and press Redeem. The server checks it.
	local codesTitle = text(list, nextOrder(), 18, true)
	codesTitle.Text = "Codes"
	local codeRow = Instance.new("Frame")
	codeRow.LayoutOrder = nextOrder()
	codeRow.Size = UDim2.new(1, -6, 0, 48)
	codeRow.BackgroundTransparency = 1
	codeRow.Parent = list
	local codeBox = Instance.new("TextBox")
	codeBox.Size = UDim2.new(1, -122, 1, 0)
	codeBox.BackgroundColor3 = BUTTON_COLOUR
	codeBox.Font = Enum.Font.BuilderSansMedium
	codeBox.TextSize = 18
	codeBox.TextColor3 = Color3.new(1, 1, 1)
	codeBox.PlaceholderText = "Enter a code"
	codeBox.PlaceholderColor3 = Color3.fromRGB(160, 160, 170)
	codeBox.Text = ""
	codeBox.ClearTextOnFocus = false
	corner(codeBox)
	codeBox.Parent = codeRow
	local redeem = button("Redeem", CLAIM)
	redeem.AnchorPoint = Vector2.new(1, 0)
	redeem.Position = UDim2.fromScale(1, 0)
	redeem.Size = UDim2.new(0, 114, 1, 0)
	redeem.Parent = codeRow
	local function sendCode()
		if codeBox.Text ~= "" then
			Remotes.RedeemCode:FireServer(string.sub(codeBox.Text, 1, 32))
			codeBox.Text = ""
		end
	end
	redeem.Activated:Connect(sendCode)
	codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			sendCode()
		end
	end)

	local function refresh()
		local now = workspace:GetServerTimeNow()
		local today = RewardMath.day(now)
		local played = playtimeNow(now, today)
		local claimed = claimedToday(today)
		local ready = RewardMath.readyPlaytime(played, claimed)
		local daily = RewardMath.daily(numberAttribute("LastDailyDay"), numberAttribute("DailyStreak"), today)

		local count = #ready + (if daily.claimable then 1 else 0)
		badge.Visible = count > 0
		badge.Text = tostring(count)
		if not panel.Visible then
			return
		end

		local status = {}
		local boost = boostLeft(now)
		if boost > 0 then
			table.insert(status, `{RewardsConfig.BoostMultiplier}x income: {Format.duration(boost)} left`)
		end
		local tokens = numberAttribute("SpinTokens")
		if tokens > 0 then
			table.insert(status, `Free pet spins: {tokens} (use them at the pet shop)`)
		end
		banked.Text = table.concat(status, "\n")
		banked.Visible = #status > 0

		local resetsIn = Format.duration(RewardMath.secondsToNextDay(now))
		playtimeTitle.Text = `Playtime today: {Format.duration(played)}  <font size="14">(resets in {resetsIn})</font>`
		for _, row in rows do
			local grants = {}
			for _, milestone in RewardsConfig.Playtime do
				if milestone.minutes == row.minutes then
					grants = milestone.grants
				end
			end
			row.detail.Text = `<b>{row.minutes} min</b>\n{RewardMath.describeAll(grants)}{cashHint(grants, now)}`
			if table.find(claimed, row.minutes) then
				row.action.Text = "Claimed"
				row.action.BackgroundColor3 = DONE
				row.action.AutoButtonColor = false
			elseif table.find(ready, row.minutes) then
				row.action.Text = "Claim"
				row.action.BackgroundColor3 = CLAIM
				row.action.AutoButtonColor = true
			else
				row.action.Text = Format.duration(row.minutes * 60 - played)
				row.action.BackgroundColor3 = WAITING
				row.action.AutoButtonColor = false
			end
		end

		dailyTitle.Text = `Daily streak: {daily.streak} day{if daily.streak == 1 then "" else "s"}`
		-- Days already claimed in this run of the track are green; today's
		-- claim, if it's waiting, is gold.
		for day, box in boxes do
			local colour = BUTTON_COLOUR
			if daily.claimable then
				if day == daily.nextDay then
					colour = TODAY
				elseif day < daily.nextDay then
					colour = DONE
				end
			elseif day <= daily.streak then
				colour = DONE
			end
			box.frame.BackgroundColor3 = colour
		end
		local nextGrants = RewardsConfig.Daily[daily.nextDay]
		local when = if daily.claimable then "Today" else "Tomorrow"
		local nextText = `{RewardMath.describeAll(nextGrants)}{cashHint(nextGrants, now)}`
		dailyDetail.Text = `{when}, Day {daily.nextDay}: {nextText}. Miss a day and it starts again at Day 1.`
		if daily.claimable then
			dailyButton.Text = `Claim Day {daily.nextDay}`
			dailyButton.BackgroundColor3 = CLAIM
			dailyButton.AutoButtonColor = true
		else
			dailyButton.Text = `Come back in {resetsIn}`
			dailyButton.BackgroundColor3 = WAITING
			dailyButton.AutoButtonColor = false
		end
	end

	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
		refresh()
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	player.AttributeChanged:Connect(function(name)
		if
			name == "ClaimedPlaytime"
			or name == "PlaytimeSeconds"
			or name == "LastDailyDay"
			or name == "SpinTokens"
			or name == "BoostEndsAt"
		then
			refresh()
		end
	end)
	refresh()
	gui.Parent = player:WaitForChild("PlayerGui")

	while true do
		task.wait(UPDATE_SECONDS)
		refresh()
	end
end

return RewardsController
