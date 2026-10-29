-- Boss warning footprints must agree with the damage predicate, including
-- edges, rotated directions, and the safe space beside a narrow lane.
local origin = Vector3.new(0, 60, 0)
local east = BossPattern.direction(origin, Vector3.new(20, 60, 0))
assert(math.abs(east.X - 1) < 0.0001 and math.abs(east.Z) < 0.0001)
local fallback = BossPattern.direction(origin, origin)
assert(fallback.Z == -1)

local circle = { kind = "circle", radius = 14 }
assert(BossPattern.hits(circle, origin, east, Vector3.new(14, 500, 0)))
assert(not BossPattern.hits(circle, origin, east, Vector3.new(14.1, 60, 0)))
assert(BossPattern.center(circle, origin, east).X == 0)

local lane = { kind = "line", length = 35, width = 8, offset = 17.5 }
local center = BossPattern.center(lane, origin, east)
assert(math.abs(center.X - 17.5) < 0.0001)
assert(BossPattern.hits(lane, origin, east, Vector3.new(30, 60, 4)))
assert(not BossPattern.hits(lane, origin, east, Vector3.new(30, 60, 4.1)))
assert(not BossPattern.hits(lane, origin, east, Vector3.new(-1, 60, 0)))
assert(not BossPattern.hits(lane, origin, east, Vector3.new(36, 60, 0)))

local sweep = { kind = "sweep", length = 10, width = 30, offset = 7 }
assert(BossPattern.hits(sweep, origin, east, Vector3.new(7, 60, 14)))
assert(not BossPattern.hits(sweep, origin, east, Vector3.new(7, 60, 16)))
assert(not BossPattern.hits(sweep, origin, east, Vector3.new(14, 60, 0)))
assert(not BossPattern.hits({ kind = "unknown" }, origin, east, origin))

-- All six island bosses cycle through the three visibly different attacks.
for _, boss in Config.Bosses do
	local patterns = boss.slam.patterns
	assert(#patterns == 3)
	assert(patterns[1].kind == "circle" and patterns[1].radius == boss.slam.radius)
	assert(patterns[2].kind == "line" and patterns[3].kind == "sweep")
	assert(patterns[2].length > patterns[3].length)
	assert(patterns[3].width > patterns[2].width)
end
print("Boss attack geometry and six-boss pattern configuration checks passed")
