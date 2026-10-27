--!strict
-- Artifacts: rare finds that give passive bonuses. They drop from enemies,
-- from zone bosses, or from a glowing relic hidden somewhere on each island.
-- Found artifacts go in the player's index; a limited number can be equipped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)
local WorldService = require(script.Parent.WorldService)

local ArtifactService = {}

local relics: { [number]: BasePart } = {} -- zoneId -> relic part

local function unfound(data: any, zoneId: number, source: string): { string }
	local list = {}
	for _, id in Config.ArtifactOrder do
		local artifact = Config.Artifacts[id]
		if artifact.zone == zoneId and artifact.source == source and not data.artifacts.found[id] then
			table.insert(list, id)
		end
	end
	return list
end

function ArtifactService.grant(player: Player, artifactId: string)
	local artifact = Config.Artifacts[artifactId]
	local golem = GolemService.get(player)
	DataService.update(player, function(data)
		if data.artifacts.found[artifactId] then
			return
		end
		data.artifacts.found[artifactId] = true
		-- Auto-equip into a free slot.
		local slots = if golem then golem.stats.artifactSlots else Config.Golem.baseArtifactSlots
		if #data.artifacts.equipped < slots then
			table.insert(data.artifacts.equipped, artifactId)
		end
	end)
	Events.fire("artifactFound", player, artifactId)
	Remotes.Notify:FireClient(player, "artifact", artifact.name)
end

-- Rolls for an artifact drop. `source` is "drop" or "boss".
function ArtifactService.roll(player: Player, zoneId: number, source: string)
	local data = DataService.get(player)
	local golem = GolemService.get(player)
	if not data then
		return
	end
	local chance = if source == "boss" then Config.ArtifactBossChance else Config.ArtifactDropChance
	chance *= if golem then golem.stats.luckMult else 1
	if math.random() >= chance then
		return
	end
	local options = unfound(data, zoneId, source)
	if #options > 0 then
		ArtifactService.grant(player, options[math.random(1, #options)])
	end
end

---------------------------------------------------------------- hidden relics

local function placeRelic(zoneId: number)
	local relic = Instance.new("Part")
	relic.Name = "HiddenRelic"
	relic.Shape = Enum.PartType.Ball
	relic.Size = Vector3.new(2.5, 2.5, 2.5)
	relic.Anchored = true
	relic.CanCollide = false
	relic.Material = Enum.Material.Neon
	relic.Color = Color3.fromRGB(255, 214, 90)
	relic.Position = WorldService.randomPoint(zoneId, 20) + Vector3.new(0, 2, 0)
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Color = relic.Color
	light.Parent = relic
	relic.Parent = WorldService.getFolder("Relics")
	TweenService:Create(relic, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = relic.Position + Vector3.new(0, 1.5, 0),
	}):Play()
	relics[zoneId] = relic
end

local function collectRelic(player: Player, zoneId: number)
	local relic = relics[zoneId]
	relics[zoneId] = nil
	if relic then
		relic:Destroy()
	end
	local data = DataService.get(player)
	local options = if data then unfound(data, zoneId, "hidden") else {}
	if #options > 0 then
		ArtifactService.grant(player, options[1])
	else
		local zone = Config.Zones[zoneId]
		local minerals = {}
		for mineral in zone.offlineMinerals do
			minerals[mineral] = Config.HiddenRelic.consolationMinerals
		end
		EconomyService.grant(player, { minerals = minerals })
		Remotes.Notify:FireClient(player, "message", "You found a relic cache full of minerals!")
	end
	task.delay(Config.HiddenRelic.respawn, placeRelic, zoneId)
end

---------------------------------------------------------------- actions

local function equip(player: Player, artifactId: any): (boolean, string?)
	local data = DataService.get(player)
	local golem = GolemService.get(player)
	if type(artifactId) ~= "string" or not data or not golem then
		return false, "Not ready"
	end
	if not data.artifacts.found[artifactId] then
		return false, "You haven't found that yet"
	end
	if table.find(data.artifacts.equipped, artifactId) then
		return false, "Already equipped"
	end
	if #data.artifacts.equipped >= golem.stats.artifactSlots then
		return false, "All artifact slots are full. Unequip one first."
	end
	DataService.update(player, function(d)
		table.insert(d.artifacts.equipped, artifactId)
	end)
	return true, nil
end

local function unequip(player: Player, artifactId: any): (boolean, string?)
	local data = DataService.get(player)
	if type(artifactId) ~= "string" or not data then
		return false, "Not ready"
	end
	local index = table.find(data.artifacts.equipped, artifactId)
	if not index then
		return false, "Not equipped"
	end
	DataService.update(player, function(d)
		table.remove(d.artifacts.equipped, index)
	end)
	return true, nil
end

function ArtifactService.start()
	ActionService.register("equipArtifact", equip)
	ActionService.register("unequipArtifact", unequip)

	for zoneId in Config.Zones do
		placeRelic(zoneId)
	end

	-- Golems pick up a relic by walking near it.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for zoneId, relic in relics do
				for player, golem in GolemService.all() do
					if golem.zoneId == zoneId and GolemService.isActive(golem) then
						local range = Config.HiddenRelic.pickupRange * golem.stats.scale
						local flat = (golem.root.Position - relic.Position) * Vector3.new(1, 0, 1)
						if flat.Magnitude <= range then
							collectRelic(player, zoneId)
							break
						end
					end
				end
			end
		end
	end)

	-- Trim equipped artifacts if a player loses slots (after an Awakening, for example).
	DataService.Changed:Connect(function(player)
		local data = DataService.get(player)
		local golem = GolemService.get(player)
		if data and golem and #data.artifacts.equipped > golem.stats.artifactSlots then
			while #data.artifacts.equipped > golem.stats.artifactSlots do
				table.remove(data.artifacts.equipped)
			end
			DataService.markChanged(player)
		end
	end)
end

return ArtifactService
