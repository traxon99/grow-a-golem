--!strict
-- Pure server-side validation for an optional three-tap rune challenge.
-- The client only sends rune indices; it never supplies timing or rewards.

local RuneSequence = {}

export type Session = {
	sequence: { number },
	nextIndex: number,
	expiresAt: number,
	finished: boolean,
}

function RuneSequence.new(rng: Random, now: number, duration: number): Session
	local sequence = {}
	for _ = 1, 3 do
		table.insert(sequence, rng:NextInteger(1, 3))
	end
	return {
		sequence = sequence,
		nextIndex = 1,
		expiresAt = now + duration,
		finished = false,
	}
end

-- A wrong, late, or malformed tap ends the attempt. Once finished, extra
-- packets cannot turn failure into success or grant a second reward.
function RuneSequence.press(session: Session, rune: any, now: number): string
	if session.finished then
		return "ignored"
	end
	if now > session.expiresAt then
		session.finished = true
		return "expired"
	end
	if type(rune) ~= "number" or rune % 1 ~= 0 or rune < 1 or rune > 3 or session.sequence[session.nextIndex] ~= rune then
		session.finished = true
		return "wrong"
	end
	session.nextIndex += 1
	if session.nextIndex > #session.sequence then
		session.finished = true
		return "complete"
	end
	return "next"
end

return RuneSequence
