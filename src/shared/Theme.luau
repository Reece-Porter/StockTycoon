--!strict
-- The look of the game in one place (docs/visual-pass.md): every colour, font,
-- corner radius, stroke width, text size, tween timing and lighting value.
-- Nothing else hard-codes colours: configs (tiers, rarities, variants), the UI
-- kit (client/Ui/Kit), LightingService and, as the visual pass goes on, the
-- map and models all read from here. Pure data and small colour helpers, so
-- the server, the client and tests share it.

local Theme = {}

-- A colour from "#RRGGBB".
function Theme.hex(code: string): Color3
	return Color3.fromHex(code)
end

-- The colour moved towards black (amount 0 to 1), for shadows and pressed
-- states.
function Theme.shade(colour: Color3, amount: number): Color3
	return colour:Lerp(Color3.new(0, 0, 0), amount)
end

-- The colour moved towards white (amount 0 to 1), for highlights.
function Theme.tint(colour: Color3, amount: number): Color3
	return colour:Lerp(Color3.new(1, 1, 1), amount)
end

local hex = Theme.hex

-- The palette: one strong accent per object or window, the rest neutral.
Theme.Colours = {
	-- Outlines and dark text.
	Ink = hex("#1B1B2F"),
	-- Window bodies, cards and card borders.
	Panel = hex("#F4F6FB"),
	Card = hex("#FFFFFF"),
	CardBorder = hex("#D5DAE8"),
	Text = hex("#1B1B2F"),
	TextMuted = hex("#5B6178"),
	TextOnColour = hex("#FFFFFF"),
	-- Accents.
	Cash = hex("#3CCB5A"),
	Gold = hex("#FFC83D"),
	Primary = hex("#3D8BFF"),
	Purple = hex("#A66CFF"),
	Danger = hex("#FF4D5E"),
	-- Greyed-out (locked or unavailable) things.
	Locked = hex("#A3A9B8"),
	-- Behind an open window.
	Dim = hex("#0B0B16"),
}

-- Company tiers, by Config/Tiers id.
Theme.Tiers = {
	Startup = hex("#7ED957"),
	ScaleUp = hex("#3D8BFF"),
	Unicorn = hex("#A66CFF"),
	BlueChip = hex("#2FD3E0"),
	Conglomerate = hex("#FFC83D"),
	Monopoly = hex("#FF4D5E"),
} :: { [string]: Color3 }

-- Pet rarities, by Config/Pets rarity id.
Theme.Rarities = {
	Common = hex("#B8C0CC"),
	Uncommon = hex("#7ED957"),
	Rare = hex("#3D8BFF"),
	Epic = hex("#A66CFF"),
	Legendary = hex("#FFB020"),
	Mythic = hex("#FF3D6E"),
} :: { [string]: Color3 }

-- Company variants, by Config/Variants id: badge and name colours, each easy
-- to tell from the others at a glance. Rainbow badges also get
-- RainbowGradient over the top.
Theme.Variants = {
	Shiny = hex("#DCE6F7"),
	Pixel = hex("#9BE22D"),
	Molten = hex("#FF7A1A"),
	Galaxy = hex("#6A4DFF"),
	Rainbow = hex("#FF5FB0"),
	Glitched = hex("#19F0E0"),
} :: { [string]: Color3 }

Theme.RainbowGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, hex("#FF4D5E")),
	ColorSequenceKeypoint.new(0.25, hex("#FFC83D")),
	ColorSequenceKeypoint.new(0.5, hex("#7ED957")),
	ColorSequenceKeypoint.new(0.75, hex("#3D8BFF")),
	ColorSequenceKeypoint.new(1, hex("#A66CFF")),
})

-- The left edge of each kind of notification toast.
Theme.Toasts = {
	Info = Theme.Colours.Primary,
	Success = Theme.Colours.Cash,
	Warning = Theme.Colours.Gold,
	Error = Theme.Colours.Danger,
}

-- Two fonts only: a rounded display font for titles, big numbers and
-- buttons, and a clean bold one for everything else.
Theme.Fonts = {
	Display = Enum.Font.FredokaOne,
	Body = Enum.Font.BuilderSansBold,
}

-- Text sizes in pixels. Small is the smallest text anywhere, still readable
-- on a small phone.
Theme.TextSize = {
	Small = 14,
	Body = 16,
	Button = 20,
	Title = 26,
	Big = 36,
	Huge = 56,
}

-- Corner radii in pixels.
Theme.Corner = {
	Small = 8,
	Medium = 12,
	Large = 18,
}

-- Outline thickness in pixels.
Theme.Stroke = {
	Thin = 1.5,
	Normal = 2.5,
	Thick = 3.5,
}

-- Sizes in pixels. Touch is the smallest a button may be, so it's easy to hit
-- with a thumb.
Theme.Size = {
	Touch = 44,
	ButtonHeight = 52,
	HeaderHeight = 52,
	-- How far a button's shadow sits below it.
	ShadowDepth = 4,
	Padding = 12,
	Gap = 8,
}

-- Tween timings in seconds, and how far buttons squash and grow.
Theme.Tween = {
	Press = 0.08,
	Hover = 0.12,
	Open = 0.2,
	Toast = 0.25,
	CountUp = 0.4,
	PressScale = 0.92,
	HoverScale = 1.04,
	-- A window opens from this size up to full size.
	OpenScale = 0.85,
}

-- How see-through the dimmed background behind an open window is.
Theme.DimTransparency = 0.45

-- Notification toasts: how long each stays up and how many at once.
Theme.ToastSeconds = 3.5
Theme.MaxToasts = 3

-- Sunny early afternoon, warm and slightly saturated (LightingService). The
-- sky is Roblox's default until a custom skybox exists (docs/ASSETS_NEEDED.md).
Theme.Lighting = {
	ClockTime = 14.5,
	GeographicLatitude = 30,
	Brightness = 2.6,
	ExposureCompensation = 0.1,
	Ambient = hex("#6E6458"),
	OutdoorAmbient = hex("#9A8E7C"),
	ColorShiftTop = hex("#FFF0DC"),
	ColorShiftBottom = hex("#000000"),
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.5,
	Atmosphere = {
		Density = 0.22,
		Offset = 0.25,
		Color = hex("#CDDCF0"),
		Decay = hex("#6A8CBE"),
		Glare = 0.2,
		Haze = 1,
	},
	-- A high threshold, so only Neon glows.
	Bloom = { Intensity = 0.6, Size = 22, Threshold = 1.9 },
	ColorCorrection = { Brightness = 0.02, Contrast = 0.06, Saturation = 0.12, TintColor = hex("#FFFAF2") },
	SunRays = { Intensity = 0.06, Spread = 0.6 },
}

return Theme
