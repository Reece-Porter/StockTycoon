--!strict
-- Finding and copying company models from ReplicatedStorage.Assets.Companies,
-- named by company id. When the server starts, prepare() builds a model for
-- every company that doesn't have one there yet, from its look in
-- Config/CompanyLooks (CompanyBuilder), so the clients get them too, for
-- cards. A model built by hand in Studio with the company's id always wins
-- and is left alone. The "Default" model is only used if a company somehow
-- has neither. Every copy gets the "Company" tag (for CompanyFxController),
-- and a variant's copy gets the variant's look (VariantLayer) and a Variant
-- attribute.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local CompanyBuilder = require(script.Parent.CompanyBuilder)
local VariantLayer = require(ReplicatedStorage.Shared.VariantLayer)

-- On every copy in the world, so the client can find them.
local TAG = "Company"

local CompanyModels = {}

local prepared = false

local function folder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Companies")
end

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

-- Builds the models no company has yet, once. Says what it did, and which
-- companies have no look of their own yet (they get a plain box).
function CompanyModels.prepare()
	if prepared then
		return
	end
	prepared = true
	local companies = childFolder(childFolder(ReplicatedStorage, "Assets"), "Companies")

	local built, handMade, plain = 0, {}, {}
	for _, company in Companies.list do
		if companies:FindFirstChild(company.id) then
			table.insert(handMade, company.id)
		else
			CompanyBuilder.build(company).Parent = companies
			built += 1
			if not CompanyBuilder.hasLook(company.id) then
				table.insert(plain, company.id)
			end
		end
	end
	local kept = if #handMade > 0 then ` Kept the hand-made ones: {table.concat(handMade, ", ")}.` else ""
	print(`[CompanyModels] Built {built} company models from Config/CompanyLooks.{kept}`)
	if #plain > 0 then
		warn(`[CompanyModels] No look in Config/CompanyLooks yet, so a plain box: {table.concat(plain, ", ")}`)
	end
end

-- The company's own model, or the Default model if it somehow has none.
function CompanyModels.find(companyId: string): Model?
	CompanyModels.prepare()
	local companies = folder()
	if companies == nil then
		return nil
	end
	local model = companies:FindFirstChild(companyId) or companies:FindFirstChild("Default")
	return if model and model:IsA("Model") then model else nil
end

-- A copy that can't be walked into or touched. Anchored for display on a belt
-- or plot; unanchored and massless for carrying. A variant's copy gets the
-- variant's look first, so the parts it adds are set up the same way.
function CompanyModels.clone(companyId: string, anchored: boolean, variantId: string?): Model?
	local template = CompanyModels.find(companyId)
	if template == nil then
		return nil
	end

	local model = template:Clone()
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if variantId then
		VariantLayer.apply(model, variantId)
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = not anchored
		end
	end
	model:AddTag(TAG)
	return model
end

-- How far the model's pivot is above the bottom of its bounding box, so it can
-- be stood on a surface with PivotTo.
function CompanyModels.pivotHeight(model: Model): number
	local boxCFrame, boxSize = model:GetBoundingBox()
	return model:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
end

-- Stands the model on a point, keeping the given rotation.
function CompanyModels.standOn(model: Model, point: Vector3, rotation: CFrame)
	model:PivotTo(CFrame.new(point + Vector3.new(0, CompanyModels.pivotHeight(model), 0)) * rotation.Rotation)
end

return CompanyModels
