--!strict
-- Client-only hit feedback, drawn locally so it costs the server nothing:
-- enemies turn white, shake their health bar and pop a damage number when
-- hit (the bar's pale ghost segment then drains down), your golem flashes red,
-- defeated enemies burst into chunks, mined nodes throw off chips, and the
-- color grading shifts a little to match the island you're on.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Ui = require(script.Parent:WaitForChild("Ui"))

local Fx = {}

local player = Players.LocalPlayer

local MAX_DISTANCE = 180 -- skip effects farther than this from the camera
local MAX_DEBRIS = 120 -- cap on loose chunks alive at once

local debrisCount = 0
local folder: Folder

local function near(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= MAX_DISTANCE
end

-- A short flash where a Quake slam lands: a ball that swells and fades, with
-- a smaller white core that goes faster. Skipped with Reduced Motion.
local function blast(position: Vector3, radius: number)
	if GuiService.ReducedMotionEnabled or not near(position) then
		return
	end
	local layers = {
		{ color = Color3.fromRGB(150, 225, 255), size = radius * 0.8, time = 0.35 },
		{ color = Color3.new(1, 1, 1), size = radius * 0.4, time = 0.2 },
	}
	for _, layer in layers do
		local ball = Instance.new("Part")
		ball.Name = "QuakeBlast"
		ball.Shape = Enum.PartType.Ball
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.Material = Enum.Material.Neon
		ball.Color = layer.color
		ball.Transparency = 0.3
		ball.Size = Vector3.new(2, 2, 2)
		ball.Position = position + Vector3.new(0, 1, 0)
		ball.Parent = folder
		local info = TweenInfo.new(layer.time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(ball, info, {
			Size = Vector3.new(layer.size, layer.size, layer.size),
			Transparency = 1,
		})
		tween:Play()
		tween.Completed:Once(function()
			ball:Destroy()
		end)
	end
end

-- A soft cloud of dust where a golem puffs away and where it reappears
-- beside its rider (the dismounted leash, see GolemService.followRider).
-- `scale` is the golem's size. Skipped with Reduced Motion.
local function puff(position: Vector3, scale: number)
	if GuiService.ReducedMotionEnabled or not near(position) then
		return
	end
	for index = 1, 3 do
		local cloud = Instance.new("Part")
		cloud.Name = "GolemPuff"
		cloud.Shape = Enum.PartType.Ball
		cloud.Anchored = true
		cloud.CanCollide = false
		cloud.CanQuery = false
		cloud.CanTouch = false
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.Color = Color3.fromRGB(205, 195, 180)
		cloud.Transparency = 0.35
		cloud.Size = Vector3.new(2, 2, 2) * scale
		local spread = Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1) * 2 * scale
		cloud.Position = position + spread + Vector3.new(0, (1 + index) * scale, 0)
		cloud.Parent = folder
		local size = (7 + index * 2) * scale
		local tween = TweenService:Create(
			cloud,
			TweenInfo.new(0.5 + index * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(size, size, size), Transparency = 1 }
		)
		tween:Play()
		tween.Completed:Once(function()
			cloud:Destroy()
		end)
	end
end

-- Throws `count` little cubes out from `position`, then shrinks them away.
local function burst(
	position: Vector3,
	color: Color3,
	material: Enum.Material,
	count: number,
	size: number,
	power: number,
	reform: boolean?
)
	if GuiService.ReducedMotionEnabled or not near(position) then
		return
	end
	for _ = 1, count do
		if debrisCount >= MAX_DEBRIS then
			return
		end
		debrisCount += 1
		local s = size * (0.6 + math.random() * 0.6)
		local chunk = Instance.new("Part")
		chunk.Name = "Chunk"
		chunk.Size = Vector3.new(s, s, s)
		chunk.Color = color
		chunk.Material = material
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.Anchored = true
		chunk.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		chunk.Parent = folder
		local direction = Vector3.new(math.random() * 2 - 1, 0.6 + math.random(), math.random() * 2 - 1).Unit
		local target = position + direction * power * (0.6 + math.random() * 0.6) - Vector3.new(0, power * 0.4, 0)
		if reform then
			chunk.CFrame = CFrame.new(target)
			chunk.Size = Vector3.new(0.05, 0.05, 0.05)
			target = position
		end
		local tween = TweenService:Create(chunk, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(target) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			Size = if reform then Vector3.new(s, s, s) else Vector3.new(0.05, 0.05, 0.05),
		})
		tween:Play()
		tween.Completed:Once(function()
			chunk:Destroy()
			debrisCount -= 1
		end)
	end
end

-- A quick colored glow over the whole model.
local function flash(model: Model, color: Color3, transparency: number?, duration: number?)
	local highlight = model:FindFirstChild("HitFlash") :: Highlight?
	if not highlight then
		local made = Instance.new("Highlight")
		made.Name = "HitFlash"
		made.DepthMode = Enum.HighlightDepthMode.Occluded
		made.OutlineTransparency = 1
		made.FillTransparency = 1
		made.Parent = model
		highlight = made
	end
	assert(highlight)
	-- Roblox draws a limited number of Highlights, so only enable it briefly.
	highlight.Enabled = true
	highlight.FillColor = color
	highlight.FillTransparency = transparency or 0.35
	local fade = TweenService:Create(highlight, TweenInfo.new(duration or 0.18), { FillTransparency = 1 })
	fade:Play()
	fade.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			highlight.Enabled = false
		end
	end)
end

-- A number that pops up over the target and floats away.
local function damageNumber(at: BasePart, amount: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = at.Position + Vector3.new(math.random() * 2 - 1, at.Size.Y / 2 + 1, math.random() * 2 - 1)
	anchor.Parent = folder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(90, 36)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = Ui.short(amount)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 236, 140)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui

	-- Punch: the number lands big, then settles to size as it floats up.
	if not GuiService.ReducedMotionEnabled then
		local pop = Instance.new("UIScale")
		pop.Scale = Config.HitFeel.numberPop
		pop.Parent = label
		TweenService:Create(pop, TweenInfo.new(Config.HitFeel.numberPopTime, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
	end

	TweenService:Create(anchor, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = anchor.Position + Vector3.new(0, 4, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(0.75, anchor.Destroy, anchor)
end

local function bodyColor(model: Model): Color3
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Color
	end
	return Color3.fromRGB(140, 130, 120)
end

-- A name and health bar over a normal enemy. The red fill drops to the new
-- health quickly; a pale ghost segment holds where the health was, then
-- drains down to it, so every hit visibly takes a chunk out. Returns a
-- function that shakes the bar.
local function healthBar(model: Model, humanoid: Humanoid, root: BasePart): () -> ()
	local feel = Config.HitFeel
	local _, extents = model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(feel.barWidth, feel.barHeight + 24)
	gui.StudsOffsetWorldSpace = Vector3.new(0, math.max(extents.Y, root.Size.Y) / 2 + 1.5, 0)
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = folder

	-- Everything sits in one holder, so a shake moves the name and bar together.
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local name = Ui.label(holder, humanoid.DisplayName, UDim2.new(1, 0, 0, 20), UDim2.new(), {
		Title = true,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	if model:GetAttribute("Elite") then
		name.TextColor3 = Ui.Colors.gold
	end
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0, feel.barHeight)
	back.Position = UDim2.new(0, 0, 1, -feel.barHeight)
	back.BackgroundColor3 = Color3.fromRGB(24, 22, 30)
	back.Parent = holder
	Ui.corner(back, 6)
	local rim = Instance.new("UIStroke")
	rim.Color = Ui.Colors.outline
	rim.Thickness = 2
	rim.Parent = back
	local ghost = Instance.new("Frame")
	ghost.Size = UDim2.fromScale(1, 1)
	ghost.BackgroundColor3 = feel.ghostColor
	ghost.ZIndex = 2
	ghost.Parent = back
	Ui.corner(ghost, 6)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.ZIndex = 3
	fill.Parent = back
	Ui.corner(fill, 6)
	Ui.fill(fill, feel.barColor)

	local shown = 1
	local ghostTween: Tween? = nil
	local function update()
		local fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		Ui.tween(fill, TweenInfo.new(feel.fillTime, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(fraction, 1) })
		if ghostTween then
			ghostTween:Cancel()
		end
		if fraction < shown then
			-- Restarting the delay on every hit lets fast combos pile up in
			-- the ghost before it drains.
			ghostTween = Ui.tween(
				ghost,
				TweenInfo.new(
					feel.ghostDrainTime,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In,
					0,
					false,
					feel.ghostDelay
				),
				{ Size = UDim2.fromScale(fraction, 1) }
			)
		else
			ghost.Size = UDim2.fromScale(fraction, 1) -- healing back up
		end
		shown = fraction
	end
	update()
	humanoid.HealthChanged:Connect(update)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	humanoid:GetPropertyChangedSignal("DisplayName"):Connect(function()
		name.Text = humanoid.DisplayName
	end)
	model.Destroying:Connect(function()
		gui:Destroy()
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			gui:Destroy()
		end
	end)

	return function()
		Ui.shake(holder, feel.shakePixels, feel.shakeTime)
	end
end

local function watchEnemy(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local shakeBar: (() -> ())? = nil
	task.spawn(function()
		local humanoid = model:WaitForChild("Humanoid", 10)
		local root = model.PrimaryPart or model:WaitForChild("HumanoidRootPart", 10)
		-- Bosses use the big bar at the top of the screen (Moments.luau).
		if model:GetAttribute("BossZone") then
			return
		end
		if humanoid and humanoid:IsA("Humanoid") and root and root:IsA("BasePart") and model.Parent then
			shakeBar = healthBar(model, humanoid, root)
		end
	end)
	model:GetAttributeChangedSignal("Hit"):Connect(function()
		local root = model.PrimaryPart
		if not root or not near(root.Position) then
			return
		end
		local feel = Config.HitFeel
		flash(model, Color3.new(1, 1, 1), feel.flashTransparency, feel.flashTime)
		if shakeBar then
			shakeBar()
		end
		local amount = model:GetAttribute("HitDamage") :: number?
		if amount then
			damageNumber(root, amount)
		end
	end)
end

local function watchGolem(model: Instance)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("Hit"):Connect(function()
		local root = model.PrimaryPart
		if root and near(root.Position) then
			flash(model, Color3.fromRGB(255, 70, 60))
		end
	end)
	-- A fall disperses stone at the saved fall position, then draws the same
	-- pieces inward at spawn. No model clones or server-side debris are needed.
	local hidden: { [BasePart]: number } = {}
	local generation = 0
	local recovering = model:GetAttribute("FallRecovery") == true
	local function hide(part: Instance)
		if part:IsA("BasePart") and hidden[part] == nil then
			hidden[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		end
	end
	local function restore()
		for part, transparency in hidden do
			part.LocalTransparencyModifier = transparency
		end
		table.clear(hidden)
	end
	local function fallChanged(animate: boolean)
		generation += 1
		local current = generation
		local falling = model:GetAttribute("FallRecovery") == true
		-- Publishing the initial false attribute is not a reformation.
		animate = animate and (falling or recovering)
		recovering = falling
		local root = model.PrimaryPart
		if falling then
			for _, part in model:GetDescendants() do
				hide(part)
			end
		end
		if not animate or not root or GuiService.ReducedMotionEnabled then
			if not falling then
				restore()
			end
			return
		end
		local at = if falling then model:GetAttribute("FallPosition") else root.Position
		if typeof(at) ~= "Vector3" or not near(at) then
			if not falling then
				restore()
			end
			return
		end
		local effect = Config.FallEffects
		local scale = root.Size.Y / 8
		burst(
			at,
			bodyColor(model),
			Enum.Material.Slate,
			effect.chunks,
			effect.chunkSize * scale,
			effect.spread * scale,
			not falling
		)
		if not falling then
			task.delay(0.55, function()
				if model.Parent and generation == current then
					restore()
				end
			end)
		end
	end
	model:GetAttributeChangedSignal("FallRecovery"):Connect(function()
		fallChanged(true)
	end)
	model.DescendantAdded:Connect(function(part)
		if model:GetAttribute("FallRecovery") == true then
			hide(part)
		end
	end)
	fallChanged(false)
end

local function watchNode(node: Instance)
	if not node:IsA("BasePart") then
		return
	end
	node:GetAttributeChangedSignal("Hit"):Connect(function()
		local ore = node:FindFirstChild("Ore")
		local color = if ore and ore:IsA("BasePart") then ore.Color else node.Color
		burst(node.Position + Vector3.new(0, node.Size.Y / 2, 0), color, node.Material, 3, 0.5, 4)
	end)
end

local function each(folderName: string, callback: (Instance) -> ())
	local container = workspace:WaitForChild(folderName)
	for _, child in container:GetChildren() do
		callback(child)
	end
	container.ChildAdded:Connect(callback)
	return container
end

-- Slightly warmer or cooler color grading and sky haze per island.
local function zoneTint()
	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local zoneId = (player:GetAttribute("GolemZone") :: number?) or 1
	local zone = if zoneId == Config.HubZone then Config.Hub else Config.Zones[zoneId]
	local tint = zone and Config.Visuals.zoneTints[zone.theme or ""]
	if color and tint then
		TweenService:Create(color, TweenInfo.new(2), { TintColor = tint }):Play()
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local haze = zone and Config.Visuals.zoneAtmosphere[zone.theme or ""]
	if atmosphere and haze then
		TweenService
			:Create(atmosphere, TweenInfo.new(2), { Color = haze.color, Decay = haze.decay, Density = haze.density })
			:Play()
	end
end

function Fx.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalFx"
	folder.Parent = workspace

	task.spawn(function()
		local enemies = each("Enemies", watchEnemy)
		-- Defeated enemies are removed by the server; burst where they stood.
		enemies.ChildRemoved:Connect(function(child: Instance)
			if child:IsA("Model") and child.PrimaryPart then
				local model = child :: Model
				local root = model.PrimaryPart :: BasePart
				local count = if model:GetAttribute("BossZone") then 24 else 9
				burst(
					root.Position,
					bodyColor(model),
					Enum.Material.SmoothPlastic,
					count,
					root.Size.Y * 0.18,
					root.Size.Y * 1.2
				)
			end
		end)
	end)
	task.spawn(each, "Golems", watchGolem)
	task.spawn(function()
		local nodes = each("Nodes", watchNode)
		nodes.ChildRemoved:Connect(function(child)
			if child:IsA("BasePart") then
				local ore = child:FindFirstChild("Ore")
				local color = if ore and ore:IsA("BasePart") then ore.Color else child.Color
				burst(child.Position, color, child.Material, 8, 0.9, 7)
			end
		end)
	end)

	-- A Quake slam landing: everyone nearby sees a blast, and the caster's rocks
	-- fly. The server only says so if the slam really lands.
	Remotes.Notify.OnClientEvent:Connect(function(kind: string, position: Vector3?, radius: number?, ownerId: number?)
		if kind == "golemPuff" and position and radius then
			puff(position, radius)
			return
		end
		if kind ~= "quakeImpact" or not position or not radius then
			return
		end
		blast(position, radius)
		if ownerId == player.UserId then
			burst(position, Color3.fromRGB(120, 110, 96), Enum.Material.Slate, 24, 1.2, radius * 0.4)
		end
	end)

	if Config.Visuals.controlLighting then
		player:GetAttributeChangedSignal("GolemZone"):Connect(zoneTint)
		task.delay(2, zoneTint)
	end
end

return Fx
