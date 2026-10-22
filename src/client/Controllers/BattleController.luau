--!strict
-- The battle arena on this player's screen (docs/design.md, "Battle arena";
-- BattleService on the server, which decides everything):
--   - A teleport prompt on each gate in the middle of the street (to the
--     arena), a Join prompt on the arena's podium (Leave once in), and a Go
--     home prompt on its exit pad.
--   - A panel at the top while the player is queued or playing: waiting (with
--     Practice when they're the only one, and Leave), the countdown, the round
--     with their place and value, and how they finished.
--   - Each round's pick pop-up (Ui/BattlePick), the keep-or-machine choice,
--     the machine (Ui/BattleMachine), and a banner for first place.
--   - The arena's big board: every player's place, name, latest pick and
--     value, updated after each round, and the final values and rewards.
-- Reads ReplicatedStorage.Battle's State attribute (JSON).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BattleConfig = require(ReplicatedStorage.Shared.Config.Battle)
local BattleMath = require(ReplicatedStorage.Shared.BattleMath)
local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)
local BattleMachine = require(script.Parent.Parent.Ui.BattleMachine)
local BattlePick = require(script.Parent.Parent.Ui.BattlePick)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Celebration = require(script.Parent.Parent.Ui.Celebration)
local Layout = require(script.Parent.Parent.Ui.Layout)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)
local Reels = require(script.Parent.Parent.Ui.Reels)

local UPDATE_SECONDS = 0.25
local CHECK_SECONDS = 1
local BOARD_ROWS = 8
local BOARD_PIXELS_PER_STUD = 25
local BOARD_DISTANCE = 220
local PANEL_HEIGHT = 44
local CHOOSE_DISPLAY_ORDER = 55

export type Row = {
	name: string,
	userId: number,
	place: number?,
	total: number,
	last: string?,
	picks: number?,
	picked: boolean?,
	choice: string?,
	chosen: boolean?,
	multiplier: number?,
	final: number?,
	reward: number?,
	left: boolean?,
}

export type State = {
	phase: string,
	round: number,
	rounds: number,
	endsAt: number,
	practice: boolean,
	lobby: { string },
	lobbyIds: { number },
	players: { Row },
}

type BoardRow = { frame: Frame, place: TextLabel, name: TextLabel, pick: TextLabel, chip: Frame, value: TextLabel }

local player = Players.LocalPlayer
local state: State = {
	phase = "Idle",
	round = 0,
	rounds = BattleConfig.Rounds,
	endsAt = 0,
	practice = false,
	lobby = {},
	lobbyIds = {},
	players = {},
}
local pickPopup: BattlePick.Popup? = nil
local machineScreen: BattleMachine.Screen? = nil
local chooseGui: ScreenGui? = nil
local celebrated = false
local panel: Frame
local panelText: TextLabel
local practiceButton: Button.Button
local leaveButton: Button.Button
local joinPrompt: ProximityPrompt? = nil
local board: { gui: SurfaceGui, status: TextLabel, rows: { BoardRow } }? = nil

local BattleController = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function myRow(): Row?
	for _, row in state.players do
		if row.userId == player.UserId then
			return row
		end
	end
	return nil
end

-- Whether a part (or something on one) is still in the map, not streamed out.
local function inMap(instance: Instance): boolean
	local map = workspace:FindFirstChild("Map")
	return map ~= nil and instance:IsDescendantOf(map)
end

local function inLobby(): boolean
	return table.find(state.lobbyIds, player.UserId) ~= nil
end

local function playing(): boolean
	local row = myRow()
	return row ~= nil and not row.left and state.phase ~= "Idle"
end

-- A pick as players see it, e.g. "Galaxy Kittygram", and its tier colour.
local function describe(text: string?): (string, Color3?)
	if text == nil then
		return "", nil
	end
	local results = Reels.parse(text)
	local result = results[1]
	local company = if result then Companies.byId[result.companyId] else nil
	if result == nil or company == nil then
		return "", nil
	end
	local variant = if result.variant then Variants.byId[result.variant] else nil
	local tier = Tiers.byId[company.tier]
	return if variant then `{variant.name} {company.name}` else company.name, if tier then tier.color else nil
end

-- What the phase is, for the board.
local function statusText(time: number): string
	local left = Format.duration(math.max(0, state.endsAt - time))
	local phase = state.phase
	if phase == "Idle" then
		return `Waiting for players ({#state.lobby}/{BattleConfig.MaxPlayers})`
	elseif phase == "Countdown" then
		return `Starts in {left}  ·  {#state.lobby} players`
	elseif phase == "Spin" then
		return `Round {state.round} of {state.rounds}  ·  picking ({left})`
	elseif phase == "Results" then
		return `Round {state.round} of {state.rounds} done`
	elseif phase == "Choose" then
		return `Keep it or the machine? ({left})`
	elseif phase == "Machine" then
		return "The machine is running"
	end
	return if state.practice then "Practice over" else "Final results"
end

-- The same, short enough for the panel on a phone held upright.
local function shortStatus(time: number): string
	local left = Format.duration(math.max(0, state.endsAt - time))
	local phase = state.phase
	if phase == "Spin" then
		return `Round {state.round}/{state.rounds}  ·  {left}`
	elseif phase == "Results" then
		return `Round {state.round}/{state.rounds}`
	elseif phase == "Choose" then
		return `Keep or machine?  ·  {left}`
	elseif phase == "Machine" then
		return "Machine running"
	end
	return statusText(time)
end

-- The panel at the top while the player is queued or playing.
local function renderPanel(time: number)
	local queued, inMatch = inLobby(), playing()
	panel.Visible = queued or inMatch
	practiceButton.Instance.Visible = queued and state.phase == "Idle" and #state.lobby == 1
	leaveButton.Instance.Visible = queued
	local row = myRow()
	if inMatch and row then
		local value = row.final or row.total
		local place = if row.place then BattleMath.ordinal(row.place) else "-"
		if state.phase == "Final" then
			panelText.Text = if row.reward
				then `You came {place}: {Format.cash(value)}  ·  +{Format.cash(row.reward)}`
				else `You came {place}: {Format.cash(value)}`
		else
			panelText.Text = `{shortStatus(time)}  ·  {place}  ·  {Format.cash(value)}`
		end
	elseif queued then
		panelText.Text = shortStatus(time)
	end
end

local function buildPanel()
	panel = Instance.new("Frame")
	panel.Name = "Battle"
	panel.Size = UDim2.fromOffset(0, PANEL_HEIGHT)
	panel.AutomaticSize = Enum.AutomaticSize.X
	panel.BackgroundColor3 = Theme.Base.Spinner
	panel.Visible = false
	Make.corner(panel)
	Make.outline(panel, Theme.Colours.Ink, Theme.Stroke.Thick)
	Make.padding(panel, 4, 12)
	local layout = Make.list(panel, Enum.FillDirection.Horizontal, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	panelText = Make.label(panel, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Body,
		colour = Theme.Colours.TextOnColour,
		outline = true,
	})
	panelText.Name = "Text"
	panelText.LayoutOrder = 1
	panelText.Size = UDim2.fromScale(0, 1)
	panelText.AutomaticSize = Enum.AutomaticSize.X
	practiceButton = Button.new({
		text = "Practice",
		colour = Theme.Colours.Primary,
		size = UDim2.fromOffset(100, PANEL_HEIGHT - 8),
		textSize = Theme.TextSize.Small,
		layoutOrder = 2,
	})
	practiceButton.Instance.Name = "Practice"
	practiceButton.Instance.Parent = panel
	practiceButton.Activated:Connect(function()
		Remotes.BattlePractice:FireServer()
	end)
	leaveButton = Button.new({
		text = "Leave",
		colour = Theme.Colours.Danger,
		size = UDim2.fromOffset(80, PANEL_HEIGHT - 8),
		textSize = Theme.TextSize.Small,
		layoutOrder = 3,
	})
	leaveButton.Instance.Name = "Leave"
	leaveButton.Instance.Parent = panel
	leaveButton.Activated:Connect(function()
		Remotes.BattleLeave:FireServer()
	end)
	Menu.addTop(panel, 2)
end

local function closeChoose()
	local gui = chooseGui
	if gui then
		chooseGui = nil
		gui:Destroy()
	end
end

-- Keep the total, or put it through the machine.
local function openChoose(total: number)
	closeChoose()
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BattleChoose"
	gui.DisplayOrder = CHOOSE_DISPLAY_ORDER
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	local box = Instance.new("Frame")
	box.Name = "Panel"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.48)
	box.Size = UDim2.fromOffset(380, 200)
	box.BackgroundColor3 = Theme.Colours.Card
	Make.corner(box, Theme.Corner.Large)
	Make.outline(box, Theme.Colours.Ink, Theme.Stroke.Thick)
	Layout.scaled(box)
	box.Parent = gui
	local text = Make.label(box, {
		text = `Your stocks are worth {Format.cash(total)}. Keep that, or put it through the machine? It could end up anywhere from half to five times as much.`,
		size = Theme.TextSize.Body,
		colour = Theme.Colours.Text,
		wrapped = true,
	})
	text.Name = "Text"
	text.Position = UDim2.fromOffset(16, 12)
	text.Size = UDim2.new(1, -32, 0, 90)
	local function choice(name: string, label: string, colour: Color3, x: number)
		local button = Button.new({ text = label, colour = colour, size = UDim2.new(0.5, -22, 0, 56) })
		button.Instance.Name = name
		button.Instance.AnchorPoint = Vector2.new(x, 1)
		button.Instance.Position = UDim2.new(x, if x == 0 then 16 else -16, 1, -14)
		button.Instance.Parent = box
		button.Activated:Connect(function()
			Remotes.BattleChoose:FireServer(string.lower(name))
			closeChoose()
		end)
	end
	choice("Keep", "Keep it", Theme.Colours.Cash, 0)
	choice("Machine", "Machine!", Theme.Colours.Purple, 1)
	gui.Parent = playerGui
	chooseGui = gui
end

-- The arena's board, once its part has streamed in (and again if it
-- streams out and back).
local function setUpBoard()
	local current = board
	if current and inMap(current.gui) then
		return
	end
	board = nil
	local map = workspace:FindFirstChild("Map")
	local arena = map and map:FindFirstChild("Arena")
	local part = arena and arena:FindFirstChild("Board")
	if part == nil or not part:IsA("BasePart") then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardScreen"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = BOARD_PIXELS_PER_STUD
	gui.MaxDistance = BOARD_DISTANCE
	gui.LightInfluence = 0
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Theme.Base.SpinnerScreen
	back.Parent = gui
	local title = Make.label(back, {
		text = "BATTLE ARENA",
		font = Theme.Fonts.Display,
		colour = Theme.Colours.Gold,
		alignX = Enum.TextXAlignment.Left,
		outline = true,
	})
	title.Name = "Title"
	title.Position = UDim2.fromScale(0.03, 0.02)
	title.Size = UDim2.fromScale(0.45, 0.13)
	title.TextScaled = true
	local status = Make.label(back, {
		font = Theme.Fonts.Display,
		colour = Theme.Colours.TextOnColour,
		alignX = Enum.TextXAlignment.Right,
		outline = true,
	})
	status.Name = "Status"
	status.Position = UDim2.fromScale(0.48, 0.04)
	status.Size = UDim2.fromScale(0.49, 0.09)
	status.TextScaled = true
	local rows = {}
	local rowHeight = 0.8 / BOARD_ROWS
	for index = 1, BOARD_ROWS do
		local frame = Instance.new("Frame")
		frame.Name = `Row{index}`
		frame.Position = UDim2.fromScale(0.02, 0.17 + (index - 1) * rowHeight)
		frame.Size = UDim2.fromScale(0.96, rowHeight * 0.9)
		frame.BackgroundColor3 = if index % 2 == 0 then Theme.Base.Spinner else Theme.Colours.Ink
		Make.corner(frame)
		frame.Parent = back
		local function cell(name: string, x: number, width: number, align: Enum.TextXAlignment): TextLabel
			local label = Make.label(frame, {
				font = Theme.Fonts.Display,
				colour = Theme.Colours.TextOnColour,
				alignX = align,
				outline = true,
			})
			label.Name = name
			label.Position = UDim2.fromScale(x, 0.12)
			label.Size = UDim2.fromScale(width, 0.76)
			label.TextScaled = true
			return label
		end
		local chip = Instance.new("Frame")
		chip.Name = "Chip"
		chip.AnchorPoint = Vector2.new(0, 0.5)
		chip.Position = UDim2.fromScale(0.42, 0.5)
		chip.Size = UDim2.fromScale(0.012, 0.6)
		chip.BorderSizePixel = 0
		chip.Parent = frame
		table.insert(rows, {
			frame = frame,
			place = cell("Place", 0.01, 0.08, Enum.TextXAlignment.Center),
			name = cell("Player", 0.11, 0.3, Enum.TextXAlignment.Left),
			chip = chip,
			pick = cell("Pick", 0.44, 0.33, Enum.TextXAlignment.Left),
			value = cell("Value", 0.78, 0.21, Enum.TextXAlignment.Right),
		})
	end
	gui.Parent = part
	board = { gui = gui, status = status, rows = rows }
end

local function renderBoard(time: number)
	local current = board
	if current == nil then
		return
	end
	current.status.Text = statusText(time)
	local lines: { { place: string, name: string, pick: string, colour: Color3?, value: string, faded: boolean } } = {}
	if state.phase == "Idle" or state.phase == "Countdown" then
		for _, name in state.lobby do
			table.insert(lines, { place = "", name = name, pick = "Ready", colour = nil, value = "", faded = false })
		end
	else
		for _, row in state.players do
			local pick, colour = describe(row.last)
			if row.left then
				pick, colour = "Left", nil
			elseif state.phase == "Spin" and row.picked then
				pick = `{pick}  ✓`
			end
			local value = Format.cash(row.final or row.total)
			if row.final and row.multiplier and row.choice == "machine" then
				value = `{Format.cash(row.final)} ({string.format("%.2fx", row.multiplier)})`
			end
			if row.reward then
				value ..= `  +{Format.cash(row.reward)}`
			end
			table.insert(lines, {
				place = if row.place then BattleMath.ordinal(row.place) else "",
				name = row.name,
				pick = pick,
				colour = colour,
				value = value,
				faded = row.left == true,
			})
		end
	end
	for index, boardRow in current.rows do
		local line = lines[index]
		boardRow.frame.Visible = line ~= nil
		if line then
			boardRow.place.Text = line.place
			boardRow.place.TextColor3 = if line.place == "1st" then Theme.Colours.Gold else Theme.Colours.TextOnColour
			boardRow.name.Text = line.name
			boardRow.pick.Text = line.pick
			boardRow.value.Text = line.value
			boardRow.chip.Visible = line.colour ~= nil
			boardRow.chip.BackgroundColor3 = line.colour or Theme.Colours.Ink
			boardRow.frame.BackgroundTransparency = if line.faded then 0.6 else 0
		end
	end
end

-- The prompts on the street's gates, the podium and the exit pad.
local function setUpPrompts()
	local map = workspace:FindFirstChild("Map")
	if map == nil then
		return
	end
	local gates = map:FindFirstChild("ArenaGates")
	if gates then
		for _, gate in gates:GetChildren() do
			local pad = gate:FindFirstChild("Pad")
			if pad and pad:IsA("BasePart") and pad:FindFirstChild("ArenaPrompt") == nil then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "ArenaPrompt"
				prompt.ActionText = "Teleport"
				prompt.ObjectText = "Battle Arena"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = BattleConfig.GateDistance
				prompt.RequiresLineOfSight = false
				prompt.Triggered:Connect(function()
					Remotes.Travel:FireServer("Arena")
				end)
				prompt.Parent = pad
			end
		end
	end
	local arena = map:FindFirstChild("Arena")
	if arena == nil then
		return
	end
	local podium = arena:FindFirstChild("Join", true)
	local current = joinPrompt
	if current and not inMap(current) then
		joinPrompt = nil
	end
	if podium and podium:IsA("BasePart") and joinPrompt == nil then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "JoinPrompt"
		prompt.ActionText = "Join battle"
		prompt.ObjectText = "Battle Arena"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = BattleConfig.JoinDistance
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			if inLobby() then
				Remotes.BattleLeave:FireServer()
			else
				Remotes.BattleJoin:FireServer()
			end
		end)
		prompt.Parent = podium
		joinPrompt = prompt
	end
	local exit = arena:FindFirstChild("Exit", true)
	if exit and exit:IsA("BasePart") and exit:FindFirstChild("HomePrompt") == nil then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "HomePrompt"
		prompt.ActionText = "Go home"
		prompt.ObjectText = "Back to your base"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = BattleConfig.JoinDistance
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			Remotes.Travel:FireServer("Home")
		end)
		prompt.Parent = exit
	end
end

local function renderPrompts()
	local prompt = joinPrompt
	if prompt then
		prompt.ActionText = if inLobby() then "Leave queue" else "Join battle"
		prompt.Enabled = not playing() or state.phase == "Final"
	end
end

-- A new State from the server.
function BattleController.changed(newState: State)
	local before = state.phase
	state = newState
	local row = myRow()
	local inMatch = playing()
	-- The round's pick closes when the round does.
	local popup = pickPopup
	if popup and state.phase ~= "Spin" then
		popup.close()
		pickPopup = nil
	end
	if inMatch and row and state.phase == "Choose" and not row.chosen then
		if chooseGui == nil then
			openChoose(row.total)
		end
	else
		closeChoose()
	end
	local screen = machineScreen
	if screen and (state.phase == "Final" or not inMatch) then
		screen.locked(if row then row.multiplier else nil)
		task.delay(2.5, function()
			screen.close()
		end)
		machineScreen = nil
	end
	if state.phase == "Final" and before ~= "Final" and inMatch and row and row.place == 1 and not state.practice then
		local playerGui = player:FindFirstChild("PlayerGui")
		if playerGui and not celebrated then
			celebrated = true
			Celebration.play(
				playerGui,
				"1ST PLACE!",
				if row.reward then `+{Format.cash(row.reward)}` else "You won the battle!",
				{ colour = Theme.Colours.Gold }
			)
		end
	end
	if state.phase ~= "Final" then
		celebrated = false
	end
	local time = now()
	renderPanel(time)
	renderBoard(time)
	renderPrompts()
end

-- This round's stocks, from the server: the pick pop-up.
function BattleController.offered(round: number, text: string, rolledAt: number, landsAt: number, pickBy: number)
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return
	end
	local open = pickPopup
	if open then
		open.close()
	end
	local roll: Reels.Roll = { rolledAt = rolledAt, landsAt = landsAt, results = Reels.parse(text), previous = {} }
	pickPopup = BattlePick.open(playerGui, round, state.rounds, roll, pickBy, function(index)
		Remotes.BattlePick:FireServer(index)
	end)
end

-- The player's machine run, from the server.
function BattleController.machine(text: string)
	local playerGui = player:FindFirstChild("PlayerGui")
	local ok, run = pcall(function()
		return HttpService:JSONDecode(text)
	end)
	if playerGui == nil or not ok or typeof(run) ~= "table" then
		return
	end
	local open = machineScreen
	if open then
		open.close()
	end
	closeChoose()
	machineScreen = BattleMachine.open(playerGui, run :: any, function()
		Remotes.BattleTake:FireServer()
	end)
end

function BattleController.step(time: number)
	local popup = pickPopup
	if popup and not popup.step(time) then
		pickPopup = nil
	end
	local screen = machineScreen
	if screen and not screen.step(time) then
		machineScreen = nil
	end
end

function BattleController.check(time: number)
	setUpPrompts()
	setUpBoard()
	renderPanel(time)
	renderBoard(time)
	renderPrompts()
end

function BattleController:Start()
	buildPanel()
	Remotes.BattleOffer.OnClientEvent:Connect(
		function(round: unknown, text: unknown, rolledAt: unknown, landsAt: unknown, pickBy: unknown)
			if
				typeof(round) == "number"
				and typeof(text) == "string"
				and typeof(rolledAt) == "number"
				and typeof(landsAt) == "number"
				and typeof(pickBy) == "number"
			then
				BattleController.offered(round, text, rolledAt, landsAt, pickBy)
			end
		end
	)
	Remotes.BattleMachine.OnClientEvent:Connect(function(text: unknown)
		if typeof(text) == "string" then
			BattleController.machine(text)
		end
	end)
	local folder = ReplicatedStorage:WaitForChild("Battle")
	local function read()
		local text = folder:GetAttribute("State")
		if typeof(text) ~= "string" then
			return
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(text)
		end)
		if ok and typeof(decoded) == "table" then
			local newState = decoded :: any
			newState.lobby = newState.lobby or {}
			newState.lobbyIds = newState.lobbyIds or {}
			newState.players = newState.players or {}
			BattleController.changed(newState)
		end
	end
	folder:GetAttributeChangedSignal("State"):Connect(read)
	read()
	RunService.RenderStepped:Connect(function()
		BattleController.step(now())
	end)
	local sinceCheck = CHECK_SECONDS
	while true do
		sinceCheck += UPDATE_SECONDS
		local time = now()
		if sinceCheck >= CHECK_SECONDS then
			sinceCheck = 0
			BattleController.check(time)
		else
			renderPanel(time)
			renderBoard(time)
		end
		task.wait(UPDATE_SECONDS)
	end
end

return BattleController
