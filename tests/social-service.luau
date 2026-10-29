-- Hub cards, titles and rare-find announcements (SocialService). The check
-- script bundles the real Config/Stats above this file and loads the real
-- SocialService with its requires replaced by the mocks below.
--
-- Out of scope here: hookGolem (the Inspect-prompt wiring, which needs
-- Instance/ProximityPrompt) and the hub-refresh timer loop -- both only
-- run through task.spawn, kept a no-op, so .start() never actually drives
-- either of them in this test.
do
	local handlers = {}
	local eventHandlers = {}
	local notified = {}
	local invalidated = {}
	local providers = {}
	local datas = {}
	local golems = {}
	local playersList = {}

	local function freshData()
		return {
			golem = { xp = 0, parts = {} },
			artifacts = { equipped = {}, found = {} },
			bossesDefeated = {},
			social = { title = "", announce = false },
			awakening = { count = 0 },
		}
	end

	local nextId = 0
	local function join(data: any?)
		nextId += 1
		local player = { UserId = nextId, DisplayName = "P" .. nextId }
		if data ~= nil then
			datas[player] = data
		end
		return player
	end

	local social = loadSocialService({
		Config = Config,
		Remotes = {
			Notify = {
				FireClient = function(_, player, kind, message)
					table.insert(notified, { player = player, kind = kind, message = message })
				end,
			},
		},
		Stats = Stats,
		ActionService = {
			register = function(name, fn)
				handlers[name] = fn
			end,
		},
		DataService = {
			get = function(player)
				return datas[player]
			end,
			update = function(player, fn)
				fn(datas[player])
			end,
			addProvider = function(name, fn)
				providers[name] = fn
			end,
			invalidateProvider = function(name)
				table.insert(invalidated, name)
			end,
			ProfileLoaded = { Connect = function() end },
		},
		Events = {
			connect = function(name, fn)
				eventHandlers[name] = fn
			end,
		},
		GolemService = {
			get = function(player)
				return golems[player]
			end,
		},
		WorldService = {
			getFolder = function()
				return {
					ChildAdded = { Connect = function() end },
					GetChildren = function()
						return {}
					end,
				}
			end,
		},
	}, {
		GetService = function(_, name)
			if name == "Players" then
				return {
					GetPlayers = function()
						return playersList
					end,
					FindFirstChild = function()
						return nil
					end,
					PlayerRemoving = { Connect = function() end },
				}
			end
			return {
				WaitForChild = function()
					return {}
				end,
			}
		end,
	}, {
		spawn = function() end, -- the golem-hook loop and the hub-refresh timer never run
	})
	social.start()
	local setTitle = handlers.setTitle
	local setAnnounce = handlers.setAnnounce
	local announce = eventHandlers.artifactFound
	assert(setTitle and setAnnounce, "both actions are registered")
	assert(announce ~= nil, "SocialService connects to the artifactFound event")
	assert(providers.hub ~= nil, "SocialService registers the hub DataService provider")

	--------------------------------------------------------------------- snapshot
	do
		local caller = join(freshData())
		local other = join(freshData())
		other.DisplayName = "Other"
		datas[other].golem.parts.core = 2
		datas[other].artifacts.equipped = { "pebbleCharm" }
		datas[other].bossesDefeated["1"] = true
		datas[other].awakening.count = 1
		datas[other].social.title = "awakened"
		golems[other] = { zoneId = Config.HubZone }

		local noData = join() -- online, but DataService.get returns nil for them
		playersList = { caller, other, noData }

		local snap = providers.hub(caller)
		assert(#snap.others == 1, "a player with no data is left out of the inspect list")
		local card = snap.others[1]
		assert(card.userId == other.UserId and card.name == "Other")
		assert(card.bosses == 1, "one zone's boss counted as defeated")
		assert(card.title == "Awakened", "an earned, equipped title shows its display name")
		assert(card.inHub == true, "the card's golem is parked in the hub zone")
		assert(table.find(card.equipped, Config.Artifacts.pebbleCharm.name) ~= nil)
		local foundBareStone, foundCore = false, false
		for _, line in card.parts do
			if string.find(line, "Bare stone", 1, true) then
				foundBareStone = true
			end
			if string.find(line, Config.Tiers[2].displayName, 1, true) then
				foundCore = true
			end
		end
		assert(foundBareStone and foundCore, "parts list a tier name or \"Bare stone\" per slot")

		local foundTitleRow, notEarnedRow = false, false
		for _, row in snap.titles do
			if row.id == "awakened" then
				foundTitleRow = true
			end
			if row.id == "veteran" then
				notEarnedRow = row.earned == false
			end
		end
		assert(foundTitleRow and notEarnedRow, "the title list covers both earned and unearned titles")
	end

	do
		-- Config.Hub.maxInspect caps how many cards snapshot sends, even
		-- when more online players have data.
		local caller = join(freshData())
		local otherA = join(freshData())
		local otherB = join(freshData())
		playersList = { caller, otherA, otherB }

		local savedCap = Config.Hub.maxInspect
		Config.Hub.maxInspect = 1
		local snap = providers.hub(caller)
		Config.Hub.maxInspect = savedCap
		assert(#snap.others == 1, "the inspect list is capped at Config.Hub.maxInspect")
	end

	--------------------------------------------------------------------- setTitle
	do
		local notReady = join() -- no data at all
		local okNoData = setTitle(notReady, "awakened")
		assert(okNoData == false, "no data means not ready")

		local player = join(freshData())
		local okBadType = setTitle(player, 5 :: any)
		assert(okBadType == false, "a non-string id is refused")

		local okUnearned, msgUnearned = setTitle(player, "veteran")
		assert(okUnearned == false and msgUnearned == "You haven't earned that title yet")

		local okUnknown, msgUnknown = setTitle(player, "notARealTitle")
		assert(okUnknown == false and msgUnknown == "You haven't earned that title yet")

		datas[player].awakening.count = 1 -- earns "awakened" (unlock = {kind = "awaken", count = 1})
		local invalidatedBefore = #invalidated
		local okEarned, msgEarned = setTitle(player, "awakened")
		assert(okEarned == true and msgEarned == "Title: Awakened")
		assert(datas[player].social.title == "awakened")
		assert(#invalidated > invalidatedBefore and invalidated[#invalidated] == "hub")

		local okClear, msgClear = setTitle(player, "")
		assert(okClear == true and msgClear == "Title removed")
		assert(datas[player].social.title == "")
	end

	--------------------------------------------------------------------- setAnnounce
	do
		local notReady = join()
		assert(setAnnounce(notReady, true) == false, "no data means not ready")

		local player = join(freshData())
		local okBadType = setAnnounce(player, "yes" :: any)
		assert(okBadType == false, "a non-boolean is refused")

		local okOn, msgOn = setAnnounce(player, true)
		assert(okOn == true and msgOn == "You'll hear about rare finds")
		assert(datas[player].social.announce == true)

		local okOff, msgOff = setAnnounce(player, false)
		assert(okOff == true and msgOff == "Rare-find announcements are off")
		assert(datas[player].social.announce == false)
	end

	--------------------------------------------------------------------- announce
	do
		local finder = join(freshData())
		local optedIn = join(freshData())
		datas[optedIn].social.announce = true
		local optedOut = join(freshData())
		datas[optedOut].social.announce = false
		local noData = join()
		playersList = { finder, optedIn, optedOut, noData }

		local notifiedBefore = #notified
		announce(finder, "rockjawTooth") -- source = "boss", in Config.AnnounceSources
		local newNotifications = {}
		for i = notifiedBefore + 1, #notified do
			table.insert(newNotifications, notified[i])
		end
		assert(#newNotifications == 1, "only the opted-in player hears it, never the finder or an opted-out one")
		assert(newNotifications[1].player == optedIn)
		assert(string.find(newNotifications[1].message, finder.DisplayName, 1, true) ~= nil)
		assert(string.find(newNotifications[1].message, Config.Artifacts.rockjawTooth.name, 1, true) ~= nil)

		local notifiedBeforeDrop = #notified
		announce(finder, "pebbleCharm") -- source = "drop", not in Config.AnnounceSources
		assert(#notified == notifiedBeforeDrop, "a non-announceable source is a silent no-op")
	end

	print("social-service: ok")
end
