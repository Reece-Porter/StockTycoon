--!strict
-- The "while you were away" popup: shows once when the server reports
-- offline earnings in the OfflineEarnings attribute (JSON: away, counted and
-- cash). The server has already added the Cash.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local OfflineConfig = require(ReplicatedStorage.Shared.Config.Offline)

local player = Players.LocalPlayer

local OfflineController = {}

function OfflineController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Offline"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 150

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.85, 0, 0, 210)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(380, 210)
	sizeLimit.Parent = panel

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(16, 12)
	title.Size = UDim2.new(1, -32, 0, 34)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = 24
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "Welcome back!"
	title.Parent = panel

	local body = Instance.new("TextLabel")
	body.Position = UDim2.fromOffset(16, 50)
	body.Size = UDim2.new(1, -32, 0, 90)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.BuilderSansMedium
	body.TextSize = 17
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextWrapped = true
	body.RichText = true
	body.Parent = panel

	local ok = Instance.new("TextButton")
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.new(0.5, 0, 1, -14)
	ok.Size = UDim2.fromOffset(160, 48)
	ok.BackgroundColor3 = Color3.fromRGB(70, 150, 90)
	ok.Font = Enum.Font.BuilderSansBold
	ok.TextSize = 20
	ok.TextColor3 = Color3.new(1, 1, 1)
	ok.Text = "Nice!"
	ok.Parent = panel
	local okCorner = Instance.new("UICorner")
	okCorner.CornerRadius = UDim.new(0, 8)
	okCorner.Parent = ok
	ok.Activated:Connect(function()
		panel.Visible = false
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
		local away = Format.longDuration(tonumber(report.away) or 0)
		local share = math.floor(OfflineConfig.IncomeShare * 100 + 0.5)
		local cap = Format.longDuration(OfflineConfig.MaxSeconds)
		body.Text = `You were away for {away}. Your companies earned <b>{Format.cash(report.cash)}</b>`
			.. `\n<font size="14" color="#BBBBBB">({share}% of your income, for up to {cap})</font>`
		panel.Visible = true
	end
	player:GetAttributeChangedSignal("OfflineEarnings"):Connect(show)
	show()

	gui.Parent = player:WaitForChild("PlayerGui")
end

return OfflineController
