--!strict
-- Builds placeholder islands for any zone the place doesn't have yet, and
-- answers "where is a random spot in zone N" for spawners.
-- Once you build real islands in Studio, name each ground part "Zone1",
-- "Zone2"... (and "Hub" for the hub) and this service will use yours instead
-- of making flat ones.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Islands = require(script.Parent.Parent.Models.Islands)

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

-- Finds the first child of a class, or makes one.
local function ensure(parent: Instance, className: string): any
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local made = Instance.new(className)
	made.Parent = parent
	return made
end

-- A bright, warm afternoon with soft haze and a little glow on neon parts.
-- Low-poly art reads best with saturated colors and soft shadows.
local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(78, 74, 88)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 146, 160)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 220)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.FogEnd = 100000

	local atmosphere = ensure(Lighting, "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(200, 222, 255)
	atmosphere.Decay = Color3.fromRGB(120, 140, 190)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.2

	local bloom = ensure(Lighting, "BloomEffect") :: BloomEffect
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.4

	local color = ensure(Lighting, "ColorCorrectionEffect") :: ColorCorrectionEffect
	color.Saturation = 0.18
	color.Contrast = 0.06
	color.Brightness = 0.02

	local rays = ensure(Lighting, "SunRaysEffect") :: SunRaysEffect
	rays.Intensity = 0.05
	rays.Spread = 0.7

	ensure(Lighting, "Sky")
end

-- The Baseplate template's grey floor sits right under the islands; turn it
-- into a soft cloud layer instead so the islands look like they float.
local function cloudSea()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if not (baseplate and baseplate:IsA("BasePart")) then
		return
	end
	baseplate.Color = Color3.fromRGB(236, 242, 255)
	baseplate.Material = Enum.Material.SmoothPlastic
	for _, child in baseplate:GetChildren() do
		if child:IsA("Texture") or child:IsA("Decal") then
			child.Transparency = 1
		end
	end
end

-- Characters spawn on Mossy Quarry, a little behind where the golem stands.
local SPAWN_ZONE = 1
local SPAWN_OFFSET = Vector3.new(0, 0, 16)

-- The Baseplate template's SpawnLocation, and Roblox's fallback when there is
-- none, are at the world origin: inside zone 1's hanging underside rock. Any
-- spawn that isn't standing on an island moves up onto zone 1, and if the
-- place has none, an invisible one is made there.
local function placeSpawns()
	local top = WorldService.getSpawnPoint(SPAWN_ZONE) + SPAWN_OFFSET
	-- Hidden and walk-through, so it doesn't read as a pad on the meadow.
	local function standOnIsland(spawn: SpawnLocation)
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.Transparency = 1
		for _, child in spawn:GetChildren() do
			if child:IsA("Decal") or child:IsA("Texture") then
				child.Transparency = 1
			end
		end
		spawn.CFrame = CFrame.new(top + Vector3.new(0, spawn.Size.Y / 2, 0))
	end
	local found = false
	for _, item in workspace:GetDescendants() do
		if item:IsA("SpawnLocation") then
			found = true
			local zoneId = WorldService.zoneAt(item.Position)
			local itemTop = item.Position.Y + item.Size.Y / 2
			if not zoneId or itemTop < WorldService.getSurfaceY(zoneId) - 0.5 then
				standOnIsland(item)
			end
		end
	end
	if not found then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "IslandSpawn"
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Neutral = true
		spawn.Duration = 0
		standOnIsland(spawn)
		spawn.Parent = workspace
	end
end

function WorldService.start()
	if Config.Visuals.controlLighting then
		setupLighting()
	end
	if Config.Visuals.cloudSeaBaseplate then
		cloudSea()
	end

	-- The hub is built like an island but has its own config and no gate.
	local islands: { { id: number, zone: any } } = { { id = Config.HubZone, zone = Config.Hub } }
	for id, zone in Config.Zones do
		table.insert(islands, { id = id, zone = zone })
	end
	for _, island in islands do
		local id, zone = island.id, island.zone
		local name = if id == Config.HubZone then "Hub" else "Zone" .. id
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
			grounds[id] = part
			if Config.Visuals.decorateIslands then
				local keepClear = { { position = WorldService.getSpawnPoint(id), radius = 30 } }
				if Config.Bosses[id] then
					table.insert(keepClear, { position = WorldService.getBossPoint(id), radius = 40 })
				end
				local ok, err = pcall(Islands.decorate, part, {
					theme = zone.theme or "meadow",
					seed = if id == Config.HubZone then 4242 else id * 7919,
					keepClear = keepClear,
				})
				if not ok then
					warn(`[WorldService] island scenery failed for zone {id}: {err}`)
				end
			end
		end
		grounds[id] = ground :: BasePart
	end

	for _, name in { "Golems", "Enemies", "Nodes", "Effects", "Relics" } do
		folders[name] = getOrMakeFolder(name)
	end
	placeSpawns()
end

-- Builds (once) a flat arena ground that works like any island: spawn points,
-- random points and surface height all answer for its zone id. Used by the
-- co-op tower; arenas have no scenery, nodes or regular spawns.
function WorldService.addArena(zoneId: number, center: Vector3, size: Vector3, name: string)
	if grounds[zoneId] then
		return
	end
	local part = Instance.new("Part")
	part.Name = "TowerArena" .. zoneId
	part.Anchored = true
	part.Size = size
	part.Position = center - Vector3.new(0, size.Y / 2, 0)
	part.Material = Config.Tower.arenaMaterial
	part.Color = Config.Tower.arenaColor
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Parent = workspace
	makeSign(part, name)
	grounds[zoneId] = part
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
