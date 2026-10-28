-- Artifact finds and equip slots (ArtifactService): grant/addCopy's
-- found-vs-spare bookkeeping, equip/unequip's slot rules, and roll()'s
-- honest marble-bag draw (docs/reference/safety-compliance.md: a guaranteed
-- find before the bag runs out, never a fake near-miss). The check
-- script bundles the real Config/Stats above this file and loads the real
-- ArtifactService with its requires replaced by the mocks below, plus a
-- test-controlled os.time and math.random.
--
-- roll() needs Stats.compute's luckMult but nothing else Stats.compute
-- computes, so Stats here is the real module with just .compute swapped for
-- a stub (everything else -- artifactOdds, spareOdds, artifactBag -- stays
-- real, so the bag math itself is genuinely exercised, not reimplemented).
--
-- Out of scope here: the hidden-relic flow (placeRelic/collectRelic/
-- .start()'s pickup loop), which needs Instance.new/TweenService/
-- WorldService world-building this test doesn't otherwise need.
-- Config.Zones is emptied for the call to .start() so its relic-placement
-- loop (which runs synchronously, not through task.spawn) has nothing to
-- place, and restored right after.
do
	local handlers = {}
	local fired = {}
	local notified = {}
	local datas = {}
	local golems = {}

	local function fresh()
		return { artifacts = { found = {}, equipped = {}, bags = {}, spares = {}, boundSpares = {} }, boosts = {} }
	end

	local timeNow = 1000
	local luckMult = 1
	local randomQueue = {}
	local randomCalls = {}
	local function random(a, b)
		table.insert(randomCalls, { a = a, b = b })
		local value = table.remove(randomQueue, 1)
		assert(value ~= nil, "a math.random value was queued for every call roll() makes")
		return value
	end
	-- Only .compute is stubbed (roll() just needs its luckMult); artifactOdds,
	-- spareOdds and artifactBag fall through to the real Stats, so the bag math
	-- itself is exercised, not reimplemented here.
	local FakeStats = setmetatable({
		compute = function()
			return { luckMult = luckMult }
		end,
	}, { __index = Stats })

	local savedZones = Config.Zones
	Config.Zones = {}
	local artifacts = loadArtifactService({
		Config = Config,
		MarbleBag = MarbleBag,
		Remotes = {
			Notify = {
				FireClient = function(_, player, kind, a, b)
					table.insert(notified, { player = player, kind = kind, a = a, b = b })
				end,
			},
		},
		Stats = FakeStats,
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
			context = function()
				return {}
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
	}, function()
		return timeNow
	end, random)
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

	--------------------------------------------------------------------- roll
	-- Zone 1's "drop" artifacts: pebbleCharm, quarryLantern, oldChisel,
	-- rootboundRing (Config.ArtifactOrder's own order, matching the order
	-- roll()'s own option lists are built in).
	local size = Config.ArtifactBags.drop.marbles
	do
		-- An honest miss: a losing marble is drawn from the 167-marble bag,
		-- so only the bag's count moves.
		local player = join()
		datas[player].artifacts.found = { quarryLantern = true, oldChisel = true, rootboundRing = true }
		randomQueue, randomCalls = { 2 }, {}
		artifacts.roll(player, 1, "drop")
		local bag = datas[player].artifacts.bags.drop1
		assert(bag.drawn == 1 and bag.wins == 0, "a miss takes one marble out of the bag")
		assert(datas[player].artifacts.found.pebbleCharm == nil, "a miss grants nothing")
		assert(#randomCalls == 1 and randomCalls[1].a == 1 and randomCalls[1].b == size, "one draw from the full bag")
		-- The miss raises the shown chance: one winner in one fewer marble.
		local chance, left = Stats.artifactOdds(datas[player], 1, "drop", 1)
		assert(chance == 1 / (size - 1) and left == size - 1)
	end

	do
		-- An honest hit partway through the bag: the winner is drawn, and
		-- the rest of this bag holds only misses until it refills.
		local player = join()
		datas[player].artifacts.found = { quarryLantern = true, oldChisel = true, rootboundRing = true }
		datas[player].artifacts.bags = { drop1 = { drawn = 5, wins = 0 } }
		randomQueue, randomCalls = { 1, 1 }, {}
		artifacts.roll(player, 1, "drop")
		assert(datas[player].artifacts.found.pebbleCharm == true)
		local bag = datas[player].artifacts.bags.drop1
		assert(bag.drawn == 6 and bag.wins == 1, "the winner leaves the bag")
		assert(fired[#fired].name == "artifactFound" and fired[#fired].player == player)
		assert(#randomCalls == 2 and randomCalls[1].b == size - 5 and randomCalls[2].a == 1 and randomCalls[2].b == 1)
		-- The menus now show 0% until the bag refills, and when the next find is sure.
		datas[player].artifacts.found.pebbleCharm = nil
		local chance, left = Stats.artifactOdds(datas[player], 1, "drop", 1)
		assert(chance == 0 and left == (size - 6) + size, "sure within the rest of this bag plus the next")
		-- A draw from a bag whose winner is out never rolls and never finds.
		randomQueue, randomCalls = {}, {}
		artifacts.roll(player, 1, "drop")
		assert(#randomCalls == 0 and datas[player].artifacts.found.pebbleCharm == nil)
		assert(datas[player].artifacts.bags.drop1.drawn == 7)
	end

	do
		-- The last marble in the bag is the winner: the find is sure and the
		-- "did I get lucky" draw is never even made -- an unlucky roll here
		-- would be a fake near-miss, which safety-compliance.md rules out.
		-- Only one value is queued (for the pick): if a draw ran anyway, the
		-- a==1/b==1 assertion below would fail. The bag then refills.
		local player = join()
		datas[player].artifacts.found = { quarryLantern = true, oldChisel = true, rootboundRing = true }
		datas[player].artifacts.bags = { drop1 = { drawn = size - 1, wins = 0 } }
		randomQueue, randomCalls = { 1 }, {}
		artifacts.roll(player, 1, "drop")
		assert(datas[player].artifacts.found.pebbleCharm == true, "the last marble always finds")
		local bag = datas[player].artifacts.bags.drop1
		assert(bag.drawn == 0 and bag.wins == 0, "an empty bag refills")
		assert(#randomCalls == 1 and randomCalls[1].a == 1 and randomCalls[1].b == 1, "the chance draw never ran")
	end

	do
		-- 2x Luck halves the bag. A player 100 marbles into an unlucky bag
		-- is past the end of the 84-marble lucky bag, so their find is owed
		-- and sure on the next roll, not reset.
		local player = join()
		datas[player].artifacts.found = { quarryLantern = true, oldChisel = true, rootboundRing = true }
		datas[player].artifacts.bags = { drop1 = { drawn = 100, wins = 0 } }
		luckMult = 2
		assert(Stats.artifactOdds(datas[player], 1, "drop", 2) == 1)
		randomQueue, randomCalls = { 1 }, {}
		artifacts.roll(player, 1, "drop")
		luckMult = 1
		assert(datas[player].artifacts.found.pebbleCharm == true and #randomCalls == 1)
	end

	do
		-- Everything in the zone/source is already found: the same honest
		-- bag now gives an unbound spare (no 2x Luck boost active), drawn
		-- from a spare bag so each copy comes up once before any repeats.
		local player = join()
		datas[player].artifacts.found =
			{ pebbleCharm = true, quarryLantern = true, oldChisel = true, rootboundRing = true }
		datas[player].artifacts.spareBags = { drop1 = { "pebbleCharm" } }
		datas[player].boosts.luck = 0
		timeNow = 1000
		randomQueue, randomCalls = { 1 }, {}
		artifacts.roll(player, 1, "drop")
		assert(datas[player].artifacts.spares.pebbleCharm == 1, "a spare is granted once everything is found")
		assert(datas[player].artifacts.boundSpares.pebbleCharm == nil, "unbound without an active 2x Luck boost")
		assert(#datas[player].artifacts.spareBags.drop1 == 0, "the drawn spare leaves its bag")
		assert(string.find(notified[#notified].a, "Trade it from the Trade tab.") ~= nil)
		-- The spare bag refills with all four once empty, and gives four
		-- different spares before any repeat.
		local seen = {}
		for _ = 1, 4 do
			datas[player].artifacts.bags.drop1 = { drawn = size - 1, wins = 0 }
			randomQueue = {}
			artifacts.roll(player, 1, "drop")
			for id in datas[player].artifacts.spares do
				seen[id] = true
			end
		end
		local kinds = 0
		for _ in seen do
			kinds += 1
		end
		assert(kinds == 4 and datas[player].artifacts.spares.pebbleCharm == 2, "one of each before repeats")
	end

	do
		-- Same, but with 2x Luck active: the spare is bound and can't be traded.
		local player = join()
		datas[player].artifacts.found =
			{ pebbleCharm = true, quarryLantern = true, oldChisel = true, rootboundRing = true }
		datas[player].artifacts.spareBags = { drop1 = { "quarryLantern" } }
		timeNow = 1000
		datas[player].boosts.luck = timeNow + 100
		randomQueue, randomCalls = { 1 }, {}
		artifacts.roll(player, 1, "drop")
		assert(datas[player].artifacts.spares.quarryLantern == 1)
		assert(datas[player].artifacts.boundSpares.quarryLantern == 1, "bound while 2x Luck is active")
		assert(string.find(notified[#notified].a, "Spares from 2x Luck can't be traded.") ~= nil)
	end

	print("artifact-service: ok")
end
