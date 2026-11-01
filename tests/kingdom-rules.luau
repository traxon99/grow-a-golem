-- KingdomRules (#216): the one requirement resolver the server and prompt share.
do
	local wall = Config.Kingdom.obstacles.quarryWall
	local function player(abilities, obstacles, xp, bosses)
		return {
			campaign = { abilities = abilities or {}, obstacles = obstacles or {} },
			golem = { xp = xp or 0, parts = {} },
			bossesDefeated = bosses or {},
		}
	end
	local status, missing = KingdomRules.obstacleStatus(player(), "quarryWall")
	assert(status == "locked" and missing == "Forge a copper arm.", "names the missing tool first")
	status, missing = KingdomRules.obstacleStatus(player({ smash = true }), "quarryWall")
	assert(status == "ready" and missing == nil)
	status = KingdomRules.obstacleStatus(player({ smash = true }, { quarryWall = true }), "quarryWall")
	assert(status == "done")
	assert(KingdomRules.obstacleStatus(player(), "nope") == "locked")

	-- Size, then boss, after the tool.
	local saved = wall.gate
	wall.gate = { size = 3, boss = 1 }
	status, missing = KingdomRules.obstacleStatus(player({ smash = true }), "quarryWall")
	assert(status == "locked" and missing == "Grow to size 3.")
	local grown = Stats.xpForLevel(Config.SizeLevels[3])
	status, missing = KingdomRules.obstacleStatus(player({ smash = true }, {}, grown), "quarryWall")
	assert(status == "locked" and missing == `Beat {Config.Bosses[1].displayName}.`)
	status = KingdomRules.obstacleStatus(player({ smash = true }, {}, grown, { ["1"] = true }), "quarryWall")
	assert(status == "ready")
	status, missing = KingdomRules.obstacleStatus(player({}, {}, grown, { ["1"] = true }), "quarryWall")
	assert(missing == "Forge a copper arm.", "the tool is still named first")
	wall.gate = saved

	-- Every tool has a forge hint for its prompt.
	for _, id in Config.Kingdom.abilityOrder do
		assert(type(Config.Kingdom.abilities[id].forgeHint) == "string", id)
	end
	for _, id in Config.Kingdom.obstacleOrder do
		local obstacle = Config.Kingdom.obstacles[id]
		assert(obstacle and Config.Kingdom.abilities[obstacle.ability] and obstacle.verb, id)
	end

	assert(KingdomRules.pieceOpen(player(), nil))
	assert(not KingdomRules.pieceOpen(player(), "quarryWall"))
	assert(KingdomRules.pieceOpen(player({}, { quarryWall = true }), "quarryWall"))
	assert(KingdomRules.blockedText("quarryWall") == "The Cracked Wall blocks the way.")
	print("kingdom-rules: ok")
end
