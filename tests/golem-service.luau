-- Executes the real GolemService, including damage, travel and recovery.
local vector = {}
vector.__index = vector
vector.__add = function(a, b)
	return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, vector)
end
vector.__sub = function(a, b)
	return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, vector)
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
}
local game = {
	GetService = function()
		return shared
	end,
}
local now = 100
local messages = 0
local service = loadGolemService(
	{
		Config = Config,
		CosmeticLooks = {},
		Remotes = { Notify = {
			FireClient = function()
				messages += 1
			end,
		} },
		Stats = {},
		WorldService = {
			getSurfaceY = function()
				return 50
			end,
			getSpawnPoint = function()
				return Vector3.new(0, 50, 0)
			end,
		},
	},
	game,
	Vector3,
	{
		new = function(position)
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
		stats = { maxHealth = 200, regenPerSecond = 2, walkSpeed = 14 },
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
mountGolem.seat = { Occupant = nil }
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
