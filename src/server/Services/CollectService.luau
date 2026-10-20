--!strict
-- Cash pads (docs/design.md, "Cash pads"). Each placed company's income builds
-- up on the pad in front of its plot (IncomeService, saved in
-- Data.Uncollected) until the base's owner steps on the pad, which moves it
-- into their Cash. The server checks where the owner's character is, so the
-- client never asks, and nobody else can collect from a base's pads. A plot
-- built without a pad (reported by BaseService) pays straight into Cash, so
-- nothing gets stuck.
--
-- Pads get a Cash attribute (the whole Cash waiting, or nil under 1) for the
-- client to show, and Remotes.Collected tells the owner what they collected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.Shared.Config.Base)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AnalyticsService = require(script.Parent.AnalyticsService)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)

local CHECK_SECONDS = 0.2

local collectedCallbacks: { (Player, number) -> () } = {}

local CollectService = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Whether the character's root part is over the pad: within its edges (and
-- Config/Base.PadReach) and no more than PadHeight above it.
local function isOnPad(root: BasePart, pad: BasePart): boolean
	local offset = pad.CFrame:PointToObjectSpace(root.Position)
	local half = pad.Size / 2
	return math.abs(offset.X) <= half.X + BaseConfig.PadReach
		and math.abs(offset.Z) <= half.Z + BaseConfig.PadReach
		and offset.Y >= 0
		and offset.Y <= half.Y + BaseConfig.PadHeight
end

local function show(pad: BasePart, amount: number?)
	local whole = if amount and amount >= 1 then math.floor(amount) else nil
	if pad:GetAttribute("Cash") ~= whole then
		pad:SetAttribute("Cash", whole)
	end
end

-- Moves the Cash on a plot's pad into the player's Cash.
local function collect(player: Player, plot: BaseService.Plot)
	local amount = DataService:TakeUncollected(player, plot.key)
	if amount <= 0 then
		return
	end
	if not DataService:AddCash(player, amount) then
		DataService:AddUncollected(player, { [plot.key] = amount })
		return
	end
	AnalyticsService:Earned(player, "Income", amount)
	local pad = plot.pad
	if pad then
		show(pad, nil)
		Remotes.Collected:FireClient(player, pad, amount)
	end
	for _, callback in collectedCallbacks do
		task.spawn(callback, player, amount)
	end
end

local function update(player: Player, base: BaseService.Base)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	local root = rootOf(player)
	for _, plot in base.plots do
		local pad = plot.pad
		local waiting = data.Uncollected[plot.key]
		if pad == nil then
			if waiting then
				collect(player, plot)
			end
		elseif plot.floor <= base.floorsShown then
			if waiting and waiting >= BaseConfig.MinCollect and root and isOnPad(root, pad) then
				collect(player, plot)
			else
				show(pad, waiting)
			end
		end
	end
end

-- Runs callback(player, amount) each time a player collects from a pad.
function CollectService:OnCollected(callback: (Player, number) -> ())
	table.insert(collectedCallbacks, callback)
end

function CollectService:Start()
	BaseService:OnBaseFreed(function(_player, base)
		for _, plot in base.plots do
			if plot.pad then
				show(plot.pad, nil)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, base in BaseService:GetBases() do
				local owner = base.owner
				if owner then
					update(owner, base)
				end
			end
		end
	end)
end

return CollectService
