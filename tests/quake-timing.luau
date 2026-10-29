-- Pure server timing rules, including inclusive boundaries and one attempt.
local spell = Config.Spells.quake
local windup, lead, window = spell.windup, spell.timingLead, spell.timingWindow
assert(windup == 0.9 and spell.perfectMultiplier == 1.5)
assert(lead > window and windup > lead + window)

local target = windup - lead
assert(QuakeTiming.isPerfect(target, windup, lead, window))
assert(QuakeTiming.isPerfect(target - window, windup, lead, window))
assert(QuakeTiming.isPerfect(target + window, windup, lead, window))
assert(not QuakeTiming.isPerfect(target - window - 0.01, windup, lead, window))
assert(not QuakeTiming.isPerfect(target + window + 0.01, windup, lead, window))
assert(not QuakeTiming.isPerfect(-1, windup, lead, window))
assert(not QuakeTiming.isPerfect(windup, windup, lead, window))

local early = { attempted = false, perfect = false }
assert(QuakeTiming.press(early, 0.01, windup, lead, window) == false)
assert(QuakeTiming.press(early, target, windup, lead, window) == nil)
assert(early.attempted and not early.perfect, "early press consumes the one chance")

local perfect = { attempted = false, perfect = false }
assert(QuakeTiming.press(perfect, target, windup, lead, window) == true)
assert(QuakeTiming.press(perfect, 0, windup, lead, window) == nil)
assert(perfect.perfect, "duplicates cannot undo a perfect press")

local skipped = { attempted = false, perfect = false }
assert(not skipped.attempted and not skipped.perfect, "skipping preserves normal Quake damage")
print("quake-timing: boundaries, skipped casts and one-shot grading passed")
