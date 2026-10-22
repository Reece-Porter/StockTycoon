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
	Decacorn = hex("#FF6FD0"),
	BlueChip = hex("#2FD3E0"),
	MegaCap = hex("#FF8A3D"),
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

-- The light-to-dark sheen over buttons and closes (multiplied over their own
-- colour, so white leaves it as it is).
Theme.Shine = ColorSequence.new(hex("#FFFFFF"), hex("#D1D1D1"))

-- Each menu button's colour.
Theme.Menu = {
	Storage = hex("#3D8BFF"),
	Upgrades = hex("#3CCB5A"),
	Weapons = hex("#FF4D5E"),
	Pets = hex("#A66CFF"),
	Index = hex("#2FD3E0"),
	Rebirth = hex("#FFB020"),
	Rewards = hex("#FF5FB0"),
	Store = hex("#FFC83D"),
	Codes = hex("#7B61FF"),
}

-- In-world bits drawn by the client.
Theme.World = {
	-- The guide's line and arrow.
	Guide = hex("#FFC83D"),
	-- Ranged weapon shots.
	Projectile = hex("#C8CCD8"),
	-- Lock signs: locked, new-player protection, open.
	Locked = hex("#FF4D5E"),
	Protected = hex("#3D8BFF"),
	Open = hex("#F4F6FB"),
}

-- The player bases (studio/BuildMap.luau and the code that dresses them).
-- Each base has one accent colour, by base number, used for its carpet,
-- trim, frames, sign, plot glow and spawn ring; everything else is neutral.
-- BuildMap also stores it on each base as an Accent attribute.
Theme.Base = {
	Accents = {
		hex("#3D8BFF"),
		hex("#FF8A3D"),
		hex("#3CCB5A"),
		hex("#A66CFF"),
		hex("#FF4D5E"),
		hex("#2FD3E0"),
		hex("#FF5FB0"),
		hex("#9BE22D"),
	},
	-- Floors and platforms, with darker grout lines and edges.
	Floor = hex("#ECEEF4"),
	Grout = hex("#D3D8E4"),
	Edge = hex("#B9C0D0"),
	-- Plots: a white display top on a darker lip, with a glow in the accent
	-- colour once open; locked ones are dull stone.
	Plot = hex("#F7F8FC"),
	PlotLip = hex("#C5CBDA"),
	Stone = hex("#8E9097"),
	StoneDark = hex("#6E7178"),
	-- Pet beds.
	Pedestal = hex("#C5CBDA"),
	Cushion = hex("#FFF8EE"),
	-- Stairs, glass and rails.
	Step = hex("#D5DAE8"),
	Tread = hex("#F7F8FC"),
	Glass = hex("#CFEFFF"),
	Post = hex("#F7F8FC"),
	-- The front yard.
	Belt = hex("#3A3A4A"),
	Roller = hex("#8D99AE"),
	Housing = hex("#2B2D42"),
	Machine = hex("#2B2D42"),
	MachinePad = hex("#A66CFF"),
	LockCap = hex("#FF4D5E"),
	SignPanel = hex("#FFFFFF"),
	-- The Stock Spinner over the belt: a dark board framed in the accent
	-- colour, with dark screens for the reels and gold bulbs along it that
	-- chase while it spins.
	Spinner = hex("#2B2D42"),
	SpinnerScreen = hex("#1B1B2F"),
	Bulb = hex("#FFC83D"),
	BulbOff = hex("#7A6230"),
}

-- The middle street (studio/BuildMap.luau, docs/visual-pass.md Phase 6).
Theme.Street = {
	-- The shared conveyor: a red carpet between gold rails, with roller ends
	-- and a row of small lights along each rail.
	Carpet = hex("#A3203A"),
	Rail = hex("#E1B93C"),
	Roller = hex("#C9CED8"),
	LightOff = hex("#8A6A2A"),
	LightOn = hex("#FFE27A"),
	-- Road, markings and kerbs.
	Road = hex("#4A4E5A"),
	Line = hex("#F4F1E8"),
	Kerb = hex("#C9C4B8"),
	-- Lamps, benches and planters.
	LampPole = hex("#2B2D42"),
	Bulb = hex("#FFE9B0"),
	Wood = hex("#B07A4A"),
	Metal = hex("#3A3D4D"),
	Leaf = hex("#58AA52"),
	Soil = hex("#60462F"),
	Planter = hex("#D5DAE8"),
	-- The stock-exchange gateways and the bull.
	Marble = hex("#F1EEE6"),
	MarbleShade = hex("#D9D3C6"),
	Frieze = hex("#22325A"),
	Gold = hex("#E1B93C"),
	-- Storefronts: each shop's main colour, with a white stripe on the awning.
	Shops = {
		WeaponShop = hex("#FF8A3D"),
		PetShop = hex("#2FBFA8"),
		UpgradeStation = hex("#3CCB5A"),
	},
	ShopFloor = hex("#ECEEF4"),
	ShopWall = hex("#2B2D42"),
	Counter = hex("#B07A4A"),
	CounterTop = hex("#F7F8FC"),
	Awning = hex("#FFFFFF"),
	-- Shopkeepers: skin tones and clothes.
	Skin = { hex("#F1C27D"), hex("#8D5524"), hex("#C68642") },
	Eye = hex("#1A1A24"),
	Trousers = hex("#3A3D4D"),
	-- Leaderboards: a dark board under a coloured header, in a frame with a
	-- soft glow behind it; the top three ranks in gold, silver and bronze.
	Board = hex("#141826"),
	BoardRow = hex("#1E2336"),
	BoardHeader = hex("#3D8BFF"),
	BoardFrame = hex("#2B2D42"),
	BoardGlow = hex("#3D8BFF"),
	Ranks = { hex("#FFC83D"), hex("#C9D1DE"), hex("#D08A4E") },
}

-- The world round the bases (studio/BuildMap.luau, visual pass Phase 8):
-- patches of grass a little lighter and darker than the ground, stepping
-- stones, round trees between the bases and pines on the hills, flower
-- patches, a wooden fence along the edge, and a hazy city far behind the
-- hills in pale blue-greys so it sits back in the distance.
Theme.Scenery = {
	Grass = { hex("#6DAF50"), hex("#5A9844"), hex("#7CBA5A") },
	Stone = hex("#CFC9BC"),
	StoneShade = hex("#B4AD9F"),
	Trunk = hex("#8A5A36"),
	Leaves = { hex("#58AA52"), hex("#4C9A49"), hex("#6BBE5E") },
	Pine = { hex("#2F7D4A"), hex("#3A8F55"), hex("#2A6F43") },
	Bush = hex("#4F9E4A"),
	Mound = hex("#4A9446"),
	Flowers = { hex("#FF6FA8"), hex("#FFD84D"), hex("#FFFFFF"), hex("#B07CFF"), hex("#FF8A3D") },
	Fence = hex("#F2E8D5"),
	FenceShade = hex("#D9CCB2"),
	Towers = { hex("#AEBBD0"), hex("#B9C5D8"), hex("#A3B2C9"), hex("#C3CCDC") },
	TowerTop = hex("#97A7C0"),
	Antenna = hex("#8D99AE"),
	BillboardFrame = hex("#EEF1F7"),
	-- A billboard's own colour, one each.
	Billboards = { hex("#3D8BFF"), hex("#FF8A3D"), hex("#A66CFF"), hex("#2FBFA8") },
}

-- The photo booth (studio/BuildMap.luau, visual pass Phase 10), far from the
-- map, for screenshots of models, pets and bases: a curved backdrop in one
-- of these soft colours (the /backdrop admin command), white podiums, and
-- warm and cool studio lights.
Theme.Booth = {
	Backdrops = {
		Sky = hex("#CFE6FF"),
		Gold = hex("#FFE7A3"),
		Green = hex("#C4F0CE"),
		Blue = hex("#BCD6FF"),
		Purple = hex("#E2D3FF"),
		Teal = hex("#BDEFE6"),
		Pink = hex("#FFD3E4"),
		White = hex("#F4F6FB"),
		Night = hex("#22253A"),
	} :: { [string]: Color3 },
	Podium = hex("#FFFFFF"),
	PodiumRim = hex("#D5DAE8"),
	Stage = hex("#EEF1F7"),
	KeyLight = hex("#FFF2DC"),
	FillLight = hex("#DCE8FF"),
}

-- The battle arena (studio/BuildMap.luau), far from the map, and its
-- teleporter gates in the middle of the street: a dark stadium floor with a
-- gold ring round the podium, purple walls with neon trim, banks of seats
-- in bright colours, banners, a big board, and glowing purple portals.
Theme.Arena = {
	Floor = hex("#2B2D42"),
	FloorEdge = hex("#383B57"),
	Ring = hex("#E1B93C"),
	Wall = hex("#5B3FB8"),
	WallTrim = hex("#A66CFF"),
	Stand = hex("#22253A"),
	Seats = { hex("#3D8BFF"), hex("#FF8A3D"), hex("#A66CFF"), hex("#2FBFA8") },
	Banners = { hex("#FFC83D"), hex("#3D8BFF"), hex("#FF4D5E"), hex("#3CCB5A") },
	Podium = hex("#F4F6FB"),
	Board = hex("#141826"),
	BoardFrame = hex("#2B2D42"),
	Gate = hex("#22325A"),
	Portal = hex("#A66CFF"),
	Exit = hex("#3CCB5A"),
}

-- The Valuation Machine's chart.
Theme.Chart = {
	Rising = hex("#3CCB5A"),
	Falling = hex("#FF4D5E"),
	Grid = hex("#D5DAE8"),
	Background = hex("#FFFFFF"),
}

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

-- Where the always-on-screen pieces go (Ui/Layout, Ui/Menu), in pixels before
-- scaling up for bigger screens. The menu grid sits on the left and the
-- Rewards, Store and Codes column on the right, both clear of the thumbstick
-- (bottom left) and jump button (bottom right) on phones.
Theme.Layout = {
	-- From the screen's edges (below Roblox's own top bar).
	Margin = 10,
	-- The stack down the middle of the top: Cash, teleports, the guide.
	TopGap = 6,
	-- Square menu buttons.
	MenuButton = 56,
	MenuGap = 6,
	-- In portrait the side menus start this far down, below the top stack
	-- (the teleports and the guide's banner).
	PortraitSideTop = 130,
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
