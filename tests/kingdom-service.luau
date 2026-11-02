-- KingdomService (#216): the server side of "use obstacle".
do
	local wall = Config.Kingdom.obstacles.quarryWall
	local clock = 100
	local delayed = {}
	local function makePlayer(name)
		local data = {
			campaign = { abilities = {}, obstacles = {}, regions = { ["1"] = true } },
			golem = { xp = 0, parts = {} },
			bossesDefeated = {},
		}
		local attributes = {}
		local golem = {
			zoneId = 1,
			active = true,
			stats = { scale = 1 },
			busyUntil = 0,
			root = { Position = wall.position + Vector3.new(10, 0, 0) },
			model = {
				GetAttribute = function(_, key)
					return attributes[key]
				end,
				SetAttribute = function(_, key, value)
					attributes[key] = value
				end,
			},
			attributes = attributes,
		}
		return { Name = name, data = data, golem = golem }
	end
	local alice, bob = makePlayer("alice"), makePlayer("bob")
	local actions, events, notes, updates = {}, {}, {}, 0
	local service = loadKingdomService({
		Config = Config,
		KingdomRules = KingdomRules,
		Remotes = {
			Notify = {
				FireClient = function(_, who, kind, id)
					table.insert(notes, { who, kind, id })
				end,
			},
		},
		ActionService = {
			register = function(name, handler)
				actions[name] = handler
			end,
		},
		DataService = {
			get = function(who)
				return who.data
			end,
			update = function(who, fn)
				updates += 1
				fn(who.data)
			end,
		},
		Events = {
			fire = function(name, who, id)
				table.insert(events, { name, who, id })
			end,
		},
		GolemService = {
			get = function(who)
				return who.golem
			end,
			isActive = function(golem)
				return golem.active
			end,
		},
	}, function()
		return clock
	end, function(_, fn, ...)
		table.insert(delayed, { fn, ... })
	end)
	service.start()
	local use = actions.useObstacle
	local wasEnabled = Config.Kingdom.enabled
	local function runDelayed()
		local jobs = delayed
		delayed = {}
		local results = {}
		for _, job in jobs do
			table.insert(results, job[1](table.unpack(job, 2)))
		end
		return results
	end

	Config.Kingdom.enabled = false
	assert(not use(alice, "quarryWall"), "off while the kingdom is off")
	Config.Kingdom.enabled = true

	-- Bad ids and the missing tool.
	assert(not use(alice, 42) and not use(alice, "nope"))
	local ok, message = use(alice, "quarryWall")
	assert(not ok and message == "Forge a copper arm.")
	alice.data.campaign.abilities.smash = true

	-- Wrong region, too far, downed golem.
	alice.golem.zoneId = 2
	ok, message = use(alice, "quarryWall")
	assert(not ok and message == "Your golem needs to be closer.")
	alice.golem.zoneId = 1
	alice.golem.root.Position = wall.position + Vector3.new(200, 0, 0)
	assert(not use(alice, "quarryWall"))
	alice.golem.root.Position = wall.position + Vector3.new(10, 0, 0)
	alice.golem.active = false
	assert(not use(alice, "quarryWall"))
	alice.golem.active = true
	assert(#delayed == 0 and updates == 0, "no rejected request starts an action")

	-- A bigger golem reaches from farther away.
	alice.golem.stats.scale = 3
	alice.golem.root.Position = wall.position + Vector3.new(wall.approachRadius + 10, 0, 0)

	-- Success: one action, then one recorded completion.
	ok, message = use(alice, "quarryWall")
	assert(ok and message == "Smash!" and #delayed == 1)
	assert(alice.golem.attributes.Attack == 1, "the golem visibly swings")
	assert(alice.golem.busyUntil > clock, "the golem is held while it smashes")
	ok, message = use(alice, "quarryWall")
	assert(not ok and message == "Your golem is already on it.", "no second action while one is running")
	local results = runDelayed()
	assert(results[1] == true and alice.data.campaign.obstacles.quarryWall == true and updates == 1)
	assert(alice.golem.busyUntil == 0, "and free again afterwards")
	assert(#events == 1 and events[1][1] == "obstacleOpened" and events[1][3] == "quarryWall")
	assert(#notes == 1 and notes[1][1] == alice and notes[1][2] == "obstacleOpened")
	ok, message = use(alice, "quarryWall")
	assert(not ok and message == "Already open.")
	assert(service.finish(alice, 1) == false, "a stale finish records nothing")
	assert(updates == 1 and #events == 1)

	-- Someone else's open wall does nothing for Bob.
	assert(bob.data.campaign.obstacles.quarryWall == nil)
	ok, message = use(bob, "quarryWall")
	assert(not ok and message == "Forge a copper arm.")

	-- Interrupted: Bob's golem walks off mid-smash; nothing is recorded and
	-- he can try again once the cooldown passes.
	bob.data.campaign.abilities.smash = true
	assert(use(bob, "quarryWall"))
	bob.golem.root.Position = wall.position + Vector3.new(300, 0, 0)
	results = runDelayed()
	assert(results[1] == false and bob.data.campaign.obstacles.quarryWall == nil and updates == 1)
	local last = notes[#notes]
	assert(last[1] == bob and last[2] == "message", "an interrupted smash says so")
	bob.golem.root.Position = wall.position + Vector3.new(5, 0, 0)
	ok, message = use(bob, "quarryWall")
	assert(not ok and message == "Give your golem a moment.", "cooldown")
	clock += wall.cooldownSeconds
	assert(use(bob, "quarryWall"))
	-- Steering away cancels the hold (CombatService clears it): nothing.
	bob.golem.busyUntil = 0
	results = runDelayed()
	assert(results[1] == false and bob.data.campaign.obstacles.quarryWall == nil)
	clock += wall.cooldownSeconds
	assert(use(bob, "quarryWall"))
	-- Knocked out before it lands: also nothing.
	bob.golem.active = false
	results = runDelayed()
	assert(results[1] == false and bob.data.campaign.obstacles.quarryWall == nil)
	bob.golem.active = true
	clock += wall.cooldownSeconds
	assert(use(bob, "quarryWall"))
	results = runDelayed()
	assert(results[1] == true and bob.data.campaign.obstacles.quarryWall == true)

	-- An obstacle that opens a region grants exactly that region.
	wall.opensRegion = 2
	local carol = makePlayer("carol")
	carol.data.campaign.abilities.smash = true
	assert(use(carol, "quarryWall"))
	runDelayed()
	assert(carol.data.campaign.regions["2"] == true and carol.data.campaign.regions["3"] == nil)
	wall.opensRegion = nil

	Config.Kingdom.enabled = wasEnabled
	print("kingdom-service: ok")
end
