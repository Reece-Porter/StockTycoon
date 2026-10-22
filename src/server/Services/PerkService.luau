--!strict
-- The upgrade station (docs/design.md, "Upgrade station"; Config/Perks):
-- upgrades bought with Gold at Workspace.Map.Shops.UpgradeStation's
-- ShopPrompt, one level at a time. The server checks the player is at the
-- station, has the Gold and isn't at the top level; the client only asks.
--
-- Each upgrade works where it matters, read from the save with PerkMath:
-- walk speed here (Lib/Movement), damage in CombatService, Spinner Luck
-- (saved as ConveyorLuck) and variant chance in SpinnerService, and the
-- money multiplier in IncomeService. Rebirth keeps them, like the Gold they
-- cost (unless Config/Perks.ResetOnRebirth).
--
-- Players get a PerkLevels attribute (JSON: upgrade id to level) for the
-- Upgrades window.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local PerkMath = require(ReplicatedStorage.Shared.PerkMath)
local Perks = require(ReplicatedStorage.Shared.Config.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local Movement = require(script.Parent.Parent.Lib.Movement)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local MAX_ID_LENGTH = 32

local station: BasePart? = nil
local problems: { string } = {}
local buyLimiter = RateLimiter.new(3, 5)

local PerkService = {}

local function applySpeed(player: Player)
	local data = DataService:GetData(player)
	local level = if data then PerkMath.level(data.Perks, "WalkSpeed") else 0
	Movement.set(player, "upgrade", if level > 0 then PerkMath.multiplier("WalkSpeed", level) else nil)
end

local function publish(player: Player)
	local data = DataService:GetData(player)
	if data == nil or player.Parent ~= Players then
		return
	end
	local levels: { [string]: number } = {}
	for _, perk in Perks.list do
		levels[perk.id] = PerkMath.level(data.Perks, perk.id)
	end
	player:SetAttribute("PerkLevels", HttpService:JSONEncode(levels))
	applySpeed(player)
end

local function isNearStation(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local reach = Perks.StationDistance + Perks.StationDistanceTolerance
	return root ~= nil and root:IsA("BasePart") and (root.Position - part.Position).Magnitude <= reach
end

-- Returns the message for the player.
local function buy(player: Player, perkId: string): string
	local perk = Perks.byId[perkId]
	if perk == nil then
		return "That isn't an upgrade."
	end
	local data = DataService:GetData(player)
	if data == nil then
		return "Your data hasn't loaded yet."
	end
	local part = station
	if part == nil then
		return "The upgrade station isn't built yet."
	end
	if not isNearStation(player, part) then
		return "Go to the upgrade station to buy upgrades."
	end
	local level = PerkMath.level(data.Perks, perk.id)
	local cost = PerkMath.cost(perk.id, level)
	if cost == nil then
		return `{perk.name} is at its top level.`
	end
	if not DataService:SpendGold(player, cost) then
		return `You need {Format.gold(cost)} for that. Earn Gold from Index challenges and the battle arena.`
	end
	DataService:SetPerkLevel(player, perk.id, level + 1)
	AnalyticsService:SpentGold(player, "Upgrade", cost, perk.id)
	return `{perk.name} is now level {level + 1}!`
end

-- Admin testing: sets an upgrade's level without paying.
function PerkService:SetLevel(player: Player, perkId: string, level: number): boolean
	local perk = Perks.byId[perkId]
	if perk == nil or level < 0 or level > perk.maxLevel or level ~= math.floor(level) then
		return false
	end
	return DataService:SetPerkLevel(player, perk.id, level)
end

-- Problems found with the hand-built station, for the debug panel.
function PerkService:GetProblems(): { string }
	return problems
end

function PerkService:Init()
	local map = workspace:FindFirstChild("Map")
	local shops = map and map:FindFirstChild("Shops")
	local upgradeStation = shops and shops:FindFirstChild("UpgradeStation")
	local prompt = upgradeStation and upgradeStation:FindFirstChild("ShopPrompt")
	if prompt and prompt:IsA("BasePart") then
		station = prompt
	else
		table.insert(problems, "Workspace.Map.Shops.UpgradeStation.ShopPrompt is missing or isn't a part")
	end
	for _, problem in problems do
		warn(`[PerkService] {problem}. Run studio/BuildMap.luau in Studio.`)
	end
end

function PerkService:Start()
	DataService:OnDataLoaded(publish)
	DataService:OnDataChanged(publish)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			-- After Lib/Movement clears the old character's speeds.
			task.defer(applySpeed, player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	Remotes.BuyPerk.OnServerEvent:Connect(function(player: Player, perkId: unknown)
		if buyLimiter:allow(player) and typeof(perkId) == "string" and #perkId <= MAX_ID_LENGTH then
			Remotes.Notify:FireClient(player, buy(player, perkId))
		end
	end)
end

return PerkService
