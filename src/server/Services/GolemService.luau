--!strict
-- Owns each player's golem: building the model from its parts and size,
-- seating the rider, health, knock-outs, travel, and the steering intent sent
-- by the client. The golem is server-owned so its position can't be spoofed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local WorldService = require(script.Parent.WorldService)

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
local BARE_COLOR = Color3.fromRGB(110, 104, 96) -- a slot with no forged part
local RUNE_COLOR = Color3.fromRGB(90, 200, 255)

-- Slot -> body pieces, as (size, offset) at scale 1.
local PIECES: { [string]: { { name: string, size: Vector3, offset: Vector3 } } } = {
	core = { { name = "Head", size = Vector3.new(4, 3, 3.5), offset = Vector3.new(0, 6, 0) } },
	torso = { { name = "Torso", size = Vector3.new(7, 7, 4.5), offset = Vector3.new(0, 1, 0) } },
	armL = { { name = "LeftArm", size = Vector3.new(2.5, 7, 2.5), offset = Vector3.new(-5, 0.5, 0) } },
	armR = { { name = "RightArm", size = Vector3.new(2.5, 7, 2.5), offset = Vector3.new(5, 0.5, 0) } },
	legs = {
		{ name = "LeftLeg", size = Vector3.new(3, 5, 3), offset = Vector3.new(-2, -5.5, 0) },
		{ name = "RightLeg", size = Vector3.new(3, 5, 3), offset = Vector3.new(2, -5.5, 0) },
	},
}

function GolemService.context(player: Player): Stats.Context
	return { passes = PassService.passes(player), now = os.time() }
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
	return key
end

-- Builds the golem standing on `ground`, facing `look`.
local function buildModel(player: Player, data: any, stats: Stats.GolemStats, ground: Vector3, look: Vector3): (Model, Humanoid, BasePart, Seat, number)
	local s = stats.scale
	local model = Instance.new("Model")
	model.Name = player.Name .. "_Golem"

	local groundOffset = (HIP_HEIGHT + ROOT_SIZE.Y / 2) * s
	local root = makePart("HumanoidRootPart", ROOT_SIZE * s, BARE_COLOR, Enum.Material.Slate)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	local position = ground + Vector3.new(0, groundOffset, 0)
	root.CFrame = CFrame.lookAt(position, position + Vector3.new(look.X, 0, look.Z))
	root.Parent = model
	model.PrimaryPart = root

	for _, slot in Config.SlotOrder do
		local tierId = data.golem.parts[slot]
		local tier = tierId and Config.Tiers[tierId]
		local color = if tier then tier.color else BARE_COLOR
		local material = if tier then tier.material else Enum.Material.Slate
		for _, piece in PIECES[slot] do
			attach(root, makePart(piece.name, piece.size * s, color, material), CFrame.new(piece.offset * s), model)
		end
	end

	-- Glowing eyes and chest rune give the golem a readable "front".
	local neon = Enum.Material.Neon
	attach(root, makePart("EyeL", Vector3.new(0.8, 0.5, 0.2) * s, RUNE_COLOR, neon), CFrame.new(Vector3.new(-0.9, 6.3, -1.8) * s), model)
	attach(root, makePart("EyeR", Vector3.new(0.8, 0.5, 0.2) * s, RUNE_COLOR, neon), CFrame.new(Vector3.new(0.9, 6.3, -1.8) * s), model)
	attach(root, makePart("Rune", Vector3.new(1.6, 1.6, 0.2) * s, RUNE_COLOR, neon), CFrame.new(Vector3.new(0, 2, -2.3) * s), model)

	-- The rider sits on the right shoulder.
	local seat = Instance.new("Seat")
	seat.Name = "ShoulderSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	attach(root, seat, CFrame.new(Vector3.new(5, 4, 0) * s + Vector3.new(0, 0.5, 0)), model)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = HIP_HEIGHT * s
	humanoid.WalkSpeed = stats.walkSpeed
	humanoid.MaxHealth = stats.maxHealth
	humanoid.Health = stats.maxHealth
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	local name = player.DisplayName .. "'s Golem"
	humanoid.DisplayName = if PassService.owns(player, "vip") then "[VIP] " .. name else name
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

-- Rebuilds the model in place (new parts or a new size).
local function rebuild(golem: Golem, data: any)
	local ground = groundUnder(golem)
	local look = golem.root.CFrame.LookVector
	local oldModel = golem.model
	local model, humanoid, root, seat, groundOffset = buildModel(golem.player, data, golem.stats, ground, look)
	golem.model, golem.humanoid, golem.root, golem.seat, golem.groundOffset = model, humanoid, root, seat, groundOffset
	hookSeat(golem, seat)
	oldModel:Destroy()
	publishHealth(golem)
	seatRider(golem)
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
	local spawn = WorldService.getSpawnPoint(zoneId) + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
	golem.model:PivotTo(CFrame.new(spawn + Vector3.new(0, golem.groundOffset, 0)))
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

	-- Fell off the island: put it back at the spawn.
	if golem.root.Position.Y < WorldService.getSurfaceY(golem.zoneId) - 40 then
		GolemService.sendToZone(golem, golem.zoneId)
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
	Players.PlayerRemoving:Connect(function(player)
		local golem = golems[player]
		if golem then
			golem.model:Destroy()
			golems[player] = nil
		end
	end)
end

return GolemService
