--!strict
-- Companies knocked out of someone's hands (docs/design.md, "Combat").
--
-- A hit on a player carrying a company drops it where they stand. It lies on
-- the ground for Config/Combat.DropReturnSeconds and anyone can pick it up: its
-- owner gets it back, and anyone else carries it off as a steal, which
-- StealService completes when they place it on their own base. If nobody picks
-- it up, it goes back where it belongs: the owner's plot it was being stolen
-- from, or the owner's storage for a company they were carrying themselves.
--
-- While on the ground the company never leaves its owner's save; CarryService
-- holds it in memory only. A company bought and then dropped is put in the
-- buyer's storage straight away, so it is safe whatever happens.
--
-- Ground models go in Workspace.DroppedCompanies (made at runtime), with
-- InstanceId, CompanyId, Tier, OwnerUserId and ReturnsAt (server time)
-- attributes for the client's prompt and countdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local AnalyticsService = require(script.Parent.AnalyticsService)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)
local CompanyModels = require(script.Parent.Parent.Lib.CompanyModels)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local FOLDER_NAME = "DroppedCompanies"
local MAX_INSTANCE_ID_LENGTH = 64
-- How far below a character to look for the ground to drop onto.
local GROUND_SEARCH = 60

type Drop = { entry: CarryService.Stolen, model: Model }

local drops: { [string]: Drop } = {}
local folder: Folder
local pickUpLimiter = RateLimiter.new(4, 6)

local DropService = {}

local function notify(player: Player, message: string)
	if player.Parent == Players then
		Remotes.Notify:FireClient(player, message)
	end
end

local function companyName(company: Types.CompanyInstance): string
	local config = Companies.byId[company.companyId]
	return if config then config.name else company.companyId
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- The owner's plots and income count a company again once it's back.
local function refreshOwner(owner: Player)
	if owner.Parent == Players then
		PlotService:Refresh(owner)
		IncomeService:Refresh(owner)
	end
end

local function where(entry: CarryService.Stolen): string
	return if entry.plotKey then "on its plot" else "in your storage"
end

-- Takes a company off the ground. Returns what was there, if anything.
local function remove(instanceId: string): CarryService.Stolen?
	local drop = drops[instanceId]
	if drop == nil then
		return nil
	end
	drops[instanceId] = nil
	drop.model:Destroy()
	CarryService:TakeLoose(instanceId)
	return drop.entry
end

local function backHome(entry: CarryService.Stolen)
	refreshOwner(entry.owner)
	notify(entry.owner, `Your {companyName(entry.company)} is back {where(entry)}.`)
end

-- Nobody picked it up, so it goes back where it belongs.
local function sendHome(instanceId: string)
	local entry = remove(instanceId)
	if entry then
		backHome(entry)
	end
end

local function groundBelow(character: Model, position: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, folder }
	params.RespectCanCollide = true
	local result = workspace:Raycast(position, Vector3.new(0, -GROUND_SEARCH, 0), params)
	return if result then result.Position else nil
end

-- Knocks whatever the player is carrying out of their hands onto the ground
-- at their feet. Returns whether they were carrying anything.
function DropService:Drop(player: Player): boolean
	local character = player.Character
	local root = rootOf(player)
	local entry = CarryService:DropCarried(player)
	if entry == nil then
		return false
	end
	local company = entry.company
	local instanceId = company.instanceId

	local ground = if character and root then groundBelow(character, root.Position) else nil
	local model = if ground then CompanyModels.clone(company.companyId, true, company.variant) else nil
	if root == nil or ground == nil or model == nil then
		-- Nowhere to put it (off the edge of the map, or no model): it goes
		-- straight back.
		CarryService:TakeLoose(instanceId)
		backHome(entry)
		return true
	end

	local returnsAt = workspace:GetServerTimeNow() + CombatConfig.DropReturnSeconds
	CompanyModels.standOn(model, ground, root.CFrame)
	model.Name = instanceId
	model:SetAttribute("InstanceId", instanceId)
	model:SetAttribute("CompanyId", company.companyId)
	model:SetAttribute("Tier", company.tier)
	model:SetAttribute("OwnerUserId", entry.owner.UserId)
	model:SetAttribute("ReturnsAt", returnsAt)
	model.Parent = folder

	local drop: Drop = { entry = entry, model = model }
	drops[instanceId] = drop
	task.delay(CombatConfig.DropReturnSeconds, function()
		if drops[instanceId] == drop then
			sendHome(instanceId)
		end
	end)

	local name = companyName(company)
	notify(player, `You dropped the {name}! Grab it before it goes back.`)
	if entry.owner ~= player then
		notify(entry.owner, `{player.Name} dropped your {name}. It goes back {where(entry)} soon.`)
	end
	return true
end

-- Returns the message for the player.
local function pickUp(player: Player, instanceId: string): string
	local drop = drops[instanceId]
	if drop == nil then
		return "Too slow! Someone else got it."
	end
	local entry = drop.entry
	local name = companyName(entry.company)
	local owner = entry.owner
	if CarryService:IsCarrying(player) then
		return "Your hands are full."
	end
	local root = rootOf(player)
	local reach = CombatConfig.PickUpDistance + CombatConfig.PickUpDistanceTolerance
	if root == nil or not isAlive(player) or (root.Position - drop.model:GetPivot().Position).Magnitude > reach then
		return "Get closer to pick it up."
	end

	if owner == player then
		remove(instanceId)
		if entry.plotKey then
			refreshOwner(owner)
			return `Your {name} is back on its plot.`
		end
		-- Their own company: it was put in storage when it was dropped, so
		-- it goes back into their hands from there.
		local company = DataService:TakeFromStorage(player, instanceId)
		if company and CarryService:Carry(player, company) then
			return `Picked up your {name}.`
		end
		if company then
			DataService:AddToStorage(player, company, true)
		end
		return `Your {name} is back in your storage.`
	end

	if BaseService:GetBase(player) == nil then
		return "You need a base to take it to."
	end
	local blocked = StealService:GetBlockReason(player, owner)
	if blocked then
		return blocked
	end

	remove(instanceId)
	if not CarryService:CarryStolen(player, entry) then
		refreshOwner(owner)
		return "Your hands are full."
	end
	AnalyticsService:Event(player, "StealStarted", 1, { "Ground", entry.company.tier })
	notify(owner, `{player.Name} grabbed your {name}! Touch them to get it back.`)
	return `Got {name}! Get it to a free plot on your base.`
end

function DropService:Init()
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
end

function DropService:Start()
	-- An owner leaving takes their companies off the ground; they never left
	-- the owner's save.
	Players.PlayerRemoving:Connect(function(player)
		for _, entry in CarryService:GetLooseFrom(player) do
			remove(entry.company.instanceId)
		end
	end)

	Remotes.PickUpDropped.OnServerEvent:Connect(function(player: Player, instanceId: unknown)
		if not pickUpLimiter:allow(player) then
			return
		end
		if typeof(instanceId) ~= "string" or #instanceId > MAX_INSTANCE_ID_LENGTH then
			return
		end
		notify(player, pickUp(player, instanceId))
	end)
end

return DropService
