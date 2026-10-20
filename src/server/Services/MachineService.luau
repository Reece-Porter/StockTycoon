--!strict
-- The Valuation Machine at each base (CLAUDE.md, non-negotiable rules).
--
-- A player brings a company they are carrying to their own machine. It costs
-- nothing, and each company can go through only once, ever (hasBeenValued
-- travels with it, even when stolen). The server generates the whole path
-- (MachinePath) when the run starts and sends its parameters to the client to
-- draw. When the player presses Take the client sends only that; the server
-- works out the multiplier from its own clock. If they never press it, the
-- company gets the value when time runs out. The multiplier never goes below
-- 1.0x and a run never lasts more than 45 seconds. Nothing bought with Robux
-- touches any of this.
--
-- The run is saved (Data.Machine), so the company can't be lost; a save that
-- loads mid-run is settled as if time ran out. While in the machine a company
-- is on no plot, so it can't be stolen. Afterwards it goes back into the
-- player's hands, or to storage if their hands are full.
--
-- The run's parameters reach the client as JSON in the MachineRun attribute.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Format = require(ReplicatedStorage.Shared.Format)
local MachineConfig = require(ReplicatedStorage.Shared.Config.Machine)
local MachinePath = require(ReplicatedStorage.Shared.MachinePath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local AnalyticsService = require(script.Parent.AnalyticsService)
local AdminService = require(script.Parent.AdminService)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local CompanyModels = require(script.Parent.Parent.Lib.CompanyModels)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local random = Random.new()
local displays: { [Player]: Model } = {}
local displayFolder: Folder
local startLimiter = RateLimiter.new(2, 4)
local takeLimiter = RateLimiter.new(4, 6)

local MachineService = {}

local function companyName(company: Types.CompanyInstance): string
	local config = Companies.byId[company.companyId]
	return if config then config.name else company.companyId
end

local function paramsOf(run: Types.MachineRun): MachinePath.Params
	return { seed = run.seed, duration = run.duration, peak = run.peak, peakTime = run.peakTime }
end

local function clearDisplay(player: Player)
	local display = displays[player]
	if display then
		displays[player] = nil
		display:Destroy()
	end
end

-- Shows the company standing on the machine's pad while it is being valued.
local function showOnPad(player: Player, pad: BasePart, company: Types.CompanyInstance)
	clearDisplay(player)
	local model = CompanyModels.clone(company.companyId, true)
	if model == nil then
		return
	end
	CompanyModels.standOn(model, pad.Position + Vector3.new(0, pad.Size.Y / 2, 0), pad.CFrame)
	model.Name = `{player.Name}Machine`
	model:SetAttribute("CompanyId", company.companyId)
	model:SetAttribute("Tier", company.tier)
	model.Parent = displayFolder
	displays[player] = model
end

local function publish(player: Player, run: Types.MachineRun?)
	if run == nil then
		player:SetAttribute("MachineRun", nil)
		AdminService:SetDebugValue(player, "MachineRun", "none")
		return
	end
	player:SetAttribute(
		"MachineRun",
		HttpService:JSONEncode({
			seed = run.seed,
			duration = run.duration,
			peak = run.peak,
			peakTime = run.peakTime,
			startedAt = run.startedAt,
			companyId = run.company.companyId,
		})
	)
	AdminService:SetDebugValue(
		player,
		"MachineRun",
		`{run.duration}s, peak {run.peak}x at {run.peakTime}s, seed {run.seed}`
	)
end

-- Ends the player's run and gives the company its multiplier. With no
-- elapsed time given, it is valued as if time ran out. rejoined means the run
-- was left behind when the player last left.
local function settle(player: Player, elapsed: number?, rejoined: boolean?)
	local run = DataService:TakeMachineRun(player)
	if run == nil then
		return
	end
	clearDisplay(player)
	publish(player, nil)

	local timedOut = elapsed == nil or elapsed >= run.duration
	local at = if timedOut then run.duration else elapsed :: number
	local multiplier = MachinePath.lock(MachinePath.value(paramsOf(run), at))

	local company = run.company
	company.valuationMultiplier = multiplier
	company.hasBeenValued = true

	local where = ""
	if not CarryService:Carry(player, company) then
		DataService:AddToStorage(player, company, true)
		where = " It's in your storage."
	end

	local outcome = if rejoined then "Left" elseif timedOut then "RanOut" else "Taken"
	AnalyticsService:Event(player, "MachineResult", multiplier, { outcome, company.tier })
	Remotes.ValuationFinished:FireClient(player, multiplier, timedOut)
	Remotes.Notify:FireClient(
		player,
		`{companyName(company)} valued at {string.format("%.2f", multiplier)}x! `
			.. `It now earns {Format.income(company.baseIncome * multiplier)}.{where}`
	)
end

local function isNear(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local reach = MachineConfig.UseDistance + MachineConfig.UseDistanceTolerance
	return (root.Position - part.Position).Magnitude <= reach
end

-- Returns a message to show the player if the run couldn't start.
local function start(player: Player): string?
	local data = DataService:GetData(player)
	if data == nil then
		return "Your data hasn't loaded yet."
	end
	local base = BaseService:GetBase(player)
	local pad = base and base.machinePad
	if pad == nil then
		return "Your base doesn't have a Valuation Machine yet."
	end
	if data.Machine ~= nil then
		return "Your machine is already running."
	end
	if CarryService:GetStolen(player) then
		return "A stolen company has to go on a plot on your base first."
	end
	local carried = data.Carrying
	if carried == nil then
		return "Bring a company to the machine first."
	end
	if carried.hasBeenValued then
		return "That company has already been through the machine."
	end
	if not isNear(player, pad) then
		return "Get closer to the machine."
	end

	local company = CarryService:TakeCarried(player)
	if company == nil then
		return "Bring a company to the machine first."
	end
	local params = MachinePath.generate(function()
		return random:NextNumber()
	end)
	local run: Types.MachineRun = {
		company = company,
		seed = params.seed,
		duration = params.duration,
		peak = params.peak,
		peakTime = params.peakTime,
		-- Rounded to the millisecond so it reaches the client exactly.
		startedAt = math.round(workspace:GetServerTimeNow() * 1000) / 1000,
	}
	if not DataService:StartMachineRun(player, run) then
		CarryService:Carry(player, company)
		return "Your machine is already running."
	end

	showOnPad(player, pad, company)
	publish(player, run)
	AnalyticsService:Funnel(player, "UsedMachine")
	return nil
end

function MachineService:Init()
	displayFolder = Instance.new("Folder")
	displayFolder.Name = "MachineCompanies"
	displayFolder.Parent = workspace
end

function MachineService:Start()
	-- A save that loads mid-run was left by a previous session.
	DataService:OnDataLoaded(function(player)
		local data = DataService:GetData(player)
		if data and data.Machine then
			settle(player, nil, true)
		else
			publish(player, nil)
		end
	end)
	Players.PlayerRemoving:Connect(clearDisplay)

	Remotes.StartValuation.OnServerEvent:Connect(function(player: Player)
		if not startLimiter:allow(player) then
			return
		end
		local problem = start(player)
		if problem then
			Remotes.Notify:FireClient(player, problem)
		end
	end)

	Remotes.TakeValuation.OnServerEvent:Connect(function(player: Player)
		if not takeLimiter:allow(player) then
			return
		end
		local data = DataService:GetData(player)
		local run = data and data.Machine
		if run then
			settle(player, workspace:GetServerTimeNow() - run.startedAt)
		end
	end)

	-- Settle runs whose time has run out.
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, player in Players:GetPlayers() do
			local data = DataService:GetData(player)
			local run = data and data.Machine
			if run and now - run.startedAt >= run.duration then
				settle(player, nil)
			end
		end
	end)
end

return MachineService
