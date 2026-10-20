--!strict
-- Codes (docs/design.md, "Codes"): players type a code into the Rewards
-- window and get what the server's Config/Codes says, once each, until the
-- code expires. The list stays on the server so players can't read it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local RewardsService = require(script.Parent.RewardsService)
local Codes = require(script.Parent.Parent.Config.Codes)
local Dates = require(script.Parent.Parent.Lib.Dates)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local MAX_LENGTH = 32

-- One try a second at most, so codes can't be guessed quickly.
local redeemLimiter = RateLimiter.new(1, 3)

local CodesService = {}

-- Returns the message for the player.
local function redeem(player: Player, typed: string): string
	local code = string.upper((string.gsub(typed, "^%s*(.-)%s*$", "%1")))
	if code == "" then
		return "Type a code first."
	end
	local entry: Codes.Code? = nil
	for _, candidate in Codes do
		if string.upper(candidate.code) == code then
			entry = candidate
		end
	end
	if entry == nil then
		return "That code doesn't exist."
	end
	local expires = entry.expires
	if expires then
		local lastSecond = Dates.endOfDay(expires)
		if lastSecond == nil or os.time() > lastSecond then
			return "That code has expired."
		end
	end
	if DataService:GetData(player) == nil then
		return "Your data hasn't loaded yet."
	end
	if not DataService:RedeemCode(player, code) then
		return "You've already used that code."
	end
	return `Code {code}: {RewardsService:Grant(player, entry.grants, "Code")}!`
end

function CodesService:Start()
	Remotes.RedeemCode.OnServerEvent:Connect(function(player: Player, typed: unknown)
		if redeemLimiter:allow(player) and typeof(typed) == "string" and #typed <= MAX_LENGTH then
			if player.Parent == Players then
				Remotes.Notify:FireClient(player, redeem(player, typed))
			end
		end
	end)
end

return CodesService
