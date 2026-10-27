--!strict
-- Spawns enemy waves and one boss per zone (only while someone is in that
-- zone), runs their chase-and-hit AI and the boss ground slam, and pays out
-- rewards. Party members near a kill share it; everyone who hit a boss gets
-- the boss reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ArtifactService = require(script.Parent.ArtifactService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)
local PartyService = require(script.Parent.PartyService)
local WorldService = require(script.Parent.WorldService)
local EnemyModels = require(script.Parent.Parent.Models.EnemyModels)

export type Enemy = {
	id: string,
	def: any,
	zoneId: number,
	isBoss: boolean,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	hp: number,
	nextAttack: number,
	nextWander: number,
	nextSlam: number,
	slamAt: number, -- 0 when no slam is winding up
	slamPosition: Vector3,
	slamMarker: BasePart?,
	contributors: { [Player]: boolean },
	-- Set for tower enemies: called once on defeat instead of island rewards.
	onDefeated: ((Enemy) -> ())?,
}

local EnemyService = {}

local enemies: { [Model]: Enemy } = {}
local countByZone: { [number]: number } = {}
local bossByZone: { [number]: Enemy } = {}
local bossReadyAt: { [number]: number } = {}
local spawnsByZone: { [number]: number } = {}

local function buildModel(designId: string, def: any, at: Vector3): (Model, Humanoid, BasePart)
	local model = Instance.new("Model")
	model.Name = def.displayName

	-- The root is an invisible box the size in Config; the body is built around it.
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = def.size
	root.Transparency = 1
	root.CFrame = CFrame.new(at + Vector3.new(0, def.size.Y / 2 + 0.5, 0))
	root.Parent = model
	model.PrimaryPart = root
	EnemyModels.dress(model, root, designId, def)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 0.5
	humanoid.WalkSpeed = def.walkSpeed
	humanoid.MaxHealth = def.maxHealth
	humanoid.Health = def.maxHealth
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayName = def.displayName
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.Parent = model
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	model.Parent = WorldService.getFolder("Enemies")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return model, humanoid, root
end

local function makeEnemy(id: string, def: any, zoneId: number, at: Vector3, isBoss: boolean): Enemy
	local model, humanoid, root = buildModel(id, def, at)
	local enemy: Enemy = {
		id = id,
		def = def,
		zoneId = zoneId,
		isBoss = isBoss,
		model = model,
		humanoid = humanoid,
		root = root,
		hp = def.maxHealth,
		nextAttack = 0,
		nextWander = 0,
		nextSlam = os.clock() + (if def.slam then def.slam.every else 0),
		slamAt = 0,
		slamPosition = Vector3.zero,
		slamMarker = nil,
		contributors = {},
		onDefeated = nil,
	}
	enemies[model] = enemy
	return enemy
end

local function golemsInZone(zoneId: number): number
	local count = 0
	for _, golem in GolemService.all() do
		if golem.zoneId == zoneId then
			count += 1
		end
	end
	return count
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
	local totalWeight = 0
	for _, id in zone.enemies do
		totalWeight += Config.Enemies[id].spawnWeight or 1
	end
	local roll = math.random() * totalWeight
	local enemyId = zone.enemies[#zone.enemies]
	for _, id in zone.enemies do
		roll -= Config.Enemies[id].spawnWeight or 1
		if roll < 0 then
			enemyId = id
			break
		end
	end
	local def = Config.Enemies[enemyId]
	for _ = 1, 6 do
		local point = WorldService.randomPoint(zoneId, 12)
		if farFromGolems(point, zone.minSpawnDistance) then
			spawnsByZone[zoneId] = (spawnsByZone[zoneId] or 0) + 1
			local elite = spawnsByZone[zoneId] % Config.Elites.everySpawns == 0
			local spawnDef = def
			if elite then
				spawnDef = table.clone(def)
				spawnDef.displayName = "Elite " .. def.displayName
				spawnDef.maxHealth *= Config.Elites.health
				spawnDef.damage *= Config.Elites.damage
				spawnDef.size *= Config.Elites.scale
				spawnDef.xp *= Config.Elites.rewards
				spawnDef.drops = table.clone(def.drops)
				for mineral, amount in spawnDef.drops do
					spawnDef.drops[mineral] = amount * Config.Elites.rewards
				end
			end
			local enemy = makeEnemy(enemyId, spawnDef, zoneId, point, false)
			if elite then
				enemy.model:SetAttribute("Elite", true)
				local glow = Instance.new("Highlight")
				glow.FillColor = Color3.fromRGB(255, 210, 80)
				glow.FillTransparency = 0.7
				glow.OutlineTransparency = 0.2
				glow.DepthMode = Enum.HighlightDepthMode.Occluded
				glow.Parent = enemy.model
			end
			countByZone[zoneId] += 1
			return
		end
	end
end

local function spawnBoss(zoneId: number)
	local def = Config.Bosses[zoneId]
	local boss = makeEnemy("boss" .. zoneId, def, zoneId, WorldService.getBossPoint(zoneId), true)
	-- The client's boss health bar finds the boss by this attribute and reads
	-- the real health off its Humanoid.
	boss.model:SetAttribute("BossZone", zoneId)
	bossByZone[zoneId] = boss
end

local function clearSlam(enemy: Enemy)
	if enemy.slamMarker then
		enemy.slamMarker:Destroy()
		enemy.slamMarker = nil
	end
	enemy.slamAt = 0
end

local function remove(enemy: Enemy)
	enemies[enemy.model] = nil
	clearSlam(enemy)
	if enemy.onDefeated then
		-- Tower enemies don't touch the island spawn counts or boss timers.
		countByZone[enemy.zoneId] = math.max((countByZone[enemy.zoneId] or 1) - 1, 0)
	elseif enemy.isBoss then
		bossByZone[enemy.zoneId] = nil
		bossReadyAt[enemy.zoneId] = os.clock() + enemy.def.respawn
	else
		countByZone[enemy.zoneId] -= 1
	end
	enemy.model:Destroy()
end

local function nearestGolem(position: Vector3, range: number, zoneId: number): (GolemService.Golem?, number)
	local best, bestDistance = nil, range
	for _, golem in GolemService.all() do
		if golem.zoneId == zoneId and GolemService.isActive(golem) then
			local distance = (golem.root.Position - position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = golem, distance
			end
		end
	end
	return best, bestDistance
end

function EnemyService.findNearest(position: Vector3, range: number, zoneId: number): (Enemy?, number)
	local best, bestDistance = nil, range
	for _, enemy in enemies do
		if enemy.zoneId == zoneId then
			local distance = (enemy.root.Position - position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = enemy, distance
			end
		end
	end
	return best, bestDistance
end

function EnemyService.findInRadius(position: Vector3, radius: number, zoneId: number): { Enemy }
	local found = {}
	for _, enemy in enemies do
		if enemy.zoneId == zoneId and (enemy.root.Position - position).Magnitude <= radius then
			table.insert(found, enemy)
		end
	end
	return found
end

function EnemyService.bossStatus(zoneId: number): (boolean, number)
	local alive = bossByZone[zoneId] ~= nil
	return alive, math.max((bossReadyAt[zoneId] or 0) - os.clock(), 0)
end

local function rewardKill(enemy: Enemy, killer: Player)
	local recipients: { Player }
	if enemy.isBoss then
		recipients = {}
		for player in enemy.contributors do
			if player.Parent then
				table.insert(recipients, player)
			end
		end
	else
		recipients = PartyService.shareWith(killer, function(member)
			local golem = GolemService.get(member)
			return golem ~= nil
				and golem.zoneId == enemy.zoneId
				and (golem.root.Position - enemy.root.Position).Magnitude <= Config.Party.shareRange
		end)
	end

	for _, player in recipients do
		local given = EconomyService.grant(
			player,
			{ minerals = enemy.def.drops, xp = enemy.def.xp },
			if enemy.isBoss then "boss" else "enemy"
		)
		if enemy.isBoss then
			local firstTime = false
			DataService.update(player, function(data)
				firstTime = not data.bossesDefeated[tostring(enemy.zoneId)]
				data.bossesDefeated[tostring(enemy.zoneId)] = true
				data.totals.bosses += 1
			end)
			Events.fire("bossDefeated", player, enemy.zoneId)
			Remotes.Notify:FireClient(player, "boss", enemy.def.displayName, firstTime)
			ArtifactService.roll(player, enemy.zoneId, "boss")
		else
			DataService.update(player, function(data)
				data.totals.enemies += 1
			end)
			Events.fire("enemyDefeated", player, enemy.id, enemy.zoneId)
			Remotes.Notify:FireClient(player, "defeated", enemy.def.displayName, given.xp or 0)
			ArtifactService.roll(player, enemy.zoneId, "drop")
		end
	end
end

-- Damage from a player's golem or spell.
function EnemyService.damage(enemy: Enemy, amount: number, player: Player)
	if enemies[enemy.model] == nil then
		return -- already defeated this tick
	end
	if enemy.isBoss and not enemy.contributors[player] then
		Events.fire("bossEngaged", player, enemy.zoneId)
	end
	enemy.contributors[player] = true
	enemy.hp -= amount
	-- Clients flash the enemy and show the number (see the client Fx).
	enemy.model:SetAttribute("HitDamage", math.floor(amount + 0.5))
	enemy.model:SetAttribute("Hit", ((enemy.model:GetAttribute("Hit") :: number?) or 0) + 1)
	if enemy.hp > 0 then
		enemy.humanoid.Health = enemy.hp
		return
	end
	local onDefeated = enemy.onDefeated
	if onDefeated then
		remove(enemy)
		onDefeated(enemy)
		return
	end
	rewardKill(enemy, player)
	remove(enemy)
end

-- Spawns one tower enemy into an arena. `healthMult` scales its health.
-- `onDefeated` runs once when it's beaten; it gives no drops or artifact rolls.
function EnemyService.spawnInArena(
	zoneId: number,
	enemyId: string,
	def: any,
	at: Vector3,
	isBoss: boolean,
	healthMult: number,
	onDefeated: (Enemy) -> ()
): Enemy
	local scaled = table.clone(def)
	scaled.maxHealth = math.floor(def.maxHealth * healthMult)
	-- Bosses use their island's design id ("boss1"), like island bosses do.
	local enemy = makeEnemy(enemyId, scaled, zoneId, at, isBoss)
	enemy.onDefeated = onDefeated
	countByZone[zoneId] = (countByZone[zoneId] or 0) + 1
	if isBoss then
		-- The client's boss bar finds bosses in the player's zone by this.
		enemy.model:SetAttribute("BossZone", zoneId)
	end
	return enemy
end

-- Removes every enemy in a zone without rewards (a tower run ending).
function EnemyService.clearZone(zoneId: number)
	for _, enemy in enemies do
		if enemy.zoneId == zoneId then
			enemy.onDefeated = nil
			enemies[enemy.model] = nil
			clearSlam(enemy)
			enemy.model:Destroy()
		end
	end
	countByZone[zoneId] = 0
end

local function updateSlam(enemy: Enemy, now: number)
	local slam = enemy.def.slam
	if enemy.slamAt > 0 then
		if now >= enemy.slamAt then
			for _, golem in GolemService.all() do
				if golem.zoneId == enemy.zoneId and GolemService.isActive(golem) then
					local flat = (golem.root.Position - enemy.slamPosition) * Vector3.new(1, 0, 1)
					if flat.Magnitude <= slam.radius then
						GolemService.damage(golem, slam.damage)
					end
				end
			end
			clearSlam(enemy)
		end
		return
	end
	if now < enemy.nextSlam then
		return
	end
	local target = nearestGolem(enemy.root.Position, enemy.def.aggroRange, enemy.zoneId)
	if not target then
		return
	end
	enemy.nextSlam = now + slam.every
	enemy.slamAt = now + slam.warning
	-- Clients raise the boss's arms during the warning (see the client Animator).
	enemy.model:SetAttribute("SlamAt", workspace:GetServerTimeNow() + slam.warning)
	local ground = target.root.Position - Vector3.new(0, target.groundOffset, 0)
	enemy.slamPosition = ground

	-- A red disc on the ground shows where the slam will land.
	local marker = Instance.new("Part")
	marker.Name = "SlamWarning"
	marker.Shape = Enum.PartType.Cylinder
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(255, 60, 40)
	marker.Transparency = 0.45
	marker.Size = Vector3.new(0.3, slam.radius * 2, slam.radius * 2)
	marker.CFrame = CFrame.new(ground + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	marker.Parent = WorldService.getFolder("Effects")
	enemy.slamMarker = marker
end

function EnemyService.update()
	local now = os.clock()
	for _, enemy in enemies do
		if enemy.def.slam then
			updateSlam(enemy, now)
		end

		local target, distance = nearestGolem(enemy.root.Position, enemy.def.aggroRange, enemy.zoneId)
		if target then
			if distance <= enemy.def.attackRange + (target.stats.scale - 1) * 4 then
				enemy.humanoid:Move(Vector3.zero)
				if now >= enemy.nextAttack then
					enemy.nextAttack = now + enemy.def.attackCooldown
					enemy.model:SetAttribute("Attack", ((enemy.model:GetAttribute("Attack") :: number?) or 0) + 1)
					GolemService.damage(target, enemy.def.damage)
				end
			else
				enemy.humanoid:MoveTo(target.root.Position)
			end
		elseif enemy.isBoss then
			-- Bosses return home and slowly heal when nobody is fighting them,
			-- so stepping away to mend doesn't throw away a close fight.
			local home = WorldService.getBossPoint(enemy.zoneId)
			if (enemy.root.Position - home).Magnitude > 15 then
				enemy.humanoid:MoveTo(home)
			end
			if enemy.hp < enemy.def.maxHealth then
				enemy.hp = math.min(
					enemy.hp + enemy.def.maxHealth * Config.BossRegenPerSecond / Config.TickRate,
					enemy.def.maxHealth
				)
				enemy.humanoid.Health = enemy.hp
			else
				enemy.contributors = {}
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
		bossReadyAt[zoneId] = 0
		task.spawn(function()
			while true do
				task.wait(zone.spawnInterval)
				local players = golemsInZone(zoneId)
				if players > 0 then
					local cap = zone.maxEnemies + zone.extraEnemiesPerPlayer * (players - 1)
					if countByZone[zoneId] < cap then
						spawnEnemy(zoneId)
					end
					if Config.Bosses[zoneId] and not bossByZone[zoneId] and os.clock() >= bossReadyAt[zoneId] then
						spawnBoss(zoneId)
					end
				end
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, enemy in enemies do
			enemy.contributors[player] = nil
		end
	end)
end

return EnemyService
