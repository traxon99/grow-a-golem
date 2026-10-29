--!strict
-- Gameplay rewards go through here so every multiplier is applied in one
-- place: golem stats (skills, artifacts, passes, boosts), the party friend
-- bonus, and the Magnet spell.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldBeat = require(Shared:WaitForChild("WorldBeat"))

local DataService = require(script.Parent.DataService)
local GolemService = require(script.Parent.GolemService)
local PartyService = require(script.Parent.PartyService)
local Events = require(script.Parent.Events)

local EconomyService = {}

export type Reward = {
	minerals: { [string]: number }?,
	xp: number?,
}

function EconomyService.mineralMultiplier(player: Player): number
	local golem = GolemService.get(player)
	local mult = if golem then golem.stats.mineralMult else 1
	mult *= 1 + PartyService.friendBonus(player) / 100
	if golem and golem.magnetUntil > os.clock() then
		mult *= 1 + Config.Spells.magnet.mineralBonus
	end
	return mult
end

-- Grants a reward with multipliers. Returns what was actually given.
-- `source` tags the minerals for analytics ("enemy", "mining"...).
function EconomyService.grant(player: Player, reward: Reward, source: string): Reward
	local given: Reward = {}
	if reward.minerals then
		local mult = EconomyService.mineralMultiplier(player)
		local beatMultiplier, beatRun = 1, nil
		if source == "mining" then
			beatMultiplier, beatRun = WorldBeat.miningMultiplier(os.time())
		end
		local minerals = {}
		for id, amount in reward.minerals do
			-- Multiply the normal rounded payout so 2x means exactly twice
			-- what this node would have paid outside the surge.
			minerals[id] = math.max(math.floor(amount * mult), 1) * beatMultiplier
		end
		DataService.addMinerals(player, minerals, source)
		if beatRun then
			Events.fire("worldBeatParticipated", player, beatRun)
		end
		given.minerals = minerals
	end
	if reward.xp then
		local golem = GolemService.get(player)
		local xp = math.floor(reward.xp * (if golem then golem.stats.xpMult else 1))
		DataService.addXp(player, xp)
		given.xp = xp
	end
	return given
end

-- Grants a fixed reward with no multipliers (daily gifts, quests, packs).
function EconomyService.grantFlat(player: Player, reward: Reward, source: string)
	if reward.minerals then
		DataService.addMinerals(player, reward.minerals, source)
	end
	if reward.xp then
		DataService.addXp(player, reward.xp)
	end
end

return EconomyService
