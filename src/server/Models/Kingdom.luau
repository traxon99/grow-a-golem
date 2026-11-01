--!strict
-- Builds the graybox kingdom route (#214) from Config.Kingdom.layout: one
-- anchored slab per terrace and one sloped slab per ramp, so the ground the
-- golem walks on matches what KingdomLayout answers. Production art replaces
-- this after the first slice is validated (#218, #219).

local Kingdom = {}

local THICKNESS = 6
local GRAY = Color3.fromRGB(120, 116, 108)
local ROAD = Color3.fromRGB(150, 132, 104)

local function sign(part: BasePart, text: string)
	local holder = Instance.new("Part")
	holder.Name = "RegionSign"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = part.Position + Vector3.new(0, THICKNESS / 2 + 30, 0)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(400, 60)
	billboard.MaxDistance = 250
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	billboard.Parent = holder
	holder.Parent = part
end

local function slab(parent: Instance, name: string, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Material = Enum.Material.Slate
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Returns the folder holding the route. Building it twice reuses the first.
-- Obstacles are walk-through for everyone: the server's region check is the
-- lock, and each client shows its own player's opened or closed state.
function Kingdom.build(layout: any, obstacles: any?): Folder
	local existing = workspace:FindFirstChild("Kingdom")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Kingdom"
	for _, t in layout.terraces do
		local part = slab(folder, t.name, if t.spawns == false then ROAD else GRAY)
		part.Size = Vector3.new(t.size.X, THICKNESS, t.size.Z)
		part.Position = Vector3.new(t.center.X, t.y - THICKNESS / 2, t.center.Z)
		if t.spawns ~= false then
			sign(part, t.name)
		end
	end
	for _, r in layout.ramps or {} do
		local rise = r.to - r.from
		local length = rise.Magnitude
		local middle = (r.from + r.to) / 2
		local part = slab(folder, r.name, ROAD)
		part.Size = Vector3.new(r.width, THICKNESS, length)
		-- The slab's top face runs along the lane from `from` to `to`.
		part.CFrame = CFrame.lookAt(middle, middle + rise) * CFrame.new(0, -THICKNESS / 2, 0)
	end
	local obstacleFolder = Instance.new("Folder")
	obstacleFolder.Name = "Obstacles"
	obstacleFolder.Parent = folder
	for id, obstacle in obstacles or {} do
		local part = slab(obstacleFolder, id, Color3.fromRGB(92, 84, 76))
		part.Material = Enum.Material.Cobblestone
		part.CanCollide = false
		part.Size = obstacle.size
		part.Position = obstacle.position + Vector3.new(0, obstacle.size.Y / 2, 0)
		part:SetAttribute("ObstacleId", id)
	end
	folder.Parent = workspace
	return folder
end

return Kingdom
