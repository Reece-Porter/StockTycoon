--!strict
-- Placing companies on plots and picking them up again. Shows each placed
-- company standing on its plot, greys out plots (and their cash pads) the
-- owner hasn't unlocked (Data.UnlockedPlots, raised by UpgradeService), and
-- shows only the floors the owner has opened (BaseService:ShowFloors).
--
-- Plot state reaches clients through attributes on the plot parts: PlotKey,
-- Unlocked and HoldSeconds (how long a thief must hold to steal from it, with
-- the floor's guard pets), plus CompanyId and InstanceId while a company is
-- placed. The models shown on plots live in Workspace.PlacedCompanies with the
-- same details as attributes, including Income: its income per second with
-- the floor's pets and every other multiplier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.Shared.Config.Base)
local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local IncomeMath = require(ReplicatedStorage.Shared.IncomeMath)
local PetMath = require(ReplicatedStorage.Shared.PetMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StealConfig = require(ReplicatedStorage.Shared.Config.Steal)
local Types = require(ReplicatedStorage.Shared.Types)
local UpgradeMath = require(ReplicatedStorage.Shared.UpgradeMath)
local AnalyticsService = require(script.Parent.AnalyticsService)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local CompanyModels = require(script.Parent.Parent.Lib.CompanyModels)
local LockedLook = require(script.Parent.Parent.Lib.LockedLook)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local MAX_PLOT_KEY_LENGTH = 32

local placedFolder: Folder
local stolenPlaceHandler: ((thief: Player, plot: BaseService.Plot) -> string)? = nil
local displays: { [BasePart]: Model } = {}
local placeLimiter = RateLimiter.new(4, 6)
local pickUpLimiter = RateLimiter.new(4, 6)

local PlotService = {}

local function companyName(company: Types.CompanyInstance): string
	local config = Companies.byId[company.companyId]
	return if config then config.name else company.companyId
end

local function isUnlocked(plot: BaseService.Plot, data: DataService.Data): boolean
	return UpgradeMath.isUnlocked(data.UnlockedPlots, plot.floor, plot.index)
end

local function clearPlot(plot: BaseService.Plot)
	local display = displays[plot.part]
	if display then
		displays[plot.part] = nil
		display:Destroy()
	end
	plot.part:SetAttribute("CompanyId", nil)
	plot.part:SetAttribute("InstanceId", nil)
end

local function showOnPlot(
	base: BaseService.Base,
	plot: BaseService.Plot,
	company: Types.CompanyInstance,
	income: number
)
	local current = displays[plot.part]
	if current and current:GetAttribute("InstanceId") == company.instanceId then
		current:SetAttribute("Income", income)
		return
	end
	clearPlot(plot)

	local model = CompanyModels.clone(company.companyId, true, company.variant)
	if model == nil then
		return
	end
	local part = plot.part
	CompanyModels.standOn(model, part.Position + Vector3.new(0, part.Size.Y / 2, 0), part.CFrame)

	model.Name = `{base.name}/{plot.key}`
	model:SetAttribute("InstanceId", company.instanceId)
	model:SetAttribute("CompanyId", company.companyId)
	model:SetAttribute("Tier", company.tier)
	model:SetAttribute("Income", income)
	model:SetAttribute("OwnerUserId", company.ownerUserId)
	model:SetAttribute("BaseName", base.name)
	model:SetAttribute("PlotKey", plot.key)
	model.Parent = placedFolder

	displays[part] = model
	part:SetAttribute("CompanyId", company.companyId)
	part:SetAttribute("InstanceId", company.instanceId)
end

-- Brings a player's plots in line with their save.
local function sync(player: Player)
	local base = BaseService:GetBase(player)
	local data = DataService:GetData(player)
	if base == nil or data == nil then
		return
	end
	BaseService:ShowFloors(base, #data.UnlockedPlots)
	local multipliers = IncomeService:GetMultipliers(player)
	for _, plot in base.plots do
		local unlocked = isUnlocked(plot, data)
		LockedLook.set(plot.part, not unlocked)
		if plot.pad then
			LockedLook.set(plot.pad, not unlocked)
		end
		plot.part:SetAttribute("PlotKey", plot.key)
		plot.part:SetAttribute("Unlocked", unlocked)
		plot.part:SetAttribute("HoldSeconds", StealConfig.HoldSeconds + PetMath.guardSeconds(data.Pets, plot.floor))

		-- A company being stolen is in the thief's hands, not on the plot.
		local company = data.Placed[plot.key]
		if company and not CarryService:IsPlotBeingStolen(player, plot.key) then
			showOnPlot(base, plot, company, IncomeMath.company(company, plot.floor, multipliers))
		else
			clearPlot(plot)
		end
	end
end

local function resetBase(base: BaseService.Base)
	BaseService:ShowFloors(base, 1)
	for _, plot in base.plots do
		clearPlot(plot)
		LockedLook.set(plot.part, false)
		if plot.pad then
			LockedLook.set(plot.pad, false)
		end
		plot.part:SetAttribute("Unlocked", nil)
		plot.part:SetAttribute("HoldSeconds", nil)
	end
end

local function isNear(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - part.Position).Magnitude <= BaseConfig.PlotDistance + BaseConfig.PlotDistanceTolerance
end

local function findOwnPlot(player: Player, plotKey: string): BaseService.Plot?
	local base = BaseService:GetBase(player)
	return base and base.plotsByKey[plotKey]
end

local function place(player: Player, plotKey: string): string
	local plot = findOwnPlot(player, plotKey)
	local data = DataService:GetData(player)
	if plot == nil or data == nil then
		return "That plot isn't on your base."
	end
	if not CarryService:IsCarrying(player) then
		return "You're not carrying anything."
	end
	if not isUnlocked(plot, data) then
		return "That plot is locked."
	end
	if data.Placed[plot.key] ~= nil then
		return "That plot is taken."
	end
	if not isNear(player, plot.part) then
		return "Get closer to that plot."
	end

	-- Placing a stolen company on your own plot completes the steal.
	if CarryService:GetStolen(player) then
		return if stolenPlaceHandler then stolenPlaceHandler(player, plot) else "You can't place that here."
	end

	local company = CarryService:TakeCarried(player)
	if company == nil then
		return "You're not carrying anything."
	end
	if not DataService:PlaceOnPlot(player, plot.key, company) then
		CarryService:Carry(player, company)
		return "That plot is taken."
	end
	sync(player)
	AnalyticsService:Funnel(player, "PlacedCompany")
	return `Placed {companyName(company)}.`
end

local function pickUp(player: Player, plotKey: string): string
	local plot = findOwnPlot(player, plotKey)
	if plot == nil then
		return "That plot isn't on your base."
	end
	if CarryService:IsCarrying(player) then
		return "Your hands are full. Place or store what you're carrying first."
	end
	if CarryService:IsPlotBeingStolen(player, plot.key) then
		return "Someone is stealing that! Tag them to get it back."
	end
	if not isNear(player, plot.part) then
		return "Get closer to that plot."
	end

	local company = DataService:TakeFromPlot(player, plot.key)
	if company == nil then
		return "There's nothing on that plot."
	end
	if not CarryService:Carry(player, company) then
		DataService:PlaceOnPlot(player, plot.key, company)
		return "Your hands are full."
	end
	sync(player)
	return `Picked up {companyName(company)}.`
end

local function validPlotKey(plotKey: unknown): boolean
	return typeof(plotKey) == "string" and #plotKey <= MAX_PLOT_KEY_LENGTH
end

-- Brings a player's plots in line with their save and any steals going on.
function PlotService:Refresh(player: Player)
	sync(player)
end

-- Sets what happens when a thief places a stolen company on one of their own
-- plots (the plot has been checked: theirs, unlocked, free and close by).
function PlotService:OnPlaceStolen(handler: (thief: Player, plot: BaseService.Plot) -> string)
	stolenPlaceHandler = handler
end

function PlotService:Init()
	placedFolder = Instance.new("Folder")
	placedFolder.Name = "PlacedCompanies"
	placedFolder.Parent = workspace
end

function PlotService:Start()
	DataService:OnDataLoaded(sync)
	DataService:OnDataChanged(sync)
	BaseService:OnBaseAssigned(function(player)
		sync(player)
	end)
	BaseService:OnBaseFreed(function(_player, base)
		resetBase(base)
	end)

	Remotes.PlaceOnPlot.OnServerEvent:Connect(function(player: Player, plotKey: unknown)
		if placeLimiter:allow(player) and validPlotKey(plotKey) then
			Remotes.Notify:FireClient(player, place(player, plotKey :: string))
		end
	end)

	Remotes.PickUpFromPlot.OnServerEvent:Connect(function(player: Player, plotKey: unknown)
		if pickUpLimiter:allow(player) and validPlotKey(plotKey) then
			Remotes.Notify:FireClient(player, pickUp(player, plotKey :: string))
		end
	end)
end

return PlotService
