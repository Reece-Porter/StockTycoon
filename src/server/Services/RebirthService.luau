--!strict
-- Rebirth (docs/design.md, "Rebirth"). A player with enough Cash
-- (RebirthMath.cashRequired, x3 each time) who owns a Blue Chip company or
-- better can start again: Cash, companies and base upgrades are wiped, and
-- they keep their weapons, their pets (back in the Pets window) and a
-- permanent income multiplier (RebirthMath.incomeMultiplier), with slightly
-- better personal conveyor odds. The client only asks; every requirement is
-- checked here, and the save is written straight away.
--
-- Players get Rebirths, RebirthCost and RebirthHasTier attributes for the
-- rebirth screen, and a Rebirths column in the player list.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.Rebirth)
local RebirthMath = require(ReplicatedStorage.Shared.RebirthMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Types = require(ReplicatedStorage.Shared.Types)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local rebirthLimiter = RateLimiter.new(0.5, 2)

local RebirthService = {}

local function notify(player: Player, message: string)
	if player.Parent == Players then
		Remotes.Notify:FireClient(player, message)
	end
end

-- Every company the player owns that counts for the tier requirement: placed
-- or in storage.
local function ownedCompanies(data: DataService.Data): { Types.CompanyInstance }
	local companies = table.clone(data.Storage)
	for _, company in data.Placed do
		table.insert(companies, company)
	end
	return companies
end

local function publish(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("RebirthCost", RebirthMath.cashRequired(data.Rebirths))
	player:SetAttribute("RebirthHasTier", RebirthMath.hasRequiredTier(ownedCompanies(data)))

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local value = leaderstats:FindFirstChild("Rebirths")
		if value == nil then
			local newValue = Instance.new("IntValue")
			newValue.Name = "Rebirths"
			newValue.Parent = leaderstats
			value = newValue
		end
		if value and value:IsA("IntValue") then
			value.Value = data.Rebirths
		end
	end
end

-- Returns the message for the player.
local function rebirth(player: Player): string
	local data = DataService:GetData(player)
	if data == nil then
		return "Your data hasn't loaded yet."
	end
	local required = RebirthMath.cashRequired(data.Rebirths)
	if data.Cash < required then
		return `You need {Format.cash(required)} to rebirth.`
	end
	if not RebirthMath.hasRequiredTier(ownedCompanies(data)) then
		local tier = Tiers.byId[RebirthConfig.RequiredTier]
		return `You need a {tier.name} company or better, placed or in storage.`
	end
	if CarryService:IsCarrying(player) then
		return "Put down what you're carrying first."
	end
	if data.Machine then
		return "Wait for your Valuation Machine run to finish."
	end

	if not DataService:Rebirth(player) then
		return "Your data hasn't loaded yet."
	end
	DataService:SaveNow(player)
	local rebirths = data.Rebirths
	for _, other in Players:GetPlayers() do
		if other ~= player then
			notify(other, `{player.Name} rebirthed! (Rebirth {rebirths})`)
		end
	end
	local multiplier = RebirthMath.incomeMultiplier(rebirths)
	return `Rebirth {rebirths}! Your income is now x{multiplier}. Your pets are in the Pets window.`
end

function RebirthService:Start()
	DataService:OnDataLoaded(publish)
	DataService:OnDataChanged(publish)

	Remotes.Rebirth.OnServerEvent:Connect(function(player: Player)
		if rebirthLimiter:allow(player) then
			notify(player, rebirth(player))
		end
	end)
end

return RebirthService
