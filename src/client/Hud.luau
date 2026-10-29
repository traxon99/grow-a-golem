--!strict
-- Always-on HUD: minerals, level and XP bar, golem health, the spell bar,
-- the next-goal tracker, and pop-up messages. First-time guidance lives in
-- Tutorial.luau.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local Controls = require(script.Parent:WaitForChild("Controls"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local State = require(script.Parent:WaitForChild("State"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local Icons = require(script.Parent:WaitForChild("Icons"))

local Hud = {}

local player = Players.LocalPlayer

local spellButtons: { [string]: TextButton } = {}

-- The tutorial points at these.
function Hud.getSpellButton(spellId: string): TextButton?
	return spellButtons[spellId]
end

export type Goal = {
	title: string,
	-- Up to three steps, with `current` the one being worked on.
	steps: { string }?,
	current: number?,
	-- A bar with a "to go" number, when the step has one.
	progress: { label: string, current: number, max: number, icon: string? }?,
	-- The menu tapping the card opens.
	tab: string?,
}

-- Works out the single most useful next thing to do, in short plain words,
-- and how far along the player is when that can be measured honestly.
local function nextGoal(snap: any): Goal
	local data = snap.data
	local level = Stats.levelForXp(data.golem.xp)
	local zoneId = if snap.golem then snap.golem.zoneId else 1
	local run = snap.tower and snap.tower.run
	if run and run.state ~= "inviting" and Stats.isTowerZone(zoneId) then
		if run.state == "fighting" then
			return {
				title = `Clear wave {run.wave} of {Config.Tower.waves}`,
				progress = {
					label = "Enemies beaten",
					current = math.max(run.waveTotal - run.remaining, 0),
					max = math.max(run.waveTotal, 1),
				},
			}
		end
		return {
			title = Config.Tower.name,
			progress = { label = "Waves cleared", current = run.cleared, max = Config.Tower.waves },
		}
	end
	if Stats.isTowerZone(zoneId) or zoneId == Config.HubZone then
		return {
			title = "Head back to an island",
			steps = { "Open Travel", "Pick an island" },
			current = if Menus.isOpen("travel") then 2 else 1,
			tab = "travel",
		}
	end

	if next(data.golem.parts) == nil then
		local cost = Stats.partCost("armL", "stone").stone
		local stone = data.minerals.stone or 0
		return {
			title = "Build your first golem part",
			steps = { `Mine {cost} stone`, "Open Forge", "Forge a part" },
			current = if stone < cost then 1 elseif not Menus.isOpen("forge") then 2 else 3,
			progress = if stone < cost then { label = "Stone", current = stone, max = cost, icon = "stone" } else nil,
			tab = "forge",
		}
	end
	if Config.Bosses[zoneId] and not Stats.bossDefeated(data, zoneId) then
		return {
			title = `Beat {Config.Bosses[zoneId].displayName}`,
			steps = { "Find the boss in the far corner", `Beat {Config.Bosses[zoneId].displayName}` },
			current = 1,
		}
	end
	for _, id in Config.ZoneOrder do
		local zone = Config.Zones[id]
		local unlocked = Stats.zoneUnlocked(data, id)
		if not unlocked then
			local gate = zone.gate
			if gate.boss and not Stats.bossDefeated(data, gate.boss) then
				return { title = `Beat {Config.Bosses[gate.boss].displayName} to open {zone.name}`, tab = "travel" }
			end
			local needed = Config.SizeLevels[gate.size or 1] or 1
			return {
				title = `Grow to size {gate.size} to open {zone.name}`,
				progress = { label = "Level", current = level, max = needed, icon = "xp" },
			}
		end
		if id > zoneId and not Stats.bossDefeated(data, id) then
			return {
				title = `{zone.name} is open!`,
				steps = { "Open Travel", `Travel to {zone.name}` },
				current = if Menus.isOpen("travel") then 2 else 1,
				tab = "travel",
			}
		end
	end
	if level >= Config.Awakening.minLevel then
		return {
			title = "You can Awaken!",
			steps = { "Open Awaken", "Press Awaken" },
			current = if Menus.isOpen("awaken") then 2 else 1,
			tab = "awaken",
		}
	end
	if not Stats.zoneSetComplete(data, zoneId) then
		local found, total = Stats.zoneArtifactCount(data, zoneId)
		return {
			title = `Find {total - found} more artifacts here`,
			progress = { label = "Artifacts", current = found, max = total, icon = "artifacts" },
			tab = "artifacts",
		}
	end
	return {
		title = `Reach level {Config.Awakening.minLevel} to Awaken`,
		progress = { label = "Level", current = level, max = Config.Awakening.minLevel, icon = "xp" },
		tab = "awaken",
	}
end

local function overlaps(a: GuiObject, b: GuiObject): boolean
	local ap, as = a.AbsolutePosition, a.AbsoluteSize
	local bp, bs = b.AbsolutePosition, b.AbsoluteSize
	return ap.X < bp.X + bs.X and bp.X < ap.X + as.X and ap.Y < bp.Y + bs.Y and bp.Y < ap.Y + as.Y
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GolemHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")

	---------------------------------------------------------------- minerals + level

	-- Minerals sit in two columns as icon and short number, so the slab stays
	-- short enough to leave room for the menu buttons under it.
	local mineralRows = math.ceil(#Config.MineralOrder / 2)
	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.Size = UDim2.fromOffset(210, 28 * mineralRows + 62)
	stats.Position = UDim2.fromOffset(12, 12)
	-- No plate behind the numbers: icons and heavy outlined text read on their
	-- own, so the top-left stays quiet.
	stats.BackgroundTransparency = 1
	stats.Parent = gui

	local levelLabel = Ui.label(stats, "Level 1", UDim2.new(1, -46, 0, 24), UDim2.fromOffset(38, 6), { Title = true })
	Ui.outline(levelLabel, 3)
	Icons.create(stats, "xp", 26, UDim2.fromOffset(8, 5))
	local xpBack = Instance.new("Frame")
	xpBack.Size = UDim2.new(1, -20, 0, 10)
	xpBack.Position = UDim2.fromOffset(10, 34)
	xpBack.Parent = stats
	Ui.corner(xpBack, 5)
	local xpRim = Ui.surface(xpBack, "metal", { tint = Color3.fromRGB(20, 22, 32) })
	xpRim.Color = Ui.Colors.outline
	xpRim.Thickness = 3
	local xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.Parent = xpBack
	Ui.corner(xpFill, 5)
	Ui.fill(xpFill, Ui.Colors.rune)

	local mineralLabels: { [string]: TextLabel } = {}
	for index, id in Config.MineralOrder do
		local column = (index - 1) % 2
		local row = (index - 1) // 2
		local x = 8 + column * 100
		local y = 52 + row * 28
		Icons.create(stats, id, 24, UDim2.fromOffset(x, y))
		local l = Ui.label(stats, "0", UDim2.fromOffset(68, 24), UDim2.fromOffset(x + 28, y), {
			Title = true,
			TextSize = Ui.TextSize.body,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		l.TextColor3 = Config.Minerals[id].color:Lerp(Ui.Colors.text, 0.45)
		Ui.outline(l, 3)
		mineralLabels[id] = l
	end

	---------------------------------------------------------------- health + goal

	local healthBack = Instance.new("Frame")
	healthBack.Name = "GolemHealth"
	healthBack.AnchorPoint = Vector2.new(0.5, 0)
	healthBack.Size = UDim2.fromOffset(300, 30)
	healthBack.Position = UDim2.new(0.5, 0, 0, 12)
	healthBack.BackgroundTransparency = 0.1
	healthBack.Parent = gui
	Ui.corner(healthBack, 10)
	local healthRim = Ui.surface(healthBack, "metal", { tint = Color3.fromRGB(20, 22, 32) })
	healthRim.Color = Ui.Colors.outline
	healthRim.Thickness = 3

	local healthFill = Instance.new("Frame")
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.Parent = healthBack
	Ui.corner(healthFill, 10)
	Ui.fill(healthFill, Ui.Colors.good)

	local healthText = Ui.label(healthBack, "Golem", UDim2.new(1, -16, 1, 0), UDim2.fromOffset(8, 0), {
		Title = true,
		TextSize = Ui.TextSize.body,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		ZIndex = 2,
	})

	-- The goal card, top right: a header tab, one short sentence, up to
	-- three steps and a "to go" bar. Tapping it opens the menu it points to.
	local goalCard = Instance.new("TextButton")
	goalCard.Name = "GoalCard"
	goalCard.Text = ""
	goalCard.AutoButtonColor = false
	goalCard.AnchorPoint = Vector2.new(1, 0)
	goalCard.Position = UDim2.new(1, -12, 0, 12)
	goalCard.Size = UDim2.fromOffset(290, 0)
	goalCard.AutomaticSize = Enum.AutomaticSize.Y
	goalCard.BackgroundTransparency = 0.08
	goalCard.Visible = false
	goalCard.Parent = gui
	Ui.corner(goalCard, 12)
	Ui.surface(goalCard, "plate")
	Ui.pressable(goalCard, 1.03, 0.97)
	local goalPadding = Instance.new("UIPadding")
	goalPadding.PaddingTop = UDim.new(0, 6)
	goalPadding.PaddingBottom = UDim.new(0, 10)
	goalPadding.PaddingLeft = UDim.new(0, 10)
	goalPadding.PaddingRight = UDim.new(0, 10)
	goalPadding.Parent = goalCard
	Ui.listLayout(goalCard, 6)
	local goalHeader = Instance.new("Frame")
	goalHeader.Size = UDim2.new(1, 0, 0, 32)
	goalHeader.LayoutOrder = 1
	goalHeader.Parent = goalCard
	Ui.corner(goalHeader, 8)
	Ui.surface(goalHeader, "gem", { tint = Ui.Headers.quests, details = true })
	Icons.create(goalHeader, "quests", 26, UDim2.fromOffset(6, 3))
	Ui.label(goalHeader, "GOAL", UDim2.new(1, -44, 1, 0), UDim2.fromOffset(38, 0), {
		Title = true,
		TextSize = Ui.TextSize.body,
		TextWrapped = false,
		ZIndex = 2,
	})
	local goalOpen = Ui.label(goalHeader, "", UDim2.new(0, 120, 1, 0), UDim2.new(1, -126, 0, 0), {
		TextSize = Ui.TextSize.body,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		ZIndex = 2,
	})
	local goalBody = Instance.new("Frame")
	goalBody.Name = "Body"
	goalBody.BackgroundTransparency = 1
	goalBody.Size = UDim2.fromScale(1, 0)
	goalBody.AutomaticSize = Enum.AutomaticSize.Y
	goalBody.LayoutOrder = 2
	goalBody.Parent = goalCard
	Ui.listLayout(goalBody, 6)
	local goalTab: string? = nil
	local goalKey = ""
	goalCard.Activated:Connect(function()
		if goalTab then
			Menus.open(goalTab)
		end
	end)

	local function showGoal(goal: Goal)
		goalTab = goal.tab
		local progress = goal.progress
		local key = `{goal.title}|{goal.current or 0}|{if progress then `{progress.current}/{progress.max}` else ""}`
		if key == goalKey then
			return
		end
		goalKey = key
		goalOpen.Text = if goal.tab then "Tap to go" else ""
		for _, child in goalBody:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		local title = Ui.text(goalBody, goal.title, 20, { Title = true, TextColor3 = Ui.Colors.gold })
		title.LayoutOrder = 1
		if goal.steps then
			Ui.checklist(goalBody, goal.steps, goal.current or 1, 2)
		end
		if progress then
			Ui.progress(goalBody, {
				label = progress.label,
				current = progress.current,
				max = progress.max,
				icon = progress.icon,
				order = 3,
			})
		end
	end

	-- The goal card steps aside whenever the boss bar would overlap it.
	local inTutorial = false
	task.spawn(function()
		while true do
			task.wait(0.25)
			local moments = player.PlayerGui:FindFirstChild("GolemMoments")
			local bossBar = moments and moments:FindFirstChild("BossBar")
			local blocked = bossBar ~= nil
				and bossBar:IsA("GuiObject")
				and bossBar.Visible
				and overlaps(bossBar, goalCard)
			goalCard.Visible = not inTutorial and State.snapshot ~= nil and not blocked
		end
	end)

	local function refreshHealth()
		local hp = player:GetAttribute("GolemHealth") or 0
		local maxHp = player:GetAttribute("GolemMaxHealth") or 1
		local downed = player:GetAttribute("GolemDowned") == true
		healthFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
		healthText.Text = if downed then "Reforming..." else `Golem {Ui.short(hp)} / {Ui.short(maxHp)}`
	end
	for _, attribute in { "GolemHealth", "GolemMaxHealth", "GolemDowned" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshHealth)
	end
	refreshHealth()

	---------------------------------------------------------------- spell bar

	local readyAt: { [string]: number } = {}
	local spellLabels: { [string]: TextLabel } = {}
	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	for index, spellId in Config.SpellOrder do
		local spell = Config.Spells[spellId]
		local b = Instance.new("TextButton")
		b.Name = spellId
		b.AnchorPoint = Vector2.new(1, 1)
		b.Size = UDim2.fromOffset(84, 84)
		b.Position = UDim2.new(1, -24 - (index - 1) * 94, 1, -150)
		b.BackgroundTransparency = 0.05
		b.Text = ""
		b.Parent = gui
		Icons.create(b, spellId, 32, UDim2.fromOffset(26, 5))
		spellLabels[spellId] = Ui.label(
			b,
			if isTouch then spell.displayName else `{spell.displayName}\n[{spell.key.Name}]`,
			UDim2.new(1, -8, 0, 42),
			UDim2.fromOffset(4, 37),
			{ Title = true, TextSize = Ui.TextSize.body, TextXAlignment = Enum.TextXAlignment.Center }
		)
		Ui.corner(b, 42)
		-- Runestones: a stone disc with a glowing rune rim.
		local rim = Ui.surface(b, "stone")
		rim.Color = Ui.Colors.rune
		rim.Thickness = 3
		Ui.pressable(b)
		b.Activated:Connect(function()
			Controls.castSpell(spellId)
		end)
		spellButtons[spellId] = b
	end

	-- Mount button: ride the golem or hop off and walk on your own.
	local mountButton = Instance.new("TextButton")
	mountButton.Name = "Mount"
	mountButton.AnchorPoint = Vector2.new(1, 1)
	mountButton.Size = UDim2.fromOffset(110, 52)
	mountButton.Position = UDim2.new(1, -24, 1, -150 - 94)
	mountButton.BackgroundTransparency = 0.05
	mountButton.Text = ""
	mountButton.Parent = gui
	Ui.corner(mountButton, 26)
	Ui.surface(mountButton, "stone").Color = Ui.Colors.rune
	local mountLabel = Ui.label(
		mountButton,
		"",
		UDim2.new(1, -8, 1, -4),
		UDim2.fromOffset(4, 2),
		{ Title = true, TextSize = Ui.TextSize.body, TextXAlignment = Enum.TextXAlignment.Center }
	)
	Ui.pressable(mountButton)
	mountButton.Activated:Connect(Controls.toggleMount)
	local function refreshMount()
		local mounted = Controls.isMounted()
		local verb = if mounted then "Dismount" else "Mount"
		mountLabel.Text = if isTouch then verb else `{verb}\n[F]`
		-- Spells need a rider; dim them while dismounted.
		for _, button in spellButtons do
			button.BackgroundTransparency = if mounted then 0.05 else 0.5
		end
	end
	player:GetAttributeChangedSignal("GolemMounted"):Connect(refreshMount)
	refreshMount()

	-- Sprint button: the touch (and mouse) way to sprint; Shift or L3 hold it too.
	local sprintButton = Instance.new("TextButton")
	sprintButton.Name = "Sprint"
	sprintButton.AnchorPoint = Vector2.new(1, 1)
	sprintButton.Size = UDim2.fromOffset(110, 52)
	sprintButton.Position = UDim2.new(1, -24 - 120, 1, -150 - 94)
	sprintButton.Text = ""
	sprintButton.Parent = gui
	Ui.corner(sprintButton, 26)
	Ui.surface(sprintButton, "stone").Color = Ui.Colors.rune
	local sprintLabel = Ui.label(
		sprintButton,
		"",
		UDim2.new(1, -8, 1, -4),
		UDim2.fromOffset(4, 2),
		{ Title = true, TextSize = Ui.TextSize.body, TextXAlignment = Enum.TextXAlignment.Center }
	)
	Ui.pressable(sprintButton)
	sprintButton.Activated:Connect(Controls.toggleSprint)
	local function refreshSprint()
		local on = Controls.isSprinting()
		sprintButton.BackgroundTransparency = (if on then 0 else 0.35) * GuiService.PreferredTransparency
		local verb = if on then "Sprinting" else "Sprint"
		sprintLabel.Text = if isTouch then verb else `{verb}\n[Shift]`
	end
	Controls.SprintChanged:Connect(refreshSprint)
	refreshSprint()

	task.spawn(function()
		while true do
			task.wait(0.2)
			for spellId, label in spellLabels do
				local remaining = (readyAt[spellId] or 0) - os.clock()
				local spell = Config.Spells[spellId]
				if remaining > 0 then
					label.Text = `{spell.displayName}\n{math.ceil(remaining)}s`
				else
					label.Text = if isTouch then spell.displayName else `{spell.displayName}\n[{spell.key.Name}]`
				end
			end
		end
	end)

	---------------------------------------------------------------- event banner

	-- Shows live events and when they end, right of the stats panel.
	local banner = Instance.new("Frame")
	banner.Name = "EventBanner"
	banner.Size = UDim2.fromOffset(250, 58)
	banner.Position = UDim2.fromOffset(232, 12)
	banner.BackgroundTransparency = 0.05
	banner.Visible = false
	banner.Parent = gui
	Ui.corner(banner, 10)
	Ui.surface(banner, "wood", { details = true }) -- a notice board
	local bannerTitle = Ui.label(banner, "", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 4), {
		Title = true,
		TextColor3 = Ui.Colors.gold,
		TextSize = 20,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local bannerInfo = Ui.label(banner, "", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 30), {
		TextColor3 = Ui.Colors.quiet,
		TextSize = Ui.TextSize.body,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	task.spawn(function()
		while true do
			local now = State.serverNow()
			local active = Stats.activeEvents(now)
			banner.Visible = #active > 0
			if #active > 0 then
				local first = active[1]
				local effects = Ui.modifierText(first.event.modifiers)
				bannerTitle.Text = if #active > 1 then `{first.event.name} +{#active - 1} more` else first.event.name
				bannerInfo.Text = (if effects ~= "" then effects .. "  ·  " else "") .. Ui.timeLeft(first.endsAt - now)
			end
			task.wait(1)
		end
	end)

	---------------------------------------------------------------- toasts

	local toast = Ui.label(gui, "", UDim2.fromOffset(520, 0), UDim2.new(0.5, 0, 1, -70), {
		AnchorPoint = Vector2.new(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.Y,
		Title = true,
		TextSize = Ui.TextSize.big,
		TextXAlignment = Enum.TextXAlignment.Center,
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
			l.Text = Ui.short(data.minerals[id] or 0)
		end
		local level = Stats.levelForXp(data.golem.xp)
		local size = Stats.sizeForLevel(level)
		levelLabel.Text = `Level {level}  ·  Size {size}`
		local floor, ceiling = Stats.xpForLevel(level), Stats.xpForLevel(level + 1)
		xpFill.Size = UDim2.fromScale(
			if level >= Config.Golem.maxLevel
				then 1
				else math.clamp((data.golem.xp - floor) / math.max(ceiling - floor, 1), 0, 1),
			1
		)
		-- The tutorial gives one instruction at a time; the goal takes over after.
		inTutorial = data.tutorial and not data.tutorial.done and data.tutorial.step >= 1
		showGoal(nextGoal(snap))

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
