--!strict
-- The pet shop screen, opened from the prompt at the pet shop
-- (Workspace.Map.Shops.PetShop.ShopPrompt). It shows the spin cost, a Spin
-- button, and the chance of every pet before anyone spins. The server rolls
-- the spin and sends the pet back with PetSpun; this only shows it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local PetMath = require(ReplicatedStorage.Shared.PetMath)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PANEL_MAX_SIZE = Vector2.new(400, 520)
local BACKGROUND = Color3.fromRGB(20, 20, 25)
local BUTTON_COLOUR = Color3.fromRGB(45, 45, 55)
local SPIN = Color3.fromRGB(205, 150, 40)
-- How long the reveal flicks through pet names before showing the result.
local REVEAL_SECONDS = 1
local REVEAL_STEP = 0.08
-- One spin is asked for at a time, so no reveal is missed. If the server says
-- no (not enough Cash, say), the button works again after this long.
local SPIN_WAIT_SECONDS = 2

local player = Players.LocalPlayer

local PetShopController = {}

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

local function label(parent: Instance, order: number, text: string, size: number, colour: Color3, bold: boolean)
	local newLabel = Instance.new("TextLabel")
	newLabel.LayoutOrder = order
	newLabel.Size = UDim2.new(1, 0, 0, size + 8)
	newLabel.BackgroundTransparency = 1
	newLabel.Font = if bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium
	newLabel.TextSize = size
	newLabel.TextColor3 = colour
	newLabel.TextXAlignment = Enum.TextXAlignment.Left
	newLabel.RichText = true
	newLabel.Text = text
	newLabel.Parent = parent
	return newLabel
end

-- A chance as a percentage without trailing zeros, e.g. 30%, 0.45%.
local function percent(chance: number): string
	local text = string.format("%.2f", chance * 100)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return `{text}%`
end

-- Runs callback(child) for the child with this name now and whenever one
-- appears later.
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

function PetShopController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PetShop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 55

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
	title.Text = "Pet shop"
	title.Parent = panel

	local close = button("X", BUTTON_COLOUR)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(44, 44)
	close.Parent = panel

	local spin = button(`Spin for a pet  ·  {Format.cash(Pets.SpinCost)}`, SPIN)
	spin.Position = UDim2.fromOffset(12, 60)
	spin.Size = UDim2.new(1, -24, 0, 52)
	spin.TextSize = 20
	spin.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(16, 122)
	list.Size = UDim2.new(1, -28, 1, -134)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list

	-- Every pet's chance, shown before anyone spins.
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	label(list, nextOrder(), "Chances for each spin:", 16, Color3.fromRGB(200, 200, 200), false)
	local totalWeight = 0
	for _, rarity in Pets.rarities do
		totalWeight += rarity.weight
	end
	for _, rarity in Pets.rarities do
		label(list, nextOrder(), `{rarity.name}  {percent(rarity.weight / totalWeight)}`, 18, rarity.color, true)
		for _, pet in Pets.byRarity[rarity.id] do
			local line = `    {pet.name}  ·  {PetMath.describe(pet)}  ·  {percent(PetMath.chance(pet))}`
			label(list, nextOrder(), line, 15, Color3.new(1, 1, 1), false)
		end
	end

	-- The reveal, over the rest of the panel.
	local reveal = Instance.new("Frame")
	reveal.Name = "Reveal"
	reveal.Position = UDim2.fromOffset(12, 60)
	reveal.Size = UDim2.new(1, -24, 1, -72)
	reveal.BackgroundColor3 = BUTTON_COLOUR
	reveal.Visible = false
	reveal.ZIndex = 5
	corner(reveal)
	reveal.Parent = panel

	local revealName = Instance.new("TextLabel")
	revealName.Position = UDim2.fromScale(0, 0.2)
	revealName.Size = UDim2.new(1, 0, 0, 48)
	revealName.BackgroundTransparency = 1
	revealName.Font = Enum.Font.BuilderSansBold
	revealName.TextSize = 30
	revealName.TextColor3 = Color3.new(1, 1, 1)
	revealName.ZIndex = 6
	revealName.Parent = reveal

	local revealDetail = Instance.new("TextLabel")
	revealDetail.Position = UDim2.new(0, 0, 0.2, 52)
	revealDetail.Size = UDim2.new(1, 0, 0, 56)
	revealDetail.BackgroundTransparency = 1
	revealDetail.Font = Enum.Font.BuilderSansBold
	revealDetail.TextSize = 20
	revealDetail.TextColor3 = Color3.new(1, 1, 1)
	revealDetail.RichText = true
	revealDetail.ZIndex = 6
	revealDetail.Parent = reveal

	local done = button("Nice!", Color3.fromRGB(70, 150, 90))
	done.AnchorPoint = Vector2.new(0.5, 1)
	done.Position = UDim2.new(0.5, 0, 1, -16)
	done.Size = UDim2.fromOffset(160, 52)
	done.ZIndex = 6
	done.Visible = false
	done.Parent = reveal

	local revealing = false
	local waitingSince: number? = nil

	spin.Activated:Connect(function()
		local now = os.clock()
		if revealing or (waitingSince and now - waitingSince < SPIN_WAIT_SECONDS) then
			return
		end
		waitingSince = now
		Remotes.SpinPet:FireServer()
	end)
	close.Activated:Connect(function()
		if not revealing then
			reveal.Visible = false
			panel.Visible = false
		end
	end)
	done.Activated:Connect(function()
		reveal.Visible = false
	end)

	Remotes.PetSpun.OnClientEvent:Connect(function(petId: unknown)
		local pet = if typeof(petId) == "string" then Pets.byId[petId] else nil
		if pet == nil then
			return
		end
		waitingSince = nil
		revealing = true
		panel.Visible = true
		reveal.Visible = true
		done.Visible = false
		revealDetail.Text = ""
		local started = os.clock()
		local index = 0
		while os.clock() - started < REVEAL_SECONDS do
			index = index % #Pets.list + 1
			revealName.Text = Pets.list[index].name
			revealName.TextColor3 = Color3.fromRGB(180, 180, 180)
			task.wait(REVEAL_STEP)
		end
		local rarity = Pets.rarityById[pet.rarity]
		revealName.Text = pet.name
		revealName.TextColor3 = rarity.color
		revealDetail.Text = `{rarity.name}\n{PetMath.describe(pet)}`
		done.Visible = true
		revealing = false
	end)

	gui.Parent = player:WaitForChild("PlayerGui")

	-- The shop's prompt. The shop is built by hand and streams in and out
	-- with distance, so watch for it rather than wait.
	local function addPrompt(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("PetShopPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PetShopPrompt"
		prompt.ActionText = "Open shop"
		prompt.ObjectText = "Pets"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Pets.ShopDistance
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			panel.Visible = true
		end)
		prompt.Parent = part
	end
	watchChild(workspace:WaitForChild("Map"), "Shops", function(shops)
		watchChild(shops, "PetShop", function(shop)
			watchChild(shop, "ShopPrompt", addPrompt)
		end)
	end)
end

return PetShopController
