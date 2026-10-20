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

	-- Version 8 adds Rebirths. Nobody had rebirthed before.
	[7] = function(data)
		data.Rebirths = 0
	end,

	-- Version 9 adds Rewards (playtime, daily streak, boost, free spins) and
	-- the Index. The Index starts with every company the player owns now.
	[8] = function(data)
		data.Rewards = {
			PlaytimeDay = 0,
			PlaytimeSeconds = 0,
			ClaimedPlaytime = {},
			DailyStreak = 0,
			LastDailyDay = 0,
			BoostSeconds = 0,
			SpinTokens = 0,
		}
		local discovered = {}
		local function add(company)
			if type(company) == "table" and type(company.companyId) == "string" then
				discovered[company.companyId] = true
			end
		end
		for _, company in data.Storage or {} do
			add(company)
		end
		for _, company in data.Placed or {} do
			add(company)
		end
		add(data.Carrying)
		add(data.Machine and data.Machine.company)
		data.Index = { Discovered = discovered, Claimed = {} }
	end,

	-- Version 10 adds LastSeen (offline earnings start from the next visit),
	-- TutorialStep, Stats and RedeemedCodes. Players from before the guide
	-- already know the game, so it starts finished (step 6, Done at the time;
	-- version 14 moves it to 7).
	[9] = function(data)
		data.LastSeen = 0
		data.TutorialStep = 6
		data.Stats = { Steals = 0, Knockouts = 0 }
		data.RedeemedCodes = {}
	end,

	-- Version 11 adds Analytics. Players from before analytics are past the
	-- new-player funnel, so every step counts as reported
	-- (server/Config/Analytics.FunnelSteps) and only new players are counted.
	[10] = function(data)
		data.Analytics = { Funnel = { 1, 2, 3, 4, 5, 6 }, PlaySeconds = 0, RebirthPlaySeconds = 0 }
	end,

	-- Version 12 adds Receipts: developer product purchases already given.
	[11] = function(data)
		data.Receipts = {}
	end,

	-- Version 13 adds Perks (upgrade station levels) and Index.Variants
	-- (variants found). Companies from before have no variant, which means
	-- regular.
	[12] = function(data)
		data.Perks = {}
		data.Index.Variants = {}
	end,

	-- Version 14 adds Uncollected: Cash waiting on each plot's cash pad. The
	-- guide gains a Collect step after Place, as step 3, so the steps from 3
	-- on (Done included) move up one.
	[13] = function(data)
		data.Uncollected = {}
		if type(data.TutorialStep) == "number" and data.TutorialStep >= 3 then
			data.TutorialStep += 1
		end
	end,
} :: { [number]: (data: { [string]: any }) -> () }
