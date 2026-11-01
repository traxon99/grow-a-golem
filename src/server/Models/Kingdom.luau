--!strict
-- Graybox ground for the connected kingdom (#214): one anchored part per
-- area and ramp in Config.Kingdom.layout, plus a flat, non-colliding marker
-- on each plot boundary. Placeholder art until #218 validates the layout.
-- Ground queries never read these parts (see KingdomLayout), so art added
-- later can't change where golems spawn, walk or recover.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local KingdomLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KingdomLayout"))

local Kingdom = {}

local RAMP_COLOR = Color3.fromRGB(128, 118, 100)
local PLOT_COLOR = Color3.fromRGB(176, 150, 96)

local function look(zoneId: number): (Color3, Enum.Material)
	local zone = if zoneId == Config.HubZone then Config.Hub else Config.Zones[zoneId]
	if zone then
		return zone.color, zone.material
	end
	return RAMP_COLOR, Enum.Material.Slate
end

local function ground(name: string, zoneId: number, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("ZoneId", zoneId)
	part.Parent = parent
	return part
end

-- Builds every zone in `layout` under `parent`. Returns the parts by piece id.
function Kingdom.build(layout: KingdomLayout.Layout, parent: Instance): { [string]: BasePart }
	local parts: { [string]: BasePart } = {}
	for zoneId, zone in layout do
		local color, material = look(zoneId)
		for _, area in zone.areas do
			local part = ground(area.id, zoneId, parent)
			part.Size = area.size
			part.Position = area.center - Vector3.new(0, area.size.Y / 2, 0)
			part.Color = color
			part.Material = material
			parts[area.id] = part
		end
		for _, ramp in zone.ramps or {} do
			local length = (ramp.to - ramp.from).Magnitude
			local middle = ramp.from:Lerp(ramp.to, 0.5)
			local part = ground(ramp.id, zoneId, parent)
			part.Size = Vector3.new(ramp.width, ramp.thickness, length)
			-- Tilted along the centerline, then lowered so its top is the slope.
			part.CFrame = CFrame.lookAt(middle, ramp.to) * CFrame.new(0, -ramp.thickness / 2, 0)
			part.Color = RAMP_COLOR
			part.Material = Enum.Material.Cobblestone
			parts[ramp.id] = part
		end
		for _, box in zone.exclude or {} do
			local marker = ground(box.id, zoneId, parent)
			marker.Size = Vector3.new(box.size.X, 0.2, box.size.Z)
			marker.Position = Vector3.new(box.center.X, box.center.Y + 0.1, box.center.Z)
			marker.CanCollide = false
			marker.CanQuery = false
			marker.CanTouch = false
			marker.Color = PLOT_COLOR
			marker.Material = Enum.Material.WoodPlanks
			parts[box.id] = marker
		end
	end
	return parts
end

return Kingdom
