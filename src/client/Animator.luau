--!strict
-- Procedural animation for golems and enemies, run on each client. The server
-- builds models with Motor6D joints tagged with a Kind attribute (see
-- Build.rig); this module bends those joints every frame from how fast the
-- model is moving, so nothing has to be uploaded as an animation asset.
-- The server also sets model attributes that trigger one-off moves:
--   Attack (counter)  punch with alternating arms, or lunge and bite
--   SlamAt (time)     raise both arms, then slam down when the time comes
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
	phase: number,
	walk: number, -- 0 standing still, 1 full walk
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
	-- With streaming on, parts can arrive after the model; rescan when they do.
	model.DescendantAdded:Once(function()
		rigs[model] = nil
	end)
	return {
		model = model,
		root = root,
		joints = joints,
		stride = (model:GetAttribute("Stride") :: number?) or 4,
		phase = 0,
		walk = 0,
		lastPosition = root.Position,
		attackAt = 0,
		attackSide = 1,
		lastAttack = (model:GetAttribute("Attack") :: number?) or 0,
		cheerAt = 0,
		lastCheer = (model:GetAttribute("Cheer") :: number?) or 0,
		idleOffset = math.random() * 10,
	}
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
		speed, moved = 0, 0 -- teleported (travel, respawn)
	end
	local target = math.clamp(speed / 6, 0, 1)
	rig.walk += (target - rig.walk) * math.min(dt * 8, 1)
	local before = math.floor(rig.phase / math.pi)
	rig.phase = (rig.phase + moved / rig.stride * math.pi * 2) % (math.pi * 2)
	-- A foot lands twice per cycle, when the swing passes through the middle.
	if rig.walk > 0.4 and math.floor(rig.phase / math.pi) ~= before then
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
			transform = CFrame.Angles(swing * 0.6 * joint.side * joint.amp, 0, 0)
			if downed then
				transform = CFrame.Angles(math.rad(-35), 0, 0)
			end
		elseif kind == "arm" then
			-- Positive X rotation swings a hanging arm forward.
			local angle = -swing * 0.45 * joint.side * joint.amp
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
			local y = bob * 0.04 * size + breathe * 0.01 * size - smash * 0.06 * size
			transform = CFrame.new(0, y, -lunge) * CFrame.Angles(-punch * 0.12 + raise * 0.15 - smash * 0.25, 0, swing * 0.04)
			if downed then
				transform = CFrame.new(0, -0.12 * size, 0) * CFrame.Angles(-0.35, 0, 0)
			end
		elseif kind == "head" then
			transform = CFrame.Angles(breathe * 0.05 - bob * 0.04 - punch * 0.1, math.sin(now * 0.7 + rig.idleOffset) * 0.12 * (1 - rig.walk), 0)
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
