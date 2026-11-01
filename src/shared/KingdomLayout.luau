--!strict
-- Pure geometry for the connected kingdom (#214), read from a layout table
-- such as Config.Kingdom.layout. It answers which region a point is in, how
-- high the walkable ground is there, and where safe spawn and return points
-- are. Only authored terraces and ramps count as ground: decorative props,
-- roofs, walls and the void between pieces never do.

local KingdomLayout = {}

export type Piece = {
	name: string,
	zoneId: number,
	kind: "terrace" | "ramp",
	spawns: boolean,
	requires: string?, -- obstacle id that must be open before it is walkable
	-- terrace
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	y: number,
	-- ramp
	fromX: number,
	fromZ: number,
	fromY: number,
	toX: number,
	toZ: number,
	toY: number,
	width: number,
}

local EPSILON = 1e-6

-- Flattens a layout into pieces, in list order (terraces, then ramps).
function KingdomLayout.pieces(layout: any): { Piece }
	local pieces: { Piece } = {}
	for _, t in layout.terraces do
		table.insert(pieces, {
			name = t.name,
			zoneId = t.zoneId,
			kind = "terrace",
			spawns = t.spawns ~= false,
			requires = t.requires,
			minX = t.center.X - t.size.X / 2,
			maxX = t.center.X + t.size.X / 2,
			minZ = t.center.Z - t.size.Z / 2,
			maxZ = t.center.Z + t.size.Z / 2,
			y = t.y,
			fromX = 0,
			fromZ = 0,
			fromY = 0,
			toX = 0,
			toZ = 0,
			toY = 0,
			width = 0,
		})
	end
	for _, r in layout.ramps or {} do
		table.insert(pieces, {
			name = r.name,
			zoneId = r.zoneId,
			kind = "ramp",
			spawns = false, -- nothing spawns on a slope
			requires = r.requires,
			minX = math.min(r.from.X, r.to.X),
			maxX = math.max(r.from.X, r.to.X),
			minZ = math.min(r.from.Z, r.to.Z),
			maxZ = math.max(r.from.Z, r.to.Z),
			y = math.min(r.from.Y, r.to.Y),
			fromX = r.from.X,
			fromZ = r.from.Z,
			fromY = r.from.Y,
			toX = r.to.X,
			toZ = r.to.Z,
			toY = r.to.Y,
			width = r.width,
		})
	end
	return pieces
end

-- The piece's walkable height at (x, z), or nil when the point is off it.
function KingdomLayout.heightOn(piece: Piece, x: number, z: number): number?
	if piece.kind == "terrace" then
		if
			x >= piece.minX - EPSILON
			and x <= piece.maxX + EPSILON
			and z >= piece.minZ - EPSILON
			and z <= piece.maxZ + EPSILON
		then
			return piece.y
		end
		return nil
	end
	local dx, dz = piece.toX - piece.fromX, piece.toZ - piece.fromZ
	local lengthSq = dx * dx + dz * dz
	if lengthSq < EPSILON then
		return nil
	end
	local px, pz = x - piece.fromX, z - piece.fromZ
	local t = (px * dx + pz * dz) / lengthSq
	if t < -EPSILON or t > 1 + EPSILON then
		return nil
	end
	local lateral = math.abs(px * dz - pz * dx) / math.sqrt(lengthSq)
	if lateral > piece.width / 2 + EPSILON then
		return nil
	end
	t = math.clamp(t, 0, 1)
	return piece.fromY + (piece.toY - piece.fromY) * t
end

-- The highest piece under (x, z) and its height. Ties keep list order, so
-- membership on a shared edge is deterministic.
function KingdomLayout.groundAt(pieces: { Piece }, x: number, z: number): (number?, Piece?)
	local bestY: number?, best: Piece? = nil, nil
	for _, piece in pieces do
		local y = KingdomLayout.heightOn(piece, x, z)
		if y and (bestY == nil or y > bestY + EPSILON) then
			bestY, best = y, piece
		end
	end
	return bestY, best
end

function KingdomLayout.zoneAt(pieces: { Piece }, x: number, z: number): number?
	local _, piece = KingdomLayout.groundAt(pieces, x, z)
	return if piece then piece.zoneId else nil
end

-- Every region id the layout places.
function KingdomLayout.zones(pieces: { Piece }): { [number]: boolean }
	local zones = {}
	for _, piece in pieces do
		zones[piece.zoneId] = true
	end
	return zones
end

-- The lowest walkable height anywhere: the fall check's reference surface.
function KingdomLayout.floorY(pieces: { Piece }): number
	local lowest = math.huge
	for _, piece in pieces do
		lowest = math.min(lowest, piece.y)
	end
	return lowest
end

-- A point clamped onto a terrace, `margin` inside its edges where it fits.
local function clampOnto(piece: Piece, x: number, z: number, margin: number): (number, number)
	local cx, cz = (piece.minX + piece.maxX) / 2, (piece.minZ + piece.maxZ) / 2
	local hx = math.max((piece.maxX - piece.minX) / 2 - margin, 0)
	local hz = math.max((piece.maxZ - piece.minZ) / 2 - margin, 0)
	return math.clamp(x, cx - hx, cx + hx), math.clamp(z, cz - hz, cz + hz)
end

-- The nearest point on one of a region's terraces to (x, z), `margin` in
-- from the edge. Returns x, y, z, or nil if the region has no terrace.
-- `allow`, when given, skips pieces it rejects (routes still locked).
function KingdomLayout.safePointNear(
	pieces: { Piece },
	zoneId: number,
	x: number,
	z: number,
	margin: number,
	allow: ((Piece) -> boolean)?
): (number?, number?, number?)
	local bestDistance, bx, by, bz = math.huge, nil, nil, nil
	for _, piece in pieces do
		if piece.zoneId == zoneId and piece.kind == "terrace" and (allow == nil or allow(piece)) then
			local px, pz = clampOnto(piece, x, z, margin)
			local distance = (px - x) ^ 2 + (pz - z) ^ 2
			if distance < bestDistance then
				bestDistance, bx, by, bz = distance, px, piece.y, pz
			end
		end
	end
	return bx, by, bz
end

-- An anchor's x, y, z with y read from the ground under it. Falls back to
-- the region's nearest terrace when the anchor is off its own region.
function KingdomLayout.anchor(pieces: { Piece }, layout: any, zoneId: number, kind: string): (number?, number?, number?)
	local anchors = layout.anchors[zoneId]
	local point = anchors and (anchors[kind] or anchors.spawn)
	if not point then
		return nil, nil, nil
	end
	local y, piece = KingdomLayout.groundAt(pieces, point.X, point.Z)
	if y and piece and piece.zoneId == zoneId then
		return point.X, y, point.Z
	end
	return KingdomLayout.safePointNear(pieces, zoneId, point.X, point.Z, 0)
end

-- A random spawnable point in a region, `margin` from every edge, chosen
-- by usable area. `random` returns a number in [0, 1).
function KingdomLayout.randomPoint(
	pieces: { Piece },
	zoneId: number,
	margin: number,
	random: () -> number
): (number?, number?, number?)
	local choices, total = {}, 0
	for _, piece in pieces do
		if piece.zoneId == zoneId and piece.kind == "terrace" and piece.spawns and piece.requires == nil then
			local w = math.max(piece.maxX - piece.minX - margin * 2, 0)
			local d = math.max(piece.maxZ - piece.minZ - margin * 2, 0)
			local area = math.max(w * d, EPSILON)
			total += area
			table.insert(choices, { piece = piece, weight = area })
		end
	end
	if #choices == 0 then
		return nil, nil, nil
	end
	local pick = random() * total
	local chosen = choices[#choices].piece
	for _, choice in choices do
		pick -= choice.weight
		if pick < 0 then
			chosen = choice.piece
			break
		end
	end
	local cx, cz = (chosen.minX + chosen.maxX) / 2, (chosen.minZ + chosen.maxZ) / 2
	local hx = math.max((chosen.maxX - chosen.minX) / 2 - margin, 0)
	local hz = math.max((chosen.maxZ - chosen.minZ) / 2 - margin, 0)
	return cx + (random() * 2 - 1) * hx, chosen.y, cz + (random() * 2 - 1) * hz
end

return KingdomLayout
