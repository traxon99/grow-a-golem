--!strict
-- The big, rewarding moments: the boss health bar, the artifact reveal card,
-- and the level-up banner. Everything shown here is real game state. The boss
-- bar reads the boss's actual health, and the reveal only plays for an
-- artifact the server really granted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local Sfx = require(script.Parent:WaitForChild("Sfx"))
local State = require(script.Parent:WaitForChild("State"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local Icons = require(script.Parent:WaitForChild("Icons"))

local Moments = {}

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 214, 90)

-- Waits out a tween without missing one that already finished (with
-- Reduced Motion on, tweens end at once).
local function waitFor(tween: Tween)
	while tween.PlaybackState == Enum.PlaybackState.Begin or tween.PlaybackState == Enum.PlaybackState.Playing do
		task.wait()
	end
end

local function bar(parent: Instance, size: UDim2, position: UDim2, color: Color3): (Frame, Frame)
	local back = Instance.new("Frame")
	back.Size = size
	back.Position = position
	back.Parent = parent
	Ui.corner(back, 10)
	local rim = Ui.surface(back, "metal", { tint = Color3.fromRGB(20, 22, 32) })
	rim.Color = Ui.Colors.outline
	rim.Thickness = 3
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 3
	fill.Parent = back
	Ui.corner(fill, 10)
	Ui.fill(fill, color)
	return back, fill
end

---------------------------------------------------------------- boss bar

local function startBossBar(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "BossBar"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Size = UDim2.fromOffset(440, 82)
	frame.Position = UDim2.new(0.5, 0, 0, 50)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui

	-- The boss's name on a red header plate, the bar under it.
	local plate = Instance.new("Frame")
	plate.Name = "NamePlate"
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.fromScale(0.5, 0)
	plate.Size = UDim2.new(0.8, 0, 0, 36)
	plate.Parent = frame
	Ui.corner(plate, 10)
	Ui.surface(plate, "gem", { tint = Ui.Styles.danger, details = true })
	local title = Ui.label(plate, "", UDim2.new(1, -40, 1, 0), UDim2.fromOffset(20, 0), {
		Title = true,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 2,
	})
	local back, fill = bar(frame, UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 42), Color3.fromRGB(220, 60, 50))
	-- A pale "chip" bar trails behind the real one so each hit visibly lands.
	local chip = Instance.new("Frame")
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundColor3 = Color3.fromRGB(255, 235, 200)
	chip.ZIndex = 2
	chip.Parent = back
	Ui.corner(chip, 10)
	local numbers = Ui.label(back, "", UDim2.fromScale(1, 1), UDim2.new(), {
		Title = true,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		ZIndex = 4,
	})

	local lastFraction = 1
	local chipTween: Tween? = nil

	local function findBoss(zoneId: number): Model?
		local folder = workspace:FindFirstChild("Enemies")
		if not folder then
			return nil
		end
		for _, model in folder:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("BossZone") == zoneId then
				return model
			end
		end
		return nil
	end

	task.spawn(function()
		while true do
			task.wait(0.1)
			local snap = State.snapshot
			local zoneId = if snap and snap.golem then snap.golem.zoneId else nil
			local boss = if zoneId then findBoss(zoneId) else nil
			local humanoid = boss and boss:FindFirstChildOfClass("Humanoid")
			local root = boss and boss.PrimaryPart
			local character = player.Character
			local me = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local near = root ~= nil and me ~= nil and (root.Position - me.Position).Magnitude < 110
			if not (humanoid and near) then
				frame.Visible = false
				lastFraction = 1
				continue
			end
			local h = humanoid :: Humanoid
			local fraction = math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1)
			if not frame.Visible then
				chip.Size = UDim2.fromScale(fraction, 1)
			end
			frame.Visible = true
			fill.Size = UDim2.fromScale(fraction, 1)
			numbers.Text = `{Ui.short(math.ceil(h.Health))} / {Ui.short(h.MaxHealth)}`
			-- The bar is the real health, so "almost there" is only ever true.
			title.Text = if fraction <= 0.25 then `{h.DisplayName}  ·  Almost there!` else h.DisplayName
			title.TextColor3 = if fraction <= 0.25 then Ui.Colors.gold else Ui.Colors.text
			if fraction < lastFraction then
				Ui.shake(frame, Config.HitFeel.bossShakePixels, Config.HitFeel.shakeTime)
				if chipTween then
					chipTween:Cancel()
				end
				chipTween = Ui.tween(
					chip,
					TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.25),
					{ Size = UDim2.fromScale(fraction, 1) }
				)
			elseif fraction > lastFraction then
				chip.Size = UDim2.fromScale(fraction, 1) -- healing back up
			end
			lastFraction = fraction
		end
	end)
end

---------------------------------------------------------------- reveal card

local function startReveal(gui: ScreenGui)
	local queue: { string } = {}
	local showing = false

	local function show(artifactId: string)
		local artifact = Config.Artifacts[artifactId]
		local snap = State.snapshot
		if not artifact or not snap then
			return
		end
		local found, total = Stats.zoneArtifactCount(snap.data, artifact.zone)
		-- The snapshot may arrive just after the notice; count this one either way.
		if not snap.data.artifacts.found[artifactId] then
			found += 1
		end
		local complete = found >= total

		-- The card takes the artifact's rarity from the shared table: its
		-- color, symbol and name. It shows exactly what the server granted.
		local rarity = Ui.rarity(Config.ArtifactSourceRarity[artifact.source])
		local card = Instance.new("TextButton")
		card.Name = "ArtifactReveal"
		card.AutoButtonColor = false
		card.Text = ""
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.45)
		card.Size = UDim2.fromOffset(0, 0)
		card.ZIndex = 10
		card.Parent = gui
		Ui.corner(card, 18)
		local stroke = Ui.surface(card, "crystal", { tint = rarity.dark })
		stroke.Color = rarity.color
		stroke.Thickness = 5
		-- Ui.surface adds the "Grain" gradient that the glow below spins.
		local gradient = card:FindFirstChild("Grain") :: UIGradient

		local content = Instance.new("Frame")
		content.BackgroundTransparency = 1
		content.Size = UDim2.fromScale(1, 1)
		content.Visible = false
		content.ZIndex = 11
		content.Parent = card

		local function line(text: string, y: number, height: number, color: Color3, size: number)
			return Ui.label(content, text, UDim2.new(1, -30, 0, height), UDim2.fromOffset(15, y), {
				Title = true,
				TextSize = size,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = color,
				ZIndex = 12,
			})
		end
		line("NEW ARTIFACT!", 14, 28, GOLD, 24)
		local symbol = Icons.create(content, rarity.icon, 30, UDim2.new(0.5, -60, 0, 48), rarity.color)
		symbol.ZIndex = 12
		local rarityLabel = line(rarity.name, 48, 30, rarity.color:Lerp(Color3.new(1, 1, 1), 0.4), 22)
		rarityLabel.Position = UDim2.new(0.5, -24, 0, 48)
		rarityLabel.Size = UDim2.fromOffset(140, 30)
		rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
		line(artifact.name, 82, 40, Ui.Colors.text, 30)
		line(Ui.bonusText(artifact.bonus), 126, 30, Ui.Colors.good, 24)
		line(`{Config.Zones[artifact.zone].name}: {found} / {total} found`, 160, 24, Ui.Colors.quiet, 18)
		local back, fill = bar(content, UDim2.new(1, -60, 0, 14), UDim2.fromOffset(30, 190), GOLD)
		back.ZIndex = 12
		fill.ZIndex = 13
		fill.Size = UDim2.fromScale((found - 1) / total, 1)
		if complete then
			line(`Set complete! {Ui.bonusText(Config.ZoneSetBonus)}`, 210, 24, GOLD, 20)
		end

		local closeCard: () -> () = function() end
		local nice = Ui.button(
			content,
			"Nice!",
			UDim2.fromOffset(150, 48),
			UDim2.new(0.5, -75, 1, -60),
			true,
			function()
				closeCard()
			end
		)
		nice.ZIndex = 12
		-- Equip right away when there's a free slot.
		local stats = State.stats()
		if stats and #snap.data.artifacts.equipped < stats.artifactSlots then
			nice.Position = UDim2.new(0.5, -158, 1, -60)
			local equip = Ui.button(
				content,
				"Equip",
				UDim2.fromOffset(150, 48),
				UDim2.new(0.5, 8, 1, -60),
				true,
				function()
					State.request("equipArtifact", artifactId)
					closeCard()
				end,
				"secondary"
			)
			equip.ZIndex = 12
		end

		Sfx.moment("artifact")
		local pop = Ui.tween(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(380, 300),
		})
		waitFor(pop)
		content.Visible = true
		Ui.tween(fill, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.2), {
			Size = UDim2.fromScale(found / total, 1),
		})

		-- The card's glow sweeps and pulses while it is up (not with Reduced Motion).
		local still = Ui.reducedMotion()
		local spin = RunService.RenderStepped:Connect(function(dt: number)
			if still then
				return
			end
			gradient.Rotation = (gradient.Rotation + dt * 90) % 360
			stroke.Thickness = 4 + math.sin(os.clock() * 6)
		end)

		local closed = false
		local function close()
			if closed then
				return
			end
			closed = true
			spin:Disconnect()
			content.Visible = false
			local shrink = Ui.tween(card, TweenInfo.new(0.2), { Size = UDim2.fromOffset(0, 0) })
			waitFor(shrink)
			card:Destroy()
		end
		closeCard = function()
			task.spawn(close)
		end
		card.Activated:Connect(function()
			task.spawn(close)
		end)
		local started = os.clock()
		while not closed and os.clock() - started < 6 do
			task.wait(0.1)
		end
		close()
	end

	Remotes.Notify.OnClientEvent:Connect(function(kind: string, _name: string, artifactId: string?)
		if kind ~= "artifact" or not artifactId then
			return
		end
		table.insert(queue, artifactId)
		if showing then
			return
		end
		showing = true
		task.spawn(function()
			while #queue > 0 do
				show(table.remove(queue, 1) :: string)
			end
			showing = false
		end)
	end)
end

---------------------------------------------------------------- level up

local function startLevelUp(gui: ScreenGui)
	local banner = Ui.label(gui, "", UDim2.fromOffset(460, 70), UDim2.fromScale(0.5, 0.3), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Ui.Colors.gold,
		Title = true,
		TextSize = 60,
		TextWrapped = false,
		Visible = false,
	})
	Ui.outline(banner, 4)
	local pop = Instance.new("UIScale")
	pop.Parent = banner
	-- What it unlocked, in one line.
	local sub = Ui.label(gui, "", UDim2.fromOffset(560, 34), UDim2.fromScale(0.5, 0.3), {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.3, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Ui.Colors.text,
		Title = true,
		TextSize = 26,
		TextWrapped = false,
		Visible = false,
	})
	Ui.outline(sub, 3)

	local token = 0
	local function celebrate(level: number, grew: boolean, unlocked: string?)
		token += 1
		local mine = token
		banner.Text = `LEVEL {level}!`
		banner.Visible = true
		pop.Scale = if Ui.reducedMotion() then 1 else 0.4
		Ui.tween(pop, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		local extra = {}
		if grew then
			table.insert(extra, `Your golem grew to size {Stats.sizeForLevel(level)}!`)
		end
		if unlocked then
			table.insert(extra, `{unlocked} is open!`)
		end
		sub.Text = table.concat(extra, "  ")
		sub.Visible = #extra > 0
		Sfx.moment(if grew then "grow" else "levelUp")
		task.delay(2.5, function()
			if token == mine then
				banner.Visible = false
				sub.Visible = false
			end
		end)
	end

	local lastLevel: number? = nil
	local lastZones: { [number]: boolean } = {}
	State.Changed:Connect(function()
		local data = State.snapshot.data
		local level = Stats.levelForXp(data.golem.xp)
		local zones = {}
		for _, id in Config.ZoneOrder do
			zones[id] = (Stats.zoneUnlocked(data, id))
		end
		-- An Awakening resets the level, so only celebrate going up.
		if lastLevel and level > lastLevel then
			local unlocked = nil
			for _, id in Config.ZoneOrder do
				if zones[id] and not lastZones[id] then
					unlocked = Config.Zones[id].name
				end
			end
			celebrate(level, Stats.sizeForLevel(level) > Stats.sizeForLevel(lastLevel), unlocked)
		end
		lastLevel = level
		lastZones = zones
	end)
end

function Moments.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GolemMoments"
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")
	startBossBar(gui)
	startReveal(gui)
	startLevelUp(gui)
end

return Moments
