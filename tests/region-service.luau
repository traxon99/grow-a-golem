-- RegionService (#214): walking across kingdom region boundaries.
do
	local regions = { [1] = true, [2] = true, [0] = true }
	local zoneUnder = 1
	local obstacleUnder = nil
	local data = { campaign = { regions = { ["1"] = true }, discoveries = {} } }
	local discoveryUnder = nil
	local events, messages, placed, changed, published = {}, {}, {}, 0, 0
	local service = loadRegionService({
		Config = Config,
		Remotes = {
			Notify = {
				FireClient = function(_, _, kind, text)
					table.insert(messages, { kind, text })
				end,
			},
		},
		Stats = Stats,
		KingdomRules = KingdomRules,
		DataService = {
			get = function()
				return data
			end,
			markChanged = function()
				changed += 1
			end,
			update = function(_, fn)
				fn(data)
			end,
		},
		Events = {
			fire = function(name, _, zoneId)
				table.insert(events, { name, zoneId })
			end,
		},
		GolemService = {
			isActive = function(golem)
				return golem.active
			end,
			placeAt = function(_, position)
				table.insert(placed, position)
			end,
			setZone = function(golem, zoneId)
				golem.zoneId = zoneId
				published += 1
			end,
		},
		WorldService = {
			isKingdomZone = function(zoneId)
				return regions[zoneId] == true
			end,
			zoneAt = function()
				return zoneUnder
			end,
			requiredObstacleAt = function()
				return obstacleUnder
			end,
			discoveryAt = function()
				return discoveryUnder
			end,
			safePointNear = function(zoneId, _, _, given)
				assert(given == data, "push-back avoids ground this player can't stand on")
				return Vector3.new(zoneId, 0, 0)
			end,
		},
	})
	local player = {}
	local golem = { zoneId = 1, active = true, root = { Position = Vector3.new(0, 0, 0) } }
	local wasEnabled = Config.Kingdom.enabled
	Config.Kingdom.enabled = true

	-- Staying inside the region does nothing.
	assert(service.check(player, golem, 0) == nil and #events == 0)

	-- Into the hub: always open, no zoneEntered (travel doesn't fire one either).
	zoneUnder = Config.HubZone
	assert(service.check(player, golem, 0) == "entered" and golem.zoneId == Config.HubZone)
	assert(#events == 0 and changed == 1 and published == 1, "clients learn the new zone")
	-- Back into the quarry: entered once, and not again while standing there.
	zoneUnder = 1
	assert(service.check(player, golem, 0) == "entered" and golem.zoneId == 1)
	assert(service.check(player, golem, 0) == nil)
	assert(#events == 1 and events[1][1] == "zoneEntered" and events[1][2] == 1)

	-- A locked region: returned to the current region, no access granted.
	zoneUnder = 2
	assert(service.check(player, golem, 10) == "blocked")
	assert(golem.zoneId == 1 and #placed == 1 and placed[1].X == 1, "pushed back inside region 1")
	assert(#events == 1 and data.campaign.regions["2"] == nil)
	assert(#messages == 1 and messages[1][1] == "message")
	-- Pushing against it again soon doesn't spam the message.
	assert(service.check(player, golem, 11) == "blocked" and #messages == 1)
	assert(service.check(player, golem, 10 + Config.Kingdom.layout.lockedMessageSeconds) == "blocked")
	assert(#messages == 2)

	-- Once the campaign grants the region, the same walk enters it.
	data.campaign.regions["2"] = true
	assert(service.check(player, golem, 30) == "entered" and golem.zoneId == 2)
	assert(#events == 2 and events[2][2] == 2)

	-- Downed golems, islands and arenas are never checked.
	golem.active = false
	zoneUnder = 1
	assert(service.check(player, golem, 40) == nil and golem.zoneId == 2)
	golem.active = true
	golem.zoneId = 150 -- an arena outside the kingdom
	assert(service.check(player, golem, 40) == nil and golem.zoneId == 150)
	golem.zoneId = 1
	zoneUnder = 150
	assert(
		service.check(player, golem, 40) == nil and golem.zoneId == 1,
		"kingdom golems can't enter arenas by walking"
	)
	zoneUnder = nil
	assert(service.check(player, golem, 40) == nil, "the void between pieces is no region")

	-- Ground behind an unopened obstacle, even inside the current region.
	golem.zoneId = 1
	zoneUnder = 1
	obstacleUnder = "quarryWall"
	local before = #messages
	assert(service.check(player, golem, 100) == "blocked" and golem.zoneId == 1)
	assert(messages[before + 1][2] == "The Cracked Wall blocks the way.")
	data.campaign.obstacles = { quarryWall = true }
	assert(service.check(player, golem, 101) == nil, "once opened, the road is walkable")
	-- Into the hub over open ground.
	zoneUnder = Config.HubZone
	obstacleUnder = nil
	assert(service.check(player, golem, 102) == "entered" and golem.zoneId == Config.HubZone)

	-- First visit to the sanctuary approach: recorded once, from open ground.
	golem.zoneId = 1
	zoneUnder = 1
	obstacleUnder = "quarryWall"
	discoveryUnder = "sanctuary"
	data.campaign.obstacles = {}
	assert(service.check(player, golem, 200) == "blocked" and data.campaign.discoveries.sanctuary == nil)
	data.campaign.obstacles = { quarryWall = true }
	local eventsBefore = #events
	assert(service.check(player, golem, 201) == "discovered" and data.campaign.discoveries.sanctuary == true)
	assert(#events == eventsBefore + 1 and events[#events][1] == "discovered" and events[#events][2] == "sanctuary")
	assert(messages[#messages][2] == Config.Kingdom.discoveries.sanctuary.message)
	assert(service.check(player, golem, 202) == nil and #events == eventsBefore + 1, "only once")
	discoveryUnder = nil

	Config.Kingdom.enabled = wasEnabled
	print("region-service: ok")
end
