--!strict
-- The photo booth (docs/visual-pass.md, Phase 10), built far out past the
-- city by studio/BuildMap.luau as Workspace.Map.PhotoBooth. Admins pose
-- companies, pets and a copy of a base there for the screenshots behind
-- icons and thumbnails (docs/ART_BRIEFS.md), through AdminService's /booth,
-- /pose, /backdrop and /boothcam commands.
--
-- Everything posed is a still copy in the booth's Posed folder. Nothing in
-- the game looks there, and it all goes with /pose clear or when the server
-- shuts down. The client looks through the booth's cameras (the BoothCamera
-- attribute, PhotoBoothController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)
local CompanyModels = require(script.Parent.CompanyModels)

local MISSING = "There's no photo booth in the map yet: run studio/BuildMap.luau again."
-- How much bigger things are posed on each spot, to fill the shot.
local SPOT_SCALE: { [string]: number } = { Hero = 1.6, Left = 1.2, Right = 1.2 }
local MAX_SCALE = 4

local PhotoBooth = {}

-- The spots a company or pet can stand on.
PhotoBooth.Spots = { "Hero", "Left", "Right" }
-- The shots /boothcam can look through.
PhotoBooth.Cameras = { "Icon", "Wide", "Base" }

local function booth(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("PhotoBooth")
end

local function spot(name: string): BasePart?
	local found = booth()
	local spots = found and found:FindFirstChild("Spots")
	local part = spots and spots:FindFirstChild(`Spot_{name}`)
	return if part and part:IsA("BasePart") then part else nil
end

local function posed(): Instance?
	local found = booth()
	if found == nil then
		return nil
	end
	local existing = found:FindFirstChild("Posed")
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Posed"
	folder.Parent = found
	return folder
end

-- Lower case without spaces, dashes or underscores, for matching names.
local function plain(text: string): string
	return string.lower((string.gsub(text, "[%s%-_]", "")))
end

-- The name in list that matches text, ignoring case and spaces.
local function match(list: { string }, text: string): string?
	for _, name in list do
		if plain(name) == plain(text) then
			return name
		end
	end
	return nil
end

local function stillCopy(model: Model): Model
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	return model
end

-- A posable copy of a company (by id or name) or a pet (by id or name), and
-- what it is called.
local function modelFor(what: string, variantId: string?): (Model?, string?)
	for _, company in Companies.list do
		if plain(company.id) == plain(what) or plain(company.name) == plain(what) then
			return CompanyModels.clone(company.id, true, variantId), company.name
		end
	end
	for _, pet in Pets.list do
		if plain(pet.id) == plain(what) or plain(pet.name) == plain(what) then
			local assets = ReplicatedStorage:FindFirstChild("Assets")
			local folder = assets and assets:FindFirstChild("Pets")
			local template = folder and folder:FindFirstChild(pet.id)
			if template and template:IsA("Model") then
				return template:Clone(), pet.name
			end
			return nil, pet.name
		end
	end
	return nil, nil
end

-- Takes a player to the booth, out of shot beside the podiums.
function PhotoBooth.goTo(player: Player): string
	local found = booth()
	local stand = found and found:FindFirstChild("Stand")
	local character = player.Character
	if stand == nil or not stand:IsA("BasePart") then
		return MISSING
	end
	if character == nil then
		return "You need a character to go there."
	end
	character:PivotTo(stand.CFrame + Vector3.new(0, 3, 0))
	return "Welcome to the photo booth. /pose hero <company or pet>, /backdrop <colour>, /boothcam icon, then take your screenshot."
end

-- Poses a company or pet on a spot (Hero, Left or Right), replacing what was
-- there. variant and size are optional.
function PhotoBooth.pose(spotText: string, what: string, variantText: string?, size: number?): string
	local spotName = match(PhotoBooth.Spots, spotText)
	if spotName == nil then
		return `Pick a spot: {table.concat(PhotoBooth.Spots, ", ")}.`
	end
	local part = spot(spotName)
	local folder = posed()
	if part == nil or folder == nil then
		return MISSING
	end
	local variantId: string? = nil
	if variantText then
		local ids = {}
		for _, variant in Variants.list do
			table.insert(ids, variant.id)
		end
		variantId = match(ids, variantText)
		if variantId == nil then
			return `No variant called "{variantText}". Try one of: {table.concat(ids, ", ")}.`
		end
	end
	local model, name = modelFor(what, variantId)
	if model == nil then
		return if name
			then `The {name} model isn't built yet: try again once the game has started.`
			else `No company or pet called "{what}".`
	end
	PhotoBooth.clear(spotName)
	local scale = math.clamp(size or SPOT_SCALE[spotName] or 1, 0.25, MAX_SCALE)
	model:ScaleTo(model:GetScale() * scale)
	CompanyModels.standOn(model, part.CFrame.Position + Vector3.new(0, part.Size.Y / 2, 0), part.CFrame)
	model.Name = spotName
	stillCopy(model).Parent = folder
	return `Posed the {name} on {spotName}.`
end

-- Poses a copy of a base, with the companies on its plots and the pets in
-- its slots, on the stage, its front towards the camera.
function PhotoBooth.poseBase(base: Model, baseName: string): string
	local part = spot("Base")
	local folder = posed()
	if part == nil or folder == nil then
		return MISSING
	end
	PhotoBooth.clear("Base")
	local holder = Instance.new("Model")
	holder.Name = "Base"
	-- The base's own frame (its pivot) turned so its front, along its x,
	-- faces the camera (-z), sitting on the stage.
	local from = base:GetPivot()
	local to = CFrame.new(part.CFrame.Position + Vector3.new(0, 1 - part.Size.Y / 2, 0))
		* CFrame.Angles(0, math.pi / 2, 0)
	local function copyOver(model: Model)
		local copy = stillCopy(model:Clone())
		copy:PivotTo(to * from:ToObjectSpace(model:GetPivot()))
		copy.Parent = holder
	end
	copyOver(base)
	for _, folderName in { "PlacedCompanies", "PlacedPets" } do
		local placed = workspace:FindFirstChild(folderName)
		if placed then
			for _, model in placed:GetChildren() do
				local onBase = model:GetAttribute("BaseName") == baseName
					or string.sub(model.Name, 1, #baseName + 1) == `{baseName}/`
				if model:IsA("Model") and onBase then
					copyOver(model)
				end
			end
		end
	end
	holder.Parent = folder
	return "Posed a copy of your base on the stage. /boothcam base to look at it."
end

-- Takes away what's on a spot (or everything, with no spot).
function PhotoBooth.clear(spotName: string?)
	local folder = posed()
	if folder == nil then
		return
	end
	for _, child in folder:GetChildren() do
		if spotName == nil or child.Name == spotName then
			child:Destroy()
		end
	end
end

-- Paints the backdrop one of Theme.Booth.Backdrops.
function PhotoBooth.backdrop(colourText: string): string
	local names = {}
	for name in Theme.Booth.Backdrops do
		table.insert(names, name)
	end
	table.sort(names)
	local name = match(names, colourText)
	if name == nil then
		return `Pick a colour: {table.concat(names, ", ")}.`
	end
	local found = booth()
	local backdrop = found and found:FindFirstChild("Backdrop")
	if backdrop == nil then
		return MISSING
	end
	for _, part in backdrop:GetChildren() do
		if part:IsA("BasePart") then
			part.Color = Theme.Booth.Backdrops[name]
		end
	end
	return `The backdrop is {name} now.`
end

-- Has this player's screen look through one of the booth's cameras, with the
-- HUD hidden; or ("free") just hide the HUD, for shots anywhere in the map;
-- or ("off") go back to normal.
function PhotoBooth.camera(player: Player, shotText: string): string
	if plain(shotText) == "off" then
		player:SetAttribute("BoothCamera", nil)
		return "Back to the normal camera."
	end
	if plain(shotText) == "free" then
		player:SetAttribute("BoothCamera", "Free")
		return "The HUD is hidden: move the camera anywhere for your shot. /boothcam off when you're done."
	end
	local shot = match(PhotoBooth.Cameras, shotText)
	if shot == nil then
		return `Pick a camera: {table.concat(PhotoBooth.Cameras, ", ")}, free or off.`
	end
	if booth() == nil then
		return MISSING
	end
	player:SetAttribute("BoothCamera", shot)
	return `Looking through the {shot} camera. /boothcam off when you're done.`
end

return PhotoBooth
