--!strict
-- Free solo Golem Run: three sequential, server-validated checkpoints.
-- A native prompt in the Hub starts the run (touch, keyboard, gamepad).
-- Players steer their mounted golem; the server samples its real position,
-- detects hazards and pays each checkpoint once. No client score or purchases.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GauntletRules = require(Shared:WaitForChild("GauntletRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GolemService = require(script.Parent.GolemService)
local WorldService = require(script.Parent.WorldService)

type Run = {
	nextIndex: number,
	safe: Vector3,
	expiresAt: number,
	graceUntil: number,
}

local GauntletService = {}
local runs: { [Player]: Run } = {}
local cooldownUntil: { [Player]: number } = {}
local staticBoulders: { Vector3 } = {}
local movingBoulder: Part? = nil
local gatePosition = Vector3.zero

local function say(player: Player, message: string)
	if player.Parent then
		Remotes.Notify:FireClient(player, "message", message)
	end
end

local function point(x: number, z: number, height: number): Vector3
	return Config.Gauntlet.center + Vector3.new(x, height, z)
end

local function part(
	parent: Instance,
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	collide: boolean
): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Anchored = true
	item.CanCollide = collide
	item.CanTouch = false
	item.Size = size
	item.Position = position
	item.Material = material
	item.Color = color
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function sign(target: BasePart, words: string, width: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CourseSign"
	billboard.Size = UDim2.fromOffset(width, 65)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.MaxDistance = 160
	billboard.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
	label.TextColor3 = Color3.fromRGB(255, 245, 196)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = words
	label.Parent = billboard
	billboard.Parent = target
end

local function prompt(target: BasePart, action: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = "Free Golem Run"
	p.HoldDuration = 0.2
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = 25
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.Parent = target
	return p
end

local function boulder(folder: Instance, x: number, z: number, moving: boolean): Part
	local pos = point(x, z, 5)
	local ball = part(
		folder,
		if moving then "RollingBoulder" else "Boulder",
		pos,
		Vector3.new(10, 10, 10),
		if moving then Color3.fromRGB(255, 125, 65) else Color3.fromRGB(120, 100, 95),
		if moving then Enum.Material.Neon else Enum.Material.Slate,
		false
	)
	ball.Shape = Enum.PartType.Ball
	if not moving then
		table.insert(staticBoulders, pos)
	end
	return ball
end

-- Each lava strip is two bright hazard pieces with an obvious clear opening.
local function lava(folder: Instance, z: number, gapX: number)
	local edge = Config.Gauntlet.laneHalfWidth
	local gap = Config.Gauntlet.lavaGapHalfWidth
	local leftEnd = gapX - gap
	local rightStart = gapX + gap
	local function segment(a: number, b: number)
		if b <= a then
			return
		end
		part(
			folder,
			"Lava",
			point((a + b) / 2, z, 0.3),
			Vector3.new(b - a, 0.5, Config.Gauntlet.lavaHalfDepth * 2),
			Color3.fromRGB(255, 75, 35),
			Enum.Material.Neon,
			false
		)
	end
	segment(-edge, leftEnd)
	segment(rightStart, edge)
	local bridge = part(
		folder,
		"SafeBridge",
		point(gapX, z, 0.15),
		Vector3.new(gap * 2, 0.25, Config.Gauntlet.lavaHalfDepth * 2),
		Color3.fromRGB(115, 235, 165),
		Enum.Material.Neon,
		false
	)
	sign(bridge, "SAFE PATH", 160)
end

local function buildCourse(): (ProximityPrompt, ProximityPrompt)
	local cfg = Config.Gauntlet
	WorldService.addArena(cfg.zoneId, cfg.center, cfg.arenaSize, "Golem Run")
	local folder = Instance.new("Folder")
	folder.Name = "GolemRun"
	folder.Parent = workspace

	-- Portal stays on the public Hub. No Travel/menu UI files are touched.
	gatePosition = WorldService.getSpawnPoint(Config.HubZone) + Vector3.new(55, 3, 0)
	local gate = part(
		folder,
		"GolemRunPortal",
		gatePosition,
		Vector3.new(7, 6, 7),
		Color3.fromRGB(110, 185, 255),
		Enum.Material.Neon,
		false
	)
	gate.Transparency = 0.25
	sign(gate, "GOLEM RUN | 90 SECONDS | 3 FIXED REWARDS", 370)
	local entry = prompt(gate, "Ride the obstacle run")

	-- Wide, readable rails show the permitted lane. Hazards reset rather
	-- than deal damage; a missed dodge never removes already-earned minerals.
	for _, x in { -cfg.laneHalfWidth - 2, cfg.laneHalfWidth + 2 } do
		part(
			folder,
			"CourseRail",
			point(x, 0, 2),
			Vector3.new(1.5, 4, 254),
			Color3.fromRGB(95, 130, 160),
			Enum.Material.Slate,
			true
		)
	end
	local start = part(
		folder,
		"StartPad",
		point(0, cfg.startZ, 0.2),
		Vector3.new(22, 0.35, 12),
		Color3.fromRGB(95, 210, 235),
		Enum.Material.Neon,
		false
	)
	sign(start, "START | STEER AROUND RED HAZARDS", 330)
	local leave = prompt(start, "Leave the run")

	boulder(folder, -12, -88, false)
	boulder(folder, 12, -70, false)
	lava(folder, -18, 12)
	lava(folder, 58, -12)
	movingBoulder = boulder(folder, 0, 82, true)

	for index, checkpoint in cfg.checkpoints do
		local marker = part(
			folder,
			"Checkpoint" .. index,
			point(0, checkpoint.z, 0.2),
			Vector3.new(cfg.checkpointHalfWidth * 2, 0.3, cfg.checkpointHalfDepth * 2),
			Color3.fromRGB(255, 208, 85),
			Enum.Material.Neon,
			false
		)
		local rewardText = if index == 1
			then "+50 Stone"
			elseif index == 2 then "+40 Stone, +5 Copper"
			else "+30 Stone, +10 Copper"
		sign(marker, `CHECKPOINT {index}/3 | {rewardText}`, 330)
	end
	return entry, leave
end

local function teleportTo(golem: GolemService.Golem, destination: Vector3)
	golem.humanoid:Move(Vector3.zero)
	golem.model:PivotTo(CFrame.new(destination + Vector3.new(0, golem.groundOffset, 0)))
	golem.root.AssemblyLinearVelocity = Vector3.zero
	golem.root.AssemblyAngularVelocity = Vector3.zero
end

local function finish(player: Player, message: string)
	if not runs[player] then
		return
	end
	runs[player] = nil
	local golem = GolemService.get(player)
	if golem and golem.zoneId == Config.Gauntlet.zoneId then
		GolemService.sendToZone(golem, Config.HubZone)
	end
	if player.Parent then
		Remotes.Notify:FireClient(player, "gauntletEnd", message)
		say(player, message)
	end
end

local function startRun(player: Player): (boolean, string?)
	local cfg = Config.Gauntlet
	if not cfg.enabled then
		return false, "The Golem Run is closed"
	end
	if runs[player] then
		return false, "You're already on the run"
	end
	local now = os.clock()
	if now < (cooldownUntil[player] or 0) then
		return false, `The run opens again in {math.ceil((cooldownUntil[player] :: number) - now)}s`
	end
	local golem = GolemService.get(player)
	if not DataService.get(player) or not golem or not golem.mounted or not GolemService.isActive(golem) then
		return false, "Mount an active golem to enter"
	end
	if golem.zoneId ~= Config.HubZone or not GauntletRules.nearXZ(golem.root.Position, gatePosition, 29) then
		return false, "Ride to the Golem Run portal in the Hub"
	end
	cooldownUntil[player] = now + cfg.cooldownSeconds
	GolemService.sendToZone(golem, cfg.zoneId)
	local start = point(0, cfg.startZ, 0)
	teleportTo(golem, start)
	runs[player] = {
		nextIndex = 1,
		safe = start,
		expiresAt = now + cfg.durationSeconds,
		graceUntil = now + 1,
	}
	Remotes.Notify:FireClient(
		player,
		"gauntletStart",
		workspace:GetServerTimeNow() + cfg.durationSeconds,
		#cfg.checkpoints
	)
	say(player, "Golem Run! 90s to reach three checkpoints. Dodge boulders and use the green lava gaps.")
	return true, nil
end

local function hazard(position: Vector3, movingPosition: Vector3): boolean
	local cfg = Config.Gauntlet
	if math.abs(position.X - cfg.center.X) > cfg.laneHalfWidth then
		return true
	end
	if position.Z < cfg.center.Z + cfg.startZ - 12 or position.Z > cfg.center.Z + 127 then
		return true
	end
	for _, b in staticBoulders do
		if GauntletRules.nearXZ(position, b, cfg.boulderRadius) then
			return true
		end
	end
	if GauntletRules.nearXZ(position, movingPosition, cfg.boulderRadius) then
		return true
	end
	return GauntletRules.inLava(position, cfg.center.Z - 18, cfg.center.X + 12, cfg.lavaHalfDepth, cfg.lavaGapHalfWidth)
		or GauntletRules.inLava(position, cfg.center.Z + 58, cfg.center.X - 12, cfg.lavaHalfDepth, cfg.lavaGapHalfWidth)
end

function GauntletService.tick()
	local cfg = Config.Gauntlet
	local now = os.clock()
	local moving = movingBoulder
	if not moving then
		return
	end
	moving.Position = point(math.sin(now * 1.5) * 15, 82, 5)
	for player, run in runs do
		local golem = GolemService.get(player)
		if not player.Parent or not golem or golem.zoneId ~= cfg.zoneId then
			runs[player] = nil -- travel/disconnect forfeits unpaid checkpoints
			continue
		end
		if not golem.mounted or not GolemService.isActive(golem) then
			finish(player, "Golem Run ended. Earned checkpoint rewards are yours to keep.")
			continue
		end
		if now > run.expiresAt then
			finish(player, "Time's up! Keep your earned checkpoint rewards.")
			continue
		end
		local position = golem.root.Position
		if now >= run.graceUntil and hazard(position, moving.Position) then
			teleportTo(golem, run.safe)
			run.graceUntil = now + 1.25
			say(player, "Hazard! Back to your last checkpoint; earned rewards are safe.")
			continue
		end
		for index, checkpoint in cfg.checkpoints do
			if
				GauntletRules.canClaim(
					run.nextIndex,
					index,
					position,
					point(0, checkpoint.z, 0),
					cfg.checkpointHalfWidth,
					cfg.checkpointHalfDepth,
					now,
					run.expiresAt
				)
			then
				run.nextIndex += 1 -- consume before granting: no replay/duplicate payout
				run.safe = point(0, checkpoint.z, 0)
				EconomyService.grantFlat(player, { minerals = checkpoint.reward }, "gauntlet")
				Remotes.Notify:FireClient(player, "gauntletCheckpoint", index, #cfg.checkpoints)
				if index == #cfg.checkpoints then
					finish(player, "Golem Run complete! All three fixed checkpoint rewards earned.")
				else
					say(player, `Checkpoint {index}/3! Fixed minerals awarded. Keep riding!`)
				end
				break
			end
		end
	end
end

function GauntletService.start()
	if not Config.Gauntlet.enabled then
		return
	end
	local entry, leave = buildCourse()
	entry.Triggered:Connect(function(player: Player)
		local ok, reason = startRun(player)
		if not ok and reason then
			say(player, reason)
		end
	end)
	leave.Triggered:Connect(function(player: Player)
		if runs[player] then
			finish(player, "You left the run. Earned checkpoint rewards are yours to keep.")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
		cooldownUntil[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Gauntlet.tickSeconds)
			GauntletService.tick()
		end
	end)
end

return GauntletService
