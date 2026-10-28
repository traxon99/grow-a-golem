-- Artifact finds and equip slots (ArtifactService): grant/addCopy's
-- found-vs-spare bookkeeping and equip/unequip's slot rules. The check
-- script bundles the real Config above this file and loads the real
-- ArtifactService with its requires replaced by the mocks below.
--
-- Out of scope here: roll() (the drop-chance/pity roll itself, which needs
-- the real Stats.compute over a fully-shaped save plus a deterministic
-- math.random, and belongs with its own, bigger test) and the hidden-relic
-- flow (placeRelic/collectRelic/.start()'s pickup loop), which needs
-- Instance.new/TweenService/WorldService world-building this test doesn't
-- otherwise need. Config.Zones is emptied for the call to .start() so its
-- relic-placement loop (which runs synchronously, not through task.spawn)
-- has nothing to place, and restored right after.
do
	local handlers = {}
	local fired = {}
	local notified = {}
	local datas = {}
	local golems = {}

	local function fresh()
		return { artifacts = { found = {}, equipped = {}, pity = {}, spares = {}, boundSpares = {} } }
	end

	local savedZones = Config.Zones
	Config.Zones = {}
	local artifacts = loadArtifactService({
		Config = Config,
		Remotes = {
			Notify = {
				FireClient = function(_, player, kind, a, b)
					table.insert(notified, { player = player, kind = kind, a = a, b = b })
				end,
			},
		},
		Stats = Stats,
		ActionService = {
			register = function(name, fn)
				handlers[name] = fn
			end,
		},
		DataService = {
			get = function(player)
				return datas[player]
			end,
			update = function(player, fn)
				fn(datas[player])
			end,
			Changed = { Connect = function() end },
		},
		EconomyService = {},
		Events = {
			fire = function(name, player, artifactId)
				table.insert(fired, { name = name, player = player, artifactId = artifactId })
			end,
		},
		GolemService = {
			get = function(player)
				return golems[player]
			end,
		},
		WorldService = {},
	}, {
		GetService = function()
			return {
				WaitForChild = function()
					return {}
				end,
			}
		end,
	}, {
		spawn = function() end, -- the hidden-relic pickup loop never runs in this test
		wait = function() end,
	})
	artifacts.start()
	Config.Zones = savedZones
	local equip = handlers.equipArtifact
	local unequip = handlers.unequipArtifact
	assert(equip and unequip, "both actions are registered")

	local nextId = 0
	local function join()
		nextId += 1
		local player = { UserId = nextId, DisplayName = "P" .. nextId }
		datas[player] = fresh()
		return player
	end

	--------------------------------------------------------------------- grant
	do
		local player = join()
		golems[player] = { stats = { artifactSlots = 3 } }
		artifacts.grant(player, "pebbleCharm")
		local data = datas[player]
		assert(data.artifacts.found.pebbleCharm == true)
		assert(table.find(data.artifacts.equipped, "pebbleCharm") ~= nil, "auto-equips into a free slot")
		assert(fired[#fired].name == "artifactFound" and fired[#fired].artifactId == "pebbleCharm")
		assert(notified[#notified].kind == "artifact" and notified[#notified].a == Config.Artifacts.pebbleCharm.name)
	end

	do
		-- No free slot: still marked found, but not auto-equipped.
		local player = join()
		golems[player] = { stats = { artifactSlots = 0 } }
		artifacts.grant(player, "pebbleCharm")
		assert(datas[player].artifacts.found.pebbleCharm == true)
		assert(#datas[player].artifacts.equipped == 0, "no free slot means no auto-equip")
	end

	do
		-- No golem at all: falls back to Config.Golem.baseArtifactSlots.
		local player = join()
		artifacts.grant(player, "pebbleCharm")
		assert(#datas[player].artifacts.equipped == 1, "with no golem, the base slot count still allows one")
	end

	--------------------------------------------------------------------- addCopy
	do
		local data = fresh()
		local isNew = artifacts.addCopy(data, "pebbleCharm", 3, false)
		assert(isNew == true and data.artifacts.found.pebbleCharm == true)
		assert(table.find(data.artifacts.equipped, "pebbleCharm") ~= nil)

		local isNewAgain = artifacts.addCopy(data, "pebbleCharm", 3, false)
		assert(isNewAgain == false, "a second copy of a found artifact is a spare, not a new find")
		assert(data.artifacts.spares.pebbleCharm == 1)
		assert(data.artifacts.boundSpares.pebbleCharm == nil, "an unbound spare isn't counted as bound")

		local isNewBound = artifacts.addCopy(data, "pebbleCharm", 3, true)
		assert(isNewBound == false)
		assert(data.artifacts.spares.pebbleCharm == 2 and data.artifacts.boundSpares.pebbleCharm == 1)
	end

	--------------------------------------------------------------------- equip
	do
		local player = join()
		golems[player] = { stats = { artifactSlots = 1 } }

		local okNotReady = equip(player, 5 :: any)
		assert(okNotReady == false, "a non-string id is refused")

		local okUnfound, msgUnfound = equip(player, "pebbleCharm")
		assert(okUnfound == false and msgUnfound == "You haven't found that yet")

		datas[player].artifacts.found.pebbleCharm = true
		local okEquip = equip(player, "pebbleCharm")
		assert(okEquip == true and table.find(datas[player].artifacts.equipped, "pebbleCharm") ~= nil)

		local okAgain, msgAgain = equip(player, "pebbleCharm")
		assert(okAgain == false and msgAgain == "Already equipped")

		datas[player].artifacts.found.quarryLantern = true
		local okFull, msgFull = equip(player, "quarryLantern")
		assert(okFull == false and msgFull == "All artifact slots are full. Unequip one first.")
	end

	--------------------------------------------------------------------- unequip
	do
		local player = join()
		datas[player].artifacts.equipped = { "pebbleCharm" }

		local okNotReady = unequip(player, 5 :: any)
		assert(okNotReady == false)

		local okNotEquipped, msgNotEquipped = unequip(player, "quarryLantern")
		assert(okNotEquipped == false and msgNotEquipped == "Not equipped")

		local okUnequip = unequip(player, "pebbleCharm")
		assert(okUnequip == true and table.find(datas[player].artifacts.equipped, "pebbleCharm") == nil)
	end

	print("artifact-service: ok")
end
