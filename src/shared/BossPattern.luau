--!strict
-- Flat, server-authoritative boss attack footprints. The warning marker and
-- the damage check use the same origin, direction and dimensions.

local BossPattern = {}

export type Pattern = {
	kind: string,
	radius: number?,
	width: number?,
	length: number?,
	offset: number?,
}

function BossPattern.direction(from: Vector3, toward: Vector3): Vector3
	local dx = toward.X - from.X
	local dz = toward.Z - from.Z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.001 then
		return Vector3.new(0, 0, -1)
	end
	return Vector3.new(dx / length, 0, dz / length)
end

function BossPattern.center(pattern: Pattern, origin: Vector3, direction: Vector3): Vector3
	if pattern.kind == "circle" then
		return origin
	end
	return origin + direction * (pattern.offset or 0)
end

function BossPattern.hits(pattern: Pattern, origin: Vector3, direction: Vector3, point: Vector3): boolean
	local dx = point.X - origin.X
	local dz = point.Z - origin.Z
	if pattern.kind == "circle" then
		local radius = pattern.radius or 0
		return dx * dx + dz * dz <= radius * radius
	end
	if pattern.kind ~= "line" and pattern.kind ~= "sweep" then
		return false
	end
	local forward = dx * direction.X + dz * direction.Z - (pattern.offset or 0)
	local sideways = -dx * direction.Z + dz * direction.X
	return math.abs(forward) <= (pattern.length or 0) / 2 and math.abs(sideways) <= (pattern.width or 0) / 2
end

return BossPattern
