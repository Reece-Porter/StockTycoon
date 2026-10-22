--!strict
-- Companies knocked out of someone's hands, lying in
-- Workspace.DroppedCompanies. Each gets a "Pick up" prompt and a label
-- counting down until it goes back where it belongs. The server decides who
-- gets it: the first valid request wins.
--
-- Looks (docs/visual-pass.md, Phase 9): a company that drops while this
-- player is here bounces as it lands, and every dropped company has a ring of
-- glowing dots on the ground round it in its tier's colour, going out one by
-- one as its time runs down.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local CompanyLabel = require(script.Parent.Parent.Ui.CompanyLabel)

local UPDATE_SECONDS = 0.25
local RING_DOTS = 20
-- Between the company's widest side and the ring.
local RING_GAP = 0.8
local DOT_SIZE = 0.7
local BOUNCE_SECONDS = 0.7
local BOUNCE_HEIGHT = 3

type Drop = { model: Model, prompt: ProximityPrompt, detail: TextLabel?, ring: { BasePart } }

local player = Players.LocalPlayer
local drops: { [Model]: Drop } = {}
-- Set once the drops already there have been set up: only new drops bounce.
local live = false

local DropController = {}

local function secondsLeft(model: Model): number
	local returnsAt = model:GetAttribute("ReturnsAt")
	return if typeof(returnsAt) == "number" then math.max(0, returnsAt - workspace:GetServerTimeNow()) else 0
end

local function update(drop: Drop)
	local model = drop.model
	local isMine = model:GetAttribute("OwnerUserId") == player.UserId
	local left = math.ceil(secondsLeft(model))
	local detail = drop.detail
	if detail then
		detail.Text = if isMine then `Yours! Back in {left}s` else `Grab it! Gone in {left}s`
	end
	drop.prompt.ActionText = if isMine then "Get back" else "Pick up"
	local lit = math.ceil(secondsLeft(model) / CombatConfig.DropReturnSeconds * #drop.ring)
	for index, dot in drop.ring do
		dot.Transparency = if index <= lit then 0.15 else 1
	end
	drop.prompt.Enabled = player:GetAttribute("CarryingCompanyId") == nil
end

-- The ring of dots on the ground round the company.
local function addRing(model: Model, tier: string): { BasePart }
	local box, size = model:GetBoundingBox()
	local centre = box.Position - Vector3.new(0, size.Y / 2 - 0.1, 0)
	local radius = math.max(size.X, size.Z) / 2 + RING_GAP
	local colour = Theme.Tiers[tier] or Theme.Colours.Gold
	local holder = Instance.new("Model")
	holder.Name = "DropRing"
	local dots: { BasePart } = {}
	for index = 1, RING_DOTS do
		local angle = (index - 1) / RING_DOTS * 2 * math.pi
		local dot = Instance.new("Part")
		dot.Name = "Dot"
		dot.Shape = Enum.PartType.Cylinder
		dot.Size = Vector3.new(0.12, DOT_SIZE, DOT_SIZE)
		-- A cylinder lies along x: stand it up as a flat disc.
		local at = centre + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		dot.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
		dot.Color = colour
		dot.Material = Enum.Material.Neon
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanTouch = false
		dot.CanQuery = false
		dot.CastShadow = false
		dot.Parent = holder
		table.insert(dots, dot)
	end
	holder.Parent = model
	return dots
end

-- Drops the company in from a little above, bouncing twice before it
-- settles where the server put it.
local function bounce(model: Model, parts: { BasePart })
	local rest: { CFrame } = {}
	for _, part in parts do
		table.insert(rest, part.CFrame)
	end
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= BOUNCE_SECONDS or model.Parent == nil then
			if connection then
				connection:Disconnect()
			end
			workspace:BulkMoveTo(parts, rest, Enum.BulkMoveMode.FireCFrameChanged)
			return
		end
		local left = 1 - t / BOUNCE_SECONDS
		local height = BOUNCE_HEIGHT * math.abs(math.cos(t / BOUNCE_SECONDS * 2.5 * math.pi)) * left * left
		local cframes: { CFrame } = {}
		for index, cframe in rest do
			cframes[index] = cframe + Vector3.new(0, height, 0)
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

local function setUp(child: Instance)
	if not child:IsA("Model") or drops[child] then
		return
	end
	local model = child
	local instanceId = model:GetAttribute("InstanceId")
	local companyId = model:GetAttribute("CompanyId")
	local tier = model:GetAttribute("Tier")
	local part = CompanyLabel.mainPart(model)
	if typeof(instanceId) ~= "string" or typeof(companyId) ~= "string" or typeof(tier) ~= "string" or part == nil then
		return
	end

	local company = Companies.byId[companyId]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickUpPrompt"
	prompt.ObjectText = if company then company.name else companyId
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = CombatConfig.PickUpDistance
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		Remotes.PickUpDropped:FireServer(instanceId)
	end)
	prompt.Parent = part

	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Anchored then
			table.insert(parts, descendant)
		end
	end
	local drop: Drop = {
		model = model,
		prompt = prompt,
		detail = CompanyLabel.detail(CompanyLabel.attach(model, companyId, tier, "")),
		ring = addRing(model, tier),
	}
	if live then
		bounce(model, parts)
	end
	drops[model] = drop
	model.Destroying:Connect(function()
		drops[model] = nil
	end)
	update(drop)
end

function DropController:Start()
	local folder = workspace:WaitForChild("DroppedCompanies")
	folder.ChildAdded:Connect(setUp)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			drops[child] = nil
		end
	end)
	for _, child in folder:GetChildren() do
		setUp(child)
	end
	live = true

	while true do
		for _, drop in drops do
			update(drop)
		end
		task.wait(UPDATE_SECONDS)
	end
end

return DropController
