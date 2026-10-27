--!strict
-- Always-on HUD: minerals, level and XP bar, golem health, the spell bar,
-- the next-goal tracker, first-time hints, and pop-up messages.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local Controls = require(script.Parent:WaitForChild("Controls"))
local State = require(script.Parent:WaitForChild("State"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local Hud = {}

local player = Players.LocalPlayer

-- Works out the single most useful next thing to do.
local function nextGoal(snap: any): string
	local data = snap.data
	local level = Stats.levelForXp(data.golem.xp)
	local zoneId = if snap.golem then snap.golem.zoneId else 1

	if next(data.golem.parts) == nil then
		return "Mine stone, then open Forge to build your first part"
	end
	if Config.Bosses[zoneId] and not Stats.bossDefeated(data, zoneId) then
		return `Defeat {Config.Bosses[zoneId].displayName} in the far corner of the island`
	end
	for _, id in Config.ZoneOrder do
		local unlocked, reason = Stats.zoneUnlocked(data, id)
		if not unlocked then
			return `{reason} to unlock {Config.Zones[id].name}`
		end
		if unlocked and id > zoneId and not Stats.bossDefeated(data, id) then
			return `{Config.Zones[id].name} is open! Travel there from the Travel menu`
		end
	end
	if level >= Config.Awakening.minLevel then
		return "You can Awaken! Open Awaken for permanent upgrades"
	end
	if not Stats.zoneSetComplete(data, zoneId) then
		local missing = 0
		for id, artifact in Config.Artifacts do
			if artifact.zone == zoneId and not data.artifacts.found[id] then
				missing += 1
			end
		end
		return `Find {missing} more artifacts in {Config.Zones[zoneId].name}`
	end
	return `Reach level {Config.Awakening.minLevel} to Awaken`
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GolemHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	---------------------------------------------------------------- minerals + level

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.Size = UDim2.fromOffset(210, 26 * #Config.MineralOrder + 58)
	stats.Position = UDim2.fromOffset(12, 12)
	stats.BackgroundColor3 = Ui.Colors.panel
	stats.BackgroundTransparency = 0.25
	stats.Parent = gui
	Ui.corner(stats, 10)

	local levelLabel = Ui.label(stats, "Level 1", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 6))
	local xpBack = Instance.new("Frame")
	xpBack.Size = UDim2.new(1, -20, 0, 8)
	xpBack.Position = UDim2.fromOffset(10, 32)
	xpBack.BackgroundColor3 = Ui.Colors.row
	xpBack.Parent = stats
	Ui.corner(xpBack, 4)
	local xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.BackgroundColor3 = Ui.Colors.rune
	xpFill.Parent = xpBack
	Ui.corner(xpFill, 4)

	local mineralLabels: { [string]: TextLabel } = {}
	for index, id in Config.MineralOrder do
		local l = Ui.label(stats, `{Config.Minerals[id].displayName}: 0`, UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 48 + (index - 1) * 26))
		l.TextColor3 = Config.Minerals[id].color:Lerp(Ui.Colors.text, 0.35)
		mineralLabels[id] = l
	end

	---------------------------------------------------------------- health + goal

	local healthBack = Instance.new("Frame")
	healthBack.Name = "GolemHealth"
	healthBack.AnchorPoint = Vector2.new(0.5, 0)
	healthBack.Size = UDim2.fromOffset(280, 26)
	healthBack.Position = UDim2.new(0.5, 0, 0, 12)
	healthBack.BackgroundColor3 = Ui.Colors.panel
	healthBack.BackgroundTransparency = 0.25
	healthBack.Parent = gui
	Ui.corner(healthBack, 8)

	local healthFill = Instance.new("Frame")
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.BackgroundColor3 = Ui.Colors.good
	healthFill.Parent = healthBack
	Ui.corner(healthFill, 8)

	local healthText = Ui.label(healthBack, "Golem", UDim2.new(1, -16, 1, -6), UDim2.fromOffset(8, 3), {
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
	})

	local goal = Ui.label(gui, "", UDim2.fromOffset(440, 22), UDim2.new(0.5, 0, 0, 44), {
		AnchorPoint = Vector2.new(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Ui.Colors.warn,
		TextStrokeTransparency = 0.4,
	})

	local function refreshHealth()
		local hp = player:GetAttribute("GolemHealth") or 0
		local maxHp = player:GetAttribute("GolemMaxHealth") or 1
		local downed = player:GetAttribute("GolemDowned") == true
		healthFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
		healthText.Text = if downed then "Reforming..." else `Golem {hp} / {maxHp}`
	end
	for _, attribute in { "GolemHealth", "GolemMaxHealth", "GolemDowned" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshHealth)
	end
	refreshHealth()

	---------------------------------------------------------------- spell bar

	local spellButtons: { [string]: TextButton } = {}
	local readyAt: { [string]: number } = {}
	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	for index, spellId in Config.SpellOrder do
		local spell = Config.Spells[spellId]
		local b = Instance.new("TextButton")
		b.Name = spellId
		b.AnchorPoint = Vector2.new(1, 1)
		b.Size = UDim2.fromOffset(84, 84)
		b.Position = UDim2.new(1, -24 - (index - 1) * 94, 1, -150)
		b.BackgroundColor3 = Ui.Colors.panel
		b.BackgroundTransparency = 0.15
		b.TextColor3 = Ui.Colors.rune
		b.Font = Enum.Font.GothamBold
		b.TextScaled = true
		b.Text = if isTouch then spell.displayName else `{spell.displayName}\n[{spell.key.Name}]`
		b.Parent = gui
		Ui.corner(b, 42)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Ui.Colors.rune
		stroke.Thickness = 2
		stroke.Parent = b
		b.Activated:Connect(function()
			Controls.castSpell(spellId)
		end)
		spellButtons[spellId] = b
	end

	task.spawn(function()
		while true do
			task.wait(0.2)
			for spellId, b in spellButtons do
				local remaining = (readyAt[spellId] or 0) - os.clock()
				local spell = Config.Spells[spellId]
				if remaining > 0 then
					b.Text = tostring(math.ceil(remaining))
				else
					b.Text = if isTouch then spell.displayName else `{spell.displayName}\n[{spell.key.Name}]`
				end
			end
		end
	end)

	---------------------------------------------------------------- toasts

	local toast = Ui.label(gui, "", UDim2.fromOffset(520, 30), UDim2.new(0.5, 0, 1, -70), {
		AnchorPoint = Vector2.new(0.5, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
	})
	local toastToken = 0
	local function showToast(text: string, seconds: number?)
		toastToken += 1
		local myToken = toastToken
		toast.Text = text
		task.delay(seconds or 2.5, function()
			if toastToken == myToken then
				toast.Text = ""
			end
		end)
	end
	State.setToastHandler(showToast)

	---------------------------------------------------------------- state

	local hintShown = false
	State.Changed:Connect(function()
		local snap = State.snapshot
		local data = snap.data
		for id, l in mineralLabels do
			l.Text = `{Config.Minerals[id].displayName}: {data.minerals[id] or 0}`
		end
		local level = Stats.levelForXp(data.golem.xp)
		local size = Stats.sizeForLevel(level)
		levelLabel.Text = `Level {level}  ·  Size {size}`
		local floor, ceiling = Stats.xpForLevel(level), Stats.xpForLevel(level + 1)
		xpFill.Size = UDim2.fromScale(if level >= Config.Golem.maxLevel then 1 else math.clamp((data.golem.xp - floor) / math.max(ceiling - floor, 1), 0, 1), 1)
		goal.Text = "Next: " .. nextGoal(snap)

		if not hintShown then
			hintShown = true
			if data.golem.xp == 0 then
				showToast("Steer with WASD or the joystick. Let go and your golem fights on its own!", 8)
			end
			if not snap.canSave then
				task.delay(9, showToast, "Progress isn't saving in this test place (see the Output window).", 6)
			end
		end
	end)

	Remotes.Notify.OnClientEvent:Connect(function(kind: string, ...)
		local args = { ... }
		if kind == "mined" then
			showToast(`+{args[2]} {Config.Minerals[args[1]].displayName}`)
		elseif kind == "defeated" then
			showToast(`Defeated {args[1]}  +{args[2]} XP`)
		elseif kind == "boss" then
			showToast(if args[2] then `{args[1]} defeated! A new zone may be open.` else `{args[1]} defeated!`, 5)
		elseif kind == "artifact" then
			showToast(`Artifact found: {args[1]}!`, 5)
		elseif kind == "offline" then
			local text = `While you were away your golem mined for {args[1]} minutes: {Ui.costText(args[2])}`
			if args[3] then
				text ..= " (offline cap reached)"
			end
			showToast(text, 8)
		elseif kind == "message" then
			showToast(args[1], 4)
		elseif kind == "spellCast" then
			readyAt[args[1]] = os.clock() + args[2]
		end
	end)
end

return Hud
