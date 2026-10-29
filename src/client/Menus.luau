--!strict
-- The menu window: a column of big tab buttons on the left and one window
-- with a colored header per tab. Each tab is a function that fills the list
-- from the latest snapshot. Only relevant changes trigger a rebuild, and
-- button presses are allowed to finish before the list is replaced. Everything is built from the menu kit in Ui.luau (#82). On small
-- screens the tab column folds into one Menu button that opens a grid.

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local State = require(script.Parent:WaitForChild("State"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Wardrobe = require(script.Parent:WaitForChild("Wardrobe"))

local Icons = require(script.Parent:WaitForChild("Icons"))

local Menus = {}

local player = Players.LocalPlayer

type Render = (list: ScrollingFrame, snap: any) -> ()

local function counter(start: number?): () -> number
	local order = start or 0
	return function(): number
		order += 1
		return order
	end
end

local function tierRank(tier: string?): number
	return if tier then (table.find(Config.TierOrder, tier) or 0) else 0
end

local function percent(chance: number): string
	return `{string.format("%.2f", chance * 100)}%`
end

-- One island's artifact odds at a given luck, on the next enemy and boss.
local function oddsText(data: any, zoneId: number, luckMult: number): string
	local parts = {}
	for _, source in { "drop", "boss" } do
		local chance, _, unfound = Stats.artifactOdds(data, zoneId, source, luckMult)
		local spareChance, _, spares = Stats.spareOdds(data, zoneId, source, luckMult)
		local who = if source == "boss" then "boss" else "enemy"
		table.insert(
			parts,
			if unfound > 0
				then `{percent(chance)} on the next {who}`
				elseif
					spares
				then `{who} artifacts all found, {percent(spareChance)} on the next {who} for a spare copy`
				else `{who} artifacts all found`
		)
	end
	return table.concat(parts, ", ")
end

local function luckBoostEndsIn(data: any): number
	return math.max(((data.boosts or {}).luck or 0) - State.serverNow(), 0)
end

-- A darker shade of a world color, so white chip text stays readable.
local function deep(color: Color3): Color3
	return color:Lerp(Color3.new(0, 0, 0), 0.5)
end

local CHIP = {
	good = Color3.fromRGB(28, 126, 54),
	here = Color3.fromRGB(40, 96, 184),
	locked = Color3.fromRGB(150, 44, 48),
	gold = Color3.fromRGB(146, 100, 0),
	gray = Color3.fromRGB(84, 92, 110),
}

local function artifactRarity(id: string): string
	return Config.ArtifactSourceRarity[Config.Artifacts[id].source] or "common"
end

local function rarityRank(rarity: string): number
	return table.find(Config.RarityOrder, rarity) or 0
end

---------------------------------------------------------------- forge

-- What forging `tier` into `slot` adds, from the same math the server uses.
local function partGain(data: any, slot: string, tier: string): string
	local ctx = State.context()
	local before = Stats.compute(data, ctx)
	local trial = table.clone(data)
	trial.golem = table.clone(data.golem)
	trial.golem.parts = table.clone(data.golem.parts)
	trial.golem.parts[slot] = tier
	local after = Stats.compute(trial, ctx)
	local parts = {}
	local gains: { { name: string, amount: number } } = {
		{ name = "Health", amount = after.maxHealth - before.maxHealth },
		{ name = "Damage", amount = after.attackDamage - before.attackDamage },
		{ name = "Mining", amount = after.miningDamage - before.miningDamage },
		{ name = "Speed", amount = after.walkSpeed - before.walkSpeed },
	}
	for _, stat in gains do
		local amount = math.floor(stat.amount + 0.5)
		if amount > 0 then
			table.insert(parts, `+{amount} {stat.name}`)
		end
	end
	return if #parts > 0 then table.concat(parts, "  ") else "A sturdier part"
end

local function renderForge(list: ScrollingFrame, snap: any)
	local data = snap.data
	local stats = Stats.compute(data, State.context())
	local nextOrder = counter()

	Ui.summary(list, nextOrder(), {
		{ text = `Health {Ui.short(stats.maxHealth)}` },
		{ text = `Damage {Ui.short(stats.attackDamage)}` },
		{ text = `Mining {Ui.short(stats.miningDamage)}` },
		{ text = `Speed {math.floor(stats.walkSpeed)}` },
	})

	-- The set bonus as a progress line: the tier you have the most parts of.
	local counts: { [string]: number } = {}
	for _, slot in Config.SlotOrder do
		local tier = data.golem.parts[slot]
		if tier then
			counts[tier] = (counts[tier] or 0) + 1
		end
	end
	local bestTier, bestCount = nil, 0
	for _, tier in Config.TierOrder do
		if (counts[tier] or 0) >= bestCount and (counts[tier] or 0) > 0 then
			bestTier, bestCount = tier, counts[tier]
		end
	end
	local bonus = math.floor(Config.FullSetBonus * 100)
	if bestTier then
		local tierName = Config.Tiers[bestTier].displayName
		Ui.item(list, nextOrder(), {
			title = if stats.fullSet
				then `Full {Config.Tiers[stats.fullSet].displayName} set!`
				else `{bestCount} of 5 {tierName} parts`,
			subtitle = if stats.fullSet
				then `You get +{bonus}% health and damage.`
				else `A full set of 5 gives +{bonus}% health and damage.`,
			accent = Config.Tiers[bestTier].color,
			ready = stats.fullSet ~= nil,
			progress = { current = bestCount, max = #Config.SlotOrder },
		})
	end

	Ui.heading(list, nextOrder(), "Forge parts", "forge")
	for _, slot in Config.SlotOrder do
		local current = data.golem.parts[slot]
		local currentName = if current then Config.Tiers[current].displayName else "Bare stone"
		local currentColor = if current then Config.Tiers[current].color else Color3.fromRGB(110, 110, 110)
		local nextTier = Config.TierOrder[tierRank(current) + 1]
		local slotName = Config.Slots[slot].displayName
		if not nextTier then
			Ui.item(list, nextOrder(), {
				title = slotName,
				subtitle = "Best tier forged!",
				accent = currentColor,
				chips = { { text = currentName, color = deep(currentColor) } },
				action = { text = "Max", enabled = false },
			})
			continue
		end
		local cost = Stats.partCost(slot, nextTier)
		local canAfford = Stats.canAfford(data, cost)
		local missing = {}
		local bar: Ui.ProgressOptions? = nil
		for _, id in Config.MineralOrder do
			local need = cost[id]
			if need then
				local have = data.minerals[id] or 0
				if have < need then
					table.insert(missing, `{Ui.short(need - have)} more {Config.Minerals[id].displayName}`)
					if not bar then
						bar = {
							label = Config.Minerals[id].displayName,
							current = have,
							max = need,
							icon = id,
							color = Config.Minerals[id].color,
						}
					end
				end
			end
		end
		local nextName = Config.Tiers[nextTier].displayName
		Ui.item(list, nextOrder(), {
			title = `{slotName}: {partGain(data, slot, nextTier)}`,
			subtitle = if canAfford
				then `Forge {nextName} for {Ui.costText(cost)}.`
				else `Need {table.concat(missing, " and ")}.`,
			accent = Config.Tiers[nextTier].color,
			ready = canAfford,
			chips = {
				{ text = currentName, color = deep(currentColor) },
				{ text = `Next: {nextName}`, color = deep(Config.Tiers[nextTier].color) },
			},
			progress = bar,
			action = {
				text = "Forge",
				enabled = canAfford,
				onClick = function()
					State.request("craftPart", slot, nextTier)
				end,
			},
		})
	end
end

---------------------------------------------------------------- travel

-- The co-op Golem Tower section of Travel (TowerService). Every reward shown
-- here is the fixed amount the server pays (Stats.towerWaveReward).
local function renderTower(list: ScrollingFrame, snap: any, start: number)
	local tower = snap.tower
	if not tower or not tower.enabled then
		return
	end
	local nextOrder = counter(start)
	local name = Config.Tower.name
	local waves = Config.Tower.waves
	Ui.heading(list, nextOrder(), name, "party")
	local run = tower.run
	if run then
		local route = (Config.Zones[run.route] :: any).name
		if run.state == "inviting" then
			if run.isLeader then
				local waiting = 0
				for _, member in run.members do
					if not member.accepted then
						waiting += 1
					end
				end
				Ui.item(list, nextOrder(), {
					title = `{route} route: waiting for {waiting} to say yes`,
					subtitle = `The run starts when everyone says yes ({run.inviteLeft}s left).`,
					action = {
						text = "Cancel",
						style = "danger",
						onClick = function()
							State.request("towerLeave")
						end,
					},
				})
			else
				local reward = Stats.towerRunReward(run.route)
				Ui.item(list, nextOrder(), {
					title = `{run.leaderName} invites you: {route}, {waves} waves`,
					subtitle = `Clear it all for {Ui.rewardText(reward)}. {run.inviteLeft}s to answer.`,
					ready = true,
					action = {
						text = "Join",
						onClick = function()
							State.request("towerAccept")
						end,
					},
					second = {
						text = "No",
						style = "secondary",
						onClick = function()
							State.request("towerDecline")
						end,
					},
				})
			end
			return
		end
		local status = if run.state == "ended"
			then run.endText or "The run is over."
			elseif run.state == "break" then `Wave {run.wave + 1} of {waves} starts soon.`
			else `Wave {run.wave} of {waves}: {run.remaining} enemies left.`
		Ui.item(list, nextOrder(), {
			title = `{route} route`,
			subtitle = status,
			progress = { label = "Waves cleared", current = run.cleared, max = waves },
		})
		if run.state ~= "ended" then
			local nextWave = math.min(run.wave + (if run.state == "break" then 1 else 0), waves)
			local reward = Stats.towerWaveReward(run.route, math.max(nextWave, 1))
			Ui.item(list, nextOrder(), {
				title = `This wave pays {Ui.rewardText(reward)}`,
				subtitle = "If you leave, you keep what you've earned.",
				action = {
					text = "Leave",
					style = "danger",
					onClick = function()
						State.request("towerLeave")
					end,
				},
			})
		end
		return
	end

	local data = snap.data
	local bossList = {}
	for wave in Config.Tower.bossWaves do
		table.insert(bossList, wave)
	end
	table.sort(bossList)
	local bossWaves = table.concat(bossList, " and ")
	if not tower.isLeader then
		Ui.item(list, nextOrder(), {
			title = "Your party leader starts tower runs",
			subtitle = `{waves} waves together. Each wave pays as you clear it.`,
		})
		return
	end
	Ui.item(list, nextOrder(), {
		title = if tower.partySize > 1
			then `Climb with your party of {tower.partySize}`
			else "Climb solo or with a party",
		subtitle = `{waves} waves of one island's enemies. Its boss comes on waves {bossWaves}.`,
	})
	for _, zoneId in Config.ZoneOrder do
		if Stats.zoneUnlocked(data, zoneId) then
			local zone = Config.Zones[zoneId] :: any
			local reward = Stats.towerRunReward(zoneId)
			Ui.item(list, nextOrder(), {
				title = `{zone.name} route`,
				subtitle = `Clear it all for {Ui.rewardText(reward)}.`,
				accent = zone.color,
				action = {
					text = if tower.full then "Full" else "Start",
					enabled = not tower.full,
					onClick = function()
						State.request("towerStart", zoneId)
					end,
				},
			})
		end
	end
end

-- The guide explains a locked island, with a bar towards its gate.
local function explainLocked(data: any, zoneId: number)
	local zone = Config.Zones[zoneId] :: any
	local gate = zone.gate
	local progress: Ui.ProgressOptions? = nil
	local words: string
	if gate.boss and not Stats.bossDefeated(data, gate.boss) then
		local boss = Config.Bosses[gate.boss].displayName
		words = `{zone.name} is locked. Beat {boss} on {Config.Zones[gate.boss].name} to open it!`
		progress = {
			label = `Beat {boss}`,
			current = 0,
			max = 1,
			icon = "lock",
			hint = "Bosses wait in the far corner of their island.",
		}
	else
		local needed = Config.SizeLevels[gate.size or 1] or 1
		local level = Stats.levelForXp(data.golem.xp)
		words = `{zone.name} is locked. Grow your golem to size {gate.size} to get in!`
		progress = {
			label = "Golem level",
			current = level,
			max = needed,
			icon = "xp",
			hint = "Beat monsters and forge parts to grow.",
		}
	end
	Ui.dialog({
		name = "Guide",
		portrait = "guide",
		text = words,
		progress = progress,
		color = Ui.Headers.travel,
	})
end

local function renderTravel(list: ScrollingFrame, snap: any)
	local data = snap.data
	local currentZone = if snap.golem then snap.golem.zoneId else 1
	local nextOrder = counter()
	local inHub = currentZone == Config.HubZone
	Ui.item(list, nextOrder(), {
		title = Config.Hub.name,
		subtitle = "A safe island to show off your golem and meet players.",
		icon = "hub",
		chips = if inHub then { { text = "You are here", color = CHIP.here } } else nil,
		action = {
			text = "Travel",
			enabled = not inHub,
			onClick = function()
				State.request("travel", Config.HubZone)
			end,
		},
	})
	Ui.heading(list, nextOrder(), "Islands", "travel")
	for _, zoneId in Config.ZoneOrder do
		local zone = Config.Zones[zoneId] :: any
		local unlocked = Stats.zoneUnlocked(data, zoneId)
		local boss = Config.Bosses[zoneId]
		local beaten = Stats.bossDefeated(data, zoneId)
		local chips = {}
		if zoneId == currentZone then
			table.insert(chips, { text = "You are here", color = CHIP.here })
		end
		if not unlocked then
			table.insert(chips, { text = "Locked", color = CHIP.locked })
		elseif beaten then
			table.insert(chips, { text = "Boss beaten", color = CHIP.good })
		end
		local subtitle = if boss then `Boss: {boss.displayName}` else nil
		if zoneId == currentZone and snap.golem and boss then
			subtitle = if snap.golem.bossAlive
				then `{boss.displayName} is awake!`
				else `{boss.displayName} is back in about {snap.golem.bossRespawnIn}s.`
		end
		Ui.item(list, nextOrder(), {
			title = zone.name,
			subtitle = subtitle,
			icon = if not unlocked then "lock" elseif beaten then "tick" else "travel",
			accent = zone.color,
			chips = chips,
			action = if unlocked
				then {
					text = "Travel",
					enabled = zoneId ~= currentZone,
					onClick = function()
						State.request("travel", zoneId)
					end,
				}
				else {
					text = "How?",
					style = "secondary",
					onClick = function()
						explainLocked(data, zoneId)
					end,
				},
		})
	end
	renderTower(list, snap, 100)
end

---------------------------------------------------------------- artifacts

local artifactSort = "island"

local SOURCE_HINT = {
	drop = "Beat enemies here",
	boss = "Beat the boss here",
	hidden = "Hidden on the island",
}

local function artifactCard(grid: Instance, data: any, id: string, order: number)
	local artifact = Config.Artifacts[id]
	if not data.artifacts.found[id] then
		Ui.card(grid, {
			title = "???",
			line = SOURCE_HINT[artifact.source],
			stat = Config.Zones[artifact.zone].name,
			locked = true,
			order = order,
		})
		return
	end
	local equipped = table.find(data.artifacts.equipped, id) ~= nil
	local spare = (data.artifacts.spares or {})[id] or 0
	Ui.card(grid, {
		title = artifact.name,
		rarity = artifactRarity(id),
		line = if spare > 0 then `{spare} spare` else nil,
		icon = "artifacts",
		stat = Ui.bonusText(artifact.bonus),
		ticked = equipped,
		order = order,
		buttons = {
			{
				text = if equipped then "Unequip" else "Equip",
				style = if equipped then "secondary" else "primary",
				onClick = function()
					State.request(if equipped then "unequipArtifact" else "equipArtifact", id)
				end,
			},
		},
	})
end

-- What's left in this source's marble bag, in words.
local function bagText(data: any, zoneId: number, source: string, luckMult: number): string
	local marblesLeft, winnersLeft = Stats.artifactBag(data, zoneId, source, luckMult)
	if winnersLeft <= 0 then
		return `This bag's find is out; {marblesLeft} marbles left before a new bag.`
	end
	return `This bag: {winnersLeft} find in {marblesLeft} marbles left.`
end

-- The real odds on one island, one row per rarity, and the bag count.
local function oddsRows(list: ScrollingFrame, nextOrder: () -> number, data: any, zoneId: number, luckMult: number)
	for _, source in { "drop", "boss" } do
		local rarity = Ui.rarity(Config.ArtifactSourceRarity[source])
		local who = if source == "boss" then "boss win" else "enemy"
		local chance, rollsLeft, unfound = Stats.artifactOdds(data, zoneId, source, luckMult)
		if unfound > 0 then
			Ui.item(list, nextOrder(), {
				title = `{rarity.name}: {percent(chance)} on the next {who}`,
				subtitle = `{unfound} left to find. {bagText(data, zoneId, source, luckMult)} One is sure within {rollsLeft} more.`,
				icon = Config.ArtifactSourceRarity[source],
				accent = rarity.color,
				tint = rarity.dark,
			})
		else
			-- Everything from this source is found, so the same roll now
			-- gives spare copies to trade (see the Trade tab).
			local spareChance, spareLeft, spares = Stats.spareOdds(data, zoneId, source, luckMult)
			if spares then
				Ui.item(list, nextOrder(), {
					title = `{rarity.name} spares: {percent(spareChance)} on the next {who}`,
					subtitle = `All found here. {bagText(data, zoneId, source, luckMult)} A spare to trade is sure within {spareLeft} more.`,
					icon = Config.ArtifactSourceRarity[source],
					accent = rarity.color,
					tint = rarity.dark,
				})
			end
		end
	end
end

local function renderArtifacts(list: ScrollingFrame, snap: any)
	local data = snap.data
	local stats = Stats.compute(data, State.context())
	local nextOrder = counter()
	local zoneHere = if snap.golem and Config.Zones[snap.golem.zoneId] then snap.golem.zoneId else 1
	local foundHere, totalHere = Stats.zoneArtifactCount(data, zoneHere)
	Ui.summary(list, nextOrder(), {
		{ icon = "artifacts", text = `{#data.artifacts.equipped} / {stats.artifactSlots} equipped` },
		{ text = `Found {foundHere} / {totalHere} here` },
	})
	local boostLeft = luckBoostEndsIn(data)
	if boostLeft > 0 then
		Ui.item(list, nextOrder(), {
			title = `2x Luck is on for {Ui.duration(boostLeft)}`,
			subtitle = "The odds below include it. They drop back when it ends.",
			icon = "alert",
		})
	end
	if Stats.artifactsFound(data) == 0 then
		Ui.empty(list, nextOrder(), "No artifacts yet.", "Beat monsters to find your first one!")
	end
	Ui.toggles(
		list,
		nextOrder(),
		{
			{ id = "island", text = "By island" },
			{ id = "rarity", text = "By rarity" },
		},
		artifactSort,
		function(id: string)
			artifactSort = id
			Menus.refresh(true)
		end
	)

	if artifactSort == "rarity" then
		Ui.heading(list, nextOrder(), `Your odds on {Config.Zones[zoneHere].name}`)
		oddsRows(list, nextOrder, data, zoneHere, stats.luckMult)
		local ids = table.clone(Config.ArtifactOrder)
		table.sort(ids, function(a: string, b: string): boolean
			local ra, rb = rarityRank(artifactRarity(a)), rarityRank(artifactRarity(b))
			if ra ~= rb then
				return ra > rb
			end
			local fa, fb = data.artifacts.found[a] == true, data.artifacts.found[b] == true
			if fa ~= fb then
				return fa
			end
			return Config.Artifacts[a].name < Config.Artifacts[b].name
		end)
		local grid = Ui.grid(list, nextOrder(), Ui.CardSize)
		for index, id in ids do
			artifactCard(grid, data, id, index)
		end
		return
	end

	for _, zoneId in Config.ZoneOrder do
		local complete = Stats.zoneSetComplete(data, zoneId)
		local found, total = Stats.zoneArtifactCount(data, zoneId)
		Ui.heading(list, nextOrder(), `{Config.Zones[zoneId].name}  {found} / {total}`)
		Ui.item(list, nextOrder(), {
			title = if complete then "Set complete!" else "Find them all for a set bonus",
			subtitle = Ui.bonusText(Config.ZoneSetBonus),
			ready = complete,
			progress = { current = found, max = total },
		})
		oddsRows(list, nextOrder, data, zoneId, stats.luckMult)
		local grid = Ui.grid(list, nextOrder(), Ui.CardSize)
		local index = 0
		for _, id in Config.ArtifactOrder do
			if Config.Artifacts[id].zone == zoneId then
				index += 1
				artifactCard(grid, data, id, index)
			end
		end
	end
end

---------------------------------------------------------------- skills and awaken

local function renderSkills(list: ScrollingFrame, snap: any)
	local data = snap.data
	local nextOrder = counter()
	local points = Stats.skillPointsAvailable(data)
	Ui.summary(list, nextOrder(), {
		{ icon = "skills", text = `{points} skill point{if points == 1 then "" else "s"}` },
	})
	Ui.item(list, nextOrder(), {
		title = "You get 1 point each level.",
		subtitle = `Reset gives back your points. It costs {Ui.costText(Config.SkillRespecCost)}.`,
		action = {
			text = "Reset",
			style = "secondary",
			enabled = next(data.skills) ~= nil,
			onClick = function()
				State.request("respecSkills")
			end,
		},
	})
	for _, branch in Config.SkillBranches do
		Ui.heading(list, nextOrder(), branch.displayName, "skills")
		local grid = Ui.grid(list, nextOrder(), Ui.CardSize)
		for index, skillId in branch.nodes do
			local skill = Config.Skills[skillId]
			local extra = {}
			if next(skill.bonus) then
				table.insert(extra, Ui.bonusText(skill.bonus))
			end
			if skill.artifactSlots then
				table.insert(extra, `+{skill.artifactSlots} artifact slot`)
			end
			if skill.offlineHours then
				table.insert(extra, `+{skill.offlineHours}h offline mining`)
			end
			local learned = data.skills[skillId] == true
			local canLearn = Stats.canLearnSkill(data, skillId)
			Ui.card(grid, {
				title = skill.name,
				line = `{skill.cost} point{if skill.cost == 1 then "" else "s"}`,
				icon = "skills",
				stat = table.concat(extra, ", "),
				color = if learned then Ui.Styles.primary else Ui.Headers.skills,
				dark = Ui.Colors.card,
				ticked = learned,
				locked = not learned and not canLearn and points >= skill.cost,
				order = index,
				buttons = {
					{
						text = if learned then "Learned" else "Learn",
						enabled = canLearn and not learned,
						onClick = function()
							State.request("learnSkill", skillId)
						end,
					},
				},
			})
		end
	end
end

local function confirmReset(title: string, words: string, confirmText: string, action: string)
	Ui.dialog({
		name = title,
		portrait = "awaken",
		text = words,
		confirmText = confirmText,
		cancelText = "Not yet",
		color = Ui.Headers.awaken,
		onConfirm = function()
			State.request(action)
		end,
	})
end

local function renderAwaken(list: ScrollingFrame, snap: any)
	local data = snap.data
	local level = Stats.levelForXp(data.golem.xp)
	local nextOrder = counter()
	local count = data.awakening.count
	Ui.summary(list, nextOrder(), {
		{ icon = "awaken", text = `Awakened {count} time{if count == 1 then "" else "s"}` },
		{ text = `{Ui.short(data.awakening.shards)} shards` },
	})
	local canAwaken = level >= Config.Awakening.minLevel
	local shards = Stats.awakeningShards(level)
	local gain = Config.Awakening.mineralBonusPerAwakening
	Ui.item(list, nextOrder(), {
		title = if canAwaken then `Awaken now for {shards} shards!` else "Awaken",
		subtitle = `You start again at level 1 with no parts, skills or minerals. You keep artifacts, shards and upgrades, and get +{gain}% minerals forever.`,
		ready = canAwaken,
		progress = if canAwaken
			then nil
			else { label = "Level", current = level, max = Config.Awakening.minLevel, icon = "xp" },
		action = {
			text = "Awaken",
			enabled = canAwaken,
			onClick = function()
				confirmReset(
					"Awaken?",
					`This resets your level, parts, skills, minerals and bosses. You keep artifacts, shards and upgrades, and get {shards} shards.`,
					"Awaken!",
					"awaken"
				)
			end,
		},
	})

	local ascension = data.ascension or { count = 0, points = 0, upgrades = {} }
	local unspent = data.awakening.count - (ascension.spentAwakenings or 0)
	local required = Config.Ascension.requiredAwakenings
	local bossName = Config.Bosses[Config.Ascension.requiredBoss].displayName
	Ui.heading(list, nextOrder(), "Ascend", "awaken")
	Ui.summary(list, nextOrder(), {
		{ text = `Ascended {ascension.count}` },
		{ text = `{ascension.points} point{if ascension.points == 1 then "" else "s"}` },
	})
	Ui.item(list, nextOrder(), {
		title = `Needs {required} Awakenings and {bossName} beaten`,
		subtitle = `Uses {required} Awakenings (their bonuses stay). Resets like Awaken, and gives {Config.Ascension.points} point.`,
		ready = Stats.canAscend(data),
		progress = { label = "Unspent Awakenings", current = unspent, max = required },
		action = {
			text = "Ascend",
			enabled = Stats.canAscend(data),
			onClick = function()
				confirmReset(
					"Ascend?",
					`This uses {required} Awakenings and resets your level, parts, skills, minerals and bosses. You keep artifacts, cosmetics, shards and all upgrades.`,
					"Ascend!",
					"ascend"
				)
			end,
		},
	})
	for _, id in Config.AscendUpgradeOrder do
		local upgrade = Config.AscendUpgrades[id]
		local rank = ascension.upgrades[id] or 0
		local bonuses = {}
		for stat, amount in upgrade.bonus do
			table.insert(bonuses, `+{amount}% {stat}`)
		end
		Ui.item(list, nextOrder(), {
			title = upgrade.name,
			subtitle = table.concat(bonuses, ", ") .. " per rank",
			chips = { { text = `Rank {rank} / {upgrade.maxRank}`, color = CHIP.gray } },
			action = {
				text = if rank >= upgrade.maxRank then "Max" else `{upgrade.cost} pt`,
				enabled = rank < upgrade.maxRank and ascension.points >= upgrade.cost,
				onClick = function()
					State.request("buyAscendUpgrade", id)
				end,
			},
		})
	end

	Ui.heading(list, nextOrder(), "Shard upgrades")
	for _, id in Config.AwakenUpgradeOrder do
		local upgrade = Config.AwakenUpgrades[id]
		local rank = data.awakening.upgrades[id] or 0
		local maxed = rank >= upgrade.maxRank
		local cost = if maxed then 0 else Stats.upgradeCost(id, rank)
		Ui.item(list, nextOrder(), {
			title = upgrade.name,
			subtitle = if maxed then upgrade.description else `{upgrade.description} per rank`,
			chips = { { text = `Rank {rank} / {upgrade.maxRank}`, color = if maxed then CHIP.good else CHIP.gray } },
			action = {
				text = if maxed then "Max" else `{Ui.short(cost)} shards`,
				enabled = not maxed and data.awakening.shards >= cost,
				onClick = function()
					State.request("buyUpgrade", id)
				end,
			},
		})
	end
end

---------------------------------------------------------------- quests

-- The daily streak as a row of day boxes, today's highlighted.
local function dailyBoxes(list: ScrollingFrame, order: number, daily: any)
	local days = #Config.DailyRewards
	local today = (daily.nextStreak - 1) % days + 1
	local frame = Instance.new("Frame")
	frame.Name = "Days"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, -8, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.Parent = list
	local layout = Ui.listLayout(frame, 6, true)
	layout.Wraps = true
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	for day = 1, days do
		local claimed = if daily.canClaim then day < today else day <= today
		local isToday = daily.canClaim and day == today
		local box = Instance.new("Frame")
		box.Size = UDim2.fromOffset(72, 76)
		box.LayoutOrder = day
		box.Parent = frame
		Ui.corner(box, 10)
		local edge = Ui.surface(box, "studs", {
			tint = if claimed then Color3.fromRGB(24, 80, 40) elseif isToday then Ui.Headers.events else Ui.Colors.row,
		})
		if isToday then
			edge.Color = Ui.Colors.gold
			edge.Thickness = 3
		end
		Ui.label(box, `Day {day}`, UDim2.new(1, -4, 0, 24), UDim2.fromOffset(2, 4), {
			Title = true,
			TextSize = Ui.TextSize.body,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
		})
		local reward = Config.DailyRewards[day]
		local mark = Icons.create(box, if claimed then "tick" else Ui.rewardIcon(reward), 34, UDim2.new(0.5, 0, 0, 30))
		mark.AnchorPoint = Vector2.new(0.5, 0)
	end
end

local function renderQuests(list: ScrollingFrame, snap: any)
	local rewards = snap.rewards
	if not rewards then
		return
	end
	local nextOrder = counter()
	local anythingLeft = false

	Ui.heading(list, nextOrder(), "Daily login", "quests")
	dailyBoxes(list, nextOrder(), rewards.daily)
	local streakIndex = (rewards.daily.nextStreak - 1) % #Config.DailyRewards + 1
	if rewards.daily.canClaim then
		anythingLeft = true
		local reward = Config.DailyRewards[streakIndex]
		Ui.item(list, nextOrder(), {
			title = `Day {rewards.daily.nextStreak} reward`,
			subtitle = Ui.rewardText(reward),
			icon = Ui.rewardIcon(reward),
			ready = true,
			action = {
				text = "Claim",
				onClick = function()
					State.request("claimDaily")
				end,
			},
		})
	else
		Ui.item(list, nextOrder(), {
			title = `{rewards.daily.streak} day streak!`,
			subtitle = "Come back tomorrow for the next reward.",
			icon = "tick",
		})
	end

	Ui.heading(list, nextOrder(), "Gifts for playing")
	local played = State.serverNow() - (snap.sessionStart or State.serverNow())
	for index, gift in Config.SessionRewards do
		local claimed = table.find(rewards.sessionClaimed, index) ~= nil
		local remaining = gift.minutes * 60 - played
		local ready = not claimed and remaining <= 0
		if not claimed then
			anythingLeft = true
		end
		Ui.item(list, nextOrder(), {
			title = `{gift.minutes} minute gift`,
			subtitle = if claimed
				then "Opened!"
				elseif ready then "Ready!"
				else `Ready in {math.ceil(remaining / 60)} min.`,
			icon = if claimed then "tick" elseif ready then "alert" else Ui.rewardIcon(gift),
			ready = ready,
			chips = { { text = Ui.rewardText(gift), color = CHIP.gray } },
			action = {
				text = if claimed then "Opened" else "Open",
				enabled = ready,
				onClick = function()
					State.request("claimSession", index)
				end,
			},
		})
	end

	Ui.heading(list, nextOrder(), "Quests")
	-- Ready to claim first, then in progress, then done.
	local quests = table.clone(rewards.quests)
	local function rank(quest: any): number
		if quest.claimed then
			return 3
		end
		return if quest.progress >= quest.target then 1 else 2
	end
	table.sort(quests, function(a: any, b: any): boolean
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		return (a.weekly and 1 or 0) < (b.weekly and 1 or 0)
	end)
	local open = 0
	for _, quest in quests do
		local ready = not quest.claimed and quest.progress >= quest.target
		if not quest.claimed then
			open += 1
			anythingLeft = true
		end
		Ui.item(list, nextOrder(), {
			title = quest.text,
			icon = if quest.claimed then "tick" elseif ready then "alert" else "quests",
			ready = ready,
			chips = {
				if quest.weekly
					then { text = "Weekly", color = Ui.Headers.awaken }
					else { text = "Daily", color = Ui.Headers.quests },
				{ text = Ui.rewardText(quest.reward), color = CHIP.gray },
			},
			progress = if quest.claimed then nil else { current = quest.progress, max = quest.target },
			action = {
				text = if quest.claimed then "Done" else "Claim",
				enabled = ready,
				onClick = function()
					State.request("claimQuest", quest.id)
				end,
			},
		})
	end
	if open == 0 and #quests > 0 then
		Ui.empty(list, nextOrder(), "All quests done!", "New quests come tomorrow.")
	end

	if rewards.groupId ~= 0 and not rewards.groupClaimed then
		Ui.heading(list, nextOrder(), "Community")
		Ui.item(list, nextOrder(), {
			title = "Join our Roblox group",
			subtitle = `Then tap Check for {Ui.rewardText(Config.Group.reward)}.`,
			action = {
				text = "Check",
				onClick = function()
					State.request("claimGroup")
				end,
			},
		})
	end
	if not anythingLeft then
		Ui.empty(list, nextOrder(), "All done!", "New quests and gifts tomorrow.")
	end
end

---------------------------------------------------------------- party

local function renderParty(list: ScrollingFrame, snap: any)
	local party = snap.party
	if not party then
		return
	end
	local nextOrder = counter()
	Ui.summary(list, nextOrder(), {
		{ icon = "party", text = `{#party.members} / {Config.Party.maxSize} in party` },
		{ text = `Friend bonus +{party.friendBonus}%` },
	})
	local inviteMode = if snap.data and snap.data.social then snap.data.social.partyInvites or "friends" else "friends"
	local inviteLabel = if inviteMode == "everyone"
		then "Everyone"
		elseif inviteMode == "off" then "Off"
		else "Friends only"
	local nextInviteMode = if inviteMode == "friends"
		then "everyone"
		elseif inviteMode == "everyone" then "off"
		else "friends"
	Ui.item(list, nextOrder(), {
		title = `Party invites: {inviteLabel}`,
		subtitle = "Choose who can send you party invitations.",
		action = {
			text = "Change",
			style = "secondary",
			onClick = function()
				State.request("setPartyInvites", nextInviteMode)
			end,
		},
	})
	if not party.inParty and #party.others == 0 then
		Ui.empty(list, nextOrder(), "Playing solo.", "Invite a friend to fight together!")
	end
	if party.inParty then
		Ui.heading(list, nextOrder(), "Your party")
		for _, member in party.members do
			local chips = {}
			if member.leader then
				table.insert(chips, { text = "Leader", color = CHIP.gold })
			end
			if member.friend then
				table.insert(chips, { text = "Friend", color = CHIP.good })
			end
			Ui.item(list, nextOrder(), { title = member.name, chips = chips })
		end
		Ui.item(list, nextOrder(), {
			title = "Leave the party",
			subtitle = "You can join another one later.",
			action = {
				text = "Leave",
				style = "secondary",
				onClick = function()
					State.request("partyLeave")
				end,
			},
		})
	end

	if #party.invites > 0 then
		Ui.heading(list, nextOrder(), "Invites")
		for _, invite in party.invites do
			Ui.item(list, nextOrder(), {
				title = `{invite.name} invited you`,
				ready = true,
				action = {
					text = "Join",
					onClick = function()
						State.request("partyAccept", invite.userId)
					end,
				},
				second = {
					text = "No",
					style = "secondary",
					onClick = function()
						State.request("partyDecline", invite.userId)
					end,
				},
			})
		end
	end

	if #party.others > 0 then
		Ui.heading(list, nextOrder(), "Players in this server")
		for _, other in party.others do
			Ui.item(list, nextOrder(), {
				title = other.name,
				chips = if other.inParty then { { text = "In a party", color = CHIP.gray } } else nil,
				action = {
					text = "Invite",
					enabled = not other.inParty,
					onClick = function()
						State.request("partyInvite", other.userId)
					end,
				},
			})
		end
	end
	Ui.item(list, nextOrder(), {
		title = "How parties work",
		subtitle = "Players near a win share its rewards. Each friend adds +10% minerals.",
		icon = "guide",
	})
end

---------------------------------------------------------------- shop

-- The code being typed survives re-renders, and the list doesn't re-render
-- while the box has focus (that would drop the keyboard).
local codeDraft = ""
local codeBox: TextBox? = nil

local function codeEntry(list: ScrollingFrame, nextOrder: () -> number)
	local function redeem()
		if codeDraft ~= "" and State.request("redeemCode", codeDraft) then
			codeDraft = ""
		end
		Menus.refresh(true)
	end
	local codeRow = Ui.item(list, nextOrder(), {
		title = " ",
		action = { text = "Redeem", onClick = redeem },
	})
	local box = Instance.new("TextBox")
	box.Name = "CodeBox"
	box.Size = UDim2.new(1, -132, 0, 48)
	box.Position = UDim2.new()
	box.TextColor3 = Ui.Colors.text
	box.PlaceholderText = "Type a code"
	box.PlaceholderColor3 = Ui.Colors.quiet
	box.Text = codeDraft
	box.FontFace = Ui.Fonts.title
	box.TextSize = 22
	box.ClearTextOnFocus = false
	box.ZIndex = 3
	box.Parent = codeRow
	Ui.corner(box, 10)
	Ui.surface(box, "stone") -- a slot carved into the plate
	codeBox = box
	box:GetPropertyChangedSignal("Text"):Connect(function()
		codeDraft = string.sub(box.Text, 1, Config.CodeLimits.maxLength)
	end)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)
end

local function renderShop(list: ScrollingFrame, snap: any)
	local data = snap.data
	local passes = snap.passes or {}
	local nextOrder = counter()
	Ui.heading(list, nextOrder(), "Codes", "shop")
	codeEntry(list, nextOrder)
	Ui.item(list, nextOrder(), {
		title = "Codes are always free.",
		subtitle = "New codes come out with updates and on our group wall.",
		icon = "guide",
	})

	Ui.item(list, nextOrder(), {
		title = "Looking for skins and pets?",
		subtitle = "They're in the Wardrobe, with a preview first.",
		icon = "wardrobe",
	})

	Ui.heading(list, nextOrder(), "Game passes (yours forever)")
	for _, key in Config.GamePassOrder do
		local pass = Config.GamePasses[key]
		local owned = passes[key] == true
		Ui.item(list, nextOrder(), {
			title = pass.name,
			subtitle = pass.description,
			icon = if owned then "tick" else "shop",
			tint = Ui.Colors.card,
			chips = if owned then { { text = "Owned", color = CHIP.good } } else nil,
			action = if owned
				then { text = "Owned", enabled = false }
				elseif pass.id == 0 then { text = "Soon", enabled = false }
				else {
					text = tostring(pass.price),
					style = "robux",
					onClick = function()
						Remotes.Track:FireServer("purchasePrompted", "pass", key)
						MarketplaceService:PromptGamePassPurchase(player, pass.id)
					end,
				},
		})
	end

	Ui.heading(list, nextOrder(), "Packs and boosts")
	local now = State.serverNow()
	local policy = snap.policy or {}
	for _, key in Config.ProductOrder do
		local product = Config.Products[key]
		local activeFor = if product.boost then math.max((data.boosts[product.boost] or 0) - now, 0) else 0
		if product.paidRandom and not policy.paidRandomItems then
			-- Hidden where Roblox restricts paid random items, and until the
			-- server has checked. Time already bought still shows.
			if activeFor > 0 then
				Ui.item(list, nextOrder(), { title = product.name, subtitle = `On for {Ui.duration(activeFor)}` })
			end
			continue
		end
		local subtitle = if product.boost then "Buying more adds more time." else "Minerals from your best island."
		if product.boost == "luck" then
			subtitle = `Doubles your artifact odds for {product.minutes} min. Your real odds are below.`
		end
		local chips = nil
		if activeFor > 0 then
			chips = { { text = `On: {Ui.duration(activeFor)}`, color = CHIP.good } }
		end
		local buy = {
			text = if product.id == 0 then "Soon" else tostring(product.price),
			style = if product.id == 0 then nil else "robux" :: Ui.ButtonStyle,
			enabled = product.id ~= 0,
			onClick = function()
				Remotes.Track:FireServer("purchasePrompted", "product", key)
				MarketplaceService:PromptProductPurchase(player, product.id)
			end,
		}
		if product.boost ~= "luck" then
			Ui.item(list, nextOrder(), {
				title = product.name,
				subtitle = subtitle,
				icon = if product.boost == "xp" then "xp" else "stone",
				tint = Ui.Colors.card,
				chips = chips,
				action = buy,
			})
			continue
		end
		-- 2x Luck: the player's actual odds on this island right now, from
		-- the same numbers the server rolls with, and what the boost changes
		-- them to, all shown before the buy button.
		local zoneId = if snap.golem and Config.Zones[snap.golem.zoneId] then snap.golem.zoneId else 1
		local luckMult = Stats.compute(data, State.context()).luckMult
		local zoneName = Config.Zones[zoneId].name
		Ui.item(list, nextOrder(), {
			title = product.name,
			subtitle = subtitle,
			icon = "rare",
			tint = Ui.Colors.card,
			chips = chips,
		})
		if activeFor > 0 then
			Ui.item(list, nextOrder(), {
				title = `Your odds on {zoneName} (2x Luck on)`,
				subtitle = `{oddsText(data, zoneId, luckMult)}. Without it: {oddsText(data, zoneId, luckMult / 2)}.`,
			})
		else
			Ui.item(list, nextOrder(), {
				title = `Your odds on {zoneName} now`,
				subtitle = `{oddsText(data, zoneId, luckMult)}. With 2x Luck: {oddsText(data, zoneId, luckMult * 2)}.`,
			})
		end
		local pity = {}
		for _, source in { "drop", "boss" } do
			local _, rollsLeft, unfound = Stats.artifactOdds(data, zoneId, source, luckMult)
			local _, spareLeft, spares = Stats.spareOdds(data, zoneId, source, luckMult)
			local what = if source == "boss" then "boss wins" else "enemies"
			if unfound > 0 then
				table.insert(pity, `{rollsLeft} more {what}`)
			elseif spares then
				table.insert(pity, `{spareLeft} more {what} for a spare copy`)
			end
		end
		if #pity > 0 then
			Ui.item(list, nextOrder(), {
				title = "Marble bag: no long dry streaks (boost or not)",
				subtitle = `One is sure to drop here within {table.concat(pity, " or ")}.`,
			})
		end
		Ui.item(list, nextOrder(), {
			title = "Spares found with 2x Luck can't be traded.",
			action = buy,
		})
	end
	Ui.item(list, nextOrder(), {
		title = "Fair play",
		subtitle = "Everything that makes you stronger can also be earned by playing.",
		icon = "guide",
	})
end

local function renderWardrobe(list: ScrollingFrame, snap: any)
	Wardrobe.render(list, snap, counter(), function()
		Menus.refresh(true)
	end)
end

---------------------------------------------------------------- events

local EARN_NAMES = { enemyDefeated = "enemy", nodeMined = "rock", bossDefeated = "boss" }

local function eventTrackState(
	event: any,
	state: any,
	live: boolean,
	startsAt: number?
): (number, { [string]: boolean })
	local track = event.track
	local tokens = if state then state.tokens else 0
	local claimed = if state then state.claimed else {}
	-- Same rule as the server: a finished track starts over in a new run.
	if live and state and state.run ~= startsAt then
		local finished = true
		for index in track.tiers do
			if not claimed[tostring(index)] then
				finished = false
			end
		end
		if finished then
			tokens, claimed = 0, {}
		end
	end
	return tokens, claimed
end

local function renderEvents(list: ScrollingFrame, snap: any)
	local data = snap.data
	local now = State.serverNow()
	local nextOrder = counter()
	local shown = 0
	for _, event in Config.Events do
		local startsAt, endsAt = Stats.eventWindow(event, now)
		local live = startsAt ~= nil and endsAt ~= nil and now >= startsAt
		local state = data.eventTracks[event.id]
		if not startsAt and not state then
			continue -- a one-off event that's over and was never played
		end
		shown += 1
		Ui.heading(list, nextOrder(), event.name, "events")
		local effects = Ui.modifierText(event.modifiers)
		if live and endsAt then
			Ui.item(list, nextOrder(), {
				title = if effects ~= "" then effects else event.description,
				subtitle = if effects ~= "" then event.description else nil,
				chips = {
					{ text = "Live now!", color = CHIP.good },
					{ text = Ui.timeLeft(endsAt - now), color = CHIP.gray },
				},
			})
		elseif startsAt then
			local wait = string.gsub(Ui.timeLeft(startsAt - now), " left", "")
			Ui.item(list, nextOrder(), {
				title = event.description,
				chips = { { text = `Starts in {wait}`, color = CHIP.gray } },
			})
		else
			Ui.item(list, nextOrder(), {
				title = "This event is over.",
				subtitle = "You can still claim rewards you earned.",
			})
		end

		local track = event.track
		if track then
			local tokens, claimed = eventTrackState(event, state, live, startsAt)
			local earn = {}
			for eventName, amount in track.earn do
				table.insert(earn, `{amount} per {EARN_NAMES[eventName] or eventName}`)
			end
			table.sort(earn)
			local goal = nil
			for _, tier in track.tiers do
				if tokens < tier.tokens then
					goal = tier.tokens
					break
				end
			end
			Ui.progress(list, {
				label = track.currency,
				current = tokens,
				max = goal or tokens,
				icon = "eventPoints",
				color = Ui.Colors.gold,
				order = nextOrder(),
				hint = `Earn {table.concat(earn, ", ")} while it's on.`,
				doneText = "ALL EARNED!",
			}).Size =
				UDim2.new(1, -8, 0, 0)
			local grid = Ui.grid(list, nextOrder(), Ui.CardSize)
			for index, tier in track.tiers do
				local done = claimed[tostring(index)] == true
				local ready = not done and tokens >= tier.tokens
				Ui.card(grid, {
					title = `Reward {index}`,
					line = `{tier.tokens} {track.currency}`,
					icon = Ui.rewardIcon(tier.reward),
					stat = Ui.rewardText(tier.reward),
					color = if ready then Ui.Colors.gold else Ui.Headers.events,
					dark = Ui.Colors.card,
					ticked = done,
					order = index,
					buttons = {
						{
							text = if done
								then "Claimed"
								elseif ready then "Claim"
								else `{Ui.short(math.min(tokens, tier.tokens))} / {Ui.short(tier.tokens)}`,
							enabled = ready,
							onClick = function()
								State.request("claimEventTier", event.id, index)
							end,
						},
					},
				})
			end
		end
	end
	if shown == 0 then
		Ui.empty(list, nextOrder(), "No event right now.", "Check back soon!")
	end
	Ui.item(list, nextOrder(), {
		title = "Fair play",
		subtitle = "Event rewards come from playing. Points you don't spend carry over to the next run.",
		icon = "guide",
	})
end

---------------------------------------------------------------- ranks

local PLACE_COLORS = {
	Color3.fromRGB(120, 88, 0), -- gold
	Color3.fromRGB(78, 86, 102), -- silver
	Color3.fromRGB(110, 62, 30), -- bronze
}

local function myScore(data: any, board: string): number
	if board == "level" then
		return Stats.levelForXp(data.golem.xp)
	elseif board == "awakenings" then
		return data.awakening.count
	elseif board == "artifacts" then
		return Stats.artifactsFound(data)
	end
	return 0
end

local function renderRanks(list: ScrollingFrame, snap: any)
	local boards = snap.leaderboards or {}
	local nextOrder = counter()
	for _, board in Config.Leaderboards.boards do
		Ui.heading(list, nextOrder(), board.displayName, "ranks")
		local entries = boards[board.id]
		local mine = nil
		if not entries or #entries == 0 then
			Ui.empty(
				list,
				nextOrder(),
				"No scores yet. Be the first!",
				"Scores update every few minutes in published games."
			)
		else
			for rank, entry in entries do
				if entry.name == player.Name then
					mine = rank
				end
				Ui.item(list, nextOrder(), {
					title = entry.name,
					tint = PLACE_COLORS[rank],
					ready = entry.name == player.Name,
					chips = { { text = `#{rank}`, color = if PLACE_COLORS[rank] then CHIP.gold else CHIP.gray } },
					subtitle = Ui.short(entry.value),
				})
			end
		end
		-- Your own row, always.
		local score = if State.snapshot then myScore(snap.data, board.id) else 0
		Ui.item(list, nextOrder(), {
			title = `You: {Ui.short(score)}`,
			subtitle = if mine then `You're #{mine}!` else `Not in the top {Config.Leaderboards.size} yet. Keep going!`,
			tint = Ui.Styles.secondary,
			icon = "ranks",
		})
	end
end

---------------------------------------------------------------- hub

-- Whose inspect card is open in the Hub tab.
local inspectedId: number? = nil

local function unlockText(unlock: any): string
	if unlock.kind == "boss" then
		return `Beat {Config.Bosses[unlock.zone].displayName}`
	elseif unlock.kind == "zoneSet" then
		return `Find every artifact in {Config.Zones[unlock.zone].name}`
	elseif unlock.kind == "awaken" then
		return `Awaken {unlock.count} time{if unlock.count == 1 then "" else "s"}`
	elseif unlock.kind == "level" then
		return `Reach level {unlock.level}`
	end
	return "Keep playing"
end

local function renderHub(list: ScrollingFrame, snap: any)
	local hub = snap.hub
	if not hub then
		return
	end
	local data = snap.data
	local nextOrder = counter()

	Ui.heading(list, nextOrder(), `Players here ({#hub.others})`, "hub")
	if #hub.others == 0 then
		Ui.empty(list, nextOrder(), "Nobody else is here yet.", "Visit the Golem Hub from Travel to meet players.")
	end
	for _, other in hub.others do
		local shown = inspectedId == other.userId
		Ui.item(list, nextOrder(), {
			title = other.name,
			subtitle = `Level {other.level}  ·  Size {other.size}  ·  {other.awakenings} Awakenings`,
			chips = if other.title then { { text = other.title, color = CHIP.gold } } else nil,
			action = {
				text = if shown then "Hide" else "Look",
				style = if shown then "secondary" else "primary",
				onClick = function()
					inspectedId = if shown then nil else other.userId
					Menus.refresh(true)
				end,
			},
		})
		if shown then
			-- The inspect card: a framed panel with their golem's details.
			local card = Ui.item(list, nextOrder(), {
				title = `{other.name}'s golem`,
				subtitle = table.concat(other.parts, "  ·  "),
				icon = "hub",
				tint = Ui.Colors.card,
				ready = true,
				chips = {
					{
						text = `Artifacts {other.artifactsFound} / {#Config.ArtifactOrder}`,
						color = Ui.Headers.artifacts,
					},
					{ text = `Bosses {other.bosses} / {#Config.ZoneOrder}`, color = CHIP.locked },
				},
			})
			local column = card:FindFirstChild("Text")
			if column then
				local wearing = Ui.text(
					column,
					if #other.equipped > 0 then `Wearing: {table.concat(other.equipped, ", ")}` else "No artifacts on.",
					Ui.TextSize.body,
					{ TextColor3 = Ui.Colors.quiet }
				)
				wearing.LayoutOrder = 5
			end
		end
	end

	Ui.heading(list, nextOrder(), "Titles (on your nametag)")
	local wearing = Stats.equippedTitle(data)
	Ui.item(list, nextOrder(), {
		title = "No title",
		chips = if wearing == nil then { { text = "Wearing", color = CHIP.good } } else nil,
		action = {
			text = "Remove",
			style = "secondary",
			enabled = wearing ~= nil,
			onClick = function()
				State.request("setTitle", "")
			end,
		},
	})
	for _, title in hub.titles do
		local def = Config.Titles[title.id]
		local on = wearing == title.name
		Ui.item(list, nextOrder(), {
			title = title.name,
			subtitle = if title.earned then nil else unlockText(def.unlock),
			icon = if on then "tick" elseif title.earned then "ranks" else "lock",
			chips = if on then { { text = "Wearing", color = CHIP.good } } else nil,
			action = {
				text = if on then "On" elseif title.earned then "Wear" else "Locked",
				enabled = title.earned and not on,
				onClick = function()
					State.request("setTitle", title.id)
				end,
			},
		})
	end

	Ui.heading(list, nextOrder(), "Settings")
	local announce = data.social == nil or data.social.announce ~= false
	Ui.item(list, nextOrder(), {
		title = `Rare-find messages: {if announce then "On" else "Off"}`,
		subtitle = "A short message when someone finds a boss or relic artifact.",
		action = {
			text = if announce then "Turn off" else "Turn on",
			style = "secondary",
			onClick = function()
				State.request("setAnnounce", not announce)
			end,
		},
	})
	local inviteMode = if snap.data and snap.data.social then snap.data.social.partyInvites or "friends" else "friends"
	local inviteLabel = if inviteMode == "everyone"
		then "Everyone"
		elseif inviteMode == "off" then "Off"
		else "Friends only"
	local nextInviteMode = if inviteMode == "friends"
		then "everyone"
		elseif inviteMode == "everyone" then "off"
		else "friends"
	Ui.item(list, nextOrder(), {
		title = `Party invites: {inviteLabel}`,
		subtitle = "Choose who can send you party invitations.",
		action = {
			text = "Change",
			style = "secondary",
			onClick = function()
				State.request("setPartyInvites", nextInviteMode)
			end,
		},
	})
end

---------------------------------------------------------------- trade

local SOURCE_NAMES = { drop = "Enemy drop", boss = "Boss drop", hidden = "Hidden relic" }
local spareSort = "name"

local function sortSpares(spares: { any }): { any }
	local sorted = table.clone(spares)
	table.sort(sorted, function(a: any, b: any): boolean
		if spareSort == "rarity" then
			local ra = if Config.Artifacts[a.id] then rarityRank(artifactRarity(a.id)) else 0
			local rb = if Config.Artifacts[b.id] then rarityRank(artifactRarity(b.id)) else 0
			if ra ~= rb then
				return ra > rb
			end
		end
		return a.name < b.name
	end)
	return sorted
end

-- One side of the trade: a header, then its items as small rows.
local function tradeSide(parent: Instance, order: number, wide: boolean, title: string): Frame
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.Size = if wide then UDim2.new(0.5, -6, 0, 0) else UDim2.fromScale(1, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.LayoutOrder = order
	column.Parent = parent
	local layout = Ui.listLayout(column, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local head = Ui.heading(column, 0, title)
	head.Size = UDim2.fromScale(1, 0)
	return column
end

local function renderTrade(list: ScrollingFrame, snap: any)
	local trade = snap.trade
	if not trade then
		return
	end
	local nextOrder = counter()
	local view = trade.trade

	if view then
		local name = view.partner.name
		Ui.summary(list, nextOrder(), { { icon = "trade", text = `Trading with {name}` } })

		-- You give and you get, side by side when there's room.
		local wide = list.AbsoluteSize.X >= 560
		local sides = Instance.new("Frame")
		sides.BackgroundTransparency = 1
		sides.Size = UDim2.new(1, -8, 0, 0)
		sides.AutomaticSize = Enum.AutomaticSize.Y
		sides.LayoutOrder = nextOrder()
		sides.Parent = list
		local sidesLayout = Ui.listLayout(sides, 12, wide)
		sidesLayout.VerticalAlignment = Enum.VerticalAlignment.Top

		local give = tradeSide(sides, 1, wide, "You give")
		local giveOrder = counter()
		for _, item in view.mine do
			Ui.item(give, giveOrder(), {
				title = item.name,
				subtitle = SOURCE_NAMES[item.source],
				icon = if Config.Artifacts[item.id] then artifactRarity(item.id) else "artifacts",
				action = {
					text = "Remove",
					style = "secondary",
					onClick = function()
						State.request("tradeRemove", item.id)
					end,
				},
			}).Size =
				UDim2.fromScale(1, 0)
		end
		if #view.mine == 0 then
			Ui.empty(give, giveOrder(), "Nothing yet.", "Pick a spare copy below.").Size = UDim2.fromScale(1, 0)
		end

		local get = tradeSide(sides, 2, wide, `You get`)
		local getOrder = counter()
		for _, item in view.theirs do
			Ui.item(get, getOrder(), {
				title = item.name,
				subtitle = SOURCE_NAMES[item.source],
				icon = if Config.Artifacts[item.id] then artifactRarity(item.id) else "artifacts",
			}).Size =
				UDim2.fromScale(1, 0)
		end
		if #view.theirs == 0 then
			Ui.empty(get, getOrder(), "Nothing yet.", `{name} hasn't added anything. Fine for a gift, but check.`).Size =
				UDim2.fromScale(1, 0)
		end

		if view.lopsided then
			Ui.item(list, nextOrder(), {
				title = "Careful: you give much more than you get.",
				subtitle = "Only go ahead if you really want to. You can't undo a trade.",
				icon = "alert",
				tint = Color3.fromRGB(110, 40, 44),
			})
		end

		-- The footer: who is ready, and the one big button.
		local offered = {}
		for _, item in view.mine do
			offered[item.id] = true
		end
		local bothReady = view.myReady and view.theirReady
		local remaining = if bothReady and view.confirmAt then view.confirmAt - State.serverNow() else 0
		local summary = `You: {if view.myReady then "Ready" else "Not ready"}  ·  {name}: {if view.theirReady
			then "Ready"
			else "Not ready"}`
		local counts = `{#view.mine} for {#view.theirs}`
		local action: Ui.Action
		if not bothReady then
			action = {
				text = if view.myReady then "Not ready" else "Ready",
				style = if view.myReady then "secondary" else "primary",
				enabled = view.myReady or #view.mine + #view.theirs > 0,
				onClick = function()
					State.request("tradeReady", not view.myReady)
				end,
			}
		elseif remaining > 0 then
			action = { text = `Wait {remaining}`, enabled = false }
		elseif view.myConfirmed then
			action = { text = "Confirmed", enabled = false }
		else
			action = {
				text = `Swap {counts}`,
				onClick = function()
					State.request("tradeConfirm")
				end,
			}
		end
		Ui.item(list, nextOrder(), {
			title = summary,
			subtitle = if bothReady and view.theirConfirmed
				then `{name} has confirmed.`
				elseif bothReady and remaining > 0 then "Take a moment to check the trade."
				else "Changing anything makes you both not ready.",
			tint = Ui.Colors.card,
			ready = bothReady and not view.myConfirmed and remaining <= 0,
			action = action,
			second = if bothReady and not view.myConfirmed
				then {
					text = "Not sure",
					style = "secondary",
					onClick = function()
						State.request("tradeReady", false)
					end,
				}
				else nil,
		})
		Ui.item(list, nextOrder(), {
			title = "Cancel this trade",
			action = {
				text = "Cancel",
				style = "danger",
				onClick = function()
					State.request("tradeCancel")
				end,
			},
		})

		Ui.heading(list, nextOrder(), "Your spares to offer")
		Ui.toggles(
			list,
			nextOrder(),
			{
				{ id = "name", text = "By name" },
				{ id = "rarity", text = "By rarity" },
			},
			spareSort,
			function(id: string)
				spareSort = id
				Menus.refresh(true)
			end
		)
		local any = false
		for _, spare in sortSpares(trade.spares) do
			if spare.tradable > 0 and not offered[spare.id] then
				any = true
				Ui.item(list, nextOrder(), {
					title = spare.name,
					subtitle = `{spare.tradable} spare to trade`,
					icon = if Config.Artifacts[spare.id] then artifactRarity(spare.id) else "artifacts",
					action = {
						text = "Offer",
						enabled = #view.mine < Config.Trading.maxItems,
						onClick = function()
							State.request("tradeOffer", spare.id)
						end,
					},
				})
			end
		end
		if not any then
			Ui.empty(list, nextOrder(), "No more spares to offer.")
		end
		Ui.item(list, nextOrder(), {
			title = "Stay safe",
			subtitle = "Trade with people you know. Never trade for Robux or anything outside the game.",
			icon = "guide",
		})
		return
	end

	Ui.summary(list, nextOrder(), {
		{ icon = "trade", text = `{trade.left} trades left today` },
	})
	if trade.blocked then
		Ui.empty(list, nextOrder(), "Trading is off for now.", trade.blocked)
	end
	if #trade.incoming > 0 then
		Ui.heading(list, nextOrder(), "Requests")
		for _, request in trade.incoming do
			Ui.item(list, nextOrder(), {
				title = `{request.name} wants to trade`,
				ready = trade.blocked == nil,
				action = {
					text = "Accept",
					enabled = trade.blocked == nil,
					onClick = function()
						State.request("tradeAccept", request.userId)
					end,
				},
				second = {
					text = "No",
					style = "secondary",
					onClick = function()
						State.request("tradeDecline", request.userId)
					end,
				},
			})
		end
	end

	Ui.heading(list, nextOrder(), "Your spare copies")
	if #trade.spares == 0 then
		Ui.empty(list, nextOrder(), "No spares yet.", "Find a second copy of an artifact to trade it.")
	else
		Ui.toggles(
			list,
			nextOrder(),
			{
				{ id = "name", text = "By name" },
				{ id = "rarity", text = "By rarity" },
			},
			spareSort,
			function(id: string)
				spareSort = id
				Menus.refresh(true)
			end
		)
	end
	for _, spare in sortSpares(trade.spares) do
		local chips = { { text = `{spare.tradable} to trade`, color = CHIP.good } }
		if spare.bound > 0 then
			table.insert(chips, { text = `{spare.bound} kept (2x Luck)`, color = CHIP.gray })
		end
		Ui.item(list, nextOrder(), {
			title = spare.name,
			icon = if Config.Artifacts[spare.id] then artifactRarity(spare.id) else "artifacts",
			chips = chips,
		})
	end
	Ui.item(list, nextOrder(), {
		title = "What you can trade",
		subtitle = "Spare copies can be traded. Your first copy of each artifact, and spares found with 2x Luck, stay yours.",
		icon = "guide",
	})

	Ui.heading(list, nextOrder(), "Friends and party members here")
	if #trade.partners == 0 then
		Ui.empty(
			list,
			nextOrder(),
			"Nobody to trade with yet.",
			"Trade with Roblox friends and party members. Invite one from Party."
		)
	end
	for _, partner in trade.partners do
		Ui.item(list, nextOrder(), {
			title = partner.name,
			chips = if partner.busy then { { text = "Busy trading", color = CHIP.gray } } else nil,
			action = {
				text = "Trade",
				enabled = trade.blocked == nil and not partner.busy,
				onClick = function()
					State.request("tradeRequest", partner.userId)
				end,
			},
		})
	end
	Ui.item(list, nextOrder(), {
		title = "How trading works",
		subtitle = "Both press Ready, wait for the timer, then both press Swap.",
		icon = "guide",
	})
end

local TABS: { { id: string, name: string, render: Render } } = {
	{ id = "forge", name = "Forge", render = renderForge },
	{ id = "travel", name = "Travel", render = renderTravel },
	{ id = "artifacts", name = "Artifacts", render = renderArtifacts },
	{ id = "skills", name = "Skills", render = renderSkills },
	{ id = "awaken", name = "Awaken", render = renderAwaken },
	{ id = "quests", name = "Quests", render = renderQuests },
	{ id = "events", name = "Events", render = renderEvents },
	{ id = "party", name = "Party", render = renderParty },
	{ id = "hub", name = "Hub", render = renderHub },
	{ id = "trade", name = "Trade", render = renderTrade },
	{ id = "wardrobe", name = "Wardrobe", render = renderWardrobe },
	{ id = "shop", name = "Shop", render = renderShop },
	{ id = "ranks", name = "Ranks", render = renderRanks },
}

---------------------------------------------------------------- badges

-- What each badged tab has ready, worked out from the same snapshot the tab
-- shows, so a badge clears the moment its reward is claimed.
local function badges(snap: any): { [string]: boolean }
	local result: { [string]: boolean } = {}
	local data = snap.data
	local rewards = snap.rewards
	if rewards then
		local ready = rewards.daily.canClaim == true
		local played = State.serverNow() - (snap.sessionStart or State.serverNow())
		for index, gift in Config.SessionRewards do
			if not table.find(rewards.sessionClaimed, index) and gift.minutes * 60 - played <= 0 then
				ready = true
			end
		end
		for _, quest in rewards.quests do
			if not quest.claimed and quest.progress >= quest.target then
				ready = true
			end
		end
		result.quests = ready
	end
	local now = State.serverNow()
	for _, event in Config.Events do
		local track = event.track
		local state = data.eventTracks[event.id]
		if track and state then
			local startsAt, endsAt = Stats.eventWindow(event, now)
			local live = startsAt ~= nil and endsAt ~= nil and now >= startsAt
			local tokens, claimed = eventTrackState(event, state, live, startsAt)
			for index, tier in track.tiers do
				if not claimed[tostring(index)] and tokens >= tier.tokens then
					result.events = true
				end
			end
		end
	end
	-- Artifacts: one found but not worn while a slot is free.
	local stats = Stats.compute(data, State.context())
	if #data.artifacts.equipped < stats.artifactSlots then
		for id in data.artifacts.found do
			if not table.find(data.artifacts.equipped, id) then
				result.artifacts = true
				break
			end
		end
	end
	return result
end

---------------------------------------------------------------- window

local window: Ui.Window
local list: ScrollingFrame
local openTab: number? = nil
local tabButtons: { [string]: TextButton } = {}
local menuButton: TextButton
local menuGrid: Ui.Window
local compact = false
local themed: string? = nil
local lastTabId: string? = nil
local lastSignature: string? = nil
local lastRenderAt = 0
local refreshScheduled = false
local pendingRefresh = false
local heldInputs: { [InputObject]: boolean } = {}
local heldCount = 0

-- Even when a visible number changes on every mining tick, don't destroy
-- a full tab four times per second. User-initiated changes bypass this cap.
local MIN_REBUILD_INTERVAL = 0.75

-- The tutorial points at these. When the tabs are folded away, it points at
-- the Menu button first.
function Menus.getTabButton(id: string): TextButton?
	if compact and not menuGrid.frame.Visible then
		return menuButton
	end
	return tabButtons[id]
end

function Menus.isOpen(id: string): boolean
	return openTab ~= nil and TABS[openTab].id == id
end

local function refreshBadges()
	local snap = State.snapshot
	if not snap then
		return
	end
	local ok, ready = pcall(badges, snap)
	if not ok then
		return
	end
	local anything = false
	for _, tab in TABS do
		local on = ready[tab.id] == true
		anything = anything or on
		local b = tabButtons[tab.id]
		if b then
			Ui.badge(b, on)
		end
	end
	if menuButton then
		Ui.badge(menuButton, anything)
	end
end

-- Only serialize the fields a tab actually reads. In particular, the Party,
-- Hub, Ranks and Wardrobe tabs should not rebuild when a mineral is mined.
-- The server sends fresh table instances on every snapshot, so reference
-- equality cannot detect unchanged data.
local function tabSignature(tabId: string, snap: any): string
	local data = snap.data
	local fields: any
	if tabId == "forge" then
		fields = {
			golem = { level = Stats.levelForXp(data.golem.xp), parts = data.golem.parts },
			minerals = data.minerals,
			skills = data.skills,
			awakening = data.awakening,
			ascension = data.ascension,
			found = data.artifacts.found,
			equipped = data.artifacts.equipped,
			passes = snap.passes,
		}
	elseif tabId == "travel" then
		fields = {
			level = Stats.levelForXp(data.golem.xp),
			bosses = data.bossesDefeated,
			golem = snap.golem,
			tower = snap.tower,
		}
	elseif tabId == "artifacts" then
		fields = {
			artifacts = data.artifacts,
			skills = data.skills,
			awakening = data.awakening,
			ascension = data.ascension,
			boosts = data.boosts,
			passes = snap.passes,
			zone = snap.golem and snap.golem.zoneId,
		}
	elseif tabId == "skills" then
		fields = { level = Stats.levelForXp(data.golem.xp), skills = data.skills }
	elseif tabId == "awaken" then
		fields = {
			level = Stats.levelForXp(data.golem.xp),
			awakening = data.awakening,
			ascension = data.ascension,
			bosses = data.bossesDefeated,
		}
	elseif tabId == "quests" then
		fields = { rewards = snap.rewards, sessionStart = snap.sessionStart }
	elseif tabId == "events" then
		fields = { tracks = data.eventTracks }
	elseif tabId == "party" then
		fields = { party = snap.party, inviteMode = data.social and data.social.partyInvites }
	elseif tabId == "hub" then
		fields = {
			hub = snap.hub,
			social = data.social,
			level = Stats.levelForXp(data.golem.xp),
			bosses = data.bossesDefeated,
			found = data.artifacts.found,
			awakening = data.awakening.count,
			daily = data.daily,
			tutorial = data.tutorial,
		}
	elseif tabId == "trade" then
		fields = { trade = snap.trade }
	elseif tabId == "wardrobe" then
		fields = {
			cosmetics = data.cosmetics,
			parts = data.golem.parts,
			level = Stats.levelForXp(data.golem.xp),
			bosses = data.bossesDefeated,
			found = data.artifacts.found,
			awakening = data.awakening.count,
			daily = data.daily,
			tutorial = data.tutorial,
		}
	elseif tabId == "shop" then
		fields = {
			passes = snap.passes,
			policy = snap.policy,
			boosts = data.boosts,
			artifacts = data.artifacts,
			skills = data.skills,
			awakening = data.awakening,
			ascension = data.ascension,
			zone = snap.golem and snap.golem.zoneId,
		}
	elseif tabId == "ranks" then
		fields = {
			boards = snap.leaderboards,
			level = Stats.levelForXp(data.golem.xp),
			awakening = data.awakening.count,
			found = data.artifacts.found,
		}
	else
		fields = snap
	end
	return HttpService:JSONEncode(fields)
end

function Menus.refresh(force: boolean?)
	refreshBadges()
	if not openTab or not State.snapshot then
		lastTabId = nil
		lastSignature = nil
		pendingRefresh = false
		return
	end
	if codeBox and codeBox.Parent and codeBox:IsFocused() then
		pendingRefresh = true
		return
	end
	local tab = TABS[openTab]
	local signatureOk, result = pcall(tabSignature, tab.id, State.snapshot)
	-- Still render if an unexpected value cannot be serialized.
	local signature: string? = if signatureOk then result else nil
	if not force and lastTabId == tab.id and signature ~= nil and signature == lastSignature then
		return
	end
	-- Touch, mouse and gamepad presses must finish before their buttons are
	-- destroyed. A pending refresh is performed after the release callback.
	if heldCount > 0 then
		pendingRefresh = true
		return
	end
	local now = os.clock()
	if not force and lastTabId == tab.id and now - lastRenderAt < MIN_REBUILD_INTERVAL then
		if not refreshScheduled then
			refreshScheduled = true
			task.delay(MIN_REBUILD_INTERVAL - (now - lastRenderAt), function()
				refreshScheduled = false
				Menus.refresh()
			end)
		end
		return
	end
	pendingRefresh = false
	codeBox = nil
	Wardrobe.detach()
	local scroll = list.CanvasPosition
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	if themed ~= tab.id then
		themed = tab.id
		window.setTheme(tab.name, Ui.Headers[tab.id] or Ui.Headers.menu, tab.id)
	end
	local ok, err = pcall(function(): any
		tab.render(list, State.snapshot)
		return nil
	end)
	if not ok then
		warn(`[Menus] {tab.name} failed to render: {err}`)
		lastSignature = nil
	else
		lastSignature = signature
	end
	lastTabId = tab.id
	lastRenderAt = now
	list.CanvasPosition = scroll
end

local function indexOf(id: string): number?
	for index, tab in TABS do
		if tab.id == id then
			return index
		end
	end
	return nil
end

local open: (index: number?) -> ()

local function showInspect(userId: number)
	inspectedId = userId
	local index = indexOf("hub")
	if openTab ~= index then
		open(index)
	else
		Menus.refresh(true)
	end
end

-- Opening a tab closes the last one; opening the same tab again closes it.
function open(index: number?)
	local changed = openTab ~= index
	openTab = if openTab == index then nil else index
	window.frame.Visible = openTab ~= nil
	if menuGrid then
		menuGrid.frame.Visible = false
	end
	if changed then
		list.CanvasPosition = Vector2.zero
	end
	if openTab and TABS[openTab].id == "shop" then
		Remotes.Track:FireServer("shopOpened") -- the Shop funnel in analytics
	end
	Menus.refresh(true)
end

-- Opens a tab by id (the HUD's goal card uses this).
function Menus.open(id: string)
	local index = indexOf(id)
	if index and openTab ~= index then
		open(index)
	end
end

local COMPACT_WIDTH = 900
local COMPACT_HEIGHT = 520

local function makeTabButton(parent: Instance, index: number, tab: { id: string, name: string }): TextButton
	local b = Ui.button(parent, "", UDim2.fromOffset(176, 56), UDim2.new(), true, function()
		open(index)
	end)
	b.Name = tab.id
	Ui.surface(b, "gem", { tint = Ui.Headers[tab.id] or Ui.Headers.menu })
	local icon = Icons.create(b, tab.id, 38, UDim2.new(0, 8, 0.5, 0))
	icon.AnchorPoint = Vector2.new(0, 0.5)
	local label = b:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = tab.name
		label.Position = UDim2.fromOffset(52, 2)
		label.Size = UDim2.new(1, -58, 1, -4)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextSize = 20
	end
	b.LayoutOrder = index
	tabButtons[tab.id] = b
	return b
end

function Menus.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GolemMenus"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Tab buttons down the left edge, under the stats panel.
	-- Scrolls, so every tab stays reachable on a short screen.
	local bar = Instance.new("ScrollingFrame")
	bar.Name = "Tabs"
	bar.BackgroundTransparency = 1
	bar.BorderSizePixel = 0
	bar.ScrollBarThickness = 0
	bar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	bar.CanvasSize = UDim2.new()
	bar.Size = UDim2.new(0, 196, 1, -196)
	bar.Position = UDim2.fromOffset(8, 186)
	bar.Parent = gui
	local barLayout = Ui.listLayout(bar, 8)
	barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local barPadding = Instance.new("UIPadding")
	barPadding.PaddingTop = UDim.new(0, 8)
	barPadding.PaddingBottom = UDim.new(0, 8)
	barPadding.Parent = bar
	for index, tab in TABS do
		makeTabButton(bar, index, tab)
	end

	window = Ui.window(gui, "", Ui.Headers.menu, nil, function()
		open(openTab)
	end)
	local frame = window.frame
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.52)
	frame.Size = UDim2.fromScale(0.56, 0.8)
	frame.Visible = false
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 280)
	constraint.MaxSize = Vector2.new(720, 680)
	constraint.Parent = frame
	list = Ui.scrollList(window.body)

	-- Small screens: one Menu button that opens every tab as a grid.
	menuButton = Ui.button(gui, "Menu", UDim2.fromOffset(132, 56), UDim2.fromOffset(12, 186), true, function()
		menuGrid.frame.Visible = not menuGrid.frame.Visible
		if menuGrid.frame.Visible and openTab then
			open(openTab)
			menuGrid.frame.Visible = true
		end
	end, "secondary")
	menuButton.Name = "MenuButton"
	menuButton.Visible = false
	menuGrid = Ui.window(gui, "Menu", Ui.Headers.menu, nil, function()
		menuGrid.frame.Visible = false
	end)
	menuGrid.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	menuGrid.frame.Position = UDim2.fromScale(0.5, 0.52)
	menuGrid.frame.Size = UDim2.fromScale(0.62, 0.86)
	menuGrid.frame.Visible = false
	local gridConstraint = Instance.new("UISizeConstraint")
	gridConstraint.MinSize = Vector2.new(320, 240)
	gridConstraint.MaxSize = Vector2.new(560, 600)
	gridConstraint.Parent = menuGrid.frame
	local gridList = Instance.new("ScrollingFrame")
	gridList.Name = "Grid"
	gridList.BackgroundTransparency = 1
	gridList.BorderSizePixel = 0
	gridList.ScrollBarThickness = 6
	gridList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridList.CanvasSize = UDim2.new()
	gridList.Size = UDim2.fromScale(1, 1)
	gridList.Parent = menuGrid.body
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(150, 56)
	gridLayout.CellPadding = UDim2.fromOffset(8, 8)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = gridList
	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 8)
	gridPadding.Parent = gridList

	local function applyLayout()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local small = size.X < COMPACT_WIDTH or size.Y < COMPACT_HEIGHT
		if small == compact and (bar:FindFirstChildWhichIsA("TextButton") ~= nil) ~= small then
			return
		end
		compact = small
		for _, b in tabButtons do
			b.Parent = if small then gridList else bar
		end
		bar.Visible = not small
		menuButton.Visible = small
		if not small then
			menuGrid.frame.Visible = false
		end
		-- On a phone the window leaves the thumb corners clear.
		frame.Size = if small then UDim2.fromScale(0.6, 0.9) else UDim2.fromScale(0.56, 0.8)
	end
	applyLayout()
	local function watchCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
		end
		applyLayout()
	end
	watchCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

	-- Keep a menu button alive from press through release. This covers touch
	-- taps (including long taps), mouse clicks and gamepad A activation.
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if
			openTab
			and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonA)
			and not heldInputs[input]
		then
			heldInputs[input] = true
			heldCount += 1
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if not heldInputs[input] then
			return
		end
		heldInputs[input] = nil
		heldCount -= 1
		if heldCount == 0 and pendingRefresh then
			-- Run after the button's Activated handler, not during InputEnded.
			task.defer(function()
				if heldCount == 0 and pendingRefresh then
					Menus.refresh(true)
				end
			end)
		end
	end)

	-- Escape, gamepad B and the X all close: a dialog first, then the menu.
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.ButtonB then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if Ui.closeTop() then
			return
		end
		if menuGrid.frame.Visible then
			menuGrid.frame.Visible = false
		elseif openTab then
			open(openTab)
			GuiService.SelectedObject = nil
		end
	end)

	State.Changed:Connect(function()
		Menus.refresh()
	end)
	-- Pressing Inspect on a golem in the hub opens its card.
	Remotes.Notify.OnClientEvent:Connect(function(kind: string, userId: number?)
		if kind == "inspect" and type(userId) == "number" then
			showInspect(userId)
		end
	end)
	-- Timers (session gifts, boosts) tick even without new state.
	task.spawn(function()
		while true do
			task.wait(1)
			if
				openTab
				and (
					TABS[openTab].id == "quests"
					or TABS[openTab].id == "shop"
					or TABS[openTab].id == "artifacts"
					or TABS[openTab].id == "trade"
					or TABS[openTab].id == "events"
				)
			then
				-- These tabs display live countdowns even without new snapshots.
				Menus.refresh(true)
			else
				refreshBadges()
			end
		end
	end)
end

return Menus
