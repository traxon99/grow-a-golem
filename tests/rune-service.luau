-- RuneService's optional three-rune casting challenge (#203): eligibility
-- and cooldown gating, the full start -> tap -> complete flow driven through
-- the real RuneInput.OnServerEvent handler, the attack-multiplier boost
-- window, and PlayerRemoving cleanup. The check script bundles the real
-- Config/RuneSequence above this file and loads the real RuneService with
-- its requires replaced by the mocks below.
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

	local notified = {}
	local runeInput = signal()
	local playerRemoving = signal()
	local golems = {}
	local activeGolems = {}
	local runeClock = 0
	local function clock(): number
		return runeClock
	end

	local rune = loadRuneService({
		Config = Config,
		Remotes = {
			Notify = {
				FireClient = function(_, player, kind, ...)
					table.insert(notified, { player = player, kind = kind, ... })
				end,
			},
			RuneInput = { OnServerEvent = runeInput },
		},
		RuneSequence = RuneSequence,
		GolemService = {
			get = function(player)
				return golems[player]
			end,
			isActive = function(golem)
				return activeGolems[golem] == true
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
	}, clock, clock)
	rune.start()

	-- No golem at all: refused, nothing started.
	local pIdle = {}
	runeInput:Fire(pIdle, "start")
	assert(#notified == 1 and notified[1].kind == "runeResult" and notified[1][1] == false, "no golem is refused")

	-- The main happy path: start, three correct taps, boost window, cooldown.
	local pMain = {}
	local golemMain = { mounted = true }
	golems[pMain] = golemMain
	activeGolems[golemMain] = true

	runeClock = 0
	runeInput:Fire(pMain, "start")
	assert(#notified == 2 and notified[2].kind == "runeStart", "an eligible player starts a challenge")
	local sequence = notified[2][1]
	assert(#sequence == 3, "a challenge is three runes")
	assert(
		notified[2][2] == Config.RuneCasting.windowSeconds and notified[2][3] == Config.RuneCasting.cooldownSeconds,
		"runeStart reports the expiry and the cooldown"
	)

	-- Starting again while the challenge is still running changes nothing.
	runeInput:Fire(pMain, "start")
	assert(#notified == 2, "a second start while one is already running is ignored")

	runeInput:Fire(pMain, "tap", sequence[1])
	assert(
		#notified == 3 and notified[3].kind == "runeStep" and notified[3][1] == 1,
		"the first correct tap steps to 1"
	)
	runeInput:Fire(pMain, "tap", sequence[2])
	assert(
		#notified == 4 and notified[4].kind == "runeStep" and notified[4][1] == 2,
		"the second correct tap steps to 2"
	)
	runeInput:Fire(pMain, "tap", sequence[3])
	assert(
		#notified == 5 and notified[5].kind == "runeResult" and notified[5][1] == true,
		"the third correct tap completes the challenge"
	)
	assert(notified[5][2] == Config.RuneCasting.boostSeconds, "the completion reports the boost duration")

	assert(
		rune.attackMultiplier(pMain, runeClock) == Config.RuneCasting.attackMultiplier,
		"the boost is active right away"
	)
	runeClock = Config.RuneCasting.boostSeconds - 1
	assert(
		rune.attackMultiplier(pMain, runeClock) == Config.RuneCasting.attackMultiplier,
		"the boost holds until its window ends"
	)
	runeClock = Config.RuneCasting.boostSeconds
	assert(rune.attackMultiplier(pMain, runeClock) == 1, "the boost ends exactly at its window")

	-- Still on cooldown: refused with the remaining time, no new challenge.
	runeInput:Fire(pMain, "start")
	assert(
		#notified == 6
			and notified[6].kind == "runeCooldown"
			and notified[6][1] == Config.RuneCasting.cooldownSeconds - runeClock,
		"starting again during the cooldown reports the remaining time"
	)

	-- Once the cooldown elapses, a fresh challenge starts normally.
	runeClock = Config.RuneCasting.cooldownSeconds
	runeInput:Fire(pMain, "start")
	assert(#notified == 7 and notified[7].kind == "runeStart", "a new challenge starts once the cooldown elapses")

	-- A wrong tap ends the attempt; further taps are then no-ops.
	local pWrong = {}
	local golemWrong = { mounted = true }
	golems[pWrong] = golemWrong
	activeGolems[golemWrong] = true
	runeClock = 1000
	runeInput:Fire(pWrong, "start")
	local wrongSequence = notified[#notified][1]
	local badRune = if wrongSequence[1] == 1 then 2 else 1
	runeInput:Fire(pWrong, "tap", badRune)
	local afterWrong = #notified
	assert(
		notified[afterWrong].kind == "runeResult" and notified[afterWrong][1] == false,
		"a wrong tap fails the challenge"
	)
	runeInput:Fire(pWrong, "tap", wrongSequence[1])
	assert(#notified == afterWrong, "tapping again after a failed challenge does nothing")

	-- Losing eligibility (dismounting) mid-challenge stops it cleanly.
	local pDismount = {}
	local golemDismount = { mounted = true }
	golems[pDismount] = golemDismount
	activeGolems[golemDismount] = true
	runeClock = 2000
	runeInput:Fire(pDismount, "start")
	local dismountSequence = notified[#notified][1]
	golemDismount.mounted = false
	runeInput:Fire(pDismount, "tap", dismountSequence[1])
	assert(
		notified[#notified].kind == "runeResult" and notified[#notified][1] == false,
		"losing eligibility mid-challenge fails it rather than completing it"
	)

	-- PlayerRemoving clears a player's cooldown and boost state.
	local pLeaving = {}
	local golemLeaving = { mounted = true }
	golems[pLeaving] = golemLeaving
	activeGolems[golemLeaving] = true
	runeClock = 3000
	runeInput:Fire(pLeaving, "start")
	local leavingSequence = notified[#notified][1]
	for _, value in leavingSequence do
		runeInput:Fire(pLeaving, "tap", value)
	end
	assert(rune.attackMultiplier(pLeaving, runeClock) == Config.RuneCasting.attackMultiplier, "pLeaving is boosted")
	playerRemoving:Fire(pLeaving)
	assert(rune.attackMultiplier(pLeaving, runeClock) == 1, "leaving clears the boost")
	local beforeRejoin = #notified
	runeInput:Fire(pLeaving, "start")
	assert(
		#notified == beforeRejoin + 1 and notified[#notified].kind == "runeStart",
		"leaving clears the cooldown, so a returning player starts fresh"
	)

	print("rune-service: ok")
end
