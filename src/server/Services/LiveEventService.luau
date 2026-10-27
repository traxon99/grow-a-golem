--!strict
-- Limited-time events from Config.Events. Their multipliers live in
-- Stats.compute (so the menus show the same numbers); this service tells
-- players when an event starts or ends, refreshes golem stats at that
-- moment, and runs each event's reward track. Event currency is earned only
-- by playing during the event, and there is no way to buy it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Events)

local LiveEventService = {}

local CHECK_INTERVAL = 5

-- The player's progress on an event's track. A run is identified by the time
-- it started: a finished track starts over when a new run begins, and an
-- unfinished one carries over so missing a weekend isn't punishing.
local function trackState(data: any, event: any, runStartsAt: number?): any
	local state = data.eventTracks[event.id]
	if not state then
		state = { tokens = 0, claimed = {}, run = 0 }
		data.eventTracks[event.id] = state
	end
	if runStartsAt and state.run ~= runStartsAt then
		local finished = true
		for index in event.track.tiers do
			if not state.claimed[tostring(index)] then
				finished = false
			end
		end
		if finished then
			state.tokens = 0
			state.claimed = {}
		end
		state.run = runStartsAt
	end
	return state
end

local function onPlay(eventName: string)
	return function(player: Player)
		local data = DataService.get(player)
		if not data then
			return
		end
		local changed = false
		for _, entry in Stats.activeEvents(os.time()) do
			local track = entry.event.track
			local amount = track and track.earn[eventName]
			if amount then
				local state = trackState(data, entry.event, entry.startsAt)
				state.tokens += amount
				changed = true
			end
		end
		if changed then
			DataService.markChanged(player)
		end
	end
end

local function claimTier(player: Player, eventId: any, index: any): (boolean, string?)
	local data = DataService.get(player)
	local event = type(eventId) == "string" and Stats.eventById(eventId)
	local tier = event and event.track and type(index) == "number" and event.track.tiers[index]
	if not data or not event or not tier then
		return false, "Not ready"
	end
	-- Rewards can be claimed after the event ends too.
	local state = trackState(data, event, nil)
	local key = tostring(index)
	if state.claimed[key] then
		return false, "Already claimed"
	end
	if state.tokens < tier.tokens then
		return false, `Earn {tier.tokens - state.tokens} more {event.track.currency} first`
	end
	DataService.update(player, function()
		state.claimed[key] = true
	end)
	EconomyService.grantFlat(player, tier.reward, "event")
	Events.fire("eventRewardClaimed", player, event.id, index)
	return true, "Event reward claimed!"
end

local function activeIds(now: number): { [string]: boolean }
	local ids = {}
	for _, entry in Stats.activeEvents(now) do
		ids[entry.event.id] = true
	end
	return ids
end

local function announce(text: string)
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, "message", text)
	end
end

function LiveEventService.start()
	ActionService.register("claimEventTier", claimTier)
	for _, eventName in { "enemyDefeated", "nodeMined", "bossDefeated" } do
		Events.connect(eventName, onPlay(eventName))
	end

	task.spawn(function()
		local running = activeIds(os.time())
		while true do
			task.wait(CHECK_INTERVAL)
			local now = os.time()
			local current = activeIds(now)
			local changed = false
			for id in current do
				if not running[id] then
					changed = true
					announce(`{Stats.eventById(id).name} has started!`)
				end
			end
			for id in running do
				if not current[id] then
					changed = true
					announce(`{Stats.eventById(id).name} has ended. Thanks for playing!`)
				end
			end
			running = current
			if changed then
				-- Golem stats (and their multipliers) recalculate on a data change.
				for _, player in Players:GetPlayers() do
					DataService.markChanged(player)
				end
			end
		end
	end)
end

return LiveEventService
