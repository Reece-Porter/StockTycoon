--!strict
-- Greys out a part the owner hasn't unlocked yet (a plot or a pet slot) by
-- making it see-through, and puts back its own look once it opens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.Shared.Config.Base)

local LockedLook = {}

function LockedLook.set(part: BasePart, locked: boolean)
	if locked then
		if part:GetAttribute("OriginalTransparency") == nil then
			part:SetAttribute("OriginalTransparency", part.Transparency)
		end
		part.Transparency = BaseConfig.LockedPlotTransparency
	else
		local original = part:GetAttribute("OriginalTransparency")
		if typeof(original) == "number" then
			part.Transparency = original
		end
		part:SetAttribute("OriginalTransparency", nil)
	end
end

return LockedLook
