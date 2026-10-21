--!strict
-- The guide for new players (docs/design.md, "Onboarding"; Config/Onboarding).
-- Each step finishes when the player's save or position shows they've done
-- it, however they did it:
--   Buy: they own a company.
--   Place: a company is on one of their plots.
--   Collect: they've collected Cash from one of their cash pads this session.
--   Machine: a company has been through (or is in) the Valuation Machine, or
--     they've placed Config/Onboarding.MachineSkipAfterPlaced without trying.
--   Lock: their base is locked.
--   Middle: once they've played ExploreAfterSeconds this session, they go near
--     the middle conveyor (or ExploreStepSeconds pass).
-- The step is saved (TutorialStep), so the guide picks up where it left off.
-- Players see it through the TutorialStep and TutorialShowAt (server time the
-- current hint appears) attributes, and can skip it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseService = require(script.Parent.BaseService)
local CollectService = require(script.Parent.CollectService)
local DataService = require(script.Parent.DataService)
local StealService = require(script.Parent.StealService)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local Steps = Onboarding.Steps
local CHECK_SECONDS = 1

-- os.clock() when each player's save loaded, and when their current step began.
local joinedAt: { [Player]: number } = {}
local stepStartedAt: { [Player]: number } = {}
-- The step each player was last shown.
local publishedStep: { [Player]: number } = {}
-- Players who have collected from a cash pad this session.
local collected: { [Player]: true } = {}
local skipLimiter = RateLimiter.new(1, 2)

local TutorialService = {}

local function placedCount(data: DataService.Data): number
	local count = 0
	for _ in data.Placed do
		count += 1
	end
	return count
end

local function ownsAny(data: DataService.Data): boolean
	return #data.Storage > 0 or next(data.Placed) ~= nil or data.Carrying ~= nil or data.Machine ~= nil
end

local function triedMachine(data: DataService.Data): boolean
	if data.Machine then
		return true
	end
	for _, company in data.Placed do
		if company.hasBeenValued then
			return true
		end
	end
	for _, company in data.Storage do
		if company.hasBeenValued then
			return true
		end
	end
	return data.Carrying ~= nil and data.Carrying.hasBeenValued
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function mapPart(path: { string }): BasePart?
	local current: Instance? = workspace:FindFirstChild("Map")
	for _, name in path do
		current = current and current:FindFirstChild(name)
	end
	return if current and current:IsA("BasePart") then current else nil
end

-- Whether the player is near the middle conveyor (anywhere along it).
local function nearMiddle(position: Vector3): boolean
	local startPart = mapPart({ "SharedConveyor", "Start" })
	local endPart = mapPart({ "SharedConveyor", "End" })
	if startPart == nil or endPart == nil then
		return true
	end
	local a, b = startPart.Position, endPart.Position
	local along = b - a
	local t = math.clamp((position - a):Dot(along) / along:Dot(along), 0, 1)
	return (position - (a + along * t)).Magnitude <= Onboarding.VisitDistance
end

-- Whether the player has locked their base. A base without a lock button has
-- nothing to teach, so that counts too.
local function lockedBase(player: Player): boolean
	local base = BaseService:GetBase(player)
	if base == nil then
		return false
	end
	return #base.lockButtons == 0 or StealService:IsBaseLocked(player)
end

local function publish(player: Player)
	local data = DataService:GetData(player)
	local joined = joinedAt[player]
	if data == nil or joined == nil or player.Parent ~= Players then
		return
	end
	publishedStep[player] = data.TutorialStep
	player:SetAttribute("TutorialStep", data.TutorialStep)
	-- The middle conveyor hint waits until they've played a little.
	local showIn = if data.TutorialStep == Steps.Middle
		then math.max(0, Onboarding.ExploreAfterSeconds - (os.clock() - joined))
		else 0
	player:SetAttribute("TutorialShowAt", workspace:GetServerTimeNow() + showIn)
end

local function setStep(player: Player, step: number)
	-- Before saving it: saving runs check again, which must see the new step's
	-- start time.
	stepStartedAt[player] = os.clock()
	DataService:SetTutorialStep(player, step)
	publish(player)
end

-- Moves the guide on as far as the player has got.
local function check(player: Player)
	local data = DataService:GetData(player)
	local joined = joinedAt[player]
	if data == nil or joined == nil then
		return
	end
	local step = data.TutorialStep
	-- The step changed some other way (an admin's /resetdata), so show it
	-- from now.
	if publishedStep[player] ~= step then
		stepStartedAt[player] = os.clock()
		publish(player)
	end
	if step >= Steps.Done then
		return
	end
	local now = os.clock()
	local position = rootPosition(player)
	if step == Steps.Buy and ownsAny(data) then
		setStep(player, Steps.Place)
	elseif step == Steps.Place and placedCount(data) > 0 then
		setStep(player, Steps.Collect)
	elseif step == Steps.Collect then
		if collected[player] then
			setStep(player, Steps.Machine)
		end
	elseif step == Steps.Machine then
		if triedMachine(data) or placedCount(data) >= Onboarding.MachineSkipAfterPlaced then
			setStep(player, Steps.Lock)
		end
	elseif step == Steps.Lock then
		if lockedBase(player) then
			setStep(player, Steps.Middle)
		end
	elseif step == Steps.Middle then
		local showsAt = joined + Onboarding.ExploreAfterSeconds
		local shownFor = now - math.max(showsAt, stepStartedAt[player] or now)
		if now >= showsAt and ((position and nearMiddle(position)) or shownFor >= Onboarding.ExploreStepSeconds) then
			setStep(player, Steps.Done)
		end
	end
end

function TutorialService:Start()
	DataService:OnDataLoaded(function(player)
		joinedAt[player] = os.clock()
		stepStartedAt[player] = os.clock()
		publish(player)
		check(player)
	end)
	DataService:OnDataChanged(check)
	CollectService:OnCollected(function(player)
		collected[player] = true
		check(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		joinedAt[player] = nil
		stepStartedAt[player] = nil
		publishedStep[player] = nil
		collected[player] = nil
	end)

	Remotes.SkipTutorial.OnServerEvent:Connect(function(player: Player)
		if skipLimiter:allow(player) and joinedAt[player] then
			setStep(player, Steps.Done)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for player in joinedAt do
				check(player)
			end
		end
	end)
end

return TutorialService
