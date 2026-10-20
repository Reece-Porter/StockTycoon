--!strict
-- Buying companies off conveyors. The client only says which item it wants;
-- the server checks everything else: who may buy it, distance, Cash and that
-- the buyer's hands are free. A bought company goes into their hands to carry
-- home. Nothing between the checks and the purchase yields, so the first valid
-- request for an item wins and any later one finds it gone.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local ConveyorConfig = require(ReplicatedStorage.Shared.Config.Conveyor)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CarryService = require(script.Parent.CarryService)
local ConveyorService = require(script.Parent.ConveyorService)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local MAX_ITEM_ID_LENGTH = 64

local buyLimiter = RateLimiter.new(4, 6)

local PurchaseService = {}

local function newCompanyInstance(player: Player, item: ConveyorService.Item): Types.CompanyInstance
	return {
		instanceId = HttpService:GenerateGUID(false),
		companyId = item.companyId,
		tier = item.tier,
		baseIncome = item.income,
		purchasePrice = item.price,
		valuationMultiplier = 1,
		hasBeenValued = false,
		ownerUserId = player.UserId,
	}
end

local function isInRange(player: Player, item: ConveyorService.Item): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local distance = (root.Position - ConveyorService:GetItemPosition(item)).Magnitude
	return distance <= ConveyorConfig.BuyDistance + ConveyorConfig.BuyDistanceTolerance
end

-- Returns the message to show the player.
local function buy(player: Player, itemId: string): string
	local item = ConveyorService:GetItem(itemId)
	if item == nil then
		return "Too slow! That company is gone."
	end
	if item.ownerUserId ~= 0 and item.ownerUserId ~= player.UserId then
		return "That's not your conveyor."
	end
	if not isInRange(player, item) then
		return "Get closer to buy that."
	end
	if CarryService:IsCarrying(player) then
		return "Your hands are full. Place or store what you're carrying first."
	end

	local data = DataService:GetData(player)
	if data == nil then
		return "Your data hasn't loaded yet."
	end
	if data.Cash < item.price then
		return `You need {Format.cash(item.price)} to buy that.`
	end

	if not DataService:SpendCash(player, item.price) then
		return `You need {Format.cash(item.price)} to buy that.`
	end
	if not CarryService:Carry(player, newCompanyInstance(player, item)) then
		DataService:AddCash(player, item.price)
		return "Your hands are full. Place or store what you're carrying first."
	end
	ConveyorService:RemoveItem(item.id)

	return `Bought {Companies.byId[item.companyId].name} for {Format.cash(item.price)}! Take it to a plot.`
end

function PurchaseService:Start()
	Remotes.BuyConveyorItem.OnServerEvent:Connect(function(player: Player, itemId: unknown)
		if not buyLimiter:allow(player) then
			return
		end
		if typeof(itemId) ~= "string" or #itemId > MAX_ITEM_ID_LENGTH then
			return
		end
		Remotes.Notify:FireClient(player, buy(player, itemId))
	end)
end

return PurchaseService
