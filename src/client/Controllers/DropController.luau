--!strict
-- Companies knocked out of someone's hands, lying in
-- Workspace.DroppedCompanies. Each gets a "Pick up" prompt and a label
-- counting down until it goes back where it belongs. The server decides who
-- gets it: the first valid request wins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CompanyLabel = require(script.Parent.Parent.Ui.CompanyLabel)

local UPDATE_SECONDS = 0.25

type Drop = { model: Model, prompt: ProximityPrompt, detail: TextLabel? }

local player = Players.LocalPlayer
local drops: { [Model]: Drop } = {}

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
	drop.prompt.Enabled = player:GetAttribute("CarryingCompanyId") == nil
end

-- The label's third line is its detail text.
local function detailLabel(gui: BillboardGui?): TextLabel?
	if gui == nil then
		return nil
	end
	for _, child in gui:GetChildren() do
		if child:IsA("TextLabel") and child.LayoutOrder == 3 then
			return child
		end
	end
	return nil
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

	local drop: Drop = {
		model = model,
		prompt = prompt,
		detail = detailLabel(CompanyLabel.attach(model, companyId, tier, "")),
	}
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

	while true do
		for _, drop in drops do
			update(drop)
		end
		task.wait(UPDATE_SECONDS)
	end
end

return DropController
