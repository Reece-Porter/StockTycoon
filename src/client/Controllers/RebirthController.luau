--!strict
-- The Rebirth button (right edge of the screen) and its window: what the next
-- rebirth needs and whether the player has it, what it resets and keeps, and
-- the income multiplier now and after. Rebirthing takes two taps. The server
-- sends Rebirths, RebirthCost and RebirthHasTier and checks everything again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.Rebirth)
local RebirthMath = require(ReplicatedStorage.Shared.RebirthMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)

local BUTTON_SIZE = UDim2.fromOffset(120, 48)
local PANEL_MAX_SIZE = Vector2.new(400, 460)
local BACKGROUND = Color3.fromRGB(20, 20, 25)
local BUTTON_COLOUR = Color3.fromRGB(45, 45, 55)
local READY = Color3.fromRGB(205, 150, 40)
local NOT_READY = Color3.fromRGB(70, 65, 55)
local DONE = "#78DC8C"
local NEEDED = "#FF7878"
-- How long "Tap again" stays up before the button resets.
local CONFIRM_SECONDS = 3

local player = Players.LocalPlayer

local RebirthController = {}

local function corner(parent: Instance)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = parent
end

local function button(text: string, colour: Color3): TextButton
	local newButton = Instance.new("TextButton")
	newButton.BackgroundColor3 = colour
	newButton.Font = Enum.Font.BuilderSansBold
	newButton.TextSize = 18
	newButton.TextColor3 = Color3.new(1, 1, 1)
	newButton.Text = text
	newButton.AutoButtonColor = true
	corner(newButton)
	return newButton
end

local function numberAttribute(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function mark(done: boolean): string
	return if done then `<font color="{DONE}">Done</font>` else `<font color="{NEEDED}">Needed</font>`
end

function RebirthController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Rebirth"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local openButton = button("Rebirth", NOT_READY)
	openButton.Name = "Open"
	openButton.AnchorPoint = Vector2.new(1, 0.5)
	openButton.Position = UDim2.new(1, -12, 0.5, 0)
	openButton.Size = BUTTON_SIZE
	openButton.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.8)
	panel.BackgroundColor3 = BACKGROUND
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	corner(panel)
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = PANEL_MAX_SIZE
	sizeLimit.Parent = panel

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.new(1, -80, 0, 44)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = 22
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local close = button("X", BUTTON_COLOUR)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(44, 44)
	close.Parent = panel

	local body = Instance.new("TextLabel")
	body.Position = UDim2.fromOffset(16, 56)
	body.Size = UDim2.new(1, -32, 1, -136)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.BuilderSansMedium
	body.TextSize = 16
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.RichText = true
	body.Parent = panel

	local go = button("Rebirth", NOT_READY)
	go.AnchorPoint = Vector2.new(0.5, 1)
	go.Position = UDim2.new(0.5, 0, 1, -12)
	go.Size = UDim2.new(1, -24, 0, 56)
	go.TextSize = 20
	go.Parent = panel

	local cash: IntValue? = nil
	local confirming = false

	local function isReady(): boolean
		local cost = numberAttribute("RebirthCost")
		return cash ~= nil and cost > 0 and cash.Value >= cost and player:GetAttribute("RebirthHasTier") == true
	end

	local function render()
		local rebirths = numberAttribute("Rebirths")
		local cost = numberAttribute("RebirthCost")
		local have = if cash then cash.Value else 0
		local hasTier = player:GetAttribute("RebirthHasTier") == true
		local tier = Tiers.byId[RebirthConfig.RequiredTier]
		local now = RebirthMath.incomeMultiplier(rebirths)
		local after = RebirthMath.incomeMultiplier(rebirths + 1)
		local ready = isReady()

		title.Text = `Rebirth ({rebirths} so far)`
		body.Text = table.concat({
			`<b>Income x{now} now, x{after} after</b>, plus slightly better odds on your own conveyor.`,
			"",
			"<b>You need</b>",
			`{mark(have >= cost)}  {Format.cash(cost)} Cash (you have {Format.cash(have)})`,
			`{mark(hasTier)}  A {tier.name} company or better, placed or in storage`,
			"",
			"<b>Resets</b>  Cash, every company, plots and floors",
			"<b>Keeps</b>  Rebirths, weapons and pets (pets go back to your Pets window)",
		}, "\n")

		openButton.BackgroundColor3 = if ready then READY else NOT_READY
		go.BackgroundColor3 = if ready then READY else NOT_READY
		go.AutoButtonColor = ready
		go.Text = if confirming then "Tap again to rebirth" else "Rebirth"
	end

	openButton.Activated:Connect(function()
		confirming = false
		render()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	go.Activated:Connect(function()
		if not isReady() then
			return
		end
		if confirming then
			confirming = false
			panel.Visible = false
			Remotes.Rebirth:FireServer()
		else
			confirming = true
			task.delay(CONFIRM_SECONDS, function()
				confirming = false
				render()
			end)
		end
		render()
	end)

	for _, name in { "Rebirths", "RebirthCost", "RebirthHasTier" } do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
	render()
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Cash comes from the player list value the server keeps up to date.
	local leaderstats = player:WaitForChild("leaderstats")
	local cashValue = leaderstats:WaitForChild("Cash")
	if cashValue:IsA("IntValue") then
		cash = cashValue
		cashValue.Changed:Connect(render)
		render()
	end
end

return RebirthController
