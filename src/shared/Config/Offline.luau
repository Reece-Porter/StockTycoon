--!strict
-- Offline earnings. Starting assumptions from docs/design.md.

return {
	-- Share of normal income a player's companies earn while they're away.
	IncomeShare = 0.25,
	-- The longest time away that counts.
	MaxSeconds = 4 * 60 * 60,
	-- Shorter absences (a quick rejoin) earn nothing and show no popup.
	MinSeconds = 60,
}
