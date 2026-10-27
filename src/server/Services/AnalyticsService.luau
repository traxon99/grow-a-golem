--!strict
-- Sends gameplay events to Roblox Analytics, which fills the Creator
-- Dashboard's Funnels, Economy and Custom Events views. It listens to the
-- Events bus, so gameplay code only fires events and never calls analytics.
--
-- Rules:
--   * Every Roblox call is wrapped in pcall, so analytics can never break a
--     service (it also fails quietly in Studio before the place is published).
--   * Only gameplay facts are logged: no chat, names or other personal info.
--   * Busy events (mineral income, spell casts) are added up and sent once a
--     minute, which keeps us inside Roblox's per-server rate limits.
--
-- What shows up in the dashboard:
--   Onboarding funnel  tutorial steps, then first boss fought and beaten
--   Funnel "Zones"     per island: unlocked, entered, boss fought, boss beaten
--   Funnel "Shop"      opened, purchase prompted, purchase completed
--   Progression        "Golem level" and "Awakening"
--   Economy            each mineral, tagged by source and sink (see SOURCES)
--   Custom events      SpellsCast, ArtifactFound, PartyJoined, CodeRedeemed,
--                      EventRewardClaimed, ItemPreviewed, CosmeticUnlocked

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxAnalytics = game:GetService("AnalyticsService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)

local FLUSH_INTERVAL = 60
local MAX_TRACKS_PER_WINDOW = 10 -- client Track messages per player per window
local TRACK_WINDOW = 10

-- Where minerals come from or go, and the Roblox transaction type each one
-- is filed under. Anything not listed is logged as "other" / Gameplay.
local SOURCES: { [string]: string } = {
	mining = "Gameplay",
	enemy = "Gameplay",
	boss = "Gameplay",
	relic = "Gameplay",
	quest = "Gameplay",
	event = "Gameplay",
	code = "Gameplay",
	daily = "TimedReward",
	session = "TimedReward",
	offline = "TimedReward",
	group = "TimedReward",
	tutorial = "Onboarding",
	purchase = "IAP",
	-- sinks
	forge = "Shop",
	respec = "Shop",
	awaken = "Gameplay",
	ascend = "Gameplay",
}

local AnalyticsService = {}

type Pending = { flow: string, source: string, mineral: string, amount: number, balance: number }

local pendingEconomy: { [Player]: { [string]: Pending } } = {}
local pendingSpells: { [Player]: { [string]: number } } = {}
local logged: { [Player]: { [string]: boolean } } = {} -- one-time steps sent this session
local lastLevel: { [Player]: number } = {}
local shopSession: { [Player]: string } = {}
local trackWindows: { [Player]: { start: number, count: number } } = {}

local function call(label: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		-- Quiet on purpose: this fires a lot in unpublished places.
		if Config.Analytics.debug then
			warn(`[Analytics] {label} failed: {err}`)
		end
	end
end

local function fields(value: string?): any
	if not value then
		return nil
	end
	return { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = value }
end

local function once(player: Player, key: string): boolean
	local set = logged[player]
	if not set then
		set = {}
		logged[player] = set
	end
	if set[key] then
		return false
	end
	set[key] = true
	return true
end

---------------------------------------------------------------- public API

-- One step of the onboarding funnel (the tutorial uses steps 1 to N).
function AnalyticsService.onboardingStep(player: Player, step: number, name: string)
	if not once(player, "onboarding" .. step) then
		return
	end
	call("onboarding", function()
		RobloxAnalytics:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function AnalyticsService.custom(player: Player, name: string, value: number?, field: string?)
	call(name, function()
		RobloxAnalytics:LogCustomEvent(player, name, value or 1, fields(field))
	end)
end

---------------------------------------------------------------- zones funnel

local ZONE_PHASES = { "unlocked", "entered", "boss fought", "boss beaten" }

local function zoneStep(player: Player, zoneId: number, phase: number)
	local index = table.find(Config.ZoneOrder, zoneId)
	if not index or not once(player, `zone{zoneId}:{phase}`) then
		return
	end
	local step = (index - 1) * #ZONE_PHASES + phase
	local name = `{Config.Zones[zoneId].name}: {ZONE_PHASES[phase]}`
	call("zones", function()
		RobloxAnalytics:LogFunnelStepEvent(player, "Zones", nil, step, name)
	end)
end

---------------------------------------------------------------- shop funnel

local SHOP_STEPS = { "Opened", "Purchase prompted", "Purchase completed" }

local function shopStep(player: Player, step: number, sku: string?)
	local session = shopSession[player]
	if not session or step == 1 then
		session = HttpService:GenerateGUID(false)
		shopSession[player] = session
	end
	call("shop", function()
		RobloxAnalytics:LogFunnelStepEvent(player, "Shop", session, step, SHOP_STEPS[step], fields(sku))
	end)
end

local function validSku(kind: any, key: any): string?
	if type(key) ~= "string" then
		return nil
	end
	if kind == "pass" and Config.GamePasses[key] then
		return "pass_" .. key
	elseif kind == "product" and Config.Products[key] then
		return "product_" .. key
	elseif kind == "cosmetic" and Config.Cosmetics[key] then
		return "cosmetic_" .. key
	end
	return nil
end

-- What the client may report: only menu moments the server can't see.
local function onTrack(player: Player, name: any, kind: any, key: any)
	local now = os.clock()
	local window = trackWindows[player]
	if not window or now - window.start >= TRACK_WINDOW then
		window = { start = now, count = 0 }
		trackWindows[player] = window
	end
	window.count += 1
	if window.count > MAX_TRACKS_PER_WINDOW then
		return
	end
	if name == "shopOpened" then
		shopStep(player, 1, nil)
	elseif name == "purchasePrompted" then
		local sku = validSku(kind, key)
		if sku then
			shopStep(player, 2, sku)
		end
	elseif name == "itemPreviewed" then
		local sku = validSku(kind, key)
		if sku then
			AnalyticsService.custom(player, "ItemPreviewed", 1, sku)
		end
	end
end

---------------------------------------------------------------- economy

local function queueEconomy(player: Player, flow: string, minerals: { [string]: number }, source: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	local queue = pendingEconomy[player]
	if not queue then
		queue = {}
		pendingEconomy[player] = queue
	end
	for mineral, amount in minerals do
		if amount > 0 and Config.Minerals[mineral] then
			local key = `{flow}|{source}|{mineral}`
			local entry = queue[key]
			if not entry then
				entry = { flow = flow, source = source, mineral = mineral, amount = 0, balance = 0 }
				queue[key] = entry
			end
			entry.amount += amount
			entry.balance = data.minerals[mineral] or 0
		end
	end
end

local function flush(player: Player)
	local queue = pendingEconomy[player]
	pendingEconomy[player] = nil
	for _, entry in queue or {} do
		local flowType = if entry.flow == "source"
			then Enum.AnalyticsEconomyFlowType.Source
			else Enum.AnalyticsEconomyFlowType.Sink
		call("economy", function()
			RobloxAnalytics:LogEconomyEvent(
				player,
				flowType,
				Config.Minerals[entry.mineral].displayName,
				entry.amount,
				entry.balance,
				SOURCES[entry.source] or "Gameplay",
				entry.source
			)
		end)
	end

	local spells = pendingSpells[player]
	pendingSpells[player] = nil
	for spellId, count in spells or {} do
		AnalyticsService.custom(player, "SpellsCast", count, spellId)
	end
end

---------------------------------------------------------------- progression

local function onLoaded(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	lastLevel[player] = Stats.levelForXp(data.golem.xp)
	zoneStep(player, Config.ZoneOrder[1], 1)
	zoneStep(player, Config.ZoneOrder[1], 2) -- everyone spawns on the first island
end

local function onChanged(player: Player)
	local data = DataService.get(player)
	local previous = lastLevel[player]
	if not data or not previous then
		return
	end
	local level = Stats.levelForXp(data.golem.xp)
	if level > previous then
		for reached = previous + 1, level do
			call("level", function()
				RobloxAnalytics:LogProgressionCompleteEvent(player, "Golem level", reached, `Level {reached}`)
			end)
		end
	end
	lastLevel[player] = level -- Awakening drops it back to 1

	for _, zoneId in Config.ZoneOrder do
		if Stats.zoneUnlocked(data, zoneId) then
			zoneStep(player, zoneId, 1)
		end
	end
end

function AnalyticsService.start()
	DataService.ProfileLoaded:Connect(onLoaded)
	DataService.Changed:Connect(onChanged)
	Remotes.Track.OnServerEvent:Connect(onTrack)

	Events.connect("mineralsGained", function(player, minerals, source)
		queueEconomy(player, "source", minerals, source)
	end)
	Events.connect("mineralsSpent", function(player, minerals, sink)
		queueEconomy(player, "sink", minerals, sink)
	end)

	Events.connect("spellCast", function(player, spellId)
		local spells = pendingSpells[player]
		if not spells then
			spells = {}
			pendingSpells[player] = spells
		end
		spells[spellId] = (spells[spellId] or 0) + 1
	end)

	Events.connect("zoneEntered", function(player, zoneId)
		zoneStep(player, zoneId, 2)
	end)
	local tutorialSteps = #Config.Tutorial.steps
	Events.connect("bossEngaged", function(player, zoneId)
		zoneStep(player, zoneId, 3)
		if zoneId == Config.ZoneOrder[1] then
			AnalyticsService.onboardingStep(player, tutorialSteps + 2, "first boss fought")
		end
	end)
	Events.connect("bossDefeated", function(player, zoneId)
		zoneStep(player, zoneId, 4)
		if zoneId == Config.ZoneOrder[1] then
			AnalyticsService.onboardingStep(player, tutorialSteps + 3, "first boss beaten")
		end
	end)

	Events.connect("awakened", function(player, count)
		call("awakening", function()
			RobloxAnalytics:LogProgressionCompleteEvent(player, "Awakening", count, `Awakening {count}`)
		end)
	end)
	Events.connect("ascended", function(player, count)
		call("ascension", function()
			RobloxAnalytics:LogProgressionCompleteEvent(player, "Ascension", count, `Ascension {count}`)
		end)
	end)
	Events.connect("purchased", function(player, kind, key)
		local sku = validSku(kind, key)
		if sku then
			shopStep(player, 3, sku)
		end
	end)
	Events.connect("artifactFound", function(player, artifactId)
		AnalyticsService.custom(player, "ArtifactFound", 1, artifactId)
	end)
	Events.connect("partyJoined", function(player, size)
		AnalyticsService.custom(player, "PartyJoined", size, nil)
	end)
	Events.connect("codeRedeemed", function(player, code)
		AnalyticsService.custom(player, "CodeRedeemed", 1, code)
	end)
	Events.connect("eventRewardClaimed", function(player, eventId, tier)
		AnalyticsService.custom(player, "EventRewardClaimed", tier, eventId)
	end)

	task.spawn(function()
		while true do
			task.wait(FLUSH_INTERVAL)
			for player in pendingEconomy do
				task.spawn(flush, player)
			end
			for player in pendingSpells do
				task.spawn(flush, player) -- spells only, economy already sent
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		flush(player)
		logged[player] = nil
		lastLevel[player] = nil
		shopSession[player] = nil
		trackWindows[player] = nil
	end)
end

return AnalyticsService
