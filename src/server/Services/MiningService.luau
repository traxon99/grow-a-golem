--!strict
-- Places mineral nodes around each zone. Golems chip them down; when a node
-- breaks, the player gets its yield and a new node appears somewhere else later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MarbleBag = require(Shared:WaitForChild("MarbleBag"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)
local WorldService = require(script.Parent.WorldService)

export type Node = {
	mineral: string,
	def: any,
	zoneId: number,
	part: BasePart,
	hp: number,
	chunks: { { part: BasePart, offset: CFrame, size: Vector3 } }, -- ore bits, kept relative to `part`
	contributors: { [Player]: number }, -- actual damage, capped at remaining node health
	weakspotStage: number, -- 0 = inactive, 1/2 = next glowing ore to tap
	weakspotDeadline: number,
	weakspotPlayer: Player?,
	weakspotClaimed: boolean, -- a node can pay the rush bonus only once
	weakspotPrompt: ProximityPrompt,
	weakspotGlow: Highlight,
}

-- A node's full yield, once destroyed, is split across a few of these: they
-- pop out, arc through the air and settle, then wait for the winning
-- player's golem to come within pickup range (see `update`). Every chunk in
-- a break shares one `group`, so the "mined" notify and totals only fire
-- once, when the last of them is collected -- same payout as before, just
-- spread over a second of flight instead of handed over instantly.
type DropGroup = {
	owner: Player,
	mineral: string,
	zoneId: number,
	remaining: number,
	given: number, -- sum of EconomyService.grant's actual mineral payout so far
}
type Chunk = {
	part: BasePart,
	owner: Player,
	mineral: string,
	amount: number,
	group: DropGroup,
	velocity: Vector3,
	groundY: number,
	resting: boolean,
	spawnedAt: number,
}

local ROCK_COLOR = Color3.fromRGB(112, 106, 100)
local GLOWING = { crystal = true }

local MiningService = {}

local nodes: { [BasePart]: Node } = {}
local drops: { Chunk } = {} -- flying/settled ore chunks waiting to be collected
local magnetBurstUntil: { [Player]: number } = {}

local mineralBags: { [any]: MarbleBag.Bag<string> } = {} -- which mineral the next node holds, per zone

local function pickMineral(zone: any): string
	local bag = mineralBags[zone]
	if not bag then
		local entries = {}
		for _, entry in zone.nodes do
			table.insert(entries, { value = entry.mineral, weight = entry.weight })
		end
		bag = MarbleBag.new(entries)
		mineralBags[zone] = bag
	end
	return bag:draw()
end

-- A two-tap skill beat on the existing ore chunks. Roblox's proximity prompt
-- supplies E, gamepad and touch controls without a second HUD or client remote.
-- All deadlines, proximity checks and the reward are owned by the server.
local function clearWeakspot(node: Node)
	node.weakspotStage = 0
	node.weakspotDeadline = 0
	node.weakspotPlayer = nil
	node.weakspotPrompt.Enabled = false
	node.weakspotGlow.Enabled = false
end

local startWeakspot: (Node) -> ()

local function retryWeakspot(node: Node)
	clearWeakspot(node)
	task.delay(Config.WeakspotRush.cooldownSeconds, function()
		if nodes[node.part] == node and not node.weakspotClaimed then
			startWeakspot(node)
		end
	end)
end

local function showWeakspot(node: Node, stage: number)
	local duration = if stage == 1 then Config.WeakspotRush.firstWindowSeconds else Config.WeakspotRush.followupSeconds
	node.weakspotStage = stage
	node.weakspotDeadline = os.clock() + duration
	node.weakspotPrompt.ActionText = if stage == 1 then "Tap weakspot 1/2" else "Tap weakspot 2/2"
	node.weakspotPrompt.Parent = node.chunks[stage].part
	node.weakspotPrompt.Enabled = true
	node.weakspotGlow.Adornee = node.chunks[stage].part
	node.weakspotGlow.Enabled = true
	task.delay(duration, function()
		if nodes[node.part] == node and node.weakspotStage == stage and os.clock() >= node.weakspotDeadline then
			retryWeakspot(node)
		end
	end)
end

startWeakspot = function(node: Node)
	if nodes[node.part] ~= node or node.weakspotClaimed or node.weakspotStage ~= 0 then
		return
	end
	showWeakspot(node, 1)
end

local function tapWeakspot(node: Node, player: Player)
	if
		nodes[node.part] ~= node
		or node.weakspotClaimed
		or node.weakspotStage == 0
		or os.clock() > node.weakspotDeadline
		or not player.Parent
	then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return
	end
	local range = Config.WeakspotRush.range + math.max(node.part.Size.X, node.part.Size.Z) / 2
	if (root.Position - node.part.Position).Magnitude > range then
		return
	end
	if node.weakspotStage == 1 then
		node.weakspotPlayer = player
		showWeakspot(node, 2)
	elseif node.weakspotStage == 2 and node.weakspotPlayer == player then
		node.weakspotClaimed = true
		clearWeakspot(node) -- retire before granting; callbacks may re-enter
		local bonus = math.max(1, math.floor(node.def.yield * Config.WeakspotRush.bonusFraction))
		local given = EconomyService.grant(player, { minerals = { [node.mineral] = bonus } }, "mining", node.zoneId)
		Remotes.Notify:FireClient(player, "mined", node.mineral, given.minerals and given.minerals[node.mineral] or 0)
	end
end

local function placeNode(zoneId: number)
	local zone = Config.Zones[zoneId]
	local mineral = pickMineral(zone)
	local def = Config.Nodes[mineral]
	local point = WorldService.randomPoint(zoneId, 16)

	local color = Config.Minerals[mineral].color
	local part = Instance.new("Part")
	part.Name = Config.Minerals[mineral].displayName .. "Node"
	part.Anchored = true
	part.Size = def.size
	-- Stone nodes are plain rock; the others are rock studded with ore.
	part.Color = if mineral == "stone" then color else ROCK_COLOR
	part.Material = if mineral == "stone" then def.material else Enum.Material.Slate
	part.CFrame = CFrame.new(point + Vector3.new(0, def.size.Y / 2, 0))
		* CFrame.Angles(0, math.rad(math.random(0, 359)), 0)

	-- Ore chunks poke out of the rock at angles, low-poly style.
	local chunks: { { part: BasePart, offset: CFrame, size: Vector3 } } = {}
	local count = if mineral == "stone" then 2 else 5
	for i = 1, count do
		local s = math.min(def.size.X, def.size.Z) * (0.35 + math.random() * 0.25)
		local size = if mineral == "crystal" then Vector3.new(s * 0.5, s * 1.6, s * 0.5) else Vector3.new(s, s, s)
		local angle = i / count * math.pi * 2
		local offset = CFrame.new(
			math.cos(angle) * def.size.X * 0.35,
			def.size.Y * (math.random() * 0.5 - 0.1),
			math.sin(angle) * def.size.Z * 0.35
		) * CFrame.Angles(
			math.rad(math.random(-35, 35)),
			math.rad(math.random(0, 359)),
			math.rad(math.random(-35, 35))
		)
		local chunk = Instance.new("Part")
		chunk.Name = "Ore"
		chunk.Anchored = true
		chunk.CanCollide = false
		chunk.CanTouch = false
		chunk.CanQuery = false
		chunk.Size = size
		chunk.Color = color
		chunk.Material = if GLOWING[mineral] then Enum.Material.Neon else def.material
		chunk.CFrame = part.CFrame * offset
		chunk.Parent = part
		table.insert(chunks, { part = chunk :: BasePart, offset = offset, size = size })
	end
	if GLOWING[mineral] then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10
		light.Parent = part
	end
	part.Parent = WorldService.getFolder("Nodes")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WeakspotRush"
	prompt.ObjectText = "Vein Rush: +50% minerals"
	prompt.ActionText = "Tap weakspot 1/2"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.WeakspotRush.range
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = chunks[1].part
	local glow = Instance.new("Highlight")
	glow.Name = "WeakspotGlow"
	glow.FillColor = Color3.fromRGB(255, 208, 80)
	glow.OutlineColor = Color3.fromRGB(255, 240, 160)
	glow.FillTransparency = 0.4
	glow.OutlineTransparency = 0
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Enabled = false
	glow.Parent = part

	local node: Node = {
		mineral = mineral,
		def = def,
		zoneId = zoneId,
		part = part,
		hp = def.maxHealth,
		chunks = chunks,
		contributors = {},
		weakspotStage = 0,
		weakspotDeadline = 0,
		weakspotPlayer = nil,
		weakspotClaimed = false,
		weakspotPrompt = prompt,
		weakspotGlow = glow,
	}
	nodes[part] = node
	prompt.Triggered:Connect(function(player)
		tapWeakspot(node, player)
	end)
	task.delay(Config.WeakspotRush.firstDelaySeconds + math.random(0, 10), function()
		startWeakspot(node)
	end)
end

-- Splits a broken node's yield across a few physical chunks that pop out of
-- where it stood, arc through the air and settle nearby, instead of handing
-- the reward over instantly. Only the node's winner (see `damage` below) can
-- ever collect them, so this changes nothing about who gets paid -- it only
-- adds a second or two of flight before they do.
local function spawnDrops(node: Node, owner: Player)
	local cfg = Config.OreDrops
	local total = node.def.yield
	if total <= 0 then
		-- Nothing to pay out; stop here so a zero-yield node can never leave
		-- a DropGroup with chunks removed by the `amount <= 0` guard below
		-- but `remaining` never reaching 0, which would strand its payout.
		return
	end
	if #drops >= cfg.maxConcurrent then
		-- Hit the server-wide cap: grant instantly rather than drop a chunk
		-- nobody has room to track (see performance-mobile.md's note on
		-- capping pooled debris).
		local given = EconomyService.grant(owner, { minerals = { [node.mineral] = total } }, "mining", node.zoneId)
		DataService.update(owner, function(data)
			data.totals.nodes += 1
		end)
		Events.fire("nodeMined", owner, node.mineral)
		Remotes.Notify:FireClient(owner, "mined", node.mineral, given.minerals and given.minerals[node.mineral] or 0)
		return
	end

	local count = math.clamp(math.random(cfg.minChunks, cfg.maxChunks), 1, math.max(1, total))
	local group: DropGroup = {
		owner = owner,
		mineral = node.mineral,
		zoneId = node.zoneId,
		remaining = count,
		given = 0,
	}
	local base = math.floor(total / count)
	local extra = total - base * count -- remainder goes on the first few chunks

	local color = Config.Minerals[node.mineral].color
	local material = if GLOWING[node.mineral] then Enum.Material.Neon else node.def.material
	local groundY = node.part.Position.Y - node.part.Size.Y / 2

	for i = 1, count do
		local amount = base + (if i <= extra then 1 else 0)
		if amount <= 0 then
			continue
		end
		local part = Instance.new("Part")
		part.Name = "OreChunk"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Size = Vector3.new(cfg.chunkSize, cfg.chunkSize, cfg.chunkSize)
		part.Color = color
		part.Material = material
		part.CFrame = CFrame.new(node.part.Position)
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		part.Parent = WorldService.getFolder("Drops")

		local angle = math.random() * math.pi * 2
		local horizontal = cfg.scatterSpeed * (0.6 + math.random() * 0.6)
		local velocity = Vector3.new(
			math.cos(angle) * horizontal,
			cfg.scatterHeight * (0.7 + math.random() * 0.6),
			math.sin(angle) * horizontal
		)

		local chunk: Chunk = {
			part = part,
			owner = owner,
			mineral = node.mineral,
			amount = amount,
			group = group,
			velocity = velocity,
			groundY = groundY,
			resting = false,
			spawnedAt = os.clock(),
		}
		table.insert(drops, chunk)
	end
end

-- The pickup radius the given player's golem currently sucks chunks in from:
-- its base range (scaled with size, like the other golem ranges), widened
-- 3x for a second right after a Magnet cast (see CombatService.onCastSpell).
-- `update` also waits for each chunk to land and be pickupDelay old.
local function pickupRadius(player: Player): (number?, GolemService.Golem?)
	local golem = GolemService.get(player)
	if not golem or not GolemService.isActive(golem) then
		return nil, nil
	end
	local burstUntil = magnetBurstUntil[player]
	local multiplier = if burstUntil and os.clock() < burstUntil then Config.Spells.magnet.burstMultiplier else 1
	return Config.Golem.pickupRadius * golem.stats.scale * multiplier, golem
end

local function collect(chunk: Chunk)
	local given = EconomyService.grant(
		chunk.owner,
		{ minerals = { [chunk.mineral] = chunk.amount } },
		"mining",
		chunk.group.zoneId
	)
	chunk.group.remaining -= 1
	chunk.group.given += if given.minerals then (given.minerals[chunk.mineral] or 0) else 0
	chunk.part:Destroy()
	if chunk.group.remaining <= 0 then
		-- Last chunk of this node's drop: pay out the same single "mined"
		-- notice (toast + sound, see Hud and Sfx) as the old instant grant.
		DataService.update(chunk.owner, function(data)
			data.totals.nodes += 1
		end)
		Events.fire("nodeMined", chunk.owner, chunk.group.mineral)
		Remotes.Notify:FireClient(chunk.owner, "mined", chunk.group.mineral, chunk.group.given)
	end
end

-- Advances every flying/settled chunk and collects whatever is now in range.
-- Called from CombatService's tick loop, same cadence as golem updates.
function MiningService.update(dt: number)
	local cfg = Config.OreDrops
	local now = os.clock()
	for i = #drops, 1, -1 do
		local chunk = drops[i]
		if not chunk.owner.Parent then
			-- Owner left before collecting: matches `damage`'s own rule that
			-- a departed player can't claim a reward, so this one is
			-- forfeited rather than paid out late. Logged (not silent) since
			-- it's the one path here that destroys a reward instead of
			-- granting it. "Forfeited" tells the client not to play the
			-- pickup fx for it (see Fx.luau's watch on this folder).
			warn(`[MiningService] {chunk.owner.Name} left before collecting {chunk.amount} {chunk.mineral}; forfeited`)
			chunk.part:SetAttribute("Forfeited", true)
			chunk.part:Destroy()
			table.remove(drops, i)
			continue
		end
		if not chunk.resting then
			chunk.velocity -= Vector3.new(0, cfg.gravity * dt, 0)
			local nextPosition = chunk.part.Position + chunk.velocity * dt
			if nextPosition.Y <= chunk.groundY + cfg.settleHeight then
				nextPosition = Vector3.new(nextPosition.X, chunk.groundY + cfg.settleHeight, nextPosition.Z)
				chunk.velocity = Vector3.zero
				chunk.resting = true
			end
			chunk.part.Position = nextPosition
		end

		-- Only a landed chunk that has been out for pickupDelay can be picked
		-- up. The golem mines from inside its pickup radius, so without this
		-- every chunk was collected on the tick it spawned and never reached
		-- a client (#250).
		local collected = false
		local radius, golem = pickupRadius(chunk.owner)
		if
			radius
			and golem
			and chunk.resting
			and now - chunk.spawnedAt >= cfg.pickupDelay
			and (golem.root.Position - chunk.part.Position).Magnitude <= radius
		then
			collected = true
		end
		if not collected and now - chunk.spawnedAt >= cfg.lifetime then
			-- Safety net: an unreachable or forgotten chunk still pays out,
			-- it just never got the collection flourish.
			collected = true
		end
		if collected then
			collect(chunk)
			table.remove(drops, i)
		end
	end
end

-- Widens the caller's pickup radius for Config.Spells.magnet.burstDuration.
function MiningService.triggerMagnetBurst(player: Player)
	magnetBurstUntil[player] = os.clock() + Config.Spells.magnet.burstDuration
end

function MiningService.findNearest(position: Vector3, range: number, zoneId: number): (Node?, number)
	local best, bestDistance = nil, range
	for _, node in nodes do
		if node.zoneId == zoneId then
			local distance = (node.part.Position - position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = node, distance
			end
		end
	end
	return best, bestDistance
end

function MiningService.damage(node: Node, amount: number, player: Player)
	if nodes[node.part] == nil or amount <= 0 then
		return
	end
	local dealt = math.min(amount, node.hp)
	if dealt <= 0 then
		return
	end
	node.contributors[player] = (node.contributors[player] or 0) + dealt
	node.hp -= dealt
	if node.hp > 0 then
		-- Shrink toward 40% size as it's mined so progress is visible.
		local scale = 0.4 + 0.6 * (node.hp / node.def.maxHealth)
		local size = node.def.size * scale
		local bottom = node.part.Position.Y - node.part.Size.Y / 2
		node.part.Size = size
		node.part.CFrame = node.part.CFrame.Rotation
			+ Vector3.new(node.part.Position.X, bottom + size.Y / 2, node.part.Position.Z)
		for _, chunk in node.chunks do
			chunk.part.Size = chunk.size * scale
			chunk.part.CFrame = node.part.CFrame * (CFrame.new(chunk.offset.Position * scale) * chunk.offset.Rotation)
		end
		-- Tells clients to throw off a few chips (see the client Fx).
		node.part:SetAttribute("Hit", ((node.part:GetAttribute("Hit") :: number?) or 0) + 1)
		return
	end

	-- The final chip does not own the whole node: the highest damage contributor
	-- gets its fixed yield. A departed player cannot claim a reward.
	local winner: Player? = nil
	local best = 0
	for contributor, damage in node.contributors do
		if
			contributor.Parent
			and (damage > best or (damage == best and winner and contributor.UserId < winner.UserId))
		then
			winner = contributor
			best = damage
		end
	end
	-- Retire the node before any reward callbacks can yield or re-enter.
	nodes[node.part] = nil
	if winner then
		-- The node's yield now pops out as a few physical chunks for the
		-- winner to walk up to (or Magnet-burst) instead of an instant grant.
		spawnDrops(node, winner)
	end
	node.part:Destroy()
	task.delay(Config.Zones[node.zoneId].nodeRespawn, placeNode, node.zoneId)
end

function MiningService.start()
	for zoneId, zone in Config.Zones do
		for _ = 1, zone.nodeCount do
			placeNode(zoneId)
		end
	end
	-- Matches every other per-player table in this codebase: don't hold onto
	-- a stale entry forever just because the burst it timestamps has expired.
	Players.PlayerRemoving:Connect(function(player: Player)
		magnetBurstUntil[player] = nil
	end)
end

return MiningService
