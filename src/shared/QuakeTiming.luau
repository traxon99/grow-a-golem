--!strict
-- Pure timing rules for Quake's optional second press. The server supplies
-- elapsed time from its own clock; clients never report a timestamp.

local QuakeTiming = {}

export type Attempt = {
	attempted: boolean,
	perfect: boolean,
}

function QuakeTiming.isPerfect(elapsed: number, windup: number, lead: number, halfWindow: number): boolean
	if elapsed < 0 or windup <= 0 or lead <= 0 or halfWindow <= 0 then
		return false
	end
	local target = windup - lead
	return elapsed >= target - halfWindow and elapsed <= target + halfWindow and elapsed < windup
end

-- The first follow-up press is final, even if it was too early. Repeated
-- packets cannot fish for a better grade or alter an already-graded cast.
function QuakeTiming.press(
	attempt: Attempt,
	elapsed: number,
	windup: number,
	lead: number,
	halfWindow: number
): boolean?
	if attempt.attempted then
		return nil
	end
	attempt.attempted = true
	attempt.perfect = QuakeTiming.isPerfect(elapsed, windup, lead, halfWindow)
	return attempt.perfect
end

return QuakeTiming
