--!strict
-- Small pills for tiers, rarities and variants: a short label in white on the
-- Theme colour, with a dark outline. Rainbow variant badges get the rainbow
-- gradient.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Tiers = require(ReplicatedStorage.Shared.Config.Tiers)
local Variants = require(ReplicatedStorage.Shared.Config.Variants)
local Make = require(script.Parent.Make)

local HEIGHT = 24

local Badge = {}

-- A pill with this text and colour; gradient (if given) runs across it.
function Badge.new(text: string, colour: Color3, gradient: ColorSequence?): Frame
	local pill = Instance.new("Frame")
	pill.Name = "Badge"
	pill.Size = UDim2.fromOffset(0, HEIGHT)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = if gradient then Theme.Colours.Card else colour
	Make.corner(pill)
	Make.outline(pill, Theme.Colours.Ink, Theme.Stroke.Thin)
	Make.padding(pill, 0, 9)
	if gradient then
		local fill = Instance.new("UIGradient")
		fill.Color = gradient
		fill.Parent = pill
	end
	local label = Make.label(pill, {
		text = text,
		font = Theme.Fonts.Body,
		size = Theme.TextSize.Small,
		colour = Theme.Colours.TextOnColour,
	})
	Make.textOutline(label, Theme.Stroke.Thin)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	return pill
end

function Badge.tier(tierId: string): Frame
	local tier = Tiers.byId[tierId]
	return Badge.new(if tier then tier.name else tierId, Theme.Tiers[tierId] or Theme.Colours.Locked)
end

function Badge.rarity(rarityId: string): Frame
	local rarity = Pets.rarityById[rarityId]
	return Badge.new(if rarity then rarity.name else rarityId, Theme.Rarities[rarityId] or Theme.Colours.Locked)
end

function Badge.variant(variantId: string): Frame
	local variant = Variants.byId[variantId]
	local gradient = if variantId == "Rainbow" then Theme.RainbowGradient else nil
	return Badge.new(
		if variant then variant.name else variantId,
		Theme.Variants[variantId] or Theme.Colours.Locked,
		gradient
	)
end

return Badge
