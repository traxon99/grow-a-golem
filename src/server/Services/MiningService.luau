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

	nodes[part] = { mineral = mineral, def = def, zoneId = zoneId, part = part, hp = def.maxHealth, chunks = chunks }
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
	if nodes[node.part] == nil then
		return
	end
	node.hp -= amount
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

	local given = EconomyService.grant(player, { minerals = { [node.mineral] = node.def.yield } }, "mining")
	DataService.update(player, function(data)
		data.totals.nodes += 1
	end)
	Events.fire("nodeMined", player, node.mineral)
	Remotes.Notify:FireClient(player, "mined", node.mineral, given.minerals and given.minerals[node.mineral] or 0)
	nodes[node.part] = nil
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
