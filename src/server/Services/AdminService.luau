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
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

-- Keeps typed amounts well inside the range a number stores exactly.
local MAX_AMOUNT = 1e15

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
	DataService:OnDataLoaded(onDataLoaded)
end

return AdminService
