--!strict
-- Plots on this player's base get a prompt: "Place" while carrying a company
-- and the plot is free and unlocked, "Pick up" while empty-handed and the plot
-- has a company. The server sets the plot attributes this reads (PlotKey,
-- Unlocked, CompanyId) and checks every request again.
--
-- Every placed company, on any base, gets a label with its name, tier and
-- income per second, which follows the server's Income attribute (it changes
-- when pets are placed on that floor).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.Shared.Config.Base)
local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CompanyLabel = require(script.Parent.Parent.Ui.CompanyLabel)

local player = Players.LocalPlayer
local refreshers: { [BasePart]: () -> () } = {}

local PlotController = {}

local function companyName(companyId: unknown): string
	local company = if typeof(companyId) == "string" then Companies.byId[companyId] else nil
	return if company then company.name else ""
end

local function setUpPlot(part: Instance)
	if not part:IsA("BasePart") or refreshers[part] then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = BaseConfig.PlotDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = part

	local action: "place" | "pickUp" | nil = nil

	local function refresh()
		local carrying = player:GetAttribute("CarryingCompanyId")
		local placed = part:GetAttribute("CompanyId")
		local unlocked = part:GetAttribute("Unlocked") == true

		if carrying ~= nil and placed == nil and unlocked then
			action = "place"
			prompt.ActionText = "Place"
			prompt.ObjectText = companyName(carrying)
		elseif carrying == nil and placed ~= nil then
			action = "pickUp"
			prompt.ActionText = "Pick up"
			prompt.ObjectText = companyName(placed)
		else
			action = nil
		end
		prompt.Enabled = action ~= nil
	end

	prompt.Triggered:Connect(function()
		local plotKey = part:GetAttribute("PlotKey")
		if typeof(plotKey) ~= "string" then
			return
		end
		if action == "place" then
			Remotes.PlaceOnPlot:FireServer(plotKey)
		elseif action == "pickUp" then
			Remotes.PickUpFromPlot:FireServer(plotKey)
		end
	end)

	part.AttributeChanged:Connect(refresh)
	part.Destroying:Connect(function()
		refreshers[part] = nil
	end)
	refreshers[part] = refresh
	refresh()
end

local function watchPlotsFolder(plots: Instance)
	plots.ChildAdded:Connect(setUpPlot)
	for _, part in plots:GetChildren() do
		setUpPlot(part)
	end
end

-- Plot parts stream in and out with distance, so watch the folders (which
-- always exist) rather than the parts.
local function watchBase(baseName: string)
	local base = workspace:WaitForChild("Map"):WaitForChild("Bases"):WaitForChild(baseName)
	local floors = base:WaitForChild("Floors")

	local function watchFloor(floor: Instance)
		local plots = floor:FindFirstChild("Plots")
		if plots then
			watchPlotsFolder(plots)
		else
			floor.ChildAdded:Connect(function(child)
				if child.Name == "Plots" then
					watchPlotsFolder(child)
				end
			end)
		end
	end

	floors.ChildAdded:Connect(watchFloor)
	for _, floor in floors:GetChildren() do
		watchFloor(floor)
	end
end

local function labelPlaced(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local companyId = model:GetAttribute("CompanyId")
	local tierId = model:GetAttribute("Tier")
	local income = model:GetAttribute("Income")
	if typeof(companyId) == "string" and typeof(tierId) == "string" and typeof(income) == "number" then
		local detail = CompanyLabel.detail(CompanyLabel.attach(model, companyId, tierId, Format.income(income)))
		model:GetAttributeChangedSignal("Income"):Connect(function()
			local newIncome = model:GetAttribute("Income")
			if detail and typeof(newIncome) == "number" then
				detail.Text = Format.income(newIncome)
			end
		end)
	end
end

function PlotController:Start()
	player:GetAttributeChangedSignal("CarryingCompanyId"):Connect(function()
		for _, refresh in refreshers do
			refresh()
		end
	end)

	local function onBaseName()
		local baseName = player:GetAttribute("BaseName")
		if typeof(baseName) == "string" then
			task.spawn(watchBase, baseName)
		end
	end
	player:GetAttributeChangedSignal("BaseName"):Connect(onBaseName)
	onBaseName()

	local placed = workspace:WaitForChild("PlacedCompanies")
	placed.ChildAdded:Connect(labelPlaced)
	for _, model in placed:GetChildren() do
		labelPlaced(model)
	end
end

return PlotController
