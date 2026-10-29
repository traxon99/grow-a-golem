--!strict
-- A tiny server-side event bus so services can react to each other
-- (quests listening for kills, for example) without requiring each other.
--
-- Events used:
--   enemyDefeated (player, enemyId, zoneId)
--   bossDefeated  (player, zoneId)
--   nodeMined     (player, mineralId)
--   spellCast     (player, spellId)
--   partCrafted   (player, slot, tier)
--   artifactFound (player, artifactId)
--   bossEngaged   (player, zoneId)         first hit on a boss
--   zoneEntered   (player, zoneId)         travelled to an island
--   awakened      (player, count)
--   mineralsGained(player, minerals, source)
--   mineralsSpent (player, minerals, sink)
--   purchased     (player, "pass" | "product" | "cosmetic", key)
--   partyJoined   (player, partySize)
--   codeRedeemed  (player, code)
--   eventRewardClaimed (player, eventId, tierIndex)
--   worldBeatParticipated (player, surgeStartAt)

local Events = {}

local listeners: { [string]: { (...any) -> () } } = {}

function Events.connect(name: string, callback: (...any) -> ())
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], callback)
end

function Events.fire(name: string, ...: any)
	for _, callback in listeners[name] or ({} :: any) do
		task.spawn(callback, ...)
	end
end

return Events
