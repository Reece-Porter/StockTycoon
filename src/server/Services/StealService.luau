--!strict
-- Stealing and base locks (docs/design.md, "Stealing").
--
-- Any player can walk into someone else's base and hold the prompt on a placed
-- company to pick it up. The client reports when the hold starts (StealBegin)
-- and ends (StealFinish); the server times it itself and checks everything
-- else. While the thief carries it, the company stays in its owner's save
-- (CarryService holds it in memory only). The steal only completes when the
-- thief places it on a free plot on their own base: then it moves to the
-- thief's save, keeping its valuation, and both saves are written straight
-- away. If the owner gets close enough to tag the thief, or the thief resets
-- or leaves, or the owner leaves, it is simply back on its owner's plot.
--
-- A thief can also pick up a company knocked out of someone's hands
-- (DropService). If it came out of its owner's storage rather than off a plot,
-- the steal works the same way and it is back in their storage if it fails.
--
-- Owners lock their base from its LockButton for Config/Steal.LockSeconds.
-- While locked nobody else can steal from it, and anyone else inside is moved
-- out; when it runs out the owner presses the button again. New players can't
-- be stolen from for their first Config/Steal.NewPlayerProtectionSeconds, and
-- players with Config/Steal.VeteranRebirths or more can't steal from players
-- who have never rebirthed.
--
-- Companies in the Valuation Machine are on no plot, so they can't be taken.
--
-- Each base model gets LockedUntil and ProtectedUntil attributes (server
-- time) for the client's lock display.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Format = require(ReplicatedStorage.Shared.Format)
local PetMath = require(ReplicatedStorage.Shared.PetMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StealConfig = require(ReplicatedStorage.Shared.Config.Steal)
local Types = require(ReplicatedStorage.Shared.Types)
local AnalyticsService = require(script.Parent.AnalyticsService)
local BaseService = require(script.Parent.BaseService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local PlotService = require(script.Parent.PlotService)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local MAX_NAME_LENGTH = 32
-- How often to check tags and locked bases.
local CHECK_SECONDS = 0.1
-- How often a player being moved out of a locked base is told why.
local LOCK_NOTICE_SECONDS = 3

type Attempt = { baseName: string, plotKey: string, startedAt: number }

local attempts: { [Player]: Attempt } = {}
local lockedUntil: { [BaseService.Base]: number } = {}
local highlights: { [BaseService.Base]: Highlight } = {}
local protectedUntil: { [Player]: number } = {}
local lastLockNotice: { [Player]: number } = {}
local beginLimiter = RateLimiter.new(4, 6)
local finishLimiter = RateLimiter.new(4, 6)
local lockLimiter = RateLimiter.new(1, 3)

local StealService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function notify(player: Player, message: string)
	if player.Parent == Players then
		Remotes.Notify:FireClient(player, message)
	end
end

local function companyName(company: Types.CompanyInstance): string
	local config = Companies.byId[company.companyId]
	return if config then config.name else company.companyId
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function isWithin(player: Player, part: BasePart, reach: number): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= reach
end

local function findBase(baseName: string): BaseService.Base?
	for _, base in BaseService:GetBases() do
		if base.name == baseName then
			return base
		end
	end
	return nil
end

local function isLocked(base: BaseService.Base): boolean
	return (lockedUntil[base] or 0) > now()
end

local function protectionLeft(owner: Player): number
	return math.max(0, (protectedUntil[owner] or 0) - now())
end

-- The owner's plots and income no longer count a company being stolen, or
-- count it again once it's back.
local function refreshOwner(owner: Player)
	if owner.Parent == Players then
		PlotService:Refresh(owner)
		IncomeService:Refresh(owner)
	end
end

local function publishProtection(player: Player)
	local base = BaseService:GetBase(player)
	if base then
		local untilTime = protectedUntil[player]
		base.model:SetAttribute("ProtectedUntil", if untilTime and untilTime > now() then untilTime else nil)
	end
end

local function setLock(base: BaseService.Base, untilTime: number?)
	if untilTime then
		lockedUntil[base] = untilTime
	else
		lockedUntil[base] = nil
	end
	base.model:SetAttribute("LockedUntil", untilTime)

	local highlight: Highlight? = highlights[base]
	if untilTime and highlight == nil then
		local newHighlight = Instance.new("Highlight")
		newHighlight.Name = "LockHighlight"
		newHighlight.FillColor = Color3.fromRGB(255, 70, 70)
		newHighlight.FillTransparency = 0.85
		newHighlight.OutlineColor = Color3.fromRGB(255, 70, 70)
		newHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
		newHighlight.Adornee = base.model
		newHighlight.Parent = base.model
		highlights[base] = newHighlight
	elseif untilTime == nil and highlight then
		highlights[base] = nil
		highlight:Destroy()
	end
end

-- Moves a character just outside a base, past whichever edge is nearest.
local function pushOut(player: Player, base: BaseService.Base)
	local root = rootOf(player)
	local character = player.Character
	if root == nil or character == nil then
		return
	end
	local half = base.boxSize / 2
	local offset = base.boxCFrame:PointToObjectSpace(root.Position)
	local toSideX = half.X - math.abs(offset.X)
	local toSideZ = half.Z - math.abs(offset.Z)
	local margin = StealConfig.LockPushMargin
	local x = if toSideX <= toSideZ then math.sign(offset.X) * (half.X + margin) else offset.X
	local z = if toSideX > toSideZ then math.sign(offset.Z) * (half.Z + margin) else offset.Z
	local outside = base.boxCFrame:PointToWorldSpace(Vector3.new(x, -half.Y + 3, z))
	character:PivotTo(CFrame.new(outside) * root.CFrame.Rotation)

	local last = lastLockNotice[player] or 0
	if now() - last >= LOCK_NOTICE_SECONDS then
		lastLockNotice[player] = now()
		local owner = base.owner
		notify(player, `{if owner then owner.Name else "That"}'s base is locked.`)
	end
end

-- Returns the message for the thief.
local function finish(thief: Player, baseName: string, plotKey: string): string?
	local attempt = attempts[thief]
	attempts[thief] = nil

	local base = findBase(baseName)
	local owner = base and base.owner
	if base == nil or owner == nil then
		return "There's nothing there to take."
	end
	if owner == thief then
		return nil
	end
	local plot = base.plotsByKey[plotKey]
	local ownerData = DataService:GetData(owner)
	local company = if plot and ownerData then ownerData.Placed[plot.key] else nil
	if plot == nil or ownerData == nil or company == nil or CarryService:IsPlotBeingStolen(owner, plot.key) then
		return "There's nothing there to take."
	end

	local heldFor = if attempt
			and attempt.baseName == baseName
			and attempt.plotKey == plotKey
		then now() - attempt.startedAt
		else 0
	-- Guard pets on the plot's floor make the hold longer.
	local holdSeconds = StealConfig.HoldSeconds + PetMath.guardSeconds(ownerData.Pets, plot.floor)
	if heldFor < holdSeconds - StealConfig.HoldTolerance then
		return "Hold the button to take it."
	end
	if isLocked(base) then
		return `{owner.Name}'s base is locked.`
	end
	local blocked = StealService:GetBlockReason(thief, owner)
	if blocked then
		return blocked
	end
	if BaseService:GetBase(thief) == nil then
		return "You need a base to take it to."
	end
	if CarryService:IsCarrying(thief) then
		return "Your hands are full."
	end
	if not isWithin(thief, plot.part, StealConfig.StealDistance + StealConfig.StealDistanceTolerance) then
		return "Get closer to take it."
	end

	if not CarryService:CarryStolen(thief, { company = company, owner = owner, plotKey = plot.key }) then
		return "Your hands are full."
	end
	refreshOwner(owner)
	AnalyticsService:Event(thief, "StealStarted", 1, { "Plot", company.tier })
	notify(owner, `{thief.Name} is stealing your {companyName(company)}! Touch them to get it back.`)
	return `Got {companyName(company)}! Get it to a free plot on your base.`
end

-- Whether the company is still where it was in its owner's save.
local function isStillThere(entry: CarryService.Stolen): boolean
	local ownerData = DataService:GetData(entry.owner)
	if entry.owner.Parent ~= Players or ownerData == nil then
		return false
	end
	local plotKey = entry.plotKey
	if plotKey then
		local current = ownerData.Placed[plotKey]
		return current ~= nil and current.instanceId == entry.company.instanceId
	end
	for _, company in ownerData.Storage do
		if company.instanceId == entry.company.instanceId then
			return true
		end
	end
	return false
end

-- Takes the company out of its owner's save, or puts it back.
local function takeFromOwner(entry: CarryService.Stolen): Types.CompanyInstance?
	local plotKey = entry.plotKey
	if plotKey then
		return DataService:TakeFromPlot(entry.owner, plotKey)
	end
	return DataService:TakeFromStorage(entry.owner, entry.company.instanceId)
end

local function giveBackToOwner(entry: CarryService.Stolen, company: Types.CompanyInstance)
	local plotKey = entry.plotKey
	if plotKey == nil or not DataService:PlaceOnPlot(entry.owner, plotKey, company) then
		DataService:AddToStorage(entry.owner, company, true)
	end
end

-- Placing a stolen company on one of the thief's own plots (already checked by
-- PlotService) moves it to their save and completes the steal.
local function complete(thief: Player, plot: BaseService.Plot): string
	local entry = CarryService:GetStolen(thief)
	if entry == nil then
		return "You're not carrying anything."
	end
	local owner = entry.owner
	if not isStillThere(entry) then
		CarryService:TakeStolen(thief)
		refreshOwner(owner)
		return "That company isn't there to take any more."
	end

	local company = takeFromOwner(entry)
	CarryService:TakeStolen(thief)
	if company == nil then
		refreshOwner(owner)
		return "That company isn't there to take any more."
	end

	company.ownerUserId = thief.UserId
	if not DataService:PlaceOnPlot(thief, plot.key, company) then
		company.ownerUserId = owner.UserId
		giveBackToOwner(entry, company)
		refreshOwner(owner)
		return "That plot is taken."
	end

	-- Ownership changes from stealing are saved straight away.
	DataService:AddStat(thief, "Steals")
	AnalyticsService:Event(thief, "StealCompleted", 1, { company.tier })
	AnalyticsService:Funnel(thief, "FirstSteal")
	DataService:SaveNow(owner)
	DataService:SaveNow(thief)
	refreshOwner(owner)
	notify(owner, `{thief.Name} stole your {companyName(company)}!`)
	return `You stole {companyName(company)}!`
end

local function lock(owner: Player): string
	local base = BaseService:GetBase(owner)
	if base == nil then
		return "You don't have a base."
	end
	local button = base.lockButton
	if button == nil then
		return "Your base doesn't have a lock button yet."
	end
	if isLocked(base) then
		return "Your base is already locked."
	end
	if not isWithin(owner, button, StealConfig.LockButtonDistance + StealConfig.LockButtonDistanceTolerance) then
		return "Get closer to the lock button."
	end
	setLock(base, now() + StealConfig.LockSeconds)
	return `Base locked for {StealConfig.LockSeconds} seconds.`
end

-- Tags: an owner close enough to a thief carrying their company gets it back.
local function checkTags()
	for _, thief in Players:GetPlayers() do
		local entry = CarryService:GetStolen(thief)
		local thiefRoot = rootOf(thief)
		local ownerRoot = if entry then rootOf(entry.owner) else nil
		if entry and thiefRoot and ownerRoot then
			if (thiefRoot.Position - ownerRoot.Position).Magnitude <= StealConfig.TagDistance then
				CarryService:TakeStolen(thief)
				refreshOwner(entry.owner)
				local name = companyName(entry.company)
				notify(thief, `{entry.owner.Name} tagged you! The {name} went back.`)
				notify(entry.owner, `You got your {name} back!`)
			end
		end
	end
end

local function checkLocks()
	local time = now()
	for base, untilTime in lockedUntil do
		if time >= untilTime then
			setLock(base, nil)
			local owner = base.owner
			if owner then
				notify(owner, "Your base lock ran out. Press the button to lock it again.")
			end
		else
			for _, player in Players:GetPlayers() do
				if player ~= base.owner and BaseService:IsOnBase(player, base) then
					pushOut(player, base)
				end
			end
		end
	end
end

-- Admin testing: protects a player as if they had just joined for the first time.
function StealService:Protect(player: Player, seconds: number)
	protectedUntil[player] = now() + seconds
	publishProtection(player)
end

function StealService:GetProtectionLeft(player: Player): number
	return protectionLeft(player)
end

-- Lock Base Now (MonetisationService): locks the player's base from wherever
-- they are for Config/Steal.LockSeconds, or adds that much to a lock already
-- on. Returns false if they have no base.
function StealService:LockFromAnywhere(owner: Player): boolean
	local base = BaseService:GetBase(owner)
	if base == nil then
		return false
	end
	setLock(base, math.max(lockedUntil[base] or 0, now()) + StealConfig.LockSeconds)
	return true
end

-- Whether the player's base is locked right now.
function StealService:IsBaseLocked(player: Player): boolean
	local base = BaseService:GetBase(player)
	return base ~= nil and isLocked(base)
end

-- Why this thief may not take anything of this owner's, wherever it is (on a
-- plot or dropped on the ground), or nil if they may.
function StealService:GetBlockReason(thief: Player, owner: Player): string?
	local protection = protectionLeft(owner)
	if protection > 0 then
		return `{owner.Name} is new here and protected for {Format.duration(protection)}.`
	end
	local thiefData = DataService:GetData(thief)
	local ownerData = DataService:GetData(owner)
	if thiefData and ownerData and thiefData.Rebirths >= StealConfig.VeteranRebirths and ownerData.Rebirths == 0 then
		return `{owner.Name} hasn't rebirthed yet. With {StealConfig.VeteranRebirths}+ rebirths you can't steal from them.`
	end
	return nil
end

local function validName(value: unknown): boolean
	return typeof(value) == "string" and #value <= MAX_NAME_LENGTH
end

function StealService:Start()
	PlotService:OnPlaceStolen(complete)

	CarryService:OnStolenReturned(function(_thief, entry)
		refreshOwner(entry.owner)
		local place = if entry.plotKey then "on its plot" else "in your storage"
		notify(entry.owner, `Your {companyName(entry.company)} is back {place}.`)
	end)

	DataService:OnDataLoaded(function(player)
		local firstJoined = DataService:GetFirstSessionTime(player)
		if firstJoined then
			local left = firstJoined + StealConfig.NewPlayerProtectionSeconds - os.time()
			if left > 0 then
				protectedUntil[player] = now() + left
			end
		end
		publishProtection(player)
	end)
	BaseService:OnBaseAssigned(function(player)
		publishProtection(player)
	end)
	BaseService:OnBaseFreed(function(_player, base)
		setLock(base, nil)
		base.model:SetAttribute("ProtectedUntil", nil)
	end)

	Players.PlayerRemoving:Connect(function(player)
		attempts[player] = nil
		protectedUntil[player] = nil
		lastLockNotice[player] = nil
		-- Anyone carrying off this player's companies loses them; they never
		-- left this player's save.
		for _, thief in CarryService:GetThievesOf(player) do
			local entry = CarryService:TakeStolen(thief)
			if entry then
				notify(thief, `{player.Name} left, so the {companyName(entry.company)} went back.`)
			end
		end
	end)

	Remotes.StealBegin.OnServerEvent:Connect(function(thief: Player, baseName: unknown, plotKey: unknown)
		if beginLimiter:allow(thief) and validName(baseName) and validName(plotKey) then
			attempts[thief] = { baseName = baseName :: string, plotKey = plotKey :: string, startedAt = now() }
		end
	end)

	Remotes.StealFinish.OnServerEvent:Connect(function(thief: Player, baseName: unknown, plotKey: unknown)
		if finishLimiter:allow(thief) and validName(baseName) and validName(plotKey) then
			local message = finish(thief, baseName :: string, plotKey :: string)
			if message then
				notify(thief, message)
			end
		end
	end)

	Remotes.LockBase.OnServerEvent:Connect(function(owner: Player)
		if lockLimiter:allow(owner) then
			notify(owner, lock(owner))
		end
	end)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		sinceCheck += deltaTime
		if sinceCheck < CHECK_SECONDS then
			return
		end
		sinceCheck = 0
		checkTags()
		checkLocks()
	end)
end

return StealService
