--!strict
-- What a player still needs before their golem can open a kingdom obstacle
-- (#216). The server's action handler and the client's prompt both call
-- this, so the prompt always names the same missing requirement the server
-- would refuse with.

local Config = require(script.Parent:WaitForChild("Config"))
local Stats = require(script.Parent:WaitForChild("Stats"))

local KingdomRules = {}

export type Status = "done" | "ready" | "locked"

function KingdomRules.obstacleDone(data: any, id: string): boolean
	local campaign = data.campaign
	return campaign ~= nil and campaign.obstacles ~= nil and campaign.obstacles[id] == true
end

-- "done", "ready" or "locked", plus the first missing requirement as a short
-- instruction ("Forge a copper arm.", "Grow to size 3.", "Beat Old Rockjaw.").
function KingdomRules.obstacleStatus(data: any, id: string): (Status, string?)
	local obstacle = Config.Kingdom.obstacles[id]
	if not obstacle then
		return "locked", "Unknown obstacle."
	end
	if KingdomRules.obstacleDone(data, id) then
		return "done", nil
	end
	if not Stats.abilityLearned(data, obstacle.ability) then
		return "locked", Config.Kingdom.abilities[obstacle.ability].forgeHint
	end
	local gate = obstacle.gate or {}
	if gate.size and Stats.sizeForLevel(Stats.levelForXp(data.golem.xp)) < gate.size then
		return "locked", `Grow to size {gate.size}.`
	end
	if gate.boss and not Stats.bossDefeated(data, gate.boss) then
		return "locked", `Beat {Config.Bosses[gate.boss].displayName}.`
	end
	return "ready", nil
end

-- Whether a layout piece is walkable for this player: either it needs no
-- obstacle, or they opened it themselves. Someone else's broken wall never
-- counts.
function KingdomRules.pieceOpen(data: any, requires: string?): boolean
	return requires == nil or KingdomRules.obstacleDone(data, requires)
end

-- The message for walking onto a piece that isn't open yet.
function KingdomRules.blockedText(requires: string): string
	local obstacle = Config.Kingdom.obstacles[requires]
	return if obstacle then `The {obstacle.name} blocks the way.` else "You can't go there yet."
end

return KingdomRules
