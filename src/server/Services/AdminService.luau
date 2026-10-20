--!strict
-- Admin chat commands for testing, such as "/givecash 1000". Anyone can type
-- them, but the server only carries them out for the user IDs in
-- Config/Admins.
--
-- Admins also get the IsAdmin attribute, which shows them the debug panel, and
-- "Debug_<name>" attributes that the panel lists. Other services can add rows
-- with AdminService:SetDebugValue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Admins = require(ReplicatedStorage.Shared.Config.Admins)
local BaseConfig = require(ReplicatedStorage.Shared.Config.Base)
local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local ConveyorConfig = require(ReplicatedStorage.Shared.Config.Conveyor)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpawnRoll = require(ReplicatedStorage.Shared.SpawnRoll)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local BaseService = require(script.Parent.BaseService)
local ConveyorService = require(script.Parent.ConveyorService)
local DataService = require(script.Parent.DataService)

-- Keeps typed amounts well inside the range a number stores exactly.
local MAX_AMOUNT = 1e15

local DEFAULT_ODDS_ROLLS = 10_000
local MAX_ODDS_ROLLS = 1_000_000

local NOT_LOADED_MESSAGE = "Your data hasn't loaded yet."

type Command = {
	alias: string,
	usage: string,
	run: (player: Player, args: { string }) -> string,
}

local AdminService = {}

local function parseAmount(text: string?): number?
	local amount = tonumber(text)
	if amount == nil or amount ~= amount or amount < 0 or amount > MAX_AMOUNT then
		return nil
	end
	return math.floor(amount)
end

-- Matches "bluechip", "blue-chip", "Blue Chip" and so on to a tier.
local function findTier(text: string?): Tiers.Tier?
	if text == nil then
		return nil
	end
	local wanted = string.lower((string.gsub(text, "[%s%-]", "")))
	for _, tier in Tiers.list do
		if string.lower(tier.id) == wanted then
			return tier
		end
	end
	return nil
end

local function tierNames(): string
	local names = {}
	for _, tier in Tiers.list do
		table.insert(names, string.lower(tier.id))
	end
	return table.concat(names, ", ")
end

-- Rolls the personal conveyor's tier the given number of times, using the same
-- function as real spawns, and compares the results with Config/Conveyor.
local function oddsReport(rolls: number): string
	local weights = ConveyorConfig.Personal.Weights
	local random = Random.new()
	local counts: { [string]: number } = {}
	for _ = 1, rolls do
		local tier = SpawnRoll.pickTier(weights, random:NextNumber())
		counts[tier] = (counts[tier] or 0) + 1
	end

	local total = 0
	for _, entry in weights do
		total += entry.weight
	end

	local lines = { `{rolls} rolls (got / expected):` }
	for _, entry in weights do
		local got = (counts[entry.tier] or 0) / rolls * 100
		local expected = entry.weight / total * 100
		table.insert(lines, string.format("%s %.1f%% / %.1f%%", Tiers.byId[entry.tier].name, got, expected))
	end
	return table.concat(lines, "\n")
end

local commands: { Command } = {
	{
		alias = "/givecash",
		usage = "/givecash <amount>",
		run = function(player, args)
			local amount = parseAmount(args[1])
			if amount == nil then
				return "Usage: /givecash <amount>"
			end
			if not DataService:AddCash(player, amount) then
				return NOT_LOADED_MESSAGE
			end
			return `Gave you {amount} Cash.`
		end,
	},
	{
		alias = "/setcash",
		usage = "/setcash <amount>",
		run = function(player, args)
			local amount = parseAmount(args[1])
			if amount == nil then
				return "Usage: /setcash <amount>"
			end
			if not DataService:SetCash(player, amount) then
				return NOT_LOADED_MESSAGE
			end
			return `Set your Cash to {amount}.`
		end,
	},
	{
		alias = "/spawn",
		usage = "/spawn <tier>",
		run = function(player, args)
			local tier = findTier(args[1])
			if tier == nil then
				return `Usage: /spawn <tier>, where tier is one of: {tierNames()}`
			end
			local base = BaseService:GetBase(player)
			if base == nil then
				return "You don't have a base."
			end
			if ConveyorService:SpawnOnBase(base, tier.id) == nil then
				return "Couldn't spawn it. Check the console for a missing model."
			end
			return `Spawned a {tier.name} on your conveyor.`
		end,
	},
	{
		alias = "/testodds",
		usage = "/testodds [rolls]",
		run = function(player, args)
			local rolls = if args[1] then parseAmount(args[1]) else DEFAULT_ODDS_ROLLS
			if rolls == nil or rolls < 1 or rolls > MAX_ODDS_ROLLS then
				return `Usage: /testodds [rolls], up to {MAX_ODDS_ROLLS}`
			end
			local report = oddsReport(rolls)
			AdminService:SetDebugValue(player, "OddsTest", report)
			return report
		end,
	},
	{
		alias = "/resetdata",
		usage = "/resetdata",
		run = function(player)
			if not DataService:ResetData(player) then
				return NOT_LOADED_MESSAGE
			end
			return "Your data has been reset to a new player's."
		end,
	},
}

function AdminService:IsAdmin(player: Player): boolean
	if table.find(Admins.UserIds, player.UserId) then
		return true
	end
	return RunService:IsStudio() and table.find(Admins.StudioUserIds, player.UserId) ~= nil
end

-- Shows a row on an admin's debug panel. Does nothing for other players.
function AdminService:SetDebugValue(player: Player, name: string, value: string | number | boolean)
	if self:IsAdmin(player) then
		player:SetAttribute(`Debug_{name}`, value)
	end
end

local function onCommand(command: Command, source: TextSource, text: string)
	local player = Players:GetPlayerByUserId(source.UserId)
	if player == nil then
		return
	end

	if not AdminService:IsAdmin(player) then
		Remotes.Notify:FireClient(player, "You don't have permission to use that command.")
		return
	end

	local args = {}
	for word in string.gmatch(text, "%S+") do
		table.insert(args, word)
	end
	table.remove(args, 1)

	Remotes.Notify:FireClient(player, command.run(player, args))
end

local function onPlayerAdded(player: Player)
	if not AdminService:IsAdmin(player) then
		return
	end

	local usages = {}
	for _, command in commands do
		table.insert(usages, command.usage)
	end

	player:SetAttribute("IsAdmin", true)
	AdminService:SetDebugValue(player, "Commands", table.concat(usages, "\n"))

	local problems = BaseService:GetProblems()
	if #problems > 0 then
		AdminService:SetDebugValue(player, "MapProblems", table.concat(problems, "\n"))
	end
end

local function onDataLoaded(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	AdminService:SetDebugValue(player, "DataVersion", data.DataVersion)
	AdminService:SetDebugValue(
		player,
		"Saving",
		if DataService:IsSaving() then "On" else "Off (turn on Studio Access to API Services)"
	)
end

local function onDataChanged(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end

	local placed = 0
	for _ in data.Placed do
		placed += 1
	end
	local carrying = data.Carrying
	local carryingName = if carrying then Companies.byId[carrying.companyId].name else "nothing"

	local floors = {}
	for floor, open in data.UnlockedPlots do
		table.insert(floors, `Floor {floor}: {open}/{BaseConfig.PlotsPerFloor}`)
	end

	AdminService:SetDebugValue(player, "Floors", table.concat(floors, ", "))
	AdminService:SetDebugValue(player, "Storage", `{#data.Storage}/{BaseConfig.StorageCapacity}`)
	AdminService:SetDebugValue(player, "Placed", placed)
	AdminService:SetDebugValue(player, "Carrying", carryingName)
end

function AdminService:Init()
	for _, command in commands do
		local textChatCommand = Instance.new("TextChatCommand")
		textChatCommand.Name = `Admin{string.sub(command.alias, 2)}`
		textChatCommand.PrimaryAlias = command.alias
		-- Keep admin commands out of everyone's chat suggestions.
		textChatCommand.AutocompleteVisible = false
		textChatCommand.Triggered:Connect(function(source: TextSource, text: string)
			onCommand(command, source, text)
		end)
		textChatCommand.Parent = TextChatService
	end
end

function AdminService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	DataService:OnDataLoaded(function(player)
		onDataLoaded(player)
		onDataChanged(player)
	end)
	DataService:OnDataChanged(onDataChanged)
	BaseService:OnBaseAssigned(function(player, base)
		AdminService:SetDebugValue(player, "Base", base.name)
	end)
end

return AdminService
