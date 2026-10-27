--!strict
-- Spawns enemy waves in each zone, runs their simple chase-and-hit AI,
-- and pays out rewards when a golem defeats one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent.DataService)
local GolemService = require(script.Parent.GolemService)
local WorldService = require(script.Parent.WorldService)

export type Enemy = {
	id: string,
	def: any,
	zoneId: number,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	hp: number,
	nextAttack: number,
	nextWander: number,
}

local EnemyService = {}

local enemies: { [Model]: Enemy } = {}
local countByZone: { [number]: number } = {}

local function buildModel(def: any, at: Vector3): (Model, Humanoid, BasePart)
	local model = Instance.new("Model")
	model.Name = def.displayName

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = def.size
	root.Color = def.color
	root.Material = Enum.Material.Slate
	root.CFrame = CFrame.new(at + Vector3.new(0, def.size.Y / 2 + 0.5, 0))
	root.Parent = model
	model.PrimaryPart = root

	for _, x in { -0.5, 0.5 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.4, 0.4, 0.2)
		eye.Color = Color3.fromRGB(255, 220, 120)
		eye.Material = Enum.Material.Neon
		eye.CanCollide = false
		eye.Massless = true
		eye.CFrame = root.CFrame * CFrame.new(x, def.size.Y * 0.15, -def.size.Z / 2 - 0.05)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = eye
		weld.Parent = eye
		eye.Parent = model
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 0.5
	humanoid.WalkSpeed = def.walkSpeed
	humanoid.MaxHealth = def.maxHealth
	humanoid.Health = def.maxHealth
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	model.Parent = WorldService.getFolder("Enemies")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return model, humanoid, root
end

local function farFromGolems(point: Vector3, minDistance: number): boolean
	for _, golem in GolemService.all() do
		if (golem.root.Position - point).Magnitude < minDistance then
			return false
		end
	end
	return true
end

local function spawnEnemy(zoneId: number)
	local zone = Config.Zones[zoneId]
	local enemyId = zone.enemies[math.random(1, #zone.enemies)]
	local def = Config.Enemies[enemyId]

	local point: Vector3? = nil
	for _ = 1, 6 do
		local candidate = WorldService.randomPoint(zoneId, 12)
		if farFromGolems(candidate, zone.minSpawnDistance) then
			point = candidate
			break
		end
	end
	if not point then
		return
	end

	local model, humanoid, root = buildModel(def, point)
	enemies[model] = {
		id = enemyId,
		def = def,
		zoneId = zoneId,
		model = model,
		humanoid = humanoid,
		root = root,
		hp = def.maxHealth,
		nextAttack = 0,
		nextWander = 0,
	}
	countByZone[zoneId] = (countByZone[zoneId] or 0) + 1
end

local function remove(enemy: Enemy)
	enemies[enemy.model] = nil
	countByZone[enemy.zoneId] -= 1
	enemy.model:Destroy()
end

local function nearestGolem(position: Vector3, range: number): (GolemService.Golem?, number)
	local best, bestDistance = nil, range
	for _, golem in GolemService.all() do
		if GolemService.isActive(golem) then
			local distance = (golem.root.Position - position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = golem, distance
			end
		end
	end
	return best, bestDistance
end

function EnemyService.findNearest(position: Vector3, range: number): (Enemy?, number)
	local best, bestDistance = nil, range
	for _, enemy in enemies do
		local distance = (enemy.root.Position - position).Magnitude
		if distance <= bestDistance then
			best, bestDistance = enemy, distance
		end
	end
	return best, bestDistance
end

function EnemyService.findInRadius(position: Vector3, radius: number): { Enemy }
	local found = {}
	for _, enemy in enemies do
		if (enemy.root.Position - position).Magnitude <= radius then
			table.insert(found, enemy)
		end
	end
	return found
end

-- Damage from a player's golem or spell. Rewards go to that player.
function EnemyService.damage(enemy: Enemy, amount: number, player: Player)
	if enemies[enemy.model] == nil then
		return -- already defeated this tick
	end
	enemy.hp -= amount
	if enemy.hp > 0 then
		enemy.humanoid.Health = enemy.hp
		return
	end

	for mineralId, count in enemy.def.drops do
		DataService.addMineral(player, mineralId, count)
	end
	DataService.addXp(player, enemy.def.xp)
	Remotes.Notify:FireClient(player, "defeated", enemy.def.displayName, enemy.def.drops, enemy.def.xp)
	remove(enemy)
end

function EnemyService.update()
	local now = os.clock()
	for _, enemy in enemies do
		local target, distance = nearestGolem(enemy.root.Position, enemy.def.aggroRange)
		if target then
			if distance <= enemy.def.attackRange then
				enemy.humanoid:Move(Vector3.zero)
				if now >= enemy.nextAttack then
					enemy.nextAttack = now + enemy.def.attackCooldown
					GolemService.damage(target, enemy.def.damage)
				end
			else
				enemy.humanoid:MoveTo(target.root.Position)
			end
		elseif now >= enemy.nextWander then
			enemy.nextWander = now + math.random(3, 7)
			local offset = Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
			enemy.humanoid:MoveTo(enemy.root.Position + offset)
		end

		-- Clean up anything that fell off the island.
		if enemy.root.Position.Y < WorldService.getSurfaceY(enemy.zoneId) - 40 then
			remove(enemy)
		end
	end
end

function EnemyService.start()
	for zoneId, zone in Config.Zones do
		countByZone[zoneId] = 0
		task.spawn(function()
			while true do
				task.wait(zone.spawnInterval)
				-- Only spawn while someone is playing.
				if next(GolemService.all()) ~= nil and countByZone[zoneId] < zone.maxEnemies then
					spawnEnemy(zoneId)
				end
			end
		end)
	end
end

return EnemyService
