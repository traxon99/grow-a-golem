-- The real MiningService is loaded by scripts/check_mining_service.py.
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
vector.__mul = function(a, b)
	if type(a) == "number" then
		return v(a * b.X, a * b.Y, a * b.Z)
	end
	return v(a.X * b, a.Y * b, a.Z * b)
end
local Vector3 = { new = v, zero = v(0, 0, 0) }

local cfMeta = {}
cfMeta.__index = function(self, key)
	if key == "Rotation" then
		return self
	end
	return nil
end
cfMeta.__mul = function(a, b)
	return setmetatable({ Position = a.Position + b.Position }, cfMeta)
end
cfMeta.__add = function(a, b)
	return setmetatable({ Position = a.Position + b }, cfMeta)
end
local CFrame = {
	new = function(a, b, c)
		return setmetatable({ Position = if type(a) == "table" then a else v(a or 0, b or 0, c or 0) }, cfMeta)
	end,
	Angles = function()
		return setmetatable({ Position = v(0, 0, 0) }, cfMeta)
	end,
}

local partMeta = {}
partMeta.__index = function(self, key)
	if key == "CFrame" then
		return rawget(self, "_cf")
	end
	return nil
end
partMeta.__newindex = function(self, key, value)
	if key == "CFrame" then
		rawset(self, "_cf", value)
		rawset(self, "Position", value.Position)
	else
		rawset(self, key, value)
	end
end
local Instance = {
	new = function(class)
		local attributes = {}
		local instance = setmetatable({
			ClassName = class,
			Position = v(0, 0, 0),
			SetAttribute = function(_, key, value)
				attributes[key] = value
			end,
			GetAttribute = function(_, key)
				return attributes[key]
			end,
			Destroy = function(self)
				self.destroyed = true
				self.Parent = nil
			end,
		}, partMeta)
		if class == "ProximityPrompt" then
			instance.Triggered = {
				Connect = function(_, callback)
					instance.onTriggered = callback
				end,
			}
		end
		return instance
	end,
}
local Enum = { Material = { Slate = "Slate", Neon = "Neon" }, HighlightDepthMode = { Occluded = "Occluded" } }
local Color3 = {
	fromRGB = function()
		return {}
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
local scheduled = {}
local task = {
	delay = function(seconds, callback)
		table.insert(scheduled, { seconds = seconds, callback = callback })
	end,
}
local Config = {
	Zones = {
		[1] = {
			nodes = { { mineral = "stone", weight = 1 } },
			nodeCount = 1,
			nodeRespawn = 5,
		},
	},
	Nodes = { stone = { size = v(4, 4, 4), maxHealth = 100, yield = 10, material = "Slate" } },
	Minerals = { stone = { displayName = "Stone", color = {} } },
	WeakspotRush = {
		firstDelaySeconds = 18,
		firstWindowSeconds = 7,
		followupSeconds = 4,
		cooldownSeconds = 45,
		range = 14,
		bonusFraction = 0.5,
	},
}
local a = { UserId = 1, Parent = true }
local b = { UserId = 2, Parent = true }
local function characterAt(position)
	return {
		FindFirstChild = function()
			return {
				Position = position,
				IsA = function(_, class)
					return class == "BasePart"
				end,
			}
		end,
	}
end
a.Character = characterAt(v(0, 2, 0))
b.Character = characterAt(v(0, 2, 0))
local paid = {}
local mined = {}
local notices = {}
local mining = loadMiningService({
	Config = Config,
	MarbleBag = {
		new = function()
			return {
				draw = function()
					return "stone"
				end,
			}
		end,
	},
	Remotes = {
		Notify = {
			FireClient = function(_, player)
				notices[player] = (notices[player] or 0) + 1
			end,
		},
	},
	DataService = {
		update = function(player, callback)
			local data = mined[player] or { totals = { nodes = 0 } }
			mined[player] = data
			callback(data)
		end,
	},
	EconomyService = {
		grant = function(player, reward)
			paid[player] = (paid[player] or 0) + reward.minerals.stone
			return reward
		end,
	},
	Events = { fire = function() end },
	WorldService = {
		randomPoint = function()
			return v(0, 0, 0)
		end,
		getFolder = function()
			return {}
		end,
	},
}, game, Instance, Vector3, CFrame, Enum, Color3, task)
local function spawnNode()
	mining.start()
	local node = mining.findNearest(v(0, 2, 0), 100, 1)
	assert(node ~= nil)
	return node
end

local node = spawnNode()
mining.damage(node, 90, a)
mining.damage(node, 10, b)
assert(node.part.destroyed and paid[a] == 10 and paid[b] == nil)
assert(mined[a].totals.nodes == 1 and notices[a] == 1)

-- Equal damage is resolved deterministically, independent of the final hit.
node = spawnNode()
mining.damage(node, 50, b)
mining.damage(node, 50, a)
assert(paid[a] == 20 and paid[b] == nil)

-- Departed contributors cannot claim a node after disconnecting.
node = spawnNode()
mining.damage(node, 80, a)
a.Parent = nil
mining.damage(node, 20, b)
assert(paid[a] == 20 and paid[b] == 10)
a.Parent = true

node = spawnNode()
mining.damage(node, 0, a)
mining.damage(node, 1000, b)
assert(paid[a] == 20 and paid[b] == 20)
assert(mined[b].totals.nodes == 2 and notices[b] == 2)

-- Optional two-tap rush: the first tap changes the active ore chunk. Only the
-- same nearby player can finish; the reward is fixed and never repeats.
node = spawnNode()
scheduled[#scheduled].callback()
assert(node.weakspotStage == 1 and node.weakspotPrompt.Enabled and node.weakspotGlow.Enabled)
node.weakspotPrompt.onTriggered(a)
assert(node.weakspotStage == 2 and node.weakspotPlayer == a)
node.weakspotPrompt.onTriggered(b)
assert(paid[b] == 20 and node.weakspotStage == 2, "another player cannot finish the sequence")
node.weakspotPrompt.onTriggered(a)
assert(paid[a] == 25 and node.weakspotClaimed and not node.weakspotPrompt.Enabled)
node.weakspotPrompt.onTriggered(a)
assert(paid[a] == 25, "a completed rush cannot pay twice")

-- Spoofed/out-of-range triggers and expired windows never pay.
node = spawnNode()
scheduled[#scheduled].callback()
a.Character = characterAt(v(500, 2, 0))
node.weakspotPrompt.onTriggered(a)
assert(node.weakspotStage == 1)
a.Character = characterAt(v(0, 2, 0))
node.weakspotDeadline = os.clock() - 1
node.weakspotPrompt.onTriggered(a)
assert(paid[a] == 25)
scheduled[#scheduled].callback() -- first window expires; queue one retry
assert(node.weakspotStage == 0 and not node.weakspotPrompt.Enabled)
scheduled[#scheduled].callback() -- retry after cooldown
assert(node.weakspotStage == 1)
mining.damage(node, 100, b)
node.weakspotPrompt.onTriggered(a)
assert(paid[a] == 25, "a destroyed node cannot pay")

print("MiningService ownership and two-tap weakspot rush checks passed")
