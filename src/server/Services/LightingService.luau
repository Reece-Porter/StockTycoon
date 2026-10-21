--!strict
-- The game's lighting (docs/visual-pass.md): a fixed, sunny early afternoon,
-- warm and slightly saturated, with a light haze and a slightly blue horizon,
-- subtle bloom that only Neon is bright enough to trigger, a small colour lift
-- and gentle sun rays. Every value is in Theme.Lighting. It's set when the
-- server starts and replicates to everyone, so the Test and Live places always
-- look the same. Effects already in Lighting are reused, never doubled up.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)

local LightingService = {}

-- The first child of Lighting of this class, made if there isn't one.
local function effect(className: string): Instance
	local found = Lighting:FindFirstChildOfClass(className)
	if found then
		return found
	end
	local made = Instance.new(className :: any)
	made.Parent = Lighting
	return made
end

function LightingService:Init()
	local look = Theme.Lighting
	Lighting.ClockTime = look.ClockTime
	Lighting.GeographicLatitude = look.GeographicLatitude
	Lighting.Brightness = look.Brightness
	Lighting.ExposureCompensation = look.ExposureCompensation
	Lighting.Ambient = look.Ambient
	Lighting.OutdoorAmbient = look.OutdoorAmbient
	Lighting.ColorShift_Top = look.ColorShiftTop
	Lighting.ColorShift_Bottom = look.ColorShiftBottom
	Lighting.EnvironmentDiffuseScale = look.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = look.EnvironmentSpecularScale
	Lighting.GlobalShadows = true

	local atmosphere = effect("Atmosphere") :: Atmosphere
	atmosphere.Density = look.Atmosphere.Density
	atmosphere.Offset = look.Atmosphere.Offset
	atmosphere.Color = look.Atmosphere.Color
	atmosphere.Decay = look.Atmosphere.Decay
	atmosphere.Glare = look.Atmosphere.Glare
	atmosphere.Haze = look.Atmosphere.Haze

	local bloom = effect("BloomEffect") :: BloomEffect
	bloom.Enabled = true
	bloom.Intensity = look.Bloom.Intensity
	bloom.Size = look.Bloom.Size
	bloom.Threshold = look.Bloom.Threshold

	local colour = effect("ColorCorrectionEffect") :: ColorCorrectionEffect
	colour.Enabled = true
	colour.Brightness = look.ColorCorrection.Brightness
	colour.Contrast = look.ColorCorrection.Contrast
	colour.Saturation = look.ColorCorrection.Saturation
	colour.TintColor = look.ColorCorrection.TintColor

	local sunRays = effect("SunRaysEffect") :: SunRaysEffect
	sunRays.Enabled = true
	sunRays.Intensity = look.SunRays.Intensity
	sunRays.Spread = look.SunRays.Spread
end

return LightingService
