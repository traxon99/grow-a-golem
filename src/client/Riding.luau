--!strict
-- Riding, as the player sees it. Mounted, the golem is the main character:
-- the camera orbits it, framed and zoomed for its size (the player can still
-- zoom and orbit), and the rider sits on its shoulder in a riding pose
-- instead of walking. Dismounted, the camera, walking and jumping go back to
-- the character. The server decides when the rider is on (the GolemMounted
-- attribute, and the GolemRiderWeld it puts in the character, see
-- GolemService); this only presents it. Blends snap with Reduced Motion.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Controls = require(script.Parent:WaitForChild("Controls"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local Riding = {}

local player = Players.LocalPlayer

local RIDER_WELD = "GolemRiderWeld"
local MAX_BLEND_DISTANCE = 60 -- farther than this (a respawn), the rider just appears on the shoulder
-- Roblox's own sit animations, for characters whose Animate script has none.
local SIT_ANIMATIONS: { [Enum.HumanoidRigType]: string } = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://2506281703",
	[Enum.HumanoidRigType.R6] = "rbxassetid://178130996",
}

local walkingMinZoom = player.CameraMinZoomDistance
local walkingMaxZoom = player.CameraMaxZoomDistance
local walkingZoom = 12.5 -- the zoom to go back to on dismount; saved on mounting
local onGolem = false -- the camera is on the golem
local framedScale = 1
local rideTrack: AnimationTrack? = nil
local lastFree: CFrame? = nil -- the rider's root before it was welded on, to blend from

local function golemModel(): Model?
	local folder = workspace:FindFirstChild("Golems")
	local model = folder and folder:FindFirstChild(player.Name .. "_Golem")
	return if model and model:IsA("Model") then model else nil
end

local function scaleOf(model: Model): number
	return (model:GetAttribute("Scale") :: number?) or 1
end

local function blendInfo(): TweenInfo
	return TweenInfo.new(Config.Golem.mountBlendTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

local function currentZoom(): number
	local camera = workspace.CurrentCamera
	return if camera then (camera.CFrame.Position - camera.Focus.Position).Magnitude else walkingZoom
end

-- Moves the zoom to `distance` by pinning both limits there for a moment;
-- Roblox's camera eases over by itself, and afterwards the player zooms
-- freely between `minZoom` and `maxZoom` again.
local zoomToken = 0
local function zoomTo(distance: number, minZoom: number, maxZoom: number)
	zoomToken += 1
	local token = zoomToken
	distance = math.clamp(distance, minZoom, maxZoom)
	player.CameraMaxZoomDistance = math.max(distance, player.CameraMinZoomDistance)
	player.CameraMinZoomDistance = distance
	player.CameraMaxZoomDistance = distance
	task.delay(0.1, function()
		if token == zoomToken then
			player.CameraMinZoomDistance = minZoom
			player.CameraMaxZoomDistance = maxZoom
		end
	end)
end

-- The camera on the golem: its humanoid is the subject, the focus raised
-- toward its head, and the zoom limits grow with it. A growing golem keeps
-- the player's zoom in proportion.
local function frameGolem(model: Model, golemHumanoid: Humanoid, root: BasePart)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local scale = scaleOf(model)
	local offset = Vector3.new(0, Config.Golem.cameraHeight * scale, 0)
	local minZoom, maxZoom = Config.Golem.cameraMinZoom * scale, Config.Golem.cameraMaxZoom * scale
	if not onGolem then
		onGolem = true
		walkingZoom = currentZoom()
		-- Start the focus where it is now and ease it onto the golem.
		golemHumanoid.CameraOffset = root.CFrame:VectorToObjectSpace(camera.Focus.Position - root.Position)
		camera.CameraSubject = golemHumanoid
		Ui.tween(golemHumanoid, blendInfo(), { CameraOffset = offset })
		zoomTo(Config.Golem.cameraDistance * scale, minZoom, maxZoom)
	elseif scale ~= framedScale then
		Ui.tween(golemHumanoid, blendInfo(), { CameraOffset = offset })
		zoomTo(currentZoom() * scale / framedScale, minZoom, maxZoom)
	end
	framedScale = scale
end

-- The camera back on the character, easing over from the golem.
local function frameCharacter()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not onGolem or not camera or not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	onGolem = false
	humanoid.CameraOffset = root.CFrame:VectorToObjectSpace(camera.Focus.Position - root.Position)
	camera.CameraSubject = humanoid
	Ui.tween(humanoid, blendInfo(), { CameraOffset = Vector3.zero })
	zoomTo(walkingZoom, walkingMinZoom, walkingMaxZoom)
end

local function refreshCamera()
	local model = golemModel()
	local golemHumanoid = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and model.PrimaryPart
	if Controls.isMounted() and model and golemHumanoid and root then
		frameGolem(model, golemHumanoid, root)
	else
		frameCharacter()
	end
end

local function sitAnimationId(character: Model, humanoid: Humanoid): string
	local animate = character:FindFirstChild("Animate")
	local sit = animate and animate:FindFirstChild("sit")
	local animation = sit and sit:FindFirstChildOfClass("Animation")
	if animation and animation.AnimationId ~= "" then
		return animation.AnimationId
	end
	return SIT_ANIMATIONS[humanoid.RigType] or SIT_ANIMATIONS[Enum.HumanoidRigType.R15]
end

-- Eases the rider from where they stood onto the shoulder by starting the
-- weld's offset at their old spot. Only this client sees the slide.
local function blendOn(weld: Weld)
	local from = lastFree
	local golemRoot = weld.Part0
	if not from or not golemRoot then
		return
	end
	local seat = golemRoot.CFrame * weld.C0
	if (from.Position - seat.Position).Magnitude > MAX_BLEND_DISTANCE then
		return
	end
	local final = weld.C1
	-- Part1 = Part0 * C0 * C1:Inverse(), so this C1 leaves the rider where they were.
	weld.C1 = from:Inverse() * seat
	Ui.tween(weld, blendInfo(), { C1 = final })
end

-- The riding pose: the character stops balancing and walking (it is welded
-- on and collides with nothing, see GolemService) and plays a sit.
local function setRiding(character: Model, weld: Weld?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if weld then
		humanoid.PlatformStand = true
		if not rideTrack then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			local animation = Instance.new("Animation")
			animation.AnimationId = sitAnimationId(character, humanoid)
			local ok, track = pcall(function(): AnimationTrack?
				return if animator then animator:LoadAnimation(animation) else nil
			end)
			if ok and track then
				track.Priority = Enum.AnimationPriority.Action
				track.Looped = true
				track:Play(if Ui.reducedMotion() then 0 else 0.2)
				rideTrack = track
			end
		end
		blendOn(weld)
	else
		humanoid.PlatformStand = false
		if rideTrack then
			rideTrack:Stop(0.15)
			rideTrack = nil
		end
		if humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end

local function riderWeld(root: Instance): Weld?
	local weld = root:FindFirstChild(RIDER_WELD)
	return if weld and weld:IsA("Weld") then weld else nil
end

local function onCharacter(character: Model)
	rideTrack = nil
	lastFree = nil
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	root.ChildAdded:Connect(function(child)
		if child.Name == RIDER_WELD and child:IsA("Weld") then
			setRiding(character, child)
		end
	end)
	root.ChildRemoved:Connect(function(child)
		if child.Name == RIDER_WELD and not riderWeld(root) then
			setRiding(character, nil)
		end
	end)
	local weld = riderWeld(root)
	if weld then
		setRiding(character, weld)
	end
	-- A respawn hands the camera to the new character; the golem keeps it while mounted.
	task.defer(function()
		if onGolem then
			local model = golemModel()
			local golemHumanoid = model and model:FindFirstChildOfClass("Humanoid")
			local camera = workspace.CurrentCamera
			if golemHumanoid and camera then
				camera.CameraSubject = golemHumanoid
			end
		end
	end)
end

function Riding.start()
	player:GetAttributeChangedSignal("GolemMounted"):Connect(refreshCamera)
	task.spawn(function()
		local folder = workspace:WaitForChild("Golems")
		local function watch(model: Instance)
			if model.Name == player.Name .. "_Golem" and model:IsA("Model") then
				-- Size steps (forge, levels) reframe the camera; the model itself stays.
				model:GetAttributeChangedSignal("Scale"):Connect(refreshCamera)
				refreshCamera()
			end
		end
		folder.ChildAdded:Connect(watch)
		for _, model in folder:GetChildren() do
			watch(model)
		end
	end)

	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and not riderWeld(root) then
			lastFree = root.CFrame
		end
		-- Keep the camera on whichever body is in charge, whatever else
		-- (a respawn, the default camera scripts) moved it.
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local model = golemModel()
		local golemHumanoid = model and model:FindFirstChildOfClass("Humanoid")
		if onGolem and golemHumanoid and camera.CameraSubject ~= golemHumanoid then
			camera.CameraSubject = golemHumanoid
		elseif not onGolem and golemHumanoid and camera.CameraSubject == golemHumanoid then
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
	end)
end

return Riding
