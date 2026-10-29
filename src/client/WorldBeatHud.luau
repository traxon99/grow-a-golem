--!strict
-- Small independent gameplay banner, kept separate from Hud.luau while
-- the stud-restyle owns that file. No purchase links or urgency prompts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldBeat = require(Shared:WaitForChild("WorldBeat"))

local WorldBeatHud = {}

local function clock(seconds: number): string
	local minutes = math.floor(seconds / 60)
	return string.format("%d:%02d", minutes, seconds % 60)
end

function WorldBeatHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WorldBeatHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "MineralSurge"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 140) -- below the health and boss bars
	frame.Size = UDim2.new(0.8, 0, 0, 54)
	frame.BackgroundColor3 = Color3.fromRGB(30, 35, 52)
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(350, 54)
	sizeLimit.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = frame
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(12, 15, 24)
	outline.Thickness = 3
	outline.Parent = frame

	local lip = Instance.new("Frame")
	lip.Name = "BottomLip"
	lip.AnchorPoint = Vector2.new(0, 1)
	lip.Position = UDim2.fromScale(0, 1)
	lip.Size = UDim2.new(1, 0, 0, 7)
	lip.BackgroundColor3 = Color3.fromRGB(17, 22, 36)
	lip.BorderSizePixel = 0
	lip.Parent = frame
	local lipCorner = Instance.new("UICorner")
	lipCorner.CornerRadius = UDim.new(0, 7)
	lipCorner.Parent = lip

	local label = Instance.new("TextLabel")
	label.Name = "Countdown"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -16, 1, -8)
	label.Position = UDim2.fromOffset(8, 0)
	label.Font = Enum.Font.BuilderSansBold
	label.TextColor3 = Color3.fromRGB(255, 221, 126)
	label.TextSize = 17
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = frame
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 17
	textLimit.MinTextSize = 12
	textLimit.Parent = label

	task.spawn(function()
		while gui.Parent do
			-- Display only. Reward authority is WorldBeat.miningMultiplier(os.time())
			-- in EconomyService, never a client timestamp or remote request.
			local phase, remaining = WorldBeat.phase(workspace:GetServerTimeNow())
			frame.Visible = phase ~= "idle"
			if phase == "active" then
				label.Text =
					`MINERAL SURGE! {Config.WorldBeat.miningMultiplier}x node yields · {clock(remaining)} left`
			elseif phase == "warning" then
				label.Text = `Mineral surge in {clock(remaining)} · {Config.WorldBeat.miningMultiplier}x node yields`
			end
			task.wait(0.25)
		end
	end)
end

return WorldBeatHud
