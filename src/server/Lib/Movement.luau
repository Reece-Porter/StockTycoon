--!strict
-- Decides each character's walk speed and jump from everything slowing them
-- down at once. Carrying a company and being stunned each set a factor; the
-- walk speed is the normal speed times every factor, so they never fight over
-- the Humanoid. Factors are cleared when a new character spawns.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local factors: { [Player]: { [string]: number } } = {}

local Movement = {}

local function apply(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local multiplier = 1
	local playerFactors = factors[player]
	if playerFactors then
		for _, factor in playerFactors do
			multiplier *= factor
		end
	end
	humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed * multiplier
	-- Nobody frozen in place can jump either.
	local canJump = multiplier > 0
	humanoid.JumpHeight = if canJump then StarterPlayer.CharacterJumpHeight else 0
	humanoid.JumpPower = if canJump then StarterPlayer.CharacterJumpPower else 0
end

-- Sets (or, with nil, removes) one reason for moving at a different speed,
-- e.g. Movement.set(player, "carry", 0.75) or Movement.set(player, "stun", 0).
function Movement.set(player: Player, reason: string, factor: number?)
	local playerFactors = factors[player]
	if playerFactors == nil then
		playerFactors = {}
		factors[player] = playerFactors
	end
	if factor then
		playerFactors[reason] = factor
	else
		playerFactors[reason] = nil
	end
	apply(player)
end

-- Stops the player for the given seconds.
function Movement.stun(player: Player, seconds: number)
	Movement.set(player, "stun", 0)
	task.delay(seconds, function()
		if player.Parent == Players then
			Movement.set(player, "stun", nil)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	factors[player] = nil
end)

-- A fresh character starts unaffected; anything still in force (such as
-- carrying) sets its factor again.
local function watch(player: Player)
	player.CharacterAdded:Connect(function()
		factors[player] = {}
	end)
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end

return Movement
