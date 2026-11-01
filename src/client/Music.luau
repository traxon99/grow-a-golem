--!strict
-- Background music. Picks a track from Config.Music.areas for where the
-- player is (hub, tower, a boss fight, or an island) and fades between
-- tracks. The player's music setting (social.musicVolume) scales it, and is
-- separate from sound effects (docs/reference/art-audio.md rule 6).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Stats = require(Shared:WaitForChild("Stats"))
local State = require(script.Parent:WaitForChild("State"))

local Music = {}

local player = Players.LocalPlayer
local music = Config.Music

local sounds: { [string]: Sound } = {}
local current: string? = nil
local lastSetting = 1

-- True while this island's boss is alive and close, the same test as the boss bar.
local function nearBoss(zoneId: number): boolean
	local folder = workspace:FindFirstChild("Enemies")
	local character = player.Character
	local me = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not folder or not me then
		return false
	end
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("BossZone") == zoneId then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model.PrimaryPart
			if humanoid and humanoid.Health > 0 and root then
				return (root.Position - me.Position).Magnitude < music.bossRange
			end
		end
	end
	return false
end

-- The track key for where the player is now, or nil for silence.
local function pickTrack(): string?
	local snap = State.snapshot
	if not (snap and snap.golem) then
		return music.areas.hub
	end
	local zoneId = snap.golem.zoneId
	if type(zoneId) ~= "number" or zoneId == Config.HubZone then
		return music.areas.hub
	elseif Stats.isTowerZone(zoneId) then
		return music.areas.tower
	elseif nearBoss(zoneId) then
		return music.areas.boss
	end
	return music.areas[zoneId]
end

local function setting(): number
	local snap = State.snapshot
	local level = snap and snap.data and snap.data.social and snap.data.social.musicVolume
	return if type(level) == "number" then level else 1
end

local function targetVolume(key: string): number
	local track = music.tracks[key]
	return music.volume * (track.volume or 1) * setting()
end

local function soundFor(key: string): Sound?
	local existing = sounds[key]
	if existing then
		return existing
	end
	local track = music.tracks[key]
	if not track or track.id == 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = `Music_{key}`
	sound.SoundId = `rbxassetid://{track.id}`
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sounds[key] = sound
	return sound
end

local function fade(sound: Sound, volume: number)
	local tween = TweenService:Create(sound, TweenInfo.new(music.fadeSeconds), { Volume = volume })
	tween:Play()
	if volume == 0 then
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed and sound.Volume == 0 then
				sound:Pause()
			end
		end)
	end
end

local function update()
	local key = pickTrack()
	local level = setting()
	if key ~= current then
		local old = current and sounds[current]
		if old then
			fade(old, 0)
		end
		current = key
		local sound = key and soundFor(key)
		if sound then
			-- Coming back to an area picks its track up where it paused.
			if not sound.IsPlaying then
				sound:Resume()
			end
			fade(sound, targetVolume(key :: string))
		end
	elseif key and level ~= lastSetting then
		local sound = sounds[key]
		if sound then
			if not sound.IsPlaying then
				sound:Resume()
			end
			fade(sound, targetVolume(key))
		end
	end
	lastSetting = level
end

function Music.start()
	task.spawn(function()
		while true do
			update()
			task.wait(0.5)
		end
	end)
end

return Music
