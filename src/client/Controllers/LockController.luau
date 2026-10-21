--!strict
-- Base locks on screen. The owner gets a "Lock base" prompt on their own
-- LockButton. Every base's LockButton shows a sign: the time left on a lock,
-- the time left on a new player's protection, or that the base is open. The
-- server sets the LockedUntil and ProtectedUntil attributes (server time) on
-- each base and enforces the lock itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StealConfig = require(ReplicatedStorage.Shared.Config.Steal)
local Theme = require(ReplicatedStorage.Shared.Theme)

local UPDATE_SECONDS = 0.25
local LOCKED = Theme.World.Locked
local PROTECTED = Theme.World.Protected
local OPEN = Theme.World.Open

type Sign = { base: Instance, button: BasePart, label: TextLabel, prompt: ProximityPrompt }

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

	local sign: Sign = { base = base, button = button, label = label, prompt = prompt }
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
