--!strict
-- Independent Golem Run status banner. Display only: the server decides
-- checkpoint order, hazard resets, timeouts and every fixed mineral payout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local GauntletHud = {}

local function clock(seconds: number): string
	local value = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(value / 60), value % 60)
end

local function nextReward(index: number): string
	if index == 0 then
		return "Next: +50 Stone"
	elseif index == 1 then
		return "Next: +40 Stone, +5 Copper"
	end
	return "Next: +30 Stone, +10 Copper"
end

function GauntletHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GauntletHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 10
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "RunCountdown"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 202)
	frame.Size = UDim2.new(0.9, 0, 0, 64)
	frame.BackgroundColor3 = Color3.fromRGB(31, 39, 55)
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(410, 64)
	limit.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = frame
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(12, 16, 26)
	outline.Thickness = 3
	outline.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.Position = UDim2.fromOffset(8, 3)
	label.Size = UDim2.new(1, -16, 1, -6)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextColor3 = Color3.fromRGB(255, 221, 126)
	label.TextSize = 17
	label.TextWrapped = true
	label.TextScaled = true
	label.Parent = frame

	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 17
	textLimit.MinTextSize = 12
	textLimit.Parent = label

	local deadline = 0
	local completed = 0
	local total = 3

	Remotes.Notify.OnClientEvent:Connect(function(kind: any, first: any, second: any)
		if kind == "gauntletStart" and type(first) == "number" and type(second) == "number" then
			deadline = first
			completed = 0
			total = second
			frame.Visible = true
		elseif kind == "gauntletCheckpoint" and type(first) == "number" then
			completed = math.max(completed, math.min(first, total))
		elseif kind == "gauntletEnd" then
			frame.Visible = false
		end
	end)

	task.spawn(function()
		while gui.Parent do
			if frame.Visible then
				local left = deadline - workspace:GetServerTimeNow()
				if left < -3 then
					frame.Visible = false
				else
					label.Text = `GOLEM RUN {completed}/{total} · {clock(left)} left\n{nextReward(completed)} · Dodge red, use green gaps`
				end
			end
			task.wait(0.2)
		end
	end)
end

return GauntletHud
