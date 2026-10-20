--!strict
-- Cash pads (CollectService): the Cash waiting on every pad, shown just above
-- it, and a "+$12" that floats up when this player collects from one of
-- theirs. The server sets each pad's Cash attribute and does the collecting
-- when the owner steps on a pad.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LABEL_NAME = "CashLabel"
local LABEL_SIZE = UDim2.fromOffset(120, 30)
local LABEL_HEIGHT = 1.6
-- Labels on pads further away than this aren't drawn, so a base full of
-- pads doesn't crowd the screen.
local LABEL_DISTANCE = 45
local CASH_COLOUR = Color3.fromRGB(60, 203, 90)
local POP_SIZE = UDim2.fromOffset(160, 44)
local POP_RISE = 4
local POP = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local CollectController = {}

local function label(parent: Instance, size: UDim2, text: string?): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = size
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.BuilderSansBold
	textLabel.TextScaled = true
	textLabel.TextColor3 = CASH_COLOUR
	textLabel.TextStrokeColor3 = Color3.fromRGB(20, 40, 20)
	textLabel.TextStrokeTransparency = 0.2
	textLabel.Text = text or ""
	textLabel.Parent = parent
	return textLabel
end

local function setUpPad(pad: Instance)
	if not pad:IsA("BasePart") or pad:FindFirstChild(LABEL_NAME) then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = LABEL_NAME
	gui.Size = LABEL_SIZE
	gui.StudsOffsetWorldSpace = Vector3.new(0, LABEL_HEIGHT, 0)
	gui.MaxDistance = LABEL_DISTANCE
	gui.LightInfluence = 0
	gui.Enabled = false
	local text = label(gui, UDim2.fromScale(1, 1))
	gui.Parent = pad

	local function refresh()
		local cash = pad:GetAttribute("Cash")
		gui.Enabled = typeof(cash) == "number" and cash >= 1
		if typeof(cash) == "number" then
			text.Text = Format.cash(cash)
		end
	end
	pad:GetAttributeChangedSignal("Cash"):Connect(refresh)
	refresh()
end

-- Pads stream in and out with distance, and upper floors come and go as
-- they're opened, so watch the folders.
local function watchBase(base: Instance)
	local floors = base:WaitForChild("Floors", 30)
	if floors == nil then
		return
	end
	local function watchPads(pads: Instance)
		pads.ChildAdded:Connect(setUpPad)
		for _, pad in pads:GetChildren() do
			setUpPad(pad)
		end
	end
	local function watchFloor(floor: Instance)
		local pads = floor:FindFirstChild("CollectPads")
		if pads then
			watchPads(pads)
		else
			floor.ChildAdded:Connect(function(child)
				if child.Name == "CollectPads" then
					watchPads(child)
				end
			end)
		end
	end
	floors.ChildAdded:Connect(watchFloor)
	for _, floor in floors:GetChildren() do
		watchFloor(floor)
	end
end

-- "+$12" rising from the pad and fading away.
local function pop(pad: BasePart, amount: number)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = pad.Position + Vector3.new(0, LABEL_HEIGHT, 0)
	anchor.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = POP_SIZE
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	local text = label(gui, UDim2.fromScale(1, 1), `+{Format.cash(amount)}`)
	gui.Parent = anchor
	TweenService:Create(gui, POP, { StudsOffsetWorldSpace = Vector3.new(0, POP_RISE, 0) }):Play()
	local fade = TweenService:Create(text, POP, { TextTransparency = 1, TextStrokeTransparency = 1 })
	fade.Completed:Connect(function()
		anchor:Destroy()
	end)
	fade:Play()
end

function CollectController:Start()
	Remotes.Collected.OnClientEvent:Connect(function(pad: unknown, amount: unknown)
		if typeof(pad) == "Instance" and pad:IsA("BasePart") and typeof(amount) == "number" then
			pop(pad, amount)
		end
	end)

	local bases = workspace:WaitForChild("Map"):WaitForChild("Bases")
	bases.ChildAdded:Connect(function(base)
		task.spawn(watchBase, base)
	end)
	for _, base in bases:GetChildren() do
		task.spawn(watchBase, base)
	end
end

return CollectController
