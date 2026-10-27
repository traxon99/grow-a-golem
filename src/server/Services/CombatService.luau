--!strict
-- The game-logic heartbeat. Ten times a second it decides, for every golem,
-- whether to follow the rider's steering, chase an enemy, or walk to a node,
-- and resolves auto-attacks, mining, and rider spells.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local EnemyService = require(script.Parent.EnemyService)
local GolemService = require(script.Parent.GolemService)
local MiningService = require(script.Parent.MiningService)
local WorldService = require(script.Parent.WorldService)

local CombatService = {}

local function quakeEffect(position: Vector3, radius: number)
	local ring = Instance.new("Part")
	ring.Name = "Quake"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(90, 200, 255)
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

local function onCastSpell(player: Player, spellId: any)
	if type(spellId) ~= "string" then
		return
	end
	local spell = Config.Spells[spellId]
	local golem = GolemService.get(player)
	if not spell or not golem or not GolemService.isActive(golem) then
		return
	end
	local now = os.clock()
	if now < (golem.spellReadyAt[spellId] or 0) then
		return
	end
	golem.spellReadyAt[spellId] = now + spell.cooldown

	if spellId == "quake" then
		local ground = golem.root.Position - Vector3.new(0, golem.humanoid.HipHeight + golem.root.Size.Y / 2, 0)
		for _, enemy in EnemyService.findInRadius(golem.root.Position, spell.radius) do
			EnemyService.damage(enemy, spell.damage, player)
		end
		quakeEffect(ground + Vector3.new(0, 0.3, 0), spell.radius)
	end

	Remotes.Notify:FireClient(player, "spellCast", spellId, spell.cooldown)
end

local function updateGolem(player: Player, golem: GolemService.Golem, dt: number)
	GolemService.update(golem, dt)
	if not GolemService.isActive(golem) then
		return
	end

	local stats = Config.Golem
	local now = os.clock()
	local position = golem.root.Position

	local enemy, enemyDistance = EnemyService.findNearest(position, stats.aggroRange)
	local node, nodeDistance = nil, math.huge
	if not enemy then
		node, nodeDistance = MiningService.findNearest(position, stats.seekRange)
	end

	-- Act: enemies first, mining when the area is clear.
	if enemy and enemyDistance <= stats.attackRange and now >= golem.nextAttack then
		golem.nextAttack = now + stats.attackCooldown
		EnemyService.damage(enemy, stats.attackDamage, player)
	elseif node and nodeDistance <= stats.miningRange and now >= golem.nextMine then
		golem.nextMine = now + stats.miningCooldown
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

	task.spawn(function()
		local interval = 1 / Config.TickRate
		local last = os.clock()
		while true do
			task.wait(interval)
			local now = os.clock()
			local dt = now - last
			last = now

			for player, golem in GolemService.all() do
				local ok, err = pcall(updateGolem, player, golem, dt)
				if not ok then
					warn(`[CombatService] golem update failed for {player.Name}: {err}`)
				end
			end
			local ok, err = pcall(EnemyService.update)
			if not ok then
				warn(`[CombatService] enemy update failed: {err}`)
			end
		end
	end)
end

return CombatService
