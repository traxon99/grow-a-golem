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

local Events = {}

local listeners: { [string]: { (...any) -> () } } = {}

function Events.connect(name: string, callback: (...any) -> ())
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], callback)
end

function Events.fire(name: string, ...: any)
	for _, callback in listeners[name] or {} do
		task.spawn(callback, ...)
	end
end

return Events
