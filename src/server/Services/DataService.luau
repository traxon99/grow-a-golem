--!strict
-- Loads, holds, and saves each player's progress, and sends the client a
-- snapshot of it whenever it changes (at most every Config.Data.pushInterval).
-- Atomic per-record session leases prevent a previous server overwriting a
-- newer session. Failed loads never write default progress in live servers.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))
local SessionLease = require(Shared:WaitForChild("SessionLease"))

local Events = require(script.Parent.Events)

type Profile = {
	data: any,
	canSave: boolean,
	token: string,
	saving: boolean,
	released: boolean,
	loadedAt: number, -- os.time() when this session started
	previousLogout: number, -- lastLogout from the save, before this session
}

local DataService = {}

-- GetDataStore throws in a place that hasn't been published yet. Catch it so
-- the rest of the game still runs (without saving) instead of failing to load.
local storeOk, storeOrError = pcall(function()
	return DataStoreService:GetDataStore(Config.Data.storeName)
end)
local store: DataStore? = if storeOk then storeOrError else nil
if not store then
	warn(`[DataService] DataStores unavailable, progress will NOT save: {storeOrError}`)
	warn(
		"[DataService] To save in Studio: File > Publish to Roblox, then Game Settings > Security > Enable Studio Access to API Services."
	)
end

local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}
local pendingChanged: { [Player]: boolean } = {}
-- Slow providers are omitted from repeat packets; the client merges them
-- into its last snapshot. Fast providers (interval 0) still run each push.
local providers: { [string]: { get: (Player) -> any, interval: number } } = {}
local providerNextAt: { [Player]: { [string]: number } } = {}

local loadedEvent = Instance.new("BindableEvent")
DataService.ProfileLoaded = loadedEvent.Event -- (player)
local changedEvent = Instance.new("BindableEvent")
DataService.Changed = changedEvent.Event -- (player)

local function defaultData(): any
	local minerals = {}
	for _, id in Config.MineralOrder do
		minerals[id] = 0
	end
	return {
		version = 1,
		campaign = {
			version = 0, -- stamped only after legacy gates and parts are evaluated
			regions = { [tostring(Config.Kingdom.startingRegion)] = true },
			abilities = {},
			discoveries = {},
			obstacles = {},
			projects = {},
			titan = {},
		},
		minerals = minerals,
		golem = { xp = 0, parts = {} },
		bossesDefeated = {}, -- ["1"] = true
		artifacts = { found = {}, equipped = {}, bags = {}, spareBags = {}, spares = {}, boundSpares = {} }, -- bags["drop1"] = { drawn, wins } in the marble bag for that island and source (MarbleBag); spareBags["drop1"] = spare ids left to draw; spares[id] = extra copies, boundSpares[id] = how many of those can't be traded
		skills = {},
		coreUpgrades = {}, -- mineral-funded ranks for this run
		awakening = { count = 0, shards = 0, upgrades = {} },
		ascension = { count = 0, points = 0, spentAwakenings = 0, upgrades = {} },
		daily = { streak = 0, lastClaimDay = 0 },
		quests = { day = 0, week = 0, ids = {}, weeklyId = "", progress = {}, claimed = {} },
		boosts = { xp = 0, luck = 0 },
		receipts = {},
		groupRewardClaimed = false,
		codesRedeemed = {}, -- ["GOLEM100"] = os.time() when redeemed
		eventTracks = {}, -- [eventId] = { tokens, claimed = { ["1"] = true }, run }
		lastLogout = 0,
		totals = { enemies = 0, nodes = 0, bosses = 0 },
		tutorial = { step = 0, done = false }, -- step 0 = not started yet
		cosmetics = { owned = {}, equipped = {} }, -- owned[id] = true, equipped[slot] = id
		social = { title = "", announce = true, partyInvites = "friends" }, -- invite choices: everyone, friends, off
		trades = { day = 0, count = 0, log = {} }, -- completed trades today, and a record of recent ones
	}
end

-- Fills in any fields added since the save was written.
local function reconcile(target: any, template: any)
	for key, value in template do
		if target[key] == nil then
			target[key] = value
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
end

-- Older trade saves kept the partner's UserId in logs and pending escrow.
-- Neither field is needed for journal recovery or the daily trade limit.
-- Remove it during the lease-acquisition write so even a session that never
-- reaches autosave persists the redaction.
local function redactTradePartners(data: any)
	local trades = data.trades
	if type(trades) ~= "table" then
		return
	end
	if type(trades.log) == "table" then
		for _, entry in trades.log do
			if type(entry) == "table" then
				entry.with = nil
			end
		end
	end
	if type(trades.pending) == "table" then
		trades.pending.with = nil
	end
end

-- Saves from before marble bags (#156) counted misses in artifacts.pity.
-- Carry them into the bags, stopping one marble short of the end, so a find
-- the menus already showed as close stays close.
local function migratePity(data: any)
	local pity = data.artifacts.pity
	if type(pity) ~= "table" then
		return
	end
	for key, rolls in pity do
		local source = string.match(key, "^%a+")
		local def = source and Config.ArtifactBags[source]
		if def and type(rolls) == "number" and rolls > 0 and data.artifacts.bags[key] == nil then
			data.artifacts.bags[key] = { drawn = math.min(math.floor(rolls), def.marbles - 1), wins = 0 }
		end
	end
	data.artifacts.pity = nil
end

local function storeKey(player: Player): string
	return "player_" .. player.UserId
end

local function withRetries(label: string, fn: () -> any): (boolean, any)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[DataService] {label} failed (attempt {attempt}): {result}`)
		task.wait(attempt * 2)
	end
	return false, nil
end

local function setupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in { "Level", "Awakenings" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player
end

local function updateLeaderstats(player: Player, data: any)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local level = leaderstats:FindFirstChild("Level") :: IntValue?
	local awakenings = leaderstats:FindFirstChild("Awakenings") :: IntValue?
	if level then
		level.Value = Stats.levelForXp(data.golem.xp)
	end
	if awakenings then
		awakenings.Value = data.awakening.count
	end
end

local function sendSnapshot(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local clientData = SessionLease.copy(profile.data)
	-- Receipt IDs, code history, trade logs and escrow are server-only.
	clientData._session = nil
	clientData.receipts = nil
	clientData.codesRedeemed = nil
	if clientData.trades then
		clientData.trades.log = nil
		clientData.trades.pending = nil
	end
	-- Explicit campaign projection keeps future server bookkeeping private.
	local campaign = profile.data.campaign
	clientData.campaign = {
		regions = SessionLease.copy(campaign.regions),
		abilities = SessionLease.copy(campaign.abilities),
		discoveries = SessionLease.copy(campaign.discoveries),
		obstacles = SessionLease.copy(campaign.obstacles),
		projects = SessionLease.copy(campaign.projects),
		titan = SessionLease.copy(campaign.titan),
	}
	local snapshot: { [string]: any } = {
		data = clientData,
		serverTime = os.time(),
		sessionStart = profile.loadedAt,
		canSave = profile.canSave,
	}
	local nextAt = providerNextAt[player]
	if not nextAt then
		nextAt = {}
		providerNextAt[player] = nextAt
	end
	local now = os.clock()
	for key, provider in providers do
		if (nextAt[key] or 0) <= now then
			local ok, value = pcall(provider.get, player)
			if ok then
				snapshot[key] = value
				nextAt[key] = now + provider.interval
			else
				warn(`[DataService] snapshot provider {key} failed: {value}`)
			end
		end
	end
	Remotes.StateUpdate:FireClient(player, snapshot)
	updateLeaderstats(player, profile.data)
end

local function save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return false
	end
	-- Serialize saves, including release, so an older snapshot cannot finish last.
	while profile.saving do
		task.wait()
	end
	if profile.released or not profile.canSave then
		return false
	end
	profile.saving = true
	local data = SessionLease.copy(profile.data)
	local dataStore = store
	local lostLease = false
	local ok = withRetries(`save {player.UserId}`, function()
		local result = dataStore:UpdateAsync(storeKey(player), function(current)
			if not SessionLease.owns(current, profile.token) then
				lostLease = true
				return nil
			end
			data._session = if release
				then nil
				else {
					token = profile.token,
					expiresAt = os.time() + Config.Data.sessionLeaseSeconds,
				}
			return data
		end)
		if result == nil then
			lostLease = true
		end
		return nil
	end)
	profile.saving = false
	if lostLease then
		profile.canSave = false
		player:Kick("Golem opened elsewhere. Please rejoin.")
		return false
	end
	if ok and release then
		profile.released = true
	end
	return ok
end

local function load(player: Player)
	local ok, saved = false, nil
	local token = HttpService:GenerateGUID(false)
	if store then
		local dataStore = store
		ok, saved = withRetries(`load {player.UserId}`, function()
			return dataStore:UpdateAsync(storeKey(player), function(current)
				if not SessionLease.canAcquire(current, token, os.time()) then
					return nil
				end
				local data = if type(current) == "table" then current else defaultData()
				redactTradePartners(data)
				data._session = { token = token, expiresAt = os.time() + Config.Data.sessionLeaseSeconds }
				return data
			end)
		end)
	end

	local canSave = true
	local data: any
	if ok and not SessionLease.owns(saved, token) then
		player:Kick("Still saving your golem. Rejoin soon.")
		return
	end
	if ok then
		data = if type(saved) == "table" then saved else defaultData()
		reconcile(data, defaultData())
		redactTradePartners(data)
		migratePity(data)
		Stats.migrateCampaign(data)
	elseif RunService:IsStudio() then
		warn("[DataService] Could not load data in Studio; playing without saving.")
		data = defaultData()
		Stats.migrateCampaign(data)
		canSave = false
	else
		-- Never play on default data in a live server: saving would wipe progress.
		player:Kick("Couldn't load your golem. Please rejoin soon.")
		return
	end

	if not player.Parent then
		-- Release a lease acquired after the player disconnected, without
		-- writing defaults or changing the original logout timestamp.
		if ok and store then
			local dataStore = store
			withRetries(`release abandoned load {player.UserId}`, function()
				dataStore:UpdateAsync(storeKey(player), function(current)
					if not SessionLease.owns(current, token) then
						return nil
					end
					current._session = nil
					return current
				end)
				return nil
			end)
		end
		return
	end
	profiles[player] = {
		data = data,
		canSave = canSave,
		token = token,
		saving = false,
		released = false,
		loadedAt = os.time(),
		previousLogout = data.lastLogout,
	}
	setupLeaderstats(player)
	loadedEvent:Fire(player)
	sendSnapshot(player)
end

---------------------------------------------------------------- public API

function DataService.get(player: Player): any
	local profile = profiles[player]
	return profile and profile.data
end

function DataService.getSession(player: Player): Profile?
	return profiles[player]
end

-- Providers with an interval are sent only on first load, invalidation,
-- or expiry. The client retains their last value between partial updates.
function DataService.addProvider(key: string, provider: (Player) -> any, intervalSeconds: number?)
	providers[key] = { get = provider, interval = intervalSeconds or 0 }
end

-- Recompute a slow provider for one player, or for every loaded player.
function DataService.invalidateProvider(key: string, player: Player?)
	if player then
		if providerNextAt[player] then
			providerNextAt[player][key] = nil
		end
		DataService.markChanged(player)
	else
		for other in profiles do
			if providerNextAt[other] then
				providerNextAt[other][key] = nil
			end
			DataService.markChanged(other)
		end
	end
end

-- Coalesce expensive Changed listeners once per player per scheduler tick.
function DataService.markChanged(player: Player)
	if not profiles[player] then
		return
	end
	dirty[player] = true
	if pendingChanged[player] then
		return
	end
	pendingChanged[player] = true
	task.defer(function()
		pendingChanged[player] = nil
		if profiles[player] then
			changedEvent:Fire(player)
		end
	end)
end

-- Flushes queued snapshots; also called by the periodic push loop.
function DataService.flushPending()
	for player in dirty do
		dirty[player] = nil
		sendSnapshot(player)
	end
end

-- Runs fn on the player's data, then marks it changed. Returns false if not loaded.
function DataService.update(player: Player, fn: (any) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	fn(profile.data)
	DataService.markChanged(player)
	return true
end

-- Raw grants with no multipliers. Use EconomyService for gameplay rewards.
-- `source` says where they came from ("mining", "quest"...) for analytics.
function DataService.addMinerals(player: Player, minerals: { [string]: number }, source: string?)
	local given = {}
	local ok = DataService.update(player, function(data)
		for id, amount in minerals do
			if Config.Minerals[id] and amount > 0 then
				given[id] = math.floor(amount)
				data.minerals[id] = (data.minerals[id] or 0) + given[id]
			end
		end
	end)
	if ok then
		Events.fire("mineralsGained", player, given, source or "other")
	end
end

function DataService.addXp(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	DataService.update(player, function(data)
		data.golem.xp += math.floor(amount)
	end)
end

-- Removes a cost if the player can afford all of it. Returns success.
-- `sink` says what it was spent on ("forge"...) for analytics.
function DataService.spend(player: Player, cost: { [string]: number }, sink: string?): boolean
	local data = DataService.get(player)
	if not data or not Stats.canAfford(data, cost) then
		return false
	end
	DataService.update(player, function(d)
		for id, amount in cost do
			d.minerals[id] -= amount
		end
	end)
	Events.fire("mineralsSpent", player, cost, sink or "other")
	return true
end

-- Saves right away (used after purchases). Returns true only if it was written.
function DataService.saveNow(player: Player): boolean
	return save(player)
end

function DataService.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile.data.lastLogout = os.time()
		end
		save(player, true)
		profiles[player] = nil
		dirty[player] = nil
		pendingChanged[player] = nil
		providerNextAt[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			profile.data.lastLogout = os.time()
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Data.autosaveInterval)
			for player, profile in profiles do
				profile.data.lastLogout = os.time()
				task.spawn(save, player)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Data.pushInterval)
			DataService.flushPending()
		end
	end)
end

return DataService
