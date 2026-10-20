--!strict
-- The shape of a player's save and what a brand new player starts with.
--
-- Adding a field: add it here. Existing saves get this default the next time
-- they load.
-- Renaming or removing a field, or changing what it means: bump DataVersion
-- and add a step to Migrations.luau. Never change the schema without one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)

export type Data = {
	DataVersion: number,
	Cash: number,
}

local Template: Data = {
	DataVersion = 1,
	Cash = Economy.StartingCash,
}

return Template
