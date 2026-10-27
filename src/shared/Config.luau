--!strict
-- All balance numbers and content live here so tuning never means touching
-- game logic. Names are placeholders we can rename freely.

-- Typed as a map of anything: tables here have entries of different shapes
-- (quests, rewards, tutorial steps) and gain keys after they're defined (the
-- #15 expansion below), which strict mode would otherwise reject.
local Config: { [string]: any } = {}

Config.TickRate = 10 -- server game-logic updates per second

---------------------------------------------------------------- minerals

Config.MineralOrder = { "stone", "copper", "iron", "crystal" }

Config.Minerals = {
	stone = { displayName = "Stone", color = Color3.fromRGB(150, 150, 150) },
	copper = { displayName = "Copper", color = Color3.fromRGB(201, 118, 64) },
	iron = { displayName = "Iron", color = Color3.fromRGB(176, 184, 196) },
	crystal = { displayName = "Crystal", color = Color3.fromRGB(150, 110, 255) },
}

---------------------------------------------------------------- golem

Config.Golem = {
	maxHealth = 200,
	regenPerSecond = 2,
	walkSpeed = 14,
	attackDamage = 12,
	attackCooldown = 1.0,
	attackRange = 10, -- studs between golem root and enemy root (grows with size)
	aggroRange = 35, -- golem auto-targets enemies inside this range
	miningDamage = 10,
	miningCooldown = 0.8,
	miningRange = 10,
	seekRange = 150, -- when idle, golem walks to nodes this far away
	respawnTime = 5,
	maxLevel = 100,
	baseArtifactSlots = 3,
}

-- Total XP needed to reach a level: 25 * (level - 1) ^ 1.6
Config.LevelCurve = { base = 25, exponent = 1.6 }

-- Golem size steps up at these levels. Size gates zones and scales the model.
Config.SizeLevels = { 1, 5, 10, 18, 28, 40, 55, 75, 100 }
Config.SizeScaleStep = 0.25 -- each size step makes the model 25% bigger

-- Part tiers, weakest first. `power` scales every stat a part gives.
Config.TierOrder = { "stone", "copper", "iron", "crystal" }
Config.Tiers = {
	stone = {
		displayName = "Stone",
		power = 1,
		color = Color3.fromRGB(128, 122, 110),
		material = Enum.Material.Slate,
		cost = { stone = 20 },
	},
	copper = {
		displayName = "Copper",
		power = 2,
		color = Color3.fromRGB(184, 108, 60),
		material = Enum.Material.CorrodedMetal,
		cost = { copper = 25, stone = 40 },
	},
	iron = {
		displayName = "Iron",
		power = 3.5,
		color = Color3.fromRGB(150, 156, 166),
		material = Enum.Material.DiamondPlate,
		cost = { iron = 30, copper = 40 },
	},
	crystal = {
		displayName = "Crystal",
		power = 5.5,
		color = Color3.fromRGB(150, 110, 255),
		material = Enum.Material.Glass,
		cost = { crystal = 30, iron = 50 },
	},
}

Config.SlotOrder = { "core", "torso", "armL", "armR", "legs" }
Config.Slots = {
	core = { displayName = "Core", costMultiplier = 1.5 },
	torso = { displayName = "Torso", costMultiplier = 1.2 },
	armL = { displayName = "Left Arm", costMultiplier = 1 },
	armR = { displayName = "Right Arm", costMultiplier = 1 },
	legs = { displayName = "Legs", costMultiplier = 1 },
}
Config.FullSetBonus = 0.15 -- all five slots the same tier: +15% health and damage

---------------------------------------------------------------- spells

Config.SpellOrder = { "quake", "mend", "magnet" }
Config.Spells = {
	quake = { displayName = "Quake", key = Enum.KeyCode.Q, cooldown = 8, damage = 40, radius = 20 },
	mend = { displayName = "Mend", key = Enum.KeyCode.E, cooldown = 20, healFraction = 0.35 },
	magnet = { displayName = "Magnet", key = Enum.KeyCode.R, cooldown = 30, duration = 10, mineralBonus = 1.0 },
}

---------------------------------------------------------------- enemies

Config.Enemies = {
	pebbleCritter = {
		displayName = "Pebble Critter",
		maxHealth = 30,
		damage = 4,
		attackCooldown = 1.2,
		attackRange = 8,
		aggroRange = 40,
		walkSpeed = 10,
		size = Vector3.new(3, 3, 3),
		color = Color3.fromRGB(120, 112, 98),
		xp = 5,
		drops = { stone = 2 },
	},
	cinderImp = {
		displayName = "Cinder Imp",
		maxHealth = 90,
		damage = 10,
		attackCooldown = 1.1,
		attackRange = 8,
		aggroRange = 45,
		walkSpeed = 12,
		size = Vector3.new(3, 4, 3),
		color = Color3.fromRGB(200, 80, 40),
		xp = 12,
		drops = { copper = 2, iron = 1 },
	},
	shardSprite = {
		displayName = "Shard Sprite",
		maxHealth = 220,
		damage = 22,
		attackCooldown = 1.0,
		attackRange = 9,
		aggroRange = 50,
		walkSpeed = 13,
		size = Vector3.new(3, 5, 3),
		color = Color3.fromRGB(170, 140, 255),
		xp = 28,
		drops = { iron = 2, crystal = 1 },
	},
}

-- One boss per zone. It slams the ground: a red circle appears, then hits
-- every golem still inside it. Steer out of the circle to dodge.
Config.Bosses = {
	[1] = {
		displayName = "Old Rockjaw",
		maxHealth = 900,
		damage = 15,
		attackCooldown = 1.5,
		attackRange = 12,
		aggroRange = 60,
		walkSpeed = 8,
		size = Vector3.new(10, 10, 10),
		color = Color3.fromRGB(96, 90, 80),
		xp = 150,
		drops = { stone = 150, copper = 40 },
		slam = { every = 6, warning = 1.5, radius = 14, damage = 60 },
		respawn = 60,
	},
	[2] = {
		displayName = "Slag Matron",
		maxHealth = 4000,
		damage = 30,
		attackCooldown = 1.4,
		attackRange = 13,
		aggroRange = 60,
		walkSpeed = 9,
		size = Vector3.new(11, 12, 11),
		color = Color3.fromRGB(150, 50, 30),
		xp = 500,
		drops = { copper = 150, iron = 60 },
		slam = { every = 5, warning = 1.3, radius = 16, damage = 140 },
		respawn = 75,
	},
	[3] = {
		displayName = "The Prism Stag",
		maxHealth = 12000,
		damage = 55,
		attackCooldown = 1.2,
		attackRange = 14,
		aggroRange = 65,
		walkSpeed = 11,
		size = Vector3.new(9, 14, 14),
		color = Color3.fromRGB(190, 170, 255),
		xp = 1400,
		drops = { iron = 150, crystal = 60 },
		slam = { every = 4.5, warning = 1.2, radius = 18, damage = 260 },
		respawn = 90,
	},
}

-- Share of max health a boss heals each second while nobody is near it.
Config.BossRegenPerSecond = 0.03

Config.Nodes = {
	stone = { maxHealth = 30, yield = 5, size = Vector3.new(5, 4, 5), material = Enum.Material.Slate },
	copper = { maxHealth = 50, yield = 3, size = Vector3.new(4, 5, 4), material = Enum.Material.CorrodedMetal },
	iron = { maxHealth = 120, yield = 3, size = Vector3.new(5, 5, 5), material = Enum.Material.DiamondPlate },
	crystal = { maxHealth = 300, yield = 3, size = Vector3.new(3, 7, 3), material = Enum.Material.Glass },
}

---------------------------------------------------------------- zones

-- `gate` lists what a player needs before they can travel here.
Config.ZoneOrder = { 1, 2, 3 }
Config.Zones = {
	[1] = {
		name = "Mossy Quarry",
		center = Vector3.new(0, 60, 0), -- top surface of the floating island
		size = Vector3.new(320, 6, 320),
		color = Color3.fromRGB(92, 132, 72),
		material = Enum.Material.Grass,
		theme = "meadow", -- scenery style for the placeholder island
		gate = {},
		maxEnemies = 12,
		extraEnemiesPerPlayer = 4,
		spawnInterval = 3,
		minSpawnDistance = 40,
		enemies = { "pebbleCritter" },
		nodeCount = 16,
		nodeRespawn = 20,
		nodes = { { mineral = "stone", weight = 3 }, { mineral = "copper", weight = 1 } },
		offlineMinerals = { stone = 4, copper = 1 }, -- per minute, before multipliers
	},
	[2] = {
		name = "Ember Flats",
		center = Vector3.new(500, 60, 0),
		size = Vector3.new(320, 6, 320),
		color = Color3.fromRGB(110, 70, 55),
		material = Enum.Material.Basalt,
		theme = "ember",
		gate = { boss = 1 },
		maxEnemies = 12,
		extraEnemiesPerPlayer = 4,
		spawnInterval = 3,
		minSpawnDistance = 40,
		enemies = { "cinderImp" },
		nodeCount = 16,
		nodeRespawn = 25,
		nodes = { { mineral = "copper", weight = 2 }, { mineral = "iron", weight = 2 } },
		offlineMinerals = { copper = 3, iron = 2 },
	},
	[3] = {
		name = "Glasswood",
		center = Vector3.new(1000, 60, 0),
		size = Vector3.new(320, 6, 320),
		color = Color3.fromRGB(70, 110, 120),
		material = Enum.Material.Glacier,
		theme = "crystal",
		gate = { boss = 2, size = 3 },
		maxEnemies = 12,
		extraEnemiesPerPlayer = 4,
		spawnInterval = 3,
		minSpawnDistance = 40,
		enemies = { "shardSprite" },
		nodeCount = 16,
		nodeRespawn = 30,
		nodes = { { mineral = "iron", weight = 2 }, { mineral = "crystal", weight = 2 } },
		offlineMinerals = { iron = 3, crystal = 2 },
	},
}

---------------------------------------------------------------- artifacts

-- Stat keys used by artifacts, skills, and upgrades (all are % bonuses):
-- health, damage, attackSpeed, mining, minerals, speed, luck, spellPower,
-- spellHaste, regen, xp
-- source: "drop" (rare from zone enemies), "boss" (zone boss), "hidden" (relic on the map)
Config.ArtifactOrder = {
	"pebbleCharm",
	"quarryLantern",
	"oldChisel",
	"rootboundRing",
	"rockjawTooth",
	"mossHeart",
	"emberCoal",
	"slagGauntlet",
	"cinderBell",
	"bellowsRune",
	"matronCrown",
	"ashenMap",
	"prismShard",
	"glassLeaf",
	"mirrorSeed",
	"refractedLens",
	"stagAntler",
	"hollowBulb",
}
Config.Artifacts = {
	pebbleCharm = { name = "Pebble Charm", zone = 1, source = "drop", bonus = { health = 5 } },
	quarryLantern = { name = "Quarry Lantern", zone = 1, source = "drop", bonus = { minerals = 5 } },
	oldChisel = { name = "Old Chisel", zone = 1, source = "drop", bonus = { mining = 8 } },
	rootboundRing = { name = "Rootbound Ring", zone = 1, source = "drop", bonus = { regen = 25 } },
	rockjawTooth = { name = "Rockjaw's Tooth", zone = 1, source = "boss", bonus = { damage = 8 } },
	mossHeart = { name = "Moss Heart", zone = 1, source = "hidden", bonus = { speed = 6 } },

	emberCoal = { name = "Ember Coal", zone = 2, source = "drop", bonus = { damage = 6 } },
	slagGauntlet = { name = "Slag Gauntlet", zone = 2, source = "drop", bonus = { health = 8 } },
	cinderBell = { name = "Cinder Bell", zone = 2, source = "drop", bonus = { attackSpeed = 6 } },
	bellowsRune = { name = "Bellows Rune", zone = 2, source = "drop", bonus = { minerals = 8 } },
	matronCrown = { name = "Matron's Crown", zone = 2, source = "boss", bonus = { health = 12 } },
	ashenMap = { name = "Ashen Map", zone = 2, source = "hidden", bonus = { luck = 10 } },

	prismShard = { name = "Prism Shard", zone = 3, source = "drop", bonus = { spellPower = 15 } },
	glassLeaf = { name = "Glass Leaf", zone = 3, source = "drop", bonus = { speed = 8 } },
	mirrorSeed = { name = "Mirror Seed", zone = 3, source = "drop", bonus = { luck = 12 } },
	refractedLens = { name = "Refracted Lens", zone = 3, source = "drop", bonus = { mining = 12 } },
	stagAntler = { name = "Stag Antler", zone = 3, source = "boss", bonus = { damage = 12 } },
	hollowBulb = { name = "Hollow Bulb", zone = 3, source = "hidden", bonus = { minerals = 12 } },
}
Config.ArtifactDropChance = 0.006 -- per enemy defeated, before luck
Config.ArtifactBossChance = 0.3 -- per boss defeat, before luck
-- Bad-luck protection: after this many rolls in a row without a find in a
-- zone, the next roll always succeeds. The Artifacts menu shows the real odds
-- and the count, so random finds stay honest (Roblox requires disclosed odds
-- for anything random that money can affect, like the luck boost).
Config.ArtifactPity = { drop = 300, boss = 4 }
Config.ZoneSetBonus = { health = 5, damage = 5 } -- for finding every artifact in a zone
Config.HiddenRelic = { respawn = 180, pickupRange = 10, consolationMinerals = 50 }

---------------------------------------------------------------- skill tree

Config.SkillBranches = {
	{ id = "earthshaper", displayName = "Earthshaper", nodes = { "e1", "e2", "e3", "e4", "e5" } },
	{ id = "prospector", displayName = "Prospector", nodes = { "p1", "p2", "p3", "p4", "p5" } },
	{ id = "runebinder", displayName = "Runebinder", nodes = { "r1", "r2", "r3", "r4", "r5" } },
}
Config.Skills = {
	e1 = { name = "Heavy Fists", cost = 1, bonus = { damage = 5 } },
	e2 = { name = "Bedrock Hide", cost = 1, bonus = { health = 10 } },
	e3 = { name = "Boulder Swing", cost = 1, bonus = { damage = 10 } },
	e4 = { name = "Quick Strikes", cost = 1, bonus = { attackSpeed = 10 } },
	e5 = { name = "Titan Blows", cost = 2, bonus = { damage = 15, health = 10 } },
	p1 = { name = "Sharp Chisel", cost = 1, bonus = { mining = 10 } },
	p2 = { name = "Keen Eye", cost = 1, bonus = { minerals = 10 } },
	p3 = { name = "Long Stride", cost = 1, bonus = { speed = 5 } },
	p4 = { name = "Rich Veins", cost = 1, bonus = { minerals = 15 } },
	p5 = { name = "Night Shift", cost = 2, bonus = { minerals = 10 }, offlineHours = 1 },
	r1 = { name = "Quick Runes", cost = 1, bonus = { spellHaste = 10 } },
	r2 = { name = "Deep Runes", cost = 1, bonus = { spellPower = 20 } },
	r3 = { name = "Lucky Star", cost = 1, bonus = { luck = 10 } },
	r4 = { name = "Relic Keeper", cost = 1, bonus = {}, artifactSlots = 1 },
	r5 = { name = "Runestorm", cost = 2, bonus = { spellPower = 30, spellHaste = 10 } },
}
Config.SkillRespecCost = { stone = 200 }

---------------------------------------------------------------- awakening

Config.Awakening = {
	minLevel = 20,
	shardsPerLevelAbove = 1, -- shards = level - 15
	shardBaseLevel = 15,
	mineralBonusPerAwakening = 10, -- % minerals for each Awakening, forever
}
Config.AwakenUpgradeOrder = { "might", "prospector", "longRest", "relicSlot" }
Config.AwakenUpgrades = {
	might = {
		name = "Ancient Might",
		description = "+5% health and damage",
		maxRank = 20,
		baseCost = 3,
		costStep = 2,
		bonus = { health = 5, damage = 5 },
	},
	prospector = {
		name = "Prospector's Blessing",
		description = "+5% minerals",
		maxRank = 20,
		baseCost = 3,
		costStep = 2,
		bonus = { minerals = 5 },
	},
	longRest = {
		name = "Long Rest",
		description = "+1 hour offline mining cap",
		maxRank = 10,
		baseCost = 4,
		costStep = 3,
		offlineHours = 1,
	},
	relicSlot = {
		name = "Relic Slot",
		description = "+1 artifact slot",
		maxRank = 2,
		baseCost = 15,
		costStep = 15,
		artifactSlots = 1,
	},
}

---------------------------------------------------------------- party

Config.Party = {
	maxSize = 4,
	shareRange = 80, -- party members this close share kill rewards
	friendBonusPerFriend = 10, -- % minerals per friend in your party
	maxFriendBonus = 30,
	inviteTimeout = 60,
}

---------------------------------------------------------------- hub and trading

-- The hub is a small safe island (no enemies, no nodes) where every golem in
-- the server idles on show. Its zone id is 0 so it never clashes with the
-- numbered islands in Config.Zones. Travel menu entry: "Golem Hub".
Config.HubZone = 0
Config.Hub = {
	name = "Golem Hub",
	center = Vector3.new(-500, 60, 0), -- top surface of the floating island
	size = Vector3.new(180, 6, 180),
	color = Color3.fromRGB(150, 140, 120),
	material = Enum.Material.Cobblestone,
	theme = "meadow",
	spread = 45, -- golems arrive this many studs from the middle at most
	maxInspect = 24, -- inspect cards sent per player
	inspectRange = 14, -- studs (at golem size 1) to see the Inspect prompt
	refreshSeconds = 5, -- how often cards refresh for players standing in the hub
}

-- Titles are shown on the nametag. Each is earned by playing (same unlock
-- kinds as cosmetics: boss, awaken, zoneSet, level) and is never for sale.
Config.TitleOrder = {
	"rockjawSlayer",
	"matronBreaker",
	"stagHunter",
	"collectorQuarry",
	"collectorEmber",
	"collectorGlasswood",
	"awakened",
	"veteran",
}
Config.Titles = {
	rockjawSlayer = { name = "Rockjaw Slayer", unlock = { kind = "boss", zone = 1 } },
	matronBreaker = { name = "Matron Breaker", unlock = { kind = "boss", zone = 2 } },
	stagHunter = { name = "Stag Hunter", unlock = { kind = "boss", zone = 3 } },
	collectorQuarry = { name = "Collector: Mossy Quarry", unlock = { kind = "zoneSet", zone = 1 } },
	collectorEmber = { name = "Collector: Ember Flats", unlock = { kind = "zoneSet", zone = 2 } },
	collectorGlasswood = { name = "Collector: Glasswood", unlock = { kind = "zoneSet", zone = 3 } },
	awakened = { name = "Awakened", unlock = { kind = "awaken", count = 1 } },
	veteran = { name = "Veteran", unlock = { kind = "level", level = 30 } },
}

-- Artifacts found from a boss or a hidden relic are announced to the server
-- (players can turn announcements off in the Hub tab). Enemy drops are not.
Config.AnnounceSources = { boss = true, hidden = true }

-- Trading moves spare artifact copies only. A spare is a second copy of an
-- artifact you already found: once you have every artifact from a source on
-- an island, the same odds and bad-luck protection give spares instead. Spares
-- found while 2x Luck (bought with Robux) is on are bound to you and can never
-- be traded, so nothing bought with Robux changes hands. No minerals, no
-- cosmetics, no text: there is nothing to type, so nothing to filter or scam.
Config.Trading = {
	maxItems = 6, -- distinct artifacts per side
	countdownSeconds = 5, -- both players must wait this long before Confirm
	requestTimeout = 60,
	requestCooldown = 3, -- seconds between a player's trade requests
	idleTimeout = 300, -- an open trade closes after this long
	dailyLimit = 10, -- completed trades per player per UTC day
	minAccountAgeDays = 7, -- fresh accounts can't trade (alt and scam protection)
	saveAttempts = 3, -- tries to write each player's save at each step of a trade
	journalStore = "TradeJournal_v1", -- DataStore holding one commit/abort decision per trade (see TradeJournal)
	settleRetrySeconds = 60, -- wait before retrying a trade whose decision couldn't be read
	sweepSeconds = 5, -- how often idle trades are checked
	logKept = 30, -- trade records kept per player, keyed by UserId
	-- Value points per artifact source, only used for the "this is lopsided"
	-- warning. The warning shows when you give more than this many times what
	-- you get, and the Confirm button then says "Confirm anyway".
	value = { drop = 1, boss = 3, hidden = 5 },
	lopsidedRatio = 1.5,
}

---------------------------------------------------------------- retention

Config.Offline = { baseCapHours = 2, minSeconds = 60 }

-- 7-day login track. Missing a single day keeps your streak.
Config.DailyRewards = {
	{ minerals = { stone = 100 } },
	{ minerals = { stone = 200, copper = 40 } },
	{ minerals = { copper = 100 } },
	{ xp = 300 },
	{ minerals = { copper = 150, iron = 40 } },
	{ minerals = { iron = 100 } },
	{ minerals = { iron = 150, crystal = 40 }, xp = 1000 },
}

-- Session gifts unlock after this many minutes in one session.
Config.SessionRewards = {
	{ minutes = 5, minerals = { stone = 60 } },
	{ minutes = 15, minerals = { copper = 40 } },
	{ minutes = 30, minerals = { iron = 30 }, xp = 200 },
	{ minutes = 60, minerals = { crystal = 25 }, xp = 500 },
}

-- `event` names match what the server fires; `target` is how many to do.
Config.QuestPool = {
	{
		id = "defeat50",
		text = "Defeat 50 enemies",
		event = "enemyDefeated",
		target = 50,
		reward = { xp = 200, minerals = { stone = 100 } },
	},
	{
		id = "defeat150",
		text = "Defeat 150 enemies",
		event = "enemyDefeated",
		target = 150,
		reward = { xp = 500, minerals = { copper = 80 } },
	},
	{
		id = "mine20",
		text = "Break 20 mineral nodes",
		event = "nodeMined",
		target = 20,
		reward = { minerals = { stone = 150, copper = 30 } },
	},
	{
		id = "mine60",
		text = "Break 60 mineral nodes",
		event = "nodeMined",
		target = 60,
		reward = { minerals = { copper = 100, iron = 30 } },
	},
	{ id = "spells30", text = "Cast 30 spells", event = "spellCast", target = 30, reward = { xp = 300 } },
	{
		id = "boss1",
		text = "Defeat a zone boss",
		event = "bossDefeated",
		target = 1,
		reward = { xp = 400, minerals = { iron = 20 } },
	},
	{
		id = "craft2",
		text = "Forge 2 golem parts",
		event = "partCrafted",
		target = 2,
		reward = { minerals = { copper = 60 } },
	},
}
Config.WeeklyQuestPool = {
	{
		id = "w_defeat1000",
		text = "Defeat 1,000 enemies",
		event = "enemyDefeated",
		target = 1000,
		reward = { xp = 3000, minerals = { iron = 150 } },
	},
	{
		id = "w_mine300",
		text = "Break 300 mineral nodes",
		event = "nodeMined",
		target = 300,
		reward = { minerals = { iron = 120, crystal = 40 } },
	},
	{
		id = "w_boss10",
		text = "Defeat 10 zone bosses",
		event = "bossDefeated",
		target = 10,
		reward = { xp = 4000, minerals = { crystal = 60 } },
	},
}
Config.DailyQuestCount = 3

-- Set to your Roblox group id to give a one-time reward for joining. 0 = off.
Config.Group = { id = 0, reward = { minerals = { stone = 300, copper = 60 } } }

-- Redeemable codes. Post them with updates and on the group wall. Players type
-- them in the Shop; each works once per player. Keys must be UPPERCASE (what
-- players type is upper-cased first). `expires` is a UTC unix time, or nil
-- for never. Tip: https://www.unixtimestamp.com turns a date into one.
Config.Codes = {
	GOLEM100 = { reward = { minerals = { stone = 100 } } },
	ROCKSOLID = { reward = { minerals = { stone = 200, copper = 50 }, xp = 150 } },
}
-- Limited-time events. Each one switches on and off by itself using server
-- time (UTC), so scheduling one needs no republish once it's in this list.
-- Give an event either a one-off window:
--   startsAt = <UTC unix time>, endsAt = <UTC unix time>
-- or a weekly window that repeats forever:
--   weekly = { day = 6, hour = 0, hours = 48 } -- day 1 = Monday ... 7 = Sunday
-- `modifiers` multiply minerals, xp and luck (luck also shows in the odds).
-- `track` is an optional reward track paid in a currency earned only by
-- playing during the event. Unfinished progress carries over to the next
-- run, and once a track is finished it starts fresh at the next run.
Config.Events = {
	{
		id = "doubleMinerals",
		name = "Double Minerals Weekend",
		description = "2x minerals all weekend long!",
		weekly = { day = 6, hour = 0, hours = 48 },
		modifiers = { minerals = 2 },
		track = {
			currency = "Weekend Tokens",
			earn = { enemyDefeated = 1, nodeMined = 1, bossDefeated = 15 },
			tiers = {
				{ tokens = 40, reward = { minerals = { stone = 300 } } },
				{ tokens = 120, reward = { minerals = { copper = 150 }, xp = 400 } },
				{ tokens = 250, reward = { minerals = { iron = 120 } } },
				{ tokens = 450, reward = { minerals = { iron = 150, crystal = 50 }, xp = 1500 } },
			},
		},
	},
}

Config.CodeLimits = {
	cooldown = 2, -- seconds between attempts
	maxFailures = 5, -- wrong codes in a row before a short lockout
	lockoutSeconds = 60,
	maxLength = 24,
}

---------------------------------------------------------------- shop

-- Create these in the Creator Dashboard (Monetization) and paste the ids.
-- An id of 0 shows the item as "Coming soon".
Config.GamePassOrder = { "doubleMinerals", "autoForge", "extraSlot", "longRest", "vip" }
Config.GamePasses = {
	doubleMinerals = { id = 0, name = "2x Minerals", description = "Double all mineral income, forever.", price = 299 },
	autoForge = {
		id = 0,
		name = "Auto-Forge",
		description = "Automatically forges and equips the best part you can afford.",
		price = 149,
	},
	extraSlot = { id = 0, name = "Extra Artifact Slot", description = "+1 artifact slot.", price = 199 },
	longRest = { id = 0, name = "Long Rest", description = "Offline mining cap becomes 12 hours.", price = 249 },
	vip = { id = 0, name = "VIP", description = "VIP nametag, +10% XP.", price = 399 },
}
Config.LongRestCapHours = 12
Config.VipXpBonus = 10

Config.ProductOrder = { "mineralsSmall", "mineralsMedium", "mineralsLarge", "boostXp", "boostLuck" }
Config.Products = {
	-- Mineral packs scale with the best zone you've unlocked.
	mineralsSmall = { id = 0, name = "Small Mineral Pack", price = 49, packMinutes = 30 },
	mineralsMedium = { id = 0, name = "Mineral Crate", price = 149, packMinutes = 120 },
	mineralsLarge = { id = 0, name = "Mineral Vault", price = 449, packMinutes = 480 },
	boostXp = { id = 0, name = "2x XP (30 min)", price = 39, boost = "xp", minutes = 30 },
	-- 2x Luck changes random artifact odds, so Roblox counts it as a paid
	-- random item: it's hidden for players whose PolicyService says those are
	-- restricted. If one of them is charged anyway (an old prompt, a tampered
	-- client), they get the same time of `restrictedAlternative` instead.
	boostLuck = {
		id = 0,
		name = "2x Luck (30 min)",
		price = 39,
		boost = "luck",
		minutes = 30,
		paidRandom = true,
		restrictedAlternative = "xp",
	},
}
-- PolicyService lookups are retried this many times, this many seconds apart.
-- If every try fails we fail closed: paid random items stay hidden.
Config.PolicyCheck = { attempts = 3, retrySeconds = 5 }

---------------------------------------------------------------- cosmetics

-- Cosmetics only change how things look. Stats never reads them, so they're
-- fair in co-op. Each one is either earned (`unlock`) or bought directly
-- (`passId` + `price`): you preview the exact item, then buy that item. No
-- eggs, crates, spins or random rolls, ever.
--
-- To sell one: create a game pass for it in the Creator Dashboard, set its
-- price to `price`, and paste the id into `passId`. 0 shows "Coming soon".
-- Unlock kinds: boss (zone), awaken (count), zoneSet (zone), level, streak
-- (daily login days in a row), tutorial. Shapes for pets and outfits, and
-- how skins blend with forged tiers, live in src/shared/CosmeticLooks.luau.
Config.CosmeticSlots = {
	{ id = "skin", name = "Golem skins" },
	{ id = "outfit", name = "Wizard outfits" },
	{ id = "pet", name = "Pets" },
	{ id = "trail", name = "Trails" },
}
Config.CosmeticOrder = {
	"mossy",
	"lava",
	"frost",
	"gilded",
	"apprentice",
	"emberMage",
	"starlight",
	"pebblePup",
	"emberSprite",
	"crystalOwl",
	"dustTrail",
	"runeTrail",
}
Config.Cosmetics = {
	-- Skins tint every part toward `color` by `tint` (0 to 1), so the forged
	-- tier still shows through, and swap the material and glowing runes.
	mossy = {
		slot = "skin",
		name = "Mossy",
		description = "Moss grows over every part.",
		unlock = { kind = "boss", zone = 1 },
		skin = {
			color = Color3.fromRGB(86, 140, 70),
			material = Enum.Material.Grass,
			tint = 0.6,
			accent = Color3.fromRGB(190, 255, 120),
		},
	},
	lava = {
		slot = "skin",
		name = "Lava",
		description = "Cooled rock with molten glowing runes.",
		unlock = { kind = "boss", zone = 2 },
		skin = {
			color = Color3.fromRGB(58, 42, 38),
			material = Enum.Material.Basalt,
			tint = 0.75,
			accent = Color3.fromRGB(255, 120, 30),
		},
	},
	frost = {
		slot = "skin",
		name = "Frost",
		description = "Ice-blue armor with a cold glow.",
		passId = 0,
		price = 99,
		skin = {
			color = Color3.fromRGB(170, 215, 255),
			material = Enum.Material.Ice,
			tint = 0.7,
			accent = Color3.fromRGB(210, 250, 255),
		},
	},
	gilded = {
		slot = "skin",
		name = "Gilded",
		description = "Shining gold, for golems that have Awakened.",
		unlock = { kind = "awaken", count = 1 },
		skin = {
			color = Color3.fromRGB(232, 182, 60),
			material = Enum.Material.Foil,
			tint = 0.8,
			accent = Color3.fromRGB(255, 246, 200),
		},
	},

	apprentice = {
		slot = "outfit",
		name = "Apprentice",
		description = "A pointy blue hat, a cape and an oak staff.",
		unlock = { kind = "tutorial" },
	},
	emberMage = {
		slot = "outfit",
		name = "Ember Mage",
		description = "Fire-red robes and a staff with a burning coal.",
		unlock = { kind = "zoneSet", zone = 2 },
	},
	starlight = {
		slot = "outfit",
		name = "Starlight Wizard",
		description = "A starry hat and cape with a glowing crystal staff.",
		passId = 0,
		price = 79,
	},

	-- Pets float beside the golem and hop when it defeats an enemy.
	pebblePup = {
		slot = "pet",
		name = "Pebble Pup",
		description = "A loyal little rock dog.",
		unlock = { kind = "level", level = 10 },
	},
	emberSprite = {
		slot = "pet",
		name = "Ember Sprite",
		description = "A tiny flame with flapping wings.",
		passId = 0,
		price = 99,
	},
	crystalOwl = {
		slot = "pet",
		name = "Crystal Owl",
		description = "A wise owl made of glowing crystal.",
		passId = 0,
		price = 149,
	},

	-- Trails stream behind the golem's feet.
	dustTrail = {
		slot = "trail",
		name = "Dust Trail",
		description = "A cloud of quarry dust behind every step.",
		unlock = { kind = "streak", days = 7 },
		trail = { colors = { Color3.fromRGB(200, 186, 160), Color3.fromRGB(150, 140, 120) }, lifetime = 0.9, glow = 0 },
	},
	runeTrail = {
		slot = "trail",
		name = "Rune Trail",
		description = "Glowing blue rune light behind every step.",
		passId = 0,
		price = 59,
		trail = { colors = { Color3.fromRGB(90, 200, 255), Color3.fromRGB(150, 110, 255) }, lifetime = 0.7, glow = 1 },
	},
}

---------------------------------------------------------------- visuals

Config.Visuals = {
	-- Set to false once you tune Lighting by hand in Studio, so the game
	-- stops overwriting your settings.
	controlLighting = true,
	-- Recolors the Baseplate template's floor into a sea of clouds far below
	-- the islands. Only touches a part named "Baseplate".
	cloudSeaBaseplate = true,
	-- Adds trees, rocks and a rocky underside to placeholder islands.
	decorateIslands = true,
	-- Color grading tint on each island, by zone theme (needs controlLighting).
	zoneTints = {
		meadow = Color3.fromRGB(255, 252, 240),
		ember = Color3.fromRGB(255, 232, 214),
		crystal = Color3.fromRGB(232, 242, 255),
		storm = Color3.fromRGB(222, 230, 255),
		ruins = Color3.fromRGB(226, 255, 246),
		forge = Color3.fromRGB(255, 226, 196),
	},
	-- Sky haze per zone theme, blended in when you arrive (needs controlLighting).
	-- meadow matches the default haze set by WorldService.
	zoneAtmosphere = {
		meadow = { color = Color3.fromRGB(200, 222, 255), decay = Color3.fromRGB(120, 140, 190), density = 0.28 },
		ember = { color = Color3.fromRGB(255, 214, 190), decay = Color3.fromRGB(150, 100, 90), density = 0.3 },
		crystal = { color = Color3.fromRGB(214, 232, 255), decay = Color3.fromRGB(130, 150, 210), density = 0.28 },
		storm = { color = Color3.fromRGB(170, 184, 214), decay = Color3.fromRGB(70, 80, 120), density = 0.38 },
		ruins = { color = Color3.fromRGB(190, 236, 228), decay = Color3.fromRGB(80, 150, 150), density = 0.34 },
		forge = { color = Color3.fromRGB(255, 200, 150), decay = Color3.fromRGB(140, 80, 60), density = 0.34 },
	},
}

-- Tiling textures for UI surfaces (see docs/reference/ui-materials.md).
-- Upload each PNG in assets/ui-textures/ as a Decal or Image in Studio and
-- paste its image id here. 0 = no image: the panel still gets its material's
-- color, grain gradient, edge and details, all drawn in code.
Config.UiTextures = { wood = 0, stone = 0, metal = 0, studs = 0, crystal = 0 }

-- Sound ids for the big moments (artifact reveal, level up, growing a size).
-- 0 = silent. Paste rbxassetid numbers from the Creator Store.
Config.Sounds = { artifact = 0, levelUp = 0, grow = 0 }

-- Everyday sound effects. Each `id` is either a sound that ships inside every
-- Roblox client ("rbxasset://sounds/..."), which always works, or an asset id
-- number from the Creator Store. `speed` changes pitch and length, so a few
-- built-in sounds cover many effects. When a moment above is 0, the effect
-- with the same name here plays instead.
local THUD = "rbxasset://sounds/action_jump_land.mp3"
local WIND = "rbxasset://sounds/action_falling.ogg"
local SPLASH = "rbxasset://sounds/impact_water.mp3"
local WHOOSH = "rbxasset://sounds/action_jump.mp3"
Config.SoundEffects = {
	golemStep = { id = THUD, speed = 0.5, volume = 0.35, bass = true },
	bossStep = { id = THUD, speed = 0.4, volume = 0.5, bass = true },
	punch = { id = THUD, speed = 0.85, volume = 0.5, distortion = 0.35 },
	mine = { id = THUD, speed = 1.7, volume = 0.4, distortion = 0.2 },
	mineBreak = { id = THUD, speed = 1.2, volume = 0.6, distortion = 0.5 },
	enemyAttack = { id = WHOOSH, speed = 1.3, volume = 0.3 },
	defeat = { id = WHOOSH, speed = 0.8, volume = 0.45 },
	quake = { id = THUD, speed = 0.32, volume = 1, distortion = 0.6, reverb = true },
	mend = { id = SPLASH, speed = 1.8, volume = 0.5, reverb = true },
	magnet = { id = WIND, speed = 1.6, volume = 0.5, length = 1.2 },
	slamWarn = { id = WIND, speed = 0.6, volume = 0.6, length = 1.5 },
	slam = { id = THUD, speed = 0.25, volume = 1, distortion = 0.7, reverb = true },
	downed = { id = "rbxasset://sounds/uuhhh.mp3", speed = 0.55, volume = 0.6, reverb = true },
	artifact = { id = SPLASH, speed = 2.4, volume = 0.7, reverb = true },
	levelUp = { id = SPLASH, speed = 2, volume = 0.7, reverb = true },
	grow = { id = THUD, speed = 0.45, volume = 0.9, reverb = true },
	click = { id = THUD, speed = 2.6, volume = 0.25 },
	tutorialStep = { id = SPLASH, speed = 2.8, volume = 0.5 },
	wind = { id = WIND, speed = 0.45, volume = 0.07, loop = true },
}

---------------------------------------------------------------- tutorial

-- The first-time tutorial. One action per step; the server advances it from
-- real game events (see TutorialService) and the client points at the target.
-- `pointer` is what the client points at: "node" (nearest stone node), "forge"
-- (the Forge tab), "spell" (a spell button), or nil. `reward` is granted
-- flat when the step completes. `touchText` / `gamepadText` replace `text` on
-- those devices.
Config.Tutorial = {
	steerSeconds = 2, -- seconds of steering that finish the first step
	steps = {
		{
			id = "steer",
			text = "Your golem fights on its own. Steer it with WASD or the stick!",
			touchText = "Your golem fights on its own. Steer it with the stick!",
		},
		{ id = "mine", text = "Walk to the glowing rock. Your golem mines it!", pointer = "node" },
		{ id = "forge", text = "Open Forge and build your first part!", pointer = "forge", topUpStone = true },
		{
			id = "quake",
			text = "Press Q to smash enemies with Quake!",
			touchText = "Tap Quake to smash enemies!",
			gamepadText = "Press X to smash enemies with Quake!",
			pointer = "spell",
			spell = "quake",
			reward = { xp = 20 },
		},
		{ id = "level", text = "Defeat enemies to reach level 2!" },
	},
	doneText = "You're ready! Follow the Next goal at the top to grow your golem.",
}

---------------------------------------------------------------- analytics

-- Gameplay events go to the Creator Dashboard (see AnalyticsService and the
-- README). Set debug to true to print analytics errors in the Output window.
Config.Analytics = { debug = false }

---------------------------------------------------------------- data

Config.Data = {
	storeName = "PlayerData_v1",
	autosaveInterval = 60,
	sessionLeaseSeconds = 180,
	pushInterval = 0.25, -- at most this often, state is sent to the client
}

Config.Leaderboards = {
	refreshSeconds = 120,
	size = 10,
	boards = {
		{ id = "level", displayName = "Highest level", store = "LB_Level_v1" },
		{ id = "awakenings", displayName = "Most Awakenings", store = "LB_Awakenings_v1" },
		{ id = "artifacts", displayName = "Artifacts found", store = "LB_Artifacts_v1" },
	},
}

---------------------------------------------------------------- expansion (#15)
-- Provisional balance: see docs/playtest.md before treating pacing as measured.
Config.Elites = { everySpawns = 20, health = 2, damage = 1.4, rewards = 3, scale = 1.25 }
table.insert(Config.MineralOrder, "stormglass")
Config.Minerals.stormglass = { displayName = "Stormglass", color = Color3.fromRGB(100, 190, 255) }
table.insert(Config.TierOrder, "stormglass")
Config.Tiers.stormglass = {
	displayName = "Stormglass",
	power = 8,
	color = Color3.fromRGB(100, 190, 255),
	material = Enum.Material.Metal,
	cost = { stormglass = 80, crystal = 120 },
}
Config.Nodes.stormglass = { maxHealth = 720, yield = 3, size = Vector3.new(5, 6, 5), material = Enum.Material.Neon }
table.insert(Config.MineralOrder, "abyssite")
Config.Minerals.abyssite = { displayName = "Abyssite", color = Color3.fromRGB(55, 175, 160) }
table.insert(Config.TierOrder, "abyssite")
Config.Tiers.abyssite = {
	displayName = "Abyssite",
	power = 11,
	color = Color3.fromRGB(55, 175, 160),
	material = Enum.Material.Metal,
	cost = { abyssite = 110, stormglass = 165 },
}
Config.Nodes.abyssite = { maxHealth = 990, yield = 3, size = Vector3.new(5, 6, 5), material = Enum.Material.Neon }
table.insert(Config.MineralOrder, "sunsteel")
Config.Minerals.sunsteel = { displayName = "Sunsteel", color = Color3.fromRGB(255, 190, 70) }
table.insert(Config.TierOrder, "sunsteel")
Config.Tiers.sunsteel = {
	displayName = "Sunsteel",
	power = 15,
	color = Color3.fromRGB(255, 190, 70),
	material = Enum.Material.Metal,
	cost = { sunsteel = 150, abyssite = 225 },
}
Config.Nodes.sunsteel = { maxHealth = 1350, yield = 3, size = Vector3.new(5, 6, 5), material = Enum.Material.Neon }
table.insert(Config.MineralOrder, "aether")
Config.Minerals.aether = { displayName = "Aether", color = Color3.fromRGB(230, 170, 255) }
table.insert(Config.TierOrder, "aether")
Config.Tiers.aether = {
	displayName = "Aether",
	power = 20,
	color = Color3.fromRGB(230, 170, 255),
	material = Enum.Material.Metal,
	cost = { aether = 200, sunsteel = 300 },
}
Config.Nodes.aether = { maxHealth = 1800, yield = 3, size = Vector3.new(5, 6, 5), material = Enum.Material.Neon }
table.insert(Config.ZoneOrder, 4)
Config.Zones[4] = {
	name = "Storm Peak",
	center = Vector3.new(1500, 60, 0),
	size = Vector3.new(320, 6, 320),
	color = Color3.fromRGB(100, 190, 255),
	material = Enum.Material.Slate,
	theme = "storm",
	gate = { boss = 3, size = 4 },
	maxEnemies = 12,
	extraEnemiesPerPlayer = 4,
	spawnInterval = 3,
	minSpawnDistance = 40,
	enemies = { "stormWisp", "stormWispTank" },
	nodeCount = 16,
	nodeRespawn = 30,
	nodes = { { mineral = "crystal", weight = 1 }, { mineral = "stormglass", weight = 3 } },
	offlineMinerals = { crystal = 2, stormglass = 3 },
}
Config.Enemies.stormWisp = {
	displayName = "Storm Peak Swarmer",
	designId = "shardSprite",
	maxHealth = 500,
	damage = 36,
	attackCooldown = 0.8,
	attackRange = 9,
	aggroRange = 50,
	walkSpeed = 16,
	size = Vector3.new(3, 5, 3),
	color = Color3.fromRGB(100, 190, 255),
	xp = 50,
	drops = { stormglass = 2 },
	spawnWeight = 3,
}
Config.Bosses[4] = {
	displayName = "Thunder Roc",
	designId = "boss1",
	maxHealth = 22500,
	damage = 80,
	attackCooldown = 1.4,
	attackRange = 14,
	aggroRange = 65,
	walkSpeed = 10,
	size = Vector3.new(12, 14, 12),
	color = Color3.fromRGB(100, 190, 255),
	xp = 1750,
	drops = { stormglass = 100 },
	slam = { every = 5, warning = 1.5, radius = 18, damage = 340 },
	respawn = 90,
}
table.insert(Config.ArtifactOrder, "stormglassCharm")
Config.Artifacts.stormglassCharm = { name = "Storm Peak Charm", zone = 4, source = "drop", bonus = { health = 12 } }
table.insert(Config.ArtifactOrder, "stormglassLens")
Config.Artifacts.stormglassLens = { name = "Storm Peak Lens", zone = 4, source = "drop", bonus = { mining = 12 } }
table.insert(Config.ArtifactOrder, "stormglassRune")
Config.Artifacts.stormglassRune = { name = "Storm Peak Rune", zone = 4, source = "drop", bonus = { spellPower = 12 } }
table.insert(Config.ArtifactOrder, "stormglassBell")
Config.Artifacts.stormglassBell = { name = "Storm Peak Bell", zone = 4, source = "drop", bonus = { minerals = 12 } }
table.insert(Config.ArtifactOrder, "stormglassCrown")
Config.Artifacts.stormglassCrown = { name = "Storm Peak Crown", zone = 4, source = "boss", bonus = { damage = 12 } }
table.insert(Config.ArtifactOrder, "stormglassHeart")
Config.Artifacts.stormglassHeart = { name = "Storm Peak Heart", zone = 4, source = "hidden", bonus = { regen = 12 } }
table.insert(Config.ZoneOrder, 5)
Config.Zones[5] = {
	name = "Sunken Ruins",
	center = Vector3.new(2000, 60, 0),
	size = Vector3.new(320, 6, 320),
	color = Color3.fromRGB(55, 175, 160),
	material = Enum.Material.Slate,
	theme = "ruins",
	gate = { boss = 4, size = 5 },
	maxEnemies = 12,
	extraEnemiesPerPlayer = 4,
	spawnInterval = 3,
	minSpawnDistance = 40,
	enemies = { "ruinCrawler", "ruinCrawlerTank" },
	nodeCount = 16,
	nodeRespawn = 30,
	nodes = { { mineral = "stormglass", weight = 1 }, { mineral = "abyssite", weight = 3 } },
	offlineMinerals = { stormglass = 2, abyssite = 3 },
}
Config.Enemies.ruinCrawler = {
	displayName = "Sunken Ruins Swarmer",
	designId = "shardSprite",
	maxHealth = 950,
	damage = 45,
	attackCooldown = 0.8,
	attackRange = 9,
	aggroRange = 50,
	walkSpeed = 16,
	size = Vector3.new(3, 5, 3),
	color = Color3.fromRGB(55, 175, 160),
	xp = 90,
	drops = { abyssite = 2 },
	spawnWeight = 3,
}
Config.Bosses[5] = {
	displayName = "Tide Sentinel",
	designId = "boss2",
	maxHealth = 42750,
	damage = 100,
	attackCooldown = 1.4,
	attackRange = 14,
	aggroRange = 65,
	walkSpeed = 10,
	size = Vector3.new(12, 14, 12),
	color = Color3.fromRGB(55, 175, 160),
	xp = 3150,
	drops = { abyssite = 100 },
	slam = { every = 5, warning = 1.5, radius = 18, damage = 425 },
	respawn = 90,
}
table.insert(Config.ArtifactOrder, "abyssiteCharm")
Config.Artifacts.abyssiteCharm = { name = "Sunken Ruins Charm", zone = 5, source = "drop", bonus = { health = 15 } }
table.insert(Config.ArtifactOrder, "abyssiteLens")
Config.Artifacts.abyssiteLens = { name = "Sunken Ruins Lens", zone = 5, source = "drop", bonus = { mining = 15 } }
table.insert(Config.ArtifactOrder, "abyssiteRune")
Config.Artifacts.abyssiteRune = { name = "Sunken Ruins Rune", zone = 5, source = "drop", bonus = { spellPower = 15 } }
table.insert(Config.ArtifactOrder, "abyssiteBell")
Config.Artifacts.abyssiteBell = { name = "Sunken Ruins Bell", zone = 5, source = "drop", bonus = { minerals = 15 } }
table.insert(Config.ArtifactOrder, "abyssiteCrown")
Config.Artifacts.abyssiteCrown = { name = "Sunken Ruins Crown", zone = 5, source = "boss", bonus = { damage = 15 } }
table.insert(Config.ArtifactOrder, "abyssiteHeart")
Config.Artifacts.abyssiteHeart = { name = "Sunken Ruins Heart", zone = 5, source = "hidden", bonus = { regen = 15 } }
table.insert(Config.ZoneOrder, 6)
Config.Zones[6] = {
	name = "Sky Forge",
	center = Vector3.new(2500, 60, 0),
	size = Vector3.new(320, 6, 320),
	color = Color3.fromRGB(255, 190, 70),
	material = Enum.Material.Slate,
	theme = "forge",
	gate = { boss = 5, size = 6 },
	maxEnemies = 12,
	extraEnemiesPerPlayer = 4,
	spawnInterval = 3,
	minSpawnDistance = 40,
	enemies = { "forgeSpark", "forgeSparkTank" },
	nodeCount = 16,
	nodeRespawn = 30,
	nodes = {
		{ mineral = "abyssite", weight = 1 },
		{ mineral = "sunsteel", weight = 3 },
		{ mineral = "aether", weight = 1 },
	},
	offlineMinerals = { abyssite = 2, sunsteel = 3, aether = 1 },
}
Config.Enemies.forgeSpark = {
	displayName = "Sky Forge Swarmer",
	designId = "shardSprite",
	maxHealth = 1700,
	damage = 54,
	attackCooldown = 0.8,
	attackRange = 9,
	aggroRange = 50,
	walkSpeed = 16,
	size = Vector3.new(3, 5, 3),
	color = Color3.fromRGB(255, 190, 70),
	xp = 150,
	drops = { sunsteel = 2 },
	spawnWeight = 3,
}
Config.Bosses[6] = {
	displayName = "Solar Colossus",
	designId = "boss3",
	maxHealth = 76500,
	damage = 120,
	attackCooldown = 1.4,
	attackRange = 14,
	aggroRange = 65,
	walkSpeed = 10,
	size = Vector3.new(12, 14, 12),
	color = Color3.fromRGB(255, 190, 70),
	xp = 5250,
	drops = { sunsteel = 100 },
	slam = { every = 5, warning = 1.5, radius = 18, damage = 510 },
	respawn = 90,
}
table.insert(Config.ArtifactOrder, "sunsteelCharm")
Config.Artifacts.sunsteelCharm = { name = "Sky Forge Charm", zone = 6, source = "drop", bonus = { health = 18 } }
table.insert(Config.ArtifactOrder, "sunsteelLens")
Config.Artifacts.sunsteelLens = { name = "Sky Forge Lens", zone = 6, source = "drop", bonus = { mining = 18 } }
table.insert(Config.ArtifactOrder, "sunsteelRune")
Config.Artifacts.sunsteelRune = { name = "Sky Forge Rune", zone = 6, source = "drop", bonus = { spellPower = 18 } }
table.insert(Config.ArtifactOrder, "sunsteelBell")
Config.Artifacts.sunsteelBell = { name = "Sky Forge Bell", zone = 6, source = "drop", bonus = { minerals = 18 } }
table.insert(Config.ArtifactOrder, "sunsteelCrown")
Config.Artifacts.sunsteelCrown = { name = "Sky Forge Crown", zone = 6, source = "boss", bonus = { damage = 18 } }
table.insert(Config.ArtifactOrder, "sunsteelHeart")
Config.Artifacts.sunsteelHeart = { name = "Sky Forge Heart", zone = 6, source = "hidden", bonus = { regen = 18 } }
Config.Enemies.pebbleCritterTank = table.clone(Config.Enemies.pebbleCritter)
Config.Enemies.pebbleCritterTank.displayName = Config.Enemies.pebbleCritter.displayName .. " Guardian"
Config.Enemies.pebbleCritterTank.designId = Config.Enemies.pebbleCritter.designId or "pebbleCritter"
Config.Enemies.pebbleCritterTank.maxHealth *= 2
Config.Enemies.pebbleCritterTank.walkSpeed *= 0.6
Config.Enemies.pebbleCritterTank.xp *= 2
Config.Enemies.pebbleCritterTank.drops = table.clone(Config.Enemies.pebbleCritter.drops)
for mineral, amount in Config.Enemies.pebbleCritterTank.drops do
	Config.Enemies.pebbleCritterTank.drops[mineral] = amount * 2
end
Config.Enemies.pebbleCritterTank.spawnWeight = 1
Config.Enemies.cinderImpTank = table.clone(Config.Enemies.cinderImp)
Config.Enemies.cinderImpTank.displayName = Config.Enemies.cinderImp.displayName .. " Guardian"
Config.Enemies.cinderImpTank.designId = Config.Enemies.cinderImp.designId or "cinderImp"
Config.Enemies.cinderImpTank.maxHealth *= 2
Config.Enemies.cinderImpTank.walkSpeed *= 0.6
Config.Enemies.cinderImpTank.xp *= 2
Config.Enemies.cinderImpTank.drops = table.clone(Config.Enemies.cinderImp.drops)
for mineral, amount in Config.Enemies.cinderImpTank.drops do
	Config.Enemies.cinderImpTank.drops[mineral] = amount * 2
end
Config.Enemies.cinderImpTank.spawnWeight = 1
Config.Enemies.shardSpriteTank = table.clone(Config.Enemies.shardSprite)
Config.Enemies.shardSpriteTank.displayName = Config.Enemies.shardSprite.displayName .. " Guardian"
Config.Enemies.shardSpriteTank.designId = Config.Enemies.shardSprite.designId or "shardSprite"
Config.Enemies.shardSpriteTank.maxHealth *= 2
Config.Enemies.shardSpriteTank.walkSpeed *= 0.6
Config.Enemies.shardSpriteTank.xp *= 2
Config.Enemies.shardSpriteTank.drops = table.clone(Config.Enemies.shardSprite.drops)
for mineral, amount in Config.Enemies.shardSpriteTank.drops do
	Config.Enemies.shardSpriteTank.drops[mineral] = amount * 2
end
Config.Enemies.shardSpriteTank.spawnWeight = 1
Config.Enemies.stormWispTank = table.clone(Config.Enemies.stormWisp)
Config.Enemies.stormWispTank.displayName = Config.Enemies.stormWisp.displayName .. " Guardian"
Config.Enemies.stormWispTank.designId = Config.Enemies.stormWisp.designId or "stormWisp"
Config.Enemies.stormWispTank.maxHealth *= 2
Config.Enemies.stormWispTank.walkSpeed *= 0.6
Config.Enemies.stormWispTank.xp *= 2
Config.Enemies.stormWispTank.drops = table.clone(Config.Enemies.stormWisp.drops)
for mineral, amount in Config.Enemies.stormWispTank.drops do
	Config.Enemies.stormWispTank.drops[mineral] = amount * 2
end
Config.Enemies.stormWispTank.spawnWeight = 1
Config.Enemies.ruinCrawlerTank = table.clone(Config.Enemies.ruinCrawler)
Config.Enemies.ruinCrawlerTank.displayName = Config.Enemies.ruinCrawler.displayName .. " Guardian"
Config.Enemies.ruinCrawlerTank.designId = Config.Enemies.ruinCrawler.designId or "ruinCrawler"
Config.Enemies.ruinCrawlerTank.maxHealth *= 2
Config.Enemies.ruinCrawlerTank.walkSpeed *= 0.6
Config.Enemies.ruinCrawlerTank.xp *= 2
Config.Enemies.ruinCrawlerTank.drops = table.clone(Config.Enemies.ruinCrawler.drops)
for mineral, amount in Config.Enemies.ruinCrawlerTank.drops do
	Config.Enemies.ruinCrawlerTank.drops[mineral] = amount * 2
end
Config.Enemies.ruinCrawlerTank.spawnWeight = 1
Config.Enemies.forgeSparkTank = table.clone(Config.Enemies.forgeSpark)
Config.Enemies.forgeSparkTank.displayName = Config.Enemies.forgeSpark.displayName .. " Guardian"
Config.Enemies.forgeSparkTank.designId = Config.Enemies.forgeSpark.designId or "forgeSpark"
Config.Enemies.forgeSparkTank.maxHealth *= 2
Config.Enemies.forgeSparkTank.walkSpeed *= 0.6
Config.Enemies.forgeSparkTank.xp *= 2
Config.Enemies.forgeSparkTank.drops = table.clone(Config.Enemies.forgeSpark.drops)
for mineral, amount in Config.Enemies.forgeSparkTank.drops do
	Config.Enemies.forgeSparkTank.drops[mineral] = amount * 2
end
Config.Enemies.forgeSparkTank.spawnWeight = 1
table.insert(Config.Zones[1].enemies, "pebbleCritterTank")
Config.Enemies.pebbleCritter.spawnWeight = 3
table.insert(Config.Zones[2].enemies, "cinderImpTank")
Config.Enemies.cinderImp.spawnWeight = 3
table.insert(Config.Zones[3].enemies, "shardSpriteTank")
Config.Enemies.shardSprite.spawnWeight = 3

-- Later branch nodes reward the extended level curve without a new currency.
for _, branch in Config.SkillBranches do
	local prefix = string.sub(branch.nodes[1], 1, 1)
	for index = 6, 8 do
		table.insert(branch.nodes, prefix .. index)
	end
end
Config.Skills.e6 = { name = "Mountain Guard", cost = 2, bonus = { health = 15 } }
Config.Skills.e7 = { name = "Storm Fists", cost = 2, bonus = { damage = 15 } }
Config.Skills.e8 = { name = "Sky Titan", cost = 3, bonus = { health = 15, damage = 15 } }
Config.Skills.p6 = { name = "Deep Veins", cost = 2, bonus = { mining = 15 } }
Config.Skills.p7 = { name = "Sky Surveyor", cost = 2, bonus = { minerals = 15 } }
Config.Skills.p8 = { name = "Master Prospector", cost = 3, bonus = { mining = 15, minerals = 15 } }
Config.Skills.r6 = { name = "Storm Runes", cost = 2, bonus = { spellPower = 20 } }
Config.Skills.r7 = { name = "Rune Rhythm", cost = 2, bonus = { spellHaste = 10 } }
Config.Skills.r8 = { name = "Sky Channel", cost = 3, bonus = { spellPower = 20, regen = 20 } }

Config.Ascension = { requiredAwakenings = 5, requiredBoss = 6, points = 1 }
Config.AscendUpgradeOrder = { "vigor", "insight", "harvest" }
Config.AscendUpgrades = {
	vigor = { name = "Titan Vigor", maxRank = 10, cost = 1, bonus = { health = 10, damage = 10 } },
	insight = { name = "Ancient Insight", maxRank = 10, cost = 1, bonus = { xp = 10 } },
	harvest = { name = "Sky Harvest", maxRank = 10, cost = 1, bonus = { minerals = 10, mining = 10 } },
}

---------------------------------------------------------------- co-op tower (#62)
-- A private ten-wave challenge for a party or a solo player, started from the
-- Travel menu (design: docs/expansion-design.md). Each run gets its own arena.
-- Arena zone ids are TowerZoneBase + 1 to TowerZoneBase + arenas, so they never
-- clash with Config.Zones (1 to 6) or the hub (0). Enemies in the tower drop
-- nothing; each cleared wave pays a fixed reward, shown before entry
-- (Stats.towerWaveReward). Provisional balance, like the rest of #15.
Config.TowerZoneBase = 100
Config.Tower = {
	-- Off until the three-client Studio tests in docs/playtest.md pass.
	enabled = false,
	name = "Golem Tower",
	waves = 10,
	arenas = 4, -- runs at once per server
	arenaOrigin = Vector3.new(0, 60, 1200), -- top surface of the first arena
	arenaSpacing = 400, -- arenas sit side by side along X
	arenaSize = Vector3.new(200, 6, 200),
	arenaColor = Color3.fromRGB(110, 104, 128),
	arenaMaterial = Enum.Material.Slate,
	inviteSeconds = 45, -- party members have this long to accept
	waveBreakSeconds = 4, -- pause between a cleared wave and the next
	returnSeconds = 6, -- after a run ends, golems go back to the route's island
	tickSeconds = 0.5,
	-- Enemies per wave: first + perWave * (wave - 1), then * (1 + perExtraPlayer)
	-- for each player after the first. How many may be alive at once is the
	-- route island's normal cap (maxEnemies + extraEnemiesPerPlayer per player).
	enemies = { first = 6, perWave = 2, perExtraPlayer = 0.5 },
	healthPerWave = 0.1, -- +10% enemy health per wave after the first
	-- Boss waves and how much of the island boss's health it has.
	bossWaves = { [5] = 0.6, [10] = 1 },
	-- Each wave pays every member this many times what its enemies (and boss)
	-- would drop on the island, with no multipliers, so it matches the menu.
	rewardRate = 1.25,
}

return Config
