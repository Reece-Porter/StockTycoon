--!strict
-- Loads each player's save with ProfileStore when they join and ends the session
-- when they leave. ProfileStore autosaves, saves on leave and on shutdown, and
-- session-locks each save so two servers can never edit it at once. That lock
-- is what stops Cash being duplicated by hopping between servers.
--
-- Other services read and change player data only through this module.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

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

local function onCashChanged(player: Player, cash: number)
	local cashValue = cashValues[player]
	if cashValue then
		cashValue.Value = math.floor(cash)
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
-- make changes through the functions below, so the player list stays in sync.
function DataService:GetData(player: Player): Data?
	local profile = profiles[player]
	return if profile then profile.Data else nil
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
	onCashChanged(player, cash)
	return true
end

function DataService:SetCash(player: Player, amount: number): boolean
	local profile = profiles[player]
	if profile == nil or not isValidCash(amount) then
		return false
	end
	profile.Data.Cash = amount
	onCashChanged(player, amount)
	return true
end

-- Wipes the player's save back to a brand new player's.
function DataService:ResetData(player: Player): boolean
	local profile = profiles[player]
	if profile == nil then
		return false
	end
	replaceData(profile, deepCopy(Template))
	onCashChanged(player, profile.Data.Cash)
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
