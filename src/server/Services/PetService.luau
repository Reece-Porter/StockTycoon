--!strict
-- Pets and pet slots (docs/design.md, "Pet shop"). Pets come from spins at
-- the pet shop (PetShopService). A player puts one in a pet slot on an opened
-- floor of their base, where it changes that floor only (PetMath), takes it
-- back to their inventory, or deletes one they don't want. Every request is
-- checked here: the slot is theirs, open and free, the pet is theirs and not
-- placed, and they are standing close by. Pets can't be stolen.
--
-- Each floor has Config/Pets.SlotsPerFloor slots open, and the Extra Pet Slot
-- game pass opens Config/Monetisation.ExtraPetSlots more; others are greyed
-- out. Slots the pass would open get a NeedsPass attribute. If a player turns
-- out not to have the pass (say it was refunded), a pet in one of its slots
-- goes back to their pets.
--
-- Players get a PetList attribute (JSON: instanceId, petId, slotKey) for the
-- pets window. Slot parts get SlotKey, Unlocked, PetId and PetInstanceId
-- attributes, and the pet's model stands on the slot in Workspace.PlacedPets.
-- Pet models are built when the server starts (Lib/PetModels, from
-- Config/PetLooks) into ReplicatedStorage.Assets.Pets, unless one was made by
-- hand there; a pet without either uses "Default", with its RarityTint parts
-- coloured by rarity.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetMath = require(ReplicatedStorage.Shared.PetMath)
local Monetisation = require(ReplicatedStorage.Shared.Config.Monetisation)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local CompanyModels = require(script.Parent.Parent.Lib.CompanyModels)
local LockedLook = require(script.Parent.Parent.Lib.LockedLook)
local Passes = require(script.Parent.Parent.Lib.Passes)
local PetModels = require(script.Parent.Parent.Lib.PetModels)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local MAX_KEY_LENGTH = 64
-- Parts of the Default model with this attribute take the pet's rarity colour.
local TINT_ATTRIBUTE = "RarityTint"

local placedFolder: Folder
local displays: { [BasePart]: Model } = {}
local problems: { string } = {}
local placeLimiter = RateLimiter.new(4, 6)
local takeBackLimiter = RateLimiter.new(4, 6)
local deleteLimiter = RateLimiter.new(4, 6)

local PetService = {}

local function petName(instance: Types.PetInstance): string
	local pet = Pets.byId[instance.petId]
	return if pet then pet.name else instance.petId
end

local function petsFolder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Pets")
end

-- A copy that can't be walked into or touched, anchored for display.
local function clonePet(pet: Pets.Pet): Model?
	local folder = petsFolder()
	local own = folder and folder:FindFirstChild(pet.id)
	local template = if own and own:IsA("Model") then own else folder and folder:FindFirstChild("Default")
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local colour = Pets.rarityById[pet.rarity].color
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			if own == nil and descendant:GetAttribute(TINT_ATTRIBUTE) == true then
				descendant.Color = colour
			end
		end
	end
	return model
end

local function slotsOpen(player: Player): number
	return Pets.SlotsPerFloor + (if Passes.owns(player, "ExtraPetSlot") then Monetisation.ExtraPetSlots else 0)
end

local function isOpen(player: Player, slot: BaseService.PetSlot, data: DataService.Data): boolean
	return data.UnlockedPlots[slot.floor] ~= nil and slot.index <= slotsOpen(player)
end

-- A slot on an opened floor that only the Extra Pet Slot pass opens.
local function isPassSlot(slot: BaseService.PetSlot, data: DataService.Data): boolean
	return data.UnlockedPlots[slot.floor] ~= nil
		and slot.index > Pets.SlotsPerFloor
		and slot.index <= Pets.SlotsPerFloor + Monetisation.ExtraPetSlots
end

local function petInSlot(data: DataService.Data, slotKey: string): Types.PetInstance?
	for _, pet in data.Pets do
		if pet.slotKey == slotKey then
			return pet
		end
	end
	return nil
end

local function findPet(data: DataService.Data, instanceId: string): Types.PetInstance?
	for _, pet in data.Pets do
		if pet.instanceId == instanceId then
			return pet
		end
	end
	return nil
end

local function clearSlot(slot: BaseService.PetSlot)
	local display = displays[slot.part]
	if display then
		displays[slot.part] = nil
		display:Destroy()
	end
	slot.part:SetAttribute("PetId", nil)
	slot.part:SetAttribute("PetInstanceId", nil)
end

local function showInSlot(base: BaseService.Base, slot: BaseService.PetSlot, instance: Types.PetInstance)
	local current = displays[slot.part]
	if current and current:GetAttribute("PetInstanceId") == instance.instanceId then
		return
	end
	clearSlot(slot)
	slot.part:SetAttribute("PetId", instance.petId)
	slot.part:SetAttribute("PetInstanceId", instance.instanceId)

	local pet = Pets.byId[instance.petId]
	local model = if pet then clonePet(pet) else nil
	if model == nil then
		return
	end
	local part = slot.part
	CompanyModels.standOn(model, part.Position + Vector3.new(0, part.Size.Y / 2, 0), part.CFrame)
	model.Name = `{base.name}/{slot.key}`
	model:SetAttribute("PetInstanceId", instance.instanceId)
	model.Parent = placedFolder
	displays[part] = model
end

local function publish(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	local list = {}
	for _, pet in data.Pets do
		table.insert(list, { instanceId = pet.instanceId, petId = pet.petId, slotKey = pet.slotKey })
	end
	player:SetAttribute("PetList", HttpService:JSONEncode(list))
end

-- Brings a player's pet slots in line with their save.
local function sync(player: Player)
	publish(player)
	local base = BaseService:GetBase(player)
	local data = DataService:GetData(player)
	if base == nil or data == nil then
		return
	end
	for _, slot in base.petSlots do
		local open = isOpen(player, slot, data)
		LockedLook.set(slot.part, not open)
		slot.part:SetAttribute("SlotKey", slot.key)
		slot.part:SetAttribute("Unlocked", open)
		slot.part:SetAttribute("NeedsPass", if not open and isPassSlot(slot, data) then true else nil)
		local pet = petInSlot(data, slot.key)
		if pet and not open and isPassSlot(slot, data) and Passes.isChecked(player) then
			-- Saving this runs sync again, which clears the slot.
			DataService:SetPetSlot(player, pet.instanceId, nil)
			Remotes.Notify:FireClient(
				player,
				`Your {petName(pet)} is back in your pets: that slot needs the Extra Pet Slot pass.`
			)
		elseif pet then
			showInSlot(base, slot, pet)
		else
			clearSlot(slot)
		end
	end
end

local function resetBase(base: BaseService.Base)
	for _, slot in base.petSlots do
		clearSlot(slot)
		LockedLook.set(slot.part, false)
		slot.part:SetAttribute("Unlocked", nil)
		slot.part:SetAttribute("NeedsPass", nil)
	end
end

local function isNear(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local reach = Pets.SlotDistance + Pets.SlotDistanceTolerance
	return root ~= nil and root:IsA("BasePart") and (root.Position - part.Position).Magnitude <= reach
end

local function ownSlot(player: Player, slotKey: string): BaseService.PetSlot?
	local base = BaseService:GetBase(player)
	return base and base.petSlotsByKey[slotKey]
end

-- Returns the message for the player.
local function place(player: Player, instanceId: string, slotKey: string): string
	local slot = ownSlot(player, slotKey)
	local data = DataService:GetData(player)
	if slot == nil or data == nil then
		return "That pet slot isn't on your base."
	end
	if not isOpen(player, slot, data) then
		return if isPassSlot(slot, data)
			then "That pet slot needs the Extra Pet Slot pass (Store)."
			else "That pet slot is locked."
	end
	if petInSlot(data, slot.key) then
		return "That slot already has a pet."
	end
	local pet = findPet(data, instanceId)
	if pet == nil then
		return "That isn't one of your pets."
	end
	if pet.slotKey ~= nil then
		return `Your {petName(pet)} is already out. Take it back first.`
	end
	if not isNear(player, slot.part) then
		return "Get closer to the pet slot."
	end
	if not DataService:SetPetSlot(player, pet.instanceId, slot.key) then
		return "That slot already has a pet."
	end
	return `Your {petName(pet)} is looking after Floor {slot.floor}.`
end

local function takeBack(player: Player, slotKey: string): string
	local slot = ownSlot(player, slotKey)
	local data = DataService:GetData(player)
	if slot == nil or data == nil then
		return "That pet slot isn't on your base."
	end
	local pet = petInSlot(data, slot.key)
	if pet == nil then
		return "There's no pet in that slot."
	end
	if not isNear(player, slot.part) then
		return "Get closer to the pet slot."
	end
	DataService:SetPetSlot(player, pet.instanceId, nil)
	return `Your {petName(pet)} is back in your pets.`
end

local function delete(player: Player, instanceId: string): string
	local data = DataService:GetData(player)
	local pet = if data then findPet(data, instanceId) else nil
	if pet == nil then
		return "That isn't one of your pets."
	end
	if pet.slotKey ~= nil then
		return `Take your {petName(pet)} out of its slot first.`
	end
	DataService:RemovePet(player, pet.instanceId)
	return `Let your {petName(pet)} go.`
end

-- Problems found with the hand-built pet models, for the debug panel.
-- Brings the player's pet slots in line again, e.g. when they get or lose
-- the Extra Pet Slot pass.
function PetService:Refresh(player: Player)
	sync(player)
end

function PetService:GetProblems(): { string }
	return problems
end

-- What the player's placed pets add to each floor, for the debug panel.
function PetService:DescribeFloors(player: Player): string
	local data = DataService:GetData(player)
	if data == nil then
		return "not loaded"
	end
	local lines = {}
	for floor = 1, #data.UnlockedPlots do
		local bonus = PetMath.floorBonuses(data.Pets)[floor]
		local income = if bonus then math.floor(bonus.income * 100 + 0.5) else 0
		local guard = if bonus then bonus.guard else 0
		table.insert(lines, `Floor {floor}: +{income}% income, +{guard}s to steal`)
	end
	return table.concat(lines, "\n")
end

function PetService:Init()
	PetModels.prepare()
	placedFolder = Instance.new("Folder")
	placedFolder.Name = "PlacedPets"
	placedFolder.Parent = workspace

	local folder = petsFolder()
	local default = folder and folder:FindFirstChild("Default")
	if default == nil or not default:IsA("Model") then
		table.insert(problems, "ReplicatedStorage.Assets.Pets.Default is missing, so pets without a model can't appear")
	end
	for _, problem in problems do
		warn(`[PetService] {problem}. Build it in Studio (see "Map naming" in docs/design.md).`)
	end
end

local function validKey(value: unknown): boolean
	return typeof(value) == "string" and #value <= MAX_KEY_LENGTH
end

function PetService:Start()
	DataService:OnDataLoaded(sync)
	DataService:OnDataChanged(sync)
	BaseService:OnBaseAssigned(function(player)
		sync(player)
	end)
	BaseService:OnBaseFreed(function(_player, base)
		resetBase(base)
	end)

	local function reply(player: Player, message: string)
		if player.Parent == Players then
			Remotes.Notify:FireClient(player, message)
		end
	end

	Remotes.PlacePet.OnServerEvent:Connect(function(player: Player, instanceId: unknown, slotKey: unknown)
		if placeLimiter:allow(player) and validKey(instanceId) and validKey(slotKey) then
			reply(player, place(player, instanceId :: string, slotKey :: string))
		end
	end)
	Remotes.TakeBackPet.OnServerEvent:Connect(function(player: Player, slotKey: unknown)
		if takeBackLimiter:allow(player) and validKey(slotKey) then
			reply(player, takeBack(player, slotKey :: string))
		end
	end)
	Remotes.DeletePet.OnServerEvent:Connect(function(player: Player, instanceId: unknown)
		if deleteLimiter:allow(player) and validKey(instanceId) then
			reply(player, delete(player, instanceId :: string))
		end
	end)
end

return PetService
