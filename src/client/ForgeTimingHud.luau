--!strict
-- Optional one-tap anvil timing challenge after a manual forge has succeeded.
-- The part is already owned; skipping or missing never changes the craft.
-- No client time or claimed grade is sent to the server.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ForgeStrike = require(Shared:WaitForChild("ForgeStrike"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))
local State = require(script.Parent:WaitForChild("State"))

local ForgeTimingHud = {}

local function label(parent: Instance, name: string, text: string, y: number, height: number): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Position = UDim2.new(0, 12, 0, y)
	item.Size = UDim2.new(1, -24, 0, height)
	item.Font = Enum.Font.GothamBold
	item.TextSize = 15
	item.TextWrapped = true
	item.TextColor3 = Color3.fromRGB(255, 245, 224)
	item.Text = text
	item.Parent = parent
	return item
end

local function button(parent: Instance, name: string, text: string, x: number, color: Color3): TextButton
	local item = Instance.new("TextButton")
	item.Name = name
	item.Position = UDim2.new(x, 8, 1, -50)
	item.Size = UDim2.new(0.5, -16, 0, 42)
	item.BackgroundColor3 = color
	item.TextColor3 = Color3.fromRGB(255, 255, 255)
	item.Font = Enum.Font.GothamBold
	item.TextSize = 17
	item.Text = text
	item.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = item
	return item
end

local function refundText(slot: string, tier: string): string
	local cost = Stats.partCost(slot, tier)
	local refund = ForgeStrike.refund(cost, Config.ForgeStrike.refundFraction)
	local parts = {}
	for _, mineral in Config.MineralOrder do
		local amount = refund[mineral]
		if amount and amount > 0 then
			table.insert(parts, tostring(amount) .. " " .. Config.Minerals[mineral].displayName)
		end
	end
	return table.concat(parts, ", ")
end

function ForgeTimingHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ForgeTimingHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 11
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "OptionalAnvilStrike"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -145)
	panel.Size = UDim2.new(0.94, 0, 0, 172)
	panel.BackgroundColor3 = Color3.fromRGB(40, 32, 48)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(390, 172)
	limit.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(9, 7, 15)
	outline.Thickness = 3
	outline.Parent = panel

	label(panel, "Instruction", "Forged! Optional anvil strike", 6, 27)
	local reward = label(panel, "FixedReward", "", 34, 42)
	reward.TextSize = 14

	local track = Instance.new("Frame")
	track.Name = "TimingTrack"
	track.Position = UDim2.new(0, 12, 0, 81)
	track.Size = UDim2.new(1, -24, 0, 21)
	track.BackgroundColor3 = Color3.fromRGB(91, 88, 103)
	track.BorderSizePixel = 0
	track.Parent = panel

	local gold = Instance.new("Frame")
	gold.Name = "GoldWindow"
	gold.BackgroundColor3 = Color3.fromRGB(255, 205, 75)
	gold.BorderSizePixel = 0
	gold.Parent = track

	local progress = Instance.new("Frame")
	progress.Name = "Progress"
	progress.BackgroundColor3 = Color3.fromRGB(100, 215, 245)
	progress.BackgroundTransparency = 0.2
	progress.BorderSizePixel = 0
	progress.ZIndex = 2
	progress.Size = UDim2.fromScale(0, 1)
	progress.Parent = track

	local strikeButton = button(panel, "Strike", "STRIKE", 0, Color3.fromRGB(28, 126, 54))
	local skipButton = button(panel, "Skip", "SKIP", 0.5, Color3.fromRGB(84, 92, 110))
	local targetAt = 0
	local attempted = false
	local cfg = Config.ForgeStrike
	local total = cfg.delaySeconds + cfg.halfWindowSeconds
	gold.Position = UDim2.fromScale((cfg.delaySeconds - cfg.halfWindowSeconds) / total, 0)
	gold.Size = UDim2.fromScale(2 * cfg.halfWindowSeconds / total, 1)

	local function hide()
		panel.Visible = false
	end

	local function strike()
		if not panel.Visible or attempted then
			return
		end
		attempted = true
		hide()
		State.request("finishForgeStrike")
	end

	strikeButton.Activated:Connect(strike)
	skipButton.Activated:Connect(hide)
	ContextActionService:BindActionAtPriority("ForgeStrikeTap", function(_, state)
		if not panel.Visible then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			strike()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3100, Enum.KeyCode.Space, Enum.KeyCode.ButtonX)

	Remotes.Notify.OnClientEvent:Connect(function(kind: any, slot: any, tier: any, serverTarget: any)
		if kind ~= "forgeStrike" then
			return
		end
		if type(slot) ~= "string" or type(tier) ~= "string" or type(serverTarget) ~= "number" then
			return
		end
		if not Config.Slots[slot] or not Config.Tiers[tier] then
			return
		end
		targetAt = serverTarget
		attempted = false
		reward.Text = "Gold = refund " .. refundText(slot, tier) .. ". Miss/skip = normal forge."
		panel.Visible = true
	end)

	RunService.RenderStepped:Connect(function()
		if not panel.Visible then
			return
		end
		local now = workspace:GetServerTimeNow()
		if now > targetAt + cfg.halfWindowSeconds + 0.5 then
			hide()
			return
		end
		local elapsed = now - (targetAt - cfg.delaySeconds)
		progress.Size = UDim2.fromScale(math.clamp(elapsed / total, 0, 1), 1)
	end)
end

return ForgeTimingHud
