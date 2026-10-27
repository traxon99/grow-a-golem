--!strict
-- Builds placeholder islands for any zone the place doesn't have yet, and
-- answers "where is a random spot in zone N" for spawners.
-- Once you build real islands in Studio, name each ground part "Zone1",
-- "Zone2"... and this service will use yours instead of making flat ones.

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

local function makeSign(ground: BasePart, text: string)
	local sign = Instance.new("Part")
	sign.Name = "ZoneSign"
	sign.Anchored = true
	sign.CanCollide = false
	sign.Transparency = 1
	sign.Size = Vector3.new(1, 1, 1)
	sign.Position = ground.Position + Vector3.new(0, ground.Size.Y / 2 + 30, 0)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(400, 60)
	billboard.MaxDistance = 250
	billboard.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	billboard.Parent = sign
	sign.Parent = ground
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
			part.Material = zone.material
			part.Color = zone.color
			part.TopSurface = Enum.SurfaceType.Smooth
			part.Parent = workspace
			makeSign(part, zone.name)
			ground = part
		end
		grounds[id] = ground :: BasePart
	end

	for _, name in { "Golems", "Enemies", "Nodes", "Effects", "Relics" } do
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

-- Where the zone's boss lives: the far corner, away from the spawn.
function WorldService.getBossPoint(zoneId: number): Vector3
	local ground = grounds[zoneId]
	local x = ground.Position.X + ground.Size.X * 0.32
	local z = ground.Position.Z - ground.Size.Z * 0.32
	return Vector3.new(x, WorldService.getSurfaceY(zoneId), z)
end

function WorldService.randomPoint(zoneId: number, margin: number): Vector3
	local ground = grounds[zoneId]
	local halfX = math.max(ground.Size.X / 2 - margin, 0)
	local halfZ = math.max(ground.Size.Z / 2 - margin, 0)
	local x = ground.Position.X + (math.random() * 2 - 1) * halfX
	local z = ground.Position.Z + (math.random() * 2 - 1) * halfZ
	return Vector3.new(x, WorldService.getSurfaceY(zoneId), z)
end

-- Which zone a point is over, or nil.
function WorldService.zoneAt(position: Vector3): number?
	for id, ground in grounds do
		local offset = position - ground.Position
		if math.abs(offset.X) <= ground.Size.X / 2 and math.abs(offset.Z) <= ground.Size.Z / 2 then
			return id
		end
	end
	return nil
end

return WorldService
