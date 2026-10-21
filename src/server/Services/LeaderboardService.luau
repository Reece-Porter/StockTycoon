--!strict
-- The leaderboards (docs/design.md, "Server and leaderboards"): the all-time
-- top players across every server for Cash per second, rebirths, successful
-- steals and knockouts.
--
-- Each board's values live in an OrderedDataStore. Every
-- Config/Leaderboards.UpdateSeconds the server saves each player's values that
-- have changed (and again when they leave) and reads the top of each board
-- back. Cash per second is saved without any reward boost.
--
-- The boards are hand-built parts in Workspace.Map.Leaderboards
-- (studio/BuildMap.luau); this puts the list on each one's front face
-- (Lib/BoardDisplay draws it).
-- Without DataStore access (Studio with API access off) the boards say so.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.Leaderboards)
local DataService = require(script.Parent.DataService)
local IncomeService = require(script.Parent.IncomeService)
local BoardDisplay = require(script.Parent.Parent.Lib.BoardDisplay)

type Board = {
	part: string,
	title: string,
	storeName: string,
	value: (Player, DataService.Data) -> number,
	format: (number) -> string,
	store: OrderedDataStore?,
	rows: { BoardDisplay.Row },
	status: TextLabel?,
}

local function whole(value: number): string
	return tostring(math.floor(value))
end

local boards: { Board } = {
	{
		part = "IncomeBoard",
		title = "Top Cash per second",
		storeName = "LeaderboardIncome",
		value = function(player)
			return math.floor(IncomeService:GetIncomePerSecond(player, true))
		end,
		format = Format.income,
		rows = {},
	},
	{
		part = "RebirthsBoard",
		title = "Most rebirths",
		storeName = "LeaderboardRebirths",
		value = function(_player, data)
			return data.Rebirths
		end,
		format = whole,
		rows = {},
	},
	{
		part = "StealsBoard",
		title = "Most steals",
		storeName = "LeaderboardSteals",
		value = function(_player, data)
			return data.Stats.Steals
		end,
		format = whole,
		rows = {},
	},
	{
		part = "KnockoutsBoard",
		title = "Most knockouts",
		storeName = "LeaderboardKnockouts",
		value = function(_player, data)
			return data.Stats.Knockouts
		end,
		format = whole,
		rows = {},
	},
}

-- The last value saved for each player on each board, so unchanged values
-- aren't saved again.
local saved: { [Player]: { [string]: number } } = {}
local names: { [number]: string } = {}
local problems: { string } = {}

local LeaderboardService = {}

local function nameOf(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.Name
	end
	local cached = names[userId]
	if cached then
		return cached
	end
	-- Studio test players have negative ids and no real name.
	local name = if userId < 0 then `Player{-userId}` else `Player {userId}`
	if userId > 0 then
		local ok, found = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		if ok and typeof(found) == "string" then
			name = found
		end
	end
	names[userId] = name
	return name
end

local function setStatus(board: Board, text: string)
	local status = board.status
	if status then
		status.Text = text
		status.Visible = text ~= ""
	end
end

-- The list shown on the board's front face.
local function buildDisplay(board: Board, part: BasePart)
	local display = BoardDisplay.build(part, board.title, LeaderboardConfig.Entries)
	board.status = display.status
	board.rows = display.rows
	setStatus(board, "Loading...")
end

local function findBoards()
	local map = workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("Leaderboards")
	for _, board in boards do
		local part = folder and folder:FindFirstChild(board.part)
		if part and part:IsA("BasePart") then
			buildDisplay(board, part)
		else
			table.insert(problems, `Workspace.Map.Leaderboards.{board.part} is missing or isn't a part`)
		end
	end
	for _, problem in problems do
		warn(`[LeaderboardService] {problem}. Run studio/BuildMap.luau in Studio.`)
	end
end

local function openStores(): boolean
	local ok = true
	for _, board in boards do
		if board.store == nil then
			local opened, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, board.storeName)
			if opened then
				board.store = store
			else
				ok = false
			end
		end
	end
	return ok
end

-- Saves the player's values that changed since they were last saved.
local function savePlayer(player: Player)
	local data = DataService:GetData(player)
	if data == nil then
		return
	end
	local last = saved[player]
	if last == nil then
		last = {}
		saved[player] = last
	end
	for _, board in boards do
		local store = board.store
		local value = board.value(player, data)
		if store and last[board.storeName] ~= value then
			local ok = pcall(store.SetAsync, store, tostring(player.UserId), value)
			if ok then
				last[board.storeName] = value
			end
		end
	end
end

local function readBoards()
	for _, board in boards do
		local store = board.store
		if store == nil then
			setStatus(board, "Leaderboards need saving to be on (Studio: turn on API access).")
			continue
		end
		local ok, pages = pcall(store.GetSortedAsync, store, false, LeaderboardConfig.Entries)
		if not ok then
			setStatus(
				board,
				if DataService:IsSaving()
					then "Couldn't load the leaderboard. Trying again soon."
					else "Leaderboards need saving to be on (Studio: turn on API access)."
			)
			continue
		end
		local entries = (pages :: DataStorePages):GetCurrentPage()
		setStatus(board, if #entries == 0 then "No one yet. Be the first!" else "")
		for rank, row in board.rows do
			local entry = entries[rank]
			local userId = if entry then tonumber(entry.key) else nil
			if entry and userId then
				BoardDisplay.setRow(row, nameOf(userId), board.format(entry.value))
			else
				BoardDisplay.setRow(row, nil)
			end
		end
	end
end

-- Saves every player's values and reads the boards now. Admin testing uses
-- this rather than waiting for the next update.
function LeaderboardService:UpdateNow()
	openStores()
	for _, player in Players:GetPlayers() do
		savePlayer(player)
	end
	readBoards()
end

-- Problems found with the hand-built boards, for the debug panel.
function LeaderboardService:GetProblems(): { string }
	return problems
end

function LeaderboardService:Init()
	findBoards()
end

function LeaderboardService:Start()
	Players.PlayerRemoving:Connect(function(player)
		savePlayer(player)
		saved[player] = nil
	end)
	task.spawn(function()
		while true do
			LeaderboardService:UpdateNow()
			task.wait(LeaderboardConfig.UpdateSeconds)
		end
	end)
end

return LeaderboardService
