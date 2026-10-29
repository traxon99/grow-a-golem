-- The same pure RuneSequence module the live server uses.
do
	local rng = Random.new(42)
	local s = RuneSequence.new(rng, 100, 8)
	assert(#s.sequence == 3 and s.nextIndex == 1)
	for i = 1, 2 do
		assert(RuneSequence.press(s, s.sequence[i], 100 + i) == "next")
		assert(s.nextIndex == i + 1)
	end
	assert(RuneSequence.press(s, s.sequence[3], 108) == "complete")
	assert(s.finished)
	assert(RuneSequence.press(s, s.sequence[3], 108) == "ignored")

	local late = RuneSequence.new(rng, 20, 8)
	assert(RuneSequence.press(late, late.sequence[1], 28.001) == "expired")
	assert(RuneSequence.press(late, late.sequence[1], 27) == "ignored")

	local wrong = RuneSequence.new(rng, 30, 8)
	local different = (wrong.sequence[1] % 3) + 1
	assert(RuneSequence.press(wrong, different, 31) == "wrong")
	assert(RuneSequence.press(wrong, wrong.sequence[1], 32) == "ignored")

	for _, bad in { "1", 0, 4, 1.5, -1 } do
		local attempt = RuneSequence.new(rng, 40, 8)
		assert(RuneSequence.press(attempt, bad, 41) == "wrong")
	end

	local atBoundary = RuneSequence.new(rng, 50, 8)
	assert(RuneSequence.press(atBoundary, atBoundary.sequence[1], 58) == "next")
	print("rune-sequence: ok")
end
