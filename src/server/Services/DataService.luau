--!strict
-- Loads, holds, and saves each player's progress.
-- Milestone 1 uses DataStoreService directly; we swap to ProfileStore
-- (session locking) once the GitHub/Wally setup is in place.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

export type PlayerData = {
	version: number,
	minerals: { [string]: number },
	golem: { xp: number },
}

type Profile = {
	data: PlayerData,
	canSave: boolean,
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

local loadedEvent = Instance.new("BindableEvent")
DataService.ProfileLoaded = loadedEvent.Event -- fires (player)

local function defaultData(): PlayerData
	local minerals = {}
	for _, id in Config.MineralOrder do
		minerals[id] = 0
	end
	return { version = 1, minerals = minerals, golem = { xp = 0 } }
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

local function setupLeaderstats(player: Player, data: PlayerData)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, id in Config.MineralOrder do
		local value = Instance.new("IntValue")
		value.Name = Config.Minerals[id].displayName
		value.Value = data.minerals[id]
		value.Parent = leaderstats
	end
	leaderstats.Parent = player
end

local function pushState(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	Remotes.StateUpdate:FireClient(player, {
		minerals = profile.data.minerals,
		xp = profile.data.golem.xp,
	})
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		for _, id in Config.MineralOrder do
			local value = leaderstats:FindFirstChild(Config.Minerals[id].displayName) :: IntValue?
			if value then
				value.Value = profile.data.minerals[id]
			end
		end
	end
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return
	end
	local data = profile.data
	local dataStore = store
	withRetries(`save {player.UserId}`, function()
		dataStore:UpdateAsync(storeKey(player), function()
			return data
		end)
	end)
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
	local data: PlayerData
	if ok then
		data = if type(saved) == "table" then saved else defaultData()
		reconcile(data, defaultData())
	elseif RunService:IsStudio() then
		-- Usually means "Enable Studio Access to API Services" is off.
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
	profiles[player] = { data = data, canSave = canSave }
	setupLeaderstats(player, data)
	pushState(player)
	loadedEvent:Fire(player)
end

function DataService.get(player: Player): PlayerData?
	local profile = profiles[player]
	return profile and profile.data
end

function DataService.addMineral(player: Player, mineralId: string, amount: number)
	local profile = profiles[player]
	if not profile or Config.Minerals[mineralId] == nil or amount <= 0 then
		return
	end
	profile.data.minerals[mineralId] += math.floor(amount)
	pushState(player)
end

function DataService.addXp(player: Player, amount: number)
	local profile = profiles[player]
	if not profile or amount <= 0 then
		return
	end
	profile.data.golem.xp += math.floor(amount)
	pushState(player)
end

function DataService.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
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
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)
end

return DataService
