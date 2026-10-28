-- Crash-safe trades. The check script bundles the real Config, Stats and
-- TradeJournal above this file, and loadTradeService wraps the real
-- TradeService with its requires replaced by the mocks below. Saves go to a
-- simulated DataStore (`records`), so a "crash" is just reloading players from
-- what was actually written.
do
	local function signal()
		local listeners = {}
		return {
			Connect = function(_, fn)
				table.insert(listeners, fn)
			end,
			Fire = function(_, ...)
				for _, fn in listeners do
					fn(...)
				end
			end,
		}
	end
	local function copy(value)
		if type(value) ~= "table" then
			return value
		end
		local result = {}
		for k, v in value do
			result[k] = copy(v)
		end
		return result
	end
	-- Two artifacts that both players have already found, so trades move spares.
	local X, Y = Config.ArtifactOrder[1], Config.ArtifactOrder[2]
	local function newData(spares)
		local found = { [X] = true, [Y] = true }
		return {
			artifacts = { found = found, equipped = {}, pity = {}, spares = copy(spares), boundSpares = {} },
			trades = { day = 0, count = 0, log = {} },
		}
	end
	local function total(id, ...)
		local sum = 0
		for _, data in { ... } do
			sum += (data.artifacts.spares[id] or 0)
			for _, held in (data.trades.pending and data.trades.pending.gave) or {} do
				if held == id then
					sum += 1
				end
			end
		end
		return sum
	end

	---------------------------------------------------------------- pure rules
	do
		local a = newData({ [X] = 2 })
		local pending = { id = "t1", with = 2, gave = { X }, got = { Y }, day = 10, at = 100 }
		assert(TradeJournal.prepare(a, pending))
		assert(a.artifacts.spares[X] == 1 and a.trades.pending.id == "t1")
		assert(not TradeJournal.prepare(a, pending), "Only one trade may be pending")
		local bound = newData({ [X] = 1 })
		bound.artifacts.boundSpares[X] = 1
		assert(
			not TradeJournal.prepare(bound, pending) and bound.artifacts.spares[X] == 1,
			"Bound spares never go into escrow"
		)
		local twice = newData({ [X] = 1 })
		assert(not TradeJournal.prepare(twice, { id = "t2", with = 2, gave = { X, X }, got = {}, day = 10, at = 100 }))
		assert(twice.artifacts.spares[X] == 1 and twice.trades.pending == nil, "A failed prepare changes nothing")

		assert(TradeJournal.status(TradeJournal.decide(nil, "committed", 5)) == "committed")
		local decided = TradeJournal.decide(nil, "aborted", 5)
		assert(
			TradeJournal.status(TradeJournal.decide(decided, "committed", 6)) == "aborted",
			"An existing decision always wins"
		)
		assert(TradeJournal.status({}) == nil and TradeJournal.status("x") == nil)

		local adds = function(data, id)
			data.artifacts.spares[id] = (data.artifacts.spares[id] or 0) + 1
		end
		assert(TradeJournal.resolve(a, "committed", adds, 2))
		assert(a.artifacts.spares[Y] == 1 and a.trades.pending == nil and a.trades.count == 1 and #a.trades.log == 1)
		assert(not TradeJournal.resolve(a, "committed", adds, 2), "Resolving twice does nothing")
		assert(a.artifacts.spares[Y] == 1)
		local back = newData({ [X] = 1 })
		assert(TradeJournal.prepare(back, pending) and back.artifacts.spares[X] == nil)
		assert(
			TradeJournal.resolve(back, "aborted", adds, 2) and back.artifacts.spares[X] == 1 and back.trades.count == 0
		)
		-- Cleanup: only a decided record can be marked, and only both sides
		-- marked means the record is no longer needed.
		assert(TradeJournal.markSettled(nil, "a") == nil, "Nothing settles before a decision")
		local record = TradeJournal.decide(nil, "committed", 1)
		record = TradeJournal.markSettled(record, "a")
		assert(TradeJournal.status(record) == "committed" and not TradeJournal.bothSettled(record))
		record = TradeJournal.markSettled(record, "a")
		assert(not TradeJournal.bothSettled(record), "Marking one side twice isn't both sides")
		record = TradeJournal.markSettled(record, "b")
		assert(TradeJournal.bothSettled(record))
		assert(
			TradeJournal.status(TradeJournal.decide(record, "aborted", 2)) == "committed",
			"Marks never change the decision"
		)
		print("PASS: TradeJournal escrow, decisions, one-time resolution and cleanup marks")
	end

	---------------------------------------------------------------- the service
	local records, journalRecords = {}, {}
	local live = {} -- player -> data held by this "server"
	local failSave, failJournal = {}, false
	local queue, delayed, said, fired = {}, {}, {}, {}
	local mockTask = {
		spawn = function(fn, ...)
			table.insert(queue, { fn, table.pack(...) })
		end,
		delay = function(_, fn, ...)
			table.insert(delayed, { fn, table.pack(...) })
		end,
		wait = function() end,
	}
	local function drain()
		while #queue > 0 do
			local job = table.remove(queue, 1)
			job[1](table.unpack(job[2], 1, job[2].n))
		end
	end
	local handlers = {}
	local loaded, removing = signal(), signal()
	local byId = {}
	local players = {
		PlayerRemoving = removing,
		GetPlayers = function()
			local list = {}
			for p in live do
				table.insert(list, p)
			end
			return list
		end,
		GetPlayerByUserId = function(_, id)
			return byId[id]
		end,
	}
	local guid = 0
	local services = {
		Players = players,
		ReplicatedStorage = {
			WaitForChild = function()
				return {}
			end,
		},
		HttpService = {
			GenerateGUID = function()
				guid += 1
				return "g" .. guid
			end,
		},
		DataStoreService = {
			GetDataStore = function()
				return {
					UpdateAsync = function(_, key, transform)
						if failJournal then
							error("simulated journal outage")
						end
						local value = transform(copy(journalRecords[key]))
						if value ~= nil then
							journalRecords[key] = copy(value)
						end
						return copy(value)
					end,
					RemoveAsync = function(_, key)
						if failJournal then
							error("simulated journal outage")
						end
						journalRecords[key] = nil
					end,
				}
			end,
		},
	}
	local mockGame = {
		GetService = function(_, name)
			return services[name]
		end,
	}
	local dataService = {
		ProfileLoaded = loaded,
		get = function(player)
			return live[player]
		end,
		getSession = function(player)
			return live[player] and { data = live[player], canSave = true }
		end,
		update = function(player, fn)
			if not live[player] then
				return false
			end
			fn(live[player])
			return true
		end,
		markChanged = function() end,
		addProvider = function() end,
		saveNow = function(player)
			if not live[player] or failSave[player] then
				return false
			end
			records[player.UserId] = copy(live[player])
			return true
		end,
	}
	local tradeService = loadTradeService({
		Config = Config,
		Stats = Stats,
		TradeJournal = TradeJournal,
		DataService = dataService,
		Remotes = { Notify = {
			FireClient = function(_, player, _kind, text)
				said[player] = text
			end,
		} },
		ActionService = {
			register = function(name, fn)
				handlers[name] = fn
			end,
		},
		AnalyticsService = { custom = function() end },
		ArtifactService = {
			addCopy = function(data, id)
				if not data.artifacts.found[id] then
					data.artifacts.found[id] = true
					return true
				end
				data.artifacts.spares[id] = (data.artifacts.spares[id] or 0) + 1
				return false
			end,
		},
		Events = {
			fire = function(name)
				fired[name] = (fired[name] or 0) + 1
			end,
		},
		GolemService = {
			get = function()
				return nil
			end,
		},
		PartyService = {
			sameParty = function()
				return true
			end,
			friendNow = function()
				return true
			end,
			areFriends = function()
				return true
			end,
		},
		PolicyService = {
			isReady = function()
				return true
			end,
			paidTradingAllowed = function()
				return true
			end,
		},
	}, mockGame, mockTask)
	local countdown = Config.Trading.countdownSeconds
	local cooldown = Config.Trading.requestCooldown
	Config.Trading.countdownSeconds = 0
	Config.Trading.requestCooldown = -1
	tradeService.start()
	queue = {} -- drop the idle-trade sweep loop started by start()

	local function join(id, spares)
		local player = { UserId = id, DisplayName = "P" .. id, AccountAge = 30, Parent = {} }
		byId[id] = player
		live[player] = if records[id] then copy(records[id]) else newData(spares)
		records[id] = copy(live[player])
		loaded:Fire(player)
		drain()
		return player
	end
	local function leave(player) -- a crash: the server forgets the player without saving
		live[player] = nil
		byId[player.UserId] = nil
		player.Parent = nil
	end
	local function trade(a, b, give, get)
		assert(handlers.tradeRequest(a, b.UserId))
		assert(handlers.tradeAccept(b, a.UserId))
		assert(handlers.tradeOffer(a, give))
		assert(handlers.tradeOffer(b, get))
		assert(handlers.tradeReady(a, true) and handlers.tradeReady(b, true))
		assert(handlers.tradeConfirm(a))
		assert(handlers.tradeConfirm(b))
	end

	-- 1. Normal trade: escrow, commit, both settled and saved.
	local a, b = join(1, { [X] = 1 }), join(2, { [Y] = 1 })
	trade(a, b, X, Y)
	assert(live[a].trades.pending and live[a].artifacts.spares[X] == nil, "Offered spares wait in escrow")
	drain()
	assert(live[a].artifacts.spares[Y] == 1 and live[b].artifacts.spares[X] == 1)
	assert(live[a].trades.pending == nil and live[b].trades.pending == nil)
	assert(
		records[1].artifacts.spares[Y] == 1 and records[2].artifacts.spares[X] == 1,
		"Both settled saves are written"
	)
	assert(live[a].trades.count == 1 and #live[b].trades.log == 1 and fired.traded == 1)
	assert(journalRecords["trade_g1"] == nil, "A trade both sides settled leaves no journal record")

	-- 2. b's save fails during escrow: the trade aborts and both get their spares back.
	a, b = join(3, { [X] = 1 }), join(4, { [Y] = 1 })
	failSave[b] = true
	trade(a, b, X, Y)
	drain()
	failSave[b] = nil
	assert(live[a].artifacts.spares[X] == 1 and live[b].artifacts.spares[Y] == 1)
	assert(live[a].trades.pending == nil and live[b].trades.pending == nil and fired.traded == 1)
	assert(records[3].artifacts.spares[X] == 1, "The returned spare is saved")
	assert(
		TradeJournal.status(journalRecords["trade_g2"]) == "aborted",
		"b's save never landed, so b hasn't marked and the record stays"
	)

	-- 3. The server crashes after a's escrow save, before b's: b never saved the
	-- trade, a's save holds it. On rejoin a asks the journal, finds no decision,
	-- writes "aborted" and gets the spare back. Nothing is lost or copied.
	a, b = join(5, { [X] = 1 }), join(6, { [Y] = 1 })
	trade(a, b, X, Y)
	local finishJob = table.remove(queue, 1)
	records[5] = copy(live[a]) -- only a's escrow save lands
	leave(a)
	leave(b)
	assert(records[5].trades.pending and records[6].trades.pending == nil)
	a, b = join(5), join(6)
	assert(live[a].artifacts.spares[X] == 1 and live[a].trades.pending == nil)
	assert(total(X, live[a], live[b]) == 1 and total(Y, live[a], live[b]) == 1)
	-- The old server's finish, if it ran late, must not commit over the abort.
	assert(TradeJournal.status(journalRecords["trade_g3"]) == "aborted")
	finishJob[1](table.unpack(finishJob[2], 1, finishJob[2].n))
	drain()
	assert(TradeJournal.status(journalRecords["trade_g3"]) == "aborted" and live[a].artifacts.spares[Y] == nil)

	-- 4. The trade commits, then the server crashes before either side settles:
	-- both saves hold escrow, the journal says committed, both finish on rejoin.
	a, b = join(7, { [X] = 1 }), join(8, { [Y] = 1 })
	trade(a, b, X, Y)
	records[7], records[8] = copy(live[a]), copy(live[b])
	journalRecords["trade_g4"] = TradeJournal.decide(nil, "committed", 0)
	queue = {}
	leave(a)
	leave(b)
	a = join(7)
	assert(live[a].artifacts.spares[Y] == 1 and live[a].artifacts.spares[X] == nil and live[a].trades.pending == nil)
	assert(records[7].trades.pending == nil, "The settled side is saved")
	b = join(8)
	assert(live[b].artifacts.spares[X] == 1 and live[b].artifacts.spares[Y] == nil)
	assert(total(X, live[a], live[b]) == 1 and total(Y, live[a], live[b]) == 1)
	assert(journalRecords["trade_g4"] == nil, "Removed once the second side settles on rejoin")

	-- 5. The journal can't be reached: the trade stays in escrow, trading is
	-- blocked with a clear message, and it settles once the journal is back.
	a, b = join(9, { [X] = 1 }), join(10, { [Y] = 1 })
	trade(a, b, X, Y)
	failJournal = true
	drain()
	assert(live[a].trades.pending and live[b].trades.pending, "Escrow stays until a decision is known")
	local ok, reason = handlers.tradeRequest(a, b.UserId)
	assert(not ok and reason and reason:find("still being saved"))
	assert(#delayed >= 2, "Settling is retried later")
	failJournal = false
	queue = {}
	for _, job in delayed do
		job[1](table.unpack(job[2], 1, job[2].n))
	end
	delayed = {}
	drain()
	assert(live[a].trades.pending == nil and live[b].trades.pending == nil)
	assert(total(X, live[a], live[b]) == 1 and total(Y, live[a], live[b]) == 1)
	assert(journalRecords["trade_g5"] == nil, "Settled after the outage, aborted, and cleaned up")

	-- 6. The trade commits and a settles, but b's settle save fails and the
	-- server dies: b's save still holds escrow. On rejoin b finds "committed",
	-- gets a's spare, and only then is the record removed.
	a, b = join(11, { [X] = 1 }), join(12, { [Y] = 1 })
	trade(a, b, X, Y)
	local finishSix = table.remove(queue, 1)
	finishSix[1](table.unpack(finishSix[2], 1, finishSix[2].n)) -- escrow saves land, then the decision
	failSave[b] = true -- b's settle save won't be written
	drain()
	assert(TradeJournal.status(journalRecords["trade_g6"]) == "committed", "Only a has marked, so it stays")
	assert(records[12].trades.pending, "b's last written save still holds escrow")
	failSave[b] = nil
	leave(a)
	leave(b)
	b = join(12)
	assert(live[b].trades.pending == nil and live[b].artifacts.spares[X] == 1, "b completes the committed trade")
	assert(journalRecords["trade_g6"] == nil, "Removed once b's settled save is written")
	a = join(11)
	assert(total(X, live[a], live[b]) == 1 and total(Y, live[a], live[b]) == 1)

	Config.Trading.countdownSeconds = countdown
	Config.Trading.requestCooldown = cooldown
	print(
		"PASS: actual TradeService escrow, commit, failed save, crashes before and after the decision, journal outage"
	)
end
