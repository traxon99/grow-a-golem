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
		humanoid = { Move = function() end },
		stats = { maxHealth = 200, regenPerSecond = 2 },
		groundOffset = offset,
		zoneId = 1,
		hp = 120,
		downedUntil = 0,
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
end
assert(messages == 2)
print("GolemService fall knock-out and recovery checks passed")
