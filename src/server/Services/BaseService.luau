--!strict
-- Gives each player a base from Workspace.Map.Bases when they join, frees it
-- when they leave, and spawns their character on the base's Spawn part.
--
-- Bases are built by hand in Studio. Each Base<number> is a Model with a Spawn
-- part, a Conveyor model containing Start and End parts, plots at
-- Floors.Floor<n>.Plots.Plot<m>, and a Machine containing a Pad part. A base missing Spawn or the conveyor is
-- skipped, and missing plots are reported, with a warning naming what's
-- missing; nothing is ever patched up.

local Players = game:GetService("Players")

export type Plot = {
	-- e.g. "Floor1/Plot3"; how placed companies are saved.
	key: string,
	floor: number,
	index: number,
	part: BasePart,
}

export type Base = {
	model: Model,
	name: string,
	spawn: BasePart,
	conveyorStart: BasePart,
	conveyorEnd: BasePart,
	plots: { Plot },
	plotsByKey: { [string]: Plot },
	-- Where a company sits in the Valuation Machine; nil if it isn't built.
	machinePad: BasePart?,
	-- The base's bounding box, for checking whether someone is on it.
	boxCFrame: CFrame,
	boxSize: Vector3,
	owner: Player?,
}

-- Height above the Spawn part's top surface to place a character.
local SPAWN_HEIGHT = 3

-- How far outside its bounding box still counts as on a base: a little to the
-- sides, and well above the top so jumping or a tall floor still counts.
local ON_BASE_MARGIN = 4
local ON_BASE_HEADROOM = 25

local bases: { Base } = {}
local playerBases: { [Player]: Base } = {}
local assignedCallbacks: { (Player, Base) -> () } = {}
local freedCallbacks: { (Player, Base) -> () } = {}
local problems: { string } = {}

local BaseService = {}

local function findPart(parent: Instance, name: string, path: string): BasePart?
	local found = parent:FindFirstChild(name)
	if found and found:IsA("BasePart") then
		return found
	end
	table.insert(problems, `{path}.{name} is missing or isn't a part`)
	return nil
end

local function numbered(instance: Instance, prefix: string): number?
	return tonumber((string.match(instance.Name, `^{prefix}(%d+)$`)))
end

local function baseNumber(instance: Instance): number?
	return numbered(instance, "Base")
end

local function sortByNumber<T>(instances: { T }, prefix: string)
	table.sort(instances, function(a, b)
		return (numbered(a :: any, prefix) :: number) < (numbered(b :: any, prefix) :: number)
	end)
end

local function findPlots(model: Model, path: string): { Plot }
	local plots: { Plot } = {}
	local floorsFolder = model:FindFirstChild("Floors")
	local floor1 = floorsFolder and floorsFolder:FindFirstChild("Floor1")
	if floorsFolder == nil or floor1 == nil or floor1:FindFirstChild("Plots") == nil then
		table.insert(problems, `{path}.Floors.Floor1.Plots is missing`)
		return plots
	end

	local floors = {}
	for _, child in floorsFolder:GetChildren() do
		if numbered(child, "Floor") then
			table.insert(floors, child)
		end
	end
	sortByNumber(floors, "Floor")

	for _, floor in floors do
		local plotsFolder = floor:FindFirstChild("Plots")
		if plotsFolder then
			local parts = {}
			for _, child in plotsFolder:GetChildren() do
				if child:IsA("BasePart") and numbered(child, "Plot") then
					table.insert(parts, child)
				end
			end
			sortByNumber(parts, "Plot")

			local floorNumber = numbered(floor, "Floor") :: number
			for _, part in parts do
				local index = numbered(part, "Plot") :: number
				table.insert(plots, {
					key = `Floor{floorNumber}/Plot{index}`,
					floor = floorNumber,
					index = index,
					part = part :: BasePart,
				})
			end
		end
	end
	return plots
end

local function loadBases()
	local map = workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("Bases")
	if folder == nil then
		table.insert(problems, "Workspace.Map.Bases is missing")
		return
	end

	local models = {}
	for _, child in folder:GetChildren() do
		if baseNumber(child) then
			if child:IsA("Model") then
				table.insert(models, child)
			else
				table.insert(problems, `Workspace.Map.Bases.{child.Name} must be a Model`)
			end
		end
	end
	sortByNumber(models, "Base")

	for _, model in models do
		local path = `Workspace.Map.Bases.{model.Name}`
		local spawn = findPart(model, "Spawn", path)
		local conveyor = model:FindFirstChild("Conveyor")
		local conveyorStart, conveyorEnd
		if conveyor then
			conveyorStart = findPart(conveyor, "Start", `{path}.Conveyor`)
			conveyorEnd = findPart(conveyor, "End", `{path}.Conveyor`)
		else
			table.insert(problems, `{path}.Conveyor is missing`)
		end

		if conveyorStart and conveyorEnd and (conveyorStart.Position - conveyorEnd.Position).Magnitude < 1 then
			table.insert(problems, `{path}.Conveyor Start and End are in the same place`)
			conveyorEnd = nil
		end

		if spawn and conveyorStart and conveyorEnd then
			local plots = findPlots(model, path)
			local plotsByKey = {}
			for _, plot in plots do
				plotsByKey[plot.key] = plot
			end
			local machine = model:FindFirstChild("Machine")
			local machinePad = if machine then findPart(machine, "Pad", `{path}.Machine`) else nil
			if machine == nil then
				table.insert(problems, `{path}.Machine is missing`)
			end

			local boxCFrame, boxSize = model:GetBoundingBox()
			table.insert(bases, {
				model = model,
				name = model.Name,
				spawn = spawn,
				conveyorStart = conveyorStart,
				conveyorEnd = conveyorEnd,
				plots = plots,
				plotsByKey = plotsByKey,
				machinePad = machinePad,
				boxCFrame = boxCFrame,
				boxSize = boxSize,
				owner = nil,
			})
		end
	end
end

local function moveToBase(player: Player, character: Model)
	local base = playerBases[player]
	if base == nil or character:WaitForChild("HumanoidRootPart", 5) == nil then
		return
	end
	-- Let Roblox finish its own spawn placement first.
	task.wait()
	if character.Parent then
		character:PivotTo(base.spawn.CFrame * CFrame.new(0, base.spawn.Size.Y / 2 + SPAWN_HEIGHT, 0))
	end
end

local function assign(player: Player)
	if playerBases[player] then
		return
	end
	for _, base in bases do
		if base.owner == nil then
			base.owner = player
			playerBases[player] = base
			base.model:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("BaseName", base.name)
			for _, callback in assignedCallbacks do
				task.spawn(callback, player, base)
			end
			return
		end
	end
	warn(`[BaseService] No free base for {player.Name}.`)
end

local function free(player: Player)
	local base = playerBases[player]
	if base == nil then
		return
	end
	playerBases[player] = nil
	base.owner = nil
	base.model:SetAttribute("OwnerUserId", nil)
	for _, callback in freedCallbacks do
		task.spawn(callback, player, base)
	end
end

local function onPlayerAdded(player: Player)
	assign(player)
	player.CharacterAdded:Connect(function(character)
		moveToBase(player, character)
	end)
	if player.Character then
		task.spawn(moveToBase, player, player.Character)
	end
end

function BaseService:GetBase(player: Player): Base?
	return playerBases[player]
end

function BaseService:GetBases(): { Base }
	return bases
end

-- Whether the player's character is standing on (or just above) the base.
function BaseService:IsOnBase(player: Player, base: Base): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local offset = base.boxCFrame:PointToObjectSpace(root.Position)
	local half = base.boxSize / 2
	return math.abs(offset.X) <= half.X + ON_BASE_MARGIN
		and math.abs(offset.Z) <= half.Z + ON_BASE_MARGIN
		and offset.Y >= -half.Y - ON_BASE_MARGIN
		and offset.Y <= half.Y + ON_BASE_HEADROOM
end

-- Problems found with the hand-built map, for the debug panel.
function BaseService:GetProblems(): { string }
	return problems
end

-- Runs callback(player, base) whenever a player gets a base, including
-- players who got one before this was called.
function BaseService:OnBaseAssigned(callback: (Player, Base) -> ())
	table.insert(assignedCallbacks, callback)
	for player, base in playerBases do
		task.spawn(callback, player, base)
	end
end

-- Runs callback(player, base) when a player leaves and their base is freed.
function BaseService:OnBaseFreed(callback: (Player, Base) -> ())
	table.insert(freedCallbacks, callback)
end

function BaseService:Init()
	loadBases()
	for _, problem in problems do
		warn(`[BaseService] {problem}. Build it in Studio (see "Map naming" in docs/design.md).`)
	end
	if #bases == 0 then
		warn("[BaseService] No usable bases, so players won't get a base or a conveyor.")
	end
end

function BaseService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(free)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return BaseService
