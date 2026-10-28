-- Limited-time events (LiveEventService). The check script bundles the real
-- Config and Stats above this file and loads the real LiveEventService with
-- its requires replaced by the mocks below and a test-controlled os.time.
-- The real `doubleMinerals` event from Config.Events is used as-is (weekly,
-- day = 6, hour = 0, hours = 48), so the test picks `now` values that fall
-- inside and outside its real window rather than inventing a fake event.
do
	local event = Stats.eventById("doubleMinerals")
	assert(event and event.track, "Config.Events still has doubleMinerals with a reward track")

	-- Found once from an arbitrary anchor, using the same formula the real
	-- service calls (Stats.eventWindow), so these aren't a guess at Config's
	-- schedule: they're whatever this event's real windows actually are.
	local RUN1_START, run1End = Stats.eventWindow(event, 1793145600)
	assert(RUN1_START and run1End, "doubleMinerals has an upcoming window from this anchor")
	local BETWEEN_RUNS_NOW = run1End + 3600
	local RUN2_START, run2End = Stats.eventWindow(event, BETWEEN_RUNS_NOW)
	assert(RUN2_START and RUN2_START > run1End, "the next window starts after the first one ends")
	assert(run2End > RUN2_START + 3600)

	local now = RUN1_START + 3600 -- one hour into run 1: the event is active
	local handlers = {}
	local connected = {}
	local granted = {}
	local fired = {}
	local datas = {}
	local changed = {}

	local function fresh()
		return { eventTracks = {} }
	end

	local liveEvents = loadLiveEventService({
		Config = Config,
		Stats = Stats,
		Remotes = {
			Notify = {
				FireClient = function() end,
			},
		},
		ActionService = {
			register = function(name, fn)
				handlers[name] = fn
			end,
		},
		DataService = {
			get = function(player)
				return datas[player]
			end,
			update = function(_player, fn)
				fn()
			end,
			markChanged = function(player)
				changed[player] = (changed[player] or 0) + 1
			end,
		},
		EconomyService = {
			grantFlat = function(player, reward, source)
				assert(source == "event", 'events grant with source "event"')
				table.insert(granted, { player = player, reward = reward })
			end,
		},
		Events = {
			connect = function(name, fn)
				connected[name] = fn
			end,
			fire = function(name, player, eventId, index)
				table.insert(fired, { name = name, player = player, eventId = eventId, index = index })
			end,
		},
	}, {
		GetService = function()
			return {
				GetPlayers = function()
					return {}
				end,
				WaitForChild = function()
					return {}
				end,
			}
		end,
	}, {
		spawn = function() end, -- never runs the service's own background loop
		wait = function() end,
	}, function()
		return now
	end)
	liveEvents.start()
	local claimTier = handlers.claimEventTier
	assert(claimTier, "claimEventTier is registered")
	assert(connected.bossDefeated, "onPlay is connected to bossDefeated (and the other play events)")

	local nextId = 0
	local function join()
		nextId += 1
		local player = { UserId = nextId, DisplayName = "P" .. nextId }
		datas[player] = fresh()
		return player
	end

	----------------------------------------------------------------- onPlay
	do
		local player = join()
		connected.bossDefeated(player) -- +15 tokens, inside the active window
		local state = datas[player].eventTracks.doubleMinerals
		assert(state and state.tokens == 15, "onPlay adds the event's earn amount for that action")
		assert((changed[player] or 0) > 0, "DataService.markChanged fires when tokens change")

		connected.enemyDefeated(player) -- +1 token
		assert(datas[player].eventTracks.doubleMinerals.tokens == 16, "tokens accumulate across actions")
	end

	do
		-- No event is active at this moment, so playing earns nothing and no
		-- track is even created.
		local player = join()
		now = BETWEEN_RUNS_NOW
		connected.bossDefeated(player)
		assert(datas[player].eventTracks.doubleMinerals == nil, "no track is touched when no event is active")
		now = RUN1_START + 3600
	end

	----------------------------------------------------------------- claimTier
	do
		local player = join()
		local okBadEvent, msgBadEvent = claimTier(player, "notAnEvent", 1)
		assert(okBadEvent == false and msgBadEvent ~= nil, "an unknown event id is refused")

		local okBadIndex, msgBadIndex = claimTier(player, "doubleMinerals", 99)
		assert(okBadIndex == false and msgBadIndex ~= nil, "a tier index past the end of the track is refused")

		local okBadType = claimTier(player, "doubleMinerals", "1")
		assert(okBadType == false, "a non-number index is refused")

		-- Not enough tokens yet for even the cheapest tier (40).
		connected.bossDefeated(player) -- 15 tokens
		local okShort, msgShort = claimTier(player, "doubleMinerals", 1)
		assert(okShort == false and msgShort ~= nil, "claiming is refused when tokens are short of the tier cost")
		assert(#granted == 0, "a refused claim grants nothing")
	end

	do
		local player = join()
		for _ = 1, 3 do
			connected.bossDefeated(player) -- 45 tokens: past tier 1's cost of 40
		end
		local grantedBefore = #granted
		local okClaim = claimTier(player, "doubleMinerals", 1)
		assert(okClaim == true, "a tier is claimed once tokens cover its cost")
		assert(#granted == grantedBefore + 1 and granted[#granted].player == player)
		assert(granted[#granted].reward.minerals.stone == 300, "the tier's own reward is granted")
		assert(#fired > 0 and fired[#fired].name == "eventRewardClaimed")

		local okAgain, msgAgain = claimTier(player, "doubleMinerals", 1)
		assert(okAgain == false and msgAgain == "Already claimed", "the same tier can't be claimed twice")
	end

	--------------------------------------------------------- claim after the run ends
	do
		local player = join()
		for _ = 1, 3 do
			connected.bossDefeated(player) -- 45 tokens, earned while the event is active
		end
		now = BETWEEN_RUNS_NOW
		-- Rewards already earned can still be claimed once the event's window
		-- has passed; claimTier doesn't gate on activeEvents.
		local ok = claimTier(player, "doubleMinerals", 1)
		assert(ok == true, "a tier claim works even after the run's window has ended")
		now = RUN1_START + 3600
	end

	------------------------------------------------- finished resets, unfinished carries
	do
		-- Player A clears every tier during run 1, then plays again during
		-- run 2: a finished track starts over.
		local playerA = join()
		for _ = 1, 30 do
			connected.bossDefeated(playerA) -- 30 * 15 = 450, covers every tier
		end
		for index = 1, 4 do
			local ok = claimTier(playerA, "doubleMinerals", index)
			assert(ok == true, "every tier is reachable with 450 tokens")
		end
		local stateA = datas[playerA].eventTracks.doubleMinerals
		assert(stateA.run == RUN1_START)

		now = RUN2_START + 3600
		connected.bossDefeated(playerA) -- the first action of run 2
		local stateA2 = datas[playerA].eventTracks.doubleMinerals
		assert(stateA2.run == RUN2_START, "the track moves to the new run")
		assert(stateA2.tokens == 15, "a finished track's tokens reset, so this only has the new action's amount")
		assert(next(stateA2.claimed) == nil, "a finished track's claims reset too")
		now = RUN1_START + 3600

		-- Player B earns some tokens and claims only the first tier during
		-- run 1, then plays again during run 2: an unfinished track carries
		-- its progress forward instead of resetting.
		local playerB = join()
		for _ = 1, 3 do
			connected.bossDefeated(playerB) -- 45 tokens
		end
		local okB = claimTier(playerB, "doubleMinerals", 1)
		assert(okB == true)
		local stateB = datas[playerB].eventTracks.doubleMinerals
		assert(stateB.tokens == 45 and stateB.claimed["1"] == true)

		now = RUN2_START + 3600
		connected.bossDefeated(playerB) -- the first action of run 2
		local stateB2 = datas[playerB].eventTracks.doubleMinerals
		assert(stateB2.run == RUN2_START, "the track still moves to the new run")
		assert(stateB2.tokens == 60, "an unfinished track's tokens carry over (45 + 15), not reset")
		assert(stateB2.claimed["1"] == true, "an unfinished track's claims carry over too")
		now = RUN1_START + 3600
	end

	print("live-event-service: ok")
end
