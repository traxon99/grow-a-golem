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

-- Every OreChunk part spawnDrops creates gets recorded here, so tests below
-- can inspect what happened to it (destroyed? forfeited?) without the real
-- module needing to expose its private `drops` list.
local createdChunks = {}

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
		if key == "Name" and value == "OreChunk" then
			table.insert(createdChunks, self)
		end
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
	GetServerTimeNow = function()
		return os.clock()
	end,
}
local Players = {
	PlayerRemoving = {
		Connect = function(_, callback)
			return callback
		end,
	},
}
local game = {
	GetService = function(_, name)
		if name == "Players" then
			return Players
		end
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
	-- Huge by default so every mining.damage() below is still collected the
	-- instant the test flushes it with mining.update(0), matching the old
	-- synchronous grant these assertions were written against. The dedicated
	-- pickup-radius block near the end shrinks this back down to something
	-- testable.
	Golem = { pickupRadius = 1e9 },
	Spells = { magnet = { burstMultiplier = 3, burstDuration = 10 } },
	-- One chunk per node, for the whole node's yield, keeps every assertion
	-- below arithmetically identical to the pre-drop instant-grant behavior.
	OreDrops = {
		minChunks = 1,
		maxChunks = 1,
		chunkSize = 0.9,
		-- No scatter, flight or slide: every chunk rests where its node stood
		-- (nodes sit 2 studs up, half their 4-stud size, so a 2-stud settle
		-- height keeps it there) and, with no pickup delay, is collected on
		-- the next update.
		scatterRadius = 0,
		minScatterFraction = 0.3,
		flightTime = 0,
		slideTime = 0,
		settleHeight = 2,
		pickupDelay = 0,
		lifetime = 1e9,
		maxConcurrent = 1e9,
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
local spawnCount = 0
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
			-- Counts payout notices only; "oreBurst" is just the break sound.
			FireClient = function(_, player, kind)
				if kind ~= "oreChunk" and kind ~= "mined" then
					return
				end
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
	-- A single golem, parked at the origin, active for whichever player
	-- asks: enough for the pickup-radius math, which only cares about the
	-- distance from this point to a chunk's.
	GolemService = {
		get = function()
			return { root = { Position = v(0, 2, 0) }, stats = { scale = 1 } }
		end,
		isActive = function()
			return true
		end,
	},
	WorldService = {
		-- Every node this test places ends up at a distinct point, each
		-- one strictly closer to (0, 2, 0) than the last. Nodes from
		-- earlier spawnNode() calls are never cleaned out of the real
		-- service's internal `nodes` table, so without this, every node
		-- ever placed landed on the exact same point and findNearest's
		-- tie-break fell back to iterating that table -- which is keyed
		-- by part identity, so its order isn't guaranteed stable from
		-- one luau process run to the next. That's what made #233
		-- flaky: findNearest could return a stale node instead of the
		-- one just spawned.
		randomPoint = function()
			spawnCount += 1
			return v(10 / spawnCount, 0, 0)
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
mining.update(0) -- flushes the winner's ore chunk into a grant (see spawnDrops/collect)
assert(node.part.destroyed and paid[a] == 10 and paid[b] == nil)
assert(mined[a].totals.nodes == 1 and notices[a] == 1)

-- Equal damage is resolved deterministically, independent of the final hit.
node = spawnNode()
mining.damage(node, 50, b)
mining.damage(node, 50, a)
mining.update(0)
assert(paid[a] == 20 and paid[b] == nil)

-- Departed contributors cannot claim a node after disconnecting.
node = spawnNode()
mining.damage(node, 80, a)
a.Parent = nil
mining.damage(node, 20, b)
mining.update(0)
assert(paid[a] == 20 and paid[b] == 10)
a.Parent = true

node = spawnNode()
mining.damage(node, 0, a)
mining.damage(node, 1000, b)
mining.update(0)
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
mining.update(0) -- flush b's chunk now, before the pickup-radius block below shrinks the radius
node.weakspotPrompt.onTriggered(a)
assert(paid[a] == 25, "a destroyed node cannot pay")

-- Pickup radius: a chunk within Config.Golem.pickupRadius of the golem is
-- auto-collected; farther out, it waits -- until a Magnet burst (see
-- CombatService.onCastSpell -> MiningService.triggerMagnetBurst) widens
-- that radius by Config.Spells.magnet.burstMultiplier.
Config.Golem.pickupRadius = 5
node = spawnNode()
node.part.Position = v(12, 2, 0) -- 12 studs from the golem at the origin
mining.damage(node, 100, a)
mining.update(0)
assert(paid[a] == 25, "a chunk 12 studs out, with only a 5-stud base radius, should still be waiting")

mining.triggerMagnetBurst(a)
mining.update(0)
assert(paid[a] == 35, "Magnet's 3x burst (radius 15) should reach a chunk sitting 12 studs out")

-- The golem mines from inside its own pickup radius, so a chunk must not be
-- collected the tick it spawns (#250): it waits until it has landed and
-- pickupDelay has passed, which is what lets players see it at all.
Config.OreDrops.pickupDelay = 0.05
node = spawnNode() -- within a stud or two of the golem
mining.damage(node, 100, a)
mining.update(0)
assert(paid[a] == 35, "a chunk inside the pickup radius must wait out pickupDelay")
local waitStart = os.clock()
repeat
until os.clock() - waitStart >= 0.06
mining.update(0)
assert(paid[a] == 45, "once pickupDelay has passed, a landed chunk in range is collected")
Config.OreDrops.pickupDelay = 0

-- A chunk still flying or sliding is never collected, however close it is.
Config.OreDrops.flightTime = 0.03
Config.OreDrops.slideTime = 0.03
node = spawnNode()
mining.damage(node, 100, a)
mining.update(0)
assert(paid[a] == 45, "a chunk still flying must not be collected")
waitStart = os.clock()
repeat
until os.clock() - waitStart >= 0.075
mining.update(0)
assert(paid[a] == 55, "the chunk is collected once it has landed and slid to rest")
Config.OreDrops.flightTime = 0
Config.OreDrops.slideTime = 0

-- Chunks rest at 0.3-1.0 of the scatter radius from their node, and each
-- one pays (and announces) its own share of the node's yield.
Config.OreDrops.scatterRadius = 15
Config.OreDrops.minChunks = 4
Config.OreDrops.maxChunks = 4
Config.Golem.pickupRadius = 1e9
local before = #createdChunks
local noticesBefore = notices[a]
node = spawnNode()
local origin = node.part.Position
mining.damage(node, 100, a)
for index = before + 1, #createdChunks do
	local rest = createdChunks[index].Position
	local distance = math.sqrt((rest.X - origin.X) ^ 2 + (rest.Z - origin.Z) ^ 2)
	assert(distance >= 15 * 0.3 - 1e-6 and distance <= 15 + 1e-6, "a chunk rests 0.3-1.0 of scatterRadius out")
end
assert(#createdChunks - before == 4)
mining.update(0)
assert(paid[a] == 65, "four chunks of a 10-yield node still pay 10 in total")
assert(notices[a] - noticesBefore == 4, "each chunk announces its own share")
Config.OreDrops.scatterRadius = 0
Config.OreDrops.minChunks = 1
Config.OreDrops.maxChunks = 1
Config.Golem.pickupRadius = 5

-- A chunk nobody reaches still pays out after its lifetime, tagged "Expired"
-- so clients sparkle it in place instead of flying it to a distant golem.
Config.OreDrops.lifetime = 0
node = spawnNode()
node.part.Position = v(50, 2, 0) -- beyond even the Magnet burst's radius
mining.damage(node, 100, a)
mining.update(0)
local expired = createdChunks[#createdChunks]
assert(paid[a] == 75, "an expired chunk still pays out")
assert(expired.destroyed and expired:GetAttribute("Expired") == true, "an expired chunk is tagged for the client")
Config.OreDrops.lifetime = 1e9

-- A winner who disconnects before collecting forfeits the reward rather
-- than being paid late (matches damage()'s own "a departed player cannot
-- claim a reward" rule) -- and the server tags the chunk instead of just
-- silently dropping it, so the client knows not to play a pickup fx for it.
node = spawnNode()
mining.damage(node, 100, b)
b.Parent = nil
mining.update(0)
b.Parent = true
assert(paid[b] == 30, "a forfeited chunk must not pay out")
local forfeited = createdChunks[#createdChunks]
assert(
	forfeited.destroyed and forfeited:GetAttribute("Forfeited") == true,
	"a forfeited chunk should be destroyed and tagged for the client"
)

print("MiningService ownership, two-tap weakspot rush and pickup-radius checks passed")
