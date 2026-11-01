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

-- With the kingdom on (#214), its regions answer from the layout; arenas
-- and other islands keep their own ground.
do
	local built = 0
	local world = loadWorldService({
		Config = Config,
		Islands = {},
		KingdomLayout = KingdomLayout,
		Kingdom = {
			build = function()
				built += 1
			end,
		},
	}, {
		GetService = function()
			return {
				WaitForChild = function()
					return {}
				end,
			}
		end,
	})
	world.addArena(150, Vector3.new(0, 60, 1200), Vector3.new(120, 6, 120), "Arena")
	assert(not world.isKingdomZone(1))
	world.useKingdom(Config.Kingdom.layout)
	assert(built == 1 and world.isKingdomZone(1) and world.isKingdomZone(Config.HubZone))
	assert(not world.isKingdomZone(2) and not world.isKingdomZone(150))
	local spawn = world.getSpawnPoint(1)
	assert(spawn.X == 0 and spawn.Y == 60 and spawn.Z == -1420)
	local hub = world.getSpawnPoint(Config.HubZone)
	assert(hub.X == -480 and hub.Y == 72)
	local boss = world.getBossPoint(1)
	assert(boss.X == 100 and boss.Z == -1600)
	assert(world.getSurfaceY(1) == 60 and world.getSurfaceY(Config.HubZone) == 60, "fall check uses the lowest ground")
	assert(world.zoneAt(Vector3.new(-480, 72, -1300)) == Config.HubZone)
	assert(world.zoneAt(Vector3.new(-330, 72, -1600)) == nil, "the void is no zone")
	for _ = 1, 30 do
		local point = world.randomPoint(1, 16)
		assert(point.Y == 60 and world.zoneAt(point) == 1)
	end
	-- Arenas still answer from their own ground.
	assert(world.zoneAt(Vector3.new(0, 60, 1200)) == 150 and world.getSurfaceY(150) == 60)
	local back = world.safePointNear(1, Vector3.new(-480, 72, -1300), 12)
	assert(back.X == -480 and back.Z == -1432 and back.Y == 72)
	local arenaBack = world.safePointNear(150, Vector3.new(999, 0, 999), 12)
	assert(arenaBack.X == 0 and arenaBack.Z == 1200, "outside the kingdom, the safe point is the spawn")
	-- Straight walks: along the road is grounded, cutting the corner from the
	-- quarry spawn to the approach crosses the void.
	assert(world.groundedPath(Vector3.new(0, 60, -1500), Vector3.new(-480, 72, -1500)))
	assert(not world.groundedPath(Vector3.new(0, 60, -1420), Vector3.new(-480, 72, -1450)))
	assert(world.groundedPath(Vector3.new(0, 60, 1200), Vector3.new(10, 60, 1210)), "arena walks are not checked")
	print("world-service kingdom: ok")
end
