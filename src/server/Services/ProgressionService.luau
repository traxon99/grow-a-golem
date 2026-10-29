--!strict
-- Menu actions that change how strong the golem is or where it can go:
-- forging parts, travelling between zones, the skill tree, and Awakening.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ForgeStrike = require(Shared:WaitForChild("ForgeStrike"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)
local PassService = require(script.Parent.PassService)

local AUTO_FORGE_INTERVAL = 10

local ProgressionService = {}

type Strike = {
	targetAt: number,
	refund: { [string]: number },
}
local pendingStrikes: { [Player]: Strike } = {}

local function tierRank(tier: string?): number
	return if tier then (table.find(Config.TierOrder, tier) or 0) else 0
end

---------------------------------------------------------------- forge

local function craft(player: Player, slot: any, tier: any, automatic: boolean?): (boolean, string?)
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
	if not DataService.spend(player, cost, "forge") then
		return false, "Not enough minerals"
	end
	DataService.update(player, function(d)
		d.golem.parts[slot] = tier
	end)
	Events.fire("partCrafted", player, slot, tier)
	if automatic ~= true then
		local targetAt = workspace:GetServerTimeNow() + Config.ForgeStrike.delaySeconds
		pendingStrikes[player] = {
			targetAt = targetAt,
			refund = ForgeStrike.refund(cost, Config.ForgeStrike.refundFraction),
		}
		-- The normal forge is already complete. The player can ignore this.
		Remotes.Notify:FireClient(player, "forgeStrike", slot, tier, targetAt)
	end
	return true, `Forged a {Config.Tiers[tier].displayName} {Config.Slots[slot].displayName}!`
end

-- Auto-Forge (the pass, or the first Awakening's unlock) crafts the best
-- affordable upgrade for one slot.
local function autoForge(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	for index = #Config.TierOrder, 1, -1 do
		local tier = Config.TierOrder[index]
		for _, slot in Config.SlotOrder do
			if tierRank(data.golem.parts[slot]) < index and Stats.canAfford(data, Stats.partCost(slot, tier)) then
				local ok, message = craft(player, slot, tier, true)
				if ok then
					Remotes.Notify:FireClient(player, "message", `Auto-Forge: {message}`)
					return
				end
			end
		end
	end
end

-- The first strike request consumes the pending bonus, even if it misses.
-- The client never supplies its own timing or a claimed success grade.
local function finishForgeStrike(player: Player): (boolean, string?)
	local pending = pendingStrikes[player]
	if not pending then
		return false, "No forge strike waiting"
	end
	pendingStrikes[player] = nil
	local window = Config.ForgeStrike.halfWindowSeconds + Config.ForgeStrike.latencySlackSeconds
	if not ForgeStrike.isPerfect(workspace:GetServerTimeNow(), pending.targetAt, window) then
		return true, "Normal forge (no penalty)"
	end
	DataService.addMinerals(player, pending.refund, "forgeStrike")
	return true, "Perfect anvil strike! Fixed mineral refund earned."
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
	if zoneId == golem.zoneId then
		return false, "You're already there"
	end
	if zoneId == Config.HubZone then
		-- The hub is always open and has no enemies.
		GolemService.sendToZone(golem, zoneId)
		DataService.markChanged(player)
		return true, `Welcome to the {Config.Hub.name}! Walk up to a golem to inspect it.`
	end
	local unlocked, reason = Stats.zoneUnlocked(data, zoneId)
	if not unlocked then
		return false, reason
	end
	GolemService.sendToZone(golem, zoneId)
	DataService.markChanged(player)
	Events.fire("zoneEntered", player, zoneId)
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
	if not DataService.spend(player, Config.SkillRespecCost, "respec") then
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
	local unlock = Stats.nextAwakeningUnlock(data)
	local wiped = table.clone(data.minerals)
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
	Events.fire("mineralsSpent", player, wiped, "awaken")
	Events.fire("awakened", player, data.awakening.count)
	local unlocked = if unlock then ` Unlocked: {unlock.name}!` else ""
	return true, `Your golem Awakens! +{shards} Awakening Shards.{unlocked}`
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

local function ascend(player: Player): (boolean, string?)
	local data = DataService.get(player)
	local golem = GolemService.get(player)
	if not data or not golem or not Stats.canAscend(data) then
		return false, "Meet the Ascension requirements first"
	end
	local wiped = table.clone(data.minerals)
	DataService.update(player, function(d)
		d.ascension.count += 1
		d.ascension.points += Config.Ascension.points
		d.ascension.spentAwakenings = (d.ascension.spentAwakenings or 0) + Config.Ascension.requiredAwakenings
		d.golem.xp = 0
		d.golem.parts = {}
		d.skills = {}
		d.bossesDefeated = {}
		for id in d.minerals do
			d.minerals[id] = 0
		end
	end)
	GolemService.sendToZone(golem, 1)
	Events.fire("mineralsSpent", player, wiped, "ascend")
	Events.fire("ascended", player, data.ascension.count)
	return true, "Ascended! Choose a permanent upgrade in Awaken."
end

local function buyAscendUpgrade(player: Player, id: any): (boolean, string?)
	local data = DataService.get(player)
	local upgrade = if type(id) == "string" then Config.AscendUpgrades[id] else nil
	if not data or not upgrade then
		return false, "Unknown Ascension upgrade"
	end
	local rank = data.ascension.upgrades[id] or 0
	if rank >= upgrade.maxRank or data.ascension.points < upgrade.cost then
		return false, "Max rank or not enough Ascension points"
	end
	DataService.update(player, function(d)
		d.ascension.points -= upgrade.cost
		d.ascension.upgrades[id] = rank + 1
	end)
	return true, "Ascension upgrade learned"
end

function ProgressionService.start()
	ActionService.register("ascend", ascend)
	ActionService.register("buyAscendUpgrade", buyAscendUpgrade)
	ActionService.register("craftPart", craft)
	ActionService.register("finishForgeStrike", finishForgeStrike)
	Players.PlayerRemoving:Connect(function(player)
		pendingStrikes[player] = nil
	end)
	ActionService.register("travel", travel)
	ActionService.register("learnSkill", learn)
	ActionService.register("respecSkills", respec)
	ActionService.register("awaken", awaken)
	ActionService.register("buyUpgrade", buyUpgrade)

	task.spawn(function()
		while true do
			task.wait(AUTO_FORGE_INTERVAL)
			for player in GolemService.all() do
				local data = DataService.get(player)
				if PassService.owns(player, "autoForge") or (data and Stats.awakeningUnlocked(data, "autoForge")) then
					task.spawn(autoForge, player)
				end
			end
		end
	end)
end

return ProgressionService
