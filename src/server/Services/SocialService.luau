--!strict
-- The hub's social side: what other players can inspect about a golem, the
-- titles shown on nametags, and the server-wide shout for rare finds. It shows
-- only game progress and Roblox display names. There is no free text anywhere
-- (titles come from Config.Titles), so nothing here needs filtering, and
-- nothing needs chat: Roblox's own age-checked chat is left to Roblox.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)
local WorldService = require(script.Parent.WorldService)

local SocialService = {}

-- Everything another player may see about a golem.
local function card(other: Player, data: any): any
	local level = Stats.levelForXp(data.golem.xp)
	local parts = {}
	for _, slot in Config.SlotOrder do
		local tier = data.golem.parts[slot]
		table.insert(parts, `{Config.Slots[slot].displayName}: {if tier then Config.Tiers[tier].displayName else "Bare stone"}`)
	end
	local equipped = {}
	for _, id in data.artifacts.equipped do
		if Config.Artifacts[id] then
			table.insert(equipped, Config.Artifacts[id].name)
		end
	end
	local bosses = 0
	for _, zoneId in Config.ZoneOrder do
		if Stats.bossDefeated(data, zoneId) then
			bosses += 1
		end
	end
	local golem = GolemService.get(other)
	return {
		userId = other.UserId,
		name = other.DisplayName,
		level = level,
		size = Stats.sizeForLevel(level),
		awakenings = data.awakening.count,
		artifactsFound = Stats.artifactsFound(data),
		bosses = bosses,
		title = Stats.equippedTitle(data),
		parts = parts,
		equipped = equipped,
		inHub = golem ~= nil and golem.zoneId == Config.HubZone,
	}
end

local function snapshot(player: Player): any
	local data = DataService.get(player)
	local others = {}
	for _, other in Players:GetPlayers() do
		local otherData = if other ~= player then DataService.get(other) else nil
		if otherData and #others < Config.Hub.maxInspect then
			table.insert(others, card(other, otherData))
		end
	end
	local titles = {}
	for _, id in Config.TitleOrder do
		table.insert(titles, { id = id, name = Config.Titles[id].name, earned = data ~= nil and Stats.titleEarned(data, id) })
	end
	return { others = others, titles = titles }
end

local function setTitle(player: Player, id: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(id) ~= "string" then
		return false, "Not ready"
	end
	if id == "" then
		DataService.update(player, function(d)
			d.social.title = ""
		end)
		return true, "Title removed"
	end
	if not Config.Titles[id] or not Stats.titleEarned(data, id) then
		return false, "You haven't earned that title yet"
	end
	DataService.update(player, function(d)
		d.social.title = id
	end)
	return true, `Title: {Config.Titles[id].name}`
end

local function setAnnounce(player: Player, on: any): (boolean, string?)
	if type(on) ~= "boolean" or not DataService.get(player) then
		return false, "Not ready"
	end
	DataService.update(player, function(d)
		d.social.announce = on
	end)
	return true, if on then "You'll hear about rare finds" else "Rare-find announcements are off"
end

-- Tells everyone who hasn't opted out that someone found something rare.
local function announce(finder: Player, artifactId: string)
	local artifact = Config.Artifacts[artifactId]
	if not artifact or not Config.AnnounceSources[artifact.source] then
		return
	end
	for _, other in Players:GetPlayers() do
		local data = DataService.get(other)
		if other ~= finder and data and data.social.announce then
			Remotes.Notify:FireClient(other, "message", `{finder.DisplayName} found {artifact.name}!`)
		end
	end
end

-- Walking up to a golem in the hub and pressing Inspect opens its card.
local function hookGolem(model: Instance)
	local prompt = model:WaitForChild("HumanoidRootPart", 10)
	prompt = prompt and prompt:WaitForChild("InspectPrompt", 10)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	local owner = Players:FindFirstChild((string.gsub(model.Name, "_Golem$", "")))
	prompt.Triggered:Connect(function(who: Player)
		if owner and owner:IsA("Player") and owner ~= who and DataService.get(who) then
			Remotes.Notify:FireClient(who, "inspect", owner.UserId)
		end
	end)
end

function SocialService.start()
	DataService.addProvider("hub", snapshot)
	ActionService.register("setTitle", setTitle)
	ActionService.register("setAnnounce", setAnnounce)
	Events.connect("artifactFound", announce)

	local golems = WorldService.getFolder("Golems")
	golems.ChildAdded:Connect(function(model)
		task.spawn(hookGolem, model)
	end)
	for _, model in golems:GetChildren() do
		task.spawn(hookGolem, model)
	end

	-- Levels and artifacts change while people stand around, so keep the
	-- cards of everyone in the hub fresh.
	task.spawn(function()
		while true do
			task.wait(Config.Hub.refreshSeconds)
			for player, golem in GolemService.all() do
				if golem.zoneId == Config.HubZone then
					DataService.markChanged(player)
				end
			end
		end
	end)

	-- Cards and the Hub tab show every player's progress, so refresh everyone
	-- whenever someone joins or leaves.
	Players.PlayerAdded:Connect(function()
		for _, other in Players:GetPlayers() do
			DataService.markChanged(other)
		end
	end)
	Players.PlayerRemoving:Connect(function(leaving)
		for _, other in Players:GetPlayers() do
			if other ~= leaving then
				DataService.markChanged(other)
			end
		end
	end)
end

return SocialService
