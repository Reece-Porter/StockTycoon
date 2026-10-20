--!strict
-- The shape of a player's save and what a brand new player starts with.
--
-- Any change to the shape of the save, including adding a field: bump
-- DataVersion and add a step to Migrations.luau that upgrades the previous
-- version. Never change the schema without one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Types = require(ReplicatedStorage.Shared.Types)

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
}

local Template: Data = {
	DataVersion = 3,
	Cash = Economy.StartingCash,
	Storage = {},
	Placed = {},
}

return Template
