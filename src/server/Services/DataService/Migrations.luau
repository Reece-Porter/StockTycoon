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
} :: { [number]: (data: { [string]: any }) -> () }
