--!strict
-- The models screens show in cards: from ReplicatedStorage.Assets, named by
-- id, or the "Default" model until one exists (the same rule the server uses
-- in the world). Nil if neither is there yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- A weapon's Tool.
function Models.weapon(weaponId: string): Instance?
	return find("Weapons", weaponId)
end

return Models
