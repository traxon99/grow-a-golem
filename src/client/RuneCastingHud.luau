--!strict
-- Separate optional rune-casting overlay; does not modify the claimed HUD.
-- Touch taps, keyboard 1/2/3, and gamepad X/Y/B all send only rune indices.
-- The server reveals the sequence and grades each press on its own clock.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Controls = require(script.Parent:WaitForChild("Controls"))

local RuneCastingHud = {}

function RuneCastingHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RuneCastingHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 9
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local startButton = Instance.new("TextButton")
	startButton.Name = "RuneCast"
	startButton.AnchorPoint = Vector2.new(1, 0)
	startButton.Position = UDim2.new(1, -12, 0, 110)
	startButton.Size = UDim2.fromOffset(154, 44)
	startButton.BackgroundColor3 = Color3.fromRGB(80, 57, 144)
	startButton.TextColor3 = Color3.new(1, 1, 1)
	startButton.Font = Enum.Font.GothamBold
	startButton.TextSize = 15
	startButton.Text = "RUNE CAST"
	startButton.Parent = gui
	local startCorner = Instance.new("UICorner")
	startCorner.CornerRadius = UDim.new(0, 8)
	startCorner.Parent = startButton

	local hint = Instance.new("TextLabel")
	hint.Name = "RuneHint"
	hint.AnchorPoint = Vector2.new(1, 0)
	hint.Position = UDim2.new(1, -12, 0, 156)
	hint.Size = UDim2.fromOffset(200, 40)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.fromRGB(246, 229, 177)
	hint.TextStrokeTransparency = 0.4
	hint.TextSize = 13
	hint.Font = Enum.Font.GothamBold
	hint.TextWrapped = true
	hint.Text = "T / L2 · 3 runes = +50% attack for 8s"
	hint.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "RuneChallenge"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 70)
	panel.Size = UDim2.new(0.94, 0, 0, 164)
	panel.BackgroundColor3 = Color3.fromRGB(28, 31, 54)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(350, 164)
	sizeLimit.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(7, 9, 18)
	stroke.Thickness = 3
	stroke.Parent = panel

	local instruction = Instance.new("TextLabel")
	instruction.Name = "RuneOrder"
	instruction.Position = UDim2.fromOffset(8, 6)
	instruction.Size = UDim2.new(1, -16, 0, 42)
	instruction.BackgroundTransparency = 1
	instruction.Font = Enum.Font.GothamBold
	instruction.TextSize = 16
	instruction.TextColor3 = Color3.fromRGB(255, 221, 117)
	instruction.TextWrapped = true
	instruction.Text = "Rune order"
	instruction.Parent = panel

	local progress = Instance.new("TextLabel")
	progress.Name = "RuneProgress"
	progress.Position = UDim2.fromOffset(8, 48)
	progress.Size = UDim2.new(1, -16, 0, 26)
	progress.BackgroundTransparency = 1
	progress.Font = Enum.Font.Gotham
	progress.TextSize = 14
	progress.TextColor3 = Color3.new(1, 1, 1)
	progress.Text = "Tap rune 1 of 3"
	progress.Parent = panel

	local active = false
	local awaiting = false
	local nextRune = 1
	local sequence: { number } = {}
	local expiresAt = 0
	local cooldownUntil = 0
	local boostUntil = 0

	local function tap(index: number)
		if not active or awaiting or not Controls.isMounted() then
			return
		end
		awaiting = true
		Remotes.RuneInput:FireServer("tap", index)
	end

	for index = 1, 3 do
		local button = Instance.new("TextButton")
		button.Name = "Rune" .. index
		button.Position = UDim2.new((index - 1) / 3, 8, 0, 87)
		button.Size = UDim2.new(1 / 3, -16, 0, 58)
		button.BackgroundColor3 = Color3.fromRGB(113, 77, 186)
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 18
		button.Text = tostring(index)
		button.Parent = panel
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = button
		button.Activated:Connect(function()
			tap(index)
		end)
	end

	local function begin()
		if active or not Controls.isMounted() or workspace:GetServerTimeNow() < cooldownUntil then
			return
		end
		Remotes.RuneInput:FireServer("start")
	end

	startButton.Activated:Connect(begin)
	ContextActionService:BindActionAtPriority("RuneCastStart", function(_, state)
		if state == Enum.UserInputState.Begin then
			begin()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.T, Enum.KeyCode.ButtonL2)

	ContextActionService:BindActionAtPriority("RuneCastTap", function(_, state, input)
		if not active then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			local key = input.KeyCode
			if key == Enum.KeyCode.One or key == Enum.KeyCode.ButtonX then
				tap(1)
			elseif key == Enum.KeyCode.Two or key == Enum.KeyCode.ButtonY then
				tap(2)
			elseif key == Enum.KeyCode.Three or key == Enum.KeyCode.ButtonB then
				tap(3)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
		Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonB)

	Remotes.Notify.OnClientEvent:Connect(function(kind: any, a: any, b: any, c: any)
		if kind == "runeStart" then
			if type(a) ~= "table" or #a ~= 3 or type(b) ~= "number" or type(c) ~= "number" then
				return
			end
			for _, rune in a do
				if type(rune) ~= "number" or rune < 1 or rune > 3 then
					return
				end
			end
			sequence = a
			nextRune = 1
			awaiting = false
			active = true
			expiresAt = b
			cooldownUntil = workspace:GetServerTimeNow() + c
			instruction.Text = "Order: " .. table.concat(sequence, " - ")
			progress.Text = "Tap rune 1 of 3 · 8s to finish"
			panel.Visible = true
			hint.Text = "Match the order · no penalty for missing"
		elseif kind == "runeStep" and active and type(a) == "number" then
			nextRune = a + 1
			awaiting = false
			progress.Text = "Tap rune " .. nextRune .. " of 3"
		elseif kind == "runeResult" then
			active = false
			awaiting = false
			panel.Visible = false
			if a == true and type(b) == "number" then
				boostUntil = workspace:GetServerTimeNow() + b
				hint.Text = "+50% auto-attack damage active!"
			elseif type(b) == "string" then
				hint.Text = b
			end
		elseif kind == "runeCooldown" and type(a) == "number" then
			cooldownUntil = workspace:GetServerTimeNow() + a
			hint.Text = "Rune casting recharging"
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local mounted = Controls.isMounted()
		startButton.Visible = mounted
		hint.Visible = mounted
		if active and (not mounted or now > expiresAt) then
			active = false
			awaiting = false
			panel.Visible = false
			hint.Text = "Rune faded (no penalty)"
		end
		startButton.Active = mounted and not active and now >= cooldownUntil
		if now < boostUntil then
			startButton.Text = "BOOST " .. math.ceil(boostUntil - now) .. "s"
		elseif now < cooldownUntil then
			startButton.Text = "RUNE " .. math.ceil(cooldownUntil - now) .. "s"
		else
			startButton.Text = "RUNE CAST"
		end
		if active then
			progress.Text = "Rune " .. nextRune .. " of 3 · " .. math.max(0, math.ceil(expiresAt - now)) .. "s"
		end
	end)
end

return RuneCastingHud
