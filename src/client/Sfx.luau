--!strict
-- Sound effects. Every effect is defined in Config.SoundEffects; this module
-- plays them in 3D on golems and enemies (so a fight across the island is
-- quieter than your own) or flat for menus and rewards. It listens for the
-- same server signals the Animator uses, plus Notify events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Sfx = {}

local player = Players.LocalPlayer

local MAX_HEARING = 160 -- 3D sounds fade out by this many studs
local MAX_PER_FRAME_WINDOW = 12 -- cap on sounds started per 0.1 s, so big fights don't clip

local recent = 0
local windowStart = 0

local function soundId(id: any): string?
	if type(id) == "number" then
		return if id ~= 0 then `rbxassetid://{id}` else nil
	elseif type(id) == "string" and id ~= "" then
		return id
	end
	return nil
end

local function makeSound(def: any): Sound?
	local id = soundId(def.id)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = def.volume or 0.5
	sound.PlaybackSpeed = def.speed or 1
	sound.Looped = def.loop == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = MAX_HEARING
	if def.distortion then
		local distortion = Instance.new("DistortionSoundEffect")
		distortion.Level = def.distortion
		distortion.Parent = sound
	end
	if def.reverb then
		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime = 1.2
		reverb.WetLevel = -6
		reverb.Parent = sound
	end
	if def.bass then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = 6
		eq.MidGain = -2
		eq.HighGain = -8
		eq.Parent = sound
	end
	return sound
end

local function allowed(): boolean
	local now = os.clock()
	if now - windowStart > 0.1 then
		windowStart = now
		recent = 0
	end
	recent += 1
	return recent <= MAX_PER_FRAME_WINDOW
end

-- Plays an effect by name. With `at`, the sound comes from that part.
function Sfx.play(name: string, at: BasePart?, volumeScale: number?)
	local def = Config.SoundEffects[name]
	if not def or not allowed() then
		return
	end
	if at then
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - at.Position).Magnitude > MAX_HEARING then
			return
		end
	end
	local sound = makeSound(def)
	if not sound then
		return
	end
	sound.Volume *= volumeScale or 1
	local length = def.length
	if at then
		sound.Parent = at
		sound:Play()
	else
		sound.Parent = SoundService
		sound:Play()
	end
	if length then
		task.delay(length, function()
			sound:Stop()
		end)
	end
	-- Ended doesn't fire for sounds that fail to load, so always clean up.
	task.delay(math.max(length or 0, 6), function()
		sound:Destroy()
	end)
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

-- The big moments use Config.Sounds when set, otherwise the built-in effect.
function Sfx.moment(name: string)
	local id = (Config.Sounds :: any)[name]
	if type(id) == "number" and id ~= 0 then
		local sound = Instance.new("Sound")
		sound.SoundId = `rbxassetid://{id}`
		sound.Volume = 0.6
		SoundService:PlayLocalSound(sound)
		task.delay(6, sound.Destroy, sound)
	else
		Sfx.play(name)
	end
end

local function myGolemRoot(): BasePart?
	local folder = workspace:FindFirstChild("Golems")
	local model = folder and folder:FindFirstChild(player.Name .. "_Golem")
	if model and model:IsA("Model") then
		return model.PrimaryPart
	end
	return nil
end

-- Golems and enemies tell clients when they attack or wind up a slam.
local function watchModel(model: Instance, isGolem: boolean)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("Attack"):Connect(function()
		local root = model.PrimaryPart
		if root then
			if not isGolem then
				Sfx.play("enemyAttack", root, 0.7)
			elseif model:GetAttribute("AttackKind") == "mine" then
				Sfx.play("mine", root)
			else
				Sfx.play("punch", root)
			end
		end
	end)
	model:GetAttributeChangedSignal("SlamAt"):Connect(function()
		local root = model.PrimaryPart
		local slamAt = model:GetAttribute("SlamAt") :: number?
		if not root or not slamAt then
			return
		end
		Sfx.play("slamWarn", root)
		task.delay(math.max(slamAt - workspace:GetServerTimeNow(), 0), function()
			if model.Parent and model.PrimaryPart then
				Sfx.play("slam", model.PrimaryPart)
			end
		end)
	end)
end

local function watchFolder(name: string, isGolem: boolean)
	local folder = workspace:WaitForChild(name)
	for _, child in folder:GetChildren() do
		watchModel(child, isGolem)
	end
	folder.ChildAdded:Connect(function(child)
		watchModel(child, isGolem)
	end)
end

-- Called by the Animator each time a foot lands.
function Sfx.footstep(model: Model, root: BasePart)
	local isGolem = model.Parent and model.Parent.Name == "Golems"
	if isGolem then
		Sfx.play("golemStep", root, math.clamp(root.Size.Y / 8, 0.6, 2))
	elseif model:GetAttribute("BossZone") then
		Sfx.play("bossStep", root)
	end
end

function Sfx.start()
	task.spawn(watchFolder, "Golems", true)
	task.spawn(watchFolder, "Enemies", false)

	local wind = makeSound(Config.SoundEffects.wind)
	if wind then
		wind.Parent = SoundService
		wind:Play()
	end

	Remotes.Notify.OnClientEvent:Connect(function(kind: string, ...)
		local args = { ... }
		if kind == "spellCast" then
			-- Quake's thud waits for the slam (quakeImpact below).
			if args[1] ~= "quake" then
				Sfx.play(args[1], myGolemRoot())
			end
		elseif kind == "quakeImpact" then
			if args[3] == player.UserId then
				Sfx.play("quake", myGolemRoot())
			end
		elseif kind == "mined" then
			Sfx.play("mineBreak", myGolemRoot())
		elseif kind == "defeated" then
			Sfx.play("defeat")
		elseif kind == "boss" then
			Sfx.play("quake")
		end
	end)

	player:GetAttributeChangedSignal("GolemDowned"):Connect(function()
		if player:GetAttribute("GolemDowned") == true then
			Sfx.play("downed")
		end
	end)
end

return Sfx
