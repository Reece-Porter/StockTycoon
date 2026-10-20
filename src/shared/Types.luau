--!strict
-- Types shared by the server and client.

-- One company a player owns. Saved in their data, and kept exactly as is when
-- it is stolen (valuationMultiplier and hasBeenValued travel with it).
export type CompanyInstance = {
	instanceId: string,
	companyId: string,
	tier: string,
	baseIncome: number,
	-- What the owner paid; selling back returns a share of this.
	purchasePrice: number,
	valuationMultiplier: number,
	hasBeenValued: boolean,
	ownerUserId: number,
	-- Config/Variants id, or nil for a regular company. Kept for good.
	variant: string?,
}

-- A company in the Valuation Machine. The parameters come from
-- MachinePath.generate; startedAt is workspace:GetServerTimeNow() at the start.
export type MachineRun = {
	company: CompanyInstance,
	seed: number,
	duration: number,
	peak: number,
	peakTime: number,
	startedAt: number,
}

-- One pet a player owns. slotKey (e.g. "Floor2/Slot1") is where it is
-- placed; nil means it is in their pet inventory.
export type PetInstance = {
	instanceId: string,
	petId: string,
	slotKey: string?,
}

-- Playtime and daily rewards, saved so they carry over between sessions.
export type RewardsState = {
	-- The UTC day (RewardMath.day) the playtime below counts for.
	PlaytimeDay: number,
	PlaytimeSeconds: number,
	-- Playtime milestones claimed that day, in minutes.
	ClaimedPlaytime: { number },
	-- The track day (1 to 7) last claimed, and the UTC day it was claimed (0
	-- if never).
	DailyStreak: number,
	LastDailyDay: number,
	-- Banked 2x income boost; it only runs down while the player is in game.
	BoostSeconds: number,
	-- Free pet spins waiting to be used at the pet shop.
	SpinTokens: number,
}

-- The Index: every company id ever owned, and the milestones claimed.
export type IndexState = {
	Discovered: { [string]: boolean },
	Claimed: { number },
	-- Variants (Config/Variants ids) the player has ever owned.
	Variants: { [string]: boolean },
}

-- What's been reported to Roblox analytics.
export type AnalyticsState = {
	-- New-player funnel steps already reported (Config/Analytics.FunnelSteps).
	Funnel: { number },
	-- Lifetime play time, and what it was at the last rebirth, for timing how
	-- long each rebirth takes.
	PlaySeconds: number,
	RebirthPlaySeconds: number,
}

return {}
