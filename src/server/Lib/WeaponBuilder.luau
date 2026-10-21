--!strict
-- Builds a weapon's Tool from its look in Config/WeaponLooks, for
-- WeaponModels (docs/visual-pass.md, Phase 7):
--
--   <weapon id> (Tool, can't be dropped)
--     Handle: an invisible block at the grip.
--     The look's pieces, welded to the Handle, unanchored and massless, and
--     never colliding, touched or hit by a raycast.
--
-- The Tool also says how it swings (the Swing attribute) for the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pieces = require(ReplicatedStorage.Shared.Pieces)
local Theme = require(ReplicatedStorage.Shared.Theme)
local WeaponLooks = require(ReplicatedStorage.Shared.Config.WeaponLooks)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local WeaponBuilder = {}

-- Whether the weapon has its own look in Config/WeaponLooks.
function WeaponBuilder.hasLook(weaponId: string): boolean
	return WeaponLooks.looks[weaponId] ~= nil
end

-- The weapon's Tool, named by its id, not yet parented.
function WeaponBuilder.build(weapon: Weapons.Weapon): Tool
	local tool = Instance.new("Tool")
	tool.Name = weapon.id
	tool.CanBeDropped = false
	local size = WeaponLooks.HandleSize
	local handle = Pieces.newPart(
		tool,
		"Handle",
		Enum.PartType.Block,
		Vector3.new(size, size, size),
		CFrame.new(),
		Theme.Colours.Ink
	)
	handle.Transparency = 1
	handle.CastShadow = false

	local look = WeaponLooks.looks[weapon.id]
	local plain = { Pieces.block({ 0.4, 2, 0.4 }, { 0, 1, 0 }, Theme.Colours.Locked) }
	local pieces: { Pieces.Piece } = if look then look.pieces else plain
	for index, piece in pieces do
		local part = Pieces.make(tool, `{piece.shape}{index}`, piece, CFrame.new())
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
	end
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end

	tool:SetAttribute("Built", true)
	tool:SetAttribute("Swing", if look then look.swing else "Slash")
	return tool
end

return WeaponBuilder
