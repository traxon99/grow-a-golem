-- Reward multipliers (EconomyService): golem stats, the party friend bonus,
-- and the Magnet spell all combine in one place, so every other service's
-- EconomyService.grantFlat mock in this bundle is standing in for the real
-- thing tested here. The check script bundles the real Config above this
-- file and loads the real EconomyService with its requires replaced by the
-- mocks below and a test-controlled os.clock.
do
	local clockNow = 100
	local timeNow = Config.WorldBeat.intervalSeconds * 5 + Config.WorldBeat.durationSeconds
	local golems = {}
	local friendBonuses = {}
	local given = {}

	local economy = loadEconomyService({
		Config = Config,
		WorldBeat = WorldBeat,
		Events = {
			fire = function(name, player, runStart)
				assert(name == "worldBeatParticipated")
				table.insert(given, { kind = "surge", player = player, runStart = runStart })
			end,
		},
		DataService = {
			addMinerals = function(player, minerals, source)
				table.insert(given, { player = player, kind = "minerals", minerals = minerals, source = source })
			end,
			addXp = function(player, amount)
				table.insert(given, { player = player, kind = "xp", amount = amount, source = nil })
			end,
		},
		GolemService = {
			get = function(player)
				return golems[player]
			end,
		},
		PartyService = {
			friendBonus = function(player)
				return friendBonuses[player] or 0
			end,
		},
	}, {
		GetService = function()
			return {
				WaitForChild = function()
					return {}
				end,
			}
		end,
	}, function()
		return clockNow
	end, function()
		return timeNow
	end)

	local nextId = 0
	local function join()
		nextId += 1
		return { UserId = nextId, DisplayName = "P" .. nextId }
	end

	--------------------------------------------------------- mineralMultiplier
	do
		local noGolem = join()
		assert(economy.mineralMultiplier(noGolem) == 1, "no golem, no friends: multiplier is 1")

		local withFriends = join()
		friendBonuses[withFriends] = 50
		assert(economy.mineralMultiplier(withFriends) == 1.5, "a friend bonus applies even with no golem")

		local withGolem = join()
		golems[withGolem] = { stats = { mineralMult = 2 }, magnetUntil = 0 }
		assert(economy.mineralMultiplier(withGolem) == 2, "the golem's own mineralMult applies")

		local withMagnet = join()
		golems[withMagnet] = { stats = { mineralMult = 2 }, magnetUntil = clockNow + 10 }
		friendBonuses[withMagnet] = 50
		-- 2 (mineralMult) * 1.5 (friend bonus) * 2 (1 + magnet's mineralBonus of 1.0)
		assert(economy.mineralMultiplier(withMagnet) == 6, "mineralMult, friend bonus and an active magnet all stack")

		local magnetExpired = join()
		golems[magnetExpired] = { stats = { mineralMult = 2 }, magnetUntil = clockNow - 1 }
		assert(economy.mineralMultiplier(magnetExpired) == 2, "magnetUntil in the past doesn't apply the bonus")
	end

	--------------------------------------------------------- grant
	do
		local player = join()
		golems[player] = { stats = { mineralMult = 2, xpMult = 1.5 }, magnetUntil = 0 }

		local result = economy.grant(player, { minerals = { stone = 10, copper = 3 } }, "enemy")
		assert(
			result.minerals.stone == 20 and result.minerals.copper == 6,
			"each mineral is floored after the multiplier"
		)
		local last = given[#given]
		assert(last.kind == "minerals" and last.source == "enemy" and last.minerals.stone == 20)

		local resultXp = economy.grant(player, { xp = 100 }, "enemy")
		assert(resultXp.xp == 150, "xp is floored after the golem's xpMult")
		assert(given[#given].kind == "xp" and given[#given].amount == 150)

		-- A reward that rounds down to 0 still grants at least 1.
		local tinyPlayer = join()
		golems[tinyPlayer] = { stats = { mineralMult = 0.1, xpMult = 1 }, magnetUntil = 0 }
		local tiny = economy.grant(tinyPlayer, { minerals = { stone = 1 } }, "enemy")
		assert(tiny.minerals.stone == 1, "a reward that floors to 0 still grants a minimum of 1")

		-- No golem: multiplier and xpMult both default to 1.
		local noGolemPlayer = join()
		local plain = economy.grant(noGolemPlayer, { minerals = { stone = 10 }, xp = 10 }, "enemy")
		assert(plain.minerals.stone == 10 and plain.xp == 10, "no golem means no multiplier at all")

		-- An empty reward grants nothing and calls neither DataService function.
		local emptyPlayer = join()
		local givenBefore = #given
		local empty = economy.grant(emptyPlayer, {}, "enemy")
		assert(next(empty) == nil and #given == givenBefore, "an empty reward touches nothing")
	end

	--------------------------------------------------------- mineral surge
	do
		local player = join()
		golems[player] = { stats = { mineralMult = 1.5, xpMult = 1 }, magnetUntil = 0 }
		local base = economy.grant(player, { minerals = { stone = 3 } }, "mining")
		assert(base.minerals.stone == 4, "normal node yield is rounded before any surge bonus")
		assert(given[#given].kind == "minerals", "no participation event outside a surge")

		timeNow = Config.WorldBeat.intervalSeconds * 6
		local doubled = economy.grant(player, { minerals = { stone = 3 } }, "mining")
		assert(doubled.minerals.stone == 8, "surge doubles the normal rounded node payout exactly")
		assert(given[#given].kind == "surge" and given[#given].runStart == timeNow)

		local enemy = economy.grant(player, { minerals = { stone = 3 } }, "enemy")
		assert(enemy.minerals.stone == 4, "surge does not multiply enemy rewards")
		local flatBefore = #given
		economy.grantFlat(player, { minerals = { stone = 3 } }, "daily")
		assert(given[#given].minerals.stone == 3 and #given == flatBefore + 1, "flat rewards stay fixed")
		timeNow += Config.WorldBeat.durationSeconds
		assert(economy.grant(player, { minerals = { stone = 3 } }, "mining").minerals.stone == 4)
	end

	--------------------------------------------------------- grantFlat
	do
		local player = join()
		golems[player] = { stats = { mineralMult = 5, xpMult = 5 } } -- would change the result if grantFlat used it

		economy.grantFlat(player, { minerals = { stone = 10 }, xp = 20 }, "daily")
		local minerals, xp
		for i = #given, 1, -1 do
			if given[i].player == player then
				if given[i].kind == "minerals" and not minerals then
					minerals = given[i]
				elseif given[i].kind == "xp" and not xp then
					xp = given[i]
				end
			end
		end
		assert(minerals.minerals.stone == 10 and minerals.source == "daily", "grantFlat applies no multiplier at all")
		assert(xp.amount == 20, "grantFlat's xp is untouched by xpMult")

		local givenBefore = #given
		economy.grantFlat(player, {}, "daily")
		assert(#given == givenBefore, "an empty reward touches nothing here either")
	end

	print("economy-service: ok")
end
