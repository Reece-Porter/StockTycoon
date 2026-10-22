--!strict
-- What the game reports to Roblox analytics (docs/design.md, "Analytics";
-- Services/AnalyticsService). Results show in the Creator Dashboard under
-- Analytics. Only the server reports anything.

-- Where Cash comes from and goes, with the Roblox transaction type each is
-- reported as. The name itself is reported as the item, so the dashboard can
-- split them.
export type Source = "Income" | "Offline" | "Playtime" | "Daily" | "Index" | "Code" | "CashPack" | "Battle"
export type Sink = "Company" | "Upgrade" | "Weapon" | "PetSpin" | "Respin"
export type FunnelStep = "Joined" | "BoughtCompany" | "PlacedCompany" | "UsedMachine" | "SharedPurchase" | "FirstSteal"
-- Custom events. MachineResult's value is the multiplier, labelled Taken,
-- RanOut or Left, then the company's tier. StealStarted is labelled Plot or
-- Ground, then the tier; StealCompleted the tier. Rebirth's value is minutes
-- played since the last rebirth, labelled with the rebirth number.
export type Event = "MachineResult" | "StealStarted" | "StealCompleted" | "Rebirth"

local sources: { [Source]: string } = {
	Income = "Gameplay",
	Offline = "Gameplay",
	Playtime = "TimedReward",
	Daily = "TimedReward",
	Index = "Gameplay",
	Code = "Gameplay",
	CashPack = "IAP",
	Battle = "Gameplay",
}
local sinks: { [Sink]: string } = {
	Company = "Shop",
	Upgrade = "Shop",
	Weapon = "Shop",
	PetSpin = "Shop",
	Respin = "Gameplay",
}

return {
	-- The new-player funnel, in order. Each step is reported once per player,
	-- the first time they do it. Players from before analytics count as having
	-- done them all (save version 11), so only new players are counted.
	FunnelSteps = {
		"Joined",
		"BoughtCompany",
		"PlacedCompany",
		"UsedMachine",
		"SharedPurchase",
		"FirstSteal",
	} :: { FunnelStep },

	-- The currency's name in the economy reports.
	Currency = "Cash",
	Sources = sources,
	Sinks = sinks,

	-- Income arrives every second, so it's added up and reported this often
	-- (and when the player leaves) instead of every payout.
	IncomeReportSeconds = 300,
	-- How often play time is added to the save, for rebirth timings.
	PlaytimeSaveSeconds = 60,
	-- Rebirth numbers above this are labelled together (e.g. "50+") so the
	-- dashboard doesn't fill with labels.
	RebirthLabelCap = 50,
	-- How many recent reports /analytics shows.
	RecentCount = 12,
}
