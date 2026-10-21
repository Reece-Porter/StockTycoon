--!strict
-- The "Welcome back!" popup: shows once when the server reports offline
-- earnings in the OfflineEarnings attribute (JSON: away, counted and cash),
-- with the amount counting up. The server has already added the Cash.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local OfflineConfig = require(ReplicatedStorage.Shared.Config.Offline)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local CountUp = require(script.Parent.Parent.Ui.Kit.CountUp)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)

local player = Players.LocalPlayer

local OfflineController = {}

function OfflineController:Start()
	local window = Menu.window({
		title = "Welcome back!",
		colour = Theme.Colours.Cash,
		maxSize = Vector2.new(400, 300),
		displayOrder = 70,
	})
	local away = Make.label(window.Body, {
		size = Theme.TextSize.Body,
		colour = Theme.Colours.Text,
		wrapped = true,
	})
	away.Size = UDim2.new(1, 0, 0, 24)

	local amountRow = Instance.new("Frame")
	amountRow.Position = UDim2.fromOffset(0, 28)
	amountRow.Size = UDim2.new(1, 0, 0, 52)
	amountRow.BackgroundTransparency = 1
	amountRow.Parent = window.Body
	local rowLayout = Make.list(amountRow, Enum.FillDirection.Horizontal, Theme.Size.Gap)
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	Icons.make("Cash", 44).Parent = amountRow
	local amount = Make.label(amountRow, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Big,
		colour = Theme.Colours.Cash,
		outline = true,
	})
	amount.LayoutOrder = 2
	amount.Size = UDim2.fromScale(0, 1)
	amount.AutomaticSize = Enum.AutomaticSize.X
	local counter = CountUp.new(amount, Format.cash, 0)

	local note = Make.label(window.Body, {
		size = Theme.TextSize.Small,
		colour = Theme.Colours.TextMuted,
		wrapped = true,
	})
	note.Position = UDim2.fromOffset(0, 84)
	note.Size = UDim2.new(1, 0, 0, 36)

	local ok = Button.new({ text = "Nice!", colour = Theme.Colours.Cash, size = UDim2.fromOffset(170, 56) })
	ok.Instance.AnchorPoint = Vector2.new(0.5, 1)
	ok.Instance.Position = UDim2.fromScale(0.5, 1)
	ok.Instance.Parent = window.Body
	ok.Activated:Connect(function()
		window.close()
	end)

	local function show()
		local json = player:GetAttribute("OfflineEarnings")
		if typeof(json) ~= "string" then
			return
		end
		local decoded, report = pcall(HttpService.JSONDecode, HttpService, json)
		if not decoded or typeof(report) ~= "table" or typeof(report.cash) ~= "number" then
			return
		end
		local share = math.floor(OfflineConfig.IncomeShare * 100 + 0.5)
		local cap = Format.longDuration(OfflineConfig.MaxSeconds)
		away.Text = `You were away for {Format.longDuration(tonumber(report.away) or 0)}. Your companies earned`
		note.Text = `{share}% of your income, for up to {cap}`
		Menu.open(window)
		counter.set(report.cash)
	end
	player:GetAttributeChangedSignal("OfflineEarnings"):Connect(show)
	show()
end

return OfflineController
