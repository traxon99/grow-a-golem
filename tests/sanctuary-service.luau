-- SanctuaryService (#218): sanctuary plots and the hearth restoration.
do
	local sanctuary = Config.Kingdom.sanctuary
	local cost = sanctuary.hearth.cost
	local nextId = 0
	local function makePlayer(name, minerals)
		nextId += 1
		local data = {
			minerals = minerals or { stone = 500, copper = 100 },
			campaign = {
				abilities = { smash = true },
				obstacles = { quarryWall = true },
				discoveries = { sanctuary = true },
				projects = {},
				regions = { ["1"] = true },
			},
		}
		local golem = {
			zoneId = 1,
			active = true,
			stats = { scale = 1 },
			root = { Position = Vector3.new(0, 0, 0) },
		}
		return { Name = name, DisplayName = name, UserId = nextId, data = data, golem = golem }
	end
	local actions, events, notes, travels, shown = {}, {}, {}, {}, {}
	local updates, changed = 0, 0
	local removing
	local discovered, loaded
	local service = loadSanctuaryService({
		Config = Config,
		KingdomRules = KingdomRules,
		Stats = Stats,
		Remotes = {
			Notify = {
				FireClient = function(_, who, kind, text)
					table.insert(notes, { who, kind, text })
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
			markChanged = function()
				changed += 1
			end,
			ProfileLoaded = {
				Connect = function(_, fn)
					loaded = fn
				end,
			},
		},
		Events = {
			fire = function(name, who, a, b)
				table.insert(events, { name, who, a, b })
			end,
			connect = function(name, fn)
				if name == "discovered" then
					discovered = fn
				end
			end,
		},
		GolemService = {
			get = function(who)
				return who.golem
			end,
			isActive = function(golem)
				return golem.active
			end,
			travelTo = function(golem, zoneId, ground)
				golem.zoneId = zoneId
				table.insert(travels, { golem, zoneId, ground })
			end,
		},
		Plots = {
			buildPlots = function(config)
				local models = {}
				for index in config.plots do
					local attributes = {}
					models[index] = {
						attributes = attributes,
						SetAttribute = function(_, key, value)
							attributes[key] = value
						end,
					}
				end
				return models
			end,
			showHearth = function(model, restored, ownerName)
				shown[model] = { restored = restored, owner = ownerName }
			end,
		},
	}, {
		GetService = function()
			return {
				WaitForChild = function()
					return {}
				end,
				PlayerRemoving = {
					Connect = function(_, fn)
						removing = fn
					end,
				},
			}
		end,
	})

	-- Off: nothing starts and the actions refuse.
	assert(Config.Kingdom.enabled == false, "the kingdom ships switched off")
	service.start()
	assert(actions.restoreHearth == nil, "no actions while the kingdom is off")
	assert(not service.restoreHearth(makePlayer("off")), "restore refuses while off")
	assert(not service.returnHome(makePlayer("off")), "return refuses while off")

	Config.Kingdom.enabled = true
	service.start()
	assert(actions.restoreHearth and actions.returnHome, "both actions registered")
	assert(discovered and loaded and removing, "listens for discovery, load and leave")
	local restore, home = actions.restoreHearth, actions.returnHome

	-- A player who hasn't found the sanctuary gets no plot.
	local stranger = makePlayer("stranger")
	stranger.data.campaign.discoveries = {}
	loaded(stranger)
	assert(service.plotOf(stranger) == nil and not service.queued(stranger), "no plot before discovery")
	local ok, message = restore(stranger)
	assert(not ok and message == "Find your sanctuary plot first.")

	-- Discovery assigns the first free plot; one plot per player.
	local alice = makePlayer("alice")
	discovered(alice, "quarry")
	assert(service.plotOf(alice) == nil, "other discoveries don't assign")
	discovered(alice, "sanctuary")
	assert(service.plotOf(alice) == 1, "first plot")
	assert(service.assign(alice) == 1, "assigning twice keeps the same plot")

	-- Fill the server: every plot has exactly one owner.
	local players = { alice }
	for i = 2, #sanctuary.plots do
		local p = makePlayer(`p{i}`)
		loaded(p)
		assert(service.plotOf(p) == i, "plots fill in order")
		table.insert(players, p)
	end
	local late = makePlayer("late")
	loaded(late)
	assert(service.plotOf(late) == nil and service.queued(late), "full server queues the newcomer")
	assert(notes[#notes][2] == "message" and notes[#notes][3] == sanctuary.fullText, "told the plots are full")
	local noteCount = #notes
	loaded(late)
	assert(#notes == noteCount, "queued once, told once")
	assert(not restore(late), "no plot, no restore")

	-- Restoring: owner only, golem nearby, funds, one mutation.
	local plot = sanctuary.plots[1]
	alice.golem.root.Position = plot + Vector3.new(200, 0, 0)
	ok, message = restore(alice)
	assert(not ok and message == "Bring your golem to your hearth.", "too far away")
	alice.golem.root.Position = plot + Vector3.new(10, 0, 0)
	alice.golem.zoneId = 0
	assert(not restore(alice), "golem must be on the kingdom ground")
	alice.golem.zoneId = 1
	alice.golem.active = false
	assert(not restore(alice), "golem must be standing")
	alice.golem.active = true
	alice.data.minerals = { stone = cost.stone - 1, copper = cost.copper }
	ok, message = restore(alice)
	assert(not ok and message == `Need {Stats.costText(cost)}.`, "short of stone")
	assert(updates == 0, "nothing saved on refusals")
	alice.data.minerals = { stone = cost.stone + 5, copper = cost.copper }
	ok, message = restore(alice)
	assert(ok and message == "The hearth is lit! Return Home is open in Travel.")
	assert(updates == 1, "spend and complete in one mutation")
	assert(alice.data.minerals.stone == 5 and alice.data.minerals.copper == 0, "exact cost spent")
	assert(alice.data.campaign.projects.hearth == true)
	local spent, completed = events[#events - 1], events[#events]
	assert(spent[1] == "mineralsSpent" and spent[4] == "hearth", "spend logged")
	assert(completed[1] == "projectCompleted" and completed[3] == "hearth", "completion fired")
	ok, message = restore(alice)
	assert(not ok and message == "Your hearth is already burning.", "no double restore")
	assert(updates == 1 and alice.data.minerals.stone == 5, "duplicate spends nothing")

	-- A visitor standing at Alice's hearth restores nothing of hers.
	local bob = players[2]
	bob.golem.root.Position = plot
	ok = restore(bob)
	assert(not ok, "bob's own plot is elsewhere")
	assert(bob.data.campaign.projects.hearth == nil and updates == 1)

	-- Return Home: needs the hearth and an open road, travels to the plot.
	ok, message = home(bob)
	assert(not ok and message == "Restore your hearth first.")
	alice.golem.zoneId = 0
	ok, message = home(alice)
	assert(ok and message == "Welcome home!")
	local trip = travels[#travels]
	assert(trip[2] == 1 and (trip[3] - (plot + sanctuary.returnOffset)).Magnitude < 1e-6, "lands by the hearth")
	assert(changed == 1)
	alice.data.campaign.obstacles = {}
	ok, message = home(alice)
	assert(not ok and message == "Open the quarry road first.")
	alice.data.campaign.obstacles = { quarryWall = true }

	-- Leaving frees the plot for the queue; the hearth stays saved.
	removing(alice)
	assert(service.plotOf(alice) == nil)
	assert(service.plotOf(late) == 1 and not service.queued(late), "the waiting player gets the freed plot")
	assert(alice.data.campaign.projects.hearth == true, "restoration lives in the save")
	removing(late)
	assert(service.plotOf(late) == nil)

	-- Rejoining shows the saved hearth on whichever plot is free.
	loaded(alice)
	assert(service.plotOf(alice) == 1, "back on a free plot")
	local litCount = 0
	for _, state in shown do
		if state.restored then
			litCount += 1
			assert(state.owner == "alice")
		end
	end
	assert(litCount == 1, "only alice's plot is lit")

	-- A queued player who leaves drops out of the queue.
	local waiting = makePlayer("waiting")
	loaded(waiting)
	assert(service.queued(waiting))
	removing(waiting)
	assert(not service.queued(waiting))

	Config.Kingdom.enabled = false
	print("sanctuary-service: ok")
end
