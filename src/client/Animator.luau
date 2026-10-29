--!strict
-- Procedural animation for golems and enemies, run on each client. The server
-- builds models with Motor6D joints tagged with a Kind attribute (see
-- Build.rig); this module bends those joints every frame from how fast the
-- model is moving, so nothing has to be uploaded as an animation asset.
-- The server also sets model attributes that trigger one-off moves:
--   Attack (counter)  punch with alternating arms, or lunge and bite
--   SlamAt (time)     raise both arms, then slam down when the time comes
--   QuakeAt (time)    the golem's Quake slam lands then: arms rise (slowing as against
--                     gravity), then fall faster and faster into the slam
--   Sprinting (bool)  longer stride, harder lean and heavier steps
--   Downed (bool)     slump while the golem reforms
--   Cheer (counter)   the golem's pet hops and spins

local RunService = game:GetService("RunService")

local Sfx = require(script.Parent:WaitForChild("Sfx"))

local Animator = {}

type Joint = {
	motor: Motor6D,
	kind: string,
	side: number,
	amp: number,
	speed: number,
}

type Rig = {
	model: Model,
	root: BasePart,
	joints: { Joint },
	stride: number,
	legLength: number?, -- hip to sole; when set, feet are planted (see plantedStep)
	phase: number,
	walk: number, -- 0 standing still, 1 full walk
	speed: number, -- smoothed ground speed, studs per second
	sprint: number, -- 0 walking, 1 full sprint (eased)
	lastPosition: Vector3,
	attackAt: number,
	attackSide: number,
	lastAttack: number,
	cheerAt: number,
	lastCheer: number,
	idleOffset: number,
}

local MAX_DISTANCE = 260 -- don't animate models farther than this from the camera
local ATTACK_TIME = 0.35
local CHEER_TIME = 0.6
local QUAKE_RISE = 0.6 -- share of the Quake windup spent raising the arms
local QUAKE_RECOIL = 0.35 -- seconds the body settles after the slam lands

local rigs: { [Model]: Rig } = {}

local function makeRig(model: Model): Rig?
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local joints: { Joint } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local kind = descendant:GetAttribute("Kind")
			if type(kind) == "string" then
				table.insert(joints, {
					motor = descendant,
					kind = kind,
					side = (descendant:GetAttribute("Side") :: number?) or 1,
					amp = (descendant:GetAttribute("Amp") :: number?) or 1,
					speed = (descendant:GetAttribute("Speed") :: number?) or 1,
				})
			end
		end
	end
	if #joints == 0 then
		return nil
	end
	-- With streaming on, joints can arrive after the model; rescan when one
	-- does. Only joints count: footstep sounds and effects are parented into
	-- the model all the time, and rescanning for those restarted the walk
	-- cycle on every step.
	local connection: RBXScriptConnection
	connection = model.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Motor6D") then
			connection:Disconnect()
			rigs[model] = nil
		end
	end)
	return {
		model = model,
		root = root,
		joints = joints,
		stride = (model:GetAttribute("Stride") :: number?) or 4,
		legLength = model:GetAttribute("LegLength") :: number?,
		phase = 0,
		walk = 0,
		speed = 0,
		sprint = 0,
		lastPosition = root.Position,
		attackAt = 0,
		attackSide = 1,
		lastAttack = (model:GetAttribute("Attack") :: number?) or 0,
		cheerAt = 0,
		lastCheer = (model:GetAttribute("Cheer") :: number?) or 0,
		idleOffset = math.random() * 10,
	}
end

-- One leg of a planted gait, for a leg `legLength` long. `p` runs 0 to 2 pi:
-- the first half the foot is on the ground and slides back exactly as fast
-- as the body moves forward, so it doesn't skate; the second half it lifts
-- and swings forward. Returns the hip angle (positive swings forward) and
-- how far to raise the leg.
local function plantedStep(p: number, stride: number, legLength: number): (number, number)
	local reach = stride / 4 -- the foot travels half a stride under the hip
	local x, lift
	if p < math.pi then
		x = reach * (1 - 2 * p / math.pi)
		lift = 0
	else
		local u = (p - math.pi) / math.pi
		x = reach * -math.cos(u * math.pi)
		lift = math.sin(u * math.pi) * legLength * 0.2
	end
	return math.asin(math.clamp(x / legLength, -0.9, 0.9)), lift
end

-- The walk cycle's step number; it changes as a foot lands.
local function stepIndex(phase: number): number
	return math.floor(((phase - math.pi / 2) % (math.pi * 2)) / math.pi)
end

-- Smooth 0 -> 1 -> 0 bump over the attack time.
local function pulse(t: number): number
	if t < 0 or t > 1 then
		return 0
	end
	return math.sin(t * math.pi)
end

local function animate(rig: Rig, dt: number, now: number, serverNow: number)
	local position = rig.root.Position
	local moved = ((position - rig.lastPosition) * Vector3.new(1, 0, 1)).Magnitude
	rig.lastPosition = position
	local speed = if dt > 0 then moved / dt else 0
	if speed > 200 then
		speed = 0 -- teleported (travel, respawn)
	end
	-- Replicated positions arrive unevenly, so frame-to-frame speed jitters by
	-- a third; step from the smoothed speed so the gait doesn't stutter.
	rig.speed += (speed - rig.speed) * math.min(dt * 10, 1)
	local target = math.clamp(rig.speed / 6, 0, 1)
	rig.walk += (target - rig.walk) * math.min(dt * 8, 1)
	-- Sprinting stretches the stride (the feet still plant, they just reach
	-- further), and the lean, arm swing and thud below grow with it.
	local sprintTarget = if rig.model:GetAttribute("Sprinting") == true then 1 else 0
	rig.sprint += (sprintTarget - rig.sprint) * math.min(dt * 5, 1)
	local sprint = rig.sprint * rig.walk
	local stride = rig.stride * (1 + 0.35 * sprint)
	local before = stepIndex(rig.phase)
	rig.phase = (rig.phase + rig.speed * dt / stride * math.pi * 2) % (math.pi * 2)
	-- A foot lands twice per cycle.
	if rig.walk > 0.4 and stepIndex(rig.phase) ~= before then
		Sfx.footstep(rig.model, rig.root)
	end

	local attack = (rig.model:GetAttribute("Attack") :: number?) or 0
	if attack ~= rig.lastAttack then
		rig.lastAttack = attack
		rig.attackAt = now
		rig.attackSide = -rig.attackSide
	end
	local punch = pulse((now - rig.attackAt) / ATTACK_TIME)

	-- Slam: raise both arms during the warning, then smash down.
	local slamAt = rig.model:GetAttribute("SlamAt") :: number?
	local raise, smash = 0, 0
	if slamAt then
		local untilSlam = slamAt - serverNow
		if untilSlam > 0 and untilSlam < 2 then
			raise = math.clamp(1 - untilSlam / 1.5, 0, 1)
		elseif untilSlam <= 0 and untilSlam > -0.4 then
			smash = 1 + untilSlam / 0.4
		end
	end
	-- Quake: the arms rise fast and slow to a stop at the top, as if against
	-- gravity, then drop with growing speed so the slam lands hard.
	local quakeAt = rig.model:GetAttribute("QuakeAt") :: number?
	if quakeAt then
		local windup = (rig.model:GetAttribute("QuakeWindup") :: number?) or 0.45
		local untilQuake = quakeAt - serverNow
		if untilQuake > 0 and untilQuake <= windup then
			local t = 1 - untilQuake / windup
			if t < QUAKE_RISE then
				local u = t / QUAKE_RISE
				raise = math.max(raise, 1 - (1 - u) * (1 - u))
			else
				local f = (t - QUAKE_RISE) / (1 - QUAKE_RISE)
				raise = math.max(raise, 1 - f * f)
			end
		elseif untilQuake <= 0 and untilQuake > -QUAKE_RECOIL then
			local u = 1 + untilQuake / QUAKE_RECOIL
			smash = math.max(smash, u * u)
		end
	end
	local downed = rig.model:GetAttribute("Downed") == true
	local cheerCount = (rig.model:GetAttribute("Cheer") :: number?) or 0
	if cheerCount ~= rig.lastCheer then
		rig.lastCheer = cheerCount
		rig.cheerAt = now
	end
	local cheerT = (now - rig.cheerAt) / CHEER_TIME
	local hop = pulse(cheerT)

	local swing = math.sin(rig.phase) * rig.walk
	local bob = math.abs(math.cos(rig.phase)) * rig.walk
	local breathe = math.sin(now * 2 + rig.idleOffset) * (1 - rig.walk)
	local size = rig.root.Size.Y

	for _, joint in rig.joints do
		local kind = joint.kind
		local transform = CFrame.identity
		if kind == "leg" then
			local legLength = rig.legLength
			if legLength then
				-- In step with `swing`: the right leg is furthest forward at
				-- phase pi / 2, as it lands. The left leg is half a cycle behind.
				local p = (rig.phase - math.pi / 2 + (if joint.side < 0 then math.pi else 0)) % (math.pi * 2)
				local angle, lift = plantedStep(p, stride, legLength)
				lift *= 1 + sprint
				transform = CFrame.new(0, lift * rig.walk, 0)
					* CFrame.Angles(angle * rig.walk * joint.amp, 0, joint.side * lift / legLength * 0.5 * rig.walk)
			else
				transform = CFrame.Angles(swing * 0.6 * joint.side * joint.amp, 0, 0)
			end
			if downed then
				transform = CFrame.Angles(math.rad(-35), 0, 0)
			end
		elseif kind == "arm" then
			-- Positive X rotation swings a hanging arm forward.
			local angle = -swing * 0.45 * (1 + 0.6 * sprint) * joint.side * joint.amp
			if punch > 0 and joint.side == rig.attackSide then
				angle += punch * 1.4
			end
			angle += raise * 2.6 + smash * 0.6
			if downed then
				angle = 0.3
			end
			transform = CFrame.Angles(angle, 0, joint.side * (0.06 + 0.04 * breathe))
		elseif kind == "body" then
			-- Negative X rotation leans the body forward.
			local lunge = punch * 0.06 * size
			local y = bob * 0.04 * (1 + 1.2 * sprint) * size + breathe * 0.01 * size - smash * 0.06 * size
			y += raise * 0.03 * size -- rises onto its toes as the arms go up
			-- Heavy gait: the body rolls over the planted leg and twists with the arms.
			transform = CFrame.new(-math.cos(rig.phase) * rig.walk * 0.03 * size, y, -lunge)
				* CFrame.Angles(
					-punch * 0.12 + raise * 0.15 - smash * 0.25 - rig.walk * 0.06 - sprint * 0.14,
					swing * 0.08,
					math.cos(rig.phase) * rig.walk * 0.06
				)
			if downed then
				transform = CFrame.new(0, -0.12 * size, 0) * CFrame.Angles(-0.35, 0, 0)
			end
		elseif kind == "head" then
			transform = CFrame.Angles(
				breathe * 0.05 - bob * 0.04 - punch * 0.1 + sprint * 0.12, -- eyes stay up while the body leans
				math.sin(now * 0.7 + rig.idleOffset) * 0.12 * (1 - rig.walk),
				0
			)
			if downed then
				transform = CFrame.Angles(-0.5, 0, 0)
			end
		elseif kind == "jaw" then
			-- Negative X rotation drops the front of the jaw (opens it).
			transform = CFrame.Angles(-(punch + raise) * 0.5 - 0.05 * (1 + breathe), 0, 0)
		elseif kind == "spin" then
			transform = CFrame.Angles(0, (now * joint.speed) % (math.pi * 2), 0)
		elseif kind == "pet" then
			-- Bobs beside the golem; on a win it hops and spins once.
			local y = math.sin(now * 2.2 + rig.idleOffset) * 0.35 * joint.amp + hop * 2
			local spin = if cheerT >= 0 and cheerT <= 1 then cheerT * math.pi * 2 else 0
			transform = CFrame.new(0, y, 0) * CFrame.Angles(math.sin(now * 1.3) * 0.08, spin, 0)
		elseif kind == "float" then
			local y = math.sin(now * joint.speed + rig.idleOffset) * joint.amp
			transform = CFrame.new(0, y, -punch * 0.4) * CFrame.Angles(0, now * 0.6 % (math.pi * 2), 0)
		end
		joint.motor.Transform = transform
	end
end

local function watch(folderName: string)
	local folder = workspace:WaitForChild(folderName)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			rigs[child] = nil
		end
	end)
end

function Animator.start()
	task.spawn(watch, "Golems")
	task.spawn(watch, "Enemies")

	RunService.PreSimulation:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		local serverNow = workspace:GetServerTimeNow()
		for _, folderName in { "Golems", "Enemies" } do
			local folder = workspace:FindFirstChild(folderName)
			if folder then
				for _, model in folder:GetChildren() do
					if model:IsA("Model") then
						local rig = rigs[model]
						if not rig then
							local made = makeRig(model)
							if not made then
								continue
							end
							rigs[model] = made
							rig = made
						end
						assert(rig)
						if (rig.root.Position - eye).Magnitude <= MAX_DISTANCE then
							animate(rig, dt, now, serverNow)
						end
					end
				end
			end
		end
	end)
end

return Animator
