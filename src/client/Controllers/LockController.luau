--!strict
-- Base locks on screen. Every floor of a base has a lock button on a podium
-- in the middle of its walkway (each floor's LockButton, from
-- studio/BuildMap.luau). The owner gets a "Lock base" prompt on each one.
-- The server sets the LockedUntil and ProtectedUntil attributes (server time)
-- on each base and enforces the lock itself.
--
-- The look (docs/visual-pass.md, Phase 5):
--   - Each podium says LOCK with a padlock on all four sides (LOCKED while
--     the base is locked), and has a padlock on its cap, which stays pressed
--     down while the base is locked.
--   - While the base is locked, a shimmering force field fills the way in
--     (the Gate's Field), with a padlock and the time left on it. A new
--     player's protection shows its time left there too. Nothing floats over
--     the buttons themselves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StealConfig = require(ReplicatedStorage.Shared.Config.Steal)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)
local Make = require(script.Parent.Parent.Ui.Kit.Make)

local UPDATE_SECONDS = 0.25
local LOCKED = Theme.World.Locked
local PROTECTED = Theme.World.Protected
-- How see-through the force field is while the base is locked.
local FIELD_TRANSPARENCY = 0.35
-- The cap presses down this far, taking this long.
local PRESS_DEPTH = 0.22
local PRESS = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PIXELS_PER_STUD = 40
local LABEL_DISTANCE = 60
local PODIUM_FACES = { Enum.NormalId.Right, Enum.NormalId.Left, Enum.NormalId.Front, Enum.NormalId.Back }

type Button = {
	part: BasePart,
	prompt: ProximityPrompt,
	-- What this controller made on the button, removed if it goes away.
	made: { Instance },
	labels: { TextLabel },
	cap: BasePart?,
	capRest: CFrame?,
	pressed: boolean,
}

type Look = {
	base: Instance,
	buttons: { [BasePart]: Button },
	-- The force field across the way in, and its padlock and time left.
	field: BasePart?,
	fieldGui: BillboardGui?,
	fieldLabel: TextLabel?,
	-- A red padlock while locked, a blue one while protected.
	lockedIcon: Frame?,
	protectedIcon: Frame?,
}

local player = Players.LocalPlayer
local looks: { [Instance]: Look } = {}

local LockController = {}

local function secondsLeft(value: unknown): number
	return if typeof(value) == "number" then value - workspace:GetServerTimeNow() else 0
end

local function surface(part: BasePart, face: Enum.NormalId, name: string): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.MaxDistance = LABEL_DISTANCE
	gui.Parent = part
	return gui
end

local function press(button: Button, down: boolean)
	local cap, rest = button.cap, button.capRest
	button.pressed = down
	if cap and rest then
		local goal = if down then rest - Vector3.new(0, PRESS_DEPTH, 0) else rest
		TweenService:Create(cap, PRESS, { CFrame = goal }):Play()
	end
end

local function removeButton(look: Look, button: Button)
	look.buttons[button.part] = nil
	if button.cap and button.capRest and button.cap.Parent then
		button.cap.CFrame = button.capRest
	end
	for _, instance in button.made do
		instance:Destroy()
	end
end

local function update(look: Look)
	local base = look.base
	local isMine = base:GetAttribute("OwnerUserId") == player.UserId
	local locked = secondsLeft(base:GetAttribute("LockedUntil"))
	local protected = secondsLeft(base:GetAttribute("ProtectedUntil"))
	local isLocked = locked > 0

	local field = look.field
	if field then
		field.Transparency = if isLocked then FIELD_TRANSPARENCY else 1
	end
	local fieldGui, fieldLabel = look.fieldGui, look.fieldLabel
	local lockedIcon, protectedIcon = look.lockedIcon, look.protectedIcon
	if fieldGui and fieldLabel and lockedIcon and protectedIcon then
		local isProtected = not isLocked and protected > 0
		fieldGui.Enabled = isLocked or isProtected
		lockedIcon.Visible = isLocked
		protectedIcon.Visible = isProtected
		fieldLabel.Text = if isLocked
			then `Locked {Format.duration(locked)}`
			elseif isProtected then `Protected {Format.duration(protected)}`
			else ""
	end

	for part, button in look.buttons do
		if not part:IsDescendantOf(base) then
			removeButton(look, button)
			continue
		end
		if button.pressed ~= isLocked then
			press(button, isLocked)
		end
		for _, label in button.labels do
			label.Text = if isLocked then "LOCKED" else "LOCK"
			label.TextColor3 = if isLocked then LOCKED else Theme.Colours.TextOnColour
		end
		button.prompt.Enabled = isMine and not isLocked
	end
end

-- LOCK and a padlock on every side of the podium, and a padlock on the cap.
local function dressButton(button: Button)
	local part = button.part
	local pillar = part:FindFirstChild("Pillar")
	if pillar and pillar:IsA("BasePart") then
		for _, face in PODIUM_FACES do
			local gui = surface(pillar, face, "LockLabel")
			table.insert(button.made, gui)
			local column = Instance.new("Frame")
			column.Size = UDim2.fromScale(1, 1)
			column.BackgroundTransparency = 1
			column.Parent = gui
			local layout = Make.list(column, Enum.FillDirection.Vertical, 2)
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			layout.VerticalAlignment = Enum.VerticalAlignment.Center
			local icon = Icons.make("Padlock", math.floor(pillar.Size.X * PIXELS_PER_STUD * 0.55), LOCKED)
			icon.LayoutOrder = 1
			icon.Parent = column
			local label = Make.label(column, {
				font = Theme.Fonts.Display,
				size = Theme.TextSize.Body,
				colour = Theme.Colours.TextOnColour,
			})
			label.LayoutOrder = 2
			label.Size = UDim2.new(1, 0, 0, 22)
			label.TextScaled = true
			label.TextXAlignment = Enum.TextXAlignment.Center
			table.insert(button.labels, label)
		end
	end

	local cap = part:FindFirstChild("Cap")
	if cap and cap:IsA("BasePart") then
		button.cap = cap
		button.capRest = cap.CFrame
		-- The cap is a cylinder stood on end, so its top is its Right face.
		local gui = surface(cap, Enum.NormalId.Right, "Padlock")
		table.insert(button.made, gui)
		local icon = Icons.make("Padlock", math.floor(cap.Size.Y * PIXELS_PER_STUD * 0.55), Theme.Colours.Card)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Parent = gui
	end
end

local function setUpButton(look: Look, part: Instance)
	if not part:IsA("BasePart") or look.buttons[part] then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LockPrompt"
	prompt.ActionText = "Lock base"
	prompt.ObjectText = `{StealConfig.LockSeconds} seconds`
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = StealConfig.LockButtonDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Triggered:Connect(function()
		Remotes.LockBase:FireServer()
	end)
	prompt.Parent = part

	local button: Button = { part = part, prompt = prompt, made = { prompt }, labels = {}, pressed = false }
	dressButton(button)
	look.buttons[part] = button
	update(look)
end

-- The force field's padlock and time left, if the base has a gate.
local function setUpGate(look: Look)
	local gate = look.base:FindFirstChild("Gate")
	local field = gate and gate:FindFirstChild("Field")
	if field == nil or not field:IsA("BasePart") then
		return
	end
	look.field = field
	local gui = Instance.new("BillboardGui")
	gui.Name = "LockedSign"
	gui.Size = UDim2.fromOffset(230, 52)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Enabled = false
	local row = Instance.new("Frame")
	row.Size = UDim2.fromScale(1, 1)
	row.BackgroundColor3 = Theme.Colours.Ink
	row.BackgroundTransparency = 0.2
	Make.corner(row)
	Make.padding(row, 0, 10)
	local layout = Make.list(row, Enum.FillDirection.Horizontal, Theme.Size.Gap)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.Parent = gui
	local lockedIcon = Icons.make("Padlock", 34, LOCKED)
	lockedIcon.LayoutOrder = 1
	lockedIcon.Parent = row
	local protectedIcon = Icons.make("Padlock", 34, PROTECTED)
	protectedIcon.LayoutOrder = 1
	protectedIcon.Visible = false
	protectedIcon.Parent = row
	local label = Make.label(row, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Button,
		colour = Theme.Colours.TextOnColour,
	})
	label.LayoutOrder = 2
	label.Size = UDim2.fromOffset(0, 40)
	label.AutomaticSize = Enum.AutomaticSize.X
	gui.Parent = field
	look.fieldGui = gui
	look.fieldLabel = label
	look.lockedIcon = lockedIcon
	look.protectedIcon = protectedIcon
end

local function isButton(instance: Instance): boolean
	return instance.Name == "LockButton" and instance:IsA("BasePart")
end

local function watchBase(base: Instance)
	if looks[base] then
		return
	end
	local look: Look = { base = base, buttons = {} }
	looks[base] = look
	setUpGate(look)
	-- Upper floors (and their buttons) appear as the owner opens them.
	base.DescendantAdded:Connect(function(descendant)
		if isButton(descendant) then
			setUpButton(look, descendant)
		end
	end)
	for _, descendant in base:GetDescendants() do
		if isButton(descendant) then
			setUpButton(look, descendant)
		end
	end
	update(look)
end

function LockController:Start()
	local bases = workspace:WaitForChild("Map"):WaitForChild("Bases")
	bases.ChildAdded:Connect(watchBase)
	for _, base in bases:GetChildren() do
		watchBase(base)
	end

	while true do
		for base, look in looks do
			if base.Parent == nil then
				looks[base] = nil
			else
				update(look)
			end
		end
		task.wait(UPDATE_SECONDS)
	end
end

return LockController
