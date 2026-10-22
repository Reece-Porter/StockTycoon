--!strict
-- A quick pop over something in the world (docs/visual-pass.md, Phase 9): a
-- word that springs up, bursts, drifts up a little and shrinks away in under
-- a second. Drawn in the world, on this player's screen only, so it never
-- covers the HUD. Used for "SOLD!", "YOINK!", "TAGGED!", "REBIRTH!" and the
-- small "+$12" over plots (FeedbackFxController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Icons = require(script.Parent.Kit.Icons)
local Make = require(script.Parent.Kit.Make)

export type Options = {
	colour: Color3,
	-- Height of the pop in pixels (its width is wider).
	size: number?,
	-- Rays of light behind the word.
	burst: boolean?,
	-- Little icons flying out from the word.
	icon: Icons.IconName?,
	-- How far it drifts up, in studs.
	rise: number?,
}

local SECONDS = 0.9
local RAYS = 8
local ICONS = 4
local POP_IN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local DRIFT = TweenInfo.new(SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP_OUT_SECONDS = 0.15
local POP_OUT = TweenInfo.new(POP_OUT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local WorldPop = {}

WorldPop.Seconds = SECONDS

-- Pops text over adornee, offset studs above it.
function WorldPop.show(adornee: BasePart, offset: Vector3, text: string, options: Options): BillboardGui
	local size = options.size or 120
	local gui = Instance.new("BillboardGui")
	gui.Name = "Pop"
	gui.Size = UDim2.fromOffset(size * 1.8, size)
	gui.StudsOffsetWorldSpace = offset
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Adornee = adornee
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = gui

	if options.burst ~= false then
		for index = 1, RAYS do
			local ray = Instance.new("Frame")
			ray.Name = "Ray"
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Size = UDim2.fromOffset(6, size * 0.45)
			ray.Rotation = index * 180 / RAYS
			ray.BackgroundColor3 = Theme.tint(options.colour, 0.35)
			ray.BackgroundTransparency = 0.3
			ray.BorderSizePixel = 0
			ray.Parent = gui
			TweenService:Create(ray, DRIFT, {
				Size = UDim2.fromOffset(4, size * 1.1),
				BackgroundTransparency = 1,
			}):Play()
		end
	end

	local word = Make.label(gui, {
		text = text,
		font = Theme.Fonts.Display,
		colour = options.colour,
		outline = true,
	})
	word.Name = "Word"
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.Position = UDim2.fromScale(0.5, 0.5)
	word.Size = UDim2.fromScale(0.95, 0.5)
	word.TextScaled = true
	word.ZIndex = 3

	local icon: Icons.IconName? = options.icon
	if icon then
		for index = 1, ICONS do
			local bit = Icons.make(icon, math.floor(size * 0.22), options.colour)
			bit.Name = "Bit"
			bit.AnchorPoint = Vector2.new(0.5, 0.5)
			bit.Position = UDim2.fromScale(0.5, 0.5)
			bit.ZIndex = 2
			bit.Parent = gui
			local angle = (index - 0.5) / ICONS * 2 * math.pi
			TweenService:Create(bit, DRIFT, {
				Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.45, 0.5 + math.sin(angle) * 0.45),
			}):Play()
		end
	end

	gui.Parent = adornee
	TweenService:Create(scale, POP_IN, { Scale = 1 }):Play()
	TweenService:Create(gui, DRIFT, { StudsOffsetWorldSpace = offset + Vector3.new(0, options.rise or 1.5, 0) }):Play()
	task.delay(SECONDS - POP_OUT_SECONDS, function()
		TweenService:Create(scale, POP_OUT, { Scale = 0 }):Play()
	end)
	task.delay(SECONDS, function()
		gui:Destroy()
	end)
	return gui
end

return WorldPop
