--!strict
-- Runs the conveyors ("lanes"): each owned base's personal conveyor, and the
-- shared conveyor in the middle of the map (Workspace.Map.SharedConveyor,
-- built by hand with Start and End parts like a base's Conveyor). Each lane
-- spawns companies with its own odds and timing from Config/Conveyor (personal
-- odds improve with the owner's rebirths, RebirthMath) and
-- removes any nobody bought once they reach the End. Conglomerate and Monopoly
-- spawns on the shared conveyor are announced to the whole server.
--
-- The server never moves the models. Each one is placed at its Start with its
-- path and spawn time stored as attributes, and clients draw the movement with
-- ConveyorPath. When the server needs a position (to check buying distance) it
-- works it out from the same maths, so both always agree.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local CompanyStats = require(ReplicatedStorage.Shared.CompanyStats)
local ConveyorConfig = require(ReplicatedStorage.Shared.Config.Conveyor)
local ConveyorPath = require(ReplicatedStorage.Shared.ConveyorPath)
local RebirthMath = require(ReplicatedStorage.Shared.RebirthMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpawnRoll = require(ReplicatedStorage.Shared.SpawnRoll)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local CompanyModels = require(script.Parent.Parent.Lib.CompanyModels)

export type Lane = {
	startPart: BasePart,
	endPart: BasePart,
	weights: { ConveyorConfig.WeightEntry },
	spawnSeconds: number,
	-- How long a company takes from Start to End: the belt's length over its
	-- speed.
	travelSeconds: number,
	-- The base this is the personal conveyor of; nil for the shared conveyor.
	base: BaseService.Base?,
	nextSpawnAt: number?,
}

export type Item = {
	id: string,
	companyId: string,
	tier: string,
	price: number,
	income: number,
	-- Only this player may buy it. 0 means anyone (the shared conveyor).
	ownerUserId: number,
	spawnedAt: number,
	travelSeconds: number,
	startCFrame: CFrame,
	endCFrame: CFrame,
	model: Model,
	lane: Lane,
}

local items: { [string]: Item } = {}
local personalLanes: { [BaseService.Base]: Lane } = {}
local sharedLane: Lane? = nil
local problems: { string } = {}
local random = Random.new()
local itemsFolder: Folder

local ConveyorService = {}

-- Start and End CFrames that sit the model's bottom on the belt, facing the
-- way it travels. Start and End parts mark the belt surface with their bottom.
local function pathFor(lane: Lane, model: Model): (CFrame, CFrame)
	local startPart, endPart = lane.startPart, lane.endPart
	local startPoint = startPart.Position - Vector3.new(0, startPart.Size.Y / 2, 0)
	local endPoint = endPart.Position - Vector3.new(0, endPart.Size.Y / 2, 0)

	local lift = Vector3.new(0, CompanyModels.pivotHeight(model), 0)
	local facing = CFrame.lookAt(startPoint, endPoint).Rotation

	return CFrame.new(startPoint + lift) * facing, CFrame.new(endPoint + lift) * facing
end

-- Who may buy from the lane: the base owner, 0 for anyone, or nil if a
-- personal lane's base has no owner right now.
local function travelSecondsFor(startPart: BasePart, endPart: BasePart, studsPerSecond: number): number
	return (endPart.Position - startPart.Position).Magnitude / studsPerSecond
end

local function laneOwnerId(lane: Lane): number?
	local base = lane.base
	if base == nil then
		return 0
	end
	local owner = base.owner
	return if owner then owner.UserId else nil
end

local function announce(item: Item)
	local tier = Tiers.byId[item.tier]
	local company = Companies.byId[item.companyId]
	Remotes.Notify:FireAllClients(`A {tier.name} just hit the shared conveyor: {company.name}!`)
end

-- A personal lane's odds after its owner's rebirths; the shared lane's as set.
local function weightsFor(lane: Lane): { ConveyorConfig.WeightEntry }
	local owner = lane.base and lane.base.owner
	local data = if owner then DataService:GetData(owner) else nil
	return if data then RebirthMath.personalWeights(lane.weights, data.Rebirths) else lane.weights
end

local function spawnItem(lane: Lane, tierId: string?): Item?
	local ownerUserId = laneOwnerId(lane)
	if ownerUserId == nil then
		return nil
	end

	local tier = tierId or SpawnRoll.pickTier(weightsFor(lane), random:NextNumber())
	local choices = Companies.byTier[tier]
	if choices == nil or #choices == 0 then
		return nil
	end
	local company = choices[SpawnRoll.pickIndex(#choices, random:NextNumber())]

	local model = CompanyModels.clone(company.id, true)
	if model == nil then
		return nil
	end

	local startCFrame, endCFrame = pathFor(lane, model)
	local item: Item = {
		id = HttpService:GenerateGUID(false),
		companyId = company.id,
		tier = tier,
		price = CompanyStats.price(company.id),
		income = CompanyStats.income(company.id),
		ownerUserId = ownerUserId,
		spawnedAt = workspace:GetServerTimeNow(),
		travelSeconds = lane.travelSeconds,
		startCFrame = startCFrame,
		endCFrame = endCFrame,
		model = model,
		lane = lane,
	}

	model.Name = item.id
	model:SetAttribute("ItemId", item.id)
	model:SetAttribute("CompanyId", item.companyId)
	model:SetAttribute("Tier", item.tier)
	model:SetAttribute("Price", item.price)
	model:SetAttribute("Income", item.income)
	model:SetAttribute("OwnerUserId", item.ownerUserId)
	model:SetAttribute("SpawnedAt", item.spawnedAt)
	model:SetAttribute("TravelSeconds", item.travelSeconds)
	model:SetAttribute("StartCFrame", startCFrame)
	model:SetAttribute("EndCFrame", endCFrame)
	model:PivotTo(startCFrame)
	model.Parent = itemsFolder

	items[item.id] = item
	if lane == sharedLane and ConveyorConfig.Shared.AnnounceTiers[tier] then
		announce(item)
	end
	return item
end

local function findSharedLane()
	local map = workspace:FindFirstChild("Map")
	local conveyor = map and map:FindFirstChild("SharedConveyor")
	if conveyor == nil then
		table.insert(problems, "Workspace.Map.SharedConveyor is missing")
		return
	end
	local startPart = conveyor:FindFirstChild("Start")
	local endPart = conveyor:FindFirstChild("End")
	if startPart == nil or not startPart:IsA("BasePart") or endPart == nil or not endPart:IsA("BasePart") then
		table.insert(problems, "Workspace.Map.SharedConveyor needs Start and End parts")
		return
	end
	if (startPart.Position - endPart.Position).Magnitude < 1 then
		table.insert(problems, "Workspace.Map.SharedConveyor Start and End are in the same place")
		return
	end
	sharedLane = {
		startPart = startPart,
		endPart = endPart,
		weights = ConveyorConfig.Shared.Weights,
		spawnSeconds = ConveyorConfig.Shared.SpawnSeconds,
		travelSeconds = travelSecondsFor(startPart, endPart, ConveyorConfig.Shared.StudsPerSecond),
		base = nil,
		nextSpawnAt = nil,
	}
end

local function isRunning(lane: Lane): boolean
	if lane.base then
		return lane.base.owner ~= nil
	end
	return #Players:GetPlayers() > 0
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
		item.travelSeconds,
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

-- Problems found with the hand-built shared conveyor, for the debug panel.
-- The odds on this player's personal conveyor, after their rebirths.
function ConveyorService:GetPersonalWeights(player: Player): { ConveyorConfig.WeightEntry }
	local data = DataService:GetData(player)
	local weights = ConveyorConfig.Personal.Weights
	return if data then RebirthMath.personalWeights(weights, data.Rebirths) else weights
end

function ConveyorService:GetProblems(): { string }
	return problems
end

-- Spawns a company of the given tier straight away, on a base's conveyor or
-- (with no base) on the shared conveyor. For admin testing.
function ConveyorService:SpawnNow(base: BaseService.Base?, tierId: string): Item?
	local lane = if base then personalLanes[base] else sharedLane
	return if lane then spawnItem(lane, tierId) else nil
end

function ConveyorService:Init()
	itemsFolder = Instance.new("Folder")
	itemsFolder.Name = "ConveyorItems"
	itemsFolder.Parent = workspace

	findSharedLane()
	for _, problem in problems do
		warn(`[ConveyorService] {problem}. Build it in Studio (see "Map naming" in docs/design.md).`)
	end
	CompanyModels.reportMissing()
end

function ConveyorService:Start()
	for _, base in BaseService:GetBases() do
		personalLanes[base] = {
			startPart = base.conveyorStart,
			endPart = base.conveyorEnd,
			weights = ConveyorConfig.Personal.Weights,
			spawnSeconds = ConveyorConfig.Personal.SpawnSeconds,
			travelSeconds = travelSecondsFor(
				base.conveyorStart,
				base.conveyorEnd,
				ConveyorConfig.Personal.StudsPerSecond
			),
			base = base,
			nextSpawnAt = nil,
		}
	end

	BaseService:OnBaseFreed(function(_player, base)
		local lane = personalLanes[base]
		if lane then
			lane.nextSpawnAt = nil
		end
		for itemId, item in items do
			if item.lane.base == base then
				ConveyorService:RemoveItem(itemId)
			end
		end
	end)

	-- Bases and the shared conveyor are fixed once the server starts.
	local lanes: { Lane } = {}
	for _, lane in personalLanes do
		table.insert(lanes, lane)
	end
	if sharedLane then
		table.insert(lanes, sharedLane)
	end

	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()

		for _, lane in lanes do
			if isRunning(lane) then
				local due = lane.nextSpawnAt
				if due == nil or now >= due then
					lane.nextSpawnAt = now + lane.spawnSeconds
					spawnItem(lane, nil)
				end
			end
		end

		for itemId, item in items do
			if now - item.spawnedAt >= item.travelSeconds then
				ConveyorService:RemoveItem(itemId)
			end
		end
	end)
end

return ConveyorService
