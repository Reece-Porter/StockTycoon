--!strict
-- The all-time leaderboards (docs/design.md, "Server and leaderboards").

return {
	-- Players shown on each board.
	Entries = 10,
	-- How often each player's values are saved and the boards are read back.
	UpdateSeconds = 60,
}
