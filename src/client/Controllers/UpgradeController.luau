--!strict
-- The Upgrades menu button and its window, with two tabs:
--   Base: the next base upgrade (one more plot, or the next floor) and its
--     cost, from the NextUpgrade and NextUpgradeCost attributes. Bought from
--     anywhere.
--   Station: the upgrade station's upgrades (Config/Perks) with their levels,
--     what they do now and next, and the next level's cost, from the
--     PerkLevels attribute. These are bought at the station, so away from it
--     the window offers a teleport there instead.
-- The station's prompt (Workspace.Map.Shops.UpgradeStation.ShopPrompt) opens
-- the window on the Station tab. The menu button gets a dot while the next
-- base upgrade is affordable. The server checks every purchase
-- (UpgradeService, PerkService).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local PerkMath = require(ReplicatedStorage.Shared.PerkMath)
local Perks = require(ReplicatedStorage.Shared.Config.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)
local Row = require(script.Parent.Parent.Ui.Kit.Row)
local Scroll = require(script.Parent.Parent.Ui.Kit.Scroll)

local ROW_HEIGHT = 84
local ACTION_WIDTH = 116
local UPDATE_SECONDS = 0.5
local FULLY_UPGRADED = "Fully upgraded"

local PERK_ICONS: { [string]: Icons.IconName } = {
	WalkSpeed = "Arrow",
	Damage = "Weapon",
	ConveyorLuck = "Gem",
	Income = "Cash",
	VariantChance = "Gem",
}

local player = Players.LocalPlayer

type PerkRow = { perk: Perks.Perk, row: Row.Row, button: Button.Button }

local UpgradeController = {}

local function watchChild(parent: Instance, name: string, callback: (Instance) -> ())
	parent.ChildAdded:Connect(function(child)
		if child.Name == name then
			callback(child)
		end
	end)
	local existing = parent:FindFirstChild(name)
	if existing then
		callback(existing)
	end
end

local function levels(): { [string]: number }
	local json = player:GetAttribute("PerkLevels")
	if typeof(json) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

-- "+30%" for a multiplier of 1.3.
local function percent(multiplier: number): string
	return `+{math.floor((multiplier - 1) * 100 + 0.5)}%`
end

local function cashNow(): number?
	local stats = player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("Cash")
	return if cash and cash:IsA("IntValue") then cash.Value else nil
end

function UpgradeController:Start()
	local pages: { [string]: Frame } = {}
	local window = Menu.window({
		title = "Upgrades",
		colour = Theme.Menu.Upgrades,
		tabs = { "Base", "Station" },
		onTab = function(name)
			for pageName, page in pages do
				page.Visible = pageName == name
			end
		end,
	})
	local function page(name: string): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundTransparency = 1
		frame.Visible = false
		frame.Parent = window.Body
		pages[name] = frame
		return frame
	end

	-- Base: one big card for the next upgrade.
	local basePage = page("Base")
	local baseList = Scroll.list(basePage)
	local nextRow = Row.new({
		title = "",
		icon = "Arrow",
		accent = Theme.Menu.Upgrades,
		height = 96,
		actionWidth = 140,
		layoutOrder = 1,
	})
	nextRow.Instance.Parent = baseList
	local buyBase = Button.new({
		text = "",
		colour = Theme.Colours.Cash,
		size = UDim2.fromScale(1, 1),
		textSize = Theme.TextSize.Body,
	})
	buyBase.Instance.Parent = nextRow.Action
	buyBase.Activated:Connect(function()
		Remotes.BuyUpgrade:FireServer()
	end)
	local baseNote = Make.label(baseList, {
		text = "Each upgrade opens one more plot. Fill a floor and the next upgrade builds a whole new floor on your base.",
		size = Theme.TextSize.Small,
		colour = Theme.Colours.TextMuted,
		wrapped = true,
	})
	baseNote.LayoutOrder = 2
	baseNote.Size = UDim2.new(1, 0, 0, 44)

	-- Station: a row per upgrade, with a teleport there when away from it.
	local stationPage = page("Station")
	local stationList = Scroll.list(stationPage)
	local away = Row.new({
		title = "Buy these at the upgrade station",
		detail = "It's at the end of the street, across from the shops.",
		icon = "Home",
		accent = Theme.Colours.Gold,
		actionWidth = 120,
		layoutOrder = 0,
	})
	away.Instance.Parent = stationList
	local goThere = Button.new({
		text = "Go there",
		colour = Theme.Menu.Upgrades,
		size = UDim2.fromScale(1, 1),
		textSize = Theme.TextSize.Body,
	})
	goThere.Instance.Parent = away.Action
	goThere.Activated:Connect(function()
		Remotes.Travel:FireServer("Upgrades")
		window.close()
	end)

	local perkRows: { PerkRow } = {}
	for order, perk in Perks.list do
		local row = Row.new({
			title = perk.name,
			icon = PERK_ICONS[perk.id] or "Arrow",
			accent = Theme.Menu.Upgrades,
			height = ROW_HEIGHT,
			actionWidth = ACTION_WIDTH,
			layoutOrder = order,
		})
		row.Instance.Parent = stationList
		local button = Button.new({
			text = "",
			colour = Theme.Colours.Cash,
			size = UDim2.fromScale(1, 1),
			textSize = Theme.TextSize.Body,
		})
		button.Instance.Parent = row.Action
		button.Activated:Connect(function()
			Remotes.BuyPerk:FireServer(perk.id)
		end)
		table.insert(perkRows, { perk = perk, row = row, button = button })
	end

	local station: BasePart? = nil
	local function nearStation(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local spot = station
		if spot == nil or root == nil or not root:IsA("BasePart") then
			return false
		end
		return (root.Position - spot.Position).Magnitude <= Perks.StationDistance + Perks.StationDistanceTolerance
	end

	local menuButton = Menu.button({
		name = "Upgrades",
		text = "Upgrades",
		icon = "Arrow",
		colour = Theme.Menu.Upgrades,
		order = 2,
		side = "Left",
	})
	menuButton.Activated:Connect(function()
		Menu.toggle(window)
	end)

	local function render()
		local cash = cashNow()
		-- The next base upgrade.
		local label = player:GetAttribute("NextUpgrade")
		local cost = player:GetAttribute("NextUpgradeCost")
		local affordable = typeof(cost) == "number" and cash ~= nil and cash >= cost
		menuButton.setDot(affordable)
		if typeof(label) ~= "string" or label == FULLY_UPGRADED or typeof(cost) ~= "number" then
			nextRow.setTitle(if typeof(label) == "string" then label else "Upgrade base")
			nextRow.setDetail("Every plot and floor is open.")
			buyBase.setText("Done")
			buyBase.setEnabled(false)
		else
			nextRow.setTitle(`Next: {label}`)
			nextRow.setDetail(
				if string.find(label, "Floor")
					then "Builds a new floor on your base."
					else "One more plot on your top floor."
			)
			buyBase.setText(Format.cash(cost))
			buyBase.setEnabled(affordable)
		end

		-- The station's upgrades.
		local here = nearStation()
		away.Instance.Visible = not here
		local current = levels()
		for _, entry in perkRows do
			local perk = entry.perk
			local level = current[perk.id] or 0
			local now = PerkMath.multiplier(perk.id, level)
			local nextCost = PerkMath.cost(perk.id, level)
			entry.row.setTitle(`{perk.name}  ·  Level {level}/{perk.maxLevel}`)
			local effect = if nextCost
				then `{percent(now)} now, {percent(PerkMath.multiplier(perk.id, level + 1))} next`
				else `{percent(now)}, the most there is`
			entry.row.setDetail(`{perk.description}\n{effect}`)
			if nextCost == nil then
				entry.button.setText("Maxed")
				entry.button.setEnabled(false)
			else
				entry.button.setText(Format.cash(nextCost))
				entry.button.setEnabled(here and (cash == nil or cash >= nextCost))
			end
		end
	end

	player:GetAttributeChangedSignal("NextUpgrade"):Connect(render)
	player:GetAttributeChangedSignal("NextUpgradeCost"):Connect(render)
	player:GetAttributeChangedSignal("PerkLevels"):Connect(render)
	render()

	-- The station's prompt opens the window on the Station tab. The station
	-- is built by hand and streams in and out, so watch for it.
	local function addPrompt(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("UpgradeStationPrompt") then
			return
		end
		station = part
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "UpgradeStationPrompt"
		prompt.ActionText = "Open"
		prompt.ObjectText = "Upgrades"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Perks.StationDistance
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			Menu.open(window)
			window.selectTab("Station")
			render()
		end)
		prompt.Parent = part
	end
	watchChild(workspace:WaitForChild("Map"), "Shops", function(shops)
		watchChild(shops, "UpgradeStation", function(upgradeStation)
			watchChild(upgradeStation, "ShopPrompt", addPrompt)
		end)
	end)

	local stats = player:WaitForChild("leaderstats")
	local cashValue = stats:WaitForChild("Cash")
	if cashValue:IsA("IntValue") then
		cashValue.Changed:Connect(render)
	end
	while true do
		task.wait(UPDATE_SECONDS)
		if window.isOpen() then
			render()
		end
	end
end

return UpgradeController
