--!strict
-- Pure server-side geometry and checkpoint rules for the optional Golem Run.
-- Client input never advances checkpoints or determines mineral payouts.

local GauntletRules = {}

function GauntletRules.nearXZ(a: Vector3, b: Vector3, radius: number): boolean
	if radius <= 0 then
		return false
	end
	local dx, dz = a.X - b.X, a.Z - b.Z
	return dx * dx + dz * dz <= radius * radius
end

function GauntletRules.inCheckpoint(position: Vector3, center: Vector3, halfWidth: number, halfDepth: number): boolean
	return halfWidth > 0
		and halfDepth > 0
		and math.abs(position.X - center.X) <= halfWidth
		and math.abs(position.Z - center.Z) <= halfDepth
end

-- A lava strip has a visible, safe opening. Only the golem's ground-plane
-- center counts, so large cosmetic/level models don't get unfair hitboxes.
function GauntletRules.inLava(position: Vector3, centerZ: number, gapX: number, halfDepth: number, gapHalfWidth: number): boolean
	return math.abs(position.Z - centerZ) <= halfDepth
		and math.abs(position.X - gapX) > gapHalfWidth
end

function GauntletRules.canClaim(
	nextIndex: number,
	index: number,
	position: Vector3,
	center: Vector3,
	halfWidth: number,
	halfDepth: number,
	now: number,
	expiresAt: number
): boolean
	return nextIndex == index
		and now <= expiresAt
		and GauntletRules.inCheckpoint(position, center, halfWidth, halfDepth)
end

return GauntletRules
