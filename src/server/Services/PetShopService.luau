--!strict
-- The pet shop: spins at Workspace.Map.Shops.PetShop's ShopPrompt part
-- (docs/design.md, "Pet shop"). A spin uses a free spin token from rewards if
-- the player has one, and otherwise costs Cash (PetMath.spinCost, rising with
-- rebirths). There are no Robux spins. The server rolls every spin itself
-- with PetMath, adds the pet to the player's inventory and tells their client
-- which pet it was with PetSpun, for the reveal. The client only asks to spin.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local PetMath = require(ReplicatedStorage.Shared.PetMath)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local RewardsService = require(script.Parent.RewardsService)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local random = Random.new()
local shopPrompt: BasePart? = nil
local problems: { string } = {}
local spinLimiter = RateLimiter.new(2, 3)

local PetShopService = {}

local function notify(player: Player, message: string)
	if player.Parent == Players then
		Remotes.Notify:FireClient(player, message)
	end
end

local function isNearShop(player: Player, prompt: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local reach = Pets.ShopDistance + Pets.ShopDistanceTolerance
	return root ~= nil and root:IsA("BasePart") and (root.Position - prompt.Position).Magnitude <= reach
end

local function addPet(player: Player, pet: Pets.Pet): boolean
	return DataService:AddPet(player, { instanceId = HttpService:GenerateGUID(false), petId = pet.id })
end

-- Returns why the spin was refused, or nil once it is done.
local function spin(player: Player): string?
	local data = DataService:GetData(player)
	if data == nil then
		return "Your data hasn't loaded yet."
	end
	local prompt = shopPrompt
	if prompt == nil then
		return "The pet shop isn't built yet."
	end
	if not isNearShop(player, prompt) then
		return "Go to the pet shop to spin."
	end
	if #data.Pets >= Pets.InventoryCap then
		return `You have {Pets.InventoryCap} pets, the most you can keep. Let some go first.`
	end
	local cost = PetMath.spinCost(data.Rebirths)
	local usedToken = RewardsService:UseSpinToken(player)
	if not usedToken and not DataService:SpendCash(player, cost) then
		return `A spin costs {Format.cash(cost)}.`
	end

	local pet = PetMath.spin(random:NextNumber(), random:NextNumber())
	if not addPet(player, pet) then
		if usedToken then
			RewardsService:ReturnSpinToken(player)
		else
			DataService:AddCash(player, cost)
		end
		return `You have {Pets.InventoryCap} pets, the most you can keep. Let some go first.`
	end
	Remotes.PetSpun:FireClient(player, pet.id)

	if Pets.AnnounceRarities[pet.rarity] then
		local rarity = Pets.rarityById[pet.rarity]
		for _, other in Players:GetPlayers() do
			notify(other, `{player.Name} found a {rarity.name} {pet.name}!`)
		end
	end
	return nil
end

-- Admin testing: gives a player a pet without a spin. Returns false if their
-- data hasn't loaded or their pets are full.
function PetShopService:Give(player: Player, petId: string): boolean
	local pet = Pets.byId[petId]
	return pet ~= nil and addPet(player, pet)
end

-- Admin testing: rolls this many spins (without giving anything) and compares
-- how often each rarity came up with Config/Pets.
function PetShopService:TestOdds(rolls: number): string
	local counts: { [string]: number } = {}
	for _ = 1, rolls do
		local pet = PetMath.spin(random:NextNumber(), random:NextNumber())
		counts[pet.rarity] = (counts[pet.rarity] or 0) + 1
	end
	local total = 0
	for _, rarity in Pets.rarities do
		total += rarity.weight
	end
	local lines = { `{rolls} spins (got / expected):` }
	for _, rarity in Pets.rarities do
		local got = (counts[rarity.id] or 0) / rolls * 100
		table.insert(lines, string.format("%s %.2f%% / %.2f%%", rarity.name, got, rarity.weight / total * 100))
	end
	return table.concat(lines, "\n")
end

-- Problems found with the hand-built shop, for the debug panel.
function PetShopService:GetProblems(): { string }
	return problems
end

function PetShopService:Init()
	local map = workspace:FindFirstChild("Map")
	local shops = map and map:FindFirstChild("Shops")
	local shop = shops and shops:FindFirstChild("PetShop")
	local prompt = shop and shop:FindFirstChild("ShopPrompt")
	if prompt and prompt:IsA("BasePart") then
		shopPrompt = prompt
	else
		table.insert(problems, "Workspace.Map.Shops.PetShop.ShopPrompt is missing or isn't a part")
	end
	for _, problem in problems do
		warn(`[PetShopService] {problem}. Build it in Studio (see "Map naming" in docs/design.md).`)
	end
end

function PetShopService:Start()
	Remotes.SpinPet.OnServerEvent:Connect(function(player: Player)
		if spinLimiter:allow(player) then
			local problem = spin(player)
			if problem then
				notify(player, problem)
			end
		end
	end)
end

return PetShopService
