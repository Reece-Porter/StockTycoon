--!strict
-- Spawns companies on the personal conveyor of every owned base and removes
-- any nobody bought once they reach the End.
--
-- The server never moves the models. Each one is placed at its Start with its
-- path and spawn time stored as attributes, and clients draw the movement with
-- ConveyorPath. When the server needs a position (to check buying distance) it
-- works it out from the same maths, so both always agree.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BaseService = require(script.Parent.BaseService)
local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local CompanyStats = require(ReplicatedStorage.Shared.CompanyStats)
local ConveyorConfig = require(ReplicatedStorage.Shared.Config.Conveyor)
local ConveyorPath = require(ReplicatedStorage.Shared.ConveyorPath)
local SpawnRoll = require(ReplicatedStorage.Shared.SpawnRoll)

export type Item = {
	id: string,
	companyId: string,
	tier: string,
	price: number,
	income: number,
	-- Only this player may buy it. 0 means anyone (the shared conveyor).
	ownerUserId: number,
	spawnedAt: number,
	startCFrame: CFrame,
	endCFrame: CFrame,
	model: Model,
	-- The base whose personal conveyor it is on.
	base: BaseService.Base?,
}

local items: { [string]: Item } = {}
local nextSpawnAt: { [BaseService.Base]: number } = {}
local random = Random.new()
local itemsFolder: Folder

local ConveyorService = {}

local function companyModelsFolder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Companies")
end

-- The company's own model, or the Default model until it has one.
local function findModel(companyId: string): Model?
	local folder = companyModelsFolder()
	if folder == nil then
		return nil
	end
	local model = folder:FindFirstChild(companyId) or folder:FindFirstChild("Default")
	return if model and model:IsA("Model") then model else nil
end

-- Says once, at startup, which models are missing, rather than inventing any.
local function reportMissingModels()
	local folder = companyModelsFolder()
	if folder == nil then
		warn("[ConveyorService] ReplicatedStorage.Assets.Companies is missing, so no companies can spawn.")
		return
	end

	local missing = {}
	for _, company in Companies.list do
		if folder:FindFirstChild(company.id) == nil then
			table.insert(missing, company.id)
		end
	end
	if #missing == 0 then
		return
	end

	local default = folder:FindFirstChild("Default")
	if default and default:IsA("Model") then
		print(`[ConveyorService] {#missing} companies have no model yet and use Default: {table.concat(missing, ", ")}`)
	else
		warn(
			`[ConveyorService] ReplicatedStorage.Assets.Companies.Default is missing, so these companies can't spawn: {table.concat(
				missing,
				", "
			)}`
		)
	end
end

-- Start and End CFrames that sit the model's bottom on the belt, facing the
-- way it travels. Start and End parts mark the belt surface with their bottom.
local function pathFor(base: BaseService.Base, model: Model): (CFrame, CFrame)
	local startPart, endPart = base.conveyorStart, base.conveyorEnd
	local startPoint = startPart.Position - Vector3.new(0, startPart.Size.Y / 2, 0)
	local endPoint = endPart.Position - Vector3.new(0, endPart.Size.Y / 2, 0)

	local boxCFrame, boxSize = model:GetBoundingBox()
	local lift = Vector3.new(0, model:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2), 0)
	local facing = CFrame.lookAt(startPoint, endPoint).Rotation

	return CFrame.new(startPoint + lift) * facing, CFrame.new(endPoint + lift) * facing
end

local function spawnItem(base: BaseService.Base, tierId: string?): Item?
	local owner = base.owner
	if owner == nil then
		return nil
	end

	local tier = tierId or SpawnRoll.pickTier(ConveyorConfig.Personal.Weights, random:NextNumber())
	local choices = Companies.byTier[tier]
	if choices == nil or #choices == 0 then
		return nil
	end
	local company = choices[SpawnRoll.pickIndex(#choices, random:NextNumber())]

	local template = findModel(company.id)
	if template == nil then
		return nil
	end
	local model = template:Clone()
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end

	local startCFrame, endCFrame = pathFor(base, model)
	local item: Item = {
		id = HttpService:GenerateGUID(false),
		companyId = company.id,
		tier = tier,
		price = CompanyStats.price(company.id),
		income = CompanyStats.income(company.id),
		ownerUserId = owner.UserId,
		spawnedAt = workspace:GetServerTimeNow(),
		startCFrame = startCFrame,
		endCFrame = endCFrame,
		model = model,
		base = base,
	}

	model.Name = item.id
	model:SetAttribute("ItemId", item.id)
	model:SetAttribute("CompanyId", item.companyId)
	model:SetAttribute("Tier", item.tier)
	model:SetAttribute("Price", item.price)
	model:SetAttribute("Income", item.income)
	model:SetAttribute("OwnerUserId", item.ownerUserId)
	model:SetAttribute("SpawnedAt", item.spawnedAt)
	model:SetAttribute("TravelSeconds", ConveyorConfig.TravelSeconds)
	model:SetAttribute("StartCFrame", startCFrame)
	model:SetAttribute("EndCFrame", endCFrame)
	model:PivotTo(startCFrame)
	model.Parent = itemsFolder

	items[item.id] = item
	return item
end

function ConveyorService:GetItem(itemId: string): Item?
	return items[itemId]
end

-- Where the item's model is right now, worked out from the server clock.
function ConveyorService:GetItemPosition(item: Item): Vector3
	return ConveyorPath.cframeAt(
		item.startCFrame,
		item.endCFrame,
		item.spawnedAt,
		ConveyorConfig.TravelSeconds,
		workspace:GetServerTimeNow()
	).Position
end

function ConveyorService:RemoveItem(itemId: string)
	local item = items[itemId]
	if item then
		items[itemId] = nil
		item.model:Destroy()
	end
end

-- Spawns a company of the given tier on a base's conveyor straight away. For
-- admin testing.
function ConveyorService:SpawnOnBase(base: BaseService.Base, tierId: string): Item?
	return spawnItem(base, tierId)
end

function ConveyorService:Init()
	itemsFolder = Instance.new("Folder")
	itemsFolder.Name = "ConveyorItems"
	itemsFolder.Parent = workspace
	reportMissingModels()
end

function ConveyorService:Start()
	BaseService:OnBaseFreed(function(_player, base)
		nextSpawnAt[base] = nil
		for itemId, item in items do
			if item.base == base then
				ConveyorService:RemoveItem(itemId)
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()

		for _, base in BaseService:GetBases() do
			if base.owner then
				local due = nextSpawnAt[base]
				if due == nil or now >= due then
					nextSpawnAt[base] = now + ConveyorConfig.Personal.SpawnSeconds
					spawnItem(base, nil)
				end
			end
		end

		for itemId, item in items do
			if now - item.spawnedAt >= ConveyorConfig.TravelSeconds then
				ConveyorService:RemoveItem(itemId)
			end
		end
	end)
end

return ConveyorService
