--!strict
-- Per-player rate limiting for requests from clients. Each player gets a
-- bucket of `burst` requests that refills at `perSecond`; a request with an
-- empty bucket is refused. Every client-to-server remote goes through one.

local Players = game:GetService("Players")

export type RateLimiter = {
	allow: (self: RateLimiter, player: Player) -> boolean,
}

type Bucket = { tokens: number, updatedAt: number }

local RateLimiter = {}

function RateLimiter.new(perSecond: number, burst: number): RateLimiter
	local buckets: { [Player]: Bucket } = {}

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)

	local limiter = {}

	function limiter.allow(_self: RateLimiter, player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if bucket == nil then
			bucket = { tokens = burst, updatedAt = now }
			buckets[player] = bucket
		end

		bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.updatedAt) * perSecond)
		bucket.updatedAt = now

		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end

	return limiter :: RateLimiter
end

return RateLimiter
