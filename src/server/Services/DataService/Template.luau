--!strict
-- The shape of a player's save and what a brand new player starts with.
--
-- Any change to the shape of the save, including adding a field: bump
-- DataVersion and add a step to Migrations.luau that upgrades the previous
-- version. Never change the schema without one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(ReplicatedStorage.Shared.Config.Base)
local Onboarding = require(ReplicatedStorage.Shared.Config.Onboarding)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Types = require(ReplicatedStorage.Shared.Types)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

export type Data = {
	DataVersion: number,
	Cash: number,
	-- Companies bought but not placed yet. Config/Base.StorageCapacity limits
	-- what a player can store themselves; companies returned to storage
	-- automatically (for example after a reset) may go over it.
	Storage: { Types.CompanyInstance },
	-- Placed companies by plot key, e.g. "Floor1/Plot3".
	Placed: { [string]: Types.CompanyInstance },
	-- The company in the player's hands, saved so it can never be lost. A save
	-- that loads with one (the server stopped mid-carry) moves it to Storage.
	Carrying: Types.CompanyInstance?,
	-- Plots open on each floor, e.g. { 10, 7 }: Floor 1 full, Floor 2 has 7.
	-- The number of entries is the number of floors opened.
	UnlockedPlots: { number },
	-- The company in the player's Valuation Machine, if a run is going. Saved
	-- so it can never be lost: a save that loads with one is settled as if
	-- time ran out.
	Machine: Types.MachineRun?,
	-- Ids of the weapons the player owns (Config/Weapons), and the one in
	-- their hands. Kept through rebirth.
	OwnedWeapons: { string },
	EquippedWeapon: string,
	-- Every pet the player owns, placed or not (Config/Pets.InventoryCap at
	-- most). Kept through rebirth.
	Pets: { Types.PetInstance },
	-- How many times the player has rebirthed. Kept through rebirth.
	Rebirths: number,
	-- Playtime and daily rewards, banked boost and free spins. Kept through
	-- rebirth.
	Rewards: Types.RewardsState,
	-- Every company ever owned, and the Index prizes claimed. Kept through
	-- rebirth.
	Index: Types.IndexState,
	-- os.time() when the player was last in the game, for offline earnings.
	-- 0 until they have been.
	LastSeen: number,
	-- How far through the new-player guide they are (Config/Onboarding.Steps).
	TutorialStep: number,
	-- Lifetime counts for the leaderboards. Kept through rebirth.
	Stats: { Steals: number, Knockouts: number },
	-- Codes redeemed, in capitals. Each code works once per player.
	RedeemedCodes: { string },
}

local Template: Data = {
	DataVersion = 10,
	Cash = Economy.StartingCash,
	Storage = {},
	Placed = {},
	UnlockedPlots = { BaseConfig.StartingPlots },
	OwnedWeapons = { Weapons.Starter },
	EquippedWeapon = Weapons.Starter,
	Pets = {},
	Rebirths = 0,
	Rewards = {
		PlaytimeDay = 0,
		PlaytimeSeconds = 0,
		ClaimedPlaytime = {},
		DailyStreak = 0,
		LastDailyDay = 0,
		BoostSeconds = 0,
		SpinTokens = 0,
	},
	Index = {
		Discovered = {},
		Claimed = {},
	},
	LastSeen = 0,
	TutorialStep = Onboarding.Steps.Buy,
	Stats = { Steals = 0, Knockouts = 0 },
	RedeemedCodes = {},
}

return Template
