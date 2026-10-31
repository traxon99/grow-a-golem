-- Runs the real shared math and ProgressionService handlers. No upgrade or
-- gate calculation is copied into the test fixture.
do
	local function fresh()
		local minerals = {}
		for _, id in Config.MineralOrder do
			minerals[id] = 100000
		end
		return {
			golem = { xp = 0, parts = {} },
			minerals = minerals,
			bossesDefeated = {},
			skills = {},
			artifacts = { found = {}, equipped = {} },
			awakening = { count = 0, shards = 0, upgrades = {} },
			ascension = { count = 0, points = 0, upgrades = {} },
		}
	end
	local data = fresh() -- intentionally missing the field, like a legacy save
	local player, golem = {}, {}
	local actions, spent = {}, {}
	local service = loadProgression({
		Config = Config,
		Stats = Stats,
		ForgeStrike = ForgeStrike,
		Remotes = { Notify = { FireClient = function() end } },
		ActionService = {
			register = function(name, handler)
				actions[name] = handler
			end,
		},
		DataService = {
			get = function(who)
				return if who == player then data else nil
			end,
			update = function(_, callback)
				callback(data)
				return true
			end,
			spend = function(_, cost, source)
				if not Stats.canAfford(data, cost) then
					return false
				end
				for mineral, amount in cost do
					data.minerals[mineral] -= amount
				end
				table.insert(spent, { cost = cost, source = source })
				return true
			end,
		},
		Events = { fire = function() end },
		GolemService = {
			get = function()
				return golem
			end,
			sendToZone = function() end,
		},
		PassService = {},
	})
	service.start()
	local ctx = { passes = {}, now = 0 }
	local initial = Stats.compute(data, ctx)
	assert(Stats.coreUpgradeRankCap(data, "toughBody") == 3)
	assert(Stats.coreUpgradeRankCap(data, "heavyHits") == 0)
	assert(Stats.coreUpgradeRankCap(data, "strongSpells") == 0)
	assert(not actions.buyCoreUpgrade({}, "toughBody"), "unloaded players cannot buy upgrades")
	assert(not actions.buyCoreUpgrade(player, {}), "invalid argument types cannot buy upgrades")
	assert(not actions.buyCoreUpgrade(player, "fake"), "unknown IDs cannot spend minerals")
	assert(not actions.buyCoreUpgrade(player, "heavyHits"), "owning iron cannot bypass the island gate")
	assert(#spent == 0 and data.coreUpgrades == nil)

	data.minerals.stone = Config.CoreUpgrades.toughBody.baseCost
	assert(actions.buyCoreUpgrade(player, "toughBody"))
	assert(data.coreUpgrades.toughBody == 1 and data.minerals.stone == 0)
	assert(#spent == 1 and spent[1].source == "coreUpgrade")
	assert(Stats.compute(data, ctx).maxHealth > initial.maxHealth)
	assert(not actions.buyCoreUpgrade(player, "toughBody"), "repeated requests cannot spend missing funds")
	assert(data.coreUpgrades.toughBody == 1 and #spent == 1)
	data.minerals.stone = 100000
	assert(actions.buyCoreUpgrade(player, "toughBody"))
	assert(actions.buyCoreUpgrade(player, "toughBody"))
	local before = data.minerals.stone
	assert(not actions.buyCoreUpgrade(player, "toughBody"), "island rank cap is enforced on the server")
	assert(data.minerals.stone == before and data.coreUpgrades.toughBody == 3)
	assert(spent[2].cost.stone > spent[1].cost.stone, "later ranks cost more")
	assert(actions.craftPart(player, "armL", "copper"))
	assert(data.coreUpgrades.toughBody == 3, "forging a replacement part keeps Core ranks")
	local upgraded = Stats.compute(data, ctx)
	data.coreUpgrades = {}
	assert(upgraded.maxHealth > Stats.compute(data, ctx).maxHealth, "the bonus still applies after replacing parts")

	-- A boss unlock alone is insufficient when the next island also needs size.
	data.bossesDefeated = { ["1"] = true, ["2"] = true }
	assert(Stats.highestUnlockedIslandIndex(data) == 2)
	assert(Stats.coreUpgradeRankCap(data, "toughBody") == 6)
	assert(Stats.coreUpgradeRankCap(data, "strongSpells") == 0)
	data.golem.xp = Stats.xpForLevel(Config.SizeLevels[3])
	assert(Stats.coreUpgradeRankCap(data, "strongSpells") == 3)
	data.golem.xp = Stats.xpForLevel(100)
	for _, zone in Config.ZoneOrder do
		data.bossesDefeated[tostring(zone)] = true
	end
	for _, id in Config.CoreUpgradeOrder do
		local upgrade = Config.CoreUpgrades[id]
		assert(Stats.coreUpgradeRankCap(data, id) == upgrade.maxRank)
		local without = Stats.compute(data, ctx)
		for _ = 1, upgrade.maxRank do
			assert(actions.buyCoreUpgrade(player, id))
		end
		local with = Stats.compute(data, ctx)
		if id == "toughBody" then
			assert(with.maxHealth > without.maxHealth)
		elseif id == "quickHands" then
			assert(with.attackCooldown < without.attackCooldown)
		elseif id == "heavyHits" then
			assert(with.attackDamage > without.attackDamage)
		elseif id == "strongSpells" then
			assert(with.spellPowerMult > without.spellPowerMult)
		end
		local balance = data.minerals[upgrade.mineral]
		assert(not actions.buyCoreUpgrade(player, id))
		assert(data.minerals[upgrade.mineral] == balance, "maxed ranks cannot consume more minerals")
	end
	assert(Stats.returnMiningMultiplier(data, 1) == 3.5)
	assert(Stats.returnMiningMultiplier(data, Config.ZoneOrder[#Config.ZoneOrder]) == 1)
	assert(Stats.returnMiningMultiplier(data, Config.HubZone) == 1)
	assert(Stats.returnMiningMultiplier(data, -99) == 1)
	for _, tier in Config.TierOrder do
		assert(Config.Tiers[tier].cost.stone > 0, "every part tier keeps stone useful")
		local arm = Stats.partCost("armL", tier)
		local core = Stats.partCost("core", tier)
		assert(core.stone >= arm.stone, "stone respects the normal slot multiplier")
	end

	-- Both reset paths clear Core ranks while keeping shard upgrades.
	data.awakening.upgrades.might = 2
	assert(actions.awaken(player))
	assert(next(data.coreUpgrades) == nil and data.awakening.upgrades.might == 2)
	assert(Stats.coreUpgradeRankCap(data, "toughBody") == 3)
	assert(Stats.returnMiningMultiplier(data, 1) == 1)
	data.golem.xp = Stats.xpForLevel(100)
	data.bossesDefeated[tostring(Config.Ascension.requiredBoss)] = true
	data.awakening.count = Config.Ascension.requiredAwakenings
	data.coreUpgrades = { toughBody = 2 }
	assert(actions.ascend(player))
	assert(next(data.coreUpgrades) == nil and data.awakening.upgrades.might == 2)
	print("Core upgrades: real purchases, gates, stats, part replacement, caps, stone costs and resets passed")
end
