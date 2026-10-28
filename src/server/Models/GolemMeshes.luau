--!strict
-- Turns the uploaded Blender golem meshes (GolemMeshData) into the art
-- templates Build.attachAsset already reads, at ReplicatedStorage.Assets.
-- Golem.<tier>.<slot>. Each template replaces the older block template for
-- that slot. Meshes load in the background; a slot whose meshes fail to load
-- keeps whatever template it had, so the game never goes without art.
--
-- Roles: Main takes the tier colour, Trim a darker shade of it, and Glow is
-- the neon rune colour. They carry the attributes GolemService.tag and the
-- Wardrobe preview use to recolour them for skins.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticLooks = require(Shared:WaitForChild("CosmeticLooks"))
local GolemMeshData = require(script.Parent.GolemMeshData)

local GolemMeshes = {}

GolemMeshes.TRIM_SHADE = 0.68 -- matches TRIM_SHADE in scripts/blender/build_golems.py

local function meshPart(tier: string, role: string, mesh: GolemMeshData.Mesh): MeshPart?
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(
			"rbxassetid://" .. mesh.id,
			{ CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic }
		)
	end)
	if not ok or not part then
		warn("Golem mesh " .. mesh.id .. " didn't load: " .. tostring(part))
		return nil
	end
	part.Name = role
	part.Size = mesh.size
	-- Studio's importer stores the meshes facing +Z (half a turn from the
	-- golem's -Z front), so turn each one back.
	part.CFrame = CFrame.new(mesh.offset) * CFrame.Angles(0, math.pi, 0)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = role ~= "Glow"
	if role == "Glow" then
		part.Color = CosmeticLooks.RUNE_COLOR
		part.Material = Enum.Material.Neon
		part:SetAttribute("LookAccent", true)
	else
		local shade = if role == "Trim" then GolemMeshes.TRIM_SHADE else nil
		local color, material = CosmeticLooks.partLook(tier, shade, nil)
		part.Color = color
		part.Material = material
		part:SetAttribute("ArtShade", shade)
	end
	return part
end

-- Builds one slot's template. All its meshes must load, or nothing changes.
local function buildSlot(tier: string, slot: string, roles: { [string]: GolemMeshData.Mesh }): Model?
	local model = Instance.new("Model")
	model.Name = slot
	-- Mesh art includes its own feet, fists, chest and eyes, so GolemService
	-- drops the block extras for this slot.
	model:SetAttribute("ReplacesExtras", true)
	local pivot = Instance.new("Part")
	pivot.Name = "ArtPivot"
	pivot.Size = Vector3.new(0.01, 0.01, 0.01)
	pivot.Transparency = 1
	pivot.Anchored = true
	pivot.CanCollide = false
	pivot.CanTouch = false
	pivot.CanQuery = false
	pivot.Parent = model
	model.PrimaryPart = pivot
	for role, mesh in roles do
		local part = meshPart(tier, role, mesh)
		if not part then
			model:Destroy()
			return nil
		end
		part.Parent = model
	end
	return model
end

-- Loads every mesh, then calls `onReady` once if any template changed.
function GolemMeshes.install(onReady: () -> ())
	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild("Assets")
		local golem = assets:FindFirstChild("Golem")
		if not golem then
			golem = Instance.new("Folder")
			golem.Name = "Golem"
			golem.Parent = assets
		end
		assert(golem)
		local changed = false
		for tier, slots in GolemMeshData do
			for slot, roles in slots do
				local model = buildSlot(tier, slot, roles)
				if model then
					local folder = golem:FindFirstChild(tier)
					if not folder then
						folder = Instance.new("Folder")
						folder.Name = tier
						folder.Parent = golem
					end
					assert(folder)
					local old = folder:FindFirstChild(slot)
					if old then
						old:Destroy()
					end
					model.Parent = folder
					changed = true
				end
			end
		end
		if changed then
			onReady()
		end
	end)
end

return GolemMeshes
