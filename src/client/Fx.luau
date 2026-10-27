--!strict
-- Client-only hit feedback, drawn locally so it costs the server nothing:
-- enemies flash and pop a damage number when hit, your golem flashes red,
-- defeated enemies burst into chunks, mined nodes throw off chips, and the
-- color grading shifts a little to match the island you're on.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

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

-- Throws `count` little cubes out from `position`, then shrinks them away.
local function burst(position: Vector3, color: Color3, material: Enum.Material, count: number, size: number, power: number)
	if not near(position) then
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
		local tween = TweenService:Create(chunk, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(target) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			Size = Vector3.new(0.05, 0.05, 0.05),
		})
		tween:Play()
		tween.Completed:Once(function()
			chunk:Destroy()
			debrisCount -= 1
		end)
	end
end

-- A quick colored glow over the whole model.
local function flash(model: Model, color: Color3)
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
	highlight.FillTransparency = 0.35
	local fade = TweenService:Create(highlight, TweenInfo.new(0.18), { FillTransparency = 1 })
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
	label.Text = tostring(amount)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 236, 140)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui

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

local function watchEnemy(model: Instance)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("Hit"):Connect(function()
		local root = model.PrimaryPart
		if not root or not near(root.Position) then
			return
		end
		flash(model, Color3.new(1, 1, 1))
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

-- Slightly warmer or cooler color grading per island.
local function zoneTint()
	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local zoneId = (player:GetAttribute("GolemZone") :: number?) or 1
	local zone = Config.Zones[zoneId]
	local tint = zone and Config.Visuals.zoneTints[zone.theme or ""]
	if color and tint then
		TweenService:Create(color, TweenInfo.new(2), { TintColor = tint }):Play()
	end
end

function Fx.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalFx"
	folder.Parent = workspace

	task.spawn(function()
		local enemies = each("Enemies", watchEnemy)
		-- Defeated enemies are removed by the server; burst where they stood.
		enemies.ChildRemoved:Connect(function(child)
			if child:IsA("Model") and child.PrimaryPart then
				local root = child.PrimaryPart
				local count = if child:GetAttribute("BossZone") then 24 else 9
				burst(root.Position, bodyColor(child), Enum.Material.SmoothPlastic, count, root.Size.Y * 0.18, root.Size.Y * 1.2)
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

	-- Your own Quake throws rocks up around the golem.
	Remotes.Notify.OnClientEvent:Connect(function(kind: string, spellId: string?)
		if kind ~= "spellCast" or spellId ~= "quake" then
			return
		end
		local golems = workspace:FindFirstChild("Golems")
		local model = golems and golems:FindFirstChild(player.Name .. "_Golem")
		local root = model and (model :: Model).PrimaryPart
		if root then
			local ground = root.Position - Vector3.new(0, root.Size.Y, 0)
			burst(ground, Color3.fromRGB(120, 110, 96), Enum.Material.Slate, 16, 1.2, root.Size.Y * 2)
		end
	end)

	if Config.Visuals.controlLighting then
		player:GetAttributeChangedSignal("GolemZone"):Connect(zoneTint)
		task.delay(2, zoneTint)
	end
end

return Fx
