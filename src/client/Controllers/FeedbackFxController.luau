--!strict
-- Quick pops for the moments that matter (docs/visual-pass.md, Phase 9), on
-- each player's own screen, all short and in the world (Ui/WorldPop) so they
-- never cover the HUD. Looks only; the server has already done each thing.
--   - "SOLD!" over anyone who buys a company (their BoughtCount goes up).
--   - "YOINK!" over anyone who starts carrying off someone else's company
--     (CarryingStolen).
--   - "TAGGED!" over a thief the owner caught (their TaggedCount goes up).
--   - "REBIRTH!" over anyone else who rebirths, and the celebration on this
--     player's screen when they do (Ui/Celebration).
--   - Now and then a small "+$12" over a plot near the camera as its cash
--     pad fills: each plot at most every few seconds, and only one pop at a
--     time, so a full base never spams.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RebirthMath = require(ReplicatedStorage.Shared.RebirthMath)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Celebration = require(script.Parent.Parent.Ui.Celebration)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)
local WorldPop = require(script.Parent.Parent.Ui.WorldPop)

local HEAD_OFFSET = Vector3.new(0, 4.5, 0)
local PLOT_OFFSET = Vector3.new(0, 5, 0)
-- Income pops: how often the check runs, how long a plot waits between
-- pops, and how near the camera its plot must be.
local INCOME_CHECK_SECONDS = 0.5
local INCOME_EVERY = 8
local INCOME_DISTANCE = 45

type Pad = { pad: BasePart, last: number, pending: number, poppedAt: number }

local player = Players.LocalPlayer
local pads: { [BasePart]: Pad } = {}

local FeedbackFxController = {}

local function headOf(other: Player): BasePart?
	local character = other.Character
	local head = character and character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

local function popOver(other: Player, text: string, colour: Color3, icon: Icons.IconName?)
	local head = headOf(other)
	if head then
		WorldPop.show(head, HEAD_OFFSET, text, { colour = colour, icon = icon })
	end
end

local function numberAttribute(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

-- Calls onRise whenever the attribute goes up from a number it already had
-- (not when it first arrives, as the player's data loads).
local function onRise(other: Player, name: string, onRiseCallback: (number) -> ())
	local last = numberAttribute(other, name)
	other:GetAttributeChangedSignal(name):Connect(function()
		local value = numberAttribute(other, name)
		if value and last and value > last then
			onRiseCallback(value)
		end
		last = value
	end)
end

function FeedbackFxController.celebrate(rebirths: number): ScreenGui?
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local multiplier = RebirthMath.incomeMultiplier(rebirths)
	return Celebration.play(playerGui, "REBIRTH!", `Rebirth {rebirths}: income x{multiplier} for good`)
end

local function watchPlayer(other: Player)
	onRise(other, "BoughtCount", function()
		popOver(other, "SOLD!", Theme.Colours.Cash, "Cash")
	end)
	onRise(other, "TaggedCount", function()
		popOver(other, "TAGGED!", Theme.Colours.Danger)
	end)
	other:GetAttributeChangedSignal("CarryingStolen"):Connect(function()
		if other:GetAttribute("CarryingStolen") == true then
			popOver(other, "YOINK!", Theme.Colours.Purple)
		end
	end)
	onRise(other, "Rebirths", function(rebirths)
		if other == player then
			FeedbackFxController.celebrate(rebirths)
		else
			popOver(other, "REBIRTH!", Theme.Colours.Gold)
		end
	end)
end

-- Cash pads: watch each one's Cash, adding up what arrives between pops.
local function watchPad(pad: Instance)
	if not pad:IsA("BasePart") or pads[pad] then
		return
	end
	local entry: Pad = { pad = pad, last = numberAttribute(pad, "Cash") or 0, pending = 0, poppedAt = -math.huge }
	pads[pad] = entry
	pad:GetAttributeChangedSignal("Cash"):Connect(function()
		local value = numberAttribute(pad, "Cash") or 0
		if value > entry.last then
			entry.pending += value - entry.last
		end
		entry.last = value
	end)
end

local function watchFloor(floor: Instance)
	local collectPads = floor:FindFirstChild("CollectPads")
	if collectPads then
		for _, pad in collectPads:GetChildren() do
			watchPad(pad)
		end
		collectPads.ChildAdded:Connect(watchPad)
	end
end

local function watchBase(base: Instance)
	local floors = base:FindFirstChild("Floors")
	if floors then
		for _, floor in floors:GetChildren() do
			watchFloor(floor)
		end
		floors.ChildAdded:Connect(watchFloor)
	end
end

-- The plot a pad belongs to: PlotN for PadN on the same floor.
local function plotFor(pad: BasePart): BasePart?
	local floor = pad.Parent and pad.Parent.Parent
	local plots = floor and floor:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild((string.gsub(pad.Name, "^Pad", "Plot")))
	return if plot and plot:IsA("BasePart") then plot else nil
end

-- One income pop at most: the nearest plot that has earned since its last
-- pop and hasn't popped for a while.
function FeedbackFxController.incomePop(cameraPosition: Vector3, now: number): BillboardGui?
	local best: Pad? = nil
	local bestDistance = INCOME_DISTANCE
	for pad, entry in pads do
		-- A floor going out of the world (a rebirth) takes its pads with it.
		if pad.Parent == nil then
			pads[pad] = nil
			continue
		end
		if entry.pending > 0 and now - entry.poppedAt >= INCOME_EVERY and pad:IsDescendantOf(workspace) then
			local distance = (pad.Position - cameraPosition).Magnitude
			if distance <= bestDistance then
				best = entry
				bestDistance = distance
			end
		end
	end
	if best == nil then
		return nil
	end
	local plot = plotFor(best.pad)
	local amount = best.pending
	best.pending = 0
	best.poppedAt = now
	if plot == nil then
		return nil
	end
	return WorldPop.show(plot, PLOT_OFFSET, `+{Format.cash(amount)}`, {
		colour = Theme.Colours.Cash,
		size = 70,
		burst = false,
		rise = 2.5,
	})
end

function FeedbackFxController:Start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	local map = workspace:WaitForChild("Map")
	local bases = map:WaitForChild("Bases")
	for _, base in bases:GetChildren() do
		watchBase(base)
	end
	bases.ChildAdded:Connect(watchBase)
	while true do
		local camera = workspace.CurrentCamera
		if camera then
			FeedbackFxController.incomePop(camera.CFrame.Position, os.clock())
		end
		task.wait(INCOME_CHECK_SECONDS)
	end
end

return FeedbackFxController
