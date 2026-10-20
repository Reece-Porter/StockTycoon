--!strict
-- "Steal" prompts on companies placed on other players' bases. Holding the
-- prompt tells the server when the hold started and when it finished; the
-- server times it and decides. The prompt is hidden while the base is locked,
-- its owner is protected as a new player, this player's hands are full, or this
-- player has too many rebirths to steal from an owner who has none.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StealConfig = require(ReplicatedStorage.Shared.Config.Steal)

-- Locks and protection run out on their own, so prompts are rechecked this often.
local REFRESH_SECONDS = 1

local player = Players.LocalPlayer
local refreshers: { [BasePart]: () -> () } = {}

local StealController = {}

local function isFuture(value: unknown): boolean
	return typeof(value) == "number" and value > workspace:GetServerTimeNow()
end

local function rebirthsOf(someone: Player?): number
	local value = someone and someone:GetAttribute("Rebirths")
	return if typeof(value) == "number" then value else 0
end

-- Players with Config/Steal.VeteranRebirths or more can't steal from players
-- who have never rebirthed.
local function isVeteranBlocked(ownerUserId: number): boolean
	local owner = Players:GetPlayerByUserId(ownerUserId)
	return rebirthsOf(player) >= StealConfig.VeteranRebirths and rebirthsOf(owner) == 0
end

local function setUpPlot(base: Instance, part: Instance)
	if not part:IsA("BasePart") or refreshers[part] then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.HoldDuration = StealConfig.HoldSeconds
	prompt.MaxActivationDistance = StealConfig.StealDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = part

	local function refresh()
		local owner = base:GetAttribute("OwnerUserId")
		local companyId = part:GetAttribute("CompanyId")
		local company = if typeof(companyId) == "string" then Companies.byId[companyId] else nil
		prompt.ObjectText = if company then company.name else ""
		-- Guard pets on the floor make the hold longer.
		local holdSeconds = part:GetAttribute("HoldSeconds")
		prompt.HoldDuration = if typeof(holdSeconds) == "number" then holdSeconds else StealConfig.HoldSeconds
		prompt.Enabled = company ~= nil
			and typeof(owner) == "number"
			and owner ~= player.UserId
			and not isVeteranBlocked(owner)
			and player:GetAttribute("CarryingCompanyId") == nil
			and not isFuture(base:GetAttribute("LockedUntil"))
			and not isFuture(base:GetAttribute("ProtectedUntil"))
	end

	local function key(): string?
		local plotKey = part:GetAttribute("PlotKey")
		return if typeof(plotKey) == "string" then plotKey else nil
	end
	prompt.PromptButtonHoldBegan:Connect(function()
		local plotKey = key()
		if plotKey then
			Remotes.StealBegin:FireServer(base.Name, plotKey)
		end
	end)
	prompt.Triggered:Connect(function()
		local plotKey = key()
		if plotKey then
			Remotes.StealFinish:FireServer(base.Name, plotKey)
		end
	end)

	part.AttributeChanged:Connect(refresh)
	base.AttributeChanged:Connect(refresh)
	part.Destroying:Connect(function()
		refreshers[part] = nil
	end)
	refreshers[part] = refresh
	refresh()
end

-- Plot parts stream in and out with distance, so watch the folders.
local function watchBase(base: Instance)
	local floors = base:WaitForChild("Floors", 30)
	if floors == nil then
		return
	end
	local function watchFloor(floor: Instance)
		local function watchPlots(plots: Instance)
			plots.ChildAdded:Connect(function(part)
				setUpPlot(base, part)
			end)
			for _, part in plots:GetChildren() do
				setUpPlot(base, part)
			end
		end
		local plots = floor:FindFirstChild("Plots")
		if plots then
			watchPlots(plots)
		else
			floor.ChildAdded:Connect(function(child)
				if child.Name == "Plots" then
					watchPlots(child)
				end
			end)
		end
	end
	floors.ChildAdded:Connect(watchFloor)
	for _, floor in floors:GetChildren() do
		watchFloor(floor)
	end
end

function StealController:Start()
	local bases = workspace:WaitForChild("Map"):WaitForChild("Bases")
	bases.ChildAdded:Connect(function(base)
		task.spawn(watchBase, base)
	end)
	for _, base in bases:GetChildren() do
		task.spawn(watchBase, base)
	end

	player:GetAttributeChangedSignal("CarryingCompanyId"):Connect(function()
		for _, refresh in refreshers do
			refresh()
		end
	end)

	while true do
		task.wait(REFRESH_SECONDS)
		for _, refresh in refreshers do
			refresh()
		end
	end
end

return StealController
