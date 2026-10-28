--!strict
-- Global leaderboards (top level, most Awakenings, most artifacts found),
-- stored in OrderedDataStores and refreshed every few minutes.
-- Does nothing (quietly) when DataStores aren't available, e.g. an
-- unpublished place in Studio.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Stats = require(Shared:WaitForChild("Stats"))

local DataService = require(script.Parent.DataService)

type Entry = { name: string, value: number }

local LeaderboardService = {}

local stores: { [string]: OrderedDataStore } = {}
local boards: { [string]: { Entry } } = {}
local nameCache: { [number]: string } = {}
local lastWritten: { [string]: { [number]: number } } = {}

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

-- Fetch display names once for the page, rather than yielding on every row.
-- Failed or missing names are not cached, so the next refresh can retry.
local function cacheDisplayNames(page: { any })
	local missing: { number } = {}
	for _, row in page do
		local userId = tonumber(row.key)
		if userId and not nameCache[userId] then
			table.insert(missing, userId)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and infos then
		for _, info in infos do
			if type(info.DisplayName) == "string" and info.DisplayName ~= "" then
				nameCache[info.Id] = info.DisplayName
			end
		end
	end
end

local function refresh()
	for _, board in Config.Leaderboards.boards do
		local store = stores[board.id]
		if store then
			local written = lastWritten[board.id]
			for _, player in Players:GetPlayers() do
				local session = DataService.getSession(player)
				if session and session.canSave then
					local value = valueFor(board.id, session.data)
					if written[player.UserId] ~= value then
						local ok = pcall(function()
							store:SetAsync(tostring(player.UserId), value)
						end)
						if ok then
							written[player.UserId] = value
						end
					end
				end
			end
			local ok, page = pcall(function()
				return store:GetSortedAsync(false, Config.Leaderboards.size):GetCurrentPage()
			end)
			if ok and page then
				cacheDisplayNames(page)
				local entries = {}
				for _, row in page do
					local userId = tonumber(row.key)
					if userId then
						table.insert(entries, { name = nameCache[userId] or "Player", value = row.value })
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
			lastWritten[board.id] = {}
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
