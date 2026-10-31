-- Creator Dashboard funnels, custom events, economy and progression logging
-- (AnalyticsService). The check script bundles the real Config/Stats above
-- this file and loads the real AnalyticsService with its requires replaced
-- by the mocks below.
--
-- Out of scope here: the `while true do task.wait(FLUSH_INTERVAL) end`
-- auto-flush loop -- task.spawn is a no-op, so it never runs in this test,
-- but the `flush` it drives is also reachable directly through the real
-- Players.PlayerRemoving wiring below, so flush itself is still covered.
do
	local onboardingCalls, customCalls, funnelCalls = {}, {}, {}
	local economyCalls, progressionCalls = {}, {}
	local robloxAnalytics = {
		LogOnboardingFunnelStepEvent = function(_, player, step, name)
			table.insert(onboardingCalls, { player = player, step = step, name = name })
		end,
		LogCustomEvent = function(_, player, name, value, fieldsTable)
			table.insert(customCalls, { player = player, name = name, value = value, fields = fieldsTable })
		end,
		LogFunnelStepEvent = function(_, player, funnel, session, step, name, fieldsTable)
			table.insert(funnelCalls, {
				player = player,
				funnel = funnel,
				session = session,
				step = step,
				name = name,
				fields = fieldsTable,
			})
		end,
		LogEconomyEvent = function(_, player, flowType, displayName, amount, balance, category, source)
			table.insert(economyCalls, {
				player = player,
				flowType = flowType,
				displayName = displayName,
				amount = amount,
				balance = balance,
				category = category,
				source = source,
			})
		end,
		LogProgressionCompleteEvent = function(_, player, kind, count, label)
			table.insert(progressionCalls, { player = player, kind = kind, count = count, label = label })
		end,
	}

	local guidCounter = 0
	local httpService = {
		GenerateGUID = function(_, wrapInCurly)
			guidCounter += 1
			return "guid" .. guidCounter
		end,
	}

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
			golem = { xp = 0 },
			bossesDefeated = {},
			minerals = { stone = 0, copper = 0, iron = 0, crystal = 0 },
		}
	end

	local datas = {}
	local nextId = 0
	local function join(data: any?)
		nextId += 1
		local player = { UserId = nextId, DisplayName = "P" .. nextId }
		if data ~= nil then
			datas[player] = data
		end
		return player
	end

	local eventHandlers = {}
	local trackHandler, playerRemoving
	local loaded, changed = signal(), signal()
	local clockNow = 0
	local function clock(): number
		return clockNow
	end

	local analytics = loadAnalyticsService({
		Config = Config,
		Remotes = {
			Track = {
				OnServerEvent = {
					Connect = function(_, fn)
						trackHandler = fn
					end,
				},
			},
		},
		Stats = Stats,
		DataService = {
			get = function(player)
				return datas[player]
			end,
			ProfileLoaded = loaded,
			Changed = changed,
		},
		Events = {
			connect = function(name, fn)
				eventHandlers[name] = fn
			end,
		},
	}, {
		GetService = function(_, name)
			if name == "Players" then
				return {
					PlayerRemoving = {
						Connect = function(_, fn)
							playerRemoving = fn
						end,
					},
				}
			elseif name == "AnalyticsService" then
				return robloxAnalytics
			elseif name == "HttpService" then
				return httpService
			end
			return {
				WaitForChild = function()
					return {}
				end,
			}
		end,
	}, {
		spawn = function() end, -- the periodic auto-flush loop never runs in this test
	}, clock)
	analytics.start()

	--------------------------------------------------------------- onboardingStep
	do
		local player = join(freshData())
		analytics.onboardingStep(player, 1, "steer")
		assert(#onboardingCalls == 1 and onboardingCalls[1].step == 1 and onboardingCalls[1].name == "steer")
		analytics.onboardingStep(player, 1, "steer")
		assert(#onboardingCalls == 1, "repeating the same step for the same player logs nothing new")
		analytics.onboardingStep(player, 2, "mine")
		assert(#onboardingCalls == 2)
	end

	--------------------------------------------------------------- zones funnel
	do
		local tutorialSteps = #Config.Tutorial.steps
		local walker = join(freshData())
		loaded:Fire(walker)
		assert(#funnelCalls == 2, "loading seeds the first island's unlocked and entered steps")
		assert(
			funnelCalls[1].funnel == "Zones"
				and funnelCalls[1].step == 1
				and funnelCalls[1].name == "Mossy Quarry: unlocked"
		)
		assert(funnelCalls[2].step == 2 and funnelCalls[2].name == "Mossy Quarry: entered")

		loaded:Fire(walker)
		assert(#funnelCalls == 2, "re-loading the same player logs nothing new for already-seen zone phases")

		eventHandlers.zoneEntered(walker, 1)
		assert(#funnelCalls == 2, "re-entering an already-logged zone phase is a no-op")

		local onboardingBefore = #onboardingCalls
		eventHandlers.bossEngaged(walker, 1)
		assert(#funnelCalls == 3 and funnelCalls[3].step == 3 and funnelCalls[3].name == "Mossy Quarry: boss fought")
		assert(
			#onboardingCalls == onboardingBefore + 1
				and onboardingCalls[#onboardingCalls].step == tutorialSteps + 2
				and onboardingCalls[#onboardingCalls].name == "first boss fought"
		)

		eventHandlers.bossDefeated(walker, 1)
		assert(#funnelCalls == 4 and funnelCalls[4].step == 4 and funnelCalls[4].name == "Mossy Quarry: boss beaten")
		assert(
			onboardingCalls[#onboardingCalls].step == tutorialSteps + 3
				and onboardingCalls[#onboardingCalls].name == "first boss beaten"
		)

		onboardingBefore = #onboardingCalls
		eventHandlers.bossEngaged(walker, 2)
		assert(#funnelCalls == 5 and funnelCalls[5].step == 7 and funnelCalls[5].name == "Ember Flats: boss fought")
		assert(#onboardingCalls == onboardingBefore, "only the first zone's boss events feed the onboarding funnel")
	end

	--------------------------------------------------------------- progression
	do
		local climber = join(freshData())
		loaded:Fire(climber) -- seeds lastLevel at Stats.levelForXp(0) == 1
		local progressionBefore = #progressionCalls
		datas[climber].golem.xp = Stats.xpForLevel(4)
		changed:Fire(climber)
		assert(#progressionCalls == progressionBefore + 3, "every level crossed is logged, not just the final one")
		assert(progressionCalls[progressionBefore + 1].count == 2)
		assert(progressionCalls[progressionBefore + 2].count == 3)
		assert(
			progressionCalls[progressionBefore + 3].count == 4
				and progressionCalls[progressionBefore + 3].label == "Level 4"
				and progressionCalls[progressionBefore + 3].kind == "Golem level"
		)

		progressionBefore = #progressionCalls
		datas[climber].golem.xp = 0
		changed:Fire(climber)
		assert(#progressionCalls == progressionBefore, "a level drop after awakening logs nothing")

		-- defeating zone 1's boss unlocks zone 2, which Changed notices too
		datas[climber].bossesDefeated["1"] = true
		local funnelBefore = #funnelCalls
		changed:Fire(climber)
		assert(
			#funnelCalls == funnelBefore + 1
				and funnelCalls[#funnelCalls].step == 5
				and funnelCalls[#funnelCalls].name == "Ember Flats: unlocked"
		)
	end

	--------------------------------------------------------------- shop funnel
	do
		local shopper = join(freshData())
		trackHandler(shopper, "shopOpened", nil, nil)
		local openCall = funnelCalls[#funnelCalls]
		assert(
			openCall.funnel == "Shop" and openCall.step == 1 and openCall.name == "Opened" and openCall.session ~= nil
		)

		trackHandler(shopper, "purchasePrompted", "product", "boostXp")
		local promptCall = funnelCalls[#funnelCalls]
		assert(
			promptCall.step == 2 and promptCall.session == openCall.session,
			"a prompt reuses the open step's session"
		)
		assert(promptCall.fields and promptCall.fields.CustomField01 == "product_boostXp")

		local before = #funnelCalls
		trackHandler(shopper, "purchasePrompted", "product", "notARealProduct")
		assert(#funnelCalls == before, "an unrecognized SKU never reaches the funnel")

		eventHandlers.purchased(shopper, "pass", "doubleMinerals")
		local confirmCall = funnelCalls[#funnelCalls]
		assert(confirmCall.step == 3 and confirmCall.session == openCall.session)
		assert(confirmCall.fields.CustomField01 == "pass_doubleMinerals")

		local fresh = join(freshData())
		trackHandler(fresh, "purchasePrompted", "cosmetic", "mossy")
		local freshCall = funnelCalls[#funnelCalls]
		assert(
			freshCall.step == 2 and freshCall.session ~= openCall.session,
			"a prompt with no prior open gets its own session"
		)
	end

	--------------------------------------------------------------- rate limit
	do
		local limited = join(freshData())
		clockNow = 100 -- a window of its own, independent of any prior calls' clock state
		local funnelBefore = #funnelCalls
		for _ = 1, 10 do
			trackHandler(limited, "shopOpened", nil, nil)
		end
		assert(#funnelCalls == funnelBefore + 10, "exactly MAX_TRACKS_PER_WINDOW calls are allowed")
		trackHandler(limited, "shopOpened", nil, nil)
		assert(#funnelCalls == funnelBefore + 10, "the 11th call inside the same window is dropped")

		clockNow += 11 -- past TRACK_WINDOW (10s): a new window opens
		trackHandler(limited, "shopOpened", nil, nil)
		assert(#funnelCalls == funnelBefore + 11, "a new window allows tracking again")
	end

	--------------------------------------------------------------- economy + flush
	do
		-- DataService mutates data.minerals and *then* fires the event (see
		-- DataService.addMinerals/spend), so each queued entry's balance is
		-- set here before firing, same as the real sequence.
		local trader = join(freshData())
		datas[trader].minerals.stone = 3
		eventHandlers.mineralsGained(trader, { stone = 3 }, "mining")
		datas[trader].minerals.stone = 5
		eventHandlers.mineralsGained(trader, { stone = 2 }, "mining")
		datas[trader].minerals.copper = 4
		eventHandlers.mineralsGained(trader, { stone = 0, copper = 4 }, "mining") -- the zero amount is skipped
		datas[trader].minerals.stone = -1 -- unrealistic, but only the latest balance matters here
		eventHandlers.mineralsSpent(trader, { stone = 6 }, "forge")
		eventHandlers.mineralsSpent(trader, { copper = 3 }, "coreUpgrade")

		eventHandlers.spellCast(trader, "quake")
		eventHandlers.spellCast(trader, "quake")
		eventHandlers.spellCast(trader, "mend")

		local economyBefore, customBefore = #economyCalls, #customCalls
		playerRemoving(trader)
		assert(#economyCalls == economyBefore + 4, "one economy entry per distinct (flow, source, mineral) triplet")
		local bySource = {}
		for i = economyBefore + 1, #economyCalls do
			local entry = economyCalls[i]
			bySource[entry.displayName .. ":" .. entry.source] = entry
		end
		local stoneMined = bySource[Config.Minerals.stone.displayName .. ":mining"]
		assert(
			stoneMined and stoneMined.amount == 5 and stoneMined.balance == 5 and stoneMined.category == "Gameplay",
			"same-mineral gains in different calls accumulate into one entry, keeping the latest balance"
		)
		local copperMined = bySource[Config.Minerals.copper.displayName .. ":mining"]
		assert(
			copperMined and copperMined.amount == 4,
			"a zero-amount entry in the same call is skipped, the real one kept"
		)
		local stoneSpent = bySource[Config.Minerals.stone.displayName .. ":forge"]
		assert(stoneSpent and stoneSpent.amount == 6 and stoneSpent.category == "Shop")
		local coreSpent = bySource[Config.Minerals.copper.displayName .. ":coreUpgrade"]
		assert(
			coreSpent and coreSpent.amount == 3 and coreSpent.category == "Shop",
			"Core upgrades have their own sink"
		)

		assert(#customCalls == customBefore + 2, "each distinct spell cast is flushed as its own SpellsCast event")
		local byField = {}
		for i = customBefore + 1, #customCalls do
			local entry = customCalls[i]
			assert(entry.name == "SpellsCast")
			byField[entry.fields.CustomField01] = entry
		end
		assert(
			byField.quake and byField.quake.value == 2,
			"two casts of the same spell are counted, not re-logged twice"
		)
		assert(byField.mend and byField.mend.value == 1)

		-- PlayerRemoving also clears lastLevel, so a later Changed fire with no
		-- fresh ProfileLoaded in between logs nothing.
		local progressionBefore = #progressionCalls
		datas[trader].golem.xp = Stats.xpForLevel(5)
		changed:Fire(trader)
		assert(#progressionCalls == progressionBefore, "cleanup clears lastLevel until the player loads again")
	end

	--------------------------------------------------------------- simple custom events
	do
		local p = join(freshData())
		local customBefore = #customCalls
		eventHandlers.artifactFound(p, "pebbleCharm")
		assert(
			customCalls[#customCalls].name == "ArtifactFound"
				and customCalls[#customCalls].fields.CustomField01 == "pebbleCharm"
		)

		eventHandlers.partyJoined(p, 3)
		assert(customCalls[#customCalls].name == "PartyJoined" and customCalls[#customCalls].value == 3)

		eventHandlers.codeRedeemed(p, "LAUNCH")
		assert(
			customCalls[#customCalls].name == "CodeRedeemed"
				and customCalls[#customCalls].fields.CustomField01 == "LAUNCH"
		)

		eventHandlers.eventRewardClaimed(p, "springFestival", 2)
		assert(customCalls[#customCalls].name == "EventRewardClaimed" and customCalls[#customCalls].value == 2)
		assert(customCalls[#customCalls].fields.CustomField01 == "springFestival")
		assert(#customCalls == customBefore + 4)

		eventHandlers.worldBeatParticipated(p, 900)
		assert(customCalls[#customCalls].name == "WorldBeatParticipated")
		assert(customCalls[#customCalls].fields.CustomField01 == "mineralSurge")
		local surgeCount = #customCalls
		eventHandlers.worldBeatParticipated(p, 900)
		assert(#customCalls == surgeCount, "multiple nodes in one surge log one participant")
		eventHandlers.worldBeatParticipated(p, 1800)
		assert(#customCalls == surgeCount + 1, "a later surge logs participation again")

		local progressionBefore = #progressionCalls
		eventHandlers.awakened(p, 1)
		assert(
			progressionCalls[#progressionCalls].kind == "Awakening" and progressionCalls[#progressionCalls].count == 1
		)
		eventHandlers.ascended(p, 1)
		assert(
			progressionCalls[#progressionCalls].kind == "Ascension" and progressionCalls[#progressionCalls].count == 1
		)
		assert(#progressionCalls == progressionBefore + 2)

		local itemCustomBefore = #customCalls
		trackHandler(p, "itemPreviewed", "cosmetic", "mossy")
		assert(#customCalls == itemCustomBefore + 1 and customCalls[#customCalls].name == "ItemPreviewed")
		assert(customCalls[#customCalls].fields.CustomField01 == "cosmetic_mossy")
		trackHandler(p, "itemPreviewed", "cosmetic", "notReal")
		assert(#customCalls == itemCustomBefore + 1, "an unrecognized preview key logs nothing")
	end

	print("analytics-service: ok")
end
