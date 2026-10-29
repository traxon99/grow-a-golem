--!strict
-- Owns each player's golem: building the model from its parts and size,
-- carrying the rider, the dismounted leash, health, knock-outs, travel, and
-- the steering intent sent by the client. The golem is server-owned so its
-- position can't be spoofed.
--
-- Mounted, the rider's HumanoidRootPart is welded to the golem's RiderMount
-- attachment. There is no Seat: sitting is run by the client's Humanoid,
-- which is the likeliest reason riders fell off during rebuilds (see
-- restyle). Looks and size changes are made on the same model, root,
-- humanoid and mount, so a forge upgrade never touches the rider, the camera
-- subject or anything in flight.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CosmeticLooks = require(Shared:WaitForChild("CosmeticLooks"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local WorldService = require(script.Parent.WorldService)
local Build = require(script.Parent.Parent.Models.Build)
local GolemMeshes = require(script.Parent.Parent.Models.GolemMeshes)

export type Golem = {
	player: Player,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	mount: Attachment, -- RiderMount on the root, where the rider sits
	rider: Weld?, -- the weld holding the rider on, while there is one
	groundOffset: number, -- root height above the ground
	visualKey: string,
	stats: Stats.GolemStats,
	zoneId: number,
	hp: number,
	downedUntil: number, -- 0 when standing
	fallRecovery: boolean,
	mounted: boolean, -- the rider is on the shoulder; steering, sprint and spells only count then
	following: boolean, -- dismounted and walking back inside the leash
	followFrom: Vector3, -- where it was when it last made headway walking back
	followProgressAt: number, -- when it last made headway
	sprinting: boolean, -- the rider asked to sprint; it only speeds the golem while they steer
	nextMountChange: number,
	nextSprintChange: number,
	riderGraceUntil: number, -- a new character is exempt from the fall check until it is placed
	nextAttack: number,
	nextMine: number,
	spellReadyAt: { [string]: number },
	magnetUntil: number,
	steer: Vector3,
	lastSteerAt: number,
	steerWindowStart: number,
	steerCount: number,
}

local GolemService = {}

local golems: { [Player]: Golem } = {}

local STEER_TIMEOUT = 0.5 -- stop if the client stops sending
local MAX_STEERS_PER_SECOND = 20
local SPRINT_CHANGE_COOLDOWN = 0.1 -- seconds between sprint on/off requests
local RIDER_SPAWN_GRACE = 3 -- seconds a fresh character may be off the island (it spawns at the SpawnLocation)
local HIP_HEIGHT = 4
local ROOT_SIZE = Vector3.new(6, 8, 4)
local BARE_COLOR = CosmeticLooks.BARE_COLOR
local PET_OFFSET = Vector3.new(-8.5, 3, 1.5) -- beside the left shoulder, at scale 1
local MOUNT_OFFSET = Vector3.new(5, 5.3, 0) -- top of the right shoulder, at scale 1
local RIDER_WELD = "GolemRiderWeld"
local RIDER_GROUP = "GolemRider" -- a carried rider collides with nothing

pcall(function()
	if not PhysicsService:IsCollisionGroupRegistered(RIDER_GROUP) then
		PhysicsService:RegisterCollisionGroup(RIDER_GROUP)
	end
	for _, group in PhysicsService:GetRegisteredCollisionGroups() do
		PhysicsService:CollisionGroupSetCollidable(RIDER_GROUP, group.name, false)
	end
end)

function GolemService.context(player: Player): Stats.Context
	return { passes = PassService.passes(player), now = os.time() }
end

-- The nametag over the golem: "Name's Golem", with a [VIP] tag and the worn title.
local function displayName(player: Player, data: any): string
	local name = player.DisplayName .. "'s Golem"
	local title = Stats.equippedTitle(data)
	if title then
		name ..= " · " .. title
	end
	return if PassService.owns(player, "vip") then "[VIP] " .. name else name
end

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.Massless = true
	return part
end

local function visualKey(player: Player, data: any, stats: Stats.GolemStats): string
	local key = tostring(stats.size)
	for _, slot in Config.SlotOrder do
		key ..= ":" .. (data.golem.parts[slot] or "-")
	end
	if PassService.owns(player, "vip") then
		key ..= ":vip"
	end
	for _, slot in { "skin", "pet", "trail" } do
		key ..= ":" .. (Stats.equippedCosmetic(data, slot) or "-")
	end
	return key
end

-- Whether a tier's slot has uploaded mesh art (see GolemMeshes).
local function hasMeshArt(tier: string, slotName: string): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local golem = assets and assets:FindFirstChild("Golem")
	local folder = golem and golem:FindFirstChild(tier)
	local template = folder and folder:FindFirstChild(slotName)
	return template ~= nil and template:GetAttribute("ReplacesExtras") == true
end

-- Root height above the ground at a golem scale.
local function groundOffsetFor(scale: number): number
	return (HIP_HEIGHT + ROOT_SIZE.Y / 2) * scale
end

-- Makes what a golem keeps for life: the model, its root, humanoid, rider
-- mount and inspect prompt, standing on `ground`, facing `facing`. Its looks
-- come from dress(), which can run again on the same shell.
local function buildShell(
	player: Player,
	stats: Stats.GolemStats,
	ground: Vector3,
	facing: Vector3
): (Model, Humanoid, BasePart, Attachment)
	local s = stats.scale
	local model = Instance.new("Model")
	model.Name = player.Name .. "_Golem"
	model:SetAttribute("OwnerId", player.UserId)

	local root = makePart("HumanoidRootPart", ROOT_SIZE * s, BARE_COLOR, Enum.Material.Slate)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	local position = ground + Vector3.new(0, groundOffsetFor(s), 0)
	root.CFrame = CFrame.lookAt(position, position + Vector3.new(facing.X, 0, facing.Z))
	root.Parent = model
	model.PrimaryPart = root

	-- In the hub, anyone can walk up to a golem and inspect it. The prompt is
	-- only on while the golem is in the hub (see publishHealth).
	local inspect = Instance.new("ProximityPrompt")
	inspect.Name = "InspectPrompt"
	inspect.ActionText = "Inspect"
	inspect.ObjectText = player.DisplayName
	inspect.RequiresLineOfSight = false
	inspect.Enabled = false
	inspect.Parent = root

	-- The rider perches on the right shoulder; dress() moves this with the size.
	local mount = Instance.new("Attachment")
	mount.Name = "RiderMount"
	mount.Parent = root

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.WalkSpeed = stats.walkSpeed
	humanoid.MaxHealth = stats.maxHealth
	humanoid.Health = stats.maxHealth
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	return model, humanoid, root, mount
end

-- Gives a golem shell the look and size for `data` and `stats`, replacing
-- any earlier look. The root, humanoid, mount and anything welded to the
-- root (the rider) stay put; only body parts, pet and trail are swapped.
-- Returns the new ground offset.
local function dress(
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	mount: Attachment,
	player: Player,
	data: any,
	stats: Stats.GolemStats
): number
	local s = stats.scale
	for _, child in model:GetChildren() do
		if child ~= root and not child:IsA("Humanoid") then
			child:Destroy()
		end
	end
	for _, child in root:GetChildren() do
		if child:GetAttribute("Look") then
			child:Destroy()
		end
	end
	-- A new size keeps the feet where they are: the root grows about its
	-- centre, so lift it by the change in hip height. Velocity and facing stay.
	local groundOffset = groundOffsetFor(s)
	local oldOffset = root.Size.Y / ROOT_SIZE.Y * groundOffsetFor(1)
	if root.Size ~= ROOT_SIZE * s then
		root.Size = ROOT_SIZE * s
		root.CFrame = root.CFrame + Vector3.new(0, groundOffset - oldOffset, 0)
	end
	humanoid.HipHeight = HIP_HEIGHT * s
	mount.Position = MOUNT_OFFSET * s
	local inspect = root:FindFirstChild("InspectPrompt")
	if inspect and inspect:IsA("ProximityPrompt") then
		inspect.MaxActivationDistance = Config.Hub.inspectRange * s
	end

	-- Each slot's forged tier sets the color and material of its body parts,
	-- tinted by the equipped skin (looks only, see CosmeticLooks).
	local skinId = Stats.equippedCosmetic(data, "skin")
	local function look(slot: string, shade: number?): (Color3, Enum.Material)
		return CosmeticLooks.partLook(data.golem.parts[slot], shade, skinId)
	end
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x, y, z)
	end
	local V = Vector3.new
	local neon = Enum.Material.Neon
	local RUNE_COLOR = CosmeticLooks.accent(skinId)
	local partAssets: { [string]: { string } } = {}
	local partSlots: { [string]: string } =
		{ LeftLeg = "legs", RightLeg = "legs", Torso = "torso", Head = "core", LeftArm = "armL", RightArm = "armR" }
	for name, slot in partSlots do
		local tier = data.golem.parts[slot]
		if tier then
			partAssets[name] = { "Golem", tier, name }
		elseif hasMeshArt("stone", name) then
			-- An unforged slot wears the stone starter's mesh in the bare colour.
			partAssets[name] = { "Golem", "stone", name }
		end
	end
	local rig = Build.rig(model, root, s, partAssets)
	-- The Wardrobe preview recolors a copy of this model for other skins, so
	-- each body part says which slot it belongs to and its shade, and the
	-- glowing runes say they're runes.
	-- Art pieces inside a part keep their own role: glowing ones follow the
	-- rune colour, and trim (ArtShade) is a darker shade of the slot's look.
	local function tag(part: Part, slot: string, shade: number?): Part
		part:SetAttribute("LookSlot", slot)
		part:SetAttribute("LookShade", shade)
		for _, child in part:GetDescendants() do
			if child:IsA("BasePart") then
				if child:GetAttribute("LookAccent") then
					child.Color = RUNE_COLOR
					continue
				end
				local artShade = child:GetAttribute("ArtShade") :: number?
				local childShade = if artShade then (shade or 1) * artShade else shade
				child:SetAttribute("LookSlot", slot)
				child:SetAttribute("LookShade", childShade)
				if skinId or not data.golem.parts[slot] then
					child.Color, child.Material = look(slot, childShade)
				end
			end
		end
		return part
	end
	-- Mesh art brings its own feet, fists, chest and eyes; the block extras
	-- welded to a part with mesh art are dropped at the end of the build.
	local extras: { BasePart } = {}
	local function extra(owner: BasePart, part: Part): Part
		local art = owner:FindFirstChildWhichIsA("Model")
		if art and art:GetAttribute("ReplacesExtras") then
			table.insert(extras, part)
		end
		return part
	end
	local function accent(part: Part): Part
		part:SetAttribute("LookAccent", true)
		return part
	end

	-- Limbs are Motor6D joints so the client can animate walking and punching.
	for _, side in { -1, 1 } do
		local color, material = look("legs")
		local leg = tag(
			rig.part(if side < 0 then "LeftLeg" else "RightLeg", V(3, 5, 3), at(side * 2, -5.5, 0), color, material),
			"legs"
		)
		rig.joint(root, leg, V(side * 2, -3.2, 0), "Hip", { Kind = "leg", Side = side })
		local footColor = look("legs", 0.8)
		rig.weld(
			leg,
			extra(
				leg,
				tag(rig.part("Foot", V(3.4, 1.2, 3.8), at(side * 2, -7.4, -0.3), footColor, material), "legs", 0.8)
			)
		)
	end

	local torsoColor, torsoMaterial = look("torso")
	local torso = tag(rig.part("Torso", V(7, 7, 4.5), at(0, 1, 0), torsoColor, torsoMaterial), "torso")
	rig.joint(root, torso, V(0, -2.5, 0), "Body", { Kind = "body" })
	local chestColor = look("torso", 0.85)
	rig.weld(
		torso,
		extra(
			torso,
			tag(rig.part("Chest", V(5, 3.6, 0.6), at(0, 2.2, -2.45), chestColor, torsoMaterial), "torso", 0.85)
		)
	)
	rig.weld(
		torso,
		extra(torso, rig.part("Belt", V(7.4, 1, 4.9), at(0, -2, 0), Color3.fromRGB(72, 64, 58), Enum.Material.Slate))
	)
	rig.weld(torso, extra(torso, accent(rig.part("Rune", V(1.6, 1.6, 0.2), at(0, 2.2, -2.8), RUNE_COLOR, neon))))

	local headColor, headMaterial = look("core")
	local head = tag(rig.part("Head", V(4, 3, 3.5), at(0, 6, 0), headColor, headMaterial), "core")
	rig.joint(torso, head, V(0, 4.5, 0), "Neck", { Kind = "head" })
	local browColor = look("core", 0.8)
	rig.weld(
		head,
		extra(head, tag(rig.part("Brow", V(4.4, 0.8, 1), at(0, 7, -1.5), browColor, headMaterial), "core", 0.8))
	)
	rig.weld(head, extra(head, accent(rig.part("EyeL", V(0.8, 0.5, 0.2), at(-0.9, 6.3, -1.8), RUNE_COLOR, neon))))
	rig.weld(head, extra(head, accent(rig.part("EyeR", V(0.8, 0.5, 0.2), at(0.9, 6.3, -1.8), RUNE_COLOR, neon))))

	for _, side in { -1, 1 } do
		local slot = if side < 0 then "armL" else "armR"
		local color, material = look(slot)
		local arm = tag(
			rig.part(if side < 0 then "LeftArm" else "RightArm", V(2.5, 7, 2.5), at(side * 5, 0.5, 0), color, material),
			slot
		)
		rig.joint(torso, arm, V(side * 5, 3.5, 0), "Shoulder", { Kind = "arm", Side = side })
		local capColor = look(slot, 0.85)
		rig.weld(
			arm,
			extra(
				arm,
				tag(rig.part("ShoulderCap", V(3.2, 2, 3.2), at(side * 5, 3.6, 0), capColor, material), slot, 0.85)
			)
		)
		rig.weld(
			arm,
			extra(arm, tag(rig.part("Fist", V(3.2, 3, 3.2), at(side * 5, -3.8, -0.2), color, material), slot))
		)
	end
	for _, part in extras do
		part:Destroy()
	end
	-- A longer stride than the old 7 gives a slower, heavier stomp. LegLength
	-- is hip to sole, which the animator uses to plant the feet.
	model:SetAttribute("Stride", 9 * s)
	model:SetAttribute("LegLength", 4.8 * s)

	-- Pet: floats beside the golem on a "pet" joint the client animates
	-- (bobbing, and a hop when the golem defeats something).
	local petId = Stats.equippedCosmetic(data, "pet")
	if petId then
		local petScale = 1 + (s - 1) * 0.5 -- grows a little with the golem
		local pivot = CFrame.new(PET_OFFSET * s)
		local body, rest = CosmeticLooks.buildPet(petId, model, root.CFrame * pivot, petScale)
		if body then
			body.Name = "Pet"
			for _, part in rest do
				Build.weld(body, part)
			end
			local motor = Build.joint(root, body, pivot, "PetFloat")
			motor:SetAttribute("Kind", "pet")
		end
	end

	-- Trail: a ribbon between two points at the feet.
	local trailId = Stats.equippedCosmetic(data, "trail")
	local trailLook = trailId and Config.Cosmetics[trailId].trail
	if trailLook then
		local footY = -(HIP_HEIGHT + ROOT_SIZE.Y / 2) * s + 0.4
		local left = Instance.new("Attachment")
		left.Name = "TrailLeft"
		left:SetAttribute("Look", true)
		left.Position = Vector3.new(-3 * s, footY, 1 * s)
		left.Parent = root
		local right = Instance.new("Attachment")
		right.Name = "TrailRight"
		right:SetAttribute("Look", true)
		right.Position = Vector3.new(3 * s, footY, 1 * s)
		right.Parent = root
		local trail = Instance.new("Trail")
		trail.Attachment0 = left
		trail.Attachment1 = right
		trail.Color = ColorSequence.new(trailLook.colors[1], trailLook.colors[2])
		trail.Transparency = NumberSequence.new(0.25, 1)
		trail.Lifetime = trailLook.lifetime
		trail.LightEmission = trailLook.glow
		trail.MinLength = 0.2
		trail:SetAttribute("Look", true)
		trail.Parent = root
	end

	-- Clients rescan the joints and reframe the camera when these change.
	model:SetAttribute("Scale", s)
	model:SetAttribute("LookVersion", ((model:GetAttribute("LookVersion") :: number?) or 0) + 1)
	return groundOffset
end

local function publishHealth(golem: Golem)
	golem.player:SetAttribute("GolemHealth", math.floor(golem.hp))
	golem.player:SetAttribute("GolemMaxHealth", golem.stats.maxHealth)
	golem.player:SetAttribute("GolemDowned", golem.downedUntil > 0)
	golem.player:SetAttribute("GolemZone", golem.zoneId)
	golem.model:SetAttribute("Downed", golem.downedUntil > 0)
	golem.model:SetAttribute("FallRecovery", golem.fallRecovery)
	local inspect = golem.root:FindFirstChild("InspectPrompt")
	if inspect and inspect:IsA("ProximityPrompt") then
		inspect.Enabled = golem.zoneId == Config.HubZone
	end
	-- Keep the Humanoid above 0 so Roblox never runs its own death logic.
	golem.humanoid.MaxHealth = golem.stats.maxHealth
	golem.humanoid.Health = math.max(golem.hp, 1)
end

local FLAT = Vector3.new(1, 0, 1)

local function claimPhysics(golem: Golem)
	-- The golem (and a rider welded to it) is simulated by the server.
	pcall(function()
		golem.root:SetNetworkOwner(nil)
	end)
end

-- A carried rider collides with nothing, so it can't fight the golem's
-- physics, and weighs nothing. The original Massless is kept to put back.
local function carryPart(part: Instance, carried: boolean)
	if not part:IsA("BasePart") then
		return
	end
	if carried then
		if part:GetAttribute("RiderMassless") == nil then
			part:SetAttribute("RiderMassless", part.Massless)
		end
		part.Massless = true
		part.CollisionGroup = RIDER_GROUP
	else
		local massless = part:GetAttribute("RiderMassless")
		if massless ~= nil then
			part.Massless = massless == true
			part:SetAttribute("RiderMassless", nil)
		end
		if part.CollisionGroup == RIDER_GROUP then
			part.CollisionGroup = "Default"
		end
	end
end

local function carryCharacter(character: Model, carried: boolean)
	for _, part in character:GetDescendants() do
		carryPart(part, carried)
	end
end

local attachRider: (golem: Golem) -> ()

-- Welds a mounted rider's HumanoidRootPart to the golem's RiderMount. Safe to
-- call any time: it does nothing unless the rider is mounted, alive and in
-- the world, and only refreshes the offset when they are already on. The
-- client blends the rider and camera over (see the client Riding module).
-- The weld lives in the character, so a copy of the golem (the Wardrobe
-- preview) never carries a weld to the real rider.
attachRider = function(golem: Golem)
	local character = golem.player.Character
	if not golem.mounted or not character or not golem.model.Parent or not character:IsDescendantOf(workspace) then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local riderRoot = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not riderRoot or not riderRoot:IsA("BasePart") then
		return
	end
	local weld = golem.rider
	if weld and weld.Part1 == riderRoot and weld.Parent == riderRoot then
		weld.Part0 = golem.root
		weld.C0 = golem.mount.CFrame
		claimPhysics(golem)
		return
	end
	golem.rider = nil
	for _, old in riderRoot:GetChildren() do
		if old.Name == RIDER_WELD then
			old:Destroy()
		end
	end
	carryCharacter(character, true)
	-- The carried rider's Humanoid mustn't balance, walk or jump against the
	-- golem; the client also sets this, and plays the sit (see Riding).
	humanoid.PlatformStand = true
	local newWeld = Instance.new("Weld")
	newWeld.Name = RIDER_WELD
	newWeld.Part0 = golem.root
	newWeld.Part1 = riderRoot
	newWeld.C0 = golem.mount.CFrame
	newWeld.C1 = CFrame.new(0, -Config.Golem.riderSeatHeight, 0)
	newWeld.Parent = riderRoot
	golem.rider = newWeld
	-- Accessories that load after climbing on are carried too.
	local added = character.DescendantAdded:Connect(function(part)
		if golem.rider == newWeld then
			carryPart(part, true)
		end
	end)
	-- Lost without a dismount (the character died or was replaced): forget
	-- it, and put a living rider straight back on.
	newWeld.AncestryChanged:Connect(function()
		if newWeld:IsDescendantOf(workspace) then
			return
		end
		added:Disconnect()
		if golem.rider == newWeld then
			golem.rider = nil
			task.defer(attachRider, golem)
		end
	end)
	claimPhysics(golem)
end

local function detachRider(golem: Golem)
	local weld = golem.rider
	golem.rider = nil -- first, so the weld's own handler doesn't put the rider back
	if weld then
		weld:Destroy()
	end
	local character = golem.player.Character
	if character then
		local riderRoot = character:FindFirstChild("HumanoidRootPart")
		if riderRoot then
			for _, old in riderRoot:GetChildren() do
				if old.Name == RIDER_WELD then
					old:Destroy()
				end
			end
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
		carryCharacter(character, false)
	end
end

local function groundUnder(golem: Golem): Vector3
	return golem.root.Position - Vector3.new(0, golem.groundOffset, 0)
end

-- Rays for finding ground skip golems, enemies, effects and characters.
local function groundParams(): RaycastParams
	local ignore: { Instance } = {}
	for _, name in { "Golems", "Enemies", "Effects", "Relics" } do
		local folder = WorldService.getFolder(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

-- Solid ground `distance` out from `center` in the first of `directions`
-- that has nothing in the way at chest height and a floor near `floorY`.
local function findGround(center: Vector3, floorY: number, directions: { Vector3 }, distance: number): Vector3?
	local params = groundParams()
	local chest = Vector3.new(0, 3, 0)
	local base = Vector3.new(center.X, floorY, center.Z)
	local reach = 6 + distance * 0.5 -- how far up or down the floor may be
	for _, direction in directions do
		local flat = direction * FLAT
		if flat.Magnitude < 0.01 then
			continue
		end
		local target = base + flat.Unit * distance
		if workspace:Raycast(base + chest, target - base, params) then
			continue -- a wall or rock in the way
		end
		local hit = workspace:Raycast(target + Vector3.new(0, reach, 0), Vector3.new(0, -2 * reach, 0), params)
		if hit and hit.Normal.Y > 0.6 then
			return hit.Position
		end
	end
	return nil
end

-- Stands a dismounted rider on solid ground beside their golem: the right
-- side first, then the left, behind and in front, then the same a little
-- further out. With no clear spot at all, at the old spot on the right.
local function placeRiderBeside(golem: Golem)
	local character = golem.player.Character
	if not character or not golem.model.Parent then
		return
	end
	local riderRoot = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local cf = golem.root.CFrame
	local ground = groundUnder(golem)
	local sides = { cf.RightVector, -cf.RightVector, -cf.LookVector, cf.LookVector }
	local distance = Config.Golem.dismountOffset * golem.stats.scale
	local spot = findGround(golem.root.Position, ground.Y, sides, distance)
		or findGround(golem.root.Position, ground.Y, sides, distance * 1.8)
		or ground + cf.RightVector * distance
	local height = 3
	if humanoid and riderRoot and riderRoot:IsA("BasePart") then
		height = math.max(humanoid.HipHeight + riderRoot.Size.Y / 2, 3)
		riderRoot.AssemblyLinearVelocity = Vector3.zero
	end
	local position = spot + Vector3.new(0, height + 0.2, 0)
	character:PivotTo(CFrame.lookAt(position, position + cf.LookVector * FLAT))
end

-- Mounts or dismounts the rider. Dismounted, the golem ignores steering,
-- sprint and spells and plays itself on a leash while the rider walks.
function GolemService.setMounted(golem: Golem, mounted: boolean)
	if golem.mounted == mounted then
		return
	end
	golem.mounted = mounted
	golem.steer = Vector3.zero
	golem.following = false
	if not mounted then
		golem.sprinting = false
		GolemService.applySpeed(golem)
	end
	golem.player:SetAttribute("GolemMounted", mounted)
	if mounted then
		attachRider(golem)
		return
	end
	detachRider(golem)
	placeRiderBeside(golem)
end

-- Whether the rider is alive and standing close enough to climb on.
function GolemService.canClimbOn(golem: Golem): boolean
	local character = golem.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local riderRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not riderRoot or not riderRoot:IsA("BasePart") then
		return false
	end
	local reach = Config.Golem.mountRange * golem.stats.scale
	return ((riderRoot.Position - golem.root.Position) * FLAT).Magnitude <= reach
end

local function onMount(player: Player, wantMounted: any)
	local golem = golems[player]
	if not golem or type(wantMounted) ~= "boolean" or not GolemService.isActive(golem) then
		return
	end
	local now = os.clock()
	if wantMounted == golem.mounted or now < golem.nextMountChange then
		return
	end
	golem.nextMountChange = now + Config.Golem.mountCooldown
	if wantMounted and not GolemService.canClimbOn(golem) then
		Remotes.Notify:FireClient(player, "message", "Walk up to your golem to climb on.")
		return
	end
	GolemService.setMounted(golem, wantMounted)
end

-- Gives the golem its new look or size on the same model. Nothing the rider
-- is welded to, and nothing the camera or the game state points at, is
-- replaced, so the rider stays on through any number of forge upgrades,
-- cosmetics and mesh-art loads: no drop, camera snap or sprint reset. (The
-- old rebuild made a new model, moved the rider across with Seat:Sit() and
-- destroyed the old seat. The rider's sitting state belongs to their client,
-- which then saw its seat vanish and could stand up, dropping them until the
-- 0.5 s reseat. A rebuild also teleported the old golem along with its rider.)
local function restyle(golem: Golem, data: any)
	golem.groundOffset = dress(golem.model, golem.root, golem.humanoid, golem.mount, golem.player, data, golem.stats)
	if golem.rider then
		golem.rider.C0 = golem.mount.CFrame -- a new size moves the shoulder
	end
	claimPhysics(golem)
	publishHealth(golem)
end

-- Recalculates stats after any data change; restyles the model if it looks different.
function GolemService.refresh(player: Player)
	local golem = golems[player]
	local data = DataService.get(player)
	if not golem or not data then
		return
	end
	local oldMax = golem.stats.maxHealth
	golem.stats = Stats.compute(data, GolemService.context(player))
	if golem.stats.maxHealth > oldMax and golem.downedUntil == 0 then
		golem.hp += golem.stats.maxHealth - oldMax
	end
	golem.hp = math.min(golem.hp, golem.stats.maxHealth)
	GolemService.applySpeed(golem)
	golem.humanoid.DisplayName = displayName(player, data)

	local key = visualKey(player, data, golem.stats)
	if key ~= golem.visualKey then
		golem.visualKey = key
		restyle(golem, data)
	else
		publishHealth(golem)
	end
end

local function spawnGolem(player: Player)
	local data = DataService.get(player)
	if golems[player] or not data then
		return
	end
	local zoneId = 1
	local stats = Stats.compute(data, GolemService.context(player))
	local model, humanoid, root, mount =
		buildShell(player, stats, WorldService.getSpawnPoint(zoneId), Vector3.new(0, 0, -1))
	local groundOffset = dress(model, root, humanoid, mount, player, data, stats)
	humanoid.DisplayName = displayName(player, data)
	model.Parent = WorldService.getFolder("Golems")
	-- A new session starts on the golem, as it always has: riding is the game.
	local golem: Golem = {
		player = player,
		model = model,
		humanoid = humanoid,
		root = root,
		mount = mount,
		rider = nil,
		groundOffset = groundOffset,
		visualKey = visualKey(player, data, stats),
		stats = stats,
		zoneId = zoneId,
		hp = stats.maxHealth,
		downedUntil = 0,
		fallRecovery = false,
		mounted = true,
		following = false,
		followFrom = Vector3.zero,
		followProgressAt = 0,
		sprinting = false,
		nextMountChange = 0,
		nextSprintChange = 0,
		riderGraceUntil = 0,
		nextAttack = 0,
		nextMine = 0,
		spellReadyAt = {},
		magnetUntil = 0,
		steer = Vector3.zero,
		lastSteerAt = 0,
		steerWindowStart = 0,
		steerCount = 0,
	}
	golems[player] = golem
	claimPhysics(golem)
	player:SetAttribute("GolemMounted", true)
	player:SetAttribute("GolemSprint", false)
	publishHealth(golem)

	local function placeRider()
		if golem.mounted then
			attachRider(golem)
		else
			placeRiderBeside(golem)
		end
	end
	player.CharacterAdded:Connect(function(character)
		-- The character spawns at the place's SpawnLocation, far below the
		-- island. Don't let the fall check kill it before it is placed.
		golem.riderGraceUntil = os.clock() + RIDER_SPAWN_GRACE
		character:WaitForChild("Humanoid")
		character:WaitForChild("HumanoidRootPart")
		placeRider()
		task.wait(0.2)
		placeRider() -- the first try can come before the character is in the world; both are idempotent
	end)
	if player.Character then
		attachRider(golem)
	end
end

local function onSteer(player: Player, direction: any)
	local golem = golems[player]
	if not golem or typeof(direction) ~= "Vector3" then
		return
	end
	local now = os.clock()
	if now - golem.steerWindowStart >= 1 then
		golem.steerWindowStart = now
		golem.steerCount = 0
	end
	golem.steerCount += 1
	if golem.steerCount > MAX_STEERS_PER_SECOND then
		return
	end
	-- Reject NaN/inf, flatten, clamp to unit length.
	if not golem.mounted then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.X ~= flat.X or flat.Z ~= flat.Z or flat.Magnitude == math.huge then
		return
	end
	if flat.Magnitude > 1 then
		flat = flat.Unit
	end
	golem.steer = flat
	golem.lastSteerAt = now
end

function GolemService.get(player: Player): Golem?
	return golems[player]
end

function GolemService.all(): { [Player]: Golem }
	return golems
end

-- Walk speed for this tick: sprinting only counts for a mounted rider who is
-- steering, so a golem playing itself never sprints. The Sprinting attribute
-- tells clients to lengthen the stride (see the client Animator).
function GolemService.applySpeed(golem: Golem)
	local sprinting = golem.sprinting and GolemService.getSteer(golem).Magnitude > 0
	local speed = golem.stats.walkSpeed * (if sprinting then Config.Golem.sprintMult else 1)
	if golem.humanoid.WalkSpeed ~= speed then
		golem.humanoid.WalkSpeed = speed
	end
	if golem.model:GetAttribute("Sprinting") ~= sprinting then
		golem.model:SetAttribute("Sprinting", sprinting)
	end
	-- What the server will honour, so the client can tell its request was dropped.
	golem.player:SetAttribute("GolemSprint", golem.sprinting)
end

function GolemService.setSprinting(golem: Golem, sprinting: boolean)
	golem.sprinting = sprinting and golem.mounted
	GolemService.applySpeed(golem)
end

-- A rider's sprint request. Returns whether it changed anything. Requests
-- inside the cooldown are dropped; the client sees GolemSprint disagree with
-- what it wants and asks again, so a quick tap never leaves them out of step.
function GolemService.requestSprint(golem: Golem, wantSprint: any): boolean
	if type(wantSprint) ~= "boolean" or wantSprint == golem.sprinting then
		return false
	end
	local now = os.clock()
	if now < golem.nextSprintChange then
		return false
	end
	golem.nextSprintChange = now + SPRINT_CHANGE_COOLDOWN
	GolemService.setSprinting(golem, wantSprint)
	return golem.sprinting == wantSprint
end

local function onSprint(player: Player, wantSprint: any)
	local golem = golems[player]
	if golem then
		GolemService.requestSprint(golem, wantSprint)
	end
end

function GolemService.isActive(golem: Golem): boolean
	return golem.downedUntil == 0 and golem.model.Parent ~= nil
end

-- The dismounted leash. The golem is tied to its rider while they are alive
-- and in the world; with no rider to follow (mounted, dead, respawning) there
-- is no leash.
function GolemService.leashCenter(golem: Golem): Vector3?
	if golem.mounted then
		return nil
	end
	local character = golem.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local riderRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not riderRoot or not riderRoot:IsA("BasePart") then
		return nil
	end
	if os.clock() < golem.riderGraceUntil then
		return nil -- a new character is still being moved over from the SpawnLocation
	end
	return riderRoot.Position
end

function GolemService.leashRadius(golem: Golem): number
	return Config.Golem.followRadius * golem.stats.scale
end

-- Whether a dismounted golem may go to `position` to fight or mine.
function GolemService.inLeash(golem: Golem, position: Vector3): boolean
	local center = GolemService.leashCenter(golem)
	return center == nil or ((position - center) * FLAT).Magnitude <= GolemService.leashRadius(golem)
end

-- Puffs the golem back beside its rider (clients play the puff, see Fx).
-- Waits, returning false, while the rider is in the air or there's no room.
local function puffToRider(golem: Golem, center: Vector3): boolean
	local character = golem.player.Character
	local riderRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not riderRoot or not riderRoot:IsA("BasePart") or WorldService.zoneAt(center) ~= golem.zoneId then
		return false
	end
	local floor = workspace:Raycast(center, Vector3.new(0, -12, 0), groundParams())
	if not floor then
		return false
	end
	local cf = riderRoot.CFrame
	local spot = findGround(
		center,
		floor.Position.Y,
		{ -cf.LookVector, cf.RightVector, -cf.RightVector, cf.LookVector },
		Config.Golem.dismountOffset * golem.stats.scale
	)
	if not spot then
		return false
	end
	local from = groundUnder(golem)
	local position = spot + Vector3.new(0, golem.groundOffset, 0)
	local facing = (center - spot) * FLAT
	if facing.Magnitude < 0.01 then
		facing = cf.LookVector * FLAT
	end
	golem.humanoid:Move(Vector3.zero)
	golem.model:PivotTo(CFrame.lookAt(position, position + facing))
	golem.root.AssemblyLinearVelocity = Vector3.zero
	golem.root.AssemblyAngularVelocity = Vector3.zero
	golem.following = false
	Remotes.Notify:FireAllClients("golemPuff", from, golem.stats.scale, golem.player.UserId)
	Remotes.Notify:FireAllClients("golemPuff", spot, golem.stats.scale, golem.player.UserId)
	return true
end

-- Keeps a dismounted golem near its rider. Inside the radius it is free to
-- fight and mine (CombatService); outside it walks back until it is well
-- inside, so it doesn't jitter on the edge. Very far away, or stuck for a
-- few seconds, it puffs back beside the rider (on the golem's own island). Returns true while it is
-- walking back, when it should do nothing else.
function GolemService.followRider(golem: Golem, now: number): boolean
	local center = GolemService.leashCenter(golem)
	if not center then
		golem.following = false
		return false
	end
	local scale = golem.stats.scale
	local radius = GolemService.leashRadius(golem)
	local offset = (golem.root.Position - center) * FLAT
	local distance = offset.Magnitude
	if distance > Config.Golem.leashTeleportRadius * scale and puffToRider(golem, center) then
		return false
	end
	if golem.following then
		if distance < radius * Config.Golem.followStop then
			golem.following = false
			return false
		end
	elseif distance > radius then
		golem.following = true
		golem.followFrom = golem.root.Position
		golem.followProgressAt = now
	else
		return false
	end
	-- Stuck means the golem itself isn't getting anywhere (under about a
	-- stud a second), not that a faster rider is pulling ahead.
	if ((golem.root.Position - golem.followFrom) * FLAT).Magnitude >= Config.Golem.stuckTime then
		golem.followFrom = golem.root.Position
		golem.followProgressAt = now
	elseif now - golem.followProgressAt > Config.Golem.stuckTime then
		if puffToRider(golem, center) then
			return false
		end
		golem.followProgressAt = now -- no room to puff yet; try again later
	end
	golem.humanoid:MoveTo(center + offset.Unit * radius * 0.3)
	return true
end

-- The player's current steering, or zero if they've let go.
function GolemService.getSteer(golem: Golem): Vector3
	if not golem.mounted or os.clock() - golem.lastSteerAt > STEER_TIMEOUT then
		return Vector3.zero
	end
	return golem.steer
end

-- Moves the golem to a zone's spawn point.
function GolemService.sendToZone(golem: Golem, zoneId: number)
	golem.zoneId = zoneId
	golem.humanoid:Move(Vector3.zero)
	local spread = if zoneId == Config.HubZone then Config.Hub.spread else 10
	local spawn = WorldService.getSpawnPoint(zoneId)
		+ Vector3.new(math.random(-spread, spread), 0, math.random(-spread, spread))
	golem.model:PivotTo(CFrame.new(spawn + Vector3.new(0, golem.groundOffset, 0)))
	-- Teleporting doesn't discard falling momentum. Stop the whole assembly
	-- so a fall can't carry the golem straight through its recovery spawn.
	golem.root.AssemblyLinearVelocity = Vector3.zero
	golem.root.AssemblyAngularVelocity = Vector3.zero
	if not golem.mounted then
		placeRiderBeside(golem) -- a walking rider travels with their golem
	end
	publishHealth(golem)
end

function GolemService.heal(golem: Golem, amount: number)
	if not GolemService.isActive(golem) then
		return
	end
	golem.hp = math.min(golem.hp + amount, golem.stats.maxHealth)
	publishHealth(golem)
end

function GolemService.damage(golem: Golem, amount: number)
	if not GolemService.isActive(golem) then
		return
	end
	golem.hp = math.max(golem.hp - amount, 0)
	golem.model:SetAttribute("Hit", ((golem.model:GetAttribute("Hit") :: number?) or 0) + 1)
	if golem.hp <= 0 then
		-- Knocked out: carried back to the zone spawn to recover.
		golem.downedUntil = os.clock() + Config.Golem.respawnTime
		golem.sprinting = false
		GolemService.applySpeed(golem)
		GolemService.sendToZone(golem, golem.zoneId)
		Remotes.Notify:FireClient(golem.player, "message", "Your golem crumbled! Reforming...")
	end
	publishHealth(golem)
end

-- Called every server tick by CombatService.
function GolemService.update(golem: Golem, dt: number)
	local now = os.clock()
	local surface = WorldService.getSurfaceY(golem.zoneId) - Config.Golem.fallDepth
	local character = golem.player.Character
	local rider = character and character:FindFirstChildOfClass("Humanoid")
	local riderRoot = character and character:FindFirstChild("HumanoidRootPart")
	local riderFell = rider ~= nil
		and now >= golem.riderGraceUntil
		and rider.Health > 0
		and riderRoot ~= nil
		and riderRoot:IsA("BasePart")
		and riderRoot.Position.Y - rider.HipHeight - riderRoot.Size.Y / 2 < surface
	if riderFell and rider then
		-- A detached character can fall while its golem is still on land.
		-- Kill that character immediately too; Roblox will respawn the rider.
		rider.Health = 0
		if not golem.mounted then
			riderFell = false -- a walking rider's own fall doesn't cost the golem
		end
	end
	if golem.downedUntil > 0 then
		if now >= golem.downedUntil then
			golem.downedUntil = 0
			golem.fallRecovery = false
			golem.hp = golem.stats.maxHealth
			publishHealth(golem)
		end
		return
	end

	-- Use foot height so every golem size hits the same kill plane. Falling
	-- is a real knock-out, with the normal recovery time, not a free heal.
	if riderFell or groundUnder(golem).Y < surface then
		golem.fallRecovery = true
		golem.model:SetAttribute("FallPosition", golem.root.Position)
		GolemService.damage(golem, golem.hp)
		return
	end

	GolemService.applySpeed(golem)

	if golem.hp < golem.stats.maxHealth then
		golem.hp = math.min(golem.hp + golem.stats.regenPerSecond * dt, golem.stats.maxHealth)
		publishHealth(golem)
	end
end

function GolemService.start()
	DataService.ProfileLoaded:Connect(spawnGolem)
	DataService.Changed:Connect(GolemService.refresh)
	Remotes.MoveGolem.OnServerEvent:Connect(onSteer)
	Remotes.MountGolem.OnServerEvent:Connect(onMount)
	Remotes.SprintGolem.OnServerEvent:Connect(onSprint)
	-- Uploaded mesh art loads in the background, a tier at a time; restyle
	-- golems that wear that tier (unforged slots wear stone) once it arrives.
	GolemMeshes.install(function(tier)
		for player, golem in golems do
			local data = DataService.get(player)
			if not data then
				continue
			end
			for _, slot in Config.SlotOrder do
				local worn = data.golem.parts[slot] or "stone"
				if worn == tier then
					golem.visualKey = ""
					GolemService.refresh(player)
					break
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local golem = golems[player]
		if golem then
			golem.model:Destroy()
			golems[player] = nil
		end
	end)
end

return GolemService
