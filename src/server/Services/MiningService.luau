--!strict
-- Places mineral nodes around each zone. Golems chip them down; when a node
-- breaks, the player gets its yield and a new node appears somewhere else later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
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
}

local MiningService = {}

local nodes: { [BasePart]: Node } = {}

local function pickMineral(zone: any): string
	local total = 0
	for _, entry in zone.nodes do
		total += entry.weight
	end
	local roll = math.random() * total
	for _, entry in zone.nodes do
		roll -= entry.weight
		if roll <= 0 then
			return entry.mineral
		end
	end
	return zone.nodes[1].mineral
end

local function placeNode(zoneId: number)
	local zone = Config.Zones[zoneId]
	local mineral = pickMineral(zone)
	local def = Config.Nodes[mineral]
	local point = WorldService.randomPoint(zoneId, 16)

	local part = Instance.new("Part")
	part.Name = Config.Minerals[mineral].displayName .. "Node"
	part.Anchored = true
	part.Size = def.size
	part.Color = Config.Minerals[mineral].color
	part.Material = def.material
	part.CFrame = CFrame.new(point + Vector3.new(0, def.size.Y / 2, 0))
		* CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
	part.Parent = WorldService.getFolder("Nodes")

	nodes[part] = { mineral = mineral, def = def, zoneId = zoneId, part = part, hp = def.maxHealth }
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
		node.part.CFrame = node.part.CFrame.Rotation + Vector3.new(node.part.Position.X, bottom + size.Y / 2, node.part.Position.Z)
		return
	end

	local given = EconomyService.grant(player, { minerals = { [node.mineral] = node.def.yield } })
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
