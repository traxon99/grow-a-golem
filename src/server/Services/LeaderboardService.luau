--!strict
-- Global leaderboards (top level, most Awakenings, most artifacts found),
-- stored in OrderedDataStores and refreshed every few minutes.
-- Does nothing (quietly) when DataStores aren't available, e.g. an
-- unpublished place in Studio.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Stats = require(Shared:WaitForChild("Stats"))

local DataService = require(script.Parent.DataService)

type Entry = { name: string, value: number }

local LeaderboardService = {}

local stores: { [string]: OrderedDataStore } = {}
local boards: { [string]: { Entry } } = {}
local nameCache: { [number]: string } = {}

local function valueFor(boardId: string, data: any): number
	if boardId == "level" then
		return Stats.levelForXp(data.golem.xp)
	elseif boardId == "awakenings" then
		return data.awakening.count
	elseif boardId == "artifacts" then
		return Stats.artifactsFound(data)
	end
	return 0
end

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok and name then name else "Player"
	return nameCache[userId]
end

local function refresh()
	for _, board in Config.Leaderboards.boards do
		local store = stores[board.id]
		if store then
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					pcall(function()
						store:SetAsync(tostring(player.UserId), valueFor(board.id, data))
					end)
				end
			end
			local ok, page = pcall(function()
				return store:GetSortedAsync(false, Config.Leaderboards.size):GetCurrentPage()
			end)
			if ok and page then
				local entries = {}
				for _, row in page do
					local userId = tonumber(row.key)
					if userId then
						table.insert(entries, { name = nameFor(userId), value = row.value })
					end
				end
				boards[board.id] = entries
			end
		end
	end
	for _, player in Players:GetPlayers() do
		DataService.markChanged(player)
	end
end

function LeaderboardService.start()
	for _, board in Config.Leaderboards.boards do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(board.store)
		end)
		if ok then
			stores[board.id] = store
		end
	end
	DataService.addProvider("leaderboards", function()
		return boards
	end)
	if next(stores) == nil then
		return
	end
	task.spawn(function()
		task.wait(10)
		while true do
			refresh()
			task.wait(Config.Leaderboards.refreshSeconds)
		end
	end)
end

return LeaderboardService
