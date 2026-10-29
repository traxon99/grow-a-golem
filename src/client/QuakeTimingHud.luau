--!strict
-- Independent timing cue so the claimed main HUD can be restyled separately.
-- A second Quake press is optional: missing or skipping it keeps normal damage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Controls = require(script.Parent:WaitForChild("Controls"))

local QuakeTimingHud = {}

function QuakeTimingHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "QuakeTimingHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 9
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "TimingPrompt"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -160)
	panel.Size = UDim2.new(0.9, 0, 0, 120)
	panel.BackgroundColor3 = Color3.fromRGB(24, 30, 43)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(340, 120)
	sizeLimit.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(6, 9, 15)
	stroke.Thickness = 3
	stroke.Parent = panel

	local instruction = Instance.new("TextLabel")
	instruction.Name = "Instruction"
	instruction.BackgroundTransparency = 1
	instruction.Position = UDim2.fromOffset(10, 5)
	instruction.Size = UDim2.new(1, -20, 0, 28)
	instruction.Font = Enum.Font.GothamBold
	instruction.TextSize = 15
	instruction.TextColor3 = Color3.fromRGB(255, 255, 255)
	instruction.Text = "Tap Quake again in gold: +50% damage"
	instruction.TextWrapped = true
	instruction.Parent = panel

	local track = Instance.new("Frame")
	track.Name = "TimingTrack"
	track.Position = UDim2.fromOffset(12, 37)
	track.Size = UDim2.new(1, -24, 0, 18)
	track.BackgroundColor3 = Color3.fromRGB(75, 81, 95)
	track.BorderSizePixel = 0
	track.Parent = panel

	local window = Instance.new("Frame")
	window.Name = "PerfectWindow"
	window.BackgroundColor3 = Color3.fromRGB(255, 204, 70)
	window.BorderSizePixel = 0
	window.Parent = track

	local progress = Instance.new("Frame")
	progress.Name = "Progress"
	progress.Size = UDim2.fromScale(0, 1)
	progress.BackgroundColor3 = Color3.fromRGB(115, 218, 255)
	progress.BackgroundTransparency = 0.2
	progress.BorderSizePixel = 0
	progress.ZIndex = 2
	progress.Parent = track

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(12, 66)
	status.Size = UDim2.new(1, -158, 0, 44)
	status.Font = Enum.Font.Gotham
	status.TextSize = 14
	status.TextWrapped = true
	status.TextColor3 = Color3.fromRGB(245, 245, 245)
	status.Text = "Normal damage if skipped"
	status.Parent = panel

	local button = Instance.new("TextButton")
	button.Name = "TapQuake"
	button.Position = UDim2.new(1, -146, 1, -51)
	button.Size = UDim2.fromOffset(136, 44)
	button.BackgroundColor3 = Color3.fromRGB(255, 204, 70)
	button.TextColor3 = Color3.fromRGB(24, 30, 43)
	button.Text = "TAP QUAKE"
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.Parent = panel
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = button
	button.Activated:Connect(function()
		Controls.castSpell("quake")
	end)

	local impactAt = 0
	local windup = 1
	Remotes.Notify.OnClientEvent:Connect(function(kind: any, a: any, b: any, c: any, d: any, e: any)
		if kind == "quakeTiming" then
			if type(a) ~= "number" or type(b) ~= "number" or type(c) ~= "number" or type(d) ~= "number" then
				return
			end
			if b <= 0 or not Controls.isMounted() then
				return
			end
			impactAt = a
			windup = b
			local left = math.clamp((b - c - d) / b, 0, 1)
			local right = math.clamp((b - c + d) / b, 0, 1)
			window.Position = UDim2.fromScale(left, 0)
			window.Size = UDim2.fromScale(right - left, 1)
			instruction.Text = if e == 1.5 then "Tap Quake again in gold: +50% damage" else "Tap Quake again in gold"
			status.Text = "Normal damage if skipped"
			button.Active = true
			panel.Visible = true
		elseif kind == "quakeTimingResult" and panel.Visible then
			status.Text = if a == true then "Perfect! +50% damage" else "Normal damage (no penalty)"
			button.Active = false
		elseif kind == "quakeTimingImpact" then
			panel.Visible = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not panel.Visible then
			return
		end
		if not Controls.isMounted() or workspace:GetServerTimeNow() >= impactAt then
			panel.Visible = false
			return
		end
		local elapsed = workspace:GetServerTimeNow() - (impactAt - windup)
		progress.Size = UDim2.fromScale(math.clamp(elapsed / windup, 0, 1), 1)
	end)
end

return QuakeTimingHud
