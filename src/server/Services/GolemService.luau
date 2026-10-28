--!strict
-- Owns each player's golem: building the model from its parts and size,
-- seating the rider, health, knock-outs, travel, and the steering intent sent
-- by the client. The golem is server-owned so its position can't be spoofed.

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
	seat: Seat,
	groundOffset: number, -- root height above the ground
	visualKey: string,
	stats: Stats.GolemStats,
	zoneId: number,
	hp: number,
	downedUntil: number, -- 0 when standing
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
local HIP_HEIGHT = 4
local ROOT_SIZE = Vector3.new(6, 8, 4)
local BARE_COLOR = CosmeticLooks.BARE_COLOR
local PET_OFFSET = Vector3.new(-8.5, 3, 1.5) -- beside the left shoulder, at scale 1

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

local function attach(root: BasePart, part: BasePart, offset: CFrame, model: Model)
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
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

-- Builds the golem standing on `ground`, facing `facing`.
local function buildModel(
	player: Player,
	data: any,
	stats: Stats.GolemStats,
	ground: Vector3,
	facing: Vector3
): (Model, Humanoid, BasePart, Seat, number)
	local s = stats.scale
	local model = Instance.new("Model")
	model.Name = player.Name .. "_Golem"

	local groundOffset = (HIP_HEIGHT + ROOT_SIZE.Y / 2) * s
	local root = makePart("HumanoidRootPart", ROOT_SIZE * s, BARE_COLOR, Enum.Material.Slate)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	local position = ground + Vector3.new(0, groundOffset, 0)
	root.CFrame = CFrame.lookAt(position, position + Vector3.new(facing.X, 0, facing.Z))
	root.Parent = model
	model.PrimaryPart = root

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
		left.Position = Vector3.new(-3 * s, footY, 1 * s)
		left.Parent = root
		local right = Instance.new("Attachment")
		right.Name = "TrailRight"
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
		trail.Parent = root
	end

	-- In the hub, anyone can walk up to a golem and inspect it. The prompt is
	-- only on while the golem is in the hub (see publishHealth).
	local inspect = Instance.new("ProximityPrompt")
	inspect.Name = "InspectPrompt"
	inspect.ActionText = "Inspect"
	inspect.ObjectText = player.DisplayName
	inspect.MaxActivationDistance = Config.Hub.inspectRange * s
	inspect.RequiresLineOfSight = false
	inspect.Enabled = false
	inspect.Parent = root

	-- The rider sits on the right shoulder.
	local seat = Instance.new("Seat")
	seat.Name = "ShoulderSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	attach(root, seat, CFrame.new(Vector3.new(5, 4.8, 0) * s + Vector3.new(0, 0.5, 0)), model)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = HIP_HEIGHT * s
	humanoid.WalkSpeed = stats.walkSpeed
	humanoid.MaxHealth = stats.maxHealth
	humanoid.Health = stats.maxHealth
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayName = displayName(player, data)
	humanoid.Parent = model
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	model.Parent = WorldService.getFolder("Golems")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return model, humanoid, root, seat, groundOffset
end

local function publishHealth(golem: Golem)
	golem.player:SetAttribute("GolemHealth", math.floor(golem.hp))
	golem.player:SetAttribute("GolemMaxHealth", golem.stats.maxHealth)
	golem.player:SetAttribute("GolemDowned", golem.downedUntil > 0)
	golem.player:SetAttribute("GolemZone", golem.zoneId)
	golem.model:SetAttribute("Downed", golem.downedUntil > 0)
	local inspect = golem.root:FindFirstChild("InspectPrompt")
	if inspect and inspect:IsA("ProximityPrompt") then
		inspect.Enabled = golem.zoneId == Config.HubZone
	end
	-- Keep the Humanoid above 0 so Roblox never runs its own death logic.
	golem.humanoid.MaxHealth = golem.stats.maxHealth
	golem.humanoid.Health = math.max(golem.hp, 1)
end

local function seatRider(golem: Golem)
	local character = golem.player.Character
	if not character or not golem.model.Parent then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or golem.seat.Occupant == humanoid then
		return
	end
	character:PivotTo(golem.seat.CFrame * CFrame.new(0, 3, 0))
	golem.seat:Sit(humanoid)
	task.defer(function()
		pcall(function()
			golem.root:SetNetworkOwner(nil)
		end)
	end)
end

local function hookSeat(golem: Golem, seat: Seat)
	-- Put the rider back if they get knocked off.
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant == nil and golem.seat == seat then
			task.delay(0.5, seatRider, golem)
		end
	end)
end

local function groundUnder(golem: Golem): Vector3
	return golem.root.Position - Vector3.new(0, golem.groundOffset, 0)
end

-- Rebuilds the model in place (new parts or a new size). Seats the rider on
-- the new model before tearing down the old one: Seat:Sit() on a different
-- seat moves the humanoid's weld directly, seat to seat, with no gap where
-- gravity could take over. Destroying the old (by then unoccupied) seat
-- first would otherwise drop the rider for a frame before seatRider() got a
-- chance to teleport them back, which is what "booted off the golem" was.
local function rebuild(golem: Golem, data: any)
	local ground = groundUnder(golem)
	local look = golem.root.CFrame.LookVector
	local oldModel = golem.model
	local model, humanoid, root, seat, groundOffset = buildModel(golem.player, data, golem.stats, ground, look)
	golem.model, golem.humanoid, golem.root, golem.seat, golem.groundOffset = model, humanoid, root, seat, groundOffset
	hookSeat(golem, seat)
	seatRider(golem)
	oldModel:Destroy()
	publishHealth(golem)
end

-- Recalculates stats after any data change; rebuilds the model if it looks different.
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
	golem.humanoid.WalkSpeed = golem.stats.walkSpeed
	golem.humanoid.DisplayName = displayName(player, data)

	local key = visualKey(player, data, golem.stats)
	if key ~= golem.visualKey then
		golem.visualKey = key
		rebuild(golem, data)
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
	local model, humanoid, root, seat, groundOffset =
		buildModel(player, data, stats, WorldService.getSpawnPoint(zoneId), Vector3.new(0, 0, -1))
	local golem: Golem = {
		player = player,
		model = model,
		humanoid = humanoid,
		root = root,
		seat = seat,
		groundOffset = groundOffset,
		visualKey = visualKey(player, data, stats),
		stats = stats,
		zoneId = zoneId,
		hp = stats.maxHealth,
		downedUntil = 0,
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
	hookSeat(golem, seat)
	publishHealth(golem)

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		character:WaitForChild("HumanoidRootPart")
		task.wait(0.2)
		seatRider(golem)
	end)
	if player.Character then
		seatRider(golem)
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

function GolemService.isActive(golem: Golem): boolean
	return golem.downedUntil == 0 and golem.model.Parent ~= nil
end

-- The player's current steering, or zero if they've let go.
function GolemService.getSteer(golem: Golem): Vector3
	if os.clock() - golem.lastSteerAt > STEER_TIMEOUT then
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
		GolemService.sendToZone(golem, golem.zoneId)
		Remotes.Notify:FireClient(golem.player, "message", "Your golem crumbled! Reforming...")
	end
	publishHealth(golem)
end

-- Called every server tick by CombatService.
function GolemService.update(golem: Golem, dt: number)
	local now = os.clock()
	if golem.downedUntil > 0 then
		if now >= golem.downedUntil then
			golem.downedUntil = 0
			golem.hp = golem.stats.maxHealth
			publishHealth(golem)
		end
		return
	end

	-- Use foot height so every golem size hits the same kill plane. Falling
	-- is a real knock-out, with the normal recovery time, not a free heal.
	if groundUnder(golem).Y < WorldService.getSurfaceY(golem.zoneId) - Config.Golem.fallDepth then
		GolemService.damage(golem, golem.hp)
		return
	end

	if golem.hp < golem.stats.maxHealth then
		golem.hp = math.min(golem.hp + golem.stats.regenPerSecond * dt, golem.stats.maxHealth)
		publishHealth(golem)
	end
end

function GolemService.start()
	DataService.ProfileLoaded:Connect(spawnGolem)
	DataService.Changed:Connect(GolemService.refresh)
	Remotes.MoveGolem.OnServerEvent:Connect(onSteer)
	-- Uploaded mesh art loads in the background, a tier at a time; rebuild
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
