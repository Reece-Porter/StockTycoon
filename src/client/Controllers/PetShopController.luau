--!strict
-- The Pet shop window, opened from the prompt at the pet shop
-- (Workspace.Map.Shops.PetShop.ShopPrompt): a big Spin button with the spin
-- cost (which rises with rebirths, or free while the player has free spins
-- from rewards), and a card for every pet with its chance, shown before anyone
-- spins. The server rolls the spin and sends the pet back with PetSpun; this
-- only shows it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local PetMath = require(ReplicatedStorage.Shared.PetMath)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Badge = require(script.Parent.Parent.Ui.Kit.Badge)
local Button = require(script.Parent.Parent.Ui.Kit.Button)
local Card = require(script.Parent.Parent.Ui.Kit.Card)
local Icons = require(script.Parent.Parent.Ui.Kit.Icons)
local Make = require(script.Parent.Parent.Ui.Kit.Make)
local Menu = require(script.Parent.Parent.Ui.Menu)
local Scroll = require(script.Parent.Parent.Ui.Kit.Scroll)

local CARD_SIZE = UDim2.fromOffset(132, 176)
local SPIN_HEIGHT = 60
-- How long the reveal flicks through pet names before showing the result.
local REVEAL_SECONDS = 1
local REVEAL_STEP = 0.08
-- One spin is asked for at a time, so no reveal is missed. If the server says
-- no (not enough Cash, say), the button works again after this long.
local SPIN_WAIT_SECONDS = 2

local player = Players.LocalPlayer

local PetShopController = {}

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
	local window = Menu.window({ title = "Pet shop", colour = Theme.Menu.Pets })

	local spin = Button.new({
		text = "",
		icon = "Paw",
		colour = Theme.Colours.Gold,
		size = UDim2.new(1, 0, 0, SPIN_HEIGHT),
	})
	spin.Instance.Parent = window.Body
	-- Free spins from rewards are used first.
	local function showCost()
		local tokens = player:GetAttribute("SpinTokens")
		if typeof(tokens) == "number" and tokens > 0 then
			spin.setText(`Spin  ·  Free ({tokens} left)`)
			return
		end
		local rebirths = player:GetAttribute("Rebirths")
		local cost = PetMath.spinCost(if typeof(rebirths) == "number" then rebirths else 0)
		spin.setText(`Spin  ·  {Format.cash(cost)}`)
	end
	player:GetAttributeChangedSignal("Rebirths"):Connect(showCost)
	player:GetAttributeChangedSignal("SpinTokens"):Connect(showCost)
	showCost()

	-- Every pet's chance, rarest last, shown before anyone spins.
	local top = SPIN_HEIGHT + Theme.Size.Gap
	local grid = Scroll.grid(window.Body, CARD_SIZE)
	grid.Position = UDim2.fromOffset(0, top)
	grid.Size = UDim2.new(1, 0, 1, -top)
	local totalWeight = 0
	for _, rarity in Pets.rarities do
		totalWeight += rarity.weight
	end
	local order = 0
	for _, rarity in Pets.rarities do
		for _, pet in Pets.byRarity[rarity.id] do
			order += 1
			local card = Card.new({
				accent = Theme.Rarities[rarity.id] or Theme.Colours.Locked,
				title = pet.name,
				stat = `{percent(PetMath.chance(pet))}  ·  {PetMath.describe(pet)}`,
				badge = Badge.new(`{rarity.name} {percent(rarity.weight / totalWeight)}`, Theme.Rarities[rarity.id]),
				icon = "Paw",
				size = CARD_SIZE,
				layoutOrder = order,
			})
			card.Instance.Parent = grid
		end
	end

	-- The reveal, over the rest of the window.
	local reveal = Instance.new("Frame")
	reveal.Name = "Reveal"
	reveal.Position = UDim2.fromOffset(0, top)
	reveal.Size = UDim2.new(1, 0, 1, -top)
	reveal.BackgroundColor3 = Theme.Colours.Card
	reveal.Visible = false
	reveal.ZIndex = 5
	reveal.Active = true
	Make.corner(reveal, Theme.Corner.Large)
	local revealOutline = Make.outline(reveal, Theme.Colours.Ink, Theme.Stroke.Thick)
	reveal.Parent = window.Body
	local paw = Icons.make("Paw", 64, Theme.Colours.Locked)
	paw.AnchorPoint = Vector2.new(0.5, 0)
	paw.Position = UDim2.fromScale(0.5, 0.08)
	paw.ZIndex = 6
	paw.Parent = reveal
	local revealName = Make.label(reveal, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Big,
		colour = Theme.Colours.TextMuted,
		outline = true,
	})
	revealName.Position = UDim2.new(0, 0, 0.08, 72)
	revealName.Size = UDim2.new(1, 0, 0, 44)
	revealName.ZIndex = 6
	local revealDetail = Make.label(reveal, {
		size = Theme.TextSize.Body,
		colour = Theme.Colours.Text,
	})
	revealDetail.Position = UDim2.new(0, 0, 0.08, 120)
	revealDetail.Size = UDim2.new(1, 0, 0, 24)
	revealDetail.ZIndex = 6
	local done = Button.new({ text = "Nice!", colour = Theme.Colours.Cash, size = UDim2.fromOffset(160, 56) })
	done.Instance.AnchorPoint = Vector2.new(0.5, 1)
	done.Instance.Position = UDim2.new(0.5, 0, 1, -12)
	done.Instance.ZIndex = 6
	done.Instance.Visible = false
	done.Instance.Parent = reveal
	done.Activated:Connect(function()
		reveal.Visible = false
	end)

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

	Remotes.PetSpun.OnClientEvent:Connect(function(petId: unknown)
		local pet = if typeof(petId) == "string" then Pets.byId[petId] else nil
		if pet == nil then
			return
		end
		waitingSince = nil
		revealing = true
		Menu.open(window)
		reveal.Visible = true
		done.Instance.Visible = false
		revealDetail.Text = ""
		revealOutline.Color = Theme.Colours.Ink
		local started = os.clock()
		local index = 0
		while os.clock() - started < REVEAL_SECONDS do
			index = index % #Pets.list + 1
			revealName.Text = Pets.list[index].name
			revealName.TextColor3 = Theme.Colours.TextMuted
			task.wait(REVEAL_STEP)
		end
		local rarity = Pets.rarityById[pet.rarity]
		local colour = Theme.Rarities[pet.rarity] or Theme.Colours.Text
		revealName.Text = pet.name
		revealName.TextColor3 = colour
		revealOutline.Color = colour
		revealDetail.Text = `{rarity.name}  ·  {PetMath.describe(pet)}`
		done.Instance.Visible = true
		revealing = false
	end)

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
			Menu.open(window)
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
