--!strict
-- The company a player is carrying: one at a time, held above their head, and
-- slowing them to Config/Carry.WalkSpeedMultiplier. What they carry is saved
-- (Data.Carrying), and the held model and walk speed are always brought in
-- line with the save, so the two can't drift apart.
--
-- If the carrier resets or dies, the company goes back to their storage. If
-- they leave, it stays saved as Carrying and moves to storage when they next
-- join. On their own base, players can also store what they carry or take a
-- company out of storage.
--
-- A thief can instead be carrying a company they are stealing. That is held
-- here in memory only and never saved: the company stays in its owner's save
-- until the thief places it (StealService). If the thief resets, dies or
-- leaves, it simply goes back to its owner's plot.
--
-- The storage list is shared with the client as JSON in the player's
-- StorageList attribute; CarryingCompanyId says what they hold, and
-- CarryingStolen whether it is being stolen.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local CarryConfig = require(ReplicatedStorage.Shared.Config.Carry)
local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local CompanyModels = require(script.Parent.Parent.Lib.CompanyModels)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local HELD_MODEL_NAME = "CarriedCompany"
local MAX_INSTANCE_ID_LENGTH = 64

type Held = { model: Model, instanceId: string }

-- A company being stolen: still in its owner's save, on this plot.
export type Stolen = { company: Types.CompanyInstance, owner: Player, plotKey: string }

local held: { [Player]: Held } = {}
local stolen: { [Player]: Stolen } = {}
local stolenEndedCallbacks: { (thief: Player, entry: Stolen) -> () } = {}
local storeLimiter = RateLimiter.new(4, 6)
local takeLimiter = RateLimiter.new(4, 6)

local CarryService = {}

local function companyName(company: Types.CompanyInstance): string
	local config = Companies.byId[company.companyId]
	return if config then config.name else company.companyId
end

local function clearHeld(player: Player)
	local entry = held[player]
	if entry then
		held[player] = nil
		entry.model:Destroy()
	end
end

-- Shrinks the company to fit, stands it on top of the character's head and
-- welds it to the character so it moves with them.
local function attach(character: Model, root: BasePart, company: Types.CompanyInstance): Model?
	local model = CompanyModels.clone(company.companyId, false)
	if model == nil then
		return nil
	end

	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > CarryConfig.MaxSize then
		model:ScaleTo(model:GetScale() * CarryConfig.MaxSize / longest)
	end

	local characterBox, characterSize = character:GetBoundingBox()
	local headTop = characterBox.Position.Y + characterSize.Y / 2
	local point = Vector3.new(root.Position.X, headTop + CarryConfig.HeightAboveHead, root.Position.Z)
	CompanyModels.standOn(model, point, root.CFrame)

	-- Parent first so each weld records the offset in the world, then weld
	-- before the next physics step can move anything.
	model.Name = HELD_MODEL_NAME
	model.Parent = character
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	return model
end

local function publishStorage(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	local list = {}
	for _, company in data.Storage do
		table.insert(list, {
			instanceId = company.instanceId,
			companyId = company.companyId,
			tier = company.tier,
			income = company.baseIncome * company.valuationMultiplier,
		})
	end
	player:SetAttribute("StorageList", HttpService:JSONEncode(list))
end

-- Brings the held model, walk speed and attributes in line with the save (and
-- any company being stolen).
local function sync(player: Player)
	local data = DataService:GetData(player)
	local stolenEntry = stolen[player]
	local company = (data and data.Carrying) or (stolenEntry and stolenEntry.company)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	local entry: Held? = held[player]
	if entry and (company == nil or entry.instanceId ~= company.instanceId or entry.model.Parent ~= character) then
		clearHeld(player)
		entry = nil
	end
	if company and entry == nil and character and root and root:IsA("BasePart") then
		local model = attach(character, root, company)
		if model then
			held[player] = { model = model, instanceId = company.instanceId }
		end
	end

	if humanoid then
		local multiplier = if company then CarryConfig.WalkSpeedMultiplier else 1
		humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed * multiplier
	end
	player:SetAttribute("CarryingCompanyId", if company then company.companyId else nil)
	player:SetAttribute("CarryingValued", if company then company.hasBeenValued else nil)
	player:SetAttribute("CarryingStolen", if stolenEntry then true else nil)
	publishStorage(player)
end

-- Sends a company being stolen back to its owner's plot (it never left their
-- save) and tells anything listening, such as StealService.
local function returnStolen(thief: Player)
	local entry = stolen[thief]
	if entry == nil then
		return
	end
	stolen[thief] = nil
	if thief.Parent == Players then
		sync(thief)
		Remotes.Notify:FireClient(thief, `The {companyName(entry.company)} went back to its owner.`)
	end
	for _, callback in stolenEndedCallbacks do
		task.spawn(callback, thief, entry)
	end
end

local function returnToStorage(player: Player)
	returnStolen(player)
	local company = DataService:TakeCarrying(player)
	if company then
		DataService:AddToStorage(player, company, true)
		Remotes.Notify:FireClient(player, `Your {companyName(company)} went back to storage.`)
	end
	sync(player)
end

function CarryService:IsCarrying(player: Player): boolean
	local data = DataService:GetData(player)
	return stolen[player] ~= nil or (data ~= nil and data.Carrying ~= nil)
end

-- Puts a company in the player's hands. Fails if they already hold one.
function CarryService:Carry(player: Player, company: Types.CompanyInstance): boolean
	if stolen[player] or not DataService:SetCarrying(player, company) then
		return false
	end
	sync(player)
	return true
end

-- Empties the player's hands and returns what they held.
function CarryService:TakeCarried(player: Player): Types.CompanyInstance?
	local company = DataService:TakeCarrying(player)
	sync(player)
	return company
end

-- Puts a company the player is stealing in their hands. Nothing is saved.
function CarryService:CarryStolen(thief: Player, entry: Stolen): boolean
	if CarryService:IsCarrying(thief) then
		return false
	end
	stolen[thief] = entry
	sync(thief)
	return true
end

-- Empties a thief's hands of the company they are stealing and returns it.
function CarryService:TakeStolen(thief: Player): Stolen?
	local entry = stolen[thief]
	stolen[thief] = nil
	if thief.Parent == Players then
		sync(thief)
	end
	return entry
end

function CarryService:GetStolen(thief: Player): Stolen?
	return stolen[thief]
end

-- Whether someone is carrying off the company on this player's plot.
function CarryService:IsPlotBeingStolen(owner: Player, plotKey: string): boolean
	for _, entry in stolen do
		if entry.owner == owner and entry.plotKey == plotKey then
			return true
		end
	end
	return false
end

-- Every thief currently carrying off one of this player's companies.
function CarryService:GetThievesOf(owner: Player): { Player }
	local thieves = {}
	for thief, entry in stolen do
		if entry.owner == owner then
			table.insert(thieves, thief)
		end
	end
	return thieves
end

-- Runs callback(thief, entry) when a steal ends because the thief reset, died
-- or left, after the company has gone back to its owner's plot.
function CarryService:OnStolenReturned(callback: (thief: Player, entry: Stolen) -> ())
	table.insert(stolenEndedCallbacks, callback)
end

local function onBase(player: Player): boolean
	local base = BaseService:GetBase(player)
	return base ~= nil and BaseService:IsOnBase(player, base)
end

local function store(player: Player): string
	if stolen[player] then
		return "A stolen company has to go on a plot on your base."
	end
	if not CarryService:IsCarrying(player) then
		return "You're not carrying anything."
	end
	if not onBase(player) then
		return "Go back to your base to store it."
	end
	if not DataService:HasStorageSpace(player) then
		return "Your storage is full."
	end

	local company = CarryService:TakeCarried(player)
	if company == nil then
		return "You're not carrying anything."
	end
	if not DataService:AddToStorage(player, company) then
		CarryService:Carry(player, company)
		return "Your storage is full."
	end
	return `Stored {companyName(company)}.`
end

local function takeOut(player: Player, instanceId: string): string
	if CarryService:IsCarrying(player) then
		return "Your hands are full. Place or store what you're carrying first."
	end
	if not onBase(player) then
		return "Go back to your base to take companies out of storage."
	end

	local company = DataService:TakeFromStorage(player, instanceId)
	if company == nil then
		return "That company isn't in your storage."
	end
	if not CarryService:Carry(player, company) then
		DataService:AddToStorage(player, company, true)
		return "Your hands are full."
	end
	return `You're carrying {companyName(company)}. Take it to a plot.`
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			returnToStorage(player)
		end)
	end
	sync(player)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		returnToStorage(player)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function CarryService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		returnStolen(player)
		clearHeld(player)
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	DataService:OnDataLoaded(function(player)
		-- A save that loads holding a company was left mid-carry.
		if DataService:GetData(player) and CarryService:IsCarrying(player) then
			returnToStorage(player)
		else
			sync(player)
		end
	end)
	DataService:OnDataChanged(sync)

	Remotes.StoreCarried.OnServerEvent:Connect(function(player: Player)
		if storeLimiter:allow(player) then
			Remotes.Notify:FireClient(player, store(player))
		end
	end)

	Remotes.TakeFromStorage.OnServerEvent:Connect(function(player: Player, instanceId: unknown)
		if not takeLimiter:allow(player) then
			return
		end
		if typeof(instanceId) ~= "string" or #instanceId > MAX_INSTANCE_ID_LENGTH then
			return
		end
		Remotes.Notify:FireClient(player, takeOut(player, instanceId))
	end)
end

return CarryService
