--!strict
-- The models screens show in cards: from ReplicatedStorage.Assets, named by
-- id, or the "Default" model if there is none (the same rule the server uses
-- in the world). Company models are built there by the server when it
-- starts (CompanyModels), unless one was made by hand. Nil if neither is
-- there yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VariantLayer = require(ReplicatedStorage.Shared.VariantLayer)

local Models = {}

local function find(folderName: string, id: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(folderName)
	if folder == nil then
		return nil
	end
	return folder:FindFirstChild(id) or folder:FindFirstChild("Default")
end

function Models.company(companyId: string): Instance?
	return find("Companies", companyId)
end

-- A company's model with a variant's look over it (VariantLayer), or its
-- plain model without a variant. The variant's look goes on a copy, so the
-- stored model is never changed.
function Models.companyVariant(companyId: string, variantId: string?): Instance?
	local model = Models.company(companyId)
	if model == nil or variantId == nil or not model:IsA("Model") then
		return model
	end
	local copy = model:Clone()
	VariantLayer.apply(copy, variantId)
	return copy
end

-- A weapon's Tool.
function Models.weapon(weaponId: string): Instance?
	return find("Weapons", weaponId)
end

return Models
