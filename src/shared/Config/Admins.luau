--!strict
-- Who can use admin commands and the debug panel. Only the server uses this to
-- decide; a client can never make itself an admin.

return {
	-- Roblox user IDs (the number in a roblox.com/users/<id>/profile address).
	UserIds = {
		806599258, -- Reece
	} :: { number },

	-- Studio's local server test gives players fake IDs: Player1 is -1, Player2
	-- is -2, and so on. These only count inside Studio, so Player1 can test the
	-- admin commands and Player2 can test being refused.
	StudioUserIds = { -1 } :: { number },
}
