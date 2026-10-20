--!strict
-- The Pets button and window, and the pet slots on bases.
--
-- The window lists every pet the player owns (the server's PetList attribute)
-- and where each one is. A pet not in a slot can be let go for good, with a
-- second tap to make sure. The player's own empty pet slots get a "Place pet"
-- prompt, which opens the window to choose a pet for that slot, and slots with
-- a pet get "Take back". Every slot with a pet, on any base, shows its name,
-- rarity and what it does. The server checks every request.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetisation = require(ReplicatedStorage.Shared.Config.Monetisation)
local PetMath = require(ReplicatedStorage.Shared.PetMath)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Beside the Weapons button, under Upgrade on the left edge.
local BUTTON_POSITION = UDim2.new(0, 96, 0.5, 48)
local BUTTON_SIZE = UDim2.fromOffset(76, 48)
local ROW_HEIGHT = 60
local PANEL_MAX_SIZE = Vector2.new(400, 480)
local BACKGROUND = Color3.fromRGB(20, 20, 25)
local BUTTON_COLOUR = Color3.fromRGB(45, 45, 55)
local PLACE = Color3.fromRGB(70, 150, 90)
local LET_GO = Color3.fromRGB(150, 60, 60)
-- How long a "Sure?" stays up before the Let go button resets.
local CONFIRM_SECONDS = 3
local LABEL_MAX_DISTANCE = 80

type Entry = { instanceId: string, petId: string, slotKey: string? }

local player = Players.LocalPlayer
local refreshers: { [BasePart]: () -> () } = {}

local PetsController = {}

-- The Extra Pet Slot pass's id, or 0 if it isn't on sale yet.
local function extraSlotPassId(): number
	for _, pass in Monetisation.Passes do
		if pass.name == "ExtraPetSlot" then
			return pass.id
		end
	end
	return 0
end

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

local function readPets(): { Entry }
	local json = player:GetAttribute("PetList")
	if typeof(json) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and typeof(decoded) == "table" then decoded else {}
end

local function rarityOrder(petId: string): number
	local pet = Pets.byId[petId]
	for index, rarity in Pets.rarities do
		if pet and rarity.id == pet.rarity then
			return index
		end
	end
	return 0
end

-- Placed pets first, then rarest first, then by name.
local function sorted(entries: { Entry }): { Entry }
	local list = table.clone(entries)
	table.sort(list, function(a, b)
		if (a.slotKey ~= nil) ~= (b.slotKey ~= nil) then
			return a.slotKey ~= nil
		end
		local rarityA, rarityB = rarityOrder(a.petId), rarityOrder(b.petId)
		if rarityA ~= rarityB then
			return rarityA > rarityB
		end
		return a.petId < b.petId
	end)
	return list
end

local function hexOf(colour: Color3): string
	return `#{colour:ToHex()}`
end

local function floorText(slotKey: string): string
	local floor = PetMath.floorOf(slotKey)
	return if floor then `On Floor {floor}` else "Placed"
end

-- The label above a pet slot with a pet in it.
local function slotLabel(part: BasePart): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "PetLabel"
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 5, 0)
	gui.MaxDistance = LABEL_MAX_DISTANCE
	gui.LightInfluence = 0
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = 16
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.RichText = true
	label.Parent = gui
	return label
end

function PetsController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Pets"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local openButton = button("Pets", BACKGROUND)
	openButton.Name = "Open"
	openButton.BackgroundTransparency = 0.2
	openButton.Position = BUTTON_POSITION
	openButton.Size = BUTTON_SIZE
	openButton.TextSize = 16
	openButton.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.75)
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

	local hint = Instance.new("TextLabel")
	hint.Position = UDim2.fromOffset(16, 52)
	hint.Size = UDim2.new(1, -32, 0, 20)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.BuilderSansMedium
	hint.TextSize = 14
	hint.TextColor3 = Color3.fromRGB(200, 200, 200)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextWrapped = true
	hint.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 80)
	list.Size = UDim2.new(1, -24, 1, -92)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list

	-- The slot the player is choosing a pet for, while the window is open
	-- from a slot's prompt.
	local choosingFor: string? = nil
	local confirming: string? = nil

	local function addRow(order: number, entry: Entry, render: () -> ())
		local pet = Pets.byId[entry.petId]
		local rarity = if pet then Pets.rarityById[pet.rarity] else nil

		local row = Instance.new("Frame")
		row.Name = "Row"
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.BackgroundColor3 = BUTTON_COLOUR
		row.BackgroundTransparency = 0.3
		corner(row)

		local text = Instance.new("TextLabel")
		text.Position = UDim2.fromOffset(12, 0)
		text.Size = UDim2.new(1, -136, 1, 0)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.BuilderSansMedium
		text.TextSize = 15
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextWrapped = true
		text.RichText = true
		local name = if pet then pet.name else entry.petId
		local rarityText = if rarity then `<font color="{hexOf(rarity.color)}">{rarity.name}</font>` else ""
		local effect = if pet then PetMath.describe(pet) else ""
		text.Text = `<b><font size="17">{name}</font></b>\n{rarityText}  ·  {effect}`
		text.Parent = row

		local slotKey = entry.slotKey
		if slotKey then
			local placed = Instance.new("TextLabel")
			placed.AnchorPoint = Vector2.new(1, 0.5)
			placed.Position = UDim2.new(1, -8, 0.5, 0)
			placed.Size = UDim2.fromOffset(116, 44)
			placed.BackgroundTransparency = 1
			placed.Font = Enum.Font.BuilderSansBold
			placed.TextSize = 16
			placed.TextColor3 = Color3.fromRGB(200, 200, 200)
			placed.Text = floorText(slotKey)
			placed.Parent = row
		else
			local choosing = choosingFor
			local isConfirming = confirming == entry.instanceId
			local label = if choosing then "Put here" elseif isConfirming then "Sure?" else "Let go"
			local action = button(label, if choosing then PLACE else LET_GO)
			action.AnchorPoint = Vector2.new(1, 0.5)
			action.Position = UDim2.new(1, -8, 0.5, 0)
			action.Size = UDim2.fromOffset(116, 44)
			action.Activated:Connect(function()
				if choosing then
					Remotes.PlacePet:FireServer(entry.instanceId, choosing)
					choosingFor = nil
					panel.Visible = false
				elseif confirming == entry.instanceId then
					confirming = nil
					Remotes.DeletePet:FireServer(entry.instanceId)
				else
					confirming = entry.instanceId
					render()
					task.delay(CONFIRM_SECONDS, function()
						if confirming == entry.instanceId then
							confirming = nil
							render()
						end
					end)
				end
			end)
			action.Parent = row
		end

		row.Parent = list
	end

	local function render()
		for _, child in list:GetChildren() do
			if child.Name == "Row" then
				child:Destroy()
			end
		end
		local entries = readPets()
		title.Text = `Pets ({#entries}/{Pets.InventoryCap})`
		local choosing = choosingFor
		if choosing then
			local floor = PetMath.floorOf(choosing)
			hint.Text = `Choose a pet for Floor {floor or "?"}. It changes that floor only.`
		elseif #entries == 0 then
			hint.Text = "No pets yet. Spin for one at the pet shop."
		else
			hint.Text = "Put pets in your floors' pet slots to boost that floor."
		end
		for index, entry in sorted(entries) do
			addRow(index, entry, render)
		end
	end

	openButton.Activated:Connect(function()
		choosingFor = nil
		render()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		choosingFor = nil
		panel.Visible = false
	end)
	player:GetAttributeChangedSignal("PetList"):Connect(render)
	render()
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Pet slots, on every base. Slot parts stream in and out, so watch the
	-- folders rather than the parts.
	local function setUpSlot(base: Instance, part: Instance)
		if not part:IsA("BasePart") or refreshers[part] then
			return
		end
		local label = slotLabel(part)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PetSlotPrompt"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Pets.SlotDistance
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = part

		local function refresh()
			local petId = part:GetAttribute("PetId")
			local pet = if typeof(petId) == "string" then Pets.byId[petId] else nil
			if pet then
				local rarity = Pets.rarityById[pet.rarity]
				local effect = PetMath.describe(pet)
				label.Text = `{pet.name}\n<font color="{hexOf(rarity.color)}">{rarity.name}</font>  ·  {effect}`
			else
				label.Text = ""
			end
			local isMine = base:GetAttribute("OwnerUserId") == player.UserId
			local unlocked = part:GetAttribute("Unlocked") == true
			local needsPass = part:GetAttribute("NeedsPass") == true and extraSlotPassId() ~= 0
			if needsPass and not unlocked then
				prompt.ActionText = "Unlock"
				prompt.ObjectText = "Extra Pet Slot pass"
			else
				prompt.ActionText = if pet then "Take back" else "Place pet"
				prompt.ObjectText = if pet then pet.name else "Pet slot"
			end
			prompt.Enabled = isMine and (unlocked or needsPass)
		end

		prompt.Triggered:Connect(function()
			local slotKey = part:GetAttribute("SlotKey")
			if typeof(slotKey) ~= "string" then
				return
			end
			if part:GetAttribute("Unlocked") ~= true then
				-- A slot only the Extra Pet Slot pass opens.
				local passId = extraSlotPassId()
				if part:GetAttribute("NeedsPass") == true and passId ~= 0 then
					MarketplaceService:PromptGamePassPurchase(player, passId)
				end
				return
			end
			if part:GetAttribute("PetId") ~= nil then
				Remotes.TakeBackPet:FireServer(slotKey)
			else
				choosingFor = slotKey
				render()
				panel.Visible = true
			end
		end)

		part.AttributeChanged:Connect(refresh)
		base.AttributeChanged:Connect(refresh)
		part.Destroying:Connect(function()
			refreshers[part] = nil
		end)
		refreshers[part] = refresh
		refresh()
	end

	local function watchBase(base: Instance)
		local floors = base:WaitForChild("Floors", 30)
		if floors == nil then
			return
		end
		local function watchFloor(floor: Instance)
			local function watchSlots(slots: Instance)
				slots.ChildAdded:Connect(function(part)
					setUpSlot(base, part)
				end)
				for _, part in slots:GetChildren() do
					setUpSlot(base, part)
				end
			end
			local slots = floor:FindFirstChild("PetSlots")
			if slots then
				watchSlots(slots)
			else
				floor.ChildAdded:Connect(function(child)
					if child.Name == "PetSlots" then
						watchSlots(child)
					end
				end)
			end
		end
		floors.ChildAdded:Connect(watchFloor)
		for _, floor in floors:GetChildren() do
			watchFloor(floor)
		end
	end

	local bases = workspace:WaitForChild("Map"):WaitForChild("Bases")
	bases.ChildAdded:Connect(function(base)
		task.spawn(watchBase, base)
	end)
	for _, base in bases:GetChildren() do
		task.spawn(watchBase, base)
	end
end

return PetsController
