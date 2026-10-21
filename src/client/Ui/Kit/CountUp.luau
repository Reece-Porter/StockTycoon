--!strict
-- A number on screen that counts quickly to each new value instead of jumping,
-- e.g. Cash after a purchase or a collect.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.Theme)

export type CountUp = {
	set: (value: number) -> (),
	-- The value it's counting to (or showing).
	get: () -> number,
}

local CountUp = {}

-- Shows format(value) in label, starting at start.
function CountUp.new(label: TextLabel, format: (number) -> string, start: number?): CountUp
	local shown = Instance.new("NumberValue")
	shown.Value = start or 0
	local target = shown.Value
	label.Text = format(shown.Value)
	shown:GetPropertyChangedSignal("Value"):Connect(function()
		label.Text = format(shown.Value)
	end)
	label.Destroying:Connect(function()
		shown:Destroy()
	end)

	local tween: Tween? = nil
	local info = TweenInfo.new(Theme.Tween.CountUp, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	return {
		set = function(value: number)
			target = value
			if tween then
				tween:Cancel()
			end
			local next = TweenService:Create(shown, info, { Value = value })
			next.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					-- Exactly the value, whatever the last frame of the tween was.
					label.Text = format(value)
				end
			end)
			tween = next
			next:Play()
		end,
		get = function()
			return target
		end,
	}
end

return CountUp
