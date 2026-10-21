--!strict
-- How a part the owner hasn't unlocked yet looks (a plot, its cash pad or a
-- pet slot): dull stone, with its glow hidden, and a Locked attribute the
-- client uses to put a padlock over it (BaseFxController). Once it opens,
-- everything gets its own look back. The looks hung on a part (its child
-- parts, from studio/BuildMap.luau) change with it; an invisible part (a pet
-- slot's pad) stays invisible.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)

-- A child part with this name glows only while open.
local GLOW_NAME = "Glow"

local LockedLook = {}

local function pieces(part: BasePart): { BasePart }
	local list = { part }
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(list, descendant)
		end
	end
	return list
end

local function material(name: unknown): Enum.Material
	local found = if typeof(name) == "string" then (Enum.Material :: any)[name] else nil
	return if typeof(found) == "EnumItem" then found :: any else Enum.Material.SmoothPlastic
end

function LockedLook.set(part: BasePart, locked: boolean)
	part:SetAttribute("Locked", if locked then true else nil)
	for _, piece in pieces(part) do
		local saved = piece:GetAttribute("OpenColour") ~= nil
		if locked then
			if piece.Transparency >= 1 and not saved then
				continue
			end
			if not saved then
				piece:SetAttribute("OpenColour", piece.Color)
				piece:SetAttribute("OpenMaterial", piece.Material.Name)
				piece:SetAttribute("OpenTransparency", piece.Transparency)
			end
			if piece.Name == GLOW_NAME then
				piece.Transparency = 1
			else
				piece.Color = if piece == part then Theme.Base.Stone else Theme.Base.StoneDark
				piece.Material = Enum.Material.Slate
			end
		elseif saved then
			local colour = piece:GetAttribute("OpenColour")
			local transparency = piece:GetAttribute("OpenTransparency")
			if typeof(colour) == "Color3" then
				piece.Color = colour
			end
			piece.Material = material(piece:GetAttribute("OpenMaterial"))
			if typeof(transparency) == "number" then
				piece.Transparency = transparency
			end
			piece:SetAttribute("OpenColour", nil)
			piece:SetAttribute("OpenMaterial", nil)
			piece:SetAttribute("OpenTransparency", nil)
		end
	end
end

return LockedLook
