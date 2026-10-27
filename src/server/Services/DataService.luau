--!strict
-- Loads, holds, and saves each player's progress, and sends the client a
-- snapshot of it whenever it changes (at most every Config.Data.pushInterval).
-- Uses DataStoreService directly; swapping to ProfileStore for session
-- locking is a later improvement.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local Events = require(script.Parent.Events)

type Profile = {
	data: any,
	canSave: boolean,
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
	warn("[DataService] To save in Studio: File > Publish to Roblox, then Game Settings > Security > Enable Studio Access to API Services.")
end

local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}
local providers: { [string]: (Player) -> any } = {}

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
		minerals = minerals,
		golem = { xp = 0, parts = {} },
		bossesDefeated = {}, -- ["1"] = true
		artifacts = { found = {}, equipped = {}, pity = {} }, -- pity["drop1"] = rolls since last find
		skills = {},
		awakening = { count = 0, shards = 0, upgrades = {} },
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
	local snapshot: { [string]: any } = {
		data = profile.data,
		serverTime = os.time(),
		sessionStart = profile.loadedAt,
		canSave = profile.canSave,
	}
	for key, provider in providers do
		local ok, value = pcall(provider, player)
		if ok then
			snapshot[key] = value
		else
			warn(`[DataService] snapshot provider {key} failed: {value}`)
		end
	end
	Remotes.StateUpdate:FireClient(player, snapshot)
	updateLeaderstats(player, profile.data)
end

local function save(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return false
	end
	local data = profile.data
	local dataStore = store
	local ok = withRetries(`save {player.UserId}`, function()
		dataStore:UpdateAsync(storeKey(player), function()
			return data
		end)
	end)
	return ok
end

local function load(player: Player)
	local ok, saved = false, nil
	if store then
		local dataStore = store
		ok, saved = withRetries(`load {player.UserId}`, function()
			return dataStore:GetAsync(storeKey(player))
		end)
	end

	local canSave = true
	local data: any
	if ok then
		data = if type(saved) == "table" then saved else defaultData()
		reconcile(data, defaultData())
	elseif RunService:IsStudio() then
		warn("[DataService] Could not load data in Studio; playing without saving.")
		data = defaultData()
		canSave = false
	else
		-- Never play on default data in a live server: saving would wipe progress.
		player:Kick("We couldn't load your golem. Please rejoin in a moment.")
		return
	end

	if not player.Parent then
		return -- left while loading
	end
	profiles[player] = {
		data = data,
		canSave = canSave,
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

-- Adds a field to every snapshot sent to that player's client.
function DataService.addProvider(key: string, provider: (Player) -> any)
	providers[key] = provider
end

-- Marks a player's data as changed: the client gets a fresh snapshot soon,
-- and listeners (like golem stats) recalculate.
function DataService.markChanged(player: Player)
	if profiles[player] then
		dirty[player] = true
		changedEvent:Fire(player)
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
		save(player)
		profiles[player] = nil
		dirty[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			profile.data.lastLogout = os.time()
			pending += 1
			task.spawn(function()
				save(player)
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
			for player in dirty do
				dirty[player] = nil
				sendSnapshot(player)
			end
		end
	end)
end

return DataService
