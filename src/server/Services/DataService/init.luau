--!strict
-- Loads each player's save with ProfileStore when they join and ends the session
-- when they leave. ProfileStore autosaves, saves on leave and on shutdown, and
-- session-locks each save so two servers can never edit it at once. That lock
-- is what stops Cash being duplicated by hopping between servers.
--
-- Other services read and change player data only through this module.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

local BaseConfig = require(ReplicatedStorage.Shared.Config.Base)
local PetsConfig = require(ReplicatedStorage.Shared.Config.Pets)
local Types = require(ReplicatedStorage.Shared.Types)

local Migrations = require(script.Migrations)
local Template = require(script.Template)

export type Data = Template.Data

local STORE_NAME = "PlayerData"
local CURRENT_VERSION = Template.DataVersion

local LOAD_FAILED_MESSAGE = "Your data couldn't be loaded. Please rejoin."
local OUTDATED_SERVER_MESSAGE = "This server is running an older version of the game. Please rejoin."
local SESSION_ENDED_MESSAGE = "Your save was opened somewhere else. Please rejoin."

local store = ProfileStore.New(STORE_NAME, Template)

-- ProfileStore's profile type. A typeof in a type annotation is never run.
type Profile = typeof(assert(store:StartSessionAsync("", {})))

local profiles: { [Player]: Profile } = {}
local cashValues: { [Player]: IntValue } = {}
local loading: { [Player]: true } = {}
local loadedCallbacks: { (Player) -> () } = {}
local changedCallbacks: { (Player) -> () } = {}
local cashCallbacks: { (Player) -> () } = {}

local DataService = {}

local function isValidCash(amount: number): boolean
	return amount == amount and amount >= 0 and amount < math.huge
end

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

-- Replaces the contents of a save in place, so ProfileStore keeps saving the
-- same table.
local function replaceData(profile: Profile, newData: { [string]: any })
	local data = profile.Data :: any
	table.clear(data)
	for key, value in newData do
		data[key] = value
	end
end

-- Brings an old save up to CURRENT_VERSION. The steps run on a copy, so if one
-- fails the save is left exactly as it was. Returns a kick message on failure.
local function migrate(profile: Profile): string?
	local data = profile.Data :: any
	local version = if typeof(data.DataVersion) == "number" then data.DataVersion else 1

	if version > CURRENT_VERSION then
		return OUTDATED_SERVER_MESSAGE
	end
	if version == CURRENT_VERSION then
		return nil
	end

	local upgraded = deepCopy(data)
	while version < CURRENT_VERSION do
		local step = Migrations[version]
		local ok, err = pcall(function()
			assert(step, "missing migration step")
			step(upgraded)
		end)
		if not ok then
			warn(`[DataService] Migrating {profile.Key} from data version {version} failed: {err}`)
			return LOAD_FAILED_MESSAGE
		end
		version += 1
		upgraded.DataVersion = version
	end

	replaceData(profile, upgraded)
	return nil
end

-- Cash in the player list. Cash can be fractional, so the list shows it rounded down.
local function createLeaderstats(player: Player, cash: number)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = math.floor(cash)
	cashValue.Parent = leaderstats

	cashValues[player] = cashValue
	leaderstats.Parent = player
end

-- Call after a change to Cash only. Kept separate because income changes Cash
-- every second and most listeners only care about the rest of the save.
local function cashChanged(player: Player)
	local profile = profiles[player]
	local cashValue = cashValues[player]
	if profile and cashValue then
		cashValue.Value = math.floor(profile.Data.Cash)
	end
	for _, callback in cashCallbacks do
		task.spawn(callback, player)
	end
end

-- Call after any other change to a player's data.
local function dataChanged(player: Player)
	for _, callback in changedCallbacks do
		task.spawn(callback, player)
	end
end

local function onPlayerAdded(player: Player)
	if loading[player] or profiles[player] then
		return
	end
	loading[player] = true

	local profile = store:StartSessionAsync(
		`Player_{player.UserId}`,
		{
			-- Stop waiting if the player leaves while their save is loading.
			Cancel = function()
				return player.Parent ~= Players
			end,
		} :: any
	)
	loading[player] = nil

	if profile == nil then
		player:Kick(LOAD_FAILED_MESSAGE)
		return
	end

	profile:AddUserId(player.UserId)

	local problem = migrate(profile)
	if problem then
		profile:EndSession()
		player:Kick(problem)
		return
	end
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		cashValues[player] = nil
		player:Kick(SESSION_ENDED_MESSAGE)
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	createLeaderstats(player, profile.Data.Cash)

	for _, callback in loadedCallbacks do
		task.spawn(callback, player)
	end
end

local function onPlayerRemoving(player: Player)
	loading[player] = nil
	local profile = profiles[player]
	if profile then
		profile:EndSession()
	end
end

-- The player's save, or nil if it hasn't loaded yet. Treat it as read-only and
-- make changes through the functions below, so the player list and anything
-- listening with OnDataChanged or OnCashChanged stay in sync.
function DataService:GetData(player: Player): Data?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- When the player first ever joined (os.time()), from ProfileStore.
function DataService:GetFirstSessionTime(player: Player): number?
	local profile = profiles[player]
	return if profile then profile.FirstSessionTime else nil
end

-- Saves the player's data now rather than at the next autosave, for changes
-- that must not be lost, such as a company changing hands in a steal.
function DataService:SaveNow(player: Player)
	local profile = profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

-- False in Studio when "Enable Studio Access to API Services" is off. Saves
-- then go to a temporary store and are lost when the test ends.
function DataService:IsSaving(): boolean
	return ProfileStore.DataStoreState == "Access"
end

-- Runs callback(player) for every player whose save has loaded, including
-- players who loaded before this was called.
function DataService:OnDataLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
	for player in profiles do
		task.spawn(callback, player)
	end
end

-- Runs callback(player) after any change made through this module, other
-- than a change to Cash alone (see OnCashChanged).
function DataService:OnDataChanged(callback: (Player) -> ())
	table.insert(changedCallbacks, callback)
end

-- Runs callback(player) after the player's Cash changes.
function DataService:OnCashChanged(callback: (Player) -> ())
	table.insert(cashCallbacks, callback)
end

function DataService:AddCash(player: Player, amount: number): boolean
	local profile = profiles[player]
	if profile == nil or not isValidCash(amount) then
		return false
	end
	local cash = profile.Data.Cash + amount
	if not isValidCash(cash) then
		return false
	end
	profile.Data.Cash = cash
	cashChanged(player)
	return true
end

-- Takes Cash only if the player has enough. Returns whether it was taken.
function DataService:SpendCash(player: Player, amount: number): boolean
	local profile = profiles[player]
	if profile == nil or not isValidCash(amount) or profile.Data.Cash < amount then
		return false
	end
	profile.Data.Cash -= amount
	cashChanged(player)
	return true
end

function DataService:SetCash(player: Player, amount: number): boolean
	local profile = profiles[player]
	if profile == nil or not isValidCash(amount) then
		return false
	end
	profile.Data.Cash = amount
	cashChanged(player)
	return true
end

-- Companies move between Carrying, Storage and Placed only through the
-- functions below. Each one either makes its whole change or none of it.

function DataService:HasStorageSpace(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and #profile.Data.Storage < BaseConfig.StorageCapacity
end

-- Adds a company to storage if there is room. With force, adds it even when
-- storage is full, for companies returned automatically so they are never lost.
function DataService:AddToStorage(player: Player, company: Types.CompanyInstance, force: boolean?): boolean
	local profile = profiles[player]
	if profile == nil or (not force and #profile.Data.Storage >= BaseConfig.StorageCapacity) then
		return false
	end
	table.insert(profile.Data.Storage, company)
	dataChanged(player)
	return true
end

function DataService:TakeFromStorage(player: Player, instanceId: string): Types.CompanyInstance?
	local profile = profiles[player]
	if profile == nil then
		return nil
	end
	for index, company in profile.Data.Storage do
		if company.instanceId == instanceId then
			table.remove(profile.Data.Storage, index)
			dataChanged(player)
			return company
		end
	end
	return nil
end

-- Puts a company in the player's hands. Fails if they already hold one.
function DataService:SetCarrying(player: Player, company: Types.CompanyInstance): boolean
	local profile = profiles[player]
	if profile == nil or profile.Data.Carrying ~= nil then
		return false
	end
	profile.Data.Carrying = company
	dataChanged(player)
	return true
end

-- Empties the player's hands and returns what they held.
function DataService:TakeCarrying(player: Player): Types.CompanyInstance?
	local profile = profiles[player]
	local company = profile and profile.Data.Carrying
	if profile == nil or company == nil then
		return nil
	end
	profile.Data.Carrying = nil
	dataChanged(player)
	return company
end

-- Puts a company on a plot. Fails if the plot already has one.
function DataService:PlaceOnPlot(player: Player, plotKey: string, company: Types.CompanyInstance): boolean
	local profile = profiles[player]
	if profile == nil or profile.Data.Placed[plotKey] ~= nil then
		return false
	end
	profile.Data.Placed[plotKey] = company
	dataChanged(player)
	return true
end

function DataService:TakeFromPlot(player: Player, plotKey: string): Types.CompanyInstance?
	local profile = profiles[player]
	local company = profile and profile.Data.Placed[plotKey]
	if profile == nil or company == nil then
		return nil
	end
	profile.Data.Placed[plotKey] = nil
	dataChanged(player)
	return company
end

-- Puts a company into the Valuation Machine. Fails if a run is already going.
function DataService:StartMachineRun(player: Player, run: Types.MachineRun): boolean
	local profile = profiles[player]
	if profile == nil or profile.Data.Machine ~= nil then
		return false
	end
	profile.Data.Machine = run
	dataChanged(player)
	return true
end

-- Ends the player's Valuation Machine run and returns it.
function DataService:TakeMachineRun(player: Player): Types.MachineRun?
	local profile = profiles[player]
	local run = profile and profile.Data.Machine
	if profile == nil or run == nil then
		return nil
	end
	profile.Data.Machine = nil
	dataChanged(player)
	return run
end

-- Sets the plots open on each floor. UpgradeService decides what is allowed.
function DataService:SetUnlockedPlots(player: Player, unlockedPlots: { number }): boolean
	local profile = profiles[player]
	if profile == nil then
		return false
	end
	profile.Data.UnlockedPlots = unlockedPlots
	dataChanged(player)
	return true
end

function DataService:OwnsWeapon(player: Player, weaponId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and table.find(profile.Data.OwnedWeapons, weaponId) ~= nil
end

-- Adds a weapon the player has bought. Fails if they already own it.
function DataService:AddWeapon(player: Player, weaponId: string): boolean
	local profile = profiles[player]
	if profile == nil or table.find(profile.Data.OwnedWeapons, weaponId) then
		return false
	end
	table.insert(profile.Data.OwnedWeapons, weaponId)
	dataChanged(player)
	return true
end

-- Puts a weapon the player owns in their hands.
function DataService:SetEquippedWeapon(player: Player, weaponId: string): boolean
	local profile = profiles[player]
	if profile == nil or table.find(profile.Data.OwnedWeapons, weaponId) == nil then
		return false
	end
	profile.Data.EquippedWeapon = weaponId
	dataChanged(player)
	return true
end

-- Adds a pet. Fails if the player already has Config/Pets.InventoryCap.
function DataService:AddPet(player: Player, pet: Types.PetInstance): boolean
	local profile = profiles[player]
	if profile == nil or #profile.Data.Pets >= PetsConfig.InventoryCap then
		return false
	end
	table.insert(profile.Data.Pets, pet)
	dataChanged(player)
	return true
end

function DataService:RemovePet(player: Player, instanceId: string): Types.PetInstance?
	local profile = profiles[player]
	if profile == nil then
		return nil
	end
	for index, pet in profile.Data.Pets do
		if pet.instanceId == instanceId then
			table.remove(profile.Data.Pets, index)
			dataChanged(player)
			return pet
		end
	end
	return nil
end

-- Puts a pet in a slot, or back in the inventory with nil. Fails if the pet
-- isn't the player's or another pet is already in that slot. PetService
-- decides which slots are allowed.
function DataService:SetPetSlot(player: Player, instanceId: string, slotKey: string?): boolean
	local profile = profiles[player]
	if profile == nil then
		return false
	end
	local found: Types.PetInstance? = nil
	for _, pet in profile.Data.Pets do
		if pet.instanceId == instanceId then
			found = pet
		elseif slotKey and pet.slotKey == slotKey then
			return false
		end
	end
	if found == nil then
		return false
	end
	found.slotKey = slotKey
	dataChanged(player)
	return true
end

-- Wipes the player's save back to a brand new player's.
function DataService:ResetData(player: Player): boolean
	local profile = profiles[player]
	if profile == nil then
		return false
	end
	replaceData(profile, deepCopy(Template))
	cashChanged(player)
	dataChanged(player)
	return true
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
