--!strict
-- Teleport buttons (docs/design.md, "Teleports"; Config/Travel): Home (the
-- player's own base), Upgrades (the upgrade station) and Weapons (the weapon
-- shop, next to the pet shop). And the battle arena, from its teleporter
-- gates in the middle of the street (Lib/Arena): only from beside one. The
-- client only asks. Nobody teleports while carrying a company (it has to be
-- carried home on foot), while knocked out, or more often than
-- Config/Travel.CooldownSeconds.
--
-- Players get a TravelReadyAt attribute (server time) for the buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BattleConfig = require(ReplicatedStorage.Shared.Config.Battle)
local TravelConfig = require(ReplicatedStorage.Shared.Config.Travel)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local Arena = require(script.Parent.Parent.Lib.Arena)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local lastTravel: { [Player]: number } = {}
local limiter = RateLimiter.new(2, 3)

local TravelService = {}

-- In front of a station's counter, facing it.
local function stationCFrame(name: string): CFrame?
	local map = workspace:FindFirstChild("Map")
	local shops = map and map:FindFirstChild("Shops")
	local shop = shops and shops:FindFirstChild(name)
	if shop == nil or not shop:IsA("Model") then
		return nil
	end
	local pivot = shop:GetPivot()
	local spot = pivot * CFrame.new(0, TravelConfig.ArriveHeight, -TravelConfig.StationDistance)
	local facing = pivot * CFrame.new(0, TravelConfig.ArriveHeight, 0)
	return CFrame.lookAt(spot.Position, facing.Position)
end

-- Where a place is, or nil if it isn't built (or the player has no base).
function TravelService:GetDestination(player: Player, place: string): CFrame?
	if place == "Home" then
		local base = BaseService:GetBase(player)
		if base == nil then
			return nil
		end
		return base.spawn.CFrame * CFrame.new(0, base.spawn.Size.Y / 2 + TravelConfig.ArriveHeight, 0)
	elseif place == "Upgrades" then
		return stationCFrame("UpgradeStation")
	elseif place == "Weapons" then
		return stationCFrame("WeaponShop")
	elseif place == "Arena" then
		local arrive = Arena.part("Arrive")
		return if arrive then arrive.CFrame * CFrame.new(0, arrive.Size.Y / 2 + TravelConfig.ArriveHeight, 0) else nil
	end
	return nil
end

-- Whether the player is beside one of the arena's gates in the street.
local function atGate(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local reach = BattleConfig.GateDistance + BattleConfig.DistanceTolerance
	for _, pad in Arena.gatePads() do
		if (root.Position - pad.Position).Magnitude <= reach then
			return true
		end
	end
	return false
end

-- Returns why the player can't go, or nil once they've gone.
local function travel(player: Player, place: string): string?
	local isGate = table.find(TravelConfig.Gates, place :: TravelConfig.Place) ~= nil
	if not table.find(TravelConfig.Places, place :: TravelConfig.Place) and not isGate then
		return "That isn't somewhere you can teleport."
	end
	if isGate and not atGate(player) then
		return "Step into the arena's gate in the middle of the street."
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		return "You can't teleport while knocked out."
	end
	if CarryService:IsCarrying(player) then
		return "Teleports only work with empty hands. Carry it home on foot!"
	end
	local now = os.clock()
	local left = (lastTravel[player] or -math.huge) + TravelConfig.CooldownSeconds - now
	if left > 0 then
		return `You can teleport again in {math.ceil(left)}s.`
	end
	local target = TravelService:GetDestination(player, place)
	if target == nil then
		return "That place isn't built yet."
	end
	lastTravel[player] = now
	player:SetAttribute("TravelReadyAt", workspace:GetServerTimeNow() + TravelConfig.CooldownSeconds)
	character:PivotTo(target)
	return nil
end

function TravelService:Start()
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
	Remotes.Travel.OnServerEvent:Connect(function(player: Player, place: unknown)
		if limiter:allow(player) and typeof(place) == "string" then
			local problem = travel(player, place)
			if problem then
				Remotes.Notify:FireClient(player, problem)
			end
		end
	end)
end

return TravelService
