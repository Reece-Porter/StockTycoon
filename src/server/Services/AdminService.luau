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
local SpinnerConfig = require(ReplicatedStorage.Shared.Config.Spinner)
local Monetisation = require(ReplicatedStorage.Shared.Config.Monetisation)
local Perks = require(ReplicatedStorage.Shared.Config.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpawnRoll = require(ReplicatedStorage.Shared.SpawnRoll)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local VariantMath = require(ReplicatedStorage.Shared.VariantMath)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local RebirthMath = require(ReplicatedStorage.Shared.RebirthMath)
local RewardMath = require(ReplicatedStorage.Shared.RewardMath)
local Format = require(ReplicatedStorage.Shared.Format)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local AnalyticsService = require(script.Parent.AnalyticsService)
local BattleService = require(script.Parent.BattleService)
local BaseService = require(script.Parent.BaseService)
local ConveyorService = require(script.Parent.ConveyorService)
local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MonetisationService = require(script.Parent.MonetisationService)
local PerkService = require(script.Parent.PerkService)
local PetService = require(script.Parent.PetService)
local PetShopService = require(script.Parent.PetShopService)
local PurchaseService = require(script.Parent.PurchaseService)
local RewardsService = require(script.Parent.RewardsService)
local SpinnerService = require(script.Parent.SpinnerService)
local StealService = require(script.Parent.StealService)
local StealConfig = require(ReplicatedStorage.Shared.Config.Steal)
local TakeoverService = require(script.Parent.TakeoverService)
local WeaponShopService = require(script.Parent.WeaponShopService)
local PhotoBooth = require(script.Parent.Parent.Lib.PhotoBooth)

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

-- Matches "gavel", "Golden Calculator", "stapler-gun" and so on to a weapon.
local function findWeapon(text: string?): Weapons.Weapon?
	if text == nil then
		return nil
	end
	local wanted = string.lower((string.gsub(text, "[%s%-]", "")))
	for _, weapon in Weapons.list do
		local name = string.lower((string.gsub(weapon.name, "[%s%-]", "")))
		if string.lower(weapon.id) == wanted or name == wanted then
			return weapon
		end
	end
	return nil
end

-- Matches a pet by id or name ("coffeecat", "Coffee Cat"), or a rarity
-- ("mythic"), in which case one of that rarity's pets is picked at random.
local function findPet(text: string?): Pets.Pet?
	if text == nil then
		return nil
	end
	local wanted = string.lower((string.gsub(text, "[%s%-]", "")))
	for _, pet in Pets.list do
		local name = string.lower((string.gsub(pet.name, "[%s%-]", "")))
		if string.lower(pet.id) == wanted or name == wanted then
			return pet
		end
	end
	for _, rarity in Pets.rarities do
		if string.lower(rarity.id) == wanted then
			local choices = Pets.byRarity[rarity.id]
			return choices[math.random(#choices)]
		end
	end
	return nil
end

-- A player in this server whose name starts with the text, ignoring case.
local function findVariant(text: string?): Variants.Variant?
	local wanted = string.lower(text or "")
	for _, variant in Variants.list do
		if string.lower(variant.id) == wanted then
			return variant
		end
	end
	return nil
end

local function variantNames(): string
	local names = {}
	for _, variant in Variants.list do
		table.insert(names, string.lower(variant.id))
	end
	return table.concat(names, ", ")
end

local function findPass(text: string?): Monetisation.Pass?
	local wanted = string.lower(text or "")
	for _, pass in Monetisation.Passes do
		if string.lower(pass.name) == wanted then
			return pass
		end
	end
	return nil
end

local function passNames(): string
	local names = {}
	for _, pass in Monetisation.Passes do
		table.insert(names, string.lower(pass.name))
	end
	return table.concat(names, "|")
end

local function findPlayer(text: string): Player?
	local wanted = string.lower(text)
	for _, candidate in Players:GetPlayers() do
		if string.sub(string.lower(candidate.Name), 1, #wanted) == wanted then
			return candidate
		end
	end
	return nil
end

local function isShared(text: string?): boolean
	return text ~= nil and string.lower(text) == "shared"
end

local function tierNames(): string
	local names = {}
	for _, tier in Tiers.list do
		table.insert(names, string.lower(tier.id))
	end
	return table.concat(names, ", ")
end

-- Rolls a tier the given number of times, using the same function as real
-- spawns, and compares the results with the odds: the shared conveyor's
-- (Config/Conveyor) or this player's Stock Spinner's (Config/Spinner after
-- their rebirths and Spinner Luck).
local function oddsReport(player: Player, shared: boolean, rolls: number): string
	local weights: { SpinnerConfig.WeightEntry } = if shared
		then ConveyorConfig.Shared.Weights
		else SpinnerService:GetWeights(player)
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

	local where = if shared then "Shared conveyor" else "Your Stock Spinner (with your rebirths and Spinner Luck)"
	local lines = { `{where}, {rolls} rolls (got / expected):` }
	for _, entry in weights do
		local got = (counts[entry.tier] or 0) / rolls * 100
		local expected = entry.weight / total * 100
		table.insert(lines, string.format("%s %.2f%% / %.2f%%", Tiers.byId[entry.tier].name, got, expected))
	end
	return table.concat(lines, "\n")
end

local commands: { Command } = {
	{
		alias = "/givecash",
		usage = "/givecash <amount> [player]",
		run = function(player, args)
			local amount = parseAmount(args[1])
			if amount == nil then
				return "Usage: /givecash <amount> [player]"
			end
			local target = if args[2] then findPlayer(args[2]) else player
			if target == nil then
				return `No player called "{args[2]}" in this server.`
			end
			if not DataService:AddCash(target, amount) then
				return `{target.Name}'s data hasn't loaded yet.`
			end
			return if target == player then `Gave you {amount} Cash.` else `Gave {target.Name} {amount} Cash.`
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
		usage = "/spawn <tier> [shared] [variant]",
		run = function(player, args)
			local tier = findTier(args[1])
			if tier == nil then
				return `Usage: /spawn <tier> [shared] [variant], where tier is one of: {tierNames()}`
			end
			local shared, variantId = false, nil
			for index = 2, #args do
				local variant = findVariant(args[index])
				if isShared(args[index]) then
					shared = true
				elseif string.lower(args[index]) == "regular" then
					variantId = "regular"
				elseif variant then
					variantId = variant.id
				else
					return `Usage: /spawn <tier> [shared] [variant], where variant is regular or one of: {variantNames()}`
				end
			end
			local what = if variantId and variantId ~= "regular" then `{variantId} {tier.name}` else tier.name
			if not shared then
				if tier.sharedOnly then
					return `{tier.name} companies are only on the shared conveyor: /spawn {string.lower(tier.id)} shared`
				end
				if not SpinnerService:RollNow(player, tier.id, variantId) then
					return "You don't have a base, or your data hasn't loaded yet."
				end
				return `Rolled your Stock Spinner: a {what} comes out first.`
			end
			local item = ConveyorService:SpawnShared(tier.id, variantId)
			if item == nil then
				return "Couldn't spawn it. Check the console for a missing model or conveyor."
			end
			return `Spawned a {what} on the shared conveyor.`
		end,
	},
	{
		alias = "/roll",
		usage = "/roll",
		run = function(player)
			if not SpinnerService:RollNow(player) then
				return "You don't have a base, or your data hasn't loaded yet."
			end
			return "Rolled your Stock Spinner."
		end,
	},
	{
		alias = "/battle",
		usage = "/battle <bots [count] | skip>",
		run = function(_player, args)
			local action = string.lower(args[1] or "")
			if action == "bots" then
				local count = if args[2] then parseAmount(args[2]) else 3
				if count == nil or count < 1 then
					return "Usage: /battle bots [count]"
				end
				local added = BattleService:AddBots(count)
				return `Added {added} test bot(s) to the next battle.`
			elseif action == "skip" then
				return BattleService:Skip()
			end
			return "Usage: /battle bots [count] (test bots join the next battle), /battle skip (start now, or skip to the next part)"
		end,
	},
	{
		alias = "/takeover",
		usage = "/takeover [start [minutes] | stop]",
		run = function(_player, args)
			local action = string.lower(args[1] or "")
			if action == "start" then
				local minutes = if args[2] then tonumber(args[2]) else nil
				if args[2] and (minutes == nil or minutes <= 0 or minutes > 60) then
					return "Usage: /takeover start [minutes], up to 60 minutes"
				end
				local seconds = if minutes then minutes * 60 else StealConfig.Takeover.DurationSeconds
				TakeoverService:StartNow(seconds)
				return `Started a Hostile Takeover for {Format.longDuration(seconds)}.`
			elseif action == "stop" then
				TakeoverService:StopNow()
				return "Stopped the Hostile Takeover."
			elseif action ~= "" then
				return "Usage: /takeover [start [minutes] | stop]"
			end
			local endsAt = TakeoverService:GetEndsAt()
			local time = workspace:GetServerTimeNow()
			if endsAt then
				return `A Hostile Takeover is on for another {Format.duration(endsAt - time)}.`
			end
			return `The next Hostile Takeover starts in {Format.duration(TakeoverService:GetNextAt() - time)}.`
		end,
	},
	{
		alias = "/testvariants",
		usage = "/testvariants [rolls]",
		run = function(player, args)
			local rolls = if args[1] then parseAmount(args[1]) else DEFAULT_ODDS_ROLLS
			if rolls == nil or rolls < 1 or rolls > MAX_ODDS_ROLLS then
				return `Usage: /testvariants [rolls], up to {MAX_ODDS_ROLLS} rolls`
			end
			-- With the player's own Variant Chance upgrade, as in their spinner.
			local chance = SpinnerService:GetVariantChance(player)
			local counts: { [string]: number } = {}
			local random = Random.new()
			for _ = 1, rolls do
				local variant = VariantMath.roll(random:NextNumber(), chance)
				if variant then
					counts[variant] = (counts[variant] or 0) + 1
				end
			end
			local lines = { `{rolls} spawns, variant chance x{chance} (got / expected):` }
			for _, variant in Variants.list do
				local got = (counts[variant.id] or 0) / rolls * 100
				local expected = VariantMath.chance(variant, chance) * 100
				table.insert(lines, string.format("%s %.3f%% / %.3f%%", variant.name, got, expected))
			end
			local report = table.concat(lines, "\n")
			AdminService:SetDebugValue(player, "VariantTest", report)
			return report
		end,
	},
	{
		alias = "/testodds",
		usage = "/testodds [shared] [rolls]",
		run = function(player, args)
			local shared, rolls = false, DEFAULT_ODDS_ROLLS
			for _, arg in args do
				if isShared(arg) then
					shared = true
				else
					rolls = parseAmount(arg) or -1
				end
			end
			if rolls < 1 or rolls > MAX_ODDS_ROLLS then
				return `Usage: /testodds [shared] [rolls], up to {MAX_ODDS_ROLLS} rolls`
			end
			local report = oddsReport(player, shared, rolls)
			AdminService:SetDebugValue(player, "OddsTest", report)
			return report
		end,
	},
	{
		alias = "/racetest",
		usage = "/racetest",
		run = function(player)
			local item = ConveyorService:SpawnShared("Startup")
			if item == nil then
				return "Couldn't spawn on the shared conveyor. Check the console."
			end
			-- Shuffle so it isn't always the same player tried first.
			local players = Players:GetPlayers()
			for index = #players, 2, -1 do
				local swap = math.random(index)
				players[index], players[swap] = players[swap], players[index]
			end

			local results = PurchaseService:RaceForItem(players, item.id)
			local owners = 0
			for _, result in results do
				if string.find(result, ": Bought ", 1, true) then
					owners += 1
				end
			end
			local report = `Race for one Startup, {#players} buyers, {owners} owner(s):\n{table.concat(results, "\n")}`
			AdminService:SetDebugValue(player, "RaceTest", report)
			return report
		end,
	},
	{
		alias = "/protect",
		usage = "/protect [player] [seconds]",
		run = function(player, args)
			local target, seconds = player, StealConfig.NewPlayerProtectionSeconds
			for _, arg in args do
				local number = parseAmount(arg)
				if number then
					seconds = number
				else
					local found = findPlayer(arg)
					if found == nil then
						return `No player called "{arg}" in this server.`
					end
					target = found
				end
			end
			StealService:Protect(target, seconds)
			return if seconds > 0
				then `{target.Name} is protected from stealing for {seconds} seconds.`
				else `{target.Name} is no longer protected.`
		end,
	},
	{
		alias = "/giveweapon",
		usage = "/giveweapon <weapon> [player]",
		run = function(player, args)
			local weapon = findWeapon(args[1])
			if weapon == nil then
				local ids = {}
				for _, each in Weapons.list do
					table.insert(ids, each.id)
				end
				return `Usage: /giveweapon <weapon> [player], where weapon is one of: {table.concat(ids, ", ")}`
			end
			local target = if args[2] then findPlayer(args[2]) else player
			if target == nil then
				return `No player called "{args[2]}" in this server.`
			end
			if not WeaponShopService:Give(target, weapon.id) then
				return `{target.Name}'s data hasn't loaded yet.`
			end
			return `Gave {if target == player then "you" else target.Name} the {weapon.name}.`
		end,
	},
	{
		alias = "/setrebirths",
		usage = "/setrebirths <count> [player]",
		run = function(player, args)
			local count = parseAmount(args[1])
			if count == nil then
				return "Usage: /setrebirths <count> [player]"
			end
			local target = if args[2] then findPlayer(args[2]) else player
			if target == nil then
				return `No player called "{args[2]}" in this server.`
			end
			if not DataService:SetRebirths(target, count) then
				return `{target.Name}'s data hasn't loaded yet.`
			end
			local whose = if target == player then "your" else `{target.Name}'s`
			local multiplier = RebirthMath.incomeMultiplier(count)
			return `Set {whose} rebirths to {count} (income x{multiplier}).`
		end,
	},
	{
		alias = "/givepet",
		usage = "/givepet <pet or rarity> [player]",
		run = function(player, args)
			local pet = findPet(args[1])
			if pet == nil then
				return "Usage: /givepet <pet or rarity> [player], e.g. /givepet coffeecat or /givepet mythic"
			end
			local target = if args[2] then findPlayer(args[2]) else player
			if target == nil then
				return `No player called "{args[2]}" in this server.`
			end
			if not PetShopService:Give(target, pet.id) then
				return `Couldn't give it: {target.Name}'s data hasn't loaded or their pets are full.`
			end
			local rarity = Pets.rarityById[pet.rarity]
			return `Gave {if target == player then "you" else target.Name} a {rarity.name} {pet.name}.`
		end,
	},
	{
		alias = "/testspins",
		usage = "/testspins [rolls]",
		run = function(player, args)
			local rolls = if args[1] then parseAmount(args[1]) else DEFAULT_ODDS_ROLLS
			if rolls == nil or rolls < 1 or rolls > MAX_ODDS_ROLLS then
				return `Usage: /testspins [rolls], up to {MAX_ODDS_ROLLS} rolls`
			end
			local report = PetShopService:TestOdds(rolls)
			AdminService:SetDebugValue(player, "SpinTest", report)
			return report
		end,
	},
	{
		alias = "/skipplaytime",
		usage = "/skipplaytime <minutes>",
		run = function(player, args)
			local minutes = parseAmount(args[1])
			if minutes == nil or minutes < 1 then
				return "Usage: /skipplaytime <minutes>, e.g. /skipplaytime 60"
			end
			if not RewardsService:SkipPlaytime(player, minutes) then
				return NOT_LOADED_MESSAGE
			end
			return `Added {minutes} minutes to today's playtime.`
		end,
	},
	{
		alias = "/shiftday",
		usage = "/shiftday [days]",
		run = function(player, args)
			local days = if args[1] then parseAmount(args[1]) else 1
			if days == nil or days < 1 then
				return "Usage: /shiftday [days], e.g. /shiftday 2 to miss a day"
			end
			if not RewardsService:ShiftDays(player, days) then
				return NOT_LOADED_MESSAGE
			end
			return `Acting as if {days} day(s) have passed: playtime resets within a second and the daily reward is ready.`
		end,
	},
	{
		alias = "/discover",
		usage = "/discover <count>",
		run = function(player, args)
			local count = parseAmount(args[1])
			if count == nil or count < 1 then
				return "Usage: /discover <count>, e.g. /discover 5"
			end
			local added = IndexService:DiscoverRandom(player, count)
			return `Added {added} companies to your Index ({IndexService:GetDiscoveredCount(player)}/{#Companies.list}).`
		end,
	},
	{
		alias = "/refreshboards",
		usage = "/refreshboards",
		run = function()
			-- Saving and reading the boards waits on DataStores, so it runs on
			-- its own rather than holding up the reply.
			task.spawn(function()
				LeaderboardService:UpdateNow()
			end)
			return "Saving everyone's leaderboard values and reloading the boards."
		end,
	},
	{
		alias = "/setupgrade",
		usage = "/setupgrade <upgrade> <level> [player]",
		run = function(player, args)
			local wanted = string.lower(args[1] or "")
			local names = {}
			local found: Perks.Perk? = nil
			for _, perk in Perks.list do
				table.insert(names, string.lower(perk.id))
				if string.lower(perk.id) == wanted then
					found = perk
				end
			end
			local level = parseAmount(args[2])
			local target = if args[3] then findPlayer(args[3]) else player
			if found == nil or level == nil or target == nil then
				return `Usage: /setupgrade <{table.concat(names, "|")}> <level> [player]`
			end
			if not PerkService:SetLevel(target, found.id, level) then
				return `{found.name} goes from 0 to {found.maxLevel}, and {target.Name}'s data has to be loaded.`
			end
			return `{found.name} is level {level} for {if target == player then "you" else target.Name}.`
		end,
	},
	{
		alias = "/givepass",
		usage = "/givepass <pass> [player]",
		run = function(player, args)
			local pass = findPass(args[1])
			local target = if args[2] then findPlayer(args[2]) else player
			if pass == nil or target == nil then
				return `Usage: /givepass <{passNames()}> [player]`
			end
			MonetisationService:SetPass(target, pass.name, true)
			return `{if target == player then "You have" else target.Name .. " has"} {pass.title} for this session.`
		end,
	},
	{
		alias = "/removepass",
		usage = "/removepass <pass> [player]",
		run = function(player, args)
			local pass = findPass(args[1])
			local target = if args[2] then findPlayer(args[2]) else player
			if pass == nil or target == nil then
				return `Usage: /removepass <{passNames()}> [player]`
			end
			MonetisationService:SetPass(target, pass.name, false)
			return `{if target == player then "You don't" else target.Name .. " doesn't"} have {pass.title} for this session.`
		end,
	},
	{
		alias = "/buyproduct",
		usage = "/buyproduct <product>",
		run = function(player, args)
			local wanted = string.lower(args[1] or "")
			local keys = {}
			for _, product in Monetisation.Products do
				table.insert(keys, string.lower(product.key))
				if string.lower(product.key) == wanted then
					-- Giving and saving it waits on the save, so it runs on its own.
					task.spawn(function()
						if not MonetisationService:TestProduct(player, product.key) then
							Remotes.Notify:FireClient(player, `Couldn't give {product.title}.`)
						end
					end)
					return `Giving {product.title} as if it was bought...`
				end
			end
			return `Usage: /buyproduct <{table.concat(keys, "|")}>`
		end,
	},
	{
		alias = "/analytics",
		usage = "/analytics",
		run = function()
			return AnalyticsService:GetReport()
		end,
	},
	{
		alias = "/booth",
		usage = "/booth [back]",
		run = function(player, args)
			if args[1] and string.lower(args[1]) == "back" then
				local base = BaseService:GetBase(player)
				local character = player.Character
				if base == nil or character == nil then
					return "You don't have a base to go back to."
				end
				player:SetAttribute("BoothCamera", nil)
				character:PivotTo(base.spawn.CFrame + Vector3.new(0, 4, 0))
				return "Back at your base."
			end
			return PhotoBooth.goTo(player)
		end,
	},
	{
		alias = "/pose",
		usage = "/pose <hero|left|right> <company or pet> [variant] [size], /pose base, /pose clear [spot]",
		run = function(player, args)
			local first = if args[1] then string.lower(args[1]) else ""
			if first == "clear" then
				PhotoBooth.clear(
					if args[2]
						then string.upper(string.sub(args[2], 1, 1)) .. string.lower(string.sub(args[2], 2))
						else nil
				)
				return "Cleared."
			end
			if first == "base" then
				local base = BaseService:GetBase(player)
				if base == nil then
					return "You don't have a base."
				end
				return PhotoBooth.poseBase(base.model, base.name)
			end
			if args[2] == nil then
				return "Usage: /pose <hero|left|right> <company or pet> [variant] [size], /pose base, /pose clear [spot]"
			end
			-- The name can be several words; a variant and a size can follow.
			local words = table.move(args, 2, #args, 1, {})
			local size = tonumber(words[#words])
			if size then
				table.remove(words)
			end
			local variant: string? = nil
			if #words > 1 and findVariant(words[#words]) then
				variant = table.remove(words)
			end
			return PhotoBooth.pose(args[1], table.concat(words, " "), variant, size)
		end,
	},
	{
		alias = "/backdrop",
		usage = "/backdrop <colour>",
		run = function(_, args)
			return PhotoBooth.backdrop(args[1] or "")
		end,
	},
	{
		alias = "/boothcam",
		usage = "/boothcam <icon|wide|base|free|off>",
		run = function(player, args)
			return PhotoBooth.camera(player, args[1] or "")
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

	local problems = table.clone(BaseService:GetProblems())
	table.move(ConveyorService:GetProblems(), 1, #ConveyorService:GetProblems(), #problems + 1, problems)
	for _, list in
		{
			WeaponShopService:GetProblems(),
			PetService:GetProblems(),
			PetShopService:GetProblems(),
			LeaderboardService:GetProblems(),
			PerkService:GetProblems(),
		}
	do
		table.move(list, 1, #list, #problems + 1, problems)
	end
	if #problems > 0 then
		AdminService:SetDebugValue(player, "MapProblems", table.concat(problems, "\n"))
	end
	if BaseService:IsMapOutOfDate() then
		AdminService:SetDebugValue(player, "Map", BaseService.MapOutOfDateMessage)
		Remotes.Notify:FireClient(player, BaseService.MapOutOfDateMessage, "Warning")
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
	AdminService:SetDebugValue(player, "Pets", `{#data.Pets}/{Pets.InventoryCap}`)
	AdminService:SetDebugValue(player, "Stats", `{data.Stats.Steals} steals, {data.Stats.Knockouts} knockouts`)
	AdminService:SetDebugValue(player, "Tutorial", `step {data.TutorialStep}`)
	local owned = {}
	for _, pass in Monetisation.Passes do
		if player:GetAttribute(`Pass{pass.name}`) == true then
			table.insert(owned, pass.title)
		end
	end
	local passText = if #owned > 0 then table.concat(owned, ", ") else "none"
	AdminService:SetDebugValue(player, "Passes", `{passText}; {#data.Receipts} purchases given`)
	local levels = {}
	for _, perk in Perks.list do
		table.insert(levels, `{perk.id} {data.Perks[perk.id] or 0}`)
	end
	AdminService:SetDebugValue(player, "Upgrades", table.concat(levels, ", "))
	local multiplier = RebirthMath.incomeMultiplier(data.Rebirths)
	local nextCost = RebirthMath.cashRequired(data.Rebirths)
	AdminService:SetDebugValue(player, "Rebirths", `{data.Rebirths} (income x{multiplier}, next needs {nextCost} Cash)`)
	AdminService:SetDebugValue(player, "FloorPets", PetService:DescribeFloors(player))
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

-- Rewards and cash pads change every second without a data change, so their
-- rows are refreshed on a timer.
local function refreshRewardRows(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	local rewards = data.Rewards
	local today = RewardMath.day(os.time())
	local daily = RewardMath.daily(rewards.LastDailyDay, rewards.DailyStreak, today)
	local played = Format.duration(rewards.PlaytimeSeconds)
	local claimed = table.concat(rewards.ClaimedPlaytime, ", ")
	AdminService:SetDebugValue(
		player,
		"Playtime",
		`{played} on day {rewards.PlaytimeDay} (today is {today}), claimed: {claimed}`
	)
	AdminService:SetDebugValue(
		player,
		"Daily",
		`streak {daily.streak}, next Day {daily.nextDay}, {if daily.claimable then "ready" else "claimed today"}`
	)
	local onPads = 0
	for _, amount in data.Uncollected do
		onPads += amount
	end
	AdminService:SetDebugValue(player, "CashPads", `{Format.cash(onPads)} waiting`)
	AdminService:SetDebugValue(player, "Boost", Format.duration(rewards.BoostSeconds))
	AdminService:SetDebugValue(player, "SpinTokens", rewards.SpinTokens)
	AdminService:SetDebugValue(
		player,
		"Index",
		`{IndexService:GetDiscoveredCount(player)}/{#Companies.list}, prizes claimed: {table.concat(
			data.Index.Claimed,
			", "
		)}`
	)
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
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if AdminService:IsAdmin(player) then
					refreshRewardRows(player)
				end
			end
		end
	end)
end

return AdminService
