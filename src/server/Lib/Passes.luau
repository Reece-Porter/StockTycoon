--!strict
-- Which game passes each player has this session (Config/Monetisation).
-- MonetisationService keeps it up to date; income and pets read it here, so
-- they don't need MonetisationService, which needs them. Each pass is also a
-- player attribute (Pass<name>, e.g. PassVIP) for the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetisation = require(ReplicatedStorage.Shared.Config.Monetisation)

export type PassName = Monetisation.PassName

local owned: { [Player]: { [string]: boolean } } = {}
-- Players whose passes have all been looked up, so not having one is
-- certain rather than a failed lookup.
local checked: { [Player]: boolean } = {}
local changedCallbacks: { (Player, PassName) -> () } = {}

local Passes = {}

function Passes.owns(player: Player, pass: PassName): boolean
	local passes = owned[player]
	return passes ~= nil and passes[pass] == true
end

function Passes.isChecked(player: Player): boolean
	return checked[player] == true
end

function Passes.set(player: Player, pass: PassName, value: boolean)
	local passes = owned[player] or {}
	owned[player] = passes
	if (passes[pass] == true) == value then
		return
	end
	passes[pass] = value
	player:SetAttribute(`Pass{pass}`, if value then true else nil)
	for _, callback in changedCallbacks do
		task.spawn(callback, player, pass)
	end
end

function Passes.markChecked(player: Player)
	checked[player] = true
end

-- Runs callback(player, pass) whenever a player gets or loses a pass.
function Passes.onChanged(callback: (Player, PassName) -> ())
	table.insert(changedCallbacks, callback)
end

function Passes.forget(player: Player)
	owned[player] = nil
	checked[player] = nil
end

return Passes
