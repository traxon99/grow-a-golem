--!strict
-- The first-time tutorial on screen: one short callout at a time, and a
-- pointer at the thing to do (a beam to a rock, or a bobbing tag on a
-- button). The server decides the step (data.tutorial in the snapshot);
-- this only shows it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Hud = require(script.Parent:WaitForChild("Hud"))
local Menus = require(script.Parent:WaitForChild("Menus"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local State = require(script.Parent:WaitForChild("State"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local Tutorial = {}

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 214, 90)
local NODE_SEARCH_RANGE = 400

local stepIndex = 0 -- 0 when no tutorial is running

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function isGamepad(): boolean
	return UserInputService:GetLastInputType().Name:match("^Gamepad") ~= nil
end

local function stepText(step: any): string
	if isGamepad() and step.gamepadText then
		return step.gamepadText
	elseif isTouch() and step.touchText then
		return step.touchText
	end
	return step.text
end

local function myGolemRoot(): BasePart?
	local folder = workspace:FindFirstChild("Golems")
	local model = folder and folder:FindFirstChild(player.Name .. "_Golem")
	local root = model and model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The nearest stone node, or any node if no stone is around. Picked again
-- every frame, so if someone else breaks it the pointer just moves on.
local function nearestNode(from: Vector3): BasePart?
	local folder = workspace:FindFirstChild("Nodes")
	if not folder then
		return nil
	end
	local stone, stoneDistance = nil, NODE_SEARCH_RANGE
	local any, anyDistance = nil, NODE_SEARCH_RANGE
	for _, node in folder:GetChildren() do
		if node:IsA("BasePart") then
			local distance = (node.Position - from).Magnitude
			if node.Name == "StoneNode" and distance < stoneDistance then
				stone, stoneDistance = node, distance
			end
			if distance < anyDistance then
				any, anyDistance = node, distance
			end
		end
	end
	return stone or any
end

function Tutorial.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GolemTutorial"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	---------------------------------------------------------------- callout

	local panel = Instance.new("Frame")
	panel.Name = "Callout"
	-- Sits where the next-goal line is, which the HUD hides during the tutorial.
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 46)
	panel.Size = UDim2.new(0.62, 0, 0, 78)
	panel.BackgroundColor3 = Ui.Colors.panel
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = gui
	Ui.corner(panel, 14)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(620, 78)
	sizeLimit.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 3
	stroke.Parent = panel

	local counter = Ui.label(panel, "", UDim2.fromOffset(60, 18), UDim2.fromOffset(14, 6), {
		TextColor3 = GOLD,
	})
	local text = Ui.label(panel, "", UDim2.new(1, -28, 0, 44), UDim2.fromOffset(14, 26), {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
	})

	-- Skip takes two taps, so nobody skips by accident.
	local skipArmed = false
	local skip: TextButton
	skip = Ui.button(panel, "Skip", UDim2.fromOffset(64, 22), UDim2.new(1, -72, 0, 5), true, function()
		if not skipArmed then
			skipArmed = true
			skip.Text = "Sure?"
			task.delay(3, function()
				skipArmed = false
				skip.Text = "Skip"
			end)
			return
		end
		State.request("skipTutorial")
	end)
	skip.BackgroundColor3 = Ui.Colors.row

	local function pop()
		scale.Scale = 1.12
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	---------------------------------------------------------------- pointers

	-- A beam from the golem to the target rock, with a tag above the rock.
	-- The rock (and the golem, when it's rebuilt) can be destroyed at any
	-- time, taking the attachments with it, so they're remade when that happens.
	local beam: Beam?, fromAttachment: Attachment?, toAttachment: Attachment? = nil, nil, nil
	local function clearBeam()
		for _, instance in { beam, fromAttachment, toAttachment } :: { Instance? } do
			if instance then
				instance:Destroy()
			end
		end
		beam, fromAttachment, toAttachment = nil, nil, nil
	end
	local function beamBetween(root: BasePart, node: BasePart)
		if beam and fromAttachment and fromAttachment.Parent == root and toAttachment and toAttachment.Parent == node then
			toAttachment.Position = Vector3.new(0, node.Size.Y / 2, 0) -- nodes shrink as they're mined
			return
		end
		clearBeam()
		local from = Instance.new("Attachment")
		from.Name = "TutorialFrom"
		from.Parent = root
		local to = Instance.new("Attachment")
		to.Name = "TutorialTo"
		to.Position = Vector3.new(0, node.Size.Y / 2, 0)
		to.Parent = node
		local b = Instance.new("Beam")
		b.Color = ColorSequence.new(GOLD)
		b.LightEmission = 1
		b.FaceCamera = true
		b.Width0 = 0.6
		b.Width1 = 1.6
		b.Transparency = NumberSequence.new(0.7, 0.1)
		b.Segments = 1
		b.Attachment0 = from
		b.Attachment1 = to
		b.Parent = root
		beam, fromAttachment, toAttachment = b, from, to
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = "TutorialTag"
	tag.Size = UDim2.fromOffset(140, 70)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.Enabled = false
	tag.Parent = gui
	Ui.label(tag, "Mine this!", UDim2.new(1, 0, 0, 30), UDim2.new(), {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = GOLD,
		TextStrokeTransparency = 0.2,
	})
	local arrow = Instance.new("Frame")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(22, 22)
	arrow.Position = UDim2.new(0.5, 0, 0, 48)
	arrow.Rotation = 45
	arrow.BackgroundColor3 = GOLD
	arrow.Parent = tag

	-- A bobbing tag next to a button on screen.
	local hint = Ui.label(gui, "Here!", UDim2.fromOffset(110, 30), UDim2.new(), {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 0,
		BackgroundColor3 = GOLD,
		TextColor3 = Ui.Colors.panel,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	Ui.corner(hint, 15)
	-- A glowing ring laid over the button (buttons may already have a stroke).
	local ring = Instance.new("Frame")
	ring.Name = "TutorialRing"
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.Parent = gui
	local ringCorner = Instance.new("UICorner")
	ringCorner.Parent = ring
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = GOLD
	ringStroke.Thickness = 4
	ringStroke.Parent = ring

	local function hidePointers()
		clearBeam()
		tag.Enabled = false
		hint.Visible = false
		ring.Visible = false
	end

	local function pointAtButton(button: GuiObject?, t: number, side: string)
		if not button then
			hint.Visible = false
			ring.Visible = false
			return
		end
		local bob = math.sin(t * 6) * 8
		local position, size = button.AbsolutePosition, button.AbsoluteSize
		local inset = gui.AbsolutePosition -- the top bar inset, if any
		if side == "right" then
			hint.AnchorPoint = Vector2.new(0, 0.5)
			hint.Position = UDim2.fromOffset(position.X - inset.X + size.X + 10 + bob, position.Y - inset.Y + size.Y / 2)
		else
			hint.AnchorPoint = Vector2.new(0.5, 1)
			hint.Position = UDim2.fromOffset(position.X - inset.X + size.X / 2, position.Y - inset.Y - 8 + bob)
		end
		hint.Visible = true
		ring.Position = UDim2.fromOffset(position.X - inset.X - 4, position.Y - inset.Y - 4)
		ring.Size = UDim2.fromOffset(size.X + 8, size.Y + 8)
		ringCorner.CornerRadius = UDim.new(0, if side == "above" then (size.X + 8) / 2 else 10)
		ringStroke.Transparency = 0.3 + 0.3 * math.sin(t * 6)
		ring.Visible = true
	end

	local function pointAtNode(t: number)
		local root = myGolemRoot()
		local node = root and nearestNode(root.Position)
		if not root or not node then
			clearBeam()
			tag.Enabled = false
			return
		end
		beamBetween(root, node)
		tag.Adornee = node
		tag.StudsOffset = Vector3.new(0, node.Size.Y / 2 + 4 + math.sin(t * 5) * 0.8, 0)
		tag.Enabled = true
	end

	RunService.RenderStepped:Connect(function()
		local step = Config.Tutorial.steps[stepIndex]
		if not step then
			return
		end
		local t = os.clock()
		if step.pointer == "node" then
			pointAtNode(t)
		elseif step.pointer == "forge" then
			if Menus.isOpen("forge") then
				hint.Visible = false
				ring.Visible = false
				text.Text = "Press Forge on any part!"
			else
				pointAtButton(Menus.getTabButton("forge"), t, "right")
				text.Text = stepText(step)
			end
		elseif step.pointer == "spell" then
			pointAtButton(Hud.getSpellButton(step.spell), t, "above")
		end
	end)

	---------------------------------------------------------------- state

	local function show(index: number)
		if index == stepIndex then
			return
		end
		stepIndex = index
		hidePointers()
		local step = Config.Tutorial.steps[index]
		if not step then
			return
		end
		panel.Visible = true
		skip.Visible = true
		counter.Text = `{index} / {#Config.Tutorial.steps}`
		text.Text = stepText(step)
		pop()
	end

	State.Changed:Connect(function()
		local tutorial = State.snapshot.data.tutorial
		if not tutorial or tutorial.done or tutorial.step < 1 then
			if stepIndex ~= 0 then
				stepIndex = 0
				hidePointers()
				-- Leave the panel up only while the "you're ready" message shows.
				if counter.Text ~= "" then
					panel.Visible = false
				end
			end
			return
		end
		show(tutorial.step)
	end)

	Remotes.Notify.OnClientEvent:Connect(function(kind: string)
		if kind == "tutorialStep" then
			Sfx.play("tutorialStep")
		elseif kind == "tutorialDone" then
			stepIndex = 0
			hidePointers()
			panel.Visible = true
			skip.Visible = false
			counter.Text = ""
			text.Text = Config.Tutorial.doneText
			pop()
			task.delay(6, function()
				if stepIndex == 0 then
					panel.Visible = false
				end
			end)
		end
	end)
end

return Tutorial
