--!strict
-- Everything on a belt: the shared conveyor in the middle of the map
-- (Workspace.Map.SharedConveyor, with Start and End parts), which this runs,
-- and each base's own belt, which its Stock Spinner fills (SpinnerService,
-- through AddItem). The shared conveyor spawns companies with its own odds
-- and timing from Config/Conveyor and removes any nobody bought once they
-- reach the End. Each company may be a variant (VariantMath). Conglomerate
-- and Monopoly spawns, and the rarest variants, are announced to the whole
-- server.
--
-- The server never moves the models. Each one is placed where it comes out
-- with its path and the time it came out stored as attributes, and clients
-- draw the movement with ConveyorPath (stopping at the end of the path).
-- When the server needs a position (to check buying distance) it works it
-- out from the same maths, so both always agree.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local CompanyStats = require(ReplicatedStorage.Shared.CompanyStats)
local ConveyorConfig = require(ReplicatedStorage.Shared.Config.Conveyor)
local ConveyorPath = require(ReplicatedStorage.Shared.ConveyorPath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpawnRoll = require(ReplicatedStorage.Shared.SpawnRoll)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local VariantMath = require(ReplicatedStorage.Shared.VariantMath)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)
local BaseService = require(script.Parent.BaseService)
local CompanyModels = require(script.Parent.Parent.Lib.CompanyModels)

-- The shared conveyor.
type Lane = {
	startPart: BasePart,
	endPart: BasePart,
	-- How long a company takes from Start to End: the belt's length over its
	-- speed.
	travelSeconds: number,
	nextSpawnAt: number?,
}

export type Item = {
	id: string,
	companyId: string,
	tier: string,
	-- Config/Variants id, or nil for a regular company.
	variant: string?,
	price: number,
	-- The company's own income, before its variant.
	income: number,
	-- Only this player may buy it. 0 means anyone (the shared conveyor).
	ownerUserId: number,
	spawnedAt: number,
	travelSeconds: number,
	startCFrame: CFrame,
	endCFrame: CFrame,
	model: Model,
	-- The base whose belt it's on; nil on the shared conveyor.
	base: BaseService.Base?,
	-- When it goes if nobody buys it; nil if whoever added it takes it away.
	expiresAt: number?,
}

-- A company to put on a belt (AddItem).
export type NewItem = {
	companyId: string,
	-- Config/Variants id, or nil for a regular company.
	variant: string?,
	ownerUserId: number,
	base: BaseService.Base?,
	-- Where it comes out and where it stops, on the belt's surface.
	from: Vector3,
	to: Vector3,
	travelSeconds: number,
	expiresAt: number?,
}

local items: { [string]: Item } = {}
local sharedLane: Lane? = nil
local problems: { string } = {}
local random = Random.new()
local itemsFolder: Folder

local ConveyorService = {}

-- The point on the belt's surface a Start or End part marks: its bottom.
local function surface(part: BasePart): Vector3
	return part.Position - Vector3.new(0, part.Size.Y / 2, 0)
end

local function travelSecondsFor(startPart: BasePart, endPart: BasePart, studsPerSecond: number): number
	return (endPart.Position - startPart.Position).Magnitude / studsPerSecond
end

local function announce(item: Item)
	local tier = Tiers.byId[item.tier]
	local name = VariantMath.name(item.variant, Companies.byId[item.companyId].name)
	Remotes.Notify:FireAllClients(`A {tier.name} just hit the shared conveyor: {name}!`)
end

local function isAnnounced(item: Item): boolean
	local variant = if item.variant then Variants.byId[item.variant] else nil
	return ConveyorConfig.Shared.AnnounceTiers[item.tier] == true
		or (variant ~= nil and variant.oneIn >= Variants.AnnounceOneIn)
end

-- On the shared conveyor: tierId picks the tier, and variantId "regular"
-- means never a variant; with nil each is rolled as usual.
local function spawnShared(lane: Lane, tierId: string?, variantId: string?): Item?
	local tier = tierId or SpawnRoll.pickTier(ConveyorConfig.Shared.Weights, random:NextNumber())
	local choices = Companies.byTier[tier]
	if choices == nil or #choices == 0 then
		return nil
	end
	local company = choices[SpawnRoll.pickIndex(#choices, random:NextNumber())]
	local variant = if variantId == "regular"
		then nil
		elseif variantId then variantId
		else VariantMath.roll(random:NextNumber(), 1)
	local item = ConveyorService:AddItem({
		companyId = company.id,
		variant = variant,
		ownerUserId = 0,
		base = nil,
		from = surface(lane.startPart),
		to = surface(lane.endPart),
		travelSeconds = lane.travelSeconds,
		expiresAt = workspace:GetServerTimeNow() + lane.travelSeconds,
	})
	if item and isAnnounced(item) then
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
		travelSeconds = travelSecondsFor(startPart, endPart, ConveyorConfig.Shared.StudsPerSecond),
		nextSpawnAt = nil,
	}
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

-- Puts a company on a belt, coming out at from and stopping at to after
-- travelSeconds, facing the way it goes. Returns nil if its model is
-- missing.
function ConveyorService:AddItem(new: NewItem): Item?
	local company = Companies.byId[new.companyId]
	local model = if company then CompanyModels.clone(company.id, true, new.variant) else nil
	if company == nil or model == nil then
		return nil
	end

	local lift = Vector3.new(0, CompanyModels.pivotHeight(model), 0)
	local facing = CFrame.lookAt(new.from, new.to).Rotation
	local startCFrame = CFrame.new(new.from + lift) * facing
	local endCFrame = CFrame.new(new.to + lift) * facing
	local item: Item = {
		id = HttpService:GenerateGUID(false),
		companyId = company.id,
		tier = company.tier,
		variant = new.variant,
		price = CompanyStats.price(company.id),
		income = CompanyStats.income(company.id),
		ownerUserId = new.ownerUserId,
		spawnedAt = workspace:GetServerTimeNow(),
		travelSeconds = new.travelSeconds,
		startCFrame = startCFrame,
		endCFrame = endCFrame,
		model = model,
		base = new.base,
		expiresAt = new.expiresAt,
	}

	model.Name = item.id
	model:SetAttribute("ItemId", item.id)
	model:SetAttribute("CompanyId", item.companyId)
	model:SetAttribute("Tier", item.tier)
	model:SetAttribute("Variant", item.variant)
	model:SetAttribute("Price", item.price)
	model:SetAttribute("Income", item.income * VariantMath.multiplier(item.variant))
	model:SetAttribute("OwnerUserId", item.ownerUserId)
	model:SetAttribute("SpawnedAt", item.spawnedAt)
	model:SetAttribute("TravelSeconds", item.travelSeconds)
	model:SetAttribute("StartCFrame", startCFrame)
	model:SetAttribute("EndCFrame", endCFrame)
	model:PivotTo(startCFrame)
	model.Parent = itemsFolder

	items[item.id] = item
	return item
end

-- The point on a belt's surface that a Start or End part marks.
function ConveyorService:Surface(part: BasePart): Vector3
	return surface(part)
end

-- Problems found with the hand-built shared conveyor, for the debug panel.
function ConveyorService:GetProblems(): { string }
	return problems
end

-- Spawns a company of the given tier on the shared conveyor straight away,
-- for admin testing. variantId picks its variant ("regular" for none);
-- without it, it's rolled as usual.
function ConveyorService:SpawnShared(tierId: string, variantId: string?): Item?
	return if sharedLane then spawnShared(sharedLane, tierId, variantId) else nil
end

function ConveyorService:Init()
	itemsFolder = Instance.new("Folder")
	itemsFolder.Name = "ConveyorItems"
	itemsFolder.Parent = workspace

	findSharedLane()
	for _, problem in problems do
		warn(`[ConveyorService] {problem}. Build it in Studio (see "Map naming" in docs/design.md).`)
	end
	CompanyModels.prepare()
end

function ConveyorService:Start()
	-- Whatever was on a base's belt goes when its owner leaves.
	BaseService:OnBaseFreed(function(_player, base)
		for itemId, item in items do
			if item.base == base then
				ConveyorService:RemoveItem(itemId)
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()

		local lane = sharedLane
		if lane and #Players:GetPlayers() > 0 then
			local due = lane.nextSpawnAt
			if due == nil or now >= due then
				lane.nextSpawnAt = now + ConveyorConfig.Shared.SpawnSeconds
				spawnShared(lane, nil, nil)
			end
		end

		for itemId, item in items do
			local expiresAt = item.expiresAt
			if expiresAt and now >= expiresAt then
				ConveyorService:RemoveItem(itemId)
			end
		end
	end)
end

return ConveyorService
