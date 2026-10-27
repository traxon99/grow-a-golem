--!strict
-- Placeholder HUD: mineral counts, XP, golem health, the Quake button, and
-- short pop-up messages. Built in code for now; we can move it to a
-- Studio-designed ScreenGui once the art direction is set.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controls = require(script.Parent:WaitForChild("Controls"))

local Hud = {}

local player = Players.LocalPlayer

local PANEL_COLOR = Color3.fromRGB(30, 34, 40)
local TEXT_COLOR = Color3.fromRGB(240, 240, 240)
local RUNE_COLOR = Color3.fromRGB(90, 200, 255)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, name: string, text: string, size: UDim2, position: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.TextColor3 = TEXT_COLOR
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GolemHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Top-left: minerals and XP.
	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.Size = UDim2.fromOffset(200, 28 * (#Config.MineralOrder + 1) + 12)
	stats.Position = UDim2.fromOffset(12, 12)
	stats.BackgroundColor3 = PANEL_COLOR
	stats.BackgroundTransparency = 0.25
	stats.Parent = gui
	corner(stats, 10)

	local mineralLabels: { [string]: TextLabel } = {}
	for index, id in Config.MineralOrder do
		local l = label(stats, id, `{Config.Minerals[id].displayName}: 0`, UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 6 + (index - 1) * 28))
		l.TextColor3 = Config.Minerals[id].color:Lerp(TEXT_COLOR, 0.35)
		mineralLabels[id] = l
	end
	local xpLabel = label(stats, "XP", "XP: 0", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 6 + #Config.MineralOrder * 28))

	-- Top-center: golem health bar.
	local healthBack = Instance.new("Frame")
	healthBack.Name = "GolemHealth"
	healthBack.AnchorPoint = Vector2.new(0.5, 0)
	healthBack.Size = UDim2.fromOffset(260, 26)
	healthBack.Position = UDim2.new(0.5, 0, 0, 12)
	healthBack.BackgroundColor3 = PANEL_COLOR
	healthBack.BackgroundTransparency = 0.25
	healthBack.Parent = gui
	corner(healthBack, 8)

	local healthFill = Instance.new("Frame")
	healthFill.Name = "Fill"
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.BackgroundColor3 = Color3.fromRGB(110, 200, 90)
	healthFill.Parent = healthBack
	corner(healthFill, 8)

	local healthText = label(healthBack, "Text", "Golem", UDim2.new(1, -16, 1, -6), UDim2.fromOffset(8, 3))
	healthText.TextXAlignment = Enum.TextXAlignment.Center
	healthText.ZIndex = 2

	-- Bottom-right: Quake button, large enough for thumbs.
	local quake = Instance.new("TextButton")
	quake.Name = "Quake"
	quake.AnchorPoint = Vector2.new(1, 1)
	quake.Size = UDim2.fromOffset(96, 96)
	quake.Position = UDim2.new(1, -24, 1, -150)
	quake.BackgroundColor3 = PANEL_COLOR
	quake.BackgroundTransparency = 0.15
	quake.TextColor3 = RUNE_COLOR
	quake.Font = Enum.Font.GothamBold
	quake.TextScaled = true
	quake.Text = "Quake\n[Q]"
	quake.Parent = gui
	corner(quake, 48)
	local quakeStroke = Instance.new("UIStroke")
	quakeStroke.Color = RUNE_COLOR
	quakeStroke.Thickness = 2
	quakeStroke.Parent = quake

	quake.Activated:Connect(function()
		Controls.castSpell("quake")
	end)

	-- Bottom-center: short messages.
	local toast = label(gui, "Toast", "", UDim2.fromOffset(420, 30), UDim2.new(0.5, 0, 1, -70))
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.TextStrokeTransparency = 0.4
	local toastToken = 0
	local function showToast(text: string)
		toastToken += 1
		local myToken = toastToken
		toast.Text = text
		task.delay(2, function()
			if toastToken == myToken then
				toast.Text = ""
			end
		end)
	end

	local function refreshHealth()
		local hp = player:GetAttribute("GolemHealth") or 0
		local maxHp = player:GetAttribute("GolemMaxHealth") or 1
		local downed = player:GetAttribute("GolemDowned") == true
		healthFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
		healthText.Text = if downed then "Reforming..." else `Golem {hp} / {maxHp}`
	end
	player:GetAttributeChangedSignal("GolemHealth"):Connect(refreshHealth)
	player:GetAttributeChangedSignal("GolemMaxHealth"):Connect(refreshHealth)
	player:GetAttributeChangedSignal("GolemDowned"):Connect(refreshHealth)
	refreshHealth()

	Remotes.StateUpdate.OnClientEvent:Connect(function(state)
		for id, l in mineralLabels do
			l.Text = `{Config.Minerals[id].displayName}: {state.minerals[id] or 0}`
		end
		xpLabel.Text = `XP: {state.xp}`
	end)

	local quakeReadyAt = 0
	Remotes.Notify.OnClientEvent:Connect(function(kind: string, ...)
		local args = { ... }
		if kind == "mined" then
			showToast(`+{args[2]} {Config.Minerals[args[1]].displayName}`)
		elseif kind == "defeated" then
			showToast(`Defeated {args[1]}  +{args[3]} XP`)
		elseif kind == "message" then
			showToast(args[1])
		elseif kind == "spellCast" and args[1] == "quake" then
			quakeReadyAt = os.clock() + args[2]
			task.spawn(function()
				while os.clock() < quakeReadyAt do
					quake.Text = tostring(math.ceil(quakeReadyAt - os.clock()))
					task.wait(0.2)
				end
				quake.Text = "Quake\n[Q]"
			end)
		end
	end)
end

return Hud
