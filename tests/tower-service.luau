-- The co-op tower. The check script bundles the real Config and Stats above
-- this file; loadTowerService wraps the real TowerService with its requires
-- replaced by the mocks below and os.clock() replaced by a test clock.
do
	---------------------------------------------------------------- the formulas
	local first = Stats.towerWaveReward(1, 1)
	assert(first.xp > 0 and first.minerals.stone and first.minerals.stone > 0)
	local boss = Stats.towerWaveReward(1, 5)
	local plain = Stats.towerWaveReward(1, 4)
	assert(boss.xp > plain.xp, "A boss wave pays more than the wave before it")
	local total = Stats.towerRunReward(1)
	local sum = 0
	for wave = 1, Config.Tower.waves do
		sum += Stats.towerWaveReward(1, wave).xp
	end
	assert(total.xp == sum, "The full-clear total is the sum of the waves")
	for _, zoneId in Config.ZoneOrder do
		assert(Stats.towerRunReward(zoneId).xp > 0)
	end
	assert(Stats.towerWaveEnemies(1, 1) == Config.Tower.enemies.first)
	assert(Stats.towerWaveEnemies(3, 2) > Stats.towerWaveEnemies(3, 1))
	assert(
		Stats.isTowerZone(Config.TowerZoneBase + 1) and Stats.isTowerZone(Config.TowerZoneBase + Config.Tower.arenas)
	)
	assert(not Stats.isTowerZone(Config.HubZone) and not Stats.isTowerZone(1))
	for _, zoneId in Config.ZoneOrder do
		assert(not Stats.isTowerZone(zoneId), "Arena ids must not clash with islands")
	end

	---------------------------------------------------------------- the service
	local function signal()
		local listeners = {}
		return {
			Connect = function(_, fn)
				table.insert(listeners, fn)
			end,
			Fire = function(_, ...)
				for _, fn in listeners do
					fn(...)
				end
			end,
		}
	end
	local now = 0
	local queue = {}
	local mockTask = {
		spawn = function(fn, ...)
			table.insert(queue, { fn, table.pack(...) })
		end,
		wait = function() end,
	}
	local removing = signal()
	local said, granted, arenas, spawned = {}, {}, {}, {}
	local handlers, providers = {}, {}
	local golems, datas, parties = {}, {}, {}
	local function fresh()
		return { golem = { xp = 0, parts = {} }, bossesDefeated = {} }
	end
	local tower = loadTowerService(
		{
			Config = Config,
			MarbleBag = MarbleBag,
			Stats = Stats,
			Remotes = {
				Notify = {
					FireClient = function(_, player, _kind, text)
						said[player] = text
					end,
				},
			},
			ActionService = {
				register = function(name, fn)
					handlers[name] = fn
				end,
			},
			AnalyticsService = { custom = function() end },
			DataService = {
				get = function(player)
					return datas[player]
				end,
				markChanged = function() end,
				addProvider = function(name, fn)
					providers[name] = fn
				end,
			},
			EconomyService = {
				grantFlat = function(player, reward, source)
					assert(source == "tower")
					table.insert(granted, { player = player, reward = reward })
				end,
			},
			EnemyService = {
				spawnInArena = function(zoneId, id, def, at, isBoss, health, onDefeated)
					local enemy = {
						model = { Parent = {} },
						zoneId = zoneId,
						id = id,
						def = def,
						isBoss = isBoss,
						health = health,
					}
					enemy.defeat = function()
						if enemy.model.Parent then
							enemy.model.Parent = nil
							onDefeated(enemy)
						end
					end
					table.insert(spawned, enemy)
					return enemy
				end,
				clearZone = function(zoneId)
					for _, enemy in spawned do
						if enemy.zoneId == zoneId then
							enemy.model.Parent = nil
						end
					end
				end,
			},
			GolemService = {
				get = function(player)
					return golems[player]
				end,
				isActive = function(golem)
					return golem.active
				end,
				sendToZone = function(golem, zoneId)
					golem.zoneId = zoneId
				end,
			},
			PartyService = {
				isLeader = function(player)
					return parties[player] == nil or parties[player][1] == player
				end,
				members = function(player)
					return parties[player] or { player }
				end,
				sameParty = function(a, b)
					return parties[a] ~= nil and parties[a] == parties[b]
				end,
			},
			WorldService = {
				addArena = function(zoneId)
					arenas[zoneId] = true
				end,
				randomPoint = function()
					return Vector3.new(500, 0, 500)
				end,
				getBossPoint = function()
					return Vector3.new(400, 0, 400)
				end,
			},
		},
		{
			GetService = function()
				return {
					PlayerRemoving = removing,
					WaitForChild = function()
						return {}
					end,
				}
			end,
		},
		mockTask,
		function()
			return now
		end
	)

	local nextId = 0
	local function join()
		nextId += 1
		local player = { UserId = nextId, DisplayName = "P" .. nextId, Parent = {} }
		datas[player] = fresh()
		golems[player] = { zoneId = 1, active = true, root = { Position = Vector3.new(0, 0, 0) } }
		return player
	end
	local function liveEnemies(zoneId)
		local list = {}
		for _, enemy in spawned do
			if enemy.zoneId == zoneId and enemy.model.Parent then
				table.insert(list, enemy)
			end
		end
		return list
	end
	local function paidTo(player)
		local count = 0
		for _, grant in granted do
			if grant.player == player then
				count += 1
			end
		end
		return count
	end
	-- Fights the current wave to the end: tick, defeat everything, repeat,
	-- until the wave is paid (the run leaves "fighting").
	local function clearWave(zoneId, player)
		for _ = 1, 100 do
			for _, enemy in liveEnemies(zoneId) do
				enemy.defeat()
			end
			now += Config.Tower.tickSeconds
			tower.tick()
			local run = providers.tower(player).run
			if run == nil or run.state ~= "fighting" then
				return
			end
		end
		error("wave never cleared")
	end

	tower.start()
	queue = {} -- drop the tick loop started by start()

	-- Off by default: nothing can start, and the menu hides the section.
	assert(Config.Tower.enabled == false, "The tower ships switched off until it's playtested")
	local solo = join()
	local ok, reason = handlers.towerStart(solo, 1)
	assert(not ok and reason:find("isn't open"))
	assert(providers.tower(solo).enabled == false)
	Config.Tower.enabled = true

	-- 1. Solo run: the golem moves into its own arena, waves spawn and pay once.
	assert(not handlers.towerStart(solo, 99), "Unknown routes are refused")
	ok = handlers.towerStart(solo, 1)
	assert(ok and golems[solo].zoneId == Config.TowerZoneBase + 1 and arenas[Config.TowerZoneBase + 1])
	local arena = golems[solo].zoneId
	assert(providers.tower(solo).run.state == "break")
	now += Config.Tower.waveBreakSeconds
	tower.tick()
	assert(providers.tower(solo).run.state == "fighting" and providers.tower(solo).run.wave == 1)
	assert(#liveEnemies(arena) == 3, "Spawns are spread over ticks")
	clearWave(arena, solo)
	assert(paidTo(solo) == 1)
	local reward = granted[1].reward
	assert(reward.xp == Stats.towerWaveReward(1, 1).xp, "Pays exactly what the menu shows")
	-- A late duplicate defeat can't pay twice.
	for _, enemy in spawned do
		enemy.defeat()
	end
	tower.tick()
	assert(paidTo(solo) == 1)

	-- Waves 2 to 5; wave 5 brings the island boss at reduced health.
	for wave = 2, 5 do
		now += Config.Tower.waveBreakSeconds
		tower.tick()
		assert(providers.tower(solo).run.wave == wave)
		if wave == 5 then
			local bosses = 0
			for _, enemy in liveEnemies(arena) do
				if enemy.isBoss then
					bosses += 1
					assert(enemy.id == "boss1" and enemy.health == Config.Tower.bossWaves[5])
				end
			end
			assert(bosses == 1)
		end
		clearWave(arena, solo)
		assert(paidTo(solo) == wave)
	end

	-- 2. Leaving mid-wave: back to the island, paid waves kept, arena freed.
	now += Config.Tower.waveBreakSeconds
	tower.tick()
	assert(handlers.towerLeave(solo))
	assert(golems[solo].zoneId == 1 and providers.tower(solo).run == nil and paidTo(solo) == 5)
	assert(#liveEnemies(arena) == 0, "Leaving clears the arena")

	-- 3. Party: everyone must accept; a member who travels away leaves the run.
	local a, b = join(), join()
	local party = { a, b }
	parties[a], parties[b] = party, party
	ok, reason = handlers.towerStart(b, 1)
	assert(not ok and reason:find("leader"))
	assert(handlers.towerStart(a, 1))
	assert(golems[a].zoneId == 1, "Nobody moves until everyone accepts")
	assert(providers.tower(b).run.state == "inviting" and not providers.tower(b).run.isLeader)
	assert(handlers.towerAccept(b))
	arena = golems[a].zoneId
	assert(Stats.isTowerZone(arena) and golems[b].zoneId == arena)
	now += Config.Tower.waveBreakSeconds
	tower.tick()
	golems[b].zoneId = 2 -- b travels to another island
	tower.tick()
	assert(providers.tower(b).run == nil and providers.tower(a).run ~= nil)
	assert(said[b]:find("keep"))
	local before = paidTo(b)
	clearWave(arena, a)
	assert(paidTo(a) == 1 and paidTo(b) == before, "Only members still in the run are paid")

	-- 4. Every golem knocked out at once ends the run; then everyone goes home.
	now += Config.Tower.waveBreakSeconds
	tower.tick()
	golems[a].active = false
	tower.tick()
	assert(providers.tower(a).run.state == "ended")
	golems[a].active = true
	now += Config.Tower.returnSeconds
	tower.tick()
	assert(providers.tower(a).run == nil and golems[a].zoneId == 1)

	-- 5. Invites: a decline cancels, so does the timer, and so does a member
	-- who can't take the route.
	assert(handlers.towerStart(a, 1))
	assert(handlers.towerDecline(b))
	assert(providers.tower(a).run == nil and golems[a].zoneId == 1)
	assert(handlers.towerStart(a, 1))
	now += Config.Tower.inviteSeconds + 1
	tower.tick()
	assert(providers.tower(a).run == nil and providers.tower(b).run == nil)
	ok, reason = handlers.towerStart(a, 2)
	assert(not ok and reason:find("unlocked"), "Every member needs the route unlocked")

	-- 6. Arenas are limited; a disconnect frees its arena.
	parties[a], parties[b] = nil, nil
	local runners = {}
	for _ = 1, Config.Tower.arenas do
		local player = join()
		assert(handlers.towerStart(player, 1))
		table.insert(runners, player)
	end
	ok, reason = handlers.towerStart(a, 1)
	assert(not ok and reason:find("full"))
	assert(providers.tower(a).full)
	local gone = runners[1]
	gone.Parent = nil
	removing:Fire(gone)
	assert(handlers.towerStart(a, 1), "A disconnect frees the arena")

	Config.Tower.enabled = false
	print(
		"PASS: tower formulas, solo waves and boss wave, one payment per wave, leaving, party accept and travel-away, knockout, invites, arena limit"
	)
end
