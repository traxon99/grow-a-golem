--!strict
-- Builds placeholder zones if the place doesn't have them yet, and answers
-- "where is a random spot in zone N" for spawners.
-- Once you build real islands in Studio, name the ground part "Zone1" and
-- this service will use yours instead of making a flat one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local WorldService = {}

local grounds: { [number]: BasePart } = {}
local folders: { [string]: Folder } = {}

local function getOrMakeFolder(name: string): Folder
	local existing = workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

function WorldService.start()
	for id, zone in Config.Zones do
		local name = "Zone" .. id
		local ground = workspace:FindFirstChild(name)
		if not (ground and ground:IsA("BasePart")) then
			local part = Instance.new("Part")
			part.Name = name
			part.Anchored = true
			part.Size = zone.size
			part.Position = zone.center - Vector3.new(0, zone.size.Y / 2, 0)
			part.Material = Enum.Material.Grass
			part.Color = zone.color
			part.TopSurface = Enum.SurfaceType.Smooth
			part.Parent = workspace
			ground = part
		end
		grounds[id] = ground :: BasePart
	end

	for _, name in { "Golems", "Enemies", "Nodes", "Effects" } do
		folders[name] = getOrMakeFolder(name)
	end
end

function WorldService.getFolder(name: string): Folder
	return folders[name]
end

-- Height of the walkable top surface of a zone.
function WorldService.getSurfaceY(zoneId: number): number
	local ground = grounds[zoneId]
	return ground.Position.Y + ground.Size.Y / 2
end

function WorldService.getSpawnPoint(zoneId: number): Vector3
	local ground = grounds[zoneId]
	return Vector3.new(ground.Position.X, WorldService.getSurfaceY(zoneId), ground.Position.Z)
end

function WorldService.randomPoint(zoneId: number, margin: number): Vector3
	local ground = grounds[zoneId]
	local halfX = math.max(ground.Size.X / 2 - margin, 0)
	local halfZ = math.max(ground.Size.Z / 2 - margin, 0)
	local x = ground.Position.X + (math.random() * 2 - 1) * halfX
	local z = ground.Position.Z + (math.random() * 2 - 1) * halfZ
	return Vector3.new(x, WorldService.getSurfaceY(zoneId), z)
end

return WorldService
