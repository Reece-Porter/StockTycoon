--!strict
-- Base locks on screen. The owner gets a "Lock base" prompt on their own
-- LockButton. Every base's LockButton shows a sign: the time left on a lock,
-- the time left on a new player's protection, or that the base is open. The
-- server sets the LockedUntil and ProtectedUntil attributes (server time) on
-- each base and enforces the lock itself.
--
-- The look (docs/visual-pass.md, Phase 5): the button's cap has a padlock
-- on it and presses down when the base locks, and while it's locked a
-- shimmering force field fills the way in (the Gate's Field, from
-- studio/BuildMap.luau) with a padlock and the time left on it.

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
local OPEN = Theme.World.Open
-- How see-through the force field is while the base is locked.
local FIELD_TRANSPARENCY = 0.35
-- The cap presses down this far, and the time each way.
local PRESS_DEPTH = 0.22
local PRESS = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CAP_PIXELS_PER_STUD = 40

type Sign = {
	base: Instance,
	button: BasePart,
	label: TextLabel,
	prompt: ProximityPrompt,
	-- The force field across the way in, and its padlock and time left.
	field: BasePart?,
	fieldGui: BillboardGui?,
	fieldLabel: TextLabel?,
	cap: BasePart?,
	capRest: CFrame?,
	wasLocked: boolean,
}

local player = Players.LocalPlayer
local signs: { [BasePart]: Sign } = {}

local LockController = {}

local function secondsLeft(value: unknown): number
	return if typeof(value) == "number" then value - workspace:GetServerTimeNow() else 0
end

local function update(sign: Sign)
	local base = sign.base
	local isMine = base:GetAttribute("OwnerUserId") == player.UserId
	local locked = secondsLeft(base:GetAttribute("LockedUntil"))
	local protected = secondsLeft(base:GetAttribute("ProtectedUntil"))

	local isLocked = locked > 0
	local field, fieldGui, fieldLabel = sign.field, sign.fieldGui, sign.fieldLabel
	if field then
		field.Transparency = if isLocked then FIELD_TRANSPARENCY else 1
	end
	if fieldGui and fieldLabel then
		fieldGui.Enabled = isLocked
		fieldLabel.Text = if isLocked then `Locked {Format.duration(locked)}` else ""
	end
	local cap, rest = sign.cap, sign.capRest
	if isLocked and not sign.wasLocked and cap and rest then
		-- Pressed: down, then back up.
		local down = TweenService:Create(cap, PRESS, { CFrame = rest - Vector3.new(0, PRESS_DEPTH, 0) })
		down.Completed:Connect(function()
			TweenService:Create(cap, PRESS, { CFrame = rest }):Play()
		end)
		down:Play()
	end
	sign.wasLocked = isLocked

	if locked > 0 then
		sign.label.Text = `Locked {Format.duration(locked)}`
		sign.label.TextColor3 = LOCKED
	elseif protected > 0 then
		sign.label.Text = `New player: protected {Format.duration(protected)}`
		sign.label.TextColor3 = PROTECTED
	elseif base:GetAttribute("OwnerUserId") ~= nil then
		sign.label.Text = if isMine then "Unlocked: press to lock" else "Unlocked"
		sign.label.TextColor3 = OPEN
	else
		sign.label.Text = ""
	end

	sign.prompt.Enabled = isMine and locked <= 0
end

-- A padlock drawn on the button's cap, and the force field's padlock and
-- time left, if the base has them.
local function setUpLooks(sign: Sign)
	local cap = sign.button:FindFirstChild("Cap")
	if cap and cap:IsA("BasePart") then
		sign.cap = cap
		sign.capRest = cap.CFrame
		-- The cap is a cylinder stood on end, so its top is its Right face.
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Padlock"
		gui.Face = Enum.NormalId.Right
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = CAP_PIXELS_PER_STUD
		gui.LightInfluence = 0
		gui.MaxDistance = 80
		local icon = Icons.make("Padlock", math.floor(cap.Size.Y * CAP_PIXELS_PER_STUD * 0.55), Theme.Colours.Card)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Parent = gui
		gui.Parent = cap
	end

	local gate = sign.base:FindFirstChild("Gate")
	local field = gate and gate:FindFirstChild("Field")
	if field and field:IsA("BasePart") then
		sign.field = field
		local gui = Instance.new("BillboardGui")
		gui.Name = "LockedSign"
		gui.Size = UDim2.fromOffset(190, 52)
		gui.MaxDistance = 100
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
		local icon = Icons.make("Padlock", 34, LOCKED)
		icon.LayoutOrder = 1
		icon.Parent = row
		local label = Make.label(row, {
			font = Theme.Fonts.Display,
			size = Theme.TextSize.Button,
			colour = Theme.Colours.TextOnColour,
		})
		label.LayoutOrder = 2
		label.Size = UDim2.fromOffset(0, 40)
		label.AutomaticSize = Enum.AutomaticSize.X
		gui.Parent = field
		sign.fieldGui = gui
		sign.fieldLabel = label
	end
end

local function setUpButton(base: Instance, button: Instance)
	if not button:IsA("BasePart") or signs[button] then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "LockSign"
	gui.Adornee = button
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, button.Size.Y / 2 + 2.5, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Parent = button

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Theme.Fonts.Display
	label.TextSize = Theme.TextSize.Button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Theme.Colours.Ink
	stroke.Thickness = Theme.Stroke.Normal
	stroke.Parent = label
	label.Parent = gui

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
	prompt.Parent = button

	local sign: Sign = { base = base, button = button, label = label, prompt = prompt, wasLocked = false }
	setUpLooks(sign)
	signs[button] = sign
	button.Destroying:Connect(function()
		signs[button] = nil
	end)
	update(sign)
end

local function watchBase(base: Instance)
	base.ChildAdded:Connect(function(child)
		if child.Name == "LockButton" then
			setUpButton(base, child)
		end
	end)
	local button = base:FindFirstChild("LockButton")
	if button then
		setUpButton(base, button)
	end
end

function LockController:Start()
	local bases = workspace:WaitForChild("Map"):WaitForChild("Bases")
	bases.ChildAdded:Connect(watchBase)
	for _, base in bases:GetChildren() do
		watchBase(base)
	end

	while true do
		for _, sign in signs do
			update(sign)
		end
		task.wait(UPDATE_SECONDS)
	end
end

return LockController
