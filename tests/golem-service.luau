-- Executes the real GolemService, including damage, travel and recovery.
local vector = {}
local function vec(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vector)
end
vector.__index = function(v, key)
	local length = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	if key == "Magnitude" then
		return length
	elseif key == "Unit" then
		return vec(v.X / length, v.Y / length, v.Z / length)
	end
	return nil
end
vector.__add = function(a, b)
	return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vector.__sub = function(a, b)
	return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
vector.__unm = function(a)
	return vec(-a.X, -a.Y, -a.Z)
end
vector.__mul = function(a, b)
	if type(b) == "number" then
		return vec(a.X * b, a.Y * b, a.Z * b)
	elseif type(a) == "number" then
		return vec(b.X * a, b.Y * a, b.Z * a)
	end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
local Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x, Y = y, Z = z }, vector)
	end,
}
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.zero.Magnitude = 0 -- the engine's Vector3 has it; the steering checks read it
local shared = {
	WaitForChild = function(self)
		return self
	end,
	GetPlayers = function()
		return {}
	end,
}
local game = {
	GetService = function()
		return shared
	end,
}
local now = 100
local messages = 0
local puffs = 0
local service = loadGolemService(
	{
		Config = Config,
		CosmeticLooks = {},
		Remotes = {
			Notify = {
				FireClient = function()
					messages += 1
				end,
				FireAllClients = function(_, kind)
					if kind == "golemPuff" then
						puffs += 1
					end
				end,
			},
		},
		Stats = {},
		WorldService = {
			getSurfaceY = function()
				return 50
			end,
			getSpawnPoint = function()
				return Vector3.new(0, 50, 0)
			end,
			getFolder = function()
				return nil
			end,
			zoneAt = function()
				return 1
			end,
		},
	},
	game,
	Vector3,
	{
		new = function(position)
			return position
		end,
		lookAt = function(position)
			return position
		end,
	},
	function()
		return now
	end
)

local function fixture(offset)
	local attributes = {}
	local root = {
		Position = Vector3.new(0, 50 + offset, 0),
		AssemblyLinearVelocity = Vector3.new(0, -100, 0),
		AssemblyAngularVelocity = Vector3.new(3, 2, 1),
		FindFirstChild = function()
			return nil
		end,
	}
	local model = {
		Parent = true,
		FindFirstChild = function(_, name)
			if name == "Head" then
				return {
					Color = {},
					IsA = function(_, class)
						return class == "BasePart"
					end,
				}
			end
			return nil
		end,
		SetAttribute = function(_, key, value)
			attributes[key] = value
		end,
		GetAttribute = function(_, key)
			return attributes[key]
		end,
		PivotTo = function(_, position)
			root.Position = position
		end,
	}
	return {
		root = root,
		model = model,
		player = {
			SetAttribute = function(_, key, value)
				attributes[key] = value
			end,
		},
		humanoid = { Move = function() end, WalkSpeed = 14 },
		stats = { maxHealth = 200, regenPerSecond = 2, walkSpeed = 14, scale = 1 },
		groundOffset = offset,
		zoneId = 1,
		hp = 120,
		downedUntil = 0,
		fallRecovery = false,
		mounted = true,
		riderGraceUntil = 0,
		sprinting = false,
		nextSprintChange = 0,
		lastSteerAt = 0,
		steer = Vector3.zero,
	},
		attributes
end

for _, offset in { 8, 24 } do
	local golem, attributes = fixture(offset)
	-- The feet can reach the plane without a false knock-out.
	golem.root.Position = Vector3.new(0, 50 + offset - Config.Golem.fallDepth, 0)
	service.update(golem, 0)
	assert(golem.hp == 120 and golem.downedUntil == 0)
	-- The first server update below it kills, rather than merely teleporting.
	golem.root.Position = Vector3.new(0, golem.root.Position.Y - 0.01, 0)
	service.update(golem, 1)
	assert(golem.hp == 0 and golem.downedUntil == now + Config.Golem.respawnTime)
	assert(attributes.GolemDowned and attributes.GolemHealth == 0)
	assert(attributes.FallRecovery and attributes.FallPosition.Y < 50 + offset - Config.Golem.fallDepth)
	assert(golem.root.Position.Y == 50 + offset)
	assert(golem.root.AssemblyLinearVelocity == Vector3.zero)
	assert(golem.root.AssemblyAngularVelocity == Vector3.zero)
	assert(not service.isActive(golem))
	local count = messages
	service.update(golem, 1)
	assert(golem.hp == 0 and messages == count) -- no repeated death or regen
	now = golem.downedUntil
	service.update(golem, 1)
	assert(service.isActive(golem) and golem.hp == 200 and not attributes.GolemDowned)
	assert(not attributes.FallRecovery)
end
assert(messages == 2)

-- A detached rider is also killed even when the golem is safely on land.
local detached, detachedAttributes = fixture(8)
local humanoid = { Health = 100, HipHeight = 2 }
local riderRoot = {
	Position = Vector3.new(0, 20, 0),
	Size = Vector3.new(2, 2, 1),
	IsA = function(_, class)
		return class == "BasePart"
	end,
}
detached.player.Character = {
	FindFirstChildOfClass = function()
		return humanoid
	end,
	FindFirstChild = function()
		return riderRoot
	end,
}
service.update(detached, 0)
assert(humanoid.Health == 0 and detached.hp == 0 and detachedAttributes.FallRecovery)
assert(detached.downedUntil == now + Config.Golem.respawnTime)
local count = messages
service.update(detached, 1)
assert(messages == count and humanoid.Health == 0)
print("GolemService fall knock-out and recovery checks passed")

-- A freshly spawned rider is below the island until they are seated, so the
-- fall check waits out the spawn grace instead of killing them.
local spawning, spawningAttributes = fixture(8)
local spawningHumanoid = { Health = 100, HipHeight = 2 }
spawning.player.Character = {
	FindFirstChildOfClass = function()
		return spawningHumanoid
	end,
	FindFirstChild = function()
		return riderRoot
	end,
}
spawning.riderGraceUntil = now + 3
service.update(spawning, 0)
assert(spawningHumanoid.Health == 100 and spawning.hp == 120 and not spawningAttributes.FallRecovery)
now += 3
service.update(spawning, 0)
assert(spawningHumanoid.Health == 0 and spawning.hp == 0) -- still off the island once the grace is over
print("GolemService rider spawn grace checks passed")

-- Mounting: dismounted, steering is ignored and the golem is only hit by its own falls.
local mountGolem, mountAttributes = fixture(8)
mountGolem.mounted = true
mountGolem.nextMountChange = 0
mountGolem.lastSteerAt = 0
mountGolem.steer = Vector3.new(1, 0, 0)
mountGolem.lastSteerAt = now
assert(service.getSteer(mountGolem).X == 1)
mountGolem.player.SetAttribute = function(_, key, value)
	mountAttributes[key] = value
end
mountGolem.player.Character = nil
service.setMounted(mountGolem, false)
assert(not mountGolem.mounted and mountAttributes.GolemMounted == false)
assert(service.getSteer(mountGolem) == Vector3.zero)
service.setMounted(mountGolem, true)
assert(mountGolem.mounted and mountAttributes.GolemMounted == true)
print("GolemService mount checks passed")

-- Sprinting: faster only while a mounted rider steers; never for a golem playing itself.
local runner, runnerAttributes = fixture(8)
local sprintSpeed = 14 * Config.Golem.sprintMult
runner.steer = Vector3.new(1, 0, 0)
runner.steer.Magnitude = 1
runner.lastSteerAt = now
service.setSprinting(runner, true)
assert(runner.humanoid.WalkSpeed == sprintSpeed and runnerAttributes.Sprinting == true)
now += 1 -- the steering input has timed out: the golem is playing itself again
service.update(runner, 0)
assert(runner.humanoid.WalkSpeed == 14 and runnerAttributes.Sprinting == false)
runner.lastSteerAt = now
service.update(runner, 0)
assert(runner.humanoid.WalkSpeed == sprintSpeed) -- steering again, sprint still wanted
runner.mounted = false
service.update(runner, 0)
assert(runner.humanoid.WalkSpeed == 14 and runnerAttributes.Sprinting == false) -- dismounted: no sprint
service.setSprinting(runner, true)
assert(not runner.sprinting) -- and it can't be switched on while dismounted

-- The sprint request: booleans only, rate limited, and the server publishes what it honours.
local asker, askerAttributes = fixture(8)
assert(not service.requestSprint(asker, "yes") and not service.requestSprint(asker, nil))
assert(not service.requestSprint(asker, false)) -- already off: nothing to change
assert(service.requestSprint(asker, true) and asker.sprinting and askerAttributes.GolemSprint == true)
-- Dropped inside the cooldown; GolemSprint still says on, which is how the client knows to ask again.
assert(not service.requestSprint(asker, false) and asker.sprinting and askerAttributes.GolemSprint == true)
now += 1
assert(service.requestSprint(asker, false) and not asker.sprinting and askerAttributes.GolemSprint == false)
asker.mounted = false
now += 1
assert(not service.requestSprint(asker, true) and not asker.sprinting) -- no sprinting on foot
asker.mounted = true
now += 1
service.requestSprint(asker, true)
service.damage(asker, asker.hp) -- knocked out while sprinting
assert(not asker.sprinting and askerAttributes.Sprinting == false and askerAttributes.GolemSprint == false)
print("GolemService sprint checks passed")

-- The dismounted leash: the golem fights and mines inside followRadius, walks
-- back once beyond it (until well inside, so it doesn't jitter on the edge),
-- and puffs back beside the rider when very far or stuck.
local floorHits = true
workspace = {
	Raycast = function(_, _origin, direction)
		if direction.Y ~= 0 and floorHits then
			return { Position = Vector3.new(0, 50, 0), Normal = Vector3.new(0, 1, 0) }
		end
		return nil -- no walls
	end,
}
RaycastParams = {
	new = function()
		return {}
	end,
}
Enum = { RaycastFilterType = { Exclude = "Exclude" } }

local function leashFixture()
	local golem = fixture(8)
	golem.mounted = false
	golem.following = false
	golem.stats.scale = 1
	local moves = {}
	golem.humanoid.MoveTo = function(_, target)
		table.insert(moves, target)
	end
	local riderHumanoid = { Health = 100, HipHeight = 2 }
	local riderRoot = {
		Position = Vector3.new(0, 53, 0),
		CFrame = { LookVector = Vector3.new(0, 0, -1), RightVector = Vector3.new(1, 0, 0) },
		IsA = function(_, class)
			return class == "BasePart"
		end,
	}
	golem.player.Character = {
		FindFirstChildOfClass = function()
			return riderHumanoid
		end,
		FindFirstChild = function()
			return riderRoot
		end,
	}
	golem.player.UserId = 1
	return golem, moves, riderRoot, riderHumanoid
end

local radius = Config.Golem.followRadius
local leashed, moves, leashRider, leashHumanoid = leashFixture()
leashed.root.Position = Vector3.new(radius - 1, 58, 0)
assert(not service.followRider(leashed, now) and not leashed.following and #moves == 0) -- inside: free
assert(service.inLeash(leashed, Vector3.new(0, 50, radius - 1)))
assert(not service.inLeash(leashed, Vector3.new(0, 50, radius + 1)))
leashed.root.Position = Vector3.new(radius + 1, 58, 0)
assert(service.followRider(leashed, now) and leashed.following and #moves == 1) -- strayed: walks back
assert(moves[1].X > 0 and moves[1].X < radius * Config.Golem.followStop) -- to well inside the leash
leashed.root.Position = Vector3.new(radius * 0.8, 58, 0)
assert(service.followRider(leashed, now) and leashed.following) -- still walking: no edge jitter
leashed.root.Position = Vector3.new(radius * Config.Golem.followStop - 1, 58, 0)
assert(not service.followRider(leashed, now) and not leashed.following) -- arrived

-- A faster rider pulling ahead isn't "stuck" while the golem keeps walking.
leashed.root.Position = Vector3.new(radius + 5, 58, 0)
assert(service.followRider(leashed, now))
now += Config.Golem.stuckTime * 0.9
leashed.root.Position = Vector3.new(radius + 5 - Config.Golem.stuckTime, 58, 0)
local walkingPuffs = puffs
assert(service.followRider(leashed, now))
now += Config.Golem.stuckTime * 0.9
assert(service.followRider(leashed, now) and puffs == walkingPuffs)
leashed.following = false

-- A new character still on its way from the SpawnLocation isn't followed.
leashed.riderGraceUntil = now + 1
assert(service.leashCenter(leashed) == nil and not service.followRider(leashed, now))
leashed.riderGraceUntil = 0

-- Stuck walking back: no closer after stuckTime, so it puffs beside the rider.
leashed.root.Position = Vector3.new(radius + 5, 58, 0)
assert(service.followRider(leashed, now))
now += Config.Golem.stuckTime + 0.1
local puffsBefore = puffs
assert(not service.followRider(leashed, now) and not leashed.following)
assert(puffs == puffsBefore + 2) -- where it left and where it lands
assert(((leashed.root.Position - leashRider.Position) * Vector3.new(1, 0, 1)).Magnitude < radius)
assert(leashed.root.AssemblyLinearVelocity == Vector3.zero)

-- Very far: puffs back at once. While the rider is in the air it waits.
leashed.root.Position = Vector3.new(Config.Golem.leashTeleportRadius + 10, 58, 0)
floorHits = false
assert(service.followRider(leashed, now) and leashed.root.Position.X > radius) -- walking, no puff yet
floorHits = true
puffsBefore = puffs
service.followRider(leashed, now)
assert(puffs == puffsBefore + 2 and leashed.root.Position.X < radius)

-- No leash while mounted or while the rider is dead.
leashed.mounted = true
assert(service.leashCenter(leashed) == nil and service.inLeash(leashed, Vector3.new(999, 50, 0)))
leashed.mounted = false
leashHumanoid.Health = 0
assert(not service.followRider(leashed, now) and service.leashCenter(leashed) == nil)
leashHumanoid.Health = 100

-- Climbing on needs the rider alive and close to the golem.
leashed.root.Position = Vector3.new(Config.Golem.mountRange - 1, 58, 0)
assert(service.canClimbOn(leashed))
leashed.root.Position = Vector3.new(Config.Golem.mountRange + 1, 58, 0)
assert(not service.canClimbOn(leashed))
leashed.root.Position = Vector3.new(1, 58, 0)
leashHumanoid.Health = 0
assert(not service.canClimbOn(leashed))
print("GolemService leash and climb-on checks passed")
