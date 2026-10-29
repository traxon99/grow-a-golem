-- Exercise the real ProgressionService forge handlers with a controlled server clock.
do
	local player = {}
	local data = { golem = { parts = {} }, minerals = {} }
	for _, id in Config.MineralOrder do
		data.minerals[id] = 1000000
	end
	local actions, notifications, grants = {}, {}, {}
	local service = loadProgression({
		Config = Config,
		ForgeStrike = ForgeStrike,
		Stats = Stats,
		Remotes = {
			Notify = {
				FireClient = function(_, who, kind, a, b, c)
					assert(who == player)
					table.insert(notifications, { kind, a, b, c })
				end,
			},
		},
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
			spend = function(_, cost)
				if not Stats.canAfford(data, cost) then
					return false
				end
				for id, amount in cost do
					data.minerals[id] -= amount
				end
				return true
			end,
			addMinerals = function(_, minerals)
				table.insert(grants, minerals)
				for id, amount in minerals do
					data.minerals[id] += amount
				end
			end,
		},
		Events = { fire = function() end },
		GolemService = {},
		PassService = {},
	})
	service.start()
	local slot, tier = Config.SlotOrder[1], Config.TierOrder[1]
	local cost = Stats.partCost(slot, tier)
	assert(actions.craftPart(player, slot, tier))
	assert(data.golem.parts[slot] == tier, "normal forge finishes before challenge")
	assert(#notifications == 1 and notifications[1][1] == "forgeStrike")
	assert(notifications[1][2] == slot and notifications[1][3] == tier)
	local expected = ForgeStrike.refund(cost, Config.ForgeStrike.refundFraction)
	for id, amount in cost do
		assert(data.minerals[id] == 1000000 - amount, "forge cost paid once")
	end
	forgeClock = notifications[1][4]
	local ok = actions.finishForgeStrike(player)
	assert(ok and #grants == 1, "perfect strike pays exactly one fixed refund")
	for id, amount in expected do
		assert(grants[1][id] == amount)
	end
	assert(not actions.finishForgeStrike(player), "replay cannot pay twice")
	assert(#grants == 1)
	assert(not actions.craftPart(player, slot, tier), "same part cannot be forged again")
	local secondTier = Config.TierOrder[2]
	assert(actions.craftPart(player, slot, secondTier))
	assert(#notifications == 2)
	forgeClock = notifications[2][4]
		- Config.ForgeStrike.halfWindowSeconds
		- Config.ForgeStrike.latencySlackSeconds
		- 0.1
	assert(actions.finishForgeStrike(player), "early attempt still leaves normal craft")
	assert(#grants == 1, "early strike has no bonus")
	assert(not actions.finishForgeStrike(player), "miss consumes attempt")
	print("forge-strike-service: immediate forge, exact reward, replay and miss passed")
end
