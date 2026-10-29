-- Server-authoritative surge timing and payout boundaries.
do
	local interval = Config.WorldBeat.intervalSeconds
	local duration = Config.WorldBeat.durationSeconds
	local warning = Config.WorldBeat.warningSeconds
	assert(interval == 900 and duration == 90 and warning == 60, "initial cadence is 15m / 90s / 60s warning")

	local phase, remaining, run = WorldBeat.phase(interval * 5)
	assert(phase == "active" and remaining == duration and run == interval * 5)
	assert(WorldBeat.miningMultiplier(interval * 5) == 2, "boost starts on the UTC boundary")

	phase, remaining, run = WorldBeat.phase(interval * 5 + duration - 1)
	assert(phase == "active" and remaining == 1 and run == interval * 5)
	local mult, runId = WorldBeat.miningMultiplier(interval * 5 + duration - 1)
	assert(mult == 2 and runId == interval * 5, "last active second still pays 2x")

	phase, remaining = WorldBeat.phase(interval * 5 + duration)
	assert(phase == "idle" and remaining == interval - duration)
	assert(WorldBeat.miningMultiplier(interval * 5 + duration) == 1, "bonus stops exactly at expiry")

	phase, remaining, run = WorldBeat.phase(interval * 6 - warning)
	assert(phase == "warning" and remaining == warning and run == interval * 6)
	assert(WorldBeat.miningMultiplier(interval * 6 - warning) == 1, "warning never pays early")
	phase, remaining = WorldBeat.phase(interval * 6 - 1)
	assert(phase == "warning" and remaining == 1)
	phase, remaining, run = WorldBeat.phase(interval * 6)
	assert(phase == "active" and remaining == duration and run == interval * 6)
	assert(WorldBeat.miningMultiplier(interval * 6 + duration) == 1)
	print("world-beat: ok")
end
