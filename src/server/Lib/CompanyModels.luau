--!strict
-- Finding and copying company models from ReplicatedStorage.Assets.Companies,
-- which are built by hand in Studio and named by company id. A company without
-- its own model yet uses the "Default" model; nothing is ever generated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)

local CompanyModels = {}

local function folder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Companies")
end

-- The company's own model, or the Default model until it has one.
function CompanyModels.find(companyId: string): Model?
	local companies = folder()
	if companies == nil then
		return nil
	end
	local model = companies:FindFirstChild(companyId) or companies:FindFirstChild("Default")
	return if model and model:IsA("Model") then model else nil
end

-- A copy that can't be walked into or touched. Anchored for display on a belt
-- or plot; unanchored and massless for carrying.
function CompanyModels.clone(companyId: string, anchored: boolean): Model?
	local template = CompanyModels.find(companyId)
	if template == nil then
		return nil
	end

	local model = template:Clone()
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = not anchored
		end
	end
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

-- Says once, at startup, which models are missing, rather than inventing any.
function CompanyModels.reportMissing()
	local companies = folder()
	if companies == nil then
		warn("[CompanyModels] ReplicatedStorage.Assets.Companies is missing, so no companies can appear.")
		return
	end

	local missing = {}
	for _, company in Companies.list do
		if companies:FindFirstChild(company.id) == nil then
			table.insert(missing, company.id)
		end
	end
	if #missing == 0 then
		return
	end

	local list = table.concat(missing, ", ")
	local default = companies:FindFirstChild("Default")
	if default and default:IsA("Model") then
		print(`[CompanyModels] {#missing} companies have no model yet and use Default: {list}`)
	else
		warn(`[CompanyModels] ReplicatedStorage.Assets.Companies.Default is missing, so these can't appear: {list}`)
	end
end

return CompanyModels
