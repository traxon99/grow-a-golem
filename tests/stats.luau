-- Direct unit coverage of Stats.luau's pure progression/economy math,
-- against the real Config. Other tests (progression.luau, economy-service.luau,
-- data-service.luau, ...) exercise Stats indirectly through a service's
-- gameplay flow; this file asserts its formulas themselves, including
-- boundary cases those flows don't happen to hit.
--
-- Still thin wrappers here (not asserted directly): zoneSetComplete,
-- artifactsFound/zoneArtifactCount, bagKey, bossDefeated and isTowerZone.

local function freshData()
	local minerals = {}
	for _, id in Config.MineralOrder do
		minerals[id] = 0
	end
	return {
		campaign = {
			version = 0,
			regions = { [tostring(Config.Kingdom.startingRegion)] = true },
			abilities = {},
		},
		minerals = minerals,
		golem = { xp = 0, parts = {} },
		bossesDefeated = {},
		artifacts = { found = {}, equipped = {}, bags = {}, spares = {}, boundSpares = {} },
		skills = {},
		coreUpgrades = {},
		awakening = { count = 0, shards = 0, upgrades = {} },
		ascension = { count = 0, points = 0, spentAwakenings = 0, upgrades = {} },
		daily = { streak = 0 },
		boosts = { xp = 0, luck = 0 },
		tutorial = { done = false },
		cosmetics = { owned = {}, equipped = {} },
		social = { title = "" },
	}
end

---------------------------------------------------------------- levels and size

-- xpForLevel/levelForXp round-trip: the xp a level requires always maps
-- back to that same level.
for _, level in { 1, 2, 3, 5, 10, 20, 50, 99, 100 } do
	local xp = Stats.xpForLevel(level)
	assert(Stats.levelForXp(xp) == level, `xpForLevel/levelForXp round-trips at level {level}`)
end
assert(Stats.xpForLevel(1) == 0, "level 1 costs no xp")
-- One xp short of a level's threshold stays at the level below.
assert(Stats.levelForXp(Stats.xpForLevel(10) - 1) == 9)

assert(Stats.sizeForLevel(1) == 1)
assert(Stats.sizeForLevel(9) == 2, "level 9 is still size 2 (next step is level 10)")
assert(Stats.sizeForLevel(10) == 3)
assert(Stats.sizeForLevel(28) == 5)
assert(Stats.scaleForSize(1) == 1)
assert(Stats.scaleForSize(3) == 1.5)

---------------------------------------------------------------- costs

do
	local cost = Stats.partCost("core", "iron")
	assert(cost.iron == 45 and cost.copper == 60 and cost.stone == 75, "core's 1.5x multiplier rounds costs up")
end
do
	local cost = Stats.partCost("armL", "stone")
	assert(cost.stone == 20, "armL has no cost multiplier")
end

local data = freshData()
data.minerals.stone = 19
assert(not Stats.canAfford(data, { stone = 20 }), "one mineral short cannot afford")
data.minerals.stone = 20
assert(Stats.canAfford(data, { stone = 20 }), "exactly enough can afford")
data.minerals.stone = 20
assert(not Stats.canAfford(data, { stone = 20, copper = 1 }), "missing a second mineral entirely cannot afford")

assert(Stats.upgradeCost("might", 0) == 3)
assert(Stats.upgradeCost("might", 5) == 13)
do
	local cost = Stats.coreUpgradeCost("toughBody", 0)
	assert(cost.stone == 60)
end
assert(Stats.coreUpgradeCost("toughBody", 2).stone == 100)

assert(Stats.awakeningShards(15) == 0, "shards start accruing above the base level")
assert(Stats.awakeningShards(14) == 0, "below the base level, no shards (clamped to 0)")
assert(Stats.awakeningShards(20) == 5)

---------------------------------------------------------------- ascension

data = freshData()
data.awakening.count = 5
data.bossesDefeated["6"] = true
assert(Stats.canAscend(data), "enough awakenings and the final boss down")
data.awakening.count = 4
assert(not Stats.canAscend(data), "one awakening short")
data.awakening.count = 5
data.bossesDefeated["6"] = nil
assert(not Stats.canAscend(data), "final boss not yet defeated")
data.bossesDefeated["6"] = true
data.ascension.spentAwakenings = 1
assert(not Stats.canAscend(data), "an already-spent awakening no longer counts")

---------------------------------------------------------------- skills

data = freshData()
data.golem.xp = Stats.xpForLevel(3) -- level 3: 2 skill points available
assert(Stats.skillPointsAvailable(data) == 2)
do
	local ok, reason = Stats.canLearnSkill(data, "e1")
	assert(ok and reason == nil, "e1 has no prerequisite")
end
do
	local ok, reason = Stats.canLearnSkill(data, "e2")
	assert(not ok and reason == "Learn the skill before this one.", "e2 needs e1 first")
end
data.skills.e1 = true
assert(Stats.skillPointsSpent(data) == 1)
assert(Stats.skillPointsAvailable(data) == 1)
do
	local ok = Stats.canLearnSkill(data, "e2")
	assert(ok, "e1 learned unblocks e2")
end
do
	local ok, reason = Stats.canLearnSkill(data, "e1")
	assert(not ok and reason == "Already learned")
end
do
	local ok, reason = Stats.canLearnSkill(data, "madeUpSkill")
	assert(not ok and reason == "Unknown skill")
end
do
	-- A level-1 golem has 0 skill points. r1 has no prerequisite of its own
	-- (it's first in its branch), so this fails purely on points, not on
	-- the prerequisite check.
	local poor = freshData()
	assert(Stats.skillPointsAvailable(poor) == 0)
	local ok, reason = Stats.canLearnSkill(poor, "r1")
	assert(not ok and reason == "Not enough skill points")
end

---------------------------------------------------------------- zones and travel

assert(Config.Kingdom.enabled == false, "these zone checks assume the pre-Kingdom gate (campaign mode off)")

data = freshData()
assert(Stats.zoneUnlocked(data, 1), "zone 1 has no gate")
do
	local ok, reason = Stats.zoneUnlocked(data, 2)
	assert(not ok and reason:find("Rockjaw"), "zone 2 needs its boss down")
end
data.bossesDefeated["1"] = true
assert(Stats.zoneUnlocked(data, 2), "boss 1 down unlocks zone 2")
do
	local ok, reason = Stats.zoneUnlocked(data, 3)
	assert(not ok and reason:find("Matron"), "zone 3's boss gate is checked before its size gate")
end
data.bossesDefeated["2"] = true
do
	local ok, reason = Stats.zoneUnlocked(data, 3)
	assert(not ok and reason == "Reach golem size 3", "boss 2 down but golem still size 1")
end
data.golem.xp = Stats.xpForLevel(10) -- size 3
assert(Stats.zoneUnlocked(data, 3), "both gates satisfied")
do
	local ok, reason = Stats.zoneUnlocked(data, 999)
	assert(not ok and reason == "Unknown zone")
end
-- travelUnlocked mirrors zoneUnlocked while Kingdom mode is off.
assert(Stats.travelUnlocked(data, 3))

data = freshData()
assert(Stats.campaignZoneUnlocked(data, 1), "the starting region is already discovered")
do
	local ok, reason = Stats.campaignZoneUnlocked(data, 2)
	assert(not ok and reason == "Discover this region first")
end

---------------------------------------------------------------- core upgrade ranks

data = freshData()
data.bossesDefeated["1"] = true -- unlocks zone 2; zone 3 stays locked
assert(Stats.coreUpgradeRankCap(data, "toughBody") == 6, "island 1, 2 islands open -> 2 * 3 ranks")
assert(Stats.coreUpgradeRankCap(data, "heavyHits") == 3, "island 2, only itself open -> 1 * 3 ranks")
assert(Stats.coreUpgradeRankCap(data, "strongSpells") == 0, "island 3 not open yet")
do
	local ok, reason = Stats.canBuyCoreUpgrade(data, "strongSpells")
	assert(not ok and reason == "Open another island for more ranks.")
end
do
	local ok, reason = Stats.canBuyCoreUpgrade(data, "toughBody")
	assert(not ok and reason == "Not enough minerals", "no stone saved yet")
end
data.minerals.stone = 60
assert(Stats.canBuyCoreUpgrade(data, "toughBody"))
data.coreUpgrades.toughBody = 18 -- maxRank
do
	local ok, reason = Stats.canBuyCoreUpgrade(data, "toughBody")
	assert(not ok and reason == "Core upgrade is maxed out.")
end
do
	local ok, reason = Stats.canBuyCoreUpgrade(data, "madeUpUpgrade")
	assert(not ok and reason == "Unknown Core upgrade")
end

assert(math.abs(Stats.returnMiningMultiplier(data, 1) - 1.5) < 1e-9, "one island ahead of zone 1")
assert(Stats.returnMiningMultiplier(data, 2) == 1, "zone 2 is the frontier itself")
assert(Stats.returnMiningMultiplier(data, 999) == 1, "an unknown zone gets no bonus")

---------------------------------------------------------------- tower rewards

do
	local reward = Stats.towerWaveEnemies(1, 1)
	assert(reward == 6, "wave 1, solo: base count only")
end
assert(Stats.towerWaveEnemies(5, 1) == 14)
assert(Stats.towerBossFraction(5) == 0.6)
assert(Stats.towerBossFraction(1) == nil, "only waves 5 and 10 carry a boss")
do
	local reward = Stats.towerWaveReward(1, 1)
	assert(
		reward.minerals.stone == 18 and reward.xp == 46,
		"wave 1 pays a weighted mix of zone 1's enemies, scaled by rewardRate"
	)
end
do
	local reward = Stats.towerWaveReward(1, 5)
	assert(
		reward.minerals.stone == 156 and reward.minerals.copper == 30 and reward.xp == 221,
		"the boss wave adds the island boss's drops at its health fraction"
	)
end
do
	local reward = Stats.towerRunReward(1)
	assert(
		reward.minerals.stone == 765 and reward.minerals.copper == 80 and reward.xp == 1467,
		"a full clear sums every one of the route's 10 waves"
	)
end

---------------------------------------------------------------- artifact odds

data = freshData()
do
	-- A fresh bag: 167 marbles, 1 winner, no luck.
	local marblesLeft, winnersLeft, size = Stats.artifactBag(data, 1, "drop", 1)
	assert(marblesLeft == 167 and winnersLeft == 1 and size == 167)
end
do
	-- Luck shrinks the bag but keeps its one winner, so the chance doubles.
	local marblesLeft, winnersLeft, size = Stats.artifactBag(data, 1, "drop", 2)
	assert(marblesLeft == 84 and winnersLeft == 1 and size == 84)
end
do
	local chance, rollsLeft, unfound = Stats.artifactOdds(data, 1, "drop", 1)
	assert(
		math.abs(chance - 1 / 167) < 1e-9 and rollsLeft == 167 and unfound == 4,
		"none of zone 1's 4 drops found yet"
	)
end
do
	local chance, rollsLeft, unfound = Stats.artifactOdds(data, 1, "drop", 2)
	assert(math.abs(chance - 1 / 84) < 1e-9 and rollsLeft == 84, "2x luck halves the bag and doubles the chance")
end
-- Misses raise the chance: this bag has already drawn 100 of its 167 without
-- a win, so the one winner left is now concentrated in fewer marbles.
data.artifacts.bags[Stats.bagKey(1, "drop")] = { drawn = 100, wins = 0 }
do
	local chance, rollsLeft = Stats.artifactOdds(data, 1, "drop", 1)
	assert(math.abs(chance - 1 / 67) < 1e-9 and rollsLeft == 67, "bad-luck protection: more misses, better odds")
end

-- Once every drop from a zone/source is found, the same roll gives spares.
data = freshData()
for _, id in { "pebbleCharm", "quarryLantern", "oldChisel", "rootboundRing" } do
	data.artifacts.found[id] = true
end
do
	local chance, rollsLeft, unfound = Stats.artifactOdds(data, 1, "drop", 1)
	assert(chance == 0 and rollsLeft == 0 and unfound == 0, "nothing left to find")
end
do
	local chance, rollsLeft, isSpares = Stats.spareOdds(data, 1, "drop", 1)
	assert(math.abs(chance - 1 / 167) < 1e-9 and rollsLeft == 167 and isSpares, "a fresh bag now rolls spares instead")
end
do
	-- A zone/source with no artifacts at all (an invalid zone here) rolls
	-- for nothing, not spares.
	local chance, rollsLeft, isSpares = Stats.spareOdds(data, 999, "drop", 1)
	assert(chance == 0 and rollsLeft == 0 and not isSpares)
end

data = freshData()
data.artifacts.spares.pebbleCharm = 3
data.artifacts.boundSpares.pebbleCharm = 1
assert(Stats.tradableSpares(data, "pebbleCharm") == 2)
assert(Stats.tradableSpares(data, "quarryLantern") == 0, "no spares recorded at all")

---------------------------------------------------------------- events (synthetic windows, not the real weekly event)

do
	local event = { startsAt = 1000, endsAt = 2000 }
	local startsAt, endsAt = Stats.eventWindow(event, 500)
	assert(startsAt == 1000 and endsAt == 2000, "the window is reported even before it starts")
	assert(#Stats.activeEvents(500) == 0, "but it isn't active until startsAt")
	startsAt, endsAt = Stats.eventWindow(event, 1000)
	assert(startsAt == 1000 and endsAt == 2000, "active at the exact start")
	startsAt, endsAt = Stats.eventWindow(event, 1999)
	assert(startsAt == 1000 and endsAt == 2000, "active one tick before the end")
	startsAt, endsAt = Stats.eventWindow(event, 2000)
	assert(startsAt == nil and endsAt == nil, "ended at the exact end boundary (exclusive)")
end

do
	local real = Config.Events
	Config.Events = {
		{ id = "a", startsAt = 0, endsAt = 1000, modifiers = { minerals = 2 } },
		{ id = "b", startsAt = 500, endsAt = 1500, modifiers = { minerals = 1.5, xp = 3 } },
	}
	assert(#Stats.activeEvents(100) == 1, "only event a is running")
	assert(math.abs(Stats.eventMultiplier(100, "minerals") - 2) < 1e-9)
	assert(#Stats.activeEvents(700) == 2, "both overlap here")
	assert(math.abs(Stats.eventMultiplier(700, "minerals") - 3) < 1e-9, "modifiers multiply together")
	assert(math.abs(Stats.eventMultiplier(700, "xp") - 3) < 1e-9, "only b modifies xp")
	assert(Stats.eventMultiplier(700, "luck") == 1, "an unmodified stat stays at 1x")
	assert(#Stats.activeEvents(1600) == 0, "both have ended")
	assert(Stats.eventById("b").modifiers.xp == 3)
	assert(Stats.eventById("madeUpEvent") == nil)
	Config.Events = real
end

-- The real doubleMinerals weekend event: 1000 is a quiet Thursday, nowhere
-- near a Saturday-through-Monday weekend window.
assert(Stats.eventMultiplier(1000, "minerals") == 1, "the real weekend event is not active at this timestamp")

---------------------------------------------------------------- awakening unlocks, cosmetics and titles

data = freshData()
assert(not Stats.awakeningUnlocked(data, "autoForge"))
do
	local unlock = Stats.nextAwakeningUnlock(data)
	assert(unlock.kind == "autoForge", "the first Awakening unlocks Auto-Forge")
end
data.awakening.count = 1
assert(Stats.awakeningUnlocked(data, "autoForge"))
assert(not Stats.awakeningUnlocked(data, "artifactSlot"))
assert(Stats.nextAwakeningUnlock(data).kind == "artifactSlot")
data.awakening.count = 3
assert(Stats.awakeningUnlocked(data, "title"), "the third Awakening unlocks a title")
assert(Stats.nextAwakeningUnlock(data) == nil, "every Awakening unlock is already earned")

data = freshData()
assert(not Stats.ownsCosmetic(data, "mossy"))
assert(Stats.cosmeticProgress(data, "mossy") == 0, "boss not down yet (current of 0/1)")
data.bossesDefeated["1"] = true
assert(Stats.cosmeticEarned(data, "mossy"), "beating boss 1 earns the mossy skin")
data.cosmetics.owned.mossy = true
data.cosmetics.equipped.skin = "mossy"
assert(Stats.ownsCosmetic(data, "mossy"))
assert(Stats.equippedCosmetic(data, "skin") == "mossy")
assert(Stats.equippedCosmetic(data, "outfit") == nil, "nothing equipped in that slot")

assert(Stats.titleEarned(data, "rockjawSlayer"), "same boss-down unlock as the mossy skin")
assert(not Stats.titleEarned(data, "veteran"), "level 30 title not reached")
data.social.title = "rockjawSlayer"
assert(Stats.equippedTitle(data) == "Rockjaw Slayer")
data.social.title = "veteran" -- not earned
assert(Stats.equippedTitle(data) == nil, "an unearned title never shows")

---------------------------------------------------------------- bonuses

data = freshData()
data.coreUpgrades.toughBody = 3
data.skills.e1 = true
data.awakening.count = 2
data.awakening.upgrades.might = 2
data.ascension.upgrades.vigor = 1
data.artifacts.found.pebbleCharm = true
data.artifacts.found.rockjawTooth = true
data.artifacts.equipped = { "pebbleCharm", "rockjawTooth" }
local ctx = { passes = { extraSlot = true, vip = true, longRest = true }, now = 1000 }
local bonus, slots, capHours = Stats.bonuses(data, ctx)
assert(bonus.health == 40, "3 toughBody ranks + 2 might ranks + vigor + pebbleCharm")
assert(bonus.damage == 33, "e1 + 2 might ranks + vigor + rockjawTooth")
assert(bonus.minerals == 20, "10% per Awakening, 2 Awakenings")
assert(bonus.xp == 10, "the VIP pass")
assert(slots == 5, "base 3 + extraSlot pass + the 2nd Awakening's free slot")
assert(capHours == 12, "longRest raises the cap to Config.LongRestCapHours")

---------------------------------------------------------------- compute (the full pipeline)

do
	-- A level-1 golem with nothing equipped: every multiplier and bonus is
	-- exactly the base Config.Golem numbers.
	local baseline = freshData()
	local stats = Stats.compute(baseline, { passes = {}, now = 1000 })
	assert(stats.level == 1 and stats.size == 1 and stats.scale == 1)
	assert(stats.maxHealth == 200 and stats.attackDamage == 12 and stats.miningDamage == 10)
	assert(stats.walkSpeed == 14 and stats.attackRange == 10 and stats.miningRange == 10)
	assert(stats.mineralMult == 1 and stats.xpMult == 1 and stats.luckMult == 1)
	assert(stats.spellPowerMult == 1 and stats.spellCooldownMult == 1)
	assert(stats.artifactSlots == 3 and stats.offlineCapHours == 2)
	assert(stats.fullSet == nil, "no parts worn")
end

do
	-- A full set of the cheapest tier: health and damage get the full-set bonus.
	local allStone = freshData()
	for _, slot in Config.SlotOrder do
		allStone.golem.parts[slot] = "stone"
	end
	local stats = Stats.compute(allStone, { passes = {}, now = 1000 })
	assert(stats.maxHealth == 285, "base 200 + part bonuses, times the 15% full-set bonus")
	assert(math.abs(stats.attackDamage - 22.425) < 1e-6)
	assert(math.abs(stats.miningDamage - 15) < 1e-9, "mining isn't part of the full-set bonus")
	assert(math.abs(stats.walkSpeed - 14.6) < 1e-9)
	assert(stats.fullSet == "stone")
end

do
	-- Mixed tiers never qualify for the full-set bonus, however strong.
	local mixed = freshData()
	mixed.golem.parts = { core = "crystal", torso = "stone", armL = "stone", armR = "stone", legs = "stone" }
	local stats = Stats.compute(mixed, { passes = {}, now = 1000 })
	assert(stats.fullSet == nil)
end

---------------------------------------------------------------- campaign migration (#213)

do
	local wasEnabled = Config.Kingdom.enabled
	Config.Kingdom.enabled = false
	local data = freshData()
	data.campaign.version = 0
	data.golem.parts = { armL = "copper", armR = "iron" }
	data.bossesDefeated = { ["1"] = true, ["2"] = true }
	data.golem.xp = Stats.xpForLevel(10) -- size 3, unlocks zone 3 in legacy mode
	Stats.migrateCampaign(data)
	assert(data.campaign.version == Config.Kingdom.campaignVersion)
	assert(data.campaign.regions["1"] and data.campaign.regions["2"] and data.campaign.regions["3"])
	assert(not data.campaign.regions["4"])
	assert(data.campaign.abilities.smash and data.campaign.abilities.lift)
	assert(not data.campaign.abilities.reveal)
	assert(data.campaign.legacyPending == true, "rollout off marks a final legacy capture on leave")
	assert(
		(not data.campaign.obstacles or next(data.campaign.obstacles) == nil)
			and (not data.campaign.projects or next(data.campaign.projects) == nil),
		"migration never invents obstacles or projects"
	)
	Config.Kingdom.enabled = true
	Stats.migrateCampaign(data)
	assert(data.campaign.legacyPending == nil)
	assert(data.campaign.regions["3"], "already-migrated regions stay")
	-- Kingdom on and version current: new run progress does not backfill regions.
	data.bossesDefeated["3"] = true
	Stats.migrateCampaign(data)
	assert(not data.campaign.regions["4"], "no retroactive region grant after version is current")
	Config.Kingdom.enabled = wasEnabled
end

---------------------------------------------------------------- highestZone and island index

do
	local wasEnabled = Config.Kingdom.enabled
	Config.Kingdom.enabled = false
	local data = freshData()
	assert(Stats.highestZone(data) == 1)
	assert(Stats.highestUnlockedIslandIndex(data) == 1)
	data.bossesDefeated["1"] = true
	assert(Stats.highestZone(data) == 2)
	assert(Stats.highestUnlockedIslandIndex(data) == 2)
	data.bossesDefeated["2"] = true
	data.golem.xp = Stats.xpForLevel(10)
	assert(Stats.highestZone(data) == 3)
	assert(Stats.highestUnlockedIslandIndex(data) == 3)
	data.bossesDefeated["3"] = true
	data.golem.xp = Stats.xpForLevel(18) -- size 4 for zone 4
	assert(Stats.highestZone(data) == 4)
	assert(Stats.highestUnlockedIslandIndex(data) == 4)
	Config.Kingdom.enabled = wasEnabled
end

do
	local wasEnabled = Config.Kingdom.enabled
	Config.Kingdom.enabled = true
	local data = freshData()
	data.campaign.regions = { ["1"] = true, ["6"] = true }
	assert(Stats.highestZone(data) == 1, "campaign travel ignores run boss gates")
	assert(Stats.travelUnlocked(data, 6) and not Stats.zoneUnlocked(data, 6))
	assert(not Stats.travelUnlocked(data, 2))
	Config.Kingdom.enabled = wasEnabled
end

print("stats: core progression/economy math checks passed")
