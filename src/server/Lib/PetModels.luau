--!strict
-- Builds every pet's model into ReplicatedStorage.Assets.Pets when the server
-- starts (PetBuilder, from Config/PetLooks), so the world, the pets window
-- and the pet shop all show the same pet. A model already there with a pet's
-- id was made by hand in Studio and is kept. The "Default" model stays for
-- anything without one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local PetBuilder = require(script.Parent.PetBuilder)

local PetModels = {}

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

-- Builds the models no pet has yet, once.
function PetModels.prepare()
	if prepared then
		return
	end
	prepared = true
	local pets = childFolder(childFolder(ReplicatedStorage, "Assets"), "Pets")
	local built, handMade, plain = 0, {}, {}
	for _, pet in Pets.list do
		if pets:FindFirstChild(pet.id) then
			table.insert(handMade, pet.id)
		else
			PetBuilder.build(pet).Parent = pets
			built += 1
			if not PetBuilder.hasLook(pet.id) then
				table.insert(plain, pet.id)
			end
		end
	end
	local kept = if #handMade > 0 then ` Kept the hand-made ones: {table.concat(handMade, ", ")}.` else ""
	print(`[PetModels] Built {built} pet models from Config/PetLooks.{kept}`)
	if #plain > 0 then
		warn(`[PetModels] No look in Config/PetLooks yet, so a plain one: {table.concat(plain, ", ")}`)
	end
end

return PetModels
