--!strict
-- Owns each player's golem: building the placeholder model, seating the
-- rider, health, knock-outs, and the steering intent sent by the client.
-- The golem is server-owned so its position can't be spoofed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

export type Golem = {
	player: Player,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	seat: Seat,
	zoneId: number,
	hp: number,
	maxHp: number,
	downedUntil: number, -- 0 when standing
	nextAttack: number,
	nextMine: number,
	spellReadyAt: { [string]: number },
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
local STONE_COLOR = Color3.fromRGB(128, 122, 110)
local RUNE_COLOR = Color3.fromRGB(90, 200, 255)

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

local function buildModel(player: Player, at: Vector3): (Model, Humanoid, BasePart, Seat)
	local model = Instance.new("Model")
	model.Name = player.Name .. "_Golem"

	local root = makePart("HumanoidRootPart", ROOT_SIZE, STONE_COLOR, Enum.Material.Slate)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.CFrame = CFrame.new(at + Vector3.new(0, HIP_HEIGHT + ROOT_SIZE.Y / 2, 0))
	root.Parent = model
	model.PrimaryPart = root

	local slate = Enum.Material.Slate
	attach(root, makePart("Torso", Vector3.new(7, 7, 4.5), STONE_COLOR, slate), CFrame.new(0, 1, 0), model)
	attach(root, makePart("Head", Vector3.new(4, 3, 3.5), STONE_COLOR, slate), CFrame.new(0, 6, 0), model)
	attach(root, makePart("LeftArm", Vector3.new(2.5, 7, 2.5), STONE_COLOR, slate), CFrame.new(-5, 0.5, 0), model)
	attach(root, makePart("RightArm", Vector3.new(2.5, 7, 2.5), STONE_COLOR, slate), CFrame.new(5, 0.5, 0), model)
	attach(root, makePart("LeftLeg", Vector3.new(3, 5, 3), STONE_COLOR, slate), CFrame.new(-2, -5.5, 0), model)
	attach(root, makePart("RightLeg", Vector3.new(3, 5, 3), STONE_COLOR, slate), CFrame.new(2, -5.5, 0), model)

	-- Glowing eyes and chest rune so the golem has a readable "front".
	local neon = Enum.Material.Neon
	attach(root, makePart("EyeL", Vector3.new(0.8, 0.5, 0.2), RUNE_COLOR, neon), CFrame.new(-0.9, 6.3, -1.8), model)
	attach(root, makePart("EyeR", Vector3.new(0.8, 0.5, 0.2), RUNE_COLOR, neon), CFrame.new(0.9, 6.3, -1.8), model)
	attach(root, makePart("Rune", Vector3.new(1.6, 1.6, 0.2), RUNE_COLOR, neon), CFrame.new(0, 2, -2.3), model)

	-- The rider sits on the right shoulder.
	local seat = Instance.new("Seat")
	seat.Name = "ShoulderSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	attach(root, seat, CFrame.new(5, 4.5, 0), model)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = HIP_HEIGHT
	humanoid.WalkSpeed = Config.Golem.walkSpeed
	humanoid.MaxHealth = Config.Golem.maxHealth
	humanoid.Health = Config.Golem.maxHealth
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayName = player.DisplayName .. "'s Golem"
	humanoid.Parent = model
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	model.Parent = WorldService.getFolder("Golems")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return model, humanoid, root, seat
end

local function publishHealth(golem: Golem)
	golem.player:SetAttribute("GolemHealth", math.floor(golem.hp))
	golem.player:SetAttribute("GolemMaxHealth", golem.maxHp)
	golem.player:SetAttribute("GolemDowned", golem.downedUntil > 0)
	-- Keep the Humanoid above 0 so Roblox never runs its own death logic.
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

local function spawnGolem(player: Player)
	if golems[player] or not DataService.get(player) then
		return
	end
	local zoneId = 1
	local model, humanoid, root, seat = buildModel(player, WorldService.getSpawnPoint(zoneId))
	local golem: Golem = {
		player = player,
		model = model,
		humanoid = humanoid,
		root = root,
		seat = seat,
		zoneId = zoneId,
		hp = Config.Golem.maxHealth,
		maxHp = Config.Golem.maxHealth,
		downedUntil = 0,
		nextAttack = 0,
		nextMine = 0,
		spellReadyAt = {},
		steer = Vector3.zero,
		lastSteerAt = 0,
		steerWindowStart = 0,
		steerCount = 0,
	}
	golems[player] = golem
	publishHealth(golem)

	-- Put the rider back if they get knocked off.
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant == nil then
			task.delay(0.5, seatRider, golem)
		end
	end)
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
	-- Rate limit.
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

function GolemService.damage(golem: Golem, amount: number)
	if not GolemService.isActive(golem) then
		return
	end
	golem.hp = math.max(golem.hp - amount, 0)
	if golem.hp <= 0 then
		-- Knocked out: carried back to the zone spawn to recover.
		golem.downedUntil = os.clock() + Config.Golem.respawnTime
		golem.humanoid:Move(Vector3.zero)
		golem.model:PivotTo(CFrame.new(WorldService.getSpawnPoint(golem.zoneId) + Vector3.new(0, HIP_HEIGHT + ROOT_SIZE.Y / 2, 0)))
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
			golem.hp = golem.maxHp
			publishHealth(golem)
		end
		return
	end

	-- Fell off the island: put it back at the spawn.
	if golem.root.Position.Y < WorldService.getSurfaceY(golem.zoneId) - 40 then
		golem.model:PivotTo(CFrame.new(WorldService.getSpawnPoint(golem.zoneId) + Vector3.new(0, HIP_HEIGHT + ROOT_SIZE.Y / 2, 0)))
	end

	if golem.hp < golem.maxHp then
		golem.hp = math.min(golem.hp + Config.Golem.regenPerSecond * dt, golem.maxHp)
		publishHealth(golem)
	end
end

function GolemService.start()
	DataService.ProfileLoaded:Connect(spawnGolem)
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
