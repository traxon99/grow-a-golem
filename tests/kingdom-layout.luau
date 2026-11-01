-- KingdomLayout (#214): the connected graybox route in Config.Kingdom.layout.
do
	local layout = Config.Kingdom.layout
	local pieces = KingdomLayout.pieces(layout)

	-- The quarry, the road, the sanctuary approach and the hub are all here.
	local zones = KingdomLayout.zones(pieces)
	assert(zones[1] and zones[Config.HubZone], "the first route covers the quarry and the hub")
	for zoneId in zones do
		assert(zoneId == Config.HubZone or Config.Zones[zoneId], "regions keep their existing ids")
	end

	-- Walk the authored route from the quarry spawn to the hub spawn in small
	-- steps: ground is under every step and no step is a cliff or a gap.
	local route = {
		{ 0, -1420 },
		{ 0, -1500 },
		{ -160, -1500 },
		{ -260, -1500 },
		{ -400, -1500 },
		{ -480, -1500 },
		{ -480, -1420 },
		{ -480, -1300 },
	}
	local lastY = nil
	local seen = {}
	for index = 1, #route - 1 do
		local ax, az = route[index][1], route[index][2]
		local bx, bz = route[index + 1][1], route[index + 1][2]
		for step = 0, 40 do
			local t = step / 40
			local x, z = ax + (bx - ax) * t, az + (bz - az) * t
			local y, piece = KingdomLayout.groundAt(pieces, x, z)
			assert(y and piece, `no ground at {x}, {z}`)
			seen[piece.name] = true
			if lastY then
				assert(math.abs(y - lastY) <= 1, `step at {x}, {z} jumps {y - lastY} studs`)
			end
			lastY = y
		end
	end
	for _, name in { "Mossy Quarry", "Quarry Ramp", "Quarry Road", "Sanctuary Approach", "Golem Hub" } do
		assert(seen[name], `route crosses {name}`)
	end

	-- Membership and height, including the ramp's slope and shared edges.
	assert(KingdomLayout.zoneAt(pieces, 0, -1500) == 1)
	assert(KingdomLayout.zoneAt(pieces, -480, -1300) == Config.HubZone)
	local rampY = KingdomLayout.groundAt(pieces, -210, -1500)
	assert(rampY and math.abs(rampY - 66) < 1e-6, "halfway up the ramp is halfway between its ends")
	local edgeY, edge = KingdomLayout.groundAt(pieces, -480, -1420)
	assert(edgeY == 72 and edge and edge.name == "Sanctuary Approach", "a shared edge resolves by list order")
	local quarryEdge, quarryPiece = KingdomLayout.groundAt(pieces, -160, -1500)
	assert(quarryEdge == 60 and quarryPiece and quarryPiece.zoneId == 1)
	-- The void beside the road, past the quarry and beyond the ramp's sides.
	assert(KingdomLayout.groundAt(pieces, -330, -1600) == nil, "no ground beside the road")
	assert(KingdomLayout.groundAt(pieces, 400, -1500) == nil)
	assert(KingdomLayout.groundAt(pieces, -210, -1500 + 33) == nil, "the ramp is only its lane wide")
	assert(KingdomLayout.zoneAt(pieces, 0, 0) == nil, "the legacy island area is not kingdom ground")
	assert(KingdomLayout.floorY(pieces) == 60)

	-- Anchors stand on their own region's ground.
	local sx, sy, sz = KingdomLayout.anchor(pieces, layout, 1, "spawn")
	assert(sx == 0 and sy == 60 and sz == -1420)
	local bx, by, bz = KingdomLayout.anchor(pieces, layout, 1, "boss")
	assert(bx == 100 and by == 60 and bz == -1600)
	local hx, hy = KingdomLayout.anchor(pieces, layout, Config.HubZone, "boss")
	assert(hx == -480 and hy == 72, "a missing boss anchor falls back to the spawn anchor")
	assert(KingdomLayout.anchor(pieces, layout, 6, "spawn") == nil)
	local fakeLayout = { anchors = { [1] = { spawn = Vector3.new(-480, 0, -1300) } } }
	local fx, fy, fz = KingdomLayout.anchor(pieces, fakeLayout, 1, "spawn")
	assert(fx and KingdomLayout.zoneAt(pieces, fx, fz) == 1 and fy == 72, "an off-region anchor moves onto its region")

	-- Random points stay on spawnable terraces, `margin` from their edges:
	-- never the road, the ramp or the sanctuary approach.
	local seed = 7
	local function random()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	for _ = 1, 200 do
		local x, y, z = KingdomLayout.randomPoint(pieces, 1, 16, random)
		assert(x and y == 60 and z)
		assert(x >= -144 and x <= 144 and z >= -1644 and z <= -1356, "inside the quarry, 16 studs from its edge")
	end
	for _ = 1, 50 do
		local x, _, z = KingdomLayout.randomPoint(pieces, Config.HubZone, 10, random)
		assert(KingdomLayout.zoneAt(pieces, x, z) == Config.HubZone)
	end
	assert(KingdomLayout.randomPoint(pieces, 2, 10, random) == nil)

	-- Safe points: the nearest spot of a region, margin in from its edge.
	local px, py, pz = KingdomLayout.safePointNear(pieces, 1, -480, -1300, 12)
	assert(px == -480 and py == 72 and pz == -1432, "from the hub, the nearest quarry-region spot is the approach")
	local qx, _, qz = KingdomLayout.safePointNear(pieces, 1, 500, -1500, 12)
	assert(qx == 148 and qz == -1500)
	assert(KingdomLayout.safePointNear(pieces, 5, 0, 0, 12) == nil)

	-- Roads and ramps fit the largest golem with room to turn: twice its
	-- dismount reach (about its width) at max size, with half again spare.
	local maxScale = Stats.scaleForSize(#Config.SizeLevels)
	local footprint = 2 * Config.Golem.dismountOffset * maxScale
	assert(layout.minLaneWidth >= footprint * 1.5, "minLaneWidth fits the largest golem")
	for _, ramp in layout.ramps do
		assert(ramp.width >= layout.minLaneWidth, ramp.name)
	end
	for _, terrace in layout.terraces do
		assert(math.min(terrace.size.X, terrace.size.Z) >= layout.minLaneWidth, terrace.name)
	end

	-- The route sits clear of every legacy island, the hub island, the tower
	-- arenas and the Golem Run, so their membership answers don't change.
	local function overlaps(center, size)
		for _, piece in pieces do
			if
				piece.maxX >= center.X - size.X / 2
				and piece.minX <= center.X + size.X / 2
				and piece.maxZ >= center.Z - size.Z / 2
				and piece.minZ <= center.Z + size.Z / 2
			then
				return true
			end
		end
		return false
	end
	for id, zone in Config.Zones do
		assert(not overlaps(zone.center, zone.size), `kingdom overlaps island {id}`)
	end
	assert(not overlaps(Config.Hub.center, Config.Hub.size))
	for index = 1, Config.Tower.arenas do
		local center = Config.Tower.arenaOrigin + Vector3.new((index - 1) * Config.Tower.arenaSpacing, 0, 0)
		assert(not overlaps(center, Config.Tower.arenaSize), "kingdom overlaps a tower arena")
	end
	assert(not overlaps(Config.Gauntlet.center, Config.Gauntlet.arenaSize))

	print("kingdom-layout: ok")
end
