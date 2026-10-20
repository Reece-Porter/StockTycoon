--!strict
-- Carrying companies. Starting assumptions from docs/design.md.

return {
	-- Walk speed while carrying, as a share of normal.
	WalkSpeedMultiplier = 0.75,

	-- A carried company is shrunk, if needed, so its longest side is at most
	-- this many studs.
	MaxSize = 4,

	-- Gap in studs between the top of the character and the company.
	HeightAboveHead = 0.5,
}
