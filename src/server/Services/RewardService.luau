--!strict
-- Reasons to come back and keep playing: the daily login streak, daily and
-- weekly quests, session gifts, offline mining, and the group join reward.
-- All timing uses server time (os.time), never the client's clock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)
local PassService = require(script.Parent.PassService)

local RewardService = {}

local sessionClaims: { [Player]: { [number]: boolean } } = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

local function thisWeek(): number
	return math.floor((today() + 3) / 7) -- weeks start on Monday (UTC)
end

local function questById(id: string): any
	for _, quest in Config.QuestPool do
		if quest.id == id then
			return quest
		end
	end
	for _, quest in Config.WeeklyQuestPool do
		if quest.id == id then
			return quest
		end
	end
	return nil
end

---------------------------------------------------------------- quests

-- Rolls new daily quests each day and a new weekly quest each week.
-- Everyone gets the same quests on the same day.
local function ensureQuests(data: any)
	local quests = data.quests
	local day, week = today(), thisWeek()
	if quests.day ~= day then
		for _, id in quests.ids do
			quests.progress[id] = nil
			quests.claimed[id] = nil
		end
		local pool = table.clone(Config.QuestPool)
		local random = Random.new(day)
		quests.ids = {}
		for _ = 1, math.min(Config.DailyQuestCount, #pool) do
			local quest = table.remove(pool, random:NextInteger(1, #pool))
			table.insert(quests.ids, quest.id)
		end
		quests.day = day
	end
	if quests.week ~= week then
		if quests.weeklyId ~= "" then
			quests.progress[quests.weeklyId] = nil
			quests.claimed[quests.weeklyId] = nil
		end
		local random = Random.new(week)
		quests.weeklyId = Config.WeeklyQuestPool[random:NextInteger(1, #Config.WeeklyQuestPool)].id
		quests.week = week
	end
end

local function activeQuestIds(data: any): { string }
	local ids = table.clone(data.quests.ids)
	table.insert(ids, data.quests.weeklyId)
	return ids
end

local function onProgress(eventName: string)
	return function(player: Player)
		local data = DataService.get(player)
		if not data then
			return
		end
		local changed = false
		ensureQuests(data)
		for _, id in activeQuestIds(data) do
			local quest = questById(id)
			if quest and quest.event == eventName and not data.quests.claimed[id] then
				local progress = data.quests.progress[id] or 0
				if progress < quest.target then
					data.quests.progress[id] = progress + 1
					changed = true
					if progress + 1 == quest.target then
						Remotes.Notify:FireClient(player, "message", `Quest complete: {quest.text}! Claim it in Quests.`)
					end
				end
			end
		end
		if changed then
			DataService.markChanged(player)
		end
	end
end

local function claimQuest(player: Player, id: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(id) ~= "string" then
		return false, "Not ready"
	end
	ensureQuests(data)
	if not table.find(activeQuestIds(data), id) then
		return false, "That quest isn't active"
	end
	local quest = questById(id)
	if data.quests.claimed[id] then
		return false, "Already claimed"
	end
	if (data.quests.progress[id] or 0) < quest.target then
		return false, "Not finished yet"
	end
	DataService.update(player, function(d)
		d.quests.claimed[id] = true
	end)
	EconomyService.grantFlat(player, quest.reward, "quest")
	return true, "Quest reward claimed!"
end

---------------------------------------------------------------- daily streak

local function dailyState(data: any): (boolean, number)
	local daily = data.daily
	local day = today()
	if daily.lastClaimDay == day then
		return false, daily.streak
	end
	local keepsStreak = daily.lastClaimDay > 0 and day - daily.lastClaimDay <= 2
	return true, if keepsStreak then daily.streak + 1 else 1
end

local function claimDaily(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Not ready"
	end
	local canClaim, streak = dailyState(data)
	if not canClaim then
		return false, "Come back tomorrow!"
	end
	local reward = Config.DailyRewards[(streak - 1) % #Config.DailyRewards + 1]
	DataService.update(player, function(d)
		d.daily.streak = streak
		d.daily.lastClaimDay = today()
	end)
	EconomyService.grantFlat(player, reward, "daily")
	return true, `Day {streak} reward claimed!`
end

---------------------------------------------------------------- session gifts

local function claimSession(player: Player, index: any): (boolean, string?)
	local session = DataService.getSession(player)
	local gift = type(index) == "number" and Config.SessionRewards[index]
	if not session or not gift then
		return false, "Not ready"
	end
	local claims = sessionClaims[player] or {}
	sessionClaims[player] = claims
	if claims[index] then
		return false, "Already opened"
	end
	if (os.time() - session.loadedAt) / 60 < gift.minutes then
		return false, `Unlocks after {gift.minutes} minutes of play`
	end
	claims[index] = true
	EconomyService.grantFlat(player, gift, "session")
	DataService.markChanged(player)
	return true, "Gift opened!"
end

---------------------------------------------------------------- offline mining

local function grantOffline(player: Player)
	-- Wait for game pass ownership (2x Minerals, Long Rest) before calculating.
	for _ = 1, 20 do
		if PassService.isReady(player) or not player.Parent then
			break
		end
		task.wait(0.5)
	end
	local session = DataService.getSession(player)
	local data = DataService.get(player)
	if not session or not data or session.previousLogout <= 0 then
		return
	end
	local stats = Stats.compute(data, GolemService.context(player))
	local away = os.time() - session.previousLogout
	local seconds = math.min(away, stats.offlineCapHours * 3600)
	if seconds < Config.Offline.minSeconds then
		return
	end
	local minutes = seconds / 60
	local zone = Config.Zones[Stats.highestZone(data)]
	local minerals = {}
	for mineral, perMinute in zone.offlineMinerals do
		minerals[mineral] = math.floor(perMinute * minutes * stats.mineralMult)
	end
	DataService.addMinerals(player, minerals, "offline")
	Remotes.Notify:FireClient(player, "offline", math.floor(minutes), minerals, away > seconds)
end

---------------------------------------------------------------- group reward

local function checkGroup(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if Config.Group.id == 0 or not data then
		return false, "No group reward right now"
	end
	if data.groupRewardClaimed then
		return false, "Already claimed"
	end
	local ok, inGroup = pcall(function()
		return player:IsInGroup(Config.Group.id)
	end)
	if not ok or not inGroup then
		return false, "Join the group first, then try again"
	end
	DataService.update(player, function(d)
		d.groupRewardClaimed = true
	end)
	EconomyService.grantFlat(player, Config.Group.reward, "group")
	return true, "Thanks for joining the group!"
end

---------------------------------------------------------------- snapshot

local function snapshot(player: Player): any
	local data = DataService.get(player)
	if not data then
		return nil
	end
	ensureQuests(data)
	local quests = {}
	for index, id in activeQuestIds(data) do
		local quest = questById(id)
		if quest then
			table.insert(quests, {
				id = id,
				text = quest.text,
				weekly = index > #data.quests.ids,
				progress = math.min(data.quests.progress[id] or 0, quest.target),
				target = quest.target,
				claimed = data.quests.claimed[id] == true,
				reward = quest.reward,
			})
		end
	end
	local canClaimDaily, nextStreak = dailyState(data)
	-- Sent as a list: sparse number keys don't survive the trip to the client.
	local claimedGifts = {}
	for index in sessionClaims[player] or {} do
		table.insert(claimedGifts, index)
	end
	return {
		quests = quests,
		daily = { canClaim = canClaimDaily, streak = data.daily.streak, nextStreak = nextStreak },
		sessionClaimed = claimedGifts,
		groupId = Config.Group.id,
		groupClaimed = data.groupRewardClaimed,
	}
end

function RewardService.start()
	DataService.addProvider("rewards", snapshot)
	ActionService.register("claimQuest", claimQuest)
	ActionService.register("claimDaily", claimDaily)
	ActionService.register("claimSession", claimSession)
	ActionService.register("claimGroup", checkGroup)

	for _, eventName in { "enemyDefeated", "nodeMined", "spellCast", "bossDefeated", "partCrafted", "artifactFound" } do
		Events.connect(eventName, onProgress(eventName))
	end

	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(grantOffline, player)
		if Config.Group.id ~= 0 then
			task.spawn(checkGroup, player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessionClaims[player] = nil
	end)
end

return RewardService
