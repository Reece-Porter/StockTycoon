--!strict
-- The pet reveal after a spin (docs/visual-pass.md, Phase 7), drawn in a
-- frame the pet shop gives it: an egg shakes, cracks, bursts in the rarity's
-- colour, and the pet pops out with its name and rarity badge. Rarer pets
-- shake longer and burst bigger, with confetti for Legendary and Mythic.
-- Tapping anywhere skips straight to the pet. The server has already rolled
-- the pet; this only shows it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PetMath = require(ReplicatedStorage.Shared.PetMath)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Badge = require(script.Parent.Kit.Badge)
local Button = require(script.Parent.Kit.Button)
local Card = require(script.Parent.Kit.Card)
local Make = require(script.Parent.Kit.Make)
local Models = require(script.Parent.Models)

local EGG_SIZE = Vector2.new(110, 140)
-- Seconds the egg shakes: the first for Common, and more for each rarity up.
local SHAKE_SECONDS = 0.7
local SHAKE_STEP = 0.3
local SHAKE_SPEED = 38
local CONFETTI = 18
local PET_SIZE = 170
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type Reveal = {
	play: (petId: string) -> (),
	skip: () -> (),
	isPlaying: () -> boolean,
	Done: Instance,
}

local PetReveal = {}

local function circle(parent: Instance, name: string, size: number, colour: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = colour
	frame.BorderSizePixel = 0
	Make.corner(frame, 999)
	frame.Parent = parent
	return frame
end

function PetReveal.new(frame: Frame, onDone: () -> ()): Reveal
	local centre = UDim2.fromScale(0.5, 0.38)

	-- The egg, with spots and the cracks that show as it gets ready.
	local egg = Instance.new("Frame")
	egg.Name = "Egg"
	egg.AnchorPoint = Vector2.new(0.5, 0.5)
	egg.Position = centre
	egg.Size = UDim2.fromOffset(EGG_SIZE.X, EGG_SIZE.Y)
	egg.BackgroundColor3 = Theme.Colours.Card
	egg.ZIndex = 7
	Make.corner(egg, 999)
	Make.outline(egg, Theme.Colours.Ink, Theme.Stroke.Thick)
	egg.Parent = frame
	for index, spot in { { 0.3, 0.3, 26 }, { 0.68, 0.45, 20 }, { 0.42, 0.72, 30 } } do
		local dot = circle(egg, `Spot{index}`, spot[3], Theme.tint(Theme.Colours.Primary, 0.45))
		dot.Position = UDim2.fromScale(spot[1], spot[2])
		dot.ZIndex = 8
	end
	local cracks: { Frame } = {}
	for index, crack in { { 0.3, 0.42, 30, 38 }, { 0.5, 0.4, 28, -40 }, { 0.7, 0.43, 26, 35 } } do
		local line = Instance.new("Frame")
		line.Name = `Crack{index}`
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(crack[1], crack[2])
		line.Size = UDim2.fromOffset(crack[3], 4)
		line.Rotation = crack[4]
		line.BackgroundColor3 = Theme.Colours.Ink
		line.BorderSizePixel = 0
		line.ZIndex = 9
		line.Visible = false
		line.Parent = egg
		table.insert(cracks, line)
	end

	-- What the burst draws in: rays, a flash and confetti.
	local burst = Instance.new("Frame")
	burst.Name = "Burst"
	burst.Size = UDim2.fromScale(1, 1)
	burst.BackgroundTransparency = 1
	burst.ClipsDescendants = true
	burst.ZIndex = 6
	burst.Parent = frame

	-- The pet, its name, its rarity and what it does.
	local petHolder = Instance.new("Frame")
	petHolder.Name = "PetView"
	petHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	petHolder.Position = centre
	petHolder.Size = UDim2.fromOffset(PET_SIZE, PET_SIZE)
	petHolder.BackgroundTransparency = 1
	petHolder.ZIndex = 7
	petHolder.Visible = false
	petHolder.Parent = frame
	local petScale = Instance.new("UIScale")
	petScale.Parent = petHolder
	local name = Make.label(frame, {
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Big,
		colour = Theme.Colours.Text,
		outline = true,
	})
	name.Name = "PetName"
	name.Position = UDim2.new(0, 0, 0.38, PET_SIZE / 2 + 4)
	name.Size = UDim2.new(1, 0, 0, 40)
	name.ZIndex = 7
	local badgeRow = Instance.new("Frame")
	badgeRow.Name = "BadgeRow"
	badgeRow.Position = UDim2.new(0, 0, 0.38, PET_SIZE / 2 + 48)
	badgeRow.Size = UDim2.new(1, 0, 0, 26)
	badgeRow.BackgroundTransparency = 1
	badgeRow.ZIndex = 7
	badgeRow.Parent = frame
	local badgeLayout = Make.list(badgeRow, Enum.FillDirection.Horizontal, Theme.Size.Gap)
	badgeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local detail = Make.label(frame, { size = Theme.TextSize.Body, colour = Theme.Colours.Text })
	detail.Name = "Detail"
	detail.Position = UDim2.new(0, 0, 0.38, PET_SIZE / 2 + 80)
	detail.Size = UDim2.new(1, 0, 0, 24)
	detail.ZIndex = 7

	local done = Button.new({ text = "Nice!", colour = Theme.Colours.Cash, size = UDim2.fromOffset(160, 56) })
	done.Instance.Name = "Done"
	done.Instance.AnchorPoint = Vector2.new(0.5, 1)
	done.Instance.Position = UDim2.new(0.5, 0, 1, -12)
	done.Instance.ZIndex = 8
	done.Instance.Visible = false
	done.Instance.Parent = frame
	done.Activated:Connect(onDone)

	-- Over everything while it plays: a tap skips to the pet.
	local catcher = Instance.new("TextButton")
	catcher.Name = "Skip"
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.BackgroundTransparency = 1
	catcher.Text = ""
	catcher.ZIndex = 20
	catcher.Visible = false
	catcher.Parent = frame

	local playing = false
	local skipped = false
	catcher.Activated:Connect(function()
		skipped = true
	end)

	local function clear()
		for _, child in burst:GetChildren() do
			child:Destroy()
		end
		for _, child in petHolder:GetChildren() do
			if not child:IsA("UIScale") then
				child:Destroy()
			end
		end
		for _, child in badgeRow:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		for _, crack in cracks do
			crack.Visible = false
		end
		egg.Rotation = 0
		egg.Visible = false
		petHolder.Visible = false
		name.Text = ""
		detail.Text = ""
		done.Instance.Visible = false
	end

	local function explode(colour: Color3, rarityIndex: number)
		local flash = circle(burst, "Flash", 40, colour)
		flash.Position = centre
		TweenService:Create(flash, FADE, { Size = UDim2.fromOffset(420, 420), BackgroundTransparency = 1 }):Play()
		local rays = 4 + rarityIndex * 2
		for index = 1, rays do
			local ray = Instance.new("Frame")
			ray.Name = "Ray"
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = centre
			ray.Size = UDim2.fromOffset(8, 160 + rarityIndex * 40)
			ray.Rotation = index * 180 / rays
			ray.BackgroundColor3 = Theme.tint(colour, 0.35)
			ray.BackgroundTransparency = 0.35
			ray.BorderSizePixel = 0
			ray.Parent = burst
			TweenService:Create(ray, FADE, { BackgroundTransparency = 1, Rotation = ray.Rotation + 25 }):Play()
		end
		if rarityIndex >= 5 then
			local colours = { colour, Theme.Colours.Gold, Theme.Colours.Card, Theme.tint(colour, 0.5) }
			for index = 1, CONFETTI do
				local bit = Instance.new("Frame")
				bit.Name = "Confetti"
				bit.AnchorPoint = Vector2.new(0.5, 0.5)
				bit.Position = centre
				bit.Size = UDim2.fromOffset(10, 6)
				bit.BackgroundColor3 = colours[index % #colours + 1]
				bit.BorderSizePixel = 0
				bit.Parent = burst
				local angle = index / CONFETTI * 2 * math.pi
				local reach = 150 + (index % 3) * 40
				local goal = UDim2.new(0.5, math.cos(angle) * reach, 0.38, math.sin(angle) * reach)
				TweenService:Create(bit, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = goal,
					Rotation = 360,
					BackgroundTransparency = 1,
				}):Play()
			end
		end
	end

	local function showPet(pet: Pets.Pet, colour: Color3)
		local model = Models.pet(pet.id)
		if model then
			Card.showModel(petHolder, model, false)
		end
		petHolder.Visible = true
		petScale.Scale = 0.2
		TweenService:Create(petScale, POP, { Scale = 1 }):Play()
		name.Text = pet.name
		name.TextColor3 = colour
		local badge = Badge.rarity(pet.rarity)
		badge.Parent = badgeRow
		detail.Text = PetMath.describe(pet)
	end

	local reveal = {} :: Reveal
	reveal.Done = done.Instance

	function reveal.play(petId: string)
		local pet = Pets.byId[petId]
		if pet == nil then
			return
		end
		playing = true
		skipped = false
		clear()
		local rarityIndex = 1
		for index, rarity in Pets.rarities do
			if rarity.id == pet.rarity then
				rarityIndex = index
			end
		end
		local colour = Theme.Rarities[pet.rarity] or Theme.Colours.Text
		local shake = SHAKE_SECONDS + SHAKE_STEP * (rarityIndex - 1)

		catcher.Visible = true
		egg.Visible = true
		local started = os.clock()
		while not skipped do
			local t = os.clock() - started
			if t >= shake then
				break
			end
			local amplitude = 4 + 12 * t / shake
			egg.Rotation = math.sin(t * SHAKE_SPEED) * amplitude
			for index, crack in cracks do
				crack.Visible = t >= shake * (0.4 + index * 0.15)
			end
			task.wait()
		end
		egg.Visible = false
		explode(colour, rarityIndex)
		showPet(pet, colour)
		catcher.Visible = false
		done.Instance.Visible = true
		playing = false
	end

	function reveal.skip()
		skipped = true
	end

	function reveal.isPlaying(): boolean
		return playing
	end

	clear()
	return reveal
end

return PetReveal
