--!strict
-- Menu actions that change how strong the golem is or where it can go:
-- forging parts, travelling between zones, the skill tree, and Awakening.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)
local PassService = require(script.Parent.PassService)

local AUTO_FORGE_INTERVAL = 10

local ProgressionService = {}

local function tierRank(tier: string?): number
	return if tier then (table.find(Config.TierOrder, tier) or 0) else 0
end

---------------------------------------------------------------- forge

local function craft(player: Player, slot: any, tier: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(slot) ~= "string" or type(tier) ~= "string" then
		return false, "Not ready"
	end
	if not Config.Slots[slot] or not Config.Tiers[tier] then
		return false, "Unknown part"
	end
	if tierRank(tier) <= tierRank(data.golem.parts[slot]) then
		return false, "You already have an equal or better part there"
	end
	local cost = Stats.partCost(slot, tier)
	if not DataService.spend(player, cost) then
		return false, "Not enough minerals"
	end
	DataService.update(player, function(d)
		d.golem.parts[slot] = tier
	end)
	Events.fire("partCrafted", player, slot, tier)
	return true, `Forged a {Config.Tiers[tier].displayName} {Config.Slots[slot].displayName}!`
end

-- The Auto-Forge pass crafts the best affordable upgrade for one slot.
local function autoForge(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	for index = #Config.TierOrder, 1, -1 do
		local tier = Config.TierOrder[index]
		for _, slot in Config.SlotOrder do
			if tierRank(data.golem.parts[slot]) < index and Stats.canAfford(data, Stats.partCost(slot, tier)) then
				local ok, message = craft(player, slot, tier)
				if ok then
					Remotes.Notify:FireClient(player, "message", `Auto-Forge: {message}`)
					return
				end
			end
		end
	end
end

---------------------------------------------------------------- travel

local function travel(player: Player, zoneId: any): (boolean, string?)
	local data = DataService.get(player)
	local golem = GolemService.get(player)
	if not data or not golem or type(zoneId) ~= "number" then
		return false, "Not ready"
	end
	if not GolemService.isActive(golem) then
		return false, "Wait for your golem to reform"
	end
	local unlocked, reason = Stats.zoneUnlocked(data, zoneId)
	if not unlocked then
		return false, reason
	end
	GolemService.sendToZone(golem, zoneId)
	DataService.markChanged(player)
	return true, `Welcome to {Config.Zones[zoneId].name}!`
end

---------------------------------------------------------------- skills

local function learn(player: Player, skillId: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(skillId) ~= "string" then
		return false, "Not ready"
	end
	local ok, reason = Stats.canLearnSkill(data, skillId)
	if not ok then
		return false, reason
	end
	DataService.update(player, function(d)
		d.skills[skillId] = true
	end)
	return true, `Learned {Config.Skills[skillId].name}`
end

local function respec(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not data or next(data.skills) == nil then
		return false, "No skills to reset"
	end
	if not DataService.spend(player, Config.SkillRespecCost) then
		return false, "Not enough minerals"
	end
	DataService.update(player, function(d)
		d.skills = {}
	end)
	return true, "Skill points refunded"
end

---------------------------------------------------------------- awakening

local function awaken(player: Player): (boolean, string?)
	local data = DataService.get(player)
	local golem = GolemService.get(player)
	if not data or not golem then
		return false, "Not ready"
	end
	local level = Stats.levelForXp(data.golem.xp)
	if level < Config.Awakening.minLevel then
		return false, `Reach level {Config.Awakening.minLevel} to Awaken`
	end
	local shards = Stats.awakeningShards(level)
	DataService.update(player, function(d)
		d.awakening.count += 1
		d.awakening.shards += shards
		d.golem.xp = 0
		d.golem.parts = {}
		d.skills = {}
		d.bossesDefeated = {}
		for id in d.minerals do
			d.minerals[id] = 0
		end
	end)
	GolemService.sendToZone(golem, 1)
	return true, `Your golem Awakens! +{shards} Awakening Shards`
end

local function buyUpgrade(player: Player, upgradeId: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(upgradeId) ~= "string" then
		return false, "Not ready"
	end
	local upgrade = Config.AwakenUpgrades[upgradeId]
	if not upgrade then
		return false, "Unknown upgrade"
	end
	local rank = data.awakening.upgrades[upgradeId] or 0
	if rank >= upgrade.maxRank then
		return false, "Already at max rank"
	end
	local cost = Stats.upgradeCost(upgradeId, rank)
	if data.awakening.shards < cost then
		return false, "Not enough Awakening Shards"
	end
	DataService.update(player, function(d)
		d.awakening.shards -= cost
		d.awakening.upgrades[upgradeId] = rank + 1
	end)
	return true, `{upgrade.name} is now rank {rank + 1}`
end

function ProgressionService.start()
	ActionService.register("craftPart", craft)
	ActionService.register("travel", travel)
	ActionService.register("learnSkill", learn)
	ActionService.register("respecSkills", respec)
	ActionService.register("awaken", awaken)
	ActionService.register("buyUpgrade", buyUpgrade)

	task.spawn(function()
		while true do
			task.wait(AUTO_FORGE_INTERVAL)
			for player in GolemService.all() do
				if PassService.owns(player, "autoForge") then
					task.spawn(autoForge, player)
				end
			end
		end
	end)
end

return ProgressionService
