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
			Move = function(self)
				assert(not self.failOnMove, "a fallen enemy must not move or attack")
			end,
			MoveTo = function(self)
				assert(not self.failOnMove, "a fallen enemy must not move or attack")
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
	[attacker] = { zoneId = 1, root = { Position = v(0, 54, 0) } },
	[other] = { zoneId = 1, root = { Position = v(0, 54, 0) } },
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
			isActive = function(golem)
				return golem.active ~= false
			end,
		},
		WorldService = {
			getFolder = function()
				return {}
			end,
			getSurfaceY = function()
				return 50
			end,
			getBossPoint = function()
				return v(0, 50, 0)
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
	{
		HumanoidRigType = {},
		HumanoidHealthDisplayType = {},
		HumanoidDisplayDistanceType = {},
		HumanoidStateType = {},
		HighlightDepthMode = { Occluded = "Occluded" },
	},
	function()
		return now
	end
)

local function spawn(boss, callback)
	local def = {
		displayName = "Test enemy",
		size = v(4, 6, 4),
		maxHealth = 100,
		walkSpeed = 10,
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
	enemy.humanoid.failOnMove = true
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

-- Both independent 25%+ contributors earn rewards; a shared party member
-- receives only one reward even if both contributors belong to that party.
local multi = spawn(false)
enemies.damage(multi, 60, attacker)
enemies.damage(multi, 40, other)
assert(paid[attacker] == 2 and paid[other] == 1 and paid[friend] == 2)

-- A stranger finishing a nearly defeated enemy gets no reward.
local stolen = spawn(false)
enemies.damage(stolen, 90, attacker)
enemies.damage(stolen, 10, other)
assert(paid[attacker] == 3 and paid[other] == 1)

local untouched = spawn(false)
fall(untouched)
assert(paid[attacker] == 3 and paid[other] == 1)
local departed = spawn(false)
enemies.damage(departed, 1, other)
other.Parent = nil
fall(departed)
assert(paid[other] == 1)
other.Parent = true

-- Only active contributors still on the boss island get unlocks or rolls.
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

local beforeAway = paid[attacker]
local bossAway = spawn(true)
enemies.damage(bossAway, 1, attacker)
golems[attacker].zoneId = 0
fall(bossAway)
assert(paid[attacker] == beforeAway)
golems[attacker].zoneId = 1

local bossDown = spawn(true)
enemies.damage(bossDown, 1, attacker)
golems[attacker].active = false
fall(bossDown)
assert(paid[attacker] == beforeAway)
golems[attacker].active = true

local bossTogether = spawn(true)
enemies.damage(bossTogether, 1, attacker)
enemies.damage(bossTogether, 1, other)
fall(bossTogether)
assert(paid[attacker] == beforeAway + 1 and paid[other] == 2)

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
-- A perfect Quake creates a server-owned, one-time opening. An active red
-- telegraph is removed, the boss cannot attack during the stagger, and the
-- next slam is delayed. Repeated attempts cannot keep a boss stun-locked.
local staggerBoss = spawn(true)
staggerBoss.slamAt = now + 1
local warning = {
	Destroy = function(self)
		self.destroyed = true
	end,
}
staggerBoss.slamMarker = warning
assert(enemies.stagger(staggerBoss, attacker))
assert(staggerBoss.model:GetAttribute("Staggered") == true and staggerBoss.humanoid.WalkSpeed == 0)
assert(staggerBoss.slamAt == 0 and warning.destroyed)
assert(staggerBoss.nextAttack == now + Config.BossStagger.duration)
assert(staggerBoss.nextSlam >= now + Config.BossStagger.duration + Config.BossStagger.recovery)
assert(not enemies.stagger(staggerBoss, attacker), "cannot reapply while staggered")
now += Config.BossStagger.duration - 0.01
enemies.update()
assert(staggerBoss.model:GetAttribute("Staggered") == true)
now += 0.01
enemies.update()
assert(staggerBoss.model:GetAttribute("Staggered") == false and staggerBoss.humanoid.WalkSpeed == 10)
assert(staggerBoss.staggerGlow == nil)
assert(not enemies.stagger(staggerBoss, attacker), "per-boss cooldown persists after recovery")
now = 100 + Config.BossStagger.cooldown
assert(enemies.stagger(staggerBoss, attacker), "cooldown is inclusive at its boundary")
assert(not enemies.stagger(spawn(false), attacker), "regular enemies cannot be staggered")
assert(not enemies.stagger(spawn(true, function() end), attacker), "Tower bosses cannot be staggered")
local wrongZoneBoss = spawn(true)
golems[attacker].zoneId = 2
assert(not enemies.stagger(wrongZoneBoss, attacker))
golems[attacker].zoneId = 1
golems[attacker].active = false
assert(not enemies.stagger(wrongZoneBoss, attacker))
golems[attacker].active = true
assert(enemies.stagger(wrongZoneBoss, attacker))
fall(wrongZoneBoss)
assert(not enemies.stagger(wrongZoneBoss, attacker), "defeated bosses cannot be staggered")
print("EnemyService fair credit, party sharing, boss presence, Tower and stagger checks passed")
