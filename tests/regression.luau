-- The check script bundles real Config, Stats and SessionLease above this file.
-- Only Roblox value constructors are stubbed; no game logic is reimplemented.
local function fresh()
	return {
		golem = { xp = 0, parts = {} },
		minerals = {},
		bossesDefeated = {},
		artifacts = { found = {}, equipped = {}, bags = {}, spares = {}, boundSpares = {} },
		skills = {},
		awakening = { count = 0, shards = 0, upgrades = {} },
		ascension = { count = 0, points = 0, upgrades = {} },
		boosts = {},
	}
end
local ctx = { passes = {}, now = 0 }
local player = fresh()
assert(Stats.compute(player, ctx).level == 1)
assert(Stats.levelForXp(10 ^ 12) == Config.Golem.maxLevel)
for level = 1, Config.Golem.maxLevel do
	assert(Stats.levelForXp(Stats.xpForLevel(level)) == level)
end
assert(#Config.ZoneOrder == 6 and #Config.TierOrder == 8)
assert(#Config.ArtifactOrder == 36)
local availableMinerals = {}
local allIds = {}
for _, zoneId in Config.ZoneOrder do
	local zone = Config.Zones[zoneId]
	assert(#zone.enemies >= 2)
	assert(
		Config.Visuals.zoneTints[zone.theme] and Config.Visuals.zoneAtmosphere[zone.theme],
		`zone {zoneId} theme needs a tint and haze`
	)
	assert(Config.Bosses[zoneId].slam.warning >= 1.2)
	if zone.gate.boss then
		assert(zone.gate.boss < zoneId, "A zone cannot require its own boss")
	end
	if zone.gate.size then
		assert(zone.gate.size <= #Config.SizeLevels)
	end
	for _, entry in zone.nodes do
		assert(Config.Nodes[entry.mineral] and Config.Minerals[entry.mineral])
		assert(entry.weight > 0)
		availableMinerals[entry.mineral] = true
	end
	for _, id in zone.enemies do
		local enemy = Config.Enemies[id]
		assert(enemy and (enemy.spawnWeight or 1) > 0 and enemy.maxHealth > 0)
		for mineral in enemy.drops do
			assert(Config.Minerals[mineral])
		end
	end
	local sources = { drop = 0, boss = 0, hidden = 0 }
	for _, id in Config.ArtifactOrder do
		local artifact = Config.Artifacts[id]
		if artifact.zone == zoneId then
			sources[artifact.source] += 1
		end
	end
	assert(sources.drop == 4 and sources.boss == 1 and sources.hidden == 1)
	assert(zoneId == 1 or not Stats.zoneUnlocked(player, zoneId))
end
for _, id in Config.ArtifactOrder do
	assert(not allIds[id], "Artifact IDs must be unique")
	allIds[id] = true
end
for _, branch in Config.SkillBranches do
	assert(#branch.nodes == 8)
	for _, id in branch.nodes do
		assert(Config.Skills[id])
	end
end
local lastPower = 0
for _, id in Config.TierOrder do
	local tier = Config.Tiers[id]
	assert(tier.power > lastPower)
	lastPower = tier.power
	for mineral, amount in tier.cost do
		assert(availableMinerals[mineral] and amount > 0, "Forge cost must be earnable")
	end
end
-- Every gate is attainable on a free save with the required boss and level.
player.golem.xp = Stats.xpForLevel(Config.Golem.maxLevel)
for _, zoneId in Config.ZoneOrder do
	assert(Stats.zoneUnlocked(player, zoneId))
	player.bossesDefeated[tostring(zoneId)] = true
end
assert(not Stats.canAscend(player))
player.awakening.count = Config.Ascension.requiredAwakenings
assert(Stats.canAscend(player))
player.bossesDefeated[tostring(Config.Ascension.requiredBoss)] = nil
assert(not Stats.canAscend(player))
player.ascension.upgrades.vigor = 1
local withVigor = Stats.compute(player, ctx)
player.ascension.upgrades = {}
assert(withVigor.attackDamage > Stats.compute(player, ctx).attackDamage)
-- New zone rolls retain the exact luck and marble-bag rules used by old zones.
for zoneId = 1, 6 do
	local lucky = math.ceil(Config.ArtifactBags.drop.marbles / 2)
	local odds, left, unfound = Stats.artifactOdds(player, zoneId, "drop", 2)
	assert(odds == 1 / lucky and unfound == 4 and left == lucky)
	player.artifacts.bags[Stats.bagKey(zoneId, "drop")] = { drawn = lucky - 1, wins = 0 }
	local sure, atEnd = Stats.artifactOdds(player, zoneId, "drop", 2)
	assert(sure == 1 and atEnd == 1)
	-- Without luck the same bag is 167 marbles, and the miss count carries over.
	local plain, plainLeft = Stats.artifactOdds(player, zoneId, "drop", 1)
	assert(
		plain == 1 / (Config.ArtifactBags.drop.marbles - lucky + 1)
			and plainLeft == Config.ArtifactBags.drop.marbles - lucky + 1
	)
end
-- Marble bags: weighted bags follow their weights exactly over one bag.
do
	local bag = MarbleBag.new({ { value = "a", weight = 3 }, { value = "b", weight = 1 } })
	for _ = 1, 3 do
		local counts = { a = 0, b = 0 }
		for _ = 1, 4 do
			local value = bag:draw()
			counts[value] += 1
		end
		assert(counts.a == 3 and counts.b == 1, "each bag of four holds exactly three a and one b")
	end
	local after = MarbleBag.after({ drawn = 2, wins = 0 }, 3, 1, false)
	assert(after.drawn == 0 and after.wins == 0, "a drawn-out bag refills")
end
-- Fast hop blocked, crash lease recoverable, delayed old-server write rejected.
local record = { minerals = { stone = 50 } }
assert(SessionLease.canAcquire(record, "A", 0))
record._session = { token = "A", expiresAt = 180 }
assert(not SessionLease.canAcquire(record, "B", 179))
assert(SessionLease.canAcquire(record, "B", 180))
assert(SessionLease.canAcquire(record, "A", 1))
record._session = { token = "B", expiresAt = 360 }
assert(not SessionLease.owns(record, "A"))
assert(SessionLease.owns(record, "B"))
local snapshot = SessionLease.copy(record)
record.minerals.stone = 999
assert(snapshot.minerals.stone == 50, "Pending saves must have an immutable snapshot")
record._session = nil
assert(SessionLease.canAcquire(record, "C", 181))
record._session = { token = "B" }
assert(not SessionLease.canAcquire(record, "C", 999), "Malformed leases fail closed")
print("PASS: level boundaries, free gate/forge reachability, six-zone content, Ascension, odds/bags, session leases")
