-- Server-owned geometry, sequential progress and fixed reward configuration.
local run = Config.Gauntlet
assert(run.durationSeconds >= 60 and run.cooldownSeconds >= run.durationSeconds)
assert(#run.checkpoints == 3)
local near = GauntletRules.nearXZ
local cp = GauntletRules.inCheckpoint
local lava = GauntletRules.inLava
local point = Vector3.new(0, 60, 0)
assert(near(point, Vector3.new(3, 60, 4), 5))
assert(not near(point, Vector3.new(3, 60, 4.01), 5))
assert(not near(point, point, 0))
assert(cp(point, point, 8, 5))
assert(cp(Vector3.new(8, 60, 5), point, 8, 5))
assert(not cp(Vector3.new(8.01, 60, 0), point, 8, 5))
assert(not cp(point, point, 0, 5))
assert(lava(Vector3.new(-15, 60, 10), 10, 12, 5, 9))
assert(not lava(Vector3.new(12, 60, 10), 10, 12, 5, 9))
assert(not lava(Vector3.new(-15, 60, 15.01), 10, 12, 5, 9))
assert(GauntletRules.canClaim(1, 1, point, point, 8, 5, 90, 90))
assert(not GauntletRules.canClaim(2, 1, point, point, 8, 5, 90, 90))
assert(not GauntletRules.canClaim(1, 1, point, point, 8, 5, 90.01, 90))
assert(not GauntletRules.canClaim(1, 1, Vector3.new(20, 60, 0), point, 8, 5, 80, 90))
for _, checkpoint in run.checkpoints do
	assert(checkpoint.reward.stone > 0, "every checkpoint has a fixed stone reward")
end
assert(run.checkpoints[1].reward.stone == 50)
assert(run.checkpoints[2].reward.copper == 5)
assert(run.checkpoints[3].reward.copper == 10)
print("gauntlet-rules: checkpoint order, deadlines, hazard gaps and rewards passed")
