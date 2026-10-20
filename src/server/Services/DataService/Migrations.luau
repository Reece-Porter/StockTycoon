--!strict
-- Steps that upgrade old saves. Migrations[n] turns a version n save into a
-- version n + 1 save by editing the table in place. DataService runs every step
-- a save needs, in order, on a copy, and only keeps the result if they all
-- succeed.

return {
	-- Version 2 adds Storage: companies bought but not placed yet.
	[1] = function(data)
		data.Storage = {}
	end,

	-- Version 3 adds Placed: companies on plots, by plot key. (Carrying, the
	-- company in the player's hands, is optional and starts empty.)
	[2] = function(data)
		data.Placed = {}
	end,

	-- Version 4 adds UnlockedPlots: plots open on each floor. Before upgrades
	-- existed every base had 6 plots open on Floor 1.
	[3] = function(data)
		data.UnlockedPlots = { 6 }
	end,

	-- Version 5 adds Machine: the company in the Valuation Machine, if any. It
	-- is optional and starts empty, so there is nothing to fill in.
	[4] = function(_data) end,

	-- Version 6 adds OwnedWeapons and EquippedWeapon. Everyone starts with the
	-- free Rolled-up Newspaper.
	[5] = function(data)
		data.OwnedWeapons = { "Newspaper" }
		data.EquippedWeapon = "Newspaper"
	end,

	-- Version 7 adds Pets: every pet the player owns. Nobody had any before.
	[6] = function(data)
		data.Pets = {}
	end,
} :: { [number]: (data: { [string]: any }) -> () }
