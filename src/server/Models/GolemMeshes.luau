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

-- Runs `jobs` at once (each may yield) and returns when all have finished.
-- Loading meshes one by one took close to a minute for every tier.
local function runAll(jobs: { () -> () })
	local left = #jobs
	local waiting: thread? = nil
	for _, job in jobs do
		task.spawn(function()
			job()
			left -= 1
			if left == 0 and waiting then
				task.spawn(waiting)
			end
		end)
	end
	if left > 0 then
		waiting = coroutine.running()
		coroutine.yield()
	end
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
	local failed = false
	local jobs = {}
	for role, mesh in roles do
		table.insert(jobs, function()
			local part = meshPart(tier, role, mesh)
			if part then
				part.Parent = model
			else
				failed = true
			end
		end)
	end
	runAll(jobs)
	if failed then
		model:Destroy()
		return nil
	end
	return model
end

-- Loads every tier's meshes at once and calls `onReady(tier)` as each tier's
-- templates are in place, so golems switch to the new art within seconds.
function GolemMeshes.install(onReady: (tier: string) -> ())
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local golem = assets:FindFirstChild("Golem")
	if not golem then
		golem = Instance.new("Folder")
		golem.Name = "Golem"
		golem.Parent = assets
	end
	assert(golem)
	for tier, slots in GolemMeshData do
		task.spawn(function()
			local models: { Model } = {}
			local jobs = {}
			for slot, roles in slots do
				table.insert(jobs, function()
					local model = buildSlot(tier, slot, roles)
					if model then
						table.insert(models, model)
					end
				end)
			end
			runAll(jobs)
			if #models == 0 then
				return
			end
			local folder = golem:FindFirstChild(tier)
			if not folder then
				folder = Instance.new("Folder")
				folder.Name = tier
				folder.Parent = golem
			end
			assert(folder)
			for _, model in models do
				local old = folder:FindFirstChild(model.Name)
				if old then
					old:Destroy()
				end
				model.Parent = folder
			end
			onReady(tier)
		end)
	end
end

return GolemMeshes
