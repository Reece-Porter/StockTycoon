--!strict
-- Game passes and developer products (docs/design.md, "Monetisation";
-- Config/Monetisation). Players buy through Roblox's own purchase prompts,
-- which the store window opens; what they get is decided here.
--
-- Passes are looked up when a player joins and noted when they buy one in
-- the game, in Lib/Passes:
--   2x Income doubles their income (IncomeService).
--   Extra Pet Slot opens another pet slot on every floor (PetService).
--   VIP gives a gold tag in chat (the client) and gold trim on their base
--   (here).
-- Products are given in ProcessReceipt, exactly once per purchase: the
-- purchase id is saved along with what it gave (DataService:ProcessReceipt)
-- before Roblox is told it's done.
--   Cash packs give some of the player's income (RewardsService).
--   Lock Base Now locks their base from anywhere (StealService).
-- Nothing here touches the Valuation Machine.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetisation = require(ReplicatedStorage.Shared.Config.Monetisation)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StealConfig = require(ReplicatedStorage.Shared.Config.Steal)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local PetService = require(script.Parent.PetService)
local PlotService = require(script.Parent.PlotService)
local RewardsService = require(script.Parent.RewardsService)
local StealService = require(script.Parent.StealService)
local Passes = require(script.Parent.Parent.Lib.Passes)

-- Pass lookups that fail are tried again this often, this many times.
local RETRY_SECONDS = 10
local ATTEMPTS = 3
-- The colour a base part had before VIP trim.
local TRIM_ATTRIBUTE = "TrimColour"

local passesById: { [number]: Monetisation.Pass } = {}
local productsById: { [number]: Monetisation.Product } = {}
-- Admin testing: passes given or taken away this session, which win over
-- what Roblox says.
local overrides: { [Player]: { [string]: boolean } } = {}

local MonetisationService = {}

local function notify(player: Player, message: string)
	if player.Parent == Players then
		Remotes.Notify:FireClient(player, message)
	end
end

-- Gold trim on a VIP's base, and the base's own colour otherwise.
local function trimBase(base: BaseService.Base, vip: boolean)
	local tidy = base.model:FindFirstChild("Tidy")
	if tidy == nil then
		return
	end
	for _, part in tidy:GetChildren() do
		if part:IsA("BasePart") and (part.Name == "Border" or part.Name == "Support") then
			local original = part:GetAttribute(TRIM_ATTRIBUTE)
			if typeof(original) ~= "Color3" then
				original = part.Color
				part:SetAttribute(TRIM_ATTRIBUTE, original)
			end
			part.Color = if vip then Monetisation.VipColour else original :: Color3
		end
	end
end

local function applyPass(player: Player, pass: Passes.PassName)
	if pass == "DoubleIncome" then
		IncomeService:Refresh(player)
		PlotService:Refresh(player)
	elseif pass == "ExtraPetSlot" then
		PetService:Refresh(player)
	elseif pass == "VIP" then
		local base = BaseService:GetBase(player)
		if base then
			trimBase(base, Passes.owns(player, "VIP"))
		end
	end
end

-- Looks up every pass with an id, trying failed lookups again a few times.
-- Only once every lookup has worked does not having a pass count as certain.
local function checkPasses(player: Player)
	local pending: { Monetisation.Pass } = {}
	for _, pass in Monetisation.Passes do
		if pass.id ~= 0 then
			table.insert(pending, pass)
		end
	end
	for attempt = 1, ATTEMPTS do
		local failed = {}
		for _, pass in pending do
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if player.Parent ~= Players then
				return
			end
			if ok then
				local override = (overrides[player] or {})[pass.name]
				Passes.set(player, pass.name, if override ~= nil then override else owns == true)
			else
				table.insert(failed, pass)
			end
		end
		pending = failed
		if #pending == 0 then
			Passes.markChecked(player)
			-- A pet in a slot that needs a pass they don't have goes back.
			PetService:Refresh(player)
			return
		end
		if attempt < ATTEMPTS then
			task.wait(RETRY_SECONDS)
		end
	end
	warn(`[MonetisationService] Couldn't check {player.Name}'s game passes; trying again when they rejoin.`)
end

-- Gives a product. Returns whether it worked.
local function grantProduct(player: Player, product: Monetisation.Product): boolean
	if product.kind == "Cash" then
		local grant = product.grant
		if grant == nil then
			return false
		end
		notify(player, `Thanks! {product.title}: {RewardsService:Grant(player, { grant }, "CashPack")}`)
		return true
	elseif product.kind == "Lock" then
		if not StealService:LockFromAnywhere(player) then
			return false
		end
		notify(player, `Thanks! Your base is locked for another {StealConfig.LockSeconds} seconds.`)
		return true
	end
	return false
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local product = productsById[receipt.ProductId]
	if player == nil or product == nil or typeof(receipt.PurchaseId) ~= "string" then
		if product == nil then
			warn(`[MonetisationService] No product in Config/Monetisation has id {receipt.ProductId}.`)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local done = DataService:ProcessReceipt(player, receipt.PurchaseId, function()
		return grantProduct(player, product)
	end)
	return if done then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Admin testing: gives or takes away a pass for this session.
function MonetisationService:SetPass(player: Player, passName: Passes.PassName, owns: boolean)
	local playerOverrides = overrides[player] or {}
	overrides[player] = playerOverrides
	playerOverrides[passName] = owns
	Passes.set(player, passName, owns)
end

-- Admin testing: gives a product the same way a real purchase does, with a
-- made-up purchase id. Returns whether it was given and saved.
function MonetisationService:TestProduct(player: Player, key: string): boolean
	for _, product in Monetisation.Products do
		if product.key == key then
			return DataService:ProcessReceipt(player, `test-{HttpService:GenerateGUID(false)}`, function()
				return grantProduct(player, product)
			end)
		end
	end
	return false
end

function MonetisationService:Init()
	for _, pass in Monetisation.Passes do
		if pass.id ~= 0 then
			passesById[pass.id] = pass
		end
	end
	for _, product in Monetisation.Products do
		if product.id ~= 0 then
			productsById[product.id] = product
		end
	end
end

function MonetisationService:Start()
	Passes.onChanged(applyPass)
	BaseService:OnBaseAssigned(function(player, base)
		trimBase(base, Passes.owns(player, "VIP"))
	end)
	BaseService:OnBaseFreed(function(_player, base)
		trimBase(base, false)
	end)

	Players.PlayerAdded:Connect(checkPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPasses, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		Passes.forget(player)
		overrides[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, wasPurchased: boolean)
			local pass = passesById[passId]
			if wasPurchased and pass then
				Passes.set(player, pass.name, true)
				notify(player, `Thanks for buying {pass.title}!`)
			end
		end
	)
	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetisationService
