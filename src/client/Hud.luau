--!strict
-- Always-on HUD: minerals, level and XP bar, golem health, the spell bar,
-- the next-goal tracker, and pop-up messages. First-time guidance lives in
-- Tutorial.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
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

local spellButtons: { [string]: TextButton } = {}

-- The tutorial points at these.
function Hud.getSpellButton(spellId: string): TextButton?
	return spellButtons[spellId]
end

-- Works out the single most useful next thing to do, and how far along the
-- player is (0 to 1) when that can be measured honestly.
local function nextGoal(snap: any): (string, number?)
	local data = snap.data
	local level = Stats.levelForXp(data.golem.xp)
	local zoneId = if snap.golem then snap.golem.zoneId else 1

	if next(data.golem.parts) == nil then
		local cost = Stats.partCost("armL", "stone")
		return "Mine stone, then open Forge to build your first part", math.min((data.minerals.stone or 0) / cost.stone, 1)
	end
	if Config.Bosses[zoneId] and not Stats.bossDefeated(data, zoneId) then
		return `Defeat {Config.Bosses[zoneId].displayName} in the far corner of the island`, nil
	end
	for _, id in Config.ZoneOrder do
		local unlocked, reason = Stats.zoneUnlocked(data, id)
		if not unlocked then
			local gate = Config.Zones[id].gate
			local progress = nil
			if gate.size and (not gate.boss or Stats.bossDefeated(data, gate.boss)) then
				progress = data.golem.xp / Stats.xpForLevel(Config.SizeLevels[gate.size])
			end
			return `{reason} to unlock {Config.Zones[id].name}`, progress
		end
		if unlocked and id > zoneId and not Stats.bossDefeated(data, id) then
			return `{Config.Zones[id].name} is open! Travel there from the Travel menu`, nil
		end
	end
	if level >= Config.Awakening.minLevel then
		return "You can Awaken! Open Awaken for permanent upgrades", nil
	end
	if not Stats.zoneSetComplete(data, zoneId) then
		local found, total = Stats.zoneArtifactCount(data, zoneId)
		return `Find {total - found} more artifacts in {Config.Zones[zoneId].name} ({found} / {total})`, found / total
	end
	return `Reach level {Config.Awakening.minLevel} to Awaken`, data.golem.xp / Stats.xpForLevel(Config.Awakening.minLevel)
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
	stats.BackgroundTransparency = 0.1
	stats.Parent = gui
	Ui.corner(stats, 10)
	Ui.surface(stats, "stone", { details = true })

	local levelLabel = Ui.label(stats, "Level 1", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 6))
	local xpBack = Instance.new("Frame")
	xpBack.Size = UDim2.new(1, -20, 0, 8)
	xpBack.Position = UDim2.fromOffset(10, 32)
	xpBack.Parent = stats
	Ui.corner(xpBack, 4)
	Ui.surface(xpBack, "metal", { tint = Ui.Colors.row })
	local xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.Parent = xpBack
	Ui.corner(xpFill, 4)
	Ui.fill(xpFill, Ui.Colors.rune)

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
	healthBack.BackgroundTransparency = 0.1
	healthBack.Parent = gui
	Ui.corner(healthBack, 8)
	Ui.surface(healthBack, "metal")

	local healthFill = Instance.new("Frame")
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.Parent = healthBack
	Ui.corner(healthFill, 8)
	Ui.fill(healthFill, Ui.Colors.good)

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

	-- A thin bar under the goal shows real progress toward it.
	local goalBack = Instance.new("Frame")
	goalBack.Name = "GoalProgress"
	goalBack.AnchorPoint = Vector2.new(0.5, 0)
	goalBack.Size = UDim2.fromOffset(240, 6)
	goalBack.Position = UDim2.new(0.5, 0, 0, 68)
	goalBack.Visible = false
	goalBack.Parent = gui
	Ui.corner(goalBack, 3)
	Ui.surface(goalBack, "metal", { tint = Ui.Colors.row })
	local goalFill = Instance.new("Frame")
	goalFill.Size = UDim2.fromScale(0, 1)
	goalFill.Parent = goalBack
	Ui.corner(goalFill, 3)
	Ui.fill(goalFill, Ui.Colors.warn)

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

	local readyAt: { [string]: number } = {}
	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	for index, spellId in Config.SpellOrder do
		local spell = Config.Spells[spellId]
		local b = Instance.new("TextButton")
		b.Name = spellId
		b.AnchorPoint = Vector2.new(1, 1)
		b.Size = UDim2.fromOffset(84, 84)
		b.Position = UDim2.new(1, -24 - (index - 1) * 94, 1, -150)
		b.BackgroundTransparency = 0.05
		b.TextColor3 = Ui.Colors.rune
		b.TextStrokeColor3 = Color3.fromRGB(10, 14, 20)
		b.TextStrokeTransparency = 0.3
		b.Font = Enum.Font.GothamBold
		b.TextScaled = true
		b.Text = if isTouch then spell.displayName else `{spell.displayName}\n[{spell.key.Name}]`
		b.Parent = gui
		Ui.corner(b, 42)
		-- Runestones: a stone disc with a glowing rune rim.
		local rim = Ui.surface(b, "stone")
		rim.Color = Ui.Colors.rune
		rim.Thickness = 3
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

	---------------------------------------------------------------- event banner

	-- Shows live events and when they end, right of the stats panel.
	local banner = Instance.new("Frame")
	banner.Name = "EventBanner"
	banner.Size = UDim2.fromOffset(230, 46)
	banner.Position = UDim2.fromOffset(232, 12)
	banner.BackgroundTransparency = 0.05
	banner.Visible = false
	banner.Parent = gui
	Ui.corner(banner, 10)
	Ui.surface(banner, "wood", { details = true }) -- a notice board
	local bannerTitle = Ui.label(banner, "", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 4), { TextColor3 = Ui.Colors.warn })
	local bannerInfo = Ui.label(banner, "", UDim2.new(1, -16, 0, 16), UDim2.fromOffset(8, 26), { TextColor3 = Ui.Colors.quiet, Font = Enum.Font.Gotham })
	task.spawn(function()
		while true do
			local now = State.serverNow()
			local active = Stats.activeEvents(now)
			banner.Visible = #active > 0
			if #active > 0 then
				local first = active[1]
				local effects = Ui.modifierText(first.event.modifiers)
				bannerTitle.Text = if #active > 1 then `{first.event.name} +{#active - 1} more` else first.event.name
				bannerInfo.Text = (if effects ~= "" then effects .. "  ·  " else "") .. `ends in {Ui.duration(first.endsAt - now)}`
			end
			task.wait(1)
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
		-- The tutorial gives one instruction at a time; the goal takes over after.
		local inTutorial = data.tutorial and not data.tutorial.done and data.tutorial.step >= 1
		local goalText, progress = nextGoal(snap)
		goal.Text = "Next: " .. goalText
		goal.Visible = not inTutorial
		goalBack.Visible = progress ~= nil and not inTutorial
		if progress then
			TweenService:Create(goalFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1) }):Play()
		end

		if not hintShown then
			hintShown = true
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
