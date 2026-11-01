-- Connected kingdom ground (#214): the authored layout's queries, and the
-- shipped layout walked end to end at the largest golem size.
do
	local K = Config.Kingdom
	local layout = K.layout
	local function near(a, b)
		return math.abs(a - b) < 1e-6
	end

	-- Every zone in the layout is a real zone (or the hub) with a spawn
	-- terrace that exists, and the spawn and boss anchors stand on it.
	for zoneId, zone in layout do
		assert(zoneId == Config.HubZone or Config.Zones[zoneId], `layout zone {zoneId} exists`)
		local terrace
		for _, area in zone.areas do
			if area.id == zone.spawnArea then
				terrace = area
			end
		end
		assert(terrace, `zone {zoneId} spawnArea names one of its areas`)
		for _, anchor in { zone.spawn, KingdomLayout.bossPoint(layout, zoneId) } do
			local found = KingdomLayout.sample(layout, anchor)
			assert(
				found and found.zoneId == zoneId and near(found.height, anchor.Y),
				`zone {zoneId} anchor on its ground`
			)
		end
	end
	-- IDs 0-6 are untouched: the layout only reinterprets existing zones.
	for id = 1, 6 do
		assert(Config.Zones[id], `zone {id} still defined`)
	end
	assert(Config.HubZone == 0)

	-- Ramps: interpolated height along the centerline, nothing past the edges
	-- or the ends, and never steeper than the clearance allows.
	local rise = layout[1].ramps[1]
	local mid = Vector3.new((rise.from.X + rise.to.X) / 2, 100, (rise.from.Z + rise.to.Z) / 2)
	local midSample = KingdomLayout.sample(layout, mid)
	assert(midSample and midSample.piece == rise.id and near(midSample.height, (rise.from.Y + rise.to.Y) / 2))
	assert(
		KingdomLayout.sample(layout, Vector3.new(mid.X, 100, mid.Z + rise.width / 2 + 1)) == nil,
		"past the ramp's side is void"
	)
	local maxSlope = math.tan(math.rad(K.clearance.maxSlopeDegrees))
	for zoneId, zone in layout do
		for _, ramp in zone.ramps or {} do
			local run = math.sqrt((ramp.to.X - ramp.from.X) ^ 2 + (ramp.to.Z - ramp.from.Z) ^ 2)
			assert(run > 0 and math.abs(ramp.to.Y - ramp.from.Y) / run <= maxSlope, `ramp {ramp.id} is walkable`)
			-- Both ends meet flat ground at the same height (no step or gap).
			for _, endpoint in { ramp.from, ramp.to } do
				local flat = false
				for _, other in layout do
					for _, area in other.areas do
						local c, s = area.center, area.size
						if
							near(c.Y, endpoint.Y)
							and math.abs(endpoint.X - c.X) <= s.X / 2 + 1e-6
							and math.abs(endpoint.Z - c.Z) <= s.Z / 2 + 1e-6
						then
							flat = true
						end
					end
				end
				assert(flat, `ramp {ramp.id} in zone {zoneId} meets a terrace at both ends`)
			end
		end
	end

	-- Height-aware: standing low on the quarry under the hub's height still
	-- answers the quarry; nothing answers over the void or far below.
	assert(KingdomLayout.zoneAt(layout, Vector3.new(0, 64, 0)) == 1)
	assert(KingdomLayout.zoneAt(layout, Vector3.new(0, 64, 400)) == nil, "off the edge is void")
	assert(KingdomLayout.zoneAt(layout, Vector3.new(0, 20, 0)) == nil, "far under the terrace is not on it")
	assert(KingdomLayout.groundHeight(layout, Vector3.new(0, 20, 0)) == nil)
	assert(KingdomLayout.sample(layout, Vector3.new(0, 20, 0), true).height == 60, "anyHeight ignores Y")

	-- A seam shared by two zones resolves the same way every time.
	local seam = Vector3.new(rise.to.X, rise.to.Y + 2, rise.to.Z)
	local first = KingdomLayout.zoneAt(layout, seam)
	for _ = 1, 5 do
		assert(KingdomLayout.zoneAt(layout, seam) == first, "seams are deterministic")
	end

	-- The fall plane sits under every piece of each zone.
	assert(KingdomLayout.lowestSurface(layout, 1) == 60)
	assert(KingdomLayout.lowestSurface(layout, Config.HubZone) == 68)

	-- Random spawn points: on the spawn terrace, inside the margin, never on
	-- a plot boundary.
	local seed = 7
	local function random()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	for zoneId, zone in layout do
		for _ = 1, 200 do
			local point = KingdomLayout.randomPoint(layout, zoneId, 12, random)
			local found = KingdomLayout.sample(layout, point)
			assert(found and found.zoneId == zoneId and found.piece == zone.spawnArea, "random point on the terrace")
			for _, box in zone.exclude or {} do
				local insideX = math.abs(point.X - box.center.X) <= box.size.X / 2 + 12
				local insideZ = math.abs(point.Z - box.center.Z) <= box.size.Z / 2 + 12
				assert(not (insideX and insideZ), "random points avoid plot boundaries")
			end
		end
	end

	-- Safe points: nearest flat ground in that zone, never a ramp or plot.
	local plot = layout[Config.HubZone].exclude[1]
	local onPlot = KingdomLayout.safePoint(layout, Config.HubZone, plot.center, 4)
	local clearX = math.abs(onPlot.X - plot.center.X) > plot.size.X / 2 + 3.9
	local clearZ = math.abs(onPlot.Z - plot.center.Z) > plot.size.Z / 2 + 3.9
	assert(clearX or clearZ, "a plot is never a safe point")
	local offRamp = KingdomLayout.safePoint(layout, 1, mid, 4)
	local offRampSample = KingdomLayout.sample(layout, offRamp)
	assert(offRampSample and offRampSample.piece ~= rise.id, "ramps are never safe points")
	assert(offRampSample.zoneId == 1)
	local overVoid = KingdomLayout.safePoint(layout, 1, Vector3.new(0, 60, 900), 10)
	assert(overVoid.Z <= 160 - 10 + 1e-6 and overVoid.Y == 60, "the void clamps to the nearest edge, inside the margin")
	local inside = KingdomLayout.safePoint(layout, 1, Vector3.new(10, 60, 10), 10)
	assert(inside.X == 10 and inside.Z == 10, "a safe point stays put")

	-- The first route: no gap, no step and no slope too steep anywhere on it,
	-- with room either side for the largest golem and a dismounted rider.
	local maxScale = 1 + Config.SizeScaleStep * (#Config.SizeLevels - 1)
	local riderReach = math.max(K.clearance.golemWidth * maxScale / 2, Config.Golem.dismountOffset * maxScale)
	local halfLane = riderReach + K.clearance.edgeMargin
	local route = K.firstRoute
	assert(KingdomLayout.zoneAt(layout, route[1]) == 1, "the route starts in the quarry")
	assert(KingdomLayout.zoneAt(layout, route[#route]) == Config.HubZone, "and ends in the hub")
	local zonesSeen = {}
	for index = 1, #route - 1 do
		local a, b = route[index], route[index + 1]
		local dx, dz = b.X - a.X, b.Z - a.Z
		local length = math.sqrt(dx * dx + dz * dz)
		local ux, uz = dx / length, dz / length
		for _, side in { -halfLane, 0, halfLane } do
			local lastHeight = nil
			local steps = math.ceil(length / 2)
			for step = 0, steps do
				local t = step / steps
				local x = a.X + dx * t - uz * side
				local z = a.Z + dz * t + ux * side
				local found = KingdomLayout.sample(layout, Vector3.new(x, 200, z), true)
				assert(found, `route gap at ({x}, {z})`)
				if side == 0 then
					zonesSeen[found.zoneId] = true
				end
				if lastHeight then
					-- 2-stud samples: the rise allowed by the slope limit, plus rounding.
					assert(math.abs(found.height - lastHeight) <= 2 * maxSlope + 1e-6, `route step at ({x}, {z})`)
				end
				lastHeight = found.height
			end
		end
	end
	assert(zonesSeen[1] and zonesSeen[Config.HubZone], "the route crosses from the quarry into the hub on foot")

	print("kingdom-layout: ok")
end
