-- GauntletService's free solo Golem Run (#207): startRun's eligibility,
-- zone/cooldown/proximity gating, and tick()'s hazard detection, ordered
-- checkpoint payout and run-ending logic, driven through the real
-- ProximityPrompt.Triggered wiring .start() sets up and the real tick()
-- called directly. The check script bundles the real Config/GauntletRules
-- above this file and loads the real GauntletService with its requires
-- replaced by the mocks below.
--
-- Out of scope: buildCourse()'s billboard/rail/sign cosmetics -- every
-- field they set is a plain write on a bare Instance.new table, so none of
-- it needs inspecting here.
do
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

	-- A position in course-local coordinates, matching how buildCourse's
	-- own point(x, z, height) places things relative to Config.Gauntlet.center.
	local function at(x, z)
		return Config.Gauntlet.center + Vector3.new(x, 2, z)
	end

	local notified = {}
	local granted = {}
	local sentToZone = {}
	local playerRemoving = signal()
	local entrySignal, leaveSignal

	local Instance = {
		new = function(className)
			local inst = {}
			if className == "ProximityPrompt" then
				inst.Triggered = signal()
			end
			return inst
		end,
	}
	local UDim2 = {
		fromOffset = function()
			return {}
		end,
		fromScale = function()
			return {}
		end,
	}
	local CFrame = { new = function(position)
		return { Position = position }
	end }

	local gauntletClock = 0
	local function clock(): number
		return gauntletClock
	end

	local hasSave = {}
	local golems = {}

	local function makeGolem()
		return {
			mounted = true,
			active = true,
			zoneId = Config.HubZone,
			groundOffset = 3,
			root = {
				Position = at(0, 0),
				AssemblyLinearVelocity = Vector3.zero,
				AssemblyAngularVelocity = Vector3.zero,
			},
			humanoid = { Move = function() end },
			model = { PivotTo = function() end },
		}
	end

	local gauntlet = loadGauntletService({
		Config = Config,
		GauntletRules = GauntletRules,
		Remotes = {
			Notify = {
				FireClient = function(_, player, kind, ...)
					table.insert(notified, { player = player, kind = kind, ... })
				end,
			},
		},
		DataService = {
			get = function(player)
				return hasSave[player] == true
			end,
		},
		EconomyService = {
			grantFlat = function(player, amounts, reason)
				table.insert(granted, { player = player, amounts = amounts, reason = reason })
			end,
		},
		GolemService = {
			get = function(player)
				return golems[player]
			end,
			isActive = function(golem)
				return golem.active == true
			end,
			sendToZone = function(golem, zoneId)
				golem.zoneId = zoneId
				table.insert(sentToZone, { golem = golem, zoneId = zoneId })
			end,
		},
		WorldService = {
			addArena = function() end,
			getSpawnPoint = function()
				return Vector3.new(0, 10, 0)
			end,
		},
	}, {
		GetService = function(_, name)
			if name == "Players" then
				return { PlayerRemoving = playerRemoving }
			end
			return {
				WaitForChild = function()
					return {}
				end,
			}
		end,
	}, Instance, UDim2, CFrame, { GetServerTimeNow = clock }, clock)

	-- .start() builds the course once, through buildCourse(); capture the
	-- entry/leave prompts' Triggered signals via the real Instance.new mock
	-- above (the calls to it happen inside .start(), so there's no direct
	-- hook -- every ProximityPrompt it creates gets its own signal, and the
	-- gate and start-pad prompts are the only two created, in that order).
	local createdPrompts = {}
	local realNew = Instance.new
	Instance.new = function(className)
		local inst = realNew(className)
		if className == "ProximityPrompt" then
			table.insert(createdPrompts, inst)
		end
		return inst
	end
	gauntlet.start()
	Instance.new = realNew
	entrySignal, leaveSignal = createdPrompts[1].Triggered, createdPrompts[2].Triggered

	-- Refusals: none of these create a run or touch the cooldown.
	local pNotMounted = { Parent = true }
	hasSave[pNotMounted] = true
	golems[pNotMounted] = makeGolem()
	golems[pNotMounted].mounted = false
	entrySignal:Fire(pNotMounted)
	assert(
		notified[#notified].kind == "message" and notified[#notified][1] == "Ride your golem to enter.",
		"not mounted is refused"
	)

	local pNoSave = { Parent = true }
	golems[pNoSave] = makeGolem()
	entrySignal:Fire(pNoSave)
	assert(notified[#notified][1] == "Ride your golem to enter.", "no save is refused the same way")

	local pWrongZone = { Parent = true }
	hasSave[pWrongZone] = true
	golems[pWrongZone] = makeGolem()
	golems[pWrongZone].zoneId = Config.HubZone + 1
	entrySignal:Fire(pWrongZone)
	assert(notified[#notified][1] == "Find Golem Run's portal in the Hub.", "the wrong zone is refused")

	local pFarFromPortal = { Parent = true }
	hasSave[pFarFromPortal] = true
	golems[pFarFromPortal] = makeGolem()
	golems[pFarFromPortal].root.Position = Vector3.new(0, 10, 5000)
	entrySignal:Fire(pFarFromPortal)
	assert(notified[#notified][1] == "Find Golem Run's portal in the Hub.", "too far from the portal is refused")

	-- The main run: a full, in-order three-checkpoint completion, a hazard
	-- hit (with its grace window), a moving-boulder hit, and a revisited
	-- checkpoint paying nothing.
	local pMain = { Parent = true }
	hasSave[pMain] = true
	golems[pMain] = makeGolem()
	golems[pMain].root.Position = Vector3.new(24, 10, 0) -- near the Hub portal

	gauntletClock = 1000
	entrySignal:Fire(pMain)
	assert(golems[pMain].zoneId == Config.Gauntlet.zoneId, "a successful start sends the golem to the course")
	assert(
		notified[#notified].kind == "gauntletStart" and notified[#notified][2] == #Config.Gauntlet.checkpoints,
		"a successful start reports the checkpoint count"
	)
	-- buildCourse's teleportTo only moves the real model/humanoid (mocked as
	-- no-ops here); place the golem at the start line ourselves, the way
	-- Studio's real physics would.
	golems[pMain].root.Position = at(0, Config.Gauntlet.startZ)

	gauntlet.tick()
	assert(#granted == 0, "nothing is claimed at the start line itself")

	golems[pMain].root.Position = at(0, Config.Gauntlet.checkpoints[1].z)
	gauntlet.tick()
	assert(
		#granted == 1 and granted[1].amounts.minerals.stone == Config.Gauntlet.checkpoints[1].reward.stone,
		"checkpoint 1 pays its fixed reward"
	)
	assert(notified[#notified].kind == "gauntletCheckpoint" and notified[#notified][1] == 1, "checkpoint 1 is reported")

	gauntlet.tick()
	assert(#granted == 1, "standing on an already-claimed checkpoint pays nothing")

	-- A hazard hit teleports back to the last safe checkpoint instead of
	-- ending the run (the lane's edge, well clear of anything else). The
	-- run's initial 1-second grace (from the start itself) hasn't elapsed
	-- yet at clock 1000, so move past it first.
	gauntletClock = 1002
	golems[pMain].root.Position = at(Config.Gauntlet.laneHalfWidth + 10, Config.Gauntlet.checkpoints[1].z)
	gauntlet.tick()
	local hitCount = #notified
	assert(notified[hitCount][1] == "Hit! Back to checkpoint. Keep earned rewards.", "a hazard hit is reported")
	-- Still inside the hit's own grace window: another hazardous tick at
	-- the same instant doesn't repeat the hit.
	gauntlet.tick()
	assert(#notified == hitCount, "a second hit during the grace window is suppressed")
	-- Past that grace window, the same hazardous spot hits again.
	gauntletClock = 1004
	gauntlet.tick()
	assert(#notified == hitCount + 1 and notified[#notified][1] == "Hit! Back to checkpoint. Keep earned rewards.")

	-- The moving boulder is its own hazard: its position is always
	-- point(math.sin(now * 1.5) * 15, 82, 5), so placing the golem on the
	-- same spot it'll occupy this tick lands on top of it.
	gauntletClock = 1006
	golems[pMain].root.Position = at(math.sin(gauntletClock * 1.5) * 15, 82)
	gauntlet.tick()
	assert(notified[#notified][1] == "Hit! Back to checkpoint. Keep earned rewards.", "the moving boulder is a hazard")

	-- The run survived every hit: checkpoint 2, then a revisit of
	-- checkpoint 1 (pays nothing, out of order), then checkpoint 3
	-- completes the run.
	gauntletClock = 1009
	golems[pMain].root.Position = at(0, Config.Gauntlet.checkpoints[2].z)
	gauntlet.tick()
	assert(#granted == 2, "checkpoint 2 pays once the run has survived its hits")

	golems[pMain].root.Position = at(0, Config.Gauntlet.checkpoints[1].z)
	gauntlet.tick()
	assert(#granted == 2, "revisiting a checkpoint already behind you pays nothing")

	golems[pMain].root.Position = at(0, Config.Gauntlet.checkpoints[3].z)
	gauntlet.tick()
	assert(#granted == 3, "checkpoint 3 pays its reward too")
	assert(
		notified[#notified].kind == "gauntletEnd"
			and notified[#notified][1] == "Run complete! You earned all 3 rewards.",
		"the third checkpoint completes the run"
	)
	assert(golems[pMain].zoneId == Config.HubZone, "finishing sends the golem back to the Hub")

	-- Still on cooldown immediately after: starting again is refused.
	entrySignal:Fire(pMain)
	assert(notified[#notified].kind == "message" and notified[#notified][1]:match("^The run opens again in"))

	-- Leaving early keeps whatever was already earned.
	local pLeave = { Parent = true }
	hasSave[pLeave] = true
	golems[pLeave] = makeGolem()
	golems[pLeave].root.Position = Vector3.new(24, 10, 0)
	gauntletClock = 2000
	entrySignal:Fire(pLeave)
	golems[pLeave].root.Position = at(0, Config.Gauntlet.checkpoints[1].z)
	gauntlet.tick()
	local earnedBeforeLeaving = #granted
	leaveSignal:Fire(pLeave)
	assert(
		notified[#notified].kind == "gauntletEnd" and notified[#notified][1] == "Run ended. You keep earned rewards.",
		"leaving ends the run with its own message"
	)
	assert(golems[pLeave].zoneId == Config.HubZone, "leaving sends the golem back to the Hub")
	gauntlet.tick()
	assert(#granted == earnedBeforeLeaving, "a run that's already ended claims nothing more")

	-- Dismounting mid-run ends it the same way leaving does.
	local pDismount = { Parent = true }
	hasSave[pDismount] = true
	golems[pDismount] = makeGolem()
	golems[pDismount].root.Position = Vector3.new(24, 10, 0)
	gauntletClock = 3000
	entrySignal:Fire(pDismount)
	golems[pDismount].mounted = false
	gauntlet.tick()
	assert(
		notified[#notified].kind == "gauntletEnd" and notified[#notified][1] == "Run ended. You keep earned rewards.",
		"dismounting mid-run ends it"
	)
	assert(golems[pDismount].zoneId == Config.HubZone, "dismounting still sends the golem home")

	-- Leaving the course zone some other way ends it too, without a second
	-- (redundant) sendToZone call, since the golem is no longer there.
	local pLeftZone = { Parent = true }
	hasSave[pLeftZone] = true
	golems[pLeftZone] = makeGolem()
	golems[pLeftZone].root.Position = Vector3.new(24, 10, 0)
	gauntletClock = 4000
	entrySignal:Fire(pLeftZone)
	local sentBeforeLeavingZone = #sentToZone
	golems[pLeftZone].zoneId = Config.HubZone
	gauntlet.tick()
	assert(
		notified[#notified][1] == "Run ended. You keep earned rewards." and #sentToZone == sentBeforeLeavingZone,
		"already having left the zone doesn't send the golem home again"
	)

	-- Running out of time ends the run, even at a perfectly safe position.
	local pTimeout = { Parent = true }
	hasSave[pTimeout] = true
	golems[pTimeout] = makeGolem()
	golems[pTimeout].root.Position = Vector3.new(24, 10, 0)
	gauntletClock = 5000
	entrySignal:Fire(pTimeout)
	golems[pTimeout].root.Position = at(0, Config.Gauntlet.startZ)
	gauntletClock += Config.Gauntlet.durationSeconds + 1
	gauntlet.tick()
	assert(notified[#notified][1] == "Time's up! You keep earned rewards.", "running out of time ends the run")

	-- A player who has already left the game by the next tick is dropped
	-- with no notification (there's nobody there to notify).
	local pGoneMidTick = { Parent = true }
	hasSave[pGoneMidTick] = true
	golems[pGoneMidTick] = makeGolem()
	golems[pGoneMidTick].root.Position = Vector3.new(24, 10, 0)
	gauntletClock = 6000
	entrySignal:Fire(pGoneMidTick)
	local beforeGoneTick = #notified
	pGoneMidTick.Parent = false
	gauntlet.tick()
	assert(#notified == beforeGoneTick, "a player already gone by the next tick gets no notification")
	entrySignal:Fire(pGoneMidTick)
	assert(#notified == beforeGoneTick, "say() does nothing for a player who has left")

	-- PlayerRemoving clears a player's run and cooldown.
	local pRemoved = { Parent = true }
	hasSave[pRemoved] = true
	golems[pRemoved] = makeGolem()
	golems[pRemoved].root.Position = Vector3.new(24, 10, 0)
	gauntletClock = 7000
	entrySignal:Fire(pRemoved)
	playerRemoving:Fire(pRemoved)
	gauntlet.tick()
	-- PlayerRemoving doesn't simulate the golem traveling anywhere; put it
	-- back at the Hub portal the way rejoining there would.
	golems[pRemoved].zoneId = Config.HubZone
	local beforeRemovedRetry = #notified
	entrySignal:Fire(pRemoved)
	assert(
		notified[#notified].kind == "gauntletStart",
		"PlayerRemoving clears the cooldown too, so a returning player starts fresh"
	)
	assert(#notified > beforeRemovedRetry)

	print("gauntlet-service: ok")
end
