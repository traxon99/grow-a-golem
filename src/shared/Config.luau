--!strict
-- All balance numbers live here so tuning never means touching game logic.

local Config = {}

Config.TickRate = 10 -- server game-logic updates per second

Config.MineralOrder = { "stone", "copper" }

Config.Minerals = {
	stone = { displayName = "Stone", color = Color3.fromRGB(150, 150, 150) },
	copper = { displayName = "Copper", color = Color3.fromRGB(201, 118, 64) },
}

Config.Golem = {
	maxHealth = 200,
	regenPerSecond = 2,
	walkSpeed = 14,
	attackDamage = 12,
	attackCooldown = 1.0,
	attackRange = 10, -- studs between golem root and enemy root
	aggroRange = 35, -- golem auto-targets enemies inside this range
	miningDamage = 10,
	miningCooldown = 0.8,
	miningRange = 10,
	seekRange = 150, -- when idle, golem walks to nodes this far away
	respawnTime = 5,
}

Config.Spells = {
	quake = { displayName = "Quake", cooldown = 8, damage = 40, radius = 20 },
}

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
}

Config.Nodes = {
	stone = { maxHealth = 30, yield = 5, size = Vector3.new(5, 4, 5), material = Enum.Material.Slate },
	copper = { maxHealth = 50, yield = 3, size = Vector3.new(4, 5, 4), material = Enum.Material.CorrodedMetal },
}

Config.Zones = {
	[1] = {
		name = "Mossy Quarry",
		center = Vector3.new(0, 60, 0), -- top surface of the floating island
		size = Vector3.new(320, 6, 320),
		color = Color3.fromRGB(92, 132, 72),
		maxEnemies = 12,
		spawnInterval = 3,
		minSpawnDistance = 40, -- enemies never spawn on top of a golem
		enemies = { "pebbleCritter" },
		nodeCount = 16,
		nodeRespawn = 20,
		nodes = { { mineral = "stone", weight = 3 }, { mineral = "copper", weight = 1 } },
	},
}

Config.Data = {
	storeName = "PlayerData_v1",
	autosaveInterval = 60,
}

return Config
