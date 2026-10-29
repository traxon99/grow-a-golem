--!strict
-- Places mineral nodes around each zone. Golems chip them down; when a node
-- breaks, the player gets its yield and a new node appears somewhere else later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MarbleBag = require(Shared:WaitForChild("MarbleBag"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Events)
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

local ROCK_COLOR = Color3.fromRGB(112, 106, 100)
local GLOWING = { crystal = true }

local MiningService = {}

local nodes: { [BasePart]: Node } = {}

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
		if
			nodes[node.part] == node
			and node.weakspotStage == stage
			and os.clock() >= node.weakspotDeadline
		then
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
		local given = EconomyService.grant(player, { minerals = { [node.mineral] = bonus } }, "mining")
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
			contributor.Parent and (damage > best or (damage == best and winner and contributor.UserId < winner.UserId))
		then
			winner = contributor
			best = damage
		end
	end
	-- Retire the node before any reward callbacks can yield or re-enter.
	nodes[node.part] = nil
	if winner then
		local given = EconomyService.grant(winner, { minerals = { [node.mineral] = node.def.yield } }, "mining")
		DataService.update(winner, function(data)
			data.totals.nodes += 1
		end)
		Events.fire("nodeMined", winner, node.mineral)
		Remotes.Notify:FireClient(winner, "mined", node.mineral, given.minerals and given.minerals[node.mineral] or 0)
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
end

return MiningService
