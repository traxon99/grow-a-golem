local vector = {}
vector.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	end
	return vector[key]
end
local function v(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vector)
end
vector.__add = function(a, b)
	return v(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vector.__sub = function(a, b)
	return v(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
local Vector3 = { new = v, zero = v(0, 0, 0) }
local Instance = {
	new = function(class)
		local attributes = {}
		return {
			ClassName = class,
			SetAttribute = function(_, key, value)
				attributes[key] = value
			end,
			GetAttribute = function(_, key)
				return attributes[key]
			end,
			SetStateEnabled = function() end,
			SetNetworkOwner = function() end,
			Destroy = function(self)
				self.destroyed = true
				self.Parent = nil
			end,
			Move = function()
				error("a fallen enemy must not move or attack")
			end,
			MoveTo = function()
				error("a fallen enemy must not move or attack")
			end,
		}
	end,
}
local shared = {
	WaitForChild = function(self)
		return self
	end,
}
local game = {
	GetService = function()
		return shared
	end,
}
local attacker = { UserId = 1, Parent = true }
local other = { UserId = 2, Parent = true }
local friend = { UserId = 3, Parent = true }
local farFriend = { UserId = 4, Parent = true }
local wrongZone = { UserId = 5, Parent = true }
local golems = {
	[friend] = { zoneId = 1, root = { Position = v(5, 54, 0) } },
	[farFriend] = { zoneId = 1, root = { Position = v(100, 54, 0) } },
	[wrongZone] = { zoneId = 2, root = { Position = v(5, 54, 0) } },
}
local paid = {}
local rolls = {}
local events = {}
local totals = {}
local reenter = nil
local now = 100
Config.Party = { shareRange = 20 }
local enemies = loadEnemyService(
	{
		Config = Config,
		MarbleBag = MarbleBag,
		Remotes = { Notify = { FireClient = function() end } },
		EnemyModels = { dress = function() end },
		GolemService = {
			all = function()
				return {}
			end,
			get = function(player)
				return golems[player]
			end,
		},
		WorldService = {
			getFolder = function()
				return {}
			end,
			getSurfaceY = function()
				return 50
			end,
		},
		PartyService = {
			shareWith = function(player, nearby)
				local recipients = { player }
				for _, member in { friend, farFriend, wrongZone } do
					if nearby(member) then
						table.insert(recipients, member)
					end
				end
				return recipients
			end,
		},
		EconomyService = {
			grant = function(player, reward)
				paid[player] = (paid[player] or 0) + 1
				assert(reward.xp == 10 and reward.minerals.stone == 3)
				if reenter then
					reenter()
				end
				return reward
			end,
		},
		DataService = {
			update = function(player, callback)
				local data = totals[player] or { bossesDefeated = {}, totals = { enemies = 0, bosses = 0 } }
				totals[player] = data
				callback(data)
			end,
		},
		ArtifactService = {
			roll = function(_, _, source)
				table.insert(rolls, source)
			end,
		},
		Events = {
			fire = function(kind)
				events[kind] = (events[kind] or 0) + 1
			end,
		},
	},
	game,
	Instance,
	Vector3,
	{
		new = function(at)
			return at
		end,
	},
	{ HumanoidRigType = {}, HumanoidHealthDisplayType = {}, HumanoidDisplayDistanceType = {}, HumanoidStateType = {} },
	function()
		return now
	end
)

local function spawn(boss, callback)
	local def = {
		displayName = "Test enemy",
		size = v(4, 6, 4),
		maxHealth = 100,
		xp = 10,
		drops = { stone = 3 },
		respawn = 30,
	}
	local enemy = enemies.spawnInArena(1, "test", def, v(0, 50, 0), boss, 1, callback or function() end)
	-- Fixture can exercise ordinary island reward paths without spawn loops.
	enemy.onDefeated = callback
	enemy.root.Position = v(0, 53.5, 0)
	return enemy
end
local function fall(enemy)
	enemy.root.Position = v(0, -100, 0)
	enemies.update()
	assert(enemy.model.destroyed)
end

local enemy = spawn(false)
enemies.damage(enemy, 1, attacker)
assert(paid[attacker] == nil)
-- A second server update during reward dispatch must not pay the same enemy.
reenter = function()
	enemies.update()
	enemies.damage(enemy, 1000, attacker)
end
fall(enemy)
reenter = nil
assert(paid[attacker] == 1 and paid[friend] == 1)
assert(paid[farFriend] == nil and paid[wrongZone] == nil)
assert(totals[attacker].totals.enemies == 1 and #rolls == 2 and events.enemyDefeated == 2)
enemies.update()
assert(paid[attacker] == 1)

local multi = spawn(false)
enemies.damage(multi, 1, attacker)
enemies.damage(multi, 1, other)
fall(multi)
assert(paid[attacker] == 1 and paid[other] == 1) -- last hitter wins

local untouched = spawn(false)
fall(untouched)
assert(paid[attacker] == 1 and paid[other] == 1)
local departed = spawn(false)
enemies.damage(departed, 1, other)
other.Parent = nil
fall(departed)
assert(paid[other] == 1)
other.Parent = true

local boss = spawn(true)
enemies.damage(boss, 1, attacker)
enemies.damage(boss, 1, other)
other.Parent = nil
fall(boss)
assert(totals[attacker].bossesDefeated["1"] and totals[attacker].totals.bosses == 1)
assert(rolls[#rolls] == "boss" and paid[other] == 1)
local alive, delay = enemies.bossStatus(1)
assert(not alive and delay == 30)
other.Parent = true

local callbacks = 0
local before = paid[attacker]
local tower = spawn(false, function()
	callbacks += 1
end)
enemies.damage(tower, 1, attacker)
fall(tower)
enemies.update()
enemies.damage(tower, 200, attacker)
assert(callbacks == 1 and paid[attacker] == before)

local normal = spawn(false)
enemies.damage(normal, 100, attacker)
assert(normal.model.destroyed and paid[attacker] == before + 1)
print("EnemyService void credit, party sharing, boss and Tower checks passed")
