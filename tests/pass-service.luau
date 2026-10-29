-- Exercise the real PassService through ProcessReceipt, ProfileLoaded and the
-- registered snapshot provider. IDs are synthetic and confined to a cloned
-- Config; no marketplace request or real purchase is made. The boost watcher
-- runs in a coroutine with a controlled clock, one tick at a time.
-- Out of scope: Roblox receipts across servers, persistence after a crash,
-- real ownership-cache lag and platform purchase confirmation.
do
	local config = table.clone(Config)
	config.Products = {}
	for index, key in Config.ProductOrder do
		config.Products[key] = table.clone(Config.Products[key])
		config.Products[key].id = 1000 + index
	end
	config.GamePasses = {}
	local passId = 2000
	for key, pass in Config.GamePasses do
		passId += 1
		config.GamePasses[key] = table.clone(pass)
		config.GamePasses[key].id = passId
	end
	-- A disabled pass must not trigger a platform lookup.
	config.GamePasses.longRest.id = 0

	local function signal()
		local callbacks = {}
		return {
			Connect = function(_, callback)
				table.insert(callbacks, callback)
			end,
			Fire = function(_, ...)
				for _, callback in callbacks do
					callback(...)
				end
			end,
		}
	end

	local function fixture()
		local now = 100000
		local profiles, sessions, players, changed = {}, {}, {}, {}
		local events, notifications, mineralGrants, saved, ownershipCalls = {}, {}, {}, {}, {}
		local ownership = {}
		local duringLookupId, duringLookup
		local policyReady, allowed = true, true
		local saveSucceeds = true
		local loaded, removing, purchased = signal(), signal(), signal()
		local providers = {}
		local spawned = {}
		local marketplace = {
			PromptGamePassPurchaseFinished = purchased,
			UserOwnsGamePassAsync = function(_, userId, id)
				table.insert(ownershipCalls, { userId = userId, id = id })
				local response = ownership[id]
				if type(response) == "table" then
					response = table.remove(response, 1)
				end
				-- Trigger a confirmed purchase after an initial lookup has read
				-- its stale result, before that result is merged into the cache.
				if duringLookup and duringLookupId == id then
					local callback = duringLookup
					duringLookup = nil
					callback()
				end
				if response == "error" then
					error("simulated marketplace outage")
				end
				return response == true
			end,
		}
		local playersService = {
			PlayerRemoving = removing,
			GetPlayers = function()
				return players
			end,
			GetPlayerByUserId = function(_, userId)
				for _, player in players do
					if player.UserId == userId then
						return player
					end
				end
				return nil
			end,
		}
		local service = loadPassService({
			Config = config,
			Stats = Stats,
			Remotes = {
				Notify = {
					FireClient = function(_, player, kind, message)
						table.insert(notifications, { player = player, kind = kind, message = message })
					end,
				},
			},
			Events = {
				fire = function(...)
					table.insert(events, { ... })
				end,
			},
			PolicyService = {
				isReady = function()
					return policyReady
				end,
				paidRandomAllowed = function()
					return allowed
				end,
			},
			DataService = {
				ProfileLoaded = loaded,
				addProvider = function(name, provider)
					providers[name] = provider
				end,
				get = function(player)
					return profiles[player]
				end,
				getSession = function(player)
					return sessions[player]
				end,
				markChanged = function(player)
					changed[player] = (changed[player] or 0) + 1
				end,
				update = function(player, update)
					assert(profiles[player], "updates need a loaded profile")
					update(profiles[player])
				end,
				addMinerals = function(player, minerals, source)
					table.insert(mineralGrants, { player = player, minerals = minerals, source = source })
					for mineral, amount in minerals do
						profiles[player].minerals[mineral] = (profiles[player].minerals[mineral] or 0) + amount
					end
				end,
				saveNow = function(player)
					-- Inspect the state at the save boundary, not just after the handler.
					table.insert(saved, {
						player = player,
						receipts = table.clone(profiles[player].receipts),
						boosts = table.clone(profiles[player].boosts),
					})
					return saveSucceeds
				end,
			},
		}, {
			GetService = function(_, name)
				if name == "MarketplaceService" then
					return marketplace
				end
				if name == "Players" then
					return playersService
				end
				return {
					WaitForChild = function()
						return {}
					end,
				}
			end,
		}, {
			spawn = function(fn, ...)
				local thread = coroutine.create(fn)
				table.insert(spawned, thread)
				local ok, err = coroutine.resume(thread, ...)
				assert(ok, err)
			end,
			wait = function()
				coroutine.yield()
			end,
		}, function()
			return now
		end)
		service.start()
		local f = {
			service = service,
			marketplace = marketplace,
			profiles = profiles,
			sessions = sessions,
			players = players,
			changed = changed,
			events = events,
			notifications = notifications,
			mineralGrants = mineralGrants,
			saved = saved,
			ownership = ownership,
			ownershipCalls = ownershipCalls,
			loaded = loaded,
			removing = removing,
			providers = providers,
		}
		function f.join(withData)
			local player = { UserId = #players + 1, Parent = {} }
			table.insert(players, player)
			if withData ~= false then
				local data = fresh()
				data.receipts = {}
				profiles[player] = data
				sessions[player] = { canSave = true }
			end
			return player
		end
		function f.receipt(player, key, purchaseId)
			return marketplace.ProcessReceipt({
				PlayerId = player.UserId,
				ProductId = config.Products[key].id,
				PurchaseId = purchaseId,
			})
		end
		function f.policy(ready, permitsLuck)
			policyReady, allowed = ready, permitsLuck
		end
		function f.saveResult(result)
			saveSucceeds = result
		end
		function f.time(value)
			now = value
		end
		function f.onLookup(id, callback)
			duringLookupId, duringLookup = id, callback
		end
		function f.flushPurchases()
			-- The first spawned thread is the endless boost watcher.
			-- Resume purchase verification retries without advancing it.
			for _ = 1, 4 do
				for index = 2, #spawned do
					local thread = spawned[index]
					if coroutine.status(thread) == "suspended" then
						local ok, err = coroutine.resume(thread)
						assert(ok, err)
					end
				end
			end
		end
		function f.tick()
			local ok, err = coroutine.resume(spawned[1])
			assert(ok, err)
		end
		return f
	end
	local granted = Enum.ProductPurchaseDecision.PurchaseGranted
	local pending = Enum.ProductPurchaseDecision.NotProcessedYet

	do
		local f = fixture()
		local player = f.join()
		assert(f.receipt(player, "boostXp", "once") == granted)
		local endsAt = 100000 + config.Products.boostXp.minutes * 60
		assert(f.profiles[player].boosts.xp == endsAt)
		assert(
			#f.saved == 1 and f.saved[1].receipts[1] == "once" and f.saved[1].boosts.xp == endsAt,
			"reward and receipt must be in the state sent to saveNow"
		)
		assert(f.receipt(player, "boostXp", "once") == granted)
		assert(
			f.profiles[player].boosts.xp == endsAt and #f.profiles[player].receipts == 1,
			"a duplicate receipt never extends the reward"
		)
		assert(#f.events == 1 and #f.notifications == 1, "duplicate receipts don't repeat purchase side effects")
		assert(
			f.events[1][1] == "purchased"
				and f.events[1][2] == player
				and f.events[1][3] == "product"
				and f.events[1][4] == "boostXp"
		)
	end

	do
		local f = fixture()
		local player, unloaded = f.join(), f.join(false)
		assert(f.marketplace.ProcessReceipt({
			PlayerId = 999,
			ProductId = config.Products.boostXp.id,
			PurchaseId = "absent",
		}) == pending)
		assert(f.receipt(unloaded, "boostXp", "unloaded") == pending)
		assert(
			f.marketplace.ProcessReceipt({ PlayerId = player.UserId, ProductId = -1, PurchaseId = "unknown" })
				== pending
		)
		assert(
			#f.saved == 0
				and #f.events == 0
				and #f.notifications == 0
				and #f.profiles[player].receipts == 0
				and next(f.profiles[player].boosts) == nil,
			"unresolved receipts grant nothing"
		)
	end

	do
		local f = fixture()
		local player = f.join()
		f.saveResult(false)
		assert(f.receipt(player, "boostXp", "save-retry") == pending, "failed saving requests a retry")
		local endsAt = f.profiles[player].boosts.xp
		assert(#f.saved == 1 and f.saved[1].receipts[1] == "save-retry")
		f.saveResult(true)
		assert(f.receipt(player, "boostXp", "save-retry") == granted)
		assert(
			f.profiles[player].boosts.xp == endsAt and #f.profiles[player].receipts == 1 and #f.events == 1,
			"a retry after save failure must not grant twice within the session"
		)
		-- This deliberately makes no durability claim: a duplicate returns
		-- before saveNow in today's service. Crash/rejoin behavior isn't mocked.
	end

	do
		local f = fixture()
		local player = f.join()
		for index = 1, 50 do
			table.insert(f.profiles[player].receipts, "old-" .. index)
		end
		assert(f.receipt(player, "boostXp", "new-51") == granted)
		assert(f.receipt(player, "boostXp", "new-52") == granted)
		local receipts = f.profiles[player].receipts
		assert(
			#receipts == 50
				and receipts[1] == "old-3"
				and receipts[48] == "old-50"
				and receipts[49] == "new-51"
				and receipts[50] == "new-52",
			"trim oldest receipts first"
		)
	end

	do
		local f = fixture()
		local player = f.join()
		f.policy(false, false)
		assert(f.receipt(player, "boostLuck", "policy") == pending)
		assert(
			next(f.profiles[player].boosts) == nil
				and #f.profiles[player].receipts == 0
				and #f.saved == 0
				and #f.events == 0,
			"wait for policy before consuming or granting a luck receipt"
		)
		f.policy(true, false)
		assert(f.receipt(player, "boostLuck", "policy") == granted)
		assert(
			f.profiles[player].boosts.luck == nil
				and f.profiles[player].boosts.xp == 100000 + config.Products.boostLuck.minutes * 60,
			"restricted players receive the same duration of XP, never luck"
		)
		assert(string.find(f.notifications[1].message, "2x xp", 1, true), "confirmation describes the alternative")
	end

	do
		local f = fixture()
		local player = f.join()
		assert(f.receipt(player, "boostLuck", "luck-1") == granted)
		local duration = config.Products.boostLuck.minutes * 60
		assert(f.profiles[player].boosts.luck == 100000 + duration and f.profiles[player].boosts.xp == nil)
		f.time(100100)
		assert(f.receipt(player, "boostLuck", "luck-2") == granted)
		assert(f.profiles[player].boosts.luck == 100000 + 2 * duration, "active boosts extend from their end")
		f.profiles[player].boosts.xp = 99999
		assert(f.receipt(player, "boostXp", "expired") == granted)
		assert(
			f.profiles[player].boosts.xp == 100100 + config.Products.boostXp.minutes * 60,
			"expired boosts restart from now"
		)
	end

	do
		for _, advanced in { false, true } do
			local f = fixture()
			local player = f.join()
			local data = f.profiles[player]
			if advanced then
				data.golem.xp = Stats.xpForLevel(Config.Golem.maxLevel)
				for _, zoneId in Config.ZoneOrder do
					data.bossesDefeated[tostring(zoneId)] = true
				end
			end
			local zoneId = Stats.highestZone(data)
			assert(zoneId == (if advanced then Config.ZoneOrder[#Config.ZoneOrder] else 1))
			for _, key in { "mineralsSmall", "mineralsMedium", "mineralsLarge" } do
				assert(f.receipt(player, key, key) == granted)
				local grant = f.mineralGrants[#f.mineralGrants]
				assert(grant.player == player and grant.source == "purchase")
				local expected = Config.Zones[zoneId].offlineMinerals
				for mineral, perMinute in expected do
					assert(
						grant.minerals[mineral] == perMinute * Config.Products[key].packMinutes * 3,
						"packs scale from the highest unlocked zone and their configured minutes"
					)
				end
				for mineral in grant.minerals do
					assert(expected[mineral] ~= nil, "no minerals from another zone")
				end
			end
		end
	end

	do
		local f = fixture()
		local player = f.join()
		assert(not f.service.isReady(player) and not f.service.owns(player, "vip"))
		assert(next(f.service.passes(player)) == nil and f.providers.passes ~= nil)
		f.ownership[config.GamePasses.vip.id] = true
		f.ownership[config.GamePasses.autoForge.id] = "error"
		f.loaded:Fire(player)
		assert(f.service.isReady(player) and f.service.owns(player, "vip"))
		assert(
			not f.service.owns(player, "autoForge")
				and not f.service.owns(player, "doubleMinerals")
				and not f.service.owns(player, "longRest")
				and not f.service.owns(player, "unknown"),
			"errors, false, disabled and unknown passes confer no ownership"
		)
		assert(#f.ownershipCalls == 4, "only configured nonzero passes are looked up")
		for _, call in f.ownershipCalls do
			assert(call.userId == player.UserId and call.id > 0)
		end
		local snapshot = f.providers.passes(player)
		snapshot.vip = false
		assert(f.service.owns(player, "vip"), "snapshots cannot mutate cached ownership")
		assert(f.changed[player] == 1, "loading ownership refreshes the player")
		f.removing:Fire(player)
		assert(
			not f.service.isReady(player)
				and not f.service.owns(player, "vip")
				and next(f.service.passes(player)) == nil,
			"disconnect clears ownership"
		)
		local departed = f.join()
		departed.Parent = nil
		f.loaded:Fire(departed)
		assert(
			not f.service.isReady(departed) and f.changed[departed] == nil,
			"ownership results for a departed player are discarded"
		)
	end

	do
		local f = fixture()
		local player = f.join()
		f.profiles[player].boosts = { xp = 100002, luck = 100004 }
		f.tick()
		assert(f.changed[player] == nil, "first watcher tick records its baseline")
		f.time(100002)
		f.tick()
		assert(f.changed[player] == 1, "expiry at the exact end time refreshes stats and odds")
		f.tick()
		assert(f.changed[player] == 1, "the same expiration only refreshes once")
		f.time(100004)
		f.tick()
		assert(f.changed[player] == 2, "another boost expiring refreshes again")
		f.tick()
		assert(f.changed[player] == 2, "idle ticks don't repeat expiry notifications")
		f.removing:Fire(player)
		f.profiles[player].boosts.xp = 100010
		f.tick()
		assert(f.changed[player] == 2, "disconnect also clears the watcher's baseline")
	end

	-- The prompt's purchased flag is not proof of payment. Reject unowned,
	-- errored, cancelled and unknown passes without side effects.
	do
		local f = fixture()
		local player = f.join()
		local id = config.GamePasses.vip.id
		f.marketplace.PromptGamePassPurchaseFinished:Fire(player, id, false)
		f.marketplace.PromptGamePassPurchaseFinished:Fire(player, -1, true)
		assert(#f.ownershipCalls == 0, "cancelled and unknown prompts do not query ownership")
		f.marketplace.PromptGamePassPurchaseFinished:Fire(player, id, true)
		f.flushPurchases()
		assert(not f.service.owns(player, "vip"), "unowned pass must not be granted")
		f.ownership[id] = "error"
		f.marketplace.PromptGamePassPurchaseFinished:Fire(player, id, true)
		f.flushPurchases()
		assert(
			not f.service.owns(player, "vip") and #f.events == 0 and #f.notifications == 0,
			"failed ownership checks must not grant or announce a pass"
		)
	end

	-- A newly purchased pass can take several ownership lookups to appear.
	-- Grant once after a confirmed yes, including before initial load finishes.
	do
		local f = fixture()
		local player = f.join()
		local id = config.GamePasses.vip.id
		f.ownership[id] = { false, "error", true }
		f.marketplace.PromptGamePassPurchaseFinished:Fire(player, id, true)
		f.flushPurchases()
		assert(f.service.owns(player, "vip") and f.service.isReady(player))
		assert(#f.ownershipCalls == 3, "fresh purchases retry ownership up to three times")
		assert(#f.events == 1 and #f.notifications == 1, "verified purchase is granted once")
		f.ownership[id] = true
		f.marketplace.PromptGamePassPurchaseFinished:Fire(player, id, true)
		assert(#f.events == 1 and #f.notifications == 1, "duplicate prompt does not double-grant")
		f.loaded:Fire(player)
		assert(f.service.owns(player, "vip"), "later initial checks preserve confirmed purchases")
		f.removing:Fire(player)
		player.Parent = nil
		f.marketplace.PromptGamePassPurchaseFinished:Fire(player, id, true)
		assert(not f.service.owns(player, "vip") and #f.events == 1, "departed players cannot be granted")
	end

	-- A stale initial lookup may finish after a purchase is confirmed.
	do
		local f = fixture()
		local player = f.join()
		local id = config.GamePasses.vip.id
		f.onLookup(id, function()
			f.ownership[id] = true
			f.marketplace.PromptGamePassPurchaseFinished:Fire(player, id, true)
		end)
		f.loaded:Fire(player)
		assert(f.service.owns(player, "vip"), "stale initial lookup must not undo verified purchase")
		assert(#f.events == 1 and #f.notifications == 1, "race grants and announces only once")
	end

	print("pass-service: ok")
end
