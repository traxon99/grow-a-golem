--!strict
-- Turns the player's normal movement input (WASD, thumbstick, or the mobile
-- joystick) into a camera-relative steering direction for their golem.
-- Only the intent is sent; the server moves the golem.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local SEND_INTERVAL = 0.1

local Controls = {}

local player = Players.LocalPlayer

function Controls.castSpell(spellId: string)
	Remotes.CastSpell:FireServer(spellId)
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
	-- Riders can't jump off; the jump button would just unseat them.
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
end

function Controls.start()
	local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
	local controls = playerModule:GetControls()

	local elapsed = 0
	local lastSent = Vector3.zero
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < SEND_INTERVAL then
			return
		end
		elapsed = 0

		local direction = cameraRelative(controls:GetMoveVector())
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

	ContextActionService:BindAction("CastQuake", function(_, state)
		if state == Enum.UserInputState.Begin then
			Controls.castSpell("quake")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
end

return Controls
