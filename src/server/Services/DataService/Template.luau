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
	-- Companies bought but not placed yet, up to Config/Base.StorageCapacity.
	Storage: { Types.CompanyInstance },
}

local Template: Data = {
	DataVersion = 2,
	Cash = Economy.StartingCash,
	Storage = {},
}

return Template
