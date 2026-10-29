--!strict
-- Turns the player's normal movement input (WASD, thumbstick, or the mobile
-- joystick) into a camera-relative steering direction for their golem.
-- Only the intent is sent; the server moves the golem.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local SEND_INTERVAL = 0.1
local SPRINT_KEY = Enum.KeyCode.LeftShift
local SPRINT_GAMEPAD_KEY = Enum.KeyCode.ButtonL3

local Controls = {}

local player = Players.LocalPlayer

-- Sprinting is held (Shift, L3) or toggled (the HUD Sprint button, for touch).
-- The server only speeds the golem up while the rider is steering.
local sprinting = false
local sprintChanged = Instance.new("BindableEvent")
Controls.SprintChanged = sprintChanged.Event

function Controls.isSprinting(): boolean
	return sprinting
end

function Controls.setSprint(on: boolean)
	if on == sprinting then
		return
	end
	sprinting = on
	Remotes.SprintGolem:FireServer(on)
	sprintChanged:Fire(on)
end

function Controls.toggleSprint()
	Controls.setSprint(not sprinting)
end

function Controls.castSpell(spellId: string)
	Remotes.CastSpell:FireServer(spellId)
end

-- The server publishes whether the rider is on the golem; it starts mounted.
function Controls.isMounted(): boolean
	return player:GetAttribute("GolemMounted") ~= false
end

function Controls.toggleMount()
	Remotes.MountGolem:FireServer(not Controls.isMounted())
end

local function cameraRelative(move: Vector3): Vector3
	local camera = workspace.CurrentCamera
	if not camera or move.Magnitude < 0.05 then
		return Vector3.zero
	end
	local look = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector
	local forward = Vector3.new(look.X, 0, look.Z)
	local side = Vector3.new(right.X, 0, right.Z)
	if forward.Magnitude < 0.01 or side.Magnitude < 0.01 then
		return Vector3.zero
	end
	-- GetMoveVector uses -Z for "forward".
	local direction = side.Unit * move.X + forward.Unit * -move.Z
	if direction.Magnitude > 1 then
		direction = direction.Unit
	end
	return direction
end

local function onCharacter(character: Model)
	-- Mounted riders can't jump off; the jump button would just unseat them.
	-- A dismounted rider walks and jumps like any character.
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not Controls.isMounted())
end

-- Used only if Roblox's PlayerModule isn't available: reads WASD/arrow keys
-- and the gamepad left stick directly, in GetMoveVector's format.
local function fallbackMoveVector(): Vector3
	local x, z = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		z -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		z += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		x -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		x += 1
	end
	if x ~= 0 or z ~= 0 then
		return Vector3.new(x, 0, z)
	end
	for _, input in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if input.KeyCode == Enum.KeyCode.Thumbstick1 and input.Position.Magnitude > 0.2 then
			return Vector3.new(input.Position.X, 0, -input.Position.Y)
		end
	end
	return Vector3.zero
end

local function getMoveVectorSource(): () -> Vector3
	local playerScripts = player:WaitForChild("PlayerScripts")
	local moduleScript = playerScripts:WaitForChild("PlayerModule", 10)
	if moduleScript and moduleScript:IsA("ModuleScript") then
		local ok, controls = pcall(function()
			return (require(moduleScript) :: any):GetControls()
		end)
		if ok and controls then
			return function()
				return controls:GetMoveVector()
			end
		end
	end
	warn("[Controls] PlayerModule not found; using keyboard/gamepad fallback (no mobile joystick).")
	return fallbackMoveVector
end

function Controls.start()
	local getMoveVector = getMoveVectorSource()

	local elapsed = 0
	local lastSent = Vector3.zero
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < SEND_INTERVAL then
			return
		end
		elapsed = 0

		-- Dismounted, the stick walks the rider, not the golem.
		local direction = if Controls.isMounted() then cameraRelative(getMoveVector()) else Vector3.zero
		-- Keep sending while steering (the server times out after 0.5 s),
		-- and send one zero when the player lets go.
		if direction.Magnitude > 0 or lastSent.Magnitude > 0 then
			Remotes.MoveGolem:FireServer(direction)
			lastSent = direction
		end
	end)

	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	player:GetAttributeChangedSignal("GolemMounted"):Connect(function()
		-- Dismounting ends the server's sprint; say again if it is still wanted.
		if sprinting and Controls.isMounted() then
			Remotes.SprintGolem:FireServer(true)
		end
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end)

	ContextActionService:BindAction("ToggleMount", function(_, state)
		if state == Enum.UserInputState.Begin then
			Controls.toggleMount()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR1)

	ContextActionService:BindAction("Sprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			Controls.setSprint(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			Controls.setSprint(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, SPRINT_KEY, SPRINT_GAMEPAD_KEY)

	local gamepadButtons = { Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonB }
	for index, spellId in Config.SpellOrder do
		local spell = Config.Spells[spellId]
		ContextActionService:BindAction("Cast_" .. spellId, function(_, state)
			if state == Enum.UserInputState.Begin then
				Controls.castSpell(spellId)
			end
			return Enum.ContextActionResult.Sink
		end, false, spell.key, gamepadButtons[index])
	end
end

return Controls
