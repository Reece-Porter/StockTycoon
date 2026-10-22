--!strict
-- Carrying a company (docs/visual-pass.md, Phase 9): whoever carries one
-- holds it up over their head with both arms, and it glows softly in its
-- tier's colour. The server welds the company over the head (CarryService's
-- CarriedCompany model) and says which it is (the carrier's
-- CarryingCompanyId attribute); this only changes how it looks, on each
-- player's own screen, and puts the arms back when they let go.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Theme = require(ReplicatedStorage.Shared.Theme)

local HELD_NAME = "CarriedCompany"
-- How far each arm turns up from hanging down: nearly straight up.
local RAISE = math.rad(165)
local GLOW_FILL = 0.82
local GLOW_OUTLINE = 0.3

type Joint = { motor: Motor6D, rest: CFrame }
type Carrier = { joints: { Joint }, glow: Highlight? }

local carriers: { [Model]: Carrier } = {}

local CarryFxController = {}

-- The shoulder joints and how each turns to raise its arm: R15 shoulders
-- swing forward and up round their x axis, R6 shoulders round their z axis.
local function shoulders(character: Model): { { motor: Motor6D, turn: CFrame } }
	local found = {}
	local function add(holder: Instance?, name: string, turn: CFrame)
		local motor = holder and holder:FindFirstChild(name)
		if motor and motor:IsA("Motor6D") then
			table.insert(found, { motor = motor, turn = turn })
		end
	end
	add(character:FindFirstChild("RightUpperArm"), "RightShoulder", CFrame.Angles(RAISE, 0, 0))
	add(character:FindFirstChild("LeftUpperArm"), "LeftShoulder", CFrame.Angles(RAISE, 0, 0))
	local torso = character:FindFirstChild("Torso")
	add(torso, "Right Shoulder", CFrame.Angles(0, 0, RAISE))
	add(torso, "Left Shoulder", CFrame.Angles(0, 0, -RAISE))
	return found
end

-- The glow's colour: the tier of what the carrier says they hold.
local function tierColour(character: Model): Color3
	local carrier = Players:GetPlayerFromCharacter(character)
	local companyId = carrier and carrier:GetAttribute("CarryingCompanyId")
	local company = if typeof(companyId) == "string" then Companies.byId[companyId] else nil
	return if company then Theme.Tiers[company.tier] or Theme.Colours.Gold else Theme.Colours.Gold
end

function CarryFxController.hold(character: Model)
	local held = character:FindFirstChild(HELD_NAME)
	if carriers[character] or held == nil or not held:IsA("Model") then
		return
	end
	local carrier: Carrier = { joints = {} }
	for _, shoulder in shoulders(character) do
		table.insert(carrier.joints, { motor = shoulder.motor, rest = shoulder.motor.C0 })
		shoulder.motor.C0 = shoulder.motor.C0 * shoulder.turn
	end
	local colour = tierColour(character)
	local glow = Instance.new("Highlight")
	glow.Name = "CarryGlow"
	glow.FillColor = colour
	glow.OutlineColor = colour
	glow.FillTransparency = GLOW_FILL
	glow.OutlineTransparency = GLOW_OUTLINE
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Adornee = held
	glow.Parent = held
	carrier.glow = glow
	carriers[character] = carrier
end

function CarryFxController.letGo(character: Model)
	local carrier = carriers[character]
	if carrier == nil then
		return
	end
	carriers[character] = nil
	for _, joint in carrier.joints do
		joint.motor.C0 = joint.rest
	end
	local glow = carrier.glow
	if glow then
		glow:Destroy()
	end
end

local function watchCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child.Name == HELD_NAME then
			CarryFxController.hold(character)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child.Name == HELD_NAME then
			CarryFxController.letGo(character)
		end
	end)
	character.AncestryChanged:Connect(function()
		if character.Parent == nil then
			carriers[character] = nil
		end
	end)
	CarryFxController.hold(character)
end

local function watchPlayer(other: Player)
	other.CharacterAdded:Connect(watchCharacter)
	if other.Character then
		watchCharacter(other.Character)
	end
	-- The tier can arrive after the model: recolour the glow when it does.
	other:GetAttributeChangedSignal("CarryingCompanyId"):Connect(function()
		local character = other.Character
		local carrier = character and carriers[character]
		local glow = carrier and carrier.glow
		if character and glow then
			local colour = tierColour(character)
			glow.FillColor = colour
			glow.OutlineColor = colour
		end
	end)
end

function CarryFxController:Start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
end

return CarryFxController
