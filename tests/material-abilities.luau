-- Material mastery (#215): forging a qualifying part teaches a lasting
-- exploration tool, the same way for manual forging and Auto-Forge.
do
	local K = Config.Kingdom
	local function rank(tier)
		return table.find(Config.TierOrder, tier)
	end

	-- Every listed tool has copy, a known tier and real slots.
	assert(#K.abilityOrder == 5)
	for _, id in K.abilityOrder do
		local ability = K.abilities[id]
		assert(ability and ability.name and ability.description and ability.hint, id)
		assert(rank(ability.tier), id)
		for _, slot in ability.slots do
			assert(Config.Slots[slot], id)
		end
	end
	for id in K.abilities do
		assert(table.find(K.abilityOrder, id), "abilityOrder lists every tool")
	end

	-- Slot and tier boundaries use TierOrder ranks, not string order.
	assert(#Stats.abilitiesForPart("armL", "stone") == 0)
	assert(Stats.abilitiesForPart("armL", "copper")[1] == "smash")
	assert(Stats.abilitiesForPart("armR", "copper")[1] == "smash", "either arm qualifies")
	assert(#Stats.abilitiesForPart("core", "copper") == 0)
	assert(#Stats.abilitiesForPart("core", "iron") == 0)
	assert(Stats.abilitiesForPart("core", "crystal")[1] == "reveal")
	assert(#Stats.abilitiesForPart("torso", "crystal") == 0)
	assert(Stats.abilitiesForPart("torso", "stormglass")[1] == "conduit")
	assert(#Stats.abilitiesForPart("legs", "stormglass") == 0)
	assert(Stats.abilitiesForPart("legs", "abyssite")[1] == "anchor")
	assert(#Stats.abilitiesForPart("legs", "nonsense") == 0)
	-- A higher tier skips ahead and still teaches every lower tool.
	local skipped = Stats.abilitiesForPart("armL", "aether")
	assert(#skipped == 2 and skipped[1] == "smash" and skipped[2] == "lift")
	local arm = Stats.abilitiesForPart("armR", "iron")
	assert(#arm == 2 and arm[1] == "smash" and arm[2] == "lift")

	local learnedSmash = { campaign = { abilities = { smash = true } } }
	local fresh = Stats.newAbilitiesForPart(learnedSmash, "armL", "iron")
	assert(#fresh == 1 and fresh[1] == "lift", "already learned tools are not taught again")
	assert(Stats.abilityLearned(learnedSmash, "smash") and not Stats.abilityLearned(learnedSmash, "lift"))
	assert(not Stats.abilityLearned({}, "smash"))

	-- Each tool is earnable from minerals mined at or before its first obstacle.
	for _, id in K.abilityOrder do
		local ability = K.abilities[id]
		local regionIndex = table.find(Config.ZoneOrder, ability.region)
		assert(regionIndex, id)
		local minable = {}
		for index = 1, regionIndex do
			for _, node in Config.Zones[Config.ZoneOrder[index]].nodes do
				minable[node.mineral] = true
			end
		end
		for mineral in Config.Tiers[ability.tier].cost do
			assert(minable[mineral], `{id} needs {mineral} before region {ability.region}`)
		end
	end

	-- The real forge handler, manual and automatic, against mocked services.
	local function forgeHarness(enabled)
		local player = {}
		local data = {
			golem = { parts = {} },
			minerals = {},
			campaign = { regions = { ["1"] = true }, abilities = {}, obstacles = {} },
			bossesDefeated = {},
		}
		for _, id in Config.MineralOrder do
			data.minerals[id] = 10000000
		end
		local actions, notifications, events = {}, {}, {}
		local service = loadProgression({
			Config = Config,
			ForgeStrike = ForgeStrike,
			Stats = Stats,
			Remotes = {
				Notify = {
					FireClient = function(_, _who, kind, a)
						table.insert(notifications, { kind, a })
					end,
				},
			},
			ActionService = {
				register = function(name, handler)
					actions[name] = handler
				end,
			},
			DataService = {
				get = function()
					return data
				end,
				update = function(_, fn)
					fn(data)
				end,
				spend = function(_, cost)
					for mineral, amount in cost do
						data.minerals[mineral] -= amount
					end
					return true
				end,
			},
			Events = {
				fire = function(name, _, a)
					table.insert(events, { name, a })
				end,
			},
			GolemService = {
				setCrossingHandler = function() end,
				get = function()
					return {}
				end,
				sendToZone = function() end,
			},
			PassService = {},
		})
		local wasEnabled = K.enabled
		K.enabled = enabled
		service.start()
		local function count(list, kind)
			local n = 0
			for _, entry in list do
				if entry[1] == kind then
					n += 1
				end
			end
			return n
		end
		return player, data, actions, notifications, events, count, function()
			K.enabled = wasEnabled
		end
	end

	for _, automatic in { false, true } do
		local player, data, actions, notifications, events, count, restore = forgeHarness(true)
		-- Skipping straight to iron on the left arm teaches Smash and Lift once.
		assert(actions.craftPart(player, "armL", "iron", automatic))
		assert(data.campaign.abilities.smash and data.campaign.abilities.lift)
		assert(count(events, "abilityLearned") == 2 and count(notifications, "abilityLearned") == 2)
		-- The other arm qualifies too, but teaches nothing new.
		assert(actions.craftPart(player, "armR", "crystal", automatic))
		assert(count(events, "abilityLearned") == 2, "idempotent across arms")
		-- A higher arm on the same slot keeps the tools and adds none.
		assert(actions.craftPart(player, "armL", "aether", automatic))
		assert(count(events, "abilityLearned") == 2)
		-- No tool grants region access, a boss victory or an opened obstacle.
		assert(data.campaign.regions["2"] == nil and next(data.bossesDefeated) == nil)
		assert(next(data.campaign.obstacles) == nil)
		assert(actions.craftPart(player, "core", "crystal", automatic))
		assert(data.campaign.abilities.reveal and count(events, "abilityLearned") == 3)
		-- Awakening clears parts, but learned tools stay.
		data.golem.xp = Stats.xpForLevel(Config.Awakening.minLevel)
		data.awakening = { count = 0, shards = 0, upgrades = {} }
		data.skills, data.coreUpgrades = {}, {}
		assert(actions.awaken(player))
		assert(next(data.golem.parts) == nil)
		assert(data.campaign.abilities.smash and data.campaign.abilities.lift and data.campaign.abilities.reveal)
		-- Re-forging after the reset does not re-teach or re-announce.
		assert(actions.craftPart(player, "armL", "copper", automatic))
		assert(count(events, "abilityLearned") == 3 and count(notifications, "abilityLearned") == 3)
		restore()
	end

	-- With the kingdom off, tools are still recorded but no cue is sent.
	do
		local player, data, actions, notifications, events, count, restore = forgeHarness(false)
		assert(actions.craftPart(player, "armR", "copper", true))
		assert(data.campaign.abilities.smash and count(events, "abilityLearned") == 1)
		assert(count(notifications, "abilityLearned") == 0)
		restore()
	end
	print("material-abilities: ok")
end
