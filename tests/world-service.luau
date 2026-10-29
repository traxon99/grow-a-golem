-- WorldService's pure geometry helpers, reached through the real
-- WorldService.addArena (itself needs only a bare Instance.new and a
-- workspace stand-in, since every field it sets is a plain write and no
-- method is ever called on the result).
--
-- Out of scope here: WorldService.start() -- building the real islands,
-- lighting/atmosphere setup, Islands.decorate scenery, and spawn placement
-- via workspace:GetDescendants() -- which needs Roblox Instance behavior
-- (FindFirstChildOfClass, real GetDescendants, SpawnLocation) well beyond
-- what this harness shims, for comparatively little testable logic.
do
	local world = loadWorldService({
		Config = Config,
		Islands = {},
	}, {
		GetService = function()
			return {
				WaitForChild = function()
					return {}
				end,
			}
		end,
	})

	local center = Vector3.new(500, 60, 0)
	local size = Vector3.new(80, 6, 40)
	world.addArena(101, center, size, "Test Arena")

	-- The ground part's Position is `center` shifted down by half its
	-- height, so getSurfaceY (Position.Y + Size.Y / 2) comes back to
	-- exactly center.Y, and getSpawnPoint's X/Z pass through unchanged.
	assert(world.getSurfaceY(101) == center.Y)
	local spawn = world.getSpawnPoint(101)
	assert(spawn.X == center.X and spawn.Y == center.Y and spawn.Z == center.Z)

	local boss = world.getBossPoint(101)
	assert(
		boss.X == center.X + size.X * 0.32 and boss.Z == center.Z - size.Z * 0.32 and boss.Y == center.Y,
		"the boss point sits in the far corner, away from the spawn, at surface height"
	)

	assert(world.zoneAt(spawn) == 101, "a point over the arena's footprint resolves to its zone")
	assert(
		world.zoneAt(Vector3.new(center.X, center.Y, center.Z + size.Z)) == nil,
		"a point outside the footprint in Z resolves to nothing"
	)
	assert(
		world.zoneAt(Vector3.new(center.X + size.X, center.Y, center.Z)) == nil,
		"a point outside the footprint in X resolves to nothing"
	)

	-- addArena guards on an already-built zone id; a second call with
	-- different center/size/name changes nothing.
	world.addArena(101, Vector3.new(-999, 1, -999), Vector3.new(1, 1, 1), "ignored")
	local spawnAgain = world.getSpawnPoint(101)
	assert(
		spawnAgain.X == center.X and spawnAgain.Y == center.Y and spawnAgain.Z == center.Z,
		"addArena for an already-built zone id is a no-op"
	)

	-- A second, distinct zone for randomPoint, which must stay clear of
	-- `margin` on every side and land at surface height.
	local center2 = Vector3.new(0, 20, 0)
	local size2 = Vector3.new(100, 4, 100)
	world.addArena(102, center2, size2, "Second Arena")
	local margin = 10
	local halfExtent = size2.X / 2 - margin -- same for X and Z: size2 is square
	for _ = 1, 20 do
		local point = world.randomPoint(102, margin)
		assert(point.Y == center2.Y, "randomPoint sits at the zone's surface height")
		assert(math.abs(point.X - center2.X) <= halfExtent + 1e-9, "randomPoint stays within the margin in X")
		assert(math.abs(point.Z - center2.Z) <= halfExtent + 1e-9, "randomPoint stays within the margin in Z")
	end

	-- A margin at or beyond half the footprint clamps the usable half-extent
	-- to 0, collapsing every point to exactly the zone's center.
	local collapsed = world.randomPoint(102, size2.X / 2 + 50)
	assert(
		collapsed.X == center2.X and collapsed.Z == center2.Z,
		"a margin covering the whole footprint collapses randomPoint to the center"
	)

	print("world-service: ok")
end
