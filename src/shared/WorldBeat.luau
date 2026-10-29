--!strict
-- Shared schedule math for the free, global mineral surge. The server alone
-- decides payouts with os.time(); clients use the synchronized server clock
-- only to display the same countdown. No client event can grant a bonus.

local Config = require(script.Parent:WaitForChild("Config"))

local WorldBeat = {}

-- Returns phase, whole seconds remaining, and the current/next surge start.
-- UTC epoch alignment keeps all live servers on the same 15-minute beat.
function WorldBeat.phase(now: number): (string, number, number)
	local settings = Config.WorldBeat
	local timestamp = math.floor(now)
	local offset = timestamp % settings.intervalSeconds
	local startAt = timestamp - offset

	if offset < settings.durationSeconds then
		return "active", settings.durationSeconds - offset, startAt
	end

	local remaining = settings.intervalSeconds - offset
	if remaining <= settings.warningSeconds then
		return "warning", remaining, startAt + settings.intervalSeconds
	end
	return "idle", remaining, startAt + settings.intervalSeconds
end

-- A run id is returned only while the boost is active, so analytics can
-- count each participating player once per surge.
function WorldBeat.miningMultiplier(now: number): (number, number?)
	local phase, _, runStart = WorldBeat.phase(now)
	if phase == "active" then
		return Config.WorldBeat.miningMultiplier, runStart
	end
	return 1, nil
end

return WorldBeat
