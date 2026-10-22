--!strict
-- The market screens around the map (the stock theme): every part
-- studio/BuildMap.luau tags MarketScreen, with ScreenKind, ScreenFaces and
-- ScreenDistance attributes. Drawn on each player's device and only moving
-- while the camera is within ScreenDistance.
--   - Ticker: parody companies sliding past (bases' signs and floor fronts,
--     the skyline's ticker tower).
--   - Chart: a moving line chart with made-up numbers (each floor's trading
--     screen, the skyline's chart billboards).
--   - Quote: a base's share price board. Real numbers: the owner's ticker
--     symbol (from their display name) and their Cash per second (the
--     IncomePerSecond attribute the server sets), with how it has moved
--     over the last minute or so.
--   - Ad: a skyline billboard for a parody company, changing now and then.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Theme = require(ReplicatedStorage.Shared.Theme)
local WorldScreens = require(script.Parent.Parent.Ui.WorldScreens)

local TAG = "MarketScreen"
local CHECK_SECONDS = 0.5
local DEFAULT_DISTANCE = 80
-- How often a quote board takes its owner's Cash per second, and how many
-- readings it keeps.
local QUOTE_SAMPLE_SECONDS = 2
local QUOTE_SAMPLES = 30
local SYMBOL_LETTERS = 4
-- Ads change to another company this often.
local AD_SECONDS = 9
local AD_PIXELS_PER_STUD = 8
local AD_LINES =
	{ "Shares up again", "Now on the big board", "Invest in tomorrow", "The future is up", "Hiring interns" }

type Screen = {
	part: BasePart,
	kind: string,
	distance: number,
	near: boolean,
	charts: { WorldScreens.Chart },
	tickers: { WorldScreens.Ticker },
	quotes: { WorldScreens.Quote },
	ads: { { name: TextLabel, line: TextLabel } },
	-- Quotes: the base, whose owner the readings are for, and the readings.
	base: Instance?,
	ownerId: number?,
	history: { number },
	nextSample: number,
	nextAd: number,
}

local screens: { [BasePart]: Screen } = {}

local MarketScreensController = {}

local function faces(part: BasePart): { Enum.NormalId }
	local list = {}
	local text = part:GetAttribute("ScreenFaces")
	for _, name in string.split(if typeof(text) == "string" then text else "Right", ",") do
		local face = (Enum.NormalId :: any)[name]
		if typeof(face) == "EnumItem" then
			table.insert(list, face :: any)
		end
	end
	return list
end

-- The base model a part belongs to, if it's on one.
local function baseOf(part: Instance): Instance?
	local current = part.Parent
	while current and current.Parent do
		if current.Parent.Name == "Bases" then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- A short ticker symbol from a display name: its first few letters and
-- digits, in capitals.
function MarketScreensController.symbol(displayName: string): string
	local letters = string.upper((string.gsub(displayName, "[^%w]", "")))
	local symbol = string.sub(letters, 1, SYMBOL_LETTERS)
	return if symbol == "" then "BASE" else symbol
end

local function owner(screen: Screen): Player?
	local base = screen.base
	local userId = base and base:GetAttribute("OwnerUserId")
	return if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function makeAd(part: BasePart, face: Enum.NormalId, distance: number): { name: TextLabel, line: TextLabel }
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = AD_PIXELS_PER_STUD
	gui.MaxDistance = distance
	gui.LightInfluence = 0
	gui.Parent = part
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Theme.Colours.Ink
	back.BorderSizePixel = 0
	back.Parent = gui
	local function text(name: string, y: number, height: number, font: Enum.Font, colour: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Position = UDim2.fromScale(0.05, y)
		label.Size = UDim2.fromScale(0.9, height)
		label.BackgroundTransparency = 1
		label.Font = font
		label.TextScaled = true
		label.TextColor3 = colour
		label.Parent = back
		return label
	end
	return {
		name = text("Company", 0.08, 0.55, Theme.Fonts.Display, Theme.Colours.Gold),
		line = text("Line", 0.66, 0.26, Theme.Fonts.Body, Theme.Chart.Rising),
	}
end

local function showAd(screen: Screen)
	local company = Companies.list[math.random(1, #Companies.list)]
	local line = AD_LINES[math.random(1, #AD_LINES)]
	for _, ad in screen.ads do
		ad.name.Text = company.name
		ad.line.Text = line
	end
end

local function add(instance: Instance)
	if not instance:IsA("BasePart") or screens[instance] then
		return
	end
	local part = instance
	-- A part that left the world and came back keeps what was drawn on it.
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceGui") and child.Name == "Display" then
			child:Destroy()
		end
	end
	local kind = part:GetAttribute("ScreenKind")
	local distanceValue = part:GetAttribute("ScreenDistance")
	local distance = if typeof(distanceValue) == "number" then distanceValue else DEFAULT_DISTANCE
	local screen: Screen = {
		part = part,
		kind = if typeof(kind) == "string" then kind else "Ticker",
		distance = distance,
		near = false,
		charts = {},
		tickers = {},
		quotes = {},
		ads = {},
		history = {},
		nextSample = 0,
		nextAd = 0,
	}
	local options = { distance = distance }
	for _, face in faces(part) do
		if screen.kind == "Chart" then
			table.insert(screen.charts, WorldScreens.chart(part, face, options))
		elseif screen.kind == "Quote" then
			table.insert(screen.quotes, WorldScreens.quote(part, face, options))
		elseif screen.kind == "Ad" then
			table.insert(screen.ads, makeAd(part, face, distance))
		else
			table.insert(screen.tickers, WorldScreens.ticker(part, face, options))
		end
	end
	if screen.kind == "Quote" then
		screen.base = baseOf(part)
	end
	if screen.kind == "Ad" then
		showAd(screen)
	end
	screens[part] = screen
end

local function updateQuote(screen: Screen, now: number)
	local who = owner(screen)
	local ownerId = if who then who.UserId else nil
	if ownerId ~= screen.ownerId then
		screen.ownerId = ownerId
		table.clear(screen.history)
		screen.nextSample = 0
	end
	if who and now >= screen.nextSample then
		screen.nextSample = now + QUOTE_SAMPLE_SECONDS
		local income = who:GetAttribute("IncomePerSecond")
		if typeof(income) == "number" then
			table.insert(screen.history, income)
			if #screen.history > QUOTE_SAMPLES then
				table.remove(screen.history, 1)
			end
		end
	end
	local symbol = if who then MarketScreensController.symbol(who.DisplayName) else nil
	for _, quote in screen.quotes do
		WorldScreens.setQuote(quote, symbol, screen.history)
	end
end

function MarketScreensController.check(cameraPosition: Vector3, now: number)
	for part, screen in screens do
		if part.Parent == nil then
			screens[part] = nil
			continue
		end
		screen.near = (part.Position - cameraPosition).Magnitude <= screen.distance
		if screen.kind == "Quote" then
			-- Readings are taken even when far, so a board has a history
			-- when someone walks up to it.
			updateQuote(screen, now)
		elseif screen.kind == "Ad" and screen.near and now >= screen.nextAd then
			screen.nextAd = now + AD_SECONDS
			showAd(screen)
		end
	end
end

function MarketScreensController.step(now: number, delta: number)
	for _, screen in screens do
		if not screen.near then
			continue
		end
		for _, chart in screen.charts do
			WorldScreens.stepChart(chart, now)
		end
		for _, ticker in screen.tickers do
			WorldScreens.stepTicker(ticker, delta)
		end
	end
end

function MarketScreensController:Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		if instance:IsA("BasePart") then
			screens[instance] = nil
		end
	end)
	for _, instance in CollectionService:GetTagged(TAG) do
		add(instance)
	end

	local last = os.clock()
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		MarketScreensController.step(now, now - last)
		last = now
	end)
	while true do
		local camera = workspace.CurrentCamera
		if camera then
			MarketScreensController.check(camera.CFrame.Position, os.clock())
		end
		task.wait(CHECK_SECONDS)
	end
end

return MarketScreensController
