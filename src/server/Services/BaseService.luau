--!strict
-- Gives each player a base from Workspace.Map.Bases when they join, frees it
-- when they leave, and spawns their character on the base's Spawn part.
--
-- Bases are built by hand in Studio. Each Base<number> needs a Spawn part and
-- a Conveyor model containing Start and End parts. A base missing any of these
-- is skipped with a warning naming what's missing; it is never patched up.

local Players = game:GetService("Players")

export type Base = {
	model: Instance,
	name: string,
	spawn: BasePart,
	conveyorStart: BasePart,
	conveyorEnd: BasePart,
	owner: Player?,
}

-- Height above the Spawn part's top surface to place a character.
local SPAWN_HEIGHT = 3

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

local function baseNumber(instance: Instance): number?
	return tonumber(string.match(instance.Name, "^Base(%d+)$"))
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
			table.insert(models, child)
		end
	end
	table.sort(models, function(a, b)
		return (baseNumber(a) :: number) < (baseNumber(b) :: number)
	end)

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
			table.insert(bases, {
				model = model,
				name = model.Name,
				spawn = spawn,
				conveyorStart = conveyorStart,
				conveyorEnd = conveyorEnd,
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
