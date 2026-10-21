--!strict
-- The Pets menu button and window, and the pet slots on bases.
--
-- The window has a card for every pet the player owns (the server's PetList
-- attribute) saying where it is. A pet not in a slot can be let go for good,
-- with a second tap to make sure. The player's own empty pet slots get a
-- "Place pet" prompt, which opens the window to choose a pet for that slot,
-- and slots with a pet get "Take back". Every slot with a pet, on any base,
-- shows its name, rarity and what it does. The server checks every request.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetisation = require(ReplicatedStorage.Shared.Config.Monetisation)
local PetMath = require(ReplicatedStorage.Shared.PetMath)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Badge = require(script.Parent.Parent.Ui.Kit.Badge)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Card = require(script.Parent.Parent.Ui.Kit.Card)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)
local Scroll = require(script.Parent.Parent.Ui.Kit.Scroll)

local CARD_SIZE = UDim2.fromOffset(136, 220)
local FOOTER_HEIGHT = 50
local HINT_HEIGHT = 24
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

local function floorText(slotKey: string): string
	local floor = PetMath.floorOf(slotKey)
	return if floor then `On Floor {floor}` else "Placed"
end

-- The label above a pet slot with a pet in it: its name, then its rarity and
-- what it does in the rarity's colour.
local function slotLabel(part: BasePart): (TextLabel, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PetLabel"
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(220, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 5, 0)
	gui.MaxDistance = LABEL_MAX_DISTANCE
	gui.LightInfluence = 0
	gui.Parent = part
	Make.list(gui, Enum.FillDirection.Vertical, 0)

	local name = Make.label(gui, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Button,
		colour = Theme.Colours.TextOnColour,
		outline = true,
	})
	name.LayoutOrder = 1
	name.Size = UDim2.new(1, 0, 0, 28)
	local detail = Make.label(gui, {
		font = Theme.Fonts.Body,
		size = Theme.TextSize.Small,
		outline = true,
	})
	detail.LayoutOrder = 2
	detail.Size = UDim2.new(1, 0, 0, 22)
	return name, detail
end

function PetsController:Start()
	local window = Menu.window({ title = "Pets", colour = Theme.Menu.Pets })
	local hint = Make.label(window.Body, {
		size = Theme.TextSize.Small,
		colour = Theme.Colours.TextMuted,
		alignX = Enum.TextXAlignment.Left,
		wrapped = true,
	})
	hint.Size = UDim2.new(1, 0, 0, HINT_HEIGHT)
	local grid = Scroll.grid(window.Body, CARD_SIZE)
	grid.Position = UDim2.fromOffset(0, HINT_HEIGHT)
	grid.Size = UDim2.new(1, 0, 1, -HINT_HEIGHT)

	-- The slot the player is choosing a pet for, while the window is open
	-- from a slot's prompt.
	local choosingFor: string? = nil
	local confirming: string? = nil

	local function addCard(order: number, entry: Entry, render: () -> ())
		local pet = Pets.byId[entry.petId]
		local rarityId = if pet then pet.rarity else "Common"
		local card = Card.new({
			accent = Theme.Rarities[rarityId] or Theme.Colours.Locked,
			title = if pet then pet.name else entry.petId,
			stat = if pet then PetMath.describe(pet) else "",
			badge = Badge.rarity(rarityId),
			icon = "Paw",
			footerHeight = FOOTER_HEIGHT,
			layoutOrder = order,
		})
		card.Instance.Name = "Entry"
		local slotKey = entry.slotKey
		local choosing = choosingFor
		local isConfirming = confirming == entry.instanceId
		local action = Button.new({
			text = if slotKey
				then floorText(slotKey)
				elseif choosing then "Put here"
				elseif isConfirming then "Sure?"
				else "Let go",
			colour = if slotKey
				then Theme.Colours.Locked
				elseif choosing then Theme.Colours.Cash
				else Theme.Colours.Danger,
			size = UDim2.fromScale(1, 1),
			textSize = Theme.TextSize.Body,
		})
		action.Instance.Parent = card.Footer
		if slotKey then
			action.setEnabled(false)
		end
		action.Activated:Connect(function()
			if slotKey then
				return
			elseif choosing then
				Remotes.PlacePet:FireServer(entry.instanceId, choosing)
				choosingFor = nil
				window.close()
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
		card.Instance.Parent = grid
	end

	local function render()
		for _, child in grid:GetChildren() do
			if child.Name == "Entry" then
				child:Destroy()
			end
		end
		local entries = readPets()
		window.setTitle(`Pets ({#entries}/{Pets.InventoryCap})`)
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
			addCard(index, entry, render)
		end
	end

	local menuButton = Menu.button({
		name = "Pets",
		text = "Pets",
		icon = "Paw",
		colour = Theme.Menu.Pets,
		order = 4,
		side = "Left",
	})
	menuButton.Activated:Connect(function()
		choosingFor = nil
		render()
		Menu.toggle(window)
	end)
	player:GetAttributeChangedSignal("PetList"):Connect(render)
	render()

	-- Pet slots, on every base. Slot parts stream in and out, so watch the
	-- folders rather than the parts.
	local function setUpSlot(base: Instance, part: Instance)
		if not part:IsA("BasePart") or refreshers[part] then
			return
		end
		local nameLabel, detailLabel = slotLabel(part)
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
				nameLabel.Text = pet.name
				detailLabel.Text = `{rarity.name}  ·  {PetMath.describe(pet)}`
				detailLabel.TextColor3 = Theme.Rarities[pet.rarity] or Theme.Colours.TextOnColour
			else
				nameLabel.Text = ""
				detailLabel.Text = ""
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
				Menu.open(window)
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
