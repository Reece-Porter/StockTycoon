--!strict
-- Teleport buttons (docs/design.md, "Teleports"; Config/Travel): Home (the
-- player's own base), Upgrades (the upgrade station) and Weapons (the weapon
-- shop, next to the pet shop). The client only asks. Nobody teleports while
-- carrying a company (it has to be carried home on foot), while knocked out,
-- or more often than Config/Travel.CooldownSeconds.
--
-- Players get a TravelReadyAt attribute (server time) for the buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TravelConfig = require(ReplicatedStorage.Shared.Config.Travel)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
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
	end
	return nil
end

-- Returns why the player can't go, or nil once they've gone.
local function travel(player: Player, place: string): string?
	if not table.find(TravelConfig.Places, place :: TravelConfig.Place) then
		return "That isn't somewhere you can teleport."
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
