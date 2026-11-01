--!strict
-- Pure ground queries for the connected kingdom (#214). The ground is only
-- what Config.Kingdom.layout authors: flat areas and straight ramps. Walls,
-- roofs, props and the void between pieces never count, so these answers
-- don't depend on raycasts or on what art sits on top. Plot boundaries
-- (`exclude` boxes) are ground you can stand on but never a safe point.
--
-- Every answer is deterministic: zones are scanned in ascending id order and
-- pieces in the order the layout lists them, so a point on a seam always
-- resolves to the same zone.

local KingdomLayout = {}

export type Area = { id: string, center: Vector3, size: Vector3 }
export type Ramp = { id: string, from: Vector3, to: Vector3, width: number, thickness: number }
export type Box = { id: string, center: Vector3, size: Vector3 }
export type Zone = {
	spawn: Vector3,
	boss: Vector3?,
	spawnArea: string,
	areas: { Area },
	ramps: { Ramp }?,
	exclude: { Box }?,
}
export type Layout = { [number]: Zone }
export type Sample = { zoneId: number, height: number, piece: string }

-- How far above the given height a surface may be and still count as the
-- ground under it (a step up a seam or a ramp).
KingdomLayout.STEP_UP = 3

local NO_RAMPS: { Ramp } = {}
local NO_BOXES: { Box } = {}

function KingdomLayout.rampsOf(zone: Zone): { Ramp }
	return zone.ramps or NO_RAMPS
end

function KingdomLayout.excludesOf(zone: Zone): { Box }
	return zone.exclude or NO_BOXES
end

local function sortedIds(layout: Layout): { number }
	local ids = {}
	for id in layout do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

local function inBox(center: Vector3, size: Vector3, x: number, z: number, margin: number): boolean
	return math.abs(x - center.X) <= size.X / 2 - margin and math.abs(z - center.Z) <= size.Z / 2 - margin
end

-- Surface height of a ramp at (x, z), or nil off it.
local function rampHeight(ramp: Ramp, x: number, z: number): number?
	local dx, dz = ramp.to.X - ramp.from.X, ramp.to.Z - ramp.from.Z
	local length2 = dx * dx + dz * dz
	if length2 <= 0 then
		return nil
	end
	local px, pz = x - ramp.from.X, z - ramp.from.Z
	local t = (px * dx + pz * dz) / length2
	if t < 0 or t > 1 then
		return nil
	end
	local lateral = math.abs(px * dz - pz * dx) / math.sqrt(length2)
	if lateral > ramp.width / 2 then
		return nil
	end
	return ramp.from.Y + (ramp.to.Y - ramp.from.Y) * t
end

-- The authored ground under `position`. With `position.Y` known, the highest
-- surface at or below Y + STEP_UP wins (so a ramp's top isn't confused with
-- a lower terrace); `anyHeight` ignores Y and takes the highest surface.
function KingdomLayout.sample(layout: Layout, position: Vector3, anyHeight: boolean?): Sample?
	local best: Sample? = nil
	local limit = position.Y + KingdomLayout.STEP_UP
	local function consider(zoneId: number, height: number, piece: string)
		if not anyHeight and height > limit then
			return
		end
		if best == nil or height > best.height then
			best = { zoneId = zoneId, height = height, piece = piece }
		end
	end
	for _, zoneId in sortedIds(layout) do
		local zone = layout[zoneId]
		for _, area in zone.areas do
			if inBox(area.center, area.size, position.X, position.Z, 0) then
				consider(zoneId, area.center.Y, area.id)
			end
		end
		for _, ramp in KingdomLayout.rampsOf(zone) do
			local height = rampHeight(ramp, position.X, position.Z)
			if height then
				consider(zoneId, height, ramp.id)
			end
		end
	end
	return best
end

function KingdomLayout.zoneAt(layout: Layout, position: Vector3): number?
	local found = KingdomLayout.sample(layout, position)
	return if found then found.zoneId else nil
end

function KingdomLayout.groundHeight(layout: Layout, position: Vector3): number?
	local found = KingdomLayout.sample(layout, position)
	return if found then found.height else nil
end

-- The lowest walkable height in a zone; the fall plane sits below it.
function KingdomLayout.lowestSurface(layout: Layout, zoneId: number): number
	local zone = layout[zoneId]
	local lowest = math.huge
	for _, area in zone.areas do
		lowest = math.min(lowest, area.center.Y)
	end
	for _, ramp in KingdomLayout.rampsOf(zone) do
		lowest = math.min(lowest, ramp.from.Y, ramp.to.Y)
	end
	return lowest
end

local function findArea(zone: Zone, id: string): Area?
	for _, area in zone.areas do
		if area.id == id then
			return area
		end
	end
	return nil
end

local function excluded(zone: Zone, x: number, z: number, margin: number): boolean
	for _, box in KingdomLayout.excludesOf(zone) do
		if inBox(box.center, box.size, x, z, -margin) then
			return true
		end
	end
	return false
end

function KingdomLayout.spawnPoint(layout: Layout, zoneId: number): Vector3
	return layout[zoneId].spawn
end

-- The authored boss anchor, or the spawn terrace's far corner like islands.
function KingdomLayout.bossPoint(layout: Layout, zoneId: number): Vector3
	local zone = layout[zoneId]
	if zone.boss then
		return zone.boss
	end
	local area = findArea(zone, zone.spawnArea)
	if not area then
		return zone.spawn
	end
	return Vector3.new(area.center.X + area.size.X * 0.32, area.center.Y, area.center.Z - area.size.Z * 0.32)
end

-- A random spot on the zone's spawn terrace, `margin` in from its edges and
-- clear of every exclude box. `random` returns [0, 1) like math.random().
function KingdomLayout.randomPoint(layout: Layout, zoneId: number, margin: number, random: () -> number): Vector3
	local zone = layout[zoneId]
	local area = findArea(zone, zone.spawnArea)
	if not area then
		return zone.spawn
	end
	local halfX = math.max(area.size.X / 2 - margin, 0)
	local halfZ = math.max(area.size.Z / 2 - margin, 0)
	for _ = 1, 12 do
		local x = area.center.X + (random() * 2 - 1) * halfX
		local z = area.center.Z + (random() * 2 - 1) * halfZ
		if not excluded(zone, x, z, margin) then
			return Vector3.new(x, area.center.Y, z)
		end
	end
	return zone.spawn
end

-- The nearest point to `position` on one of the zone's flat areas, `margin`
-- in from the edge and outside every exclude box. Ramps are never used, so
-- a golem is never placed on a slope. Falls back to the zone's spawn.
function KingdomLayout.safePoint(layout: Layout, zoneId: number, position: Vector3, margin: number): Vector3
	local zone = layout[zoneId]
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, area in zone.areas do
		local halfX = math.max(area.size.X / 2 - margin, 0)
		local halfZ = math.max(area.size.Z / 2 - margin, 0)
		local x = math.clamp(position.X, area.center.X - halfX, area.center.X + halfX)
		local z = math.clamp(position.Z, area.center.Z - halfZ, area.center.Z + halfZ)
		if excluded(zone, x, z, margin) then
			continue
		end
		local distance = (x - position.X) ^ 2 + (z - position.Z) ^ 2
		if distance < bestDistance then
			bestDistance = distance
			best = Vector3.new(x, area.center.Y, z)
		end
	end
	return best or zone.spawn
end

return KingdomLayout
