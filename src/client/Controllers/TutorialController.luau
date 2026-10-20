--!strict
-- The new-player guide on screen (Config/Onboarding): a hint near the bottom
-- of the screen with a Skip button, and a glowing line from the player to
-- where they need to go, with a bouncing marker above it. The server decides
-- the step (TutorialStep, shown from TutorialShowAt); this picks the target and
-- the words for what the player is doing right now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CompanyLabel = require(script.Parent.Parent.Ui.CompanyLabel)

local Steps = Onboarding.Steps
local TARGET_SECONDS = 0.25
local LINE_COLOUR = Color3.fromRGB(255, 210, 70)
local BANNER_MAX_WIDTH = 440
-- Clear of the tool bar along the bottom of the screen.
local BANNER_BOTTOM_GAP = 96
-- Room for the sign over the lock button (LockController).
local LOCK_SIGN_HEIGHT = 3

local player = Players.LocalPlayer

local TutorialController = {}

local function numberAttribute(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function childrenOf(instance: Instance?): { Instance }
	return if instance then instance:GetChildren() else {}
end

local function rootOf(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function myBase(): Instance?
	local baseName = player:GetAttribute("BaseName")
	local map = workspace:FindFirstChild("Map")
	local bases = map and map:FindFirstChild("Bases")
	return if bases and typeof(baseName) == "string" then bases:FindFirstChild(baseName) else nil
end

local function nearest(parts: { BasePart }, from: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, part in parts do
		local distance = (part.Position - from).Magnitude
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	return best
end

-- A company on this player's own conveyor, or else the belt itself.
local function conveyorTarget(from: Vector3): BasePart?
	local items = workspace:FindFirstChild("ConveyorItems")
	local parts = {}
	for _, item in childrenOf(items) do
		if item:IsA("Model") and item:GetAttribute("OwnerUserId") == player.UserId then
			local part = CompanyLabel.mainPart(item)
			if part then
				table.insert(parts, part)
			end
		end
	end
	local found = nearest(parts, from)
	if found then
		return found
	end
	local base = myBase()
	local conveyor = base and base:FindFirstChild("Conveyor")
	local belt = conveyor and conveyor:FindFirstChild("Belt")
	return if belt and belt:IsA("BasePart") then belt else nil
end

-- The nearest free, open plot on this player's base.
local function plotTarget(from: Vector3): BasePart?
	local base = myBase()
	local floors = base and base:FindFirstChild("Floors")
	local parts = {}
	for _, floor in childrenOf(floors) do
		local plots = floor:FindFirstChild("Plots")
		for _, plot in childrenOf(plots) do
			if
				plot:IsA("BasePart")
				and plot:GetAttribute("Unlocked") == true
				and plot:GetAttribute("CompanyId") == nil
			then
				table.insert(parts, plot)
			end
		end
	end
	return nearest(parts, from)
end

local function machineTarget(): BasePart?
	local base = myBase()
	local machine = base and base:FindFirstChild("Machine")
	local pad = machine and machine:FindFirstChild("Pad")
	return if pad and pad:IsA("BasePart") then pad else nil
end

local function lockTarget(): BasePart?
	local base = myBase()
	local button = base and base:FindFirstChild("LockButton")
	return if button and button:IsA("BasePart") then button else nil
end

-- Where to point and what to say for the step, given what the player is
-- carrying right now. The point is a world position near the target part.
local function guide(step: number, from: Vector3): (string, BasePart?, Vector3?)
	local carrying = player:GetAttribute("CarryingCompanyId") ~= nil
	local valued = player:GetAttribute("CarryingValued") == true
	local hint = Onboarding.Hints[step] or ""
	if step == Steps.Buy then
		return hint, conveyorTarget(from), nil
	elseif step == Steps.Place then
		if carrying then
			return hint, plotTarget(from), nil
		end
		return "Take your company out of Storage (left of the screen), then place it on a plot", nil, nil
	elseif step == Steps.Machine then
		if carrying and not valued then
			return "Put it in the Valuation Machine: press Take when the number looks good", machineTarget(), nil
		elseif carrying then
			return "Now place it on a free plot", plotTarget(from), nil
		end
		return "Buy another company and take it to the Valuation Machine", conveyorTarget(from), nil
	elseif step == Steps.Lock then
		return hint, lockTarget(), nil
	elseif step == Steps.Middle then
		-- The nearest point along the middle conveyor.
		local map = workspace:FindFirstChild("Map")
		local shared = map and map:FindFirstChild("SharedConveyor")
		local startPart = shared and shared:FindFirstChild("Start")
		local endPart = shared and shared:FindFirstChild("End")
		if startPart and endPart and startPart:IsA("BasePart") and endPart:IsA("BasePart") then
			local a, b = startPart.Position, endPart.Position
			local along = b - a
			local t = math.clamp((from - a):Dot(along) / along:Dot(along), 0, 1)
			return hint, startPart, a + along * t
		end
		return hint, nil, nil
	end
	return "", nil, nil
end

function TutorialController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 1)
	banner.Position = UDim2.new(0.5, 0, 1, -BANNER_BOTTOM_GAP)
	banner.Size = UDim2.new(0.9, 0, 0, 64)
	banner.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	banner.BackgroundTransparency = 0.15
	banner.Visible = false
	banner.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = banner
	local stroke = Instance.new("UIStroke")
	stroke.Color = LINE_COLOUR
	stroke.Thickness = 2
	stroke.Parent = banner
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(BANNER_MAX_WIDTH, 64)
	sizeLimit.Parent = banner

	local text = Instance.new("TextLabel")
	text.Position = UDim2.fromOffset(12, 0)
	text.Size = UDim2.new(1, -96, 1, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.BuilderSansBold
	text.TextSize = 16
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextWrapped = true
	text.RichText = true
	text.Parent = banner

	local skip = Instance.new("TextButton")
	skip.AnchorPoint = Vector2.new(1, 0.5)
	skip.Position = UDim2.new(1, -8, 0.5, 0)
	skip.Size = UDim2.fromOffset(72, 44)
	skip.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	skip.Font = Enum.Font.BuilderSansBold
	skip.TextSize = 15
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.Text = "Skip"
	skip.Parent = banner
	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 8)
	skipCorner.Parent = skip
	skip.Activated:Connect(function()
		Remotes.SkipTutorial:FireServer()
		banner.Visible = false
	end)

	gui.Parent = player:WaitForChild("PlayerGui")

	-- The line and marker: a beam between two attachments, and a marker above
	-- the far end. Both are only on this player's screen. The attachments live
	-- on the terrain and are moved every frame, so a target being bought or a
	-- character respawning can't remove them.
	local fromAttachment = Instance.new("Attachment")
	fromAttachment.Name = "TutorialFrom"
	fromAttachment.Parent = workspace.Terrain
	local toAttachment = Instance.new("Attachment")
	toAttachment.Name = "TutorialTo"
	toAttachment.Parent = workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Attachment0 = fromAttachment
	beam.Attachment1 = toAttachment
	beam.Color = ColorSequence.new(LINE_COLOUR)
	beam.LightEmission = 1
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.Transparency = NumberSequence.new(0.2)
	beam.Enabled = false
	beam.Parent = fromAttachment

	local marker = Instance.new("BillboardGui")
	marker.Name = "TutorialMarker"
	marker.Size = UDim2.fromOffset(60, 60)
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.Adornee = toAttachment
	marker.Enabled = false
	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.BuilderSansBold
	arrow.TextScaled = true
	arrow.TextColor3 = LINE_COLOUR
	arrow.TextStrokeTransparency = 0.2
	arrow.Text = "▼"
	arrow.Parent = marker
	marker.Parent = player:WaitForChild("PlayerGui")

	local target: BasePart? = nil
	local point: Vector3? = nil

	local function update()
		local step = numberAttribute("TutorialStep")
		local showing = step >= Steps.Buy
			and step < Steps.Done
			and workspace:GetServerTimeNow() >= numberAttribute("TutorialShowAt")
		local root = rootOf()
		local hint, newTarget, newPoint = "", nil, nil
		if showing and root then
			hint, newTarget, newPoint = guide(step, root.Position)
		end
		banner.Visible = showing and hint ~= ""
		text.Text = `<font color="#FFD246">{step}/{Steps.Done - 1}</font>  {hint}`
		target, point = newTarget, newPoint
	end

	RunService.RenderStepped:Connect(function()
		local current = target
		local root = rootOf()
		local visible = current ~= nil and current.Parent ~= nil and root ~= nil
		beam.Enabled = visible
		marker.Enabled = visible
		if current == nil or root == nil or not visible then
			return
		end
		local spot = point or current.Position
		fromAttachment.WorldPosition = root.Position
		toAttachment.WorldPosition = spot
		local height = if point then 3 else current.Size.Y / 2 + 3
		if current.Name == "LockButton" then
			-- Above the lock button's own sign.
			height += LOCK_SIGN_HEIGHT
		end
		marker.StudsOffsetWorldSpace = Vector3.new(0, height + math.sin(os.clock() * 4) * 0.6, 0)
	end)

	while true do
		update()
		task.wait(TARGET_SECONDS)
	end
end

return TutorialController
