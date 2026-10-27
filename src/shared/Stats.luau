--!strict
-- Pure functions that turn saved player data into game numbers: level, size,
-- stats, costs, and unlock checks. Shared so the client can show the same
-- numbers the server uses; the server is still the one that decides.

local Config = require(script.Parent:WaitForChild("Config"))

export type Context = {
	passes: { [string]: boolean },
	now: number, -- os.time()
}

export type GolemStats = {
	level: number,
	size: number,
	scale: number,
	maxHealth: number,
	regenPerSecond: number,
	attackDamage: number,
	attackCooldown: number,
	attackRange: number,
	miningDamage: number,
	miningCooldown: number,
	miningRange: number,
	walkSpeed: number,
	mineralMult: number,
	xpMult: number,
	luckMult: number,
	spellPowerMult: number,
	spellCooldownMult: number,
	artifactSlots: number,
	offlineCapHours: number,
	fullSet: string?,
}

local Stats = {}

---------------------------------------------------------------- levels and size

function Stats.xpForLevel(level: number): number
	return math.floor(Config.LevelCurve.base * (level - 1) ^ Config.LevelCurve.exponent)
end

function Stats.levelForXp(xp: number): number
	local level = 1
	while level < Config.Golem.maxLevel and xp >= Stats.xpForLevel(level + 1) do
		level += 1
	end
	return level
end

function Stats.sizeForLevel(level: number): number
	local size = 1
	for index, required in Config.SizeLevels do
		if level >= required then
			size = index
		end
	end
	return size
end

function Stats.scaleForSize(size: number): number
	return 1 + Config.SizeScaleStep * (size - 1)
end

---------------------------------------------------------------- costs

function Stats.partCost(slot: string, tier: string): { [string]: number }
	local cost = {}
	local multiplier = Config.Slots[slot].costMultiplier
	for mineral, amount in Config.Tiers[tier].cost do
		cost[mineral] = math.ceil(amount * multiplier)
	end
	return cost
end

function Stats.canAfford(data: any, cost: { [string]: number }): boolean
	for mineral, amount in cost do
		if (data.minerals[mineral] or 0) < amount then
			return false
		end
	end
	return true
end

function Stats.upgradeCost(upgradeId: string, currentRank: number): number
	local upgrade = Config.AwakenUpgrades[upgradeId]
	return upgrade.baseCost + upgrade.costStep * currentRank
end

function Stats.awakeningShards(level: number): number
	return math.max(level - Config.Awakening.shardBaseLevel, 0) * Config.Awakening.shardsPerLevelAbove
end

---------------------------------------------------------------- skills

function Stats.skillPointsSpent(data: any): number
	local spent = 0
	for id in data.skills do
		local skill = Config.Skills[id]
		if skill then
			spent += skill.cost
		end
	end
	return spent
end

function Stats.skillPointsAvailable(data: any): number
	return Stats.levelForXp(data.golem.xp) - 1 - Stats.skillPointsSpent(data)
end

-- Returns whether a skill can be learned now, and why not.
function Stats.canLearnSkill(data: any, skillId: string): (boolean, string?)
	local skill = Config.Skills[skillId]
	if not skill then
		return false, "Unknown skill"
	end
	if data.skills[skillId] then
		return false, "Already learned"
	end
	for _, branch in Config.SkillBranches do
		local index = table.find(branch.nodes, skillId)
		if index and index > 1 and not data.skills[branch.nodes[index - 1]] then
			return false, "Learn the previous skill first"
		end
	end
	if Stats.skillPointsAvailable(data) < skill.cost then
		return false, "Not enough skill points"
	end
	return true, nil
end

---------------------------------------------------------------- zones

function Stats.bossDefeated(data: any, zoneId: number): boolean
	return data.bossesDefeated[tostring(zoneId)] == true
end

-- Returns whether the player may travel to a zone, and what is missing.
function Stats.zoneUnlocked(data: any, zoneId: number): (boolean, string?)
	local zone = Config.Zones[zoneId]
	if not zone then
		return false, "Unknown zone"
	end
	local gate = zone.gate
	if gate.boss and not Stats.bossDefeated(data, gate.boss) then
		return false, `Defeat {Config.Bosses[gate.boss].displayName}`
	end
	if gate.size and Stats.sizeForLevel(Stats.levelForXp(data.golem.xp)) < gate.size then
		return false, `Reach golem size {gate.size}`
	end
	return true, nil
end

function Stats.highestZone(data: any): number
	local highest = 1
	for _, zoneId in Config.ZoneOrder do
		if Stats.zoneUnlocked(data, zoneId) then
			highest = zoneId
		end
	end
	return highest
end

---------------------------------------------------------------- artifacts

function Stats.zoneSetComplete(data: any, zoneId: number): boolean
	for id, artifact in Config.Artifacts do
		if artifact.zone == zoneId and not data.artifacts.found[id] then
			return false
		end
	end
	return true
end

function Stats.artifactsFound(data: any): number
	local count = 0
	for id in data.artifacts.found do
		if Config.Artifacts[id] then
			count += 1
		end
	end
	return count
end

-- Found and total artifacts in one zone.
function Stats.zoneArtifactCount(data: any, zoneId: number): (number, number)
	local found, total = 0, 0
	for id, artifact in Config.Artifacts do
		if artifact.zone == zoneId then
			total += 1
			if data.artifacts.found[id] then
				found += 1
			end
		end
	end
	return found, total
end

function Stats.pityKey(zoneId: number, source: string): string
	return source .. zoneId
end

-- The real odds of an artifact roll, used by the server to roll and by the
-- menus to show them. Returns the chance per roll (0 to 1), how many rolls
-- are left before one is guaranteed, and how many artifacts are still unfound.
function Stats.artifactOdds(data: any, zoneId: number, source: string, luckMult: number): (number, number, number)
	local unfound = 0
	for id, artifact in Config.Artifacts do
		if artifact.zone == zoneId and artifact.source == source and not data.artifacts.found[id] then
			unfound += 1
		end
	end
	local base = if source == "boss" then Config.ArtifactBossChance else Config.ArtifactDropChance
	local chance = math.min(base * luckMult, 1)
	local rolls = (data.artifacts.pity or {})[Stats.pityKey(zoneId, source)] or 0
	local rollsLeft = math.max(Config.ArtifactPity[source] - rolls, 1)
	if unfound == 0 then
		return 0, 0, 0
	end
	return chance, rollsLeft, unfound
end

-- Once every artifact from a source on an island is found, the same roll
-- (same chance, same bad-luck protection) gives a spare copy to trade
-- instead. Returns the chance per roll, rolls left before one is guaranteed,
-- and whether spares are what this source is rolling for right now.
function Stats.spareOdds(data: any, zoneId: number, source: string, luckMult: number): (number, number, boolean)
	local chance, rollsLeft, unfound = Stats.artifactOdds(data, zoneId, source, luckMult)
	if unfound > 0 then
		return 0, 0, false
	end
	local total = 0
	for _, artifact in Config.Artifacts do
		if artifact.zone == zoneId and artifact.source == source then
			total += 1
		end
	end
	if total == 0 then
		return 0, 0, false
	end
	local base = if source == "boss" then Config.ArtifactBossChance else Config.ArtifactDropChance
	local rolls = (data.artifacts.pity or {})[Stats.pityKey(zoneId, source)] or 0
	return math.min(base * luckMult, 1), math.max(Config.ArtifactPity[source] - rolls, 1), true
end

-- Spare copies of an artifact that can be traded (the rest are bound).
function Stats.tradableSpares(data: any, artifactId: string): number
	local spares = (data.artifacts.spares or {})[artifactId] or 0
	local bound = (data.artifacts.boundSpares or {})[artifactId] or 0
	return math.max(spares - bound, 0)
end

---------------------------------------------------------------- bonuses

local function addBonus(total: { [string]: number }, bonus: { [string]: number }, times: number)
	for stat, amount in bonus do
		total[stat] = (total[stat] or 0) + amount * times
	end
end

---------------------------------------------------------------- events

-- When an event's current or next window runs. Returns (startsAt, endsAt) of
-- the window that contains `now`, or else the next one; nil if none is left.
function Stats.eventWindow(event: any, now: number): (number?, number?)
	if event.weekly then
		local day = math.floor(now / 86400)
		local monday = (day - (day + 3) % 7) * 86400 -- 1970-01-01 was a Thursday
		local offset = ((event.weekly.day - 1) * 24 + event.weekly.hour) * 3600
		local length = event.weekly.hours * 3600
		for week = -1, 1 do
			local startsAt = monday + week * 7 * 86400 + offset
			if now < startsAt + length then
				return startsAt, startsAt + length
			end
		end
		return nil, nil
	end
	if event.startsAt and event.endsAt and now < event.endsAt then
		return event.startsAt, event.endsAt
	end
	return nil, nil
end

-- Events running right now, each with the time it ends.
function Stats.activeEvents(now: number): { { event: any, startsAt: number, endsAt: number } }
	local active = {}
	for _, event in Config.Events do
		local startsAt, endsAt = Stats.eventWindow(event, now)
		if startsAt and endsAt and now >= startsAt then
			table.insert(active, { event = event, startsAt = startsAt, endsAt = endsAt })
		end
	end
	return active
end

-- The combined event multiplier for "minerals", "xp" or "luck".
function Stats.eventMultiplier(now: number, stat: string): number
	local mult = 1
	for _, entry in Stats.activeEvents(now) do
		mult *= entry.event.modifiers and entry.event.modifiers[stat] or 1
	end
	return mult
end

function Stats.eventById(id: string): any
	for _, event in Config.Events do
		if event.id == id then
			return event
		end
	end
	return nil
end

---------------------------------------------------------------- cosmetics
-- Cosmetics are looks only: nothing in this file's stat math reads them.

-- How far a player is toward earning a cosmetic: (current, needed).
function Stats.unlockProgress(data: any, unlock: any): (number, number)
	if not unlock then
		return 0, 1
	end
	if unlock.kind == "boss" then
		return (if Stats.bossDefeated(data, unlock.zone) then 1 else 0), 1
	elseif unlock.kind == "awaken" then
		return math.min(data.awakening.count, unlock.count), unlock.count
	elseif unlock.kind == "zoneSet" then
		local found, total = Stats.zoneArtifactCount(data, unlock.zone)
		return found, total
	elseif unlock.kind == "level" then
		return math.min(Stats.levelForXp(data.golem.xp), unlock.level), unlock.level
	elseif unlock.kind == "streak" then
		return math.min(data.daily.streak, unlock.days), unlock.days
	elseif unlock.kind == "tutorial" then
		return (if data.tutorial.done then 1 else 0), 1
	end
	return 0, 1
end

function Stats.cosmeticProgress(data: any, id: string): (number, number)
	local cosmetic = Config.Cosmetics[id]
	return Stats.unlockProgress(data, cosmetic and cosmetic.unlock)
end

function Stats.cosmeticEarned(data: any, id: string): boolean
	local current, needed = Stats.cosmeticProgress(data, id)
	return current >= needed
end

-- Titles use the same unlock kinds as cosmetics.
function Stats.titleEarned(data: any, id: string): boolean
	local title = Config.Titles[id]
	if not title then
		return false
	end
	local current, needed = Stats.unlockProgress(data, title.unlock)
	return current >= needed
end

-- The title shown on the nametag, or nil (also nil if it isn't earned).
function Stats.equippedTitle(data: any): string?
	local id = data.social and data.social.title
	if type(id) == "string" and Stats.titleEarned(data, id) then
		return Config.Titles[id].name
	end
	return nil
end

function Stats.ownsCosmetic(data: any, id: string): boolean
	return Config.Cosmetics[id] ~= nil and data.cosmetics.owned[id] == true
end

-- The cosmetic worn in a slot, or nil (also nil if it isn't owned any more).
function Stats.equippedCosmetic(data: any, slot: string): string?
	local id = data.cosmetics.equipped[slot]
	if type(id) == "string" and Stats.ownsCosmetic(data, id) and Config.Cosmetics[id].slot == slot then
		return id
	end
	return nil
end

-- Sums every % bonus a player has, plus extra slots and offline hours.
function Stats.bonuses(data: any, ctx: Context): ({ [string]: number }, number, number)
	local total: { [string]: number } = {}
	local extraSlots = 0
	local extraHours = 0

	for id in data.skills do
		local skill = Config.Skills[id]
		if skill then
			addBonus(total, skill.bonus, 1)
			extraSlots += skill.artifactSlots or 0
			extraHours += skill.offlineHours or 0
		end
	end

	for id, rank in data.awakening.upgrades do
		local upgrade = Config.AwakenUpgrades[id]
		if upgrade and rank > 0 then
			addBonus(total, upgrade.bonus or {}, rank)
			extraSlots += (upgrade.artifactSlots or 0) * rank
			extraHours += (upgrade.offlineHours or 0) * rank
		end
	end
	total.minerals = (total.minerals or 0) + data.awakening.count * Config.Awakening.mineralBonusPerAwakening

	if ctx.passes.extraSlot then
		extraSlots += 1
	end
	local slots = Config.Golem.baseArtifactSlots + extraSlots

	-- Equipped artifacts, only up to the number of slots.
	local used = 0
	for _, id in data.artifacts.equipped do
		local artifact = Config.Artifacts[id]
		if artifact and data.artifacts.found[id] and used < slots then
			used += 1
			addBonus(total, artifact.bonus, 1)
		end
	end
	for _, zoneId in Config.ZoneOrder do
		if Stats.zoneSetComplete(data, zoneId) then
			addBonus(total, Config.ZoneSetBonus, 1)
		end
	end

	if ctx.passes.vip then
		total.xp = (total.xp or 0) + Config.VipXpBonus
	end

	local capHours = Config.Offline.baseCapHours + extraHours
	if ctx.passes.longRest then
		capHours = math.max(capHours, Config.LongRestCapHours + extraHours)
	end
	return total, slots, capHours
end

---------------------------------------------------------------- golem stats

function Stats.compute(data: any, ctx: Context): GolemStats
	local base = Config.Golem
	local level = Stats.levelForXp(data.golem.xp)
	local size = Stats.sizeForLevel(level)
	local scale = Stats.scaleForSize(size)

	local health = base.maxHealth * (1 + 0.06 * (level - 1))
	local damage = base.attackDamage * (1 + 0.06 * (level - 1))
	local mining = base.miningDamage * (1 + 0.05 * (level - 1))
	local speed = base.walkSpeed

	-- Parts: each slot favours different stats.
	local setTier: string? = data.golem.parts[Config.SlotOrder[1]]
	for _, slot in Config.SlotOrder do
		local tier = data.golem.parts[slot]
		local power = if tier and Config.Tiers[tier] then Config.Tiers[tier].power else 0
		if tier ~= setTier then
			setTier = nil
		end
		if slot == "core" then
			health += 10 * power
			damage += 1.5 * power
			mining += 2 * power
		elseif slot == "torso" then
			health += 30 * power
		elseif slot == "armL" or slot == "armR" then
			damage += 3 * power
			mining += 1.5 * power
		elseif slot == "legs" then
			health += 8 * power
			speed += 0.6 * power
		end
	end
	if setTier then
		health *= 1 + Config.FullSetBonus
		damage *= 1 + Config.FullSetBonus
	end

	local bonus, slots, capHours = Stats.bonuses(data, ctx)
	local function pct(stat: string): number
		return 1 + (bonus[stat] or 0) / 100
	end

	local boosts = data.boosts or {}
	local xpBoost = if (boosts.xp or 0) > ctx.now then 2 else 1
	local luckBoost = if (boosts.luck or 0) > ctx.now then 2 else 1

	return {
		level = level,
		size = size,
		scale = scale,
		maxHealth = math.floor(health * pct("health")),
		regenPerSecond = base.regenPerSecond * (1 + 0.04 * (level - 1)) * pct("regen"),
		attackDamage = damage * pct("damage"),
		attackCooldown = base.attackCooldown / pct("attackSpeed"),
		attackRange = base.attackRange * scale,
		miningDamage = mining * pct("mining"),
		miningCooldown = base.miningCooldown,
		miningRange = base.miningRange * scale,
		walkSpeed = math.min(speed * pct("speed"), 40),
		mineralMult = pct("minerals") * (if ctx.passes.doubleMinerals then 2 else 1) * Stats.eventMultiplier(ctx.now, "minerals"),
		xpMult = pct("xp") * xpBoost * Stats.eventMultiplier(ctx.now, "xp"),
		luckMult = pct("luck") * luckBoost * Stats.eventMultiplier(ctx.now, "luck"),
		spellPowerMult = pct("spellPower"),
		spellCooldownMult = 1 / pct("spellHaste"),
		artifactSlots = slots,
		offlineCapHours = capHours,
		fullSet = setTier,
	}
end

return Stats
