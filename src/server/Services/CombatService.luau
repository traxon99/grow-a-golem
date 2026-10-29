--!strict
-- The game-logic heartbeat. Ten times a second it decides, for every golem,
-- whether to follow the rider's steering, chase an enemy, or walk to a node,
-- and resolves auto-attacks, mining, and rider spells.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)
local MiningService = require(script.Parent.MiningService)
local WorldService = require(script.Parent.WorldService)

local CombatService = {}

-- Tells clients to play a punch (see the client Animator and Sfx).
-- `kind` is "hit" for enemies or "mine" for mineral nodes.
local function swing(model: Model, kind: string)
	model:SetAttribute("AttackKind", kind)
	model:SetAttribute("Attack", ((model:GetAttribute("Attack") :: number?) or 0) + 1)
end

local function ringEffect(position: Vector3, radius: number, color: Color3)
	local ring = Instance.new("Part")
	ring.Name = "SpellRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = WorldService.getFolder("Effects")

	local tween = TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Once(function()
		ring:Destroy()
	end)
end

-- A short flash of light where the slam lands: a ball that swells and fades,
-- with a smaller white core that goes faster.
local function blastEffect(position: Vector3, radius: number, color: Color3)
	local layers = {
		{ color = color, size = radius * 0.8, time = 0.35 },
		{ color = Color3.new(1, 1, 1), size = radius * 0.4, time = 0.2 },
	}
	for index, layer in layers do
		local ball = Instance.new("Part")
		ball.Name = "QuakeBlast" .. index
		ball.Shape = Enum.PartType.Ball
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.Material = Enum.Material.Neon
		ball.Color = layer.color
		ball.Transparency = 0.25
		ball.Size = Vector3.new(2, 2, 2)
		ball.Position = position + Vector3.new(0, 1, 0)
		ball.Parent = WorldService.getFolder("Effects")

		local info = TweenInfo.new(layer.time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(ball, info, {
			Size = Vector3.new(layer.size, layer.size, layer.size),
			Transparency = 1,
		})
		tween:Play()
		tween.Completed:Once(function()
			ball:Destroy()
		end)
	end
end

-- Quake: the golem raises both arms (clients animate from QuakeAt, a server
-- time), then the slam lands `windup` seconds later with the damage, ring and
-- blast. A golem that was knocked out or removed in between slams nothing.
local function quake(player: Player, golem: GolemService.Golem, spell: any)
	golem.model:SetAttribute("QuakeWindup", spell.windup)
	golem.model:SetAttribute("QuakeAt", workspace:GetServerTimeNow() + spell.windup)
	task.delay(spell.windup, function()
		if GolemService.get(player) ~= golem or not GolemService.isActive(golem) then
			return
		end
		local radius = spell.radius * golem.stats.scale
		for _, enemy in EnemyService.findInRadius(golem.root.Position, radius, golem.zoneId) do
			EnemyService.damage(
				enemy,
				spell.damage * golem.stats.spellPowerMult * (1 + 0.05 * (golem.stats.level - 1)),
				player
			)
		end
		local ground = golem.root.Position - Vector3.new(0, golem.groundOffset, 0) + Vector3.new(0, 0.3, 0)
		ringEffect(ground, radius, Color3.fromRGB(90, 200, 255))
		blastEffect(ground, radius, Color3.fromRGB(150, 225, 255))
	end)
end

local function onCastSpell(player: Player, spellId: any)
	if type(spellId) ~= "string" then
		return
	end
	local spell = Config.Spells[spellId]
	local golem = GolemService.get(player)
	if not spell or not golem or not golem.mounted or not GolemService.isActive(golem) then
		return
	end
	local now = os.clock()
	if now < (golem.spellReadyAt[spellId] or 0) then
		return
	end
	local cooldown = spell.cooldown * golem.stats.spellCooldownMult
	golem.spellReadyAt[spellId] = now + cooldown
	local ground = golem.root.Position - Vector3.new(0, golem.groundOffset, 0) + Vector3.new(0, 0.3, 0)

	if spellId == "quake" then
		quake(player, golem, spell)
	elseif spellId == "mend" then
		GolemService.heal(golem, golem.stats.maxHealth * spell.healFraction * golem.stats.spellPowerMult)
		ringEffect(ground, 10 * golem.stats.scale, Color3.fromRGB(110, 230, 120))
	elseif spellId == "magnet" then
		golem.magnetUntil = now + spell.duration
		ringEffect(ground, 14 * golem.stats.scale, Color3.fromRGB(255, 200, 80))
	end

	Events.fire("spellCast", player, spellId)
	Remotes.Notify:FireClient(player, "spellCast", spellId, cooldown)
end

local function updateGolem(player: Player, golem: GolemService.Golem, dt: number)
	GolemService.update(golem, dt)
	if not GolemService.isActive(golem) then
		return
	end

	local stats = golem.stats
	local now = os.clock()
	local position = golem.root.Position
	local aggro = Config.Golem.aggroRange * stats.scale

	local enemy, enemyDistance = EnemyService.findNearest(position, aggro, golem.zoneId)
	local node, nodeDistance = nil, math.huge
	if not enemy then
		node, nodeDistance = MiningService.findNearest(position, Config.Golem.seekRange, golem.zoneId)
	end

	-- Act: enemies first, mining when the area is clear.
	if enemy and enemyDistance <= stats.attackRange and now >= golem.nextAttack then
		golem.nextAttack = now + stats.attackCooldown
		swing(golem.model, "hit")
		EnemyService.damage(enemy, stats.attackDamage, player)
	elseif node and nodeDistance <= stats.miningRange and now >= golem.nextMine then
		golem.nextMine = now + stats.miningCooldown
		swing(golem.model, "mine")
		MiningService.damage(node, stats.miningDamage, player)
	end

	-- Move: the rider's steering always wins; otherwise the golem plays itself.
	local steer = GolemService.getSteer(golem)
	if steer.Magnitude > 0 then
		golem.humanoid:Move(steer)
	elseif enemy and enemyDistance > stats.attackRange * 0.8 then
		golem.humanoid:MoveTo(enemy.root.Position)
	elseif node and nodeDistance > stats.miningRange * 0.8 then
		golem.humanoid:MoveTo(node.part.Position)
	else
		golem.humanoid:Move(Vector3.zero)
	end
end

function CombatService.start()
	Remotes.CastSpell.OnServerEvent:Connect(onCastSpell)

	-- Lets the client show where the golem is and whether the zone boss is up.
	DataService.addProvider("golem", function(player)
		local golem = GolemService.get(player)
		if not golem then
			return nil
		end
		local bossAlive, bossRespawnIn = EnemyService.bossStatus(golem.zoneId)
		return { zoneId = golem.zoneId, bossAlive = bossAlive, bossRespawnIn = math.ceil(bossRespawnIn) }
	end)

	task.spawn(function()
		local interval = 1 / Config.TickRate
		local last = os.clock()
		while true do
			task.wait(interval)
			local now = os.clock()
			local dt = now - last
			last = now

			for player, golem in GolemService.all() do
				local ok, err = pcall(function(): any
					updateGolem(player, golem, dt)
					return nil
				end)
				if not ok then
					warn(`[CombatService] golem update failed for {player.Name}: {err}`)
				end
			end
			local ok, err = pcall(function(): any
				EnemyService.update()
				return nil
			end)
			if not ok then
				warn(`[CombatService] enemy update failed: {err}`)
			end
		end
	end)
end

return CombatService
