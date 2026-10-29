do
	local data = {
		golem = { xp = Stats.xpForLevel(100), parts = { torso = "aether" } },
		minerals = { stone = 100, aether = 200 },
		skills = { e1 = true },
		bossesDefeated = { ["6"] = true },
		artifacts = { found = { pebbleCharm = true } },
		cosmetics = { owned = { earned = true } },
		awakening = { count = 5, shards = 77, upgrades = { might = 2 } },
		ascension = { count = 0, points = 0, upgrades = {} },
	}
	local actions, events, trips = {}, {}, {}
	local golem = {}
	local service = loadProgression({
		Config = Config,
		Stats = Stats,
		Remotes = {},
		ActionService = {
			register = function(name, handler)
				actions[name] = handler
			end,
		},
		DataService = {
			get = function()
				return data
			end,
			update = function(_, fn)
				fn(data)
			end,
		},
		Events = {
			fire = function(name, ...)
				table.insert(events, { name, ... })
			end,
		},
		GolemService = {
			get = function()
				return golem
			end,
			sendToZone = function(_, zone)
				table.insert(trips, zone)
			end,
		},
		PassService = {},
	})
	-- Start registers handlers; the perpetual auto-forge loop is not scheduled.
	-- loadProgression captures this outer local when bundled by check.py.
	service.start()
	assert(actions.ascend({}))
	assert(data.ascension.count == 1 and data.ascension.points == Config.Ascension.points)
	assert(
		data.awakening.count == 5
			and data.ascension.spentAwakenings == 5
			and data.awakening.shards == 77
			and data.awakening.upgrades.might == 2
	)
	assert(data.golem.xp == 0 and next(data.golem.parts) == nil and next(data.skills) == nil)
	assert(data.minerals.stone == 0 and data.minerals.aether == 0)
	assert(next(data.bossesDefeated) == nil and trips[1] == 1)
	assert(data.artifacts.found.pebbleCharm and data.cosmetics.owned.earned)
	assert(not actions.ascend({}), "Repeat requests must not mint extra points")
	data.bossesDefeated["6"] = true
	assert(not actions.ascend({}), "Beating the boss again cannot reuse spent Awakenings")
	assert(data.ascension.points == 1)
	data.bossesDefeated = {}
	assert(not actions.buyAscendUpgrade({}, {}))
	assert(not actions.buyAscendUpgrade({}, "unknown"))
	assert(actions.buyAscendUpgrade({}, "vigor"))
	assert(data.ascension.upgrades.vigor == 1 and data.ascension.points == 0)
	assert(not actions.buyAscendUpgrade({}, "vigor"), "Cannot overspend Ascension points")
	data.ascension.upgrades.vigor = Config.AscendUpgrades.vigor.maxRank
	data.ascension.points = 1
	assert(not actions.buyAscendUpgrade({}, "vigor"), "Cannot exceed max rank")
	assert(data.ascension.points == 1)
	print("PASS: real Ascension handlers reset, preserve, reject repeats, validate IDs, enforce funds and max rank")
end

-- Awakening names what it unlocked, and the auto-forge loop runs for players
-- who unlocked it by Awakening as well as for pass owners.
do
	local data = {
		golem = { xp = Stats.xpForLevel(Config.Awakening.minLevel), parts = { torso = "stone" } },
		minerals = { stone = 10 },
		skills = {},
		bossesDefeated = {},
		artifacts = { found = {} },
		awakening = { count = 0, shards = 0, upgrades = {} },
		ascension = { count = 0, points = 0, upgrades = {} },
	}
	local actions = {}
	local service = loadProgression({
		Config = Config,
		Stats = Stats,
		Remotes = {},
		ActionService = {
			register = function(name, handler)
				actions[name] = handler
			end,
		},
		DataService = {
			get = function()
				return data
			end,
			update = function(_, fn)
				fn(data)
			end,
		},
		Events = { fire = function() end },
		GolemService = {
			get = function()
				return {}
			end,
			sendToZone = function() end,
		},
		PassService = {},
	})
	service.start()
	local ok, message = actions.awaken({})
	assert(ok and data.awakening.count == 1)
	assert(string.find(message, Config.AwakeningUnlocks[1].name, 1, true), "Awakening 1 names its unlock")
	data.golem.xp = Stats.xpForLevel(Config.Awakening.minLevel)
	ok, message = actions.awaken({})
	assert(ok and string.find(message, Config.AwakeningUnlocks[2].name, 1, true))
	print("PASS: Awakening reports the unlock it gives")
end
