--!strict
-- Draws companies travelling along conveyors. The server places each company
-- at its Start and stores its path as attributes; this moves it every frame
-- with the same maths the server uses, so what players see matches what the
-- server checks. Each company gets a label, and companies this player may buy
-- get a Buy prompt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local ConveyorConfig = require(ReplicatedStorage.Shared.Config.Conveyor)
local ConveyorPath = require(ReplicatedStorage.Shared.ConveyorPath)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CompanyLabel = require(script.Parent.Parent.Ui.CompanyLabel)

type Path = {
	startCFrame: CFrame,
	endCFrame: CFrame,
	spawnedAt: number,
	travelSeconds: number,
}

local player = Players.LocalPlayer
local paths: { [Model]: Path } = {}

local ConveyorController = {}

local function addBuyPrompt(adornee: BasePart, itemId: string, companyName: string, price: number)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = companyName
	prompt.ActionText = `Buy {Format.cash(price)}`
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = ConveyorConfig.BuyDistance
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		Remotes.BuyConveyorItem:FireServer(itemId)
	end)
	prompt.Parent = adornee
end

local function track(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance

	local itemId = model:GetAttribute("ItemId")
	local companyId = model:GetAttribute("CompanyId")
	local tierId = model:GetAttribute("Tier")
	local price = model:GetAttribute("Price")
	local income = model:GetAttribute("Income")
	local ownerUserId = model:GetAttribute("OwnerUserId")
	local spawnedAt = model:GetAttribute("SpawnedAt")
	local travelSeconds = model:GetAttribute("TravelSeconds")
	local startCFrame = model:GetAttribute("StartCFrame")
	local endCFrame = model:GetAttribute("EndCFrame")
	if
		typeof(itemId) ~= "string"
		or typeof(companyId) ~= "string"
		or typeof(tierId) ~= "string"
		or typeof(price) ~= "number"
		or typeof(income) ~= "number"
		or typeof(ownerUserId) ~= "number"
		or typeof(spawnedAt) ~= "number"
		or typeof(travelSeconds) ~= "number"
		or typeof(startCFrame) ~= "CFrame"
		or typeof(endCFrame) ~= "CFrame"
	then
		return
	end

	paths[model] = {
		startCFrame = startCFrame,
		endCFrame = endCFrame,
		spawnedAt = spawnedAt,
		travelSeconds = travelSeconds,
	}

	CompanyLabel.attach(model, companyId, tierId, `{Format.cash(price)}  ·  {Format.income(income)}`)

	local company = Companies.byId[companyId]
	local adornee = CompanyLabel.mainPart(model)
	if company == nil or adornee == nil then
		return
	end
	if ownerUserId == 0 or ownerUserId == player.UserId then
		addBuyPrompt(adornee, itemId, company.name, price)
	end
end

function ConveyorController:Start()
	local folder = workspace:WaitForChild("ConveyorItems")

	folder.ChildAdded:Connect(track)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			paths[child] = nil
		end
	end)
	for _, child in folder:GetChildren() do
		track(child)
	end

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		for model, path in paths do
			model:PivotTo(
				ConveyorPath.cframeAt(path.startCFrame, path.endCFrame, path.spawnedAt, path.travelSeconds, now)
			)
		end
	end)
end

return ConveyorController
