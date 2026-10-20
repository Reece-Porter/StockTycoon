--!strict
-- Placing companies on plots and picking them up again. Shows each placed
-- company standing on its plot and greys out plots the owner hasn't unlocked.
--
-- Plot state reaches clients through attributes on the plot parts: PlotKey and
-- Unlocked, plus CompanyId and InstanceId while a company is placed. The models shown on
-- plots live in Workspace.PlacedCompanies with the same details as attributes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.Shared.Config.Base)
local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local CompanyModels = require(script.Parent.Parent.Lib.CompanyModels)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local MAX_PLOT_KEY_LENGTH = 32

local placedFolder: Folder
local displays: { [BasePart]: Model } = {}
local placeLimiter = RateLimiter.new(4, 6)
local pickUpLimiter = RateLimiter.new(4, 6)

local PlotService = {}

local function companyName(company: Types.CompanyInstance): string
	local config = Companies.byId[company.companyId]
	return if config then config.name else company.companyId
end

-- Until base upgrades exist, the first StartingPlots plots on Floor 1 are open.
local function isUnlocked(plot: BaseService.Plot): boolean
	return plot.floor == 1 and plot.index <= BaseConfig.StartingPlots
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

local function showOnPlot(base: BaseService.Base, plot: BaseService.Plot, company: Types.CompanyInstance)
	local current = displays[plot.part]
	if current and current:GetAttribute("InstanceId") == company.instanceId then
		return
	end
	clearPlot(plot)

	local model = CompanyModels.clone(company.companyId, true)
	if model == nil then
		return
	end
	local part = plot.part
	CompanyModels.standOn(model, part.Position + Vector3.new(0, part.Size.Y / 2, 0), part.CFrame)

	model.Name = `{base.name}/{plot.key}`
	model:SetAttribute("InstanceId", company.instanceId)
	model:SetAttribute("CompanyId", company.companyId)
	model:SetAttribute("Tier", company.tier)
	model:SetAttribute("Income", company.baseIncome * company.valuationMultiplier)
	model:SetAttribute("OwnerUserId", company.ownerUserId)
	model:SetAttribute("BaseName", base.name)
	model:SetAttribute("PlotKey", plot.key)
	model.Parent = placedFolder

	displays[part] = model
	part:SetAttribute("CompanyId", company.companyId)
	part:SetAttribute("InstanceId", company.instanceId)
end

local function setLocked(part: BasePart, locked: boolean)
	if locked then
		if part:GetAttribute("OriginalTransparency") == nil then
			part:SetAttribute("OriginalTransparency", part.Transparency)
		end
		part.Transparency = BaseConfig.LockedPlotTransparency
	else
		local original = part:GetAttribute("OriginalTransparency")
		if typeof(original) == "number" then
			part.Transparency = original
		end
		part:SetAttribute("OriginalTransparency", nil)
	end
end

-- Brings a player's plots in line with their save.
local function sync(player: Player)
	local base = BaseService:GetBase(player)
	local data = DataService:GetData(player)
	if base == nil or data == nil then
		return
	end
	for _, plot in base.plots do
		local unlocked = isUnlocked(plot)
		setLocked(plot.part, not unlocked)
		plot.part:SetAttribute("PlotKey", plot.key)
		plot.part:SetAttribute("Unlocked", unlocked)

		local company = data.Placed[plot.key]
		if company then
			showOnPlot(base, plot, company)
		else
			clearPlot(plot)
		end
	end
end

local function resetBase(base: BaseService.Base)
	for _, plot in base.plots do
		clearPlot(plot)
		setLocked(plot.part, false)
		plot.part:SetAttribute("Unlocked", nil)
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
	if not isUnlocked(plot) then
		return "That plot is locked."
	end
	if data.Placed[plot.key] ~= nil then
		return "That plot is taken."
	end
	if not isNear(player, plot.part) then
		return "Get closer to that plot."
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
