--!strict
-- The game-logic heartbeat. Ten times a second it decides, for every golem,
-- whether to follow the rider's steering, walk back to a dismounted rider,
-- chase an enemy, or walk to a node, and resolves auto-attacks, mining, and
-- rider spells.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local QuakeTiming = require(Shared:WaitForChild("QuakeTiming"))

local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)
local MiningService = require(script.Parent.MiningService)
local WorldService = require(script.Parent.WorldService)

local CombatService = {}

type PendingQuake = {
	golem: GolemService.Golem,
	startedAt: number,
	attempted: boolean,
	perfect: boolean,
}

-- A cast gets one follow-up press. Clear the record at impact even when
-- the golem was knocked out or the player left during the windup.
local pendingQuakes: { [Player]: PendingQuake } = {}

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

-- Quake: the golem raises both arms (clients animate from QuakeAt, a server
-- time), then the slam lands `windup` seconds later with the damage and ring,
-- and clients are told so they can play the blast, rocks and thud (gated on
-- their own Reduced Motion). A golem knocked out or removed in between slams
-- nothing, and nobody is told.
local function quake(player: Player, golem: GolemService.Golem, spell: any, pending: PendingQuake)
	local impactAt = workspace:GetServerTimeNow() + spell.windup
	golem.model:SetAttribute("QuakeAt", impactAt)
	Remotes.Notify:FireClient(
		player,
		"quakeTiming",
		impactAt,
		spell.windup,
		spell.timingLead,
		spell.timingWindow,
		spell.perfectMultiplier
	)
	task.delay(spell.windup, function()
		if pendingQuakes[player] == pending then
			pendingQuakes[player] = nil
		end
		if GolemService.get(player) ~= golem or not GolemService.isActive(golem) then
			return
		end
		local radius = spell.radius * golem.stats.scale
		for _, enemy in EnemyService.findInRadius(golem.root.Position, radius, golem.zoneId) do
			EnemyService.damage(
				enemy,
				spell.damage
					* (if pending.perfect then spell.perfectMultiplier else 1)
					* golem.stats.spellPowerMult
					* (1 + 0.05 * (golem.stats.level - 1)),
				player
			)
			-- Only the server-graded second press can interrupt a living island
			-- boss. A killing blow, ordinary Quake, and Tower bosses never stagger.
			if pending.perfect then
				EnemyService.stagger(enemy, player)
			end
		end
		local ground = golem.root.Position - Vector3.new(0, golem.groundOffset, 0) + Vector3.new(0, 0.3, 0)
		ringEffect(
			ground,
			radius,
			if pending.perfect then Color3.fromRGB(255, 204, 70) else Color3.fromRGB(90, 200, 255)
		)
		Remotes.Notify:FireAllClients("quakeImpact", ground, radius, player.UserId)
		Remotes.Notify:FireClient(player, "quakeTimingImpact")
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
	if spellId == "quake" then
		local pending = pendingQuakes[player]
		if pending and pending.golem == golem then
			local graded =
				QuakeTiming.press(pending, now - pending.startedAt, spell.windup, spell.timingLead, spell.timingWindow)
			if graded ~= nil then
				Remotes.Notify:FireClient(player, "quakeTimingResult", graded)
			end
			return
		end
	end
	if now < (golem.spellReadyAt[spellId] or 0) then
		return
	end
	local cooldown = spell.cooldown * golem.stats.spellCooldownMult
	golem.spellReadyAt[spellId] = now + cooldown
	local ground = golem.root.Position - Vector3.new(0, golem.groundOffset, 0) + Vector3.new(0, 0.3, 0)

	if spellId == "quake" then
		local pending: PendingQuake = {
			golem = golem,
			startedAt = now,
			attempted = false,
			perfect = false,
		}
		pendingQuakes[player] = pending
		quake(player, golem, spell, pending)
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

	-- Dismounted, the golem is a companion on a leash: it walks back to its
	-- rider when it strays, and only fights and mines inside the leash.
	if GolemService.followRider(golem, now) then
		return
	end
	local center = GolemService.leashCenter(golem)
	local leash = GolemService.leashRadius(golem)

	local enemy, enemyDistance = EnemyService.findNearest(position, aggro, golem.zoneId)
	if enemy and center and not GolemService.inLeash(golem, enemy.root.Position) then
		enemy = EnemyService.findNearest(center, leash, golem.zoneId)
		enemyDistance = if enemy then (enemy.root.Position - position).Magnitude else math.huge
	end
	local node, nodeDistance = nil, math.huge
	if not enemy then
		node, nodeDistance = MiningService.findNearest(position, Config.Golem.seekRange, golem.zoneId)
		if node and center and not GolemService.inLeash(golem, node.part.Position) then
			node = MiningService.findNearest(center, leash, golem.zoneId)
			nodeDistance = if node then (node.part.Position - position).Magnitude else math.huge
		end
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
