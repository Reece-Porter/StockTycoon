--!strict
-- The floating label above a company: name, tier (in the tier's colour) and a
-- detail line such as price and income. Used on conveyors and plots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)

local SIZE = UDim2.fromOffset(200, 72)
local MAX_DISTANCE = 80
local GAP = 1.5

local CompanyLabel = {}

-- The part labels and prompts attach to.
function CompanyLabel.mainPart(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function addText(parent: Instance, order: number, text: string, size: number, color: Color3, bold: boolean)
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, size + 4)
	label.BackgroundTransparency = 1
	label.Font = if bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSansMedium
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = parent
end

-- The detail line (third line) of a label made by attach, to update it.
function CompanyLabel.detail(gui: BillboardGui?): TextLabel?
	if gui == nil then
		return nil
	end
	for _, child in gui:GetChildren() do
		if child:IsA("TextLabel") and child.LayoutOrder == 3 then
			return child
		end
	end
	return nil
end

function CompanyLabel.attach(model: Model, companyId: string, tierId: string, detail: string): BillboardGui?
	local company = Companies.byId[companyId]
	local tier = Tiers.byId[tierId]
	local adornee = CompanyLabel.mainPart(model)
	if company == nil or tier == nil or adornee == nil then
		return nil
	end

	local boxCFrame, boxSize = model:GetBoundingBox()
	local topAboveAdornee = (boxCFrame.Position.Y + boxSize.Y / 2) - adornee.Position.Y

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = adornee
	gui.Size = SIZE
	gui.StudsOffsetWorldSpace = Vector3.new(0, topAboveAdornee + GAP, 0)
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = gui

	addText(gui, 1, company.name, 20, Color3.new(1, 1, 1), true)
	addText(gui, 2, tier.name, 15, tier.color, true)
	addText(gui, 3, detail, 15, Color3.fromRGB(230, 230, 230), false)

	gui.Parent = model
	return gui
end

return CompanyLabel
