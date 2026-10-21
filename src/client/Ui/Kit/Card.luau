--!strict
-- A card for grids of items (companies, pets, weapons, upgrades): white, with
-- a border in the tier, rarity or variant colour, a picture (a model in a
-- viewport, or an icon), the name, a key stat, an optional badge and a slot
-- at the bottom for its main button. Locked cards grey out with a padlock;
-- owned cards get a tick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Icons = require(script.Parent.Icons)
local Make = require(script.Parent.Make)

local NAME_HEIGHT = 22
local STAT_HEIGHT = 18
local MARK_SIZE = 30

export type Props = {
	-- The border and picture background colour.
	accent: Color3,
	title: string,
	stat: string?,
	badge: Frame?,
	-- A model (or a Tool) shown turned slightly to the camera, or else an icon.
	model: Instance?,
	-- Shows the model as a dark shape only (something not found yet).
	silhouette: boolean?,
	icon: Icons.IconName?,
	-- Defaults to a size that fits two or three across on a phone.
	size: UDim2?,
	-- Height kept free at the bottom for a button (put it in Footer).
	footerHeight: number?,
	layoutOrder: number?,
}

export type Card = {
	Instance: Frame,
	Footer: Frame,
	setTitle: (text: string) -> (),
	setStat: (text: string) -> (),
	setLocked: (locked: boolean) -> (),
	setOwned: (owned: boolean) -> (),
}

local Card = {}

-- The model in a viewport, framed so all of it shows. A Tool's parts are put
-- in a model first.
local function showModel(parent: Frame, model: Instance, silhouette: boolean)
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Theme.Colours.Panel
	viewport.LightColor = Theme.Colours.Card
	if silhouette then
		viewport.ImageColor3 = Theme.Colours.Ink
		viewport.ImageTransparency = 0.15
	end
	local clone = model:Clone()
	local copy: Model
	if clone:IsA("Model") then
		copy = clone
	else
		copy = Instance.new("Model")
		for _, child in clone:GetChildren() do
			child.Parent = copy
		end
		clone:Destroy()
	end
	copy.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local centre, size = copy:GetBoundingBox()
	local distance = (size.Magnitude / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	local direction = (centre.LookVector + centre.RightVector * 0.6 + Vector3.new(0, 0.5, 0)).Unit
	camera.CFrame = CFrame.lookAt(centre.Position + direction * distance, centre.Position)
	viewport.Parent = parent
end

function Card.new(props: Props): Card
	local footerHeight = props.footerHeight or 0

	local card = Instance.new("Frame")
	card.Name = props.title
	card.Size = props.size or UDim2.fromOffset(140, 176 + footerHeight)
	card.BackgroundColor3 = Theme.Colours.Card
	card.LayoutOrder = props.layoutOrder or 0
	Make.corner(card, Theme.Corner.Medium)
	local border = Make.outline(card, props.accent, Theme.Stroke.Thick)

	local textHeight = NAME_HEIGHT + STAT_HEIGHT
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.Position = UDim2.fromOffset(6, 6)
	art.Size = UDim2.new(1, -12, 1, -(12 + textHeight + footerHeight))
	art.BackgroundColor3 = Theme.tint(props.accent, 0.75)
	Make.corner(art, Theme.Corner.Small)
	art.Parent = card
	if props.model then
		showModel(art, props.model, props.silhouette == true)
	elseif props.icon then
		local icon = Icons.make(props.icon, 48)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Parent = art
	end

	local name = Make.label(card, {
		text = props.title,
		font = Theme.Fonts.Display,
		size = Theme.TextSize.Body,
		colour = Theme.Colours.Text,
	})
	name.AnchorPoint = Vector2.new(0, 1)
	name.Position = UDim2.new(0, 6, 1, -(STAT_HEIGHT + footerHeight + 4))
	name.Size = UDim2.new(1, -12, 0, NAME_HEIGHT)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local stat = Make.label(card, {
		text = props.stat,
		size = Theme.TextSize.Small,
		colour = Theme.Colours.TextMuted,
	})
	stat.AnchorPoint = Vector2.new(0, 1)
	stat.Position = UDim2.new(0, 6, 1, -(footerHeight + 4))
	stat.Size = UDim2.new(1, -12, 0, STAT_HEIGHT)
	stat.TextTruncate = Enum.TextTruncate.AtEnd

	if props.badge then
		props.badge.Position = UDim2.fromOffset(10, 10)
		props.badge.ZIndex = 3
		props.badge.Parent = card
	end

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 6, 1, -6)
	footer.Size = UDim2.new(1, -12, 0, math.max(0, footerHeight - 6))
	footer.BackgroundTransparency = 1
	footer.Parent = card

	-- Greyed out with a padlock while locked.
	local cover = Instance.new("Frame")
	cover.Name = "Locked"
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Theme.Colours.Locked
	cover.BackgroundTransparency = 0.35
	cover.ZIndex = 5
	cover.Visible = false
	Make.corner(cover, Theme.Corner.Medium)
	local padlock = Icons.make("Padlock", 40)
	padlock.AnchorPoint = Vector2.new(0.5, 0.5)
	padlock.Position = UDim2.fromScale(0.5, 0.4)
	padlock.ZIndex = 6
	padlock.Parent = cover
	cover.Parent = card

	-- A tick in a green circle while owned.
	local owned = Instance.new("Frame")
	owned.Name = "Owned"
	owned.AnchorPoint = Vector2.new(1, 0)
	owned.Position = UDim2.new(1, -6, 0, 6)
	owned.Size = UDim2.fromOffset(MARK_SIZE, MARK_SIZE)
	owned.BackgroundColor3 = Theme.Colours.Cash
	owned.ZIndex = 4
	owned.Visible = false
	Make.corner(owned)
	Make.outline(owned, Theme.Colours.Ink, Theme.Stroke.Normal)
	local tick = Icons.make("Tick", MARK_SIZE)
	tick.ZIndex = 5
	tick.Parent = owned
	owned.Parent = card

	return {
		Instance = card,
		Footer = footer,
		setTitle = function(text: string)
			name.Text = text
		end,
		setStat = function(text: string)
			stat.Text = text
		end,
		setLocked = function(locked: boolean)
			cover.Visible = locked
			border.Color = if locked then Theme.Colours.Locked else props.accent
		end,
		setOwned = function(isOwned: boolean)
			owned.Visible = isOwned
		end,
	}
end

return Card
