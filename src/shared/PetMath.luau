--!strict
-- Pet spins and what placed pets do to their floor. Pure functions: rolls are
-- passed in as numbers from 0 up to (not including) 1, so the server and tests
-- share the same code.

local Pets = require(script.Parent.Config.Pets)
local SpawnRoll = require(script.Parent.SpawnRoll)
local Types = require(script.Parent.Types)

export type FloorBonus = { income: number, guard: number }

local PetMath = {}

function PetMath.pickRarity(roll: number): Pets.Rarity
	local total = 0
	for _, rarity in Pets.rarities do
		total += rarity.weight
	end
	local target = roll * total
	for _, rarity in Pets.rarities do
		if target < rarity.weight then
			return rarity
		end
		target -= rarity.weight
	end
	return Pets.rarities[#Pets.rarities]
end

-- One spin: a rarity from the first roll, then one of its pets from the second.
function PetMath.spin(rarityRoll: number, petRoll: number): Pets.Pet
	local rarity = PetMath.pickRarity(rarityRoll)
	local choices = Pets.byRarity[rarity.id]
	return choices[SpawnRoll.pickIndex(#choices, petRoll)]
end

-- The chance (0 to 1) that one spin gives this pet.
function PetMath.chance(pet: Pets.Pet): number
	local total = 0
	for _, rarity in Pets.rarities do
		total += rarity.weight
	end
	return Pets.rarityById[pet.rarity].weight / total / #Pets.byRarity[pet.rarity]
end

-- The floor number in a slot key such as "Floor2/Slot1".
function PetMath.floorOf(slotKey: string): number?
	return tonumber((string.match(slotKey, "^Floor(%d+)/")))
end

-- What the placed pets add to each floor. Floors without pets aren't listed.
function PetMath.floorBonuses(pets: { Types.PetInstance }): { [number]: FloorBonus }
	local bonuses: { [number]: FloorBonus } = {}
	for _, instance in pets do
		local pet = Pets.byId[instance.petId]
		local floor = if instance.slotKey then PetMath.floorOf(instance.slotKey) else nil
		if pet and floor then
			local bonus = bonuses[floor]
			if bonus == nil then
				bonus = { income = 0, guard = 0 }
				bonuses[floor] = bonus
			end
			local rarity = Pets.rarityById[pet.rarity]
			if pet.kind == "income" then
				bonus.income += rarity.income
			else
				bonus.guard += rarity.guard
			end
		end
	end
	return bonuses
end

-- The income multiplier for each floor with pets, for IncomeMath.
function PetMath.incomeMultipliers(pets: { Types.PetInstance }): { [number]: number }
	local multipliers = {}
	for floor, bonus in PetMath.floorBonuses(pets) do
		multipliers[floor] = 1 + bonus.income
	end
	return multipliers
end

-- Extra seconds a thief must hold to steal from this floor.
function PetMath.guardSeconds(pets: { Types.PetInstance }, floor: number): number
	local bonus = PetMath.floorBonuses(pets)[floor]
	return if bonus then bonus.guard else 0
end

-- What a pet does, e.g. "+20% income" or "+1.5s to steal".
function PetMath.describe(pet: Pets.Pet): string
	local rarity = Pets.rarityById[pet.rarity]
	if pet.kind == "income" then
		return `+{math.floor(rarity.income * 100 + 0.5)}% income`
	end
	return `+{rarity.guard}s to steal`
end

return PetMath
