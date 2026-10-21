--!strict
-- The floating label above a company: name (with its variant in front, in the
-- variant's colour), tier (in the tier's colour) and a detail line such as
-- price and income. Used on conveyors and plots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Companies = require(ReplicatedStorage.Shared.Config.Companies)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)

local SIZE = UDim2.fromOffset(200, 72)
local MAX_DISTANCE = 80
local GAP = 1.5

local CompanyLabel = {}

-- The part labels and prompts attach to.
function CompanyLabel.mainPart(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function addText(
	parent: Instance,
	order: number,
	text: string,
	size: number,
	colour: Color3,
	font: Enum.Font,
	outline: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, size + 6)
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextColor3 = colour
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Theme.Colours.Ink
	stroke.Thickness = outline
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = parent
	return label
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

	local variantId = model:GetAttribute("Variant")
	local variant = if typeof(variantId) == "string" then Variants.byId[variantId] else nil
	local name = if variant then `{variant.name} {company.name}` else company.name
	local nameColour = if variant then variant.colour else Theme.Colours.TextOnColour
	addText(gui, 1, name, Theme.TextSize.Button, nameColour, Theme.Fonts.Display, Theme.Stroke.Normal)
	addText(gui, 2, tier.name, Theme.TextSize.Small, tier.color, Theme.Fonts.Body, Theme.Stroke.Thin)
	addText(gui, 3, detail, Theme.TextSize.Small, Theme.Colours.TextOnColour, Theme.Fonts.Body, Theme.Stroke.Thin)

	gui.Parent = model
	return gui
end

return CompanyLabel
