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
	local records, snapshots = {}, {}
	local deferred = {}
	local testTask = {
		spawn = function() end,
		wait = function() end,
		defer = function(fn)
			table.insert(deferred, fn)
		end,
	}
	local function runDeferred()
		while #deferred > 0 do
			local jobs = deferred
			deferred = {}
			for _, fn in jobs do
				fn()
			end
		end
	end
	local fail, studio, guid, afterWrite = false, false, 0, nil
	local store = {
		UpdateAsync = function(_, key, transform)
			if fail then
				error("simulated API failure")
			end
			local value = transform(SessionLease.copy(records[key]))
			if value then
				records[key] = SessionLease.copy(value)
			end
			if afterWrite then
				local fn = afterWrite
				afterWrite = nil
				fn()
			end
			return SessionLease.copy(value)
		end,
	}
	local players = {
		PlayerAdded = signal(),
		PlayerRemoving = signal(),
		GetPlayers = function()
			return {}
		end,
	}
	local services = {
		DataStoreService = {
			GetDataStore = function()
				return store
			end,
		},
		Players = players,
		ReplicatedStorage = {
			WaitForChild = function()
				return {}
			end,
		},
		RunService = {
			IsStudio = function()
				return studio
			end,
		},
		HttpService = {
			GenerateGUID = function()
				guid += 1
				return tostring(guid)
			end,
		},
	}
	local mockGame = {
		GetService = function(_, key)
			return services[key]
		end,
		BindToClose = function() end,
	}
	local mockInstance = {
		new = function(kind)
			if kind == "BindableEvent" then
				local event = signal()
				return {
					Event = event,
					Fire = function(_, ...)
						event:Fire(...)
					end,
				}
			end
			return {}
		end,
	}
	local dataService = loadDataService({
		Config = Config,
		Stats = Stats,
		SessionLease = SessionLease,
		Events = { fire = function() end },
		Remotes = { StateUpdate = {
			FireClient = function(_, who, snap)
				snapshots[who] = snap
			end,
		} },
	}, mockGame, mockInstance, testTask)
	dataService.start()
	local function player(id)
		return {
			UserId = id,
			Parent = {},
			FindFirstChild = function()
				return nil
			end,
			Kick = function(self, reason)
				self.kicked = reason
			end,
		}
	end
	local a = player(1)
	players.PlayerAdded:Fire(a)
	assert(dataService.get(a) and not a.kicked)
	assert(snapshots[a].data._session == nil, "Lease token must not reach clients")
	assert(snapshots[a].data.receipts == nil and snapshots[a].data.codesRedeemed == nil)
	assert(snapshots[a].data.trades.log == nil and snapshots[a].data.trades.pending == nil)
	assert(dataService.get(a).receipts ~= nil and dataService.get(a).trades.log ~= nil, "save fields must remain")
	assert(dataService.get(a).minerals.aether == 0 and dataService.get(a).ascension.spentAwakenings == 0)
	-- Rapid mutations notify expensive listeners once per scheduler tick.
	local changedCalls, fastCalls, slowCalls = 0, 0, 0
	dataService.Changed:Connect(function(who)
		if who == a then
			changedCalls += 1
		end
	end)
	dataService.addProvider("fast", function()
		fastCalls += 1
		return { tick = fastCalls }
	end)
	dataService.addProvider("slow", function()
		slowCalls += 1
		return { tick = slowCalls }
	end, math.huge)
	dataService.markChanged(a)
	dataService.markChanged(a)
	assert(#deferred == 1 and changedCalls == 0)
	runDeferred()
	assert(changedCalls == 1)
	dataService.flushPending()
	assert(fastCalls == 1 and slowCalls == 1)
	assert(snapshots[a].fast.tick == 1 and snapshots[a].slow.tick == 1)
	dataService.markChanged(a)
	runDeferred()
	dataService.flushPending()
	assert(changedCalls == 2 and fastCalls == 2 and slowCalls == 1)
	assert(snapshots[a].slow == nil, "unchanged slow providers are sparse")
	dataService.invalidateProvider("slow", a)
	runDeferred()
	dataService.flushPending()
	assert(slowCalls == 2 and snapshots[a].slow.tick == 2)
	dataService.get(a).minerals.stone = 50
	assert(dataService.saveNow(a))
	assert(records.player_1.minerals.stone == 50)
	local b = player(1)
	players.PlayerAdded:Fire(b)
	assert(b.kicked and dataService.get(b) == nil, "An active lease must deny a fast hop")
	assert(records.player_1.minerals.stone == 50)
	-- A crashed lease expires, allowing a new server to acquire it.
	records.player_1._session.expiresAt = 0
	local c = player(1)
	players.PlayerAdded:Fire(c)
	assert(not c.kicked and dataService.get(c).minerals.stone == 50)
	dataService.get(a).minerals.stone = 1000
	assert(not dataService.saveNow(a) and a.kicked)
	assert(not dataService.getSession(a).canSave and records.player_1.minerals.stone == 50)
	players.PlayerRemoving:Fire(c)
	assert(records.player_1._session == nil and dataService.get(c) == nil)
	local d = player(1)
	players.PlayerAdded:Fire(d)
	assert(not d.kicked and dataService.get(d).minerals.stone == 50)
	-- A disconnect while acquiring must release ownership without a profile.
	local e = player(2)
	afterWrite = function()
		e.Parent = nil
	end
	players.PlayerAdded:Fire(e)
	assert(dataService.get(e) == nil and records.player_2._session == nil)
	fail = true
	local live = player(3)
	players.PlayerAdded:Fire(live)
	assert(live.kicked and dataService.get(live) == nil and records.player_3 == nil)
	studio = true
	local unsaved = player(4)
	players.PlayerAdded:Fire(unsaved)
	assert(not unsaved.kicked and dataService.get(unsaved))
	assert(not dataService.getSession(unsaved).canSave and not dataService.saveNow(unsaved))
	assert(records.player_4 == nil)
	-- A save from before marble bags keeps its miss counts as bag progress.
	studio, fail = false, false
	records.player_5 = { artifacts = { found = {}, equipped = {}, pity = { drop1 = 299, boss2 = 1 } } }
	local old = player(5)
	players.PlayerAdded:Fire(old)
	local migrated = dataService.get(old).artifacts
	assert(migrated.pity == nil, "the old pity counts are moved, not kept")
	assert(migrated.bags.drop1.drawn == Config.ArtifactBags.drop.marbles - 1, "a near-pity find stays sure")
	assert(migrated.bags.boss2.drawn == 1 and migrated.bags.boss2.wins == 0)
	-- Legacy trade history and unfinished escrow may contain a partner UserId.
	-- Lease acquisition must persist their removal, even before autosave.
	records.player_6 = {
		trades = {
			day = 10,
			count = 1,
			log = { { t = 100, with = 12345, gave = { "relic" }, got = {} } },
			pending = { id = "legacy", with = 67890, gave = {}, got = {}, day = 10, at = 100, side = "a" },
		},
	}
	local legacy = player(6)
	players.PlayerAdded:Fire(legacy)
	assert(not legacy.kicked and dataService.get(legacy))
	assert(dataService.get(legacy).trades.log[1].with == nil)
	assert(dataService.get(legacy).trades.pending.with == nil)
	assert(records.player_6.trades.log[1].with == nil and records.player_6.trades.pending.with == nil)
	assert(records.player_6.trades.log[1].t == 100 and records.player_6.trades.pending.id == "legacy")
	print(
		"PASS: actual DataService acquisition/save/release, expired takeover, stale writes, abandoned loads, failed live/Studio loads"
	)
end
