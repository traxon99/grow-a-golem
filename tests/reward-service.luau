-- Quests, daily streak, session gifts and the group reward (RewardService).
-- The check script bundles the real Config/Stats above this file and loads
-- the real RewardService with its requires replaced by the mocks below and
-- a test-controlled os.time. grantOffline (and the ProfileLoaded hook that
-- triggers it) isn't exercised here: it needs Stats.compute/GolemService.context
-- over a fully-shaped save, which is its own, heavier surface.
do
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

	-- RewardService's own today()/thisWeek() aren't exported; mirrored here
	-- so the test can predict rollovers instead of guessing at day numbers.
	local function today(nowValue)
		return math.floor(nowValue / 86400)
	end
	local function thisWeek(nowValue)
		return math.floor((today(nowValue) + 3) / 7)
	end

	local now = 86400 * 1000 + 3600 * 12 -- noon, an arbitrary day far from any epoch edge
	local handlers = {}
	local connected = {}
	local providers = {}
	local granted = {}
	local fired = {}
	local datas = {}
	local sessions = {}
	local changed = {}
	local removing = signal()

	local function fresh()
		return {
			quests = { day = 0, week = 0, ids = {}, weeklyId = "", progress = {}, claimed = {} },
			daily = { streak = 0, lastClaimDay = 0 },
			groupRewardClaimed = false,
		}
	end

	local rewards = loadRewardService({
		Config = Config,
		Remotes = {
			Notify = {
				FireClient = function(_, player, kind, text)
					table.insert(fired, { player = player, kind = kind, text = text })
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
			getSession = function(player)
				return sessions[player]
			end,
			markChanged = function(player)
				changed[player] = (changed[player] or 0) + 1
			end,
			addProvider = function(name, fn)
				providers[name] = fn
			end,
			ProfileLoaded = { Connect = function() end },
		},
		EconomyService = {
			grantFlat = function(player, reward, source)
				table.insert(granted, { player = player, reward = reward, source = source })
			end,
		},
		Events = {
			connect = function(eventName, fn)
				connected[eventName] = fn
			end,
		},
		GolemService = {},
		PassService = {},
	}, {
		GetService = function()
			return {
				PlayerRemoving = removing,
				WaitForChild = function()
					return {}
				end,
			}
		end,
	}, {
		spawn = function() end, -- grantOffline/checkGroup's ProfileLoaded hook never runs in this test
		wait = function() end,
	}, function()
		return now
	end)
	rewards.start()
	local claimQuest = handlers.claimQuest
	local claimDaily = handlers.claimDaily
	local claimSession = handlers.claimSession
	local claimGroup = handlers.claimGroup
	assert(claimQuest and claimDaily and claimSession and claimGroup, "all four actions are registered")
	for _, eventName in { "enemyDefeated", "nodeMined", "spellCast", "bossDefeated", "partCrafted", "artifactFound" } do
		assert(connected[eventName], `onProgress is connected to {eventName}`)
	end

	local nextId = 0
	local function join()
		nextId += 1
		local player = { UserId = nextId, DisplayName = "P" .. nextId }
		datas[player] = fresh()
		return player
	end

	------------------------------------------------------------- quest rollover
	do
		local player = join()
		local snap = providers.rewards(player)
		local data = datas[player]
		assert(data.quests.day == today(now), "ensureQuests rolls today's quests on first read")
		assert(data.quests.week == thisWeek(now), "ensureQuests rolls this week's quest on first read")
		assert(#data.quests.ids == Config.DailyQuestCount, "rolls exactly DailyQuestCount daily ids")
		assert(data.quests.weeklyId ~= "", "rolls a weekly id too")
		assert(#snap.quests == Config.DailyQuestCount + 1, "the snapshot lists every active quest, daily and weekly")

		-- Build up progress on whichever event one of today's active quests
		-- actually tracks, so the rollover-clears check below has something
		-- real to clear.
		local oldIds = table.clone(data.quests.ids)
		table.insert(oldIds, data.quests.weeklyId)
		local trackedId, trackedEvent
		for _, id in oldIds do
			for _, quest in Config.QuestPool do
				if quest.id == id then
					trackedId, trackedEvent = id, quest.event
				end
			end
			for _, quest in Config.WeeklyQuestPool do
				if quest.id == id then
					trackedId, trackedEvent = trackedId or id, trackedEvent or quest.event
				end
			end
		end
		assert(trackedId, "at least one of today's active quests resolves back to a Config entry")
		connected[trackedEvent](player)
		assert((data.quests.progress[trackedId] or 0) > 0, "progress was recorded before the rollover")

		-- Advance to the next day: old progress/claimed for the old ids is
		-- cleared, and a new day's worth of ids is rolled.
		now += 86400
		providers.rewards(player)
		assert(data.quests.day == today(now), "the new day is rolled")
		assert(data.quests.progress[trackedId] == nil, "the old day's progress is cleared on rollover")
		assert(data.quests.claimed[trackedId] == nil, "the old day's claimed flags are cleared on rollover")
	end

	------------------------------------------------------------- onProgress
	do
		local player = join()
		providers.rewards(player) -- roll today's quests
		local data = datas[player]

		-- artifactFound matches no quest in the pool at all, so it's a safe
		-- "touches nothing" probe.
		connected.artifactFound(player)
		assert(next(data.quests.progress) == nil, "an event matching no active quest records no progress")

		-- Find an active quest and drive its event past its target.
		local activeIds = table.clone(data.quests.ids)
		table.insert(activeIds, data.quests.weeklyId)
		local quest
		for _, id in activeIds do
			for _, q in Config.QuestPool do
				if q.id == id then
					quest = q
				end
			end
			for _, q in Config.WeeklyQuestPool do
				if q.id == id then
					quest = quest or q
				end
			end
		end
		assert(quest, "today's ids resolve to real quests")
		for _ = 1, quest.target + 2 do
			connected[quest.event](player)
		end
		assert(data.quests.progress[quest.id] == quest.target, "progress is capped at the quest's target")
		-- Scoped to this specific quest's own text, not just "Quest complete":
		-- today's active set can include two quests sharing an event (the
		-- pool has duplicates, e.g. defeat50/defeat150 both on enemyDefeated),
		-- so driving one to its target can legitimately also complete a
		-- sibling and fire a second, unrelated notice for the same player.
		local completeMessages = 0
		for _, f in fired do
			if f.player == player and f.kind == "message" and string.find(f.text, quest.text, 1, true) then
				completeMessages += 1
			end
		end
		assert(
			completeMessages == 1,
			"the completion notice fires exactly once, at the target, not on every overflow call"
		)

		-- Claiming it, then firing its event again, must not re-increment.
		local ok = claimQuest(player, quest.id)
		assert(ok == true)
		connected[quest.event](player)
		assert(data.quests.progress[quest.id] == quest.target, "a claimed quest's progress no longer moves")
	end

	------------------------------------------------------------- claimQuest
	do
		local player = join()
		providers.rewards(player)
		local data = datas[player]

		local okUnknown, msgUnknown = claimQuest(player, "notAQuest")
		assert(okUnknown == false and msgUnknown ~= nil, "an inactive/unknown id is refused")

		local okType = claimQuest(player, 5 :: any)
		assert(okType == false, "a non-string id is refused")

		local id = data.quests.ids[1]
		local okUnfinished, msgUnfinished = claimQuest(player, id)
		assert(okUnfinished == false and msgUnfinished == "Not finished yet", "an unfinished quest can't be claimed")

		local quest
		for _, q in Config.QuestPool do
			if q.id == id then
				quest = q
			end
		end
		for _ = 1, quest.target do
			connected[quest.event](player)
		end
		local grantedBefore = #granted
		local okClaim = claimQuest(player, id)
		assert(okClaim == true, "a finished, active quest claims successfully")
		assert(#granted == grantedBefore + 1 and granted[#granted].source == "quest")
		assert(granted[#granted].reward == quest.reward, "the quest's own reward table is granted")

		local okAgain, msgAgain = claimQuest(player, id)
		assert(okAgain == false and msgAgain == "Already claimed", "the same quest can't be claimed twice")
	end

	------------------------------------------------------------- daily streak
	do
		local player = join()
		local data = datas[player]

		local okFirst = claimDaily(player)
		assert(okFirst == true, "a brand new player can claim day 1")
		assert(data.daily.streak == 1 and data.daily.lastClaimDay == today(now))
		assert(granted[#granted].reward == Config.DailyRewards[1], "day 1 grants the first reward in the track")

		local okSameDay, msgSameDay = claimDaily(player)
		assert(okSameDay == false and msgSameDay == "Come back tomorrow!", "the same UTC day can't be claimed twice")

		now += 86400 -- a 1-day gap keeps the streak
		local okNext = claimDaily(player)
		assert(okNext == true and data.daily.streak == 2)
		assert(granted[#granted].reward == Config.DailyRewards[2])

		now += 86400 * 2 -- a 2-day gap still counts as "<= 2"
		local okStillKept = claimDaily(player)
		assert(okStillKept == true and data.daily.streak == 3, "a 2-day gap still keeps the streak")

		now += 86400 * 3 -- a 3-day gap breaks it
		local okBroken = claimDaily(player)
		assert(okBroken == true and data.daily.streak == 1, "a longer gap resets the streak to 1")
		assert(
			granted[#granted].reward == Config.DailyRewards[1],
			"the reward track wraps back to the first reward on reset"
		)
	end

	------------------------------------------------------------- claimSession
	do
		local player = join()
		sessions[player] = { loadedAt = now }

		local okBadIndex = claimSession(player, 99)
		assert(okBadIndex == false, "an out-of-range gift index is refused")
		local okBadType = claimSession(player, "1" :: any)
		assert(okBadType == false, "a non-number index is refused")

		local gift = Config.SessionRewards[1]
		local okEarly, msgEarly = claimSession(player, 1)
		assert(okEarly == false and string.find(msgEarly, tostring(gift.minutes)) ~= nil, "too early is refused")

		sessions[player].loadedAt = now - gift.minutes * 60
		local grantedBefore = #granted
		local okOnTime = claimSession(player, 1)
		assert(okOnTime == true and #granted == grantedBefore + 1 and granted[#granted].source == "session")

		local okTwice, msgTwice = claimSession(player, 1)
		assert(okTwice == false and msgTwice == "Already opened", "the same gift can't be opened twice")
	end

	------------------------------------------------------------- checkGroup
	do
		local player = join()
		assert(Config.Group.id == 0, "the real config ships the group reward off by default")
		local okOff, msgOff = claimGroup(player)
		assert(okOff == false and msgOff == "No group reward right now", "off by default when Config.Group.id == 0")

		Config.Group.id = 424242
		player.IsInGroupAsync = function(_self, groupId)
			assert(groupId == 424242, "the configured group id is the one checked")
			error("roblox API down")
		end
		local okApiDown, msgApiDown = claimGroup(player)
		assert(okApiDown == false and msgApiDown == "Join our group, then try again.", "a failed lookup is refused")

		player.IsInGroupAsync = function()
			return false
		end
		local okNotIn = claimGroup(player)
		assert(okNotIn == false, "not being in the group is refused the same way")

		player.IsInGroupAsync = function()
			return true
		end
		local grantedBefore = #granted
		local okJoin = claimGroup(player)
		assert(okJoin == true and #granted == grantedBefore + 1 and granted[#granted].source == "group")
		assert(granted[#granted].reward == Config.Group.reward)
		assert(datas[player].groupRewardClaimed == true)

		local okTwice, msgTwice = claimGroup(player)
		assert(okTwice == false and msgTwice == "Already claimed", "the group reward is a one-time grant")
		Config.Group.id = 0
	end

	print("reward-service: ok")
end
