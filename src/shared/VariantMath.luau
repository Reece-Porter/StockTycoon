--!strict
-- Variant chances and multipliers (Config/Variants). Pure functions: the
-- caller passes in the random roll, a number from 0 up to (not including) 1,
-- so the same code runs in the game and in tests.

local Variants = require(script.Parent.Config.Variants)

local VariantMath = {}

-- The chance of one variant (0 to 1), with every chance multiplied by
-- chanceMultiplier (the Variant Chance upgrade).
function VariantMath.chance(variant: Variants.Variant, chanceMultiplier: number): number
	return chanceMultiplier / variant.oneIn
end

-- Which variant a new company is, or nil for a regular one.
function VariantMath.roll(roll: number, chanceMultiplier: number): string?
	local target = roll
	for _, variant in Variants.list do
		local chance = VariantMath.chance(variant, chanceMultiplier)
		if target < chance then
			return variant.id
		end
		target -= chance
	end
	return nil
end

-- How much a company of this variant earns compared with a regular one.
function VariantMath.multiplier(variantId: string?): number
	local variant = if variantId then Variants.byId[variantId] else nil
	return if variant then variant.multiplier else 1
end

-- The company's name with its variant in front, e.g. "Galaxy Kittygram".
function VariantMath.name(variantId: string?, companyName: string): string
	local variant = if variantId then Variants.byId[variantId] else nil
	return if variant then `{variant.name} {companyName}` else companyName
end

return VariantMath
