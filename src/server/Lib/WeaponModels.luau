--!strict
-- Builds every weapon's Tool into ReplicatedStorage.Assets.Weapons when the
-- server starts (WeaponBuilder, from Config/WeaponLooks), so the shop, the
-- hands and the shop's display all show the same weapon. Earlier map
-- scripts left plainer Tools there, so a Tool already there is only kept if
-- it has a HandMade attribute (set it on any Tool made by hand in Studio).
-- The "Default" Tool stays for anything without one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local WeaponBuilder = require(script.Parent.WeaponBuilder)

local WeaponModels = {}

local prepared = false

local function childFolder(parent: Instance, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

-- Builds the Tools, once.
function WeaponModels.prepare()
	if prepared then
		return
	end
	prepared = true
	local weapons = childFolder(childFolder(ReplicatedStorage, "Assets"), "Weapons")
	local built, handMade = 0, {}
	for _, weapon in Weapons.list do
		local existing = weapons:FindFirstChild(weapon.id)
		if existing and existing:GetAttribute("HandMade") == true then
			table.insert(handMade, weapon.id)
			continue
		end
		if existing then
			existing:Destroy()
		end
		WeaponBuilder.build(weapon).Parent = weapons
		built += 1
	end
	local kept = if #handMade > 0 then ` Kept the hand-made ones: {table.concat(handMade, ", ")}.` else ""
	print(`[WeaponModels] Built {built} weapons from Config/WeaponLooks.{kept}`)
end

-- A still copy of a weapon for display: its Tool's visible parts, anchored,
-- as a model whose pivot is the grip.
function WeaponModels.display(weaponId: string): Model?
	WeaponModels.prepare()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Weapons")
	local tool = folder and folder:FindFirstChild(weaponId)
	local handle = tool and tool:FindFirstChild("Handle")
	if tool == nil or handle == nil or not handle:IsA("BasePart") then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = `Display{weaponId}`
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local copy = part:Clone()
			for _, child in copy:GetChildren() do
				if not (child:IsA("DataModelMesh") or child:IsA("Decal")) then
					child:Destroy()
				end
			end
			copy.Anchored = true
			copy.CFrame = handle.CFrame:ToObjectSpace(part.CFrame)
			copy.Parent = model
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

return WeaponModels
