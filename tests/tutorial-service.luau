-- The first-time tutorial (TutorialService): starting it on a fresh save,
-- skipping it for players who already have progress, stepping through each
-- real-game-event trigger, the stone top-up on entering the forge step, and
-- skipTutorial. The check script bundles the real Config/Stats above this
-- file and loads the real TutorialService with its requires replaced by the
-- mocks below.
--
-- Out of scope here: the "steer" step, which only completes through
-- .start()'s `while true do task.wait(POLL_INTERVAL) end` steering-poll
-- loop -- kept a no-op, so that loop never actually runs in this test.
do
	local handlers = {}
	local eventHandlers = {}
	local notified = {}
	local logged = {}
	local grants = {}
	local datas = {}

	local function signal()
		local callbacks = {}
		return {
			Connect = function(_, callback)
				table.insert(callbacks, callback)
			end,
			Fire = function(_, ...)
				for _, callback in callbacks do
					callback(...)
				end
			end,
		}
	end

	local function freshData()
		return {
			tutorial = { done = false, step = 0 },
			golem = { xp = 0, parts = {} },
			awakening = { count = 0 },
			minerals = { stone = 0 },
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

	local loaded, changed = signal(), signal()
	local tutorial = loadTutorialService({
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
		AnalyticsService = {
			onboardingStep = function(player, step, name)
				table.insert(logged, { player = player, step = step, name = name })
			end,
		},
		DataService = {
			get = function(player)
				return datas[player]
			end,
			update = function(player, fn)
				fn(datas[player])
			end,
			ProfileLoaded = loaded,
			Changed = changed,
		},
		EconomyService = {
			grantFlat = function(player, amounts, reason)
				table.insert(grants, { player = player, amounts = amounts, reason = reason })
			end,
		},
		Events = {
			connect = function(name, fn)
				eventHandlers[name] = fn
			end,
		},
		GolemService = {},
	}, {
		GetService = function(_, name)
			if name == "Players" then
				return { PlayerRemoving = { Connect = function() end } }
			end
			return {
				WaitForChild = function()
					return {}
				end,
			}
		end,
	}, {
		spawn = function() end, -- the steering-poll loop never runs in this test
	})
	tutorial.start()
	assert(handlers.skipTutorial, "skipTutorial is registered")
	assert(
		eventHandlers.nodeMined and eventHandlers.partCrafted and eventHandlers.spellCast,
		"TutorialService connects to the real game events"
	)

	local cheapestStone = math.huge
	for _, slot in Config.SlotOrder do
		cheapestStone = math.min(cheapestStone, Stats.partCost(slot, "stone").stone)
	end

	--------------------------------------------------------------------- onLoaded
	do
		local noData = join()
		loaded:Fire(noData)
		assert(datas[noData] == nil, "a player with no data is left alone")

		local alreadyDone = join(freshData())
		datas[alreadyDone].tutorial.done = true
		loaded:Fire(alreadyDone)
		assert(datas[alreadyDone].tutorial.step == 0, "an already-finished save is left alone")

		local veteran = join(freshData())
		datas[veteran].golem.xp = 50
		loaded:Fire(veteran)
		assert(datas[veteran].tutorial.done == true, "existing progress finishes the tutorial without starting it")
		assert(datas[veteran].tutorial.step == 0, "step is left untouched for a save that skips the tutorial")
		assert(#notified == 0 and #logged == 0, "skipping via existing progress has no notification or log")

		local fresh = join(freshData())
		loaded:Fire(fresh)
		assert(datas[fresh].tutorial.step == 1, "a fresh save starts the tutorial at step 1")
		assert(#logged == 1 and logged[1].step == 1 and logged[1].name == "steer", "starting step 1 is logged")

		local midway = join(freshData())
		datas[midway].tutorial.step = 3 -- "forge", topUpStone = true
		loaded:Fire(midway)
		assert(#grants == 1, "re-entering the forge step on load tops up stone for the first part")
		assert(grants[1].player == midway and grants[1].reason == "tutorial")
		assert(grants[1].amounts.minerals.stone == cheapestStone)

		local midwayFlush = join(freshData())
		datas[midwayFlush].tutorial.step = 3
		datas[midwayFlush].minerals.stone = cheapestStone -- already enough for the cheapest part
		loaded:Fire(midwayFlush)
		assert(#grants == 1, "already having enough stone grants nothing extra")
	end

	--------------------------------------------------------------------- complete
	do
		local walker = join(freshData())
		loaded:Fire(walker) -- step 1: "steer"

		eventHandlers.nodeMined(walker)
		assert(datas[walker].tutorial.step == 1, "mining does not complete a step the player isn't on")

		-- The "steer" step itself only finishes through the untested poll loop;
		-- move past it directly so the remaining, event-driven steps can run.
		datas[walker].tutorial.step = 2 -- "mine"
		local notifiedBefore = #notified
		local grantsBefore = #grants
		eventHandlers.nodeMined(walker)
		assert(datas[walker].tutorial.step == 3, "mining the first node advances to the forge step")
		assert(
			#notified == notifiedBefore + 1
				and notified[#notified].kind == "tutorialStep"
				and notified[#notified].message == 2
		)
		assert(#grants == grantsBefore + 1, "entering the forge step tops up stone")
		assert(grants[#grants].amounts.minerals.stone == cheapestStone)

		notifiedBefore = #notified
		eventHandlers.partCrafted(walker)
		assert(datas[walker].tutorial.step == 4, "crafting the first part advances to the quake step")
		assert(#notified == notifiedBefore + 1 and notified[#notified].message == 3)

		eventHandlers.spellCast(walker, "mend")
		assert(datas[walker].tutorial.step == 4, "a different spell does not complete the quake step")

		notifiedBefore, grantsBefore = #notified, #grants
		eventHandlers.spellCast(walker, "quake")
		assert(datas[walker].tutorial.step == 5, "casting Quake advances to the level step")
		assert(#notified == notifiedBefore + 1 and notified[#notified].message == 4)
		assert(#grants == grantsBefore + 1 and grants[#grants].amounts.xp == 20, "the quake step's reward is granted")

		tutorial.check(walker)
		assert(datas[walker].tutorial.step == 5 and datas[walker].tutorial.done == false, "check is a no-op below level 2")

		datas[walker].golem.xp = Stats.xpForLevel(2)
		local doneNotifiedBefore = #notified
		local loggedBefore = #logged
		changed:Fire(walker) -- exercises the real DataService.Changed wiring, not a direct check() call
		assert(datas[walker].tutorial.done == true, "reaching level 2 on the last step finishes the tutorial")
		-- complete() fires "tutorialStep" for the last step unconditionally, then
		-- finish() fires a second, separate "tutorialDone".
		assert(#notified == doneNotifiedBefore + 2, "the last step's own notify and tutorialDone both fire")
		assert(notified[#notified - 1].kind == "tutorialStep" and notified[#notified - 1].message == 5)
		assert(notified[#notified].kind == "tutorialDone")
		assert(#logged == loggedBefore + 1 and logged[#logged].name == "done", "finishing (not skipping) logs the final step")
	end

	--------------------------------------------------------------------- skipTutorial
	do
		local skipper = join(freshData())
		loaded:Fire(skipper)
		local notifiedBefore = #notified
		local loggedBefore = #logged
		local ok, message = handlers.skipTutorial(skipper)
		assert(ok == true and type(message) == "string", "skipping returns a confirmation message")
		assert(datas[skipper].tutorial.done == true, "skipping finishes the tutorial")
		assert(#notified == notifiedBefore, "skipping fires no tutorialDone notification")
		assert(#logged == loggedBefore, "skipping logs no final step")

		local okAgain = handlers.skipTutorial(skipper)
		assert(okAgain == false, "skipping an already-finished tutorial is refused")
	end

	print("tutorial-service: ok")
end
