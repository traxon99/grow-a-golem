--!strict
-- The menu kit (#82): every piece of UI is built from these helpers, so all
-- menus share one look. Dark stud plates for windows, a colored header bar
-- per menu, chunky outlined text, five button styles, rarity cards, "N to go"
-- progress bars, step checklists, friendly empty states and speech-bubble
-- dialogs. Surfaces get their material through `Ui.surface` (see
-- docs/reference/ui-materials.md for the rules and the contrast table).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local Icons = require(script.Parent:WaitForChild("Icons"))

local Ui = {}

Ui.Colors = {
	panel = Color3.fromRGB(30, 34, 40),
	-- The window body: a dark night-blue plate.
	plate = Color3.fromRGB(30, 34, 50),
	row = Color3.fromRGB(46, 54, 74),
	card = Color3.fromRGB(40, 46, 64),
	text = Color3.fromRGB(255, 255, 255),
	quiet = Color3.fromRGB(196, 202, 214),
	-- Later checklist steps: dimmed, but still 4.5:1 or better on rows.
	dim = Color3.fromRGB(166, 172, 186),
	outline = Color3.fromRGB(14, 12, 20),
	rune = Color3.fromRGB(90, 200, 255),
	good = Color3.fromRGB(110, 210, 100),
	warn = Color3.fromRGB(255, 200, 70),
	gold = Color3.fromRGB(255, 214, 90),
	bad = Color3.fromRGB(232, 66, 58),
	-- The speech bubble is cream with dark text.
	bubble = Color3.fromRGB(255, 244, 214),
	bubbleText = Color3.fromRGB(40, 32, 24),
	button = Color3.fromRGB(64, 120, 200),
	disabled = Color3.fromRGB(66, 70, 80),
}

-- Button styles. White text is 4.5:1 or better on each base color.
Ui.Styles = {
	primary = Color3.fromRGB(28, 126, 54), -- bright green: the one main action
	secondary = Color3.fromRGB(84, 92, 110), -- gray: everything else
	robux = Color3.fromRGB(170, 90, 0), -- gold-orange: always with the Robux icon and price
	danger = Color3.fromRGB(196, 48, 52), -- red: close, cancel, leave
	disabled = Color3.fromRGB(66, 70, 80), -- dull gray with quiet text
} :: { [string]: Color3 }

-- Header bar colors, one per menu, so the color tells you where you are.
Ui.Headers = {
	forge = Color3.fromRGB(172, 84, 16), -- ember orange
	travel = Color3.fromRGB(14, 118, 120), -- teal
	artifacts = Color3.fromRGB(116, 64, 190), -- amethyst purple
	skills = Color3.fromRGB(40, 96, 184), -- rune blue
	awaken = Color3.fromRGB(96, 60, 160), -- deep amethyst
	quests = Color3.fromRGB(32, 124, 58), -- moss green
	events = Color3.fromRGB(146, 100, 0), -- gold
	party = Color3.fromRGB(40, 96, 184), -- blue
	hub = Color3.fromRGB(40, 96, 184),
	trade = Color3.fromRGB(40, 96, 184),
	wardrobe = Color3.fromRGB(132, 84, 176), -- lilac
	shop = Color3.fromRGB(132, 84, 176),
	ranks = Color3.fromRGB(146, 100, 0),
	menu = Color3.fromRGB(84, 92, 110),
	guide = Color3.fromRGB(14, 118, 120),
} :: { [string]: Color3 }

-- Builder Sans: heavy, rounded and easy to read, with distinct I, l and 1.
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
Ui.Fonts = {
	title = Font.new(BUILDER, Enum.FontWeight.ExtraBold),
	body = Font.new(BUILDER, Enum.FontWeight.Bold),
}

-- Fixed text sizes (never TextScaled for body text), so the player's
-- PreferredTextSize setting still applies.
Ui.TextSize = {
	title = 30,
	heading = 28,
	big = 24,
	body = 18,
}

function Ui.corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

function Ui.padding(parent: Instance, pixels: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, pixels)
	p.PaddingRight = UDim.new(0, pixels)
	p.PaddingTop = UDim.new(0, pixels)
	p.PaddingBottom = UDim.new(0, pixels)
	p.Parent = parent
end

function Ui.listLayout(parent: Instance, gap: number, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	if horizontal then
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	layout.Parent = parent
	return layout
end

---------------------------------------------------------------- accessibility

function Ui.reducedMotion(): boolean
	local ok, value = pcall(function(): boolean
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
end

-- A tween that snaps straight to the end when Reduced Motion is on.
function Ui.tween(instance: Instance, info: TweenInfo, goals: { [string]: any }): Tween
	local tween = TweenService:Create(instance, if Ui.reducedMotion() then TweenInfo.new(0) else info, goals :: any)
	tween:Play()
	return tween
end

-- Jolts a GUI object around its place for `duration` seconds, fading out.
-- A new shake on the same object replaces the old one. Reduced Motion skips it.
local shaking: { [GuiObject]: { home: UDim2, token: number } } = {}
function Ui.shake(target: GuiObject, pixels: number, duration: number)
	if Ui.reducedMotion() then
		return
	end
	local entry = shaking[target]
	if not entry then
		entry = { home = target.Position, token = 0 }
		shaking[target] = entry
	end
	assert(entry)
	entry.token += 1
	local token = entry.token
	local home = entry.home
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if entry.token ~= token then
			connection:Disconnect() -- a newer shake took over
			return
		end
		if not target.Parent then
			connection:Disconnect()
			shaking[target] = nil
			return
		end
		local t = (os.clock() - started) / duration
		if t >= 1 then
			connection:Disconnect()
			target.Position = home
			shaking[target] = nil
			return
		end
		local strength = pixels * (1 - t)
		target.Position = home
			+ UDim2.fromOffset(
				math.floor((math.random() * 2 - 1) * strength + 0.5),
				math.floor((math.random() * 2 - 1) * strength * 0.5 + 0.5)
			)
	end)
end

-- Panel transparency scaled by the player's PreferredTransparency (1 is the
-- default; lower means they want more solid panels).
function Ui.transparency(base: number): number
	local ok, preferred = pcall(function(): number
		return GuiService.PreferredTransparency
	end)
	return base * (if ok then preferred else 1)
end

-- Hover and press feedback for a button: it grows a little under the cursor
-- and sinks when pressed, through a UIScale child (never Size, so layouts stay
-- put). Reduced Motion leaves the button alone.
function Ui.pressable(target: GuiButton, hover: number?, press: number?)
	local scale = Instance.new("UIScale")
	scale.Name = "Press"
	scale.Parent = target
	local hovering, down = false, false
	local function update()
		if Ui.reducedMotion() then
			scale.Scale = 1
			return
		end
		local goal = if down then (press or 0.94) elseif hovering then (hover or 1.06) else 1
		local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(scale, info, { Scale = goal }):Play()
	end
	target.MouseEnter:Connect(function()
		hovering = true
		update()
	end)
	target.MouseLeave:Connect(function()
		hovering = false
		down = false
		update()
	end)
	target.MouseButton1Down:Connect(function()
		down = true
		update()
	end)
	target.MouseButton1Up:Connect(function()
		down = false
		update()
	end)
	-- A button hidden or moved while hovered never gets MouseLeave.
	target:GetPropertyChangedSignal("Visible"):Connect(function()
		hovering, down = false, false
		update()
	end)
	target.AncestryChanged:Connect(function()
		hovering, down = false, false
		update()
	end)
end

-- A panel opening: it grows from 85% to full size with a little overshoot.
-- Reduced Motion shows it at once.
function Ui.pop(frame: GuiObject)
	if Ui.reducedMotion() then
		return
	end
	local scale = frame:FindFirstChild("Pop") :: UIScale?
	if not scale then
		scale = Instance.new("UIScale")
		assert(scale)
		scale.Name = "Pop"
		scale.Parent = frame
	end
	assert(scale)
	scale.Scale = 0.85
	local info = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(scale, info, { Scale = 1 }):Play()
end

---------------------------------------------------------------- materials

-- Themed surfaces (docs/reference/ui-materials.md). Each material has a base
-- color, a grain drawn with a UIGradient (brightness steps from 0 to 1 across
-- the surface, at `rotation` degrees), an edge stroke, and an optional tiled
-- image from Config.UiTextures, tinted with the base color and laid over it.
-- Roblox advises at most 6 gradient color stops, so each grain has 6 or
-- fewer. The image can only darken the base, and the bases are dark enough that
-- white text stays above 4.5:1 contrast.
type Material = {
	color: Color3,
	edge: Color3,
	edgeWidth: number,
	rotation: number,
	grain: { number },
	tile: number,
	imageTransparency: number,
	texture: string?,
}

Ui.Materials = {
	-- Planks: the tutorial sign and the event notice board.
	wood = {
		color = Color3.fromRGB(96, 64, 42),
		edge = Color3.fromRGB(46, 30, 20),
		edgeWidth = 3,
		rotation = 90,
		grain = { 1, 0.84, 0.97, 0.82, 0.94, 1 },
		tile = 96,
		imageTransparency = 0.45,
	},
	-- Cut stone: the HUD stats slab, runestone spell buttons, inputs.
	stone = {
		color = Color3.fromRGB(66, 70, 78),
		edge = Color3.fromRGB(34, 36, 42),
		edgeWidth = 2,
		rotation = 30,
		grain = { 1, 0.88, 0.96, 0.84, 0.94, 1 },
		tile = 80,
		imageTransparency = 0.45,
	},
	-- Riveted iron: bar frames.
	metal = {
		color = Color3.fromRGB(92, 102, 116),
		edge = Color3.fromRGB(34, 38, 46),
		edgeWidth = 2,
		rotation = 90,
		grain = { 1, 0.78, 0.88, 0.92, 0.8, 0.65 },
		tile = 64,
		imageTransparency = 0.55,
	},
	-- Building-brick plate: list rows, cards and the side buttons.
	studs = {
		color = Color3.fromRGB(58, 66, 80),
		edge = Color3.fromRGB(30, 34, 42),
		edgeWidth = 2,
		rotation = 90,
		grain = { 1, 0.94, 0.9, 0.86 },
		tile = 48,
		imageTransparency = 0.4,
	},
	-- Rune crystal: the artifact reveal card's facets.
	crystal = {
		color = Color3.fromRGB(48, 98, 178),
		edge = Color3.fromRGB(150, 215, 255),
		edgeWidth = 2,
		rotation = 45,
		grain = { 1, 0.8, 0.96, 0.78, 0.94, 0.86 },
		tile = 96,
		imageTransparency = 0.5,
	},
	-- The window body: a dark night-blue brick plate with faint studs. Uses
	-- the studs texture, tinted dark.
	plate = {
		color = Color3.fromRGB(30, 34, 50),
		edge = Color3.fromRGB(10, 10, 18),
		edgeWidth = 5,
		rotation = 90,
		grain = { 1, 0.9, 0.82 },
		tile = 48,
		imageTransparency = 0.25,
		texture = "studs",
	},
	-- Chunky glossy plastic: header bars and every kit button. Always tinted
	-- (a style or header color); the base here is the secondary gray. Uses the
	-- crystal texture for faint facets.
	gem = {
		color = Color3.fromRGB(84, 92, 110),
		edge = Color3.fromRGB(14, 12, 20),
		edgeWidth = 3,
		rotation = 90,
		grain = { 1, 0.97, 0.86, 0.8 },
		tile = 96,
		imageTransparency = 0.7,
		texture = "crystal",
	},
} :: { [string]: Material }

-- A gradient on a text object also tints its text, so text surfaces get a
-- shallower grain and no image layer.
local TEXT_GRAIN_FLOOR = 0.82
local SURFACE_PARTS = { "Grain", "Edge", "Texture", "Detail", "Lip" }

local function isTextObject(target: GuiObject): boolean
	if target:IsA("TextBox") then
		return true
	end
	return (target:IsA("TextLabel") or target:IsA("TextButton")) and (target :: any).Text ~= ""
end

local function detail(
	target: GuiObject,
	size: UDim2,
	position: UDim2,
	color: Color3,
	transparency: number,
	round: boolean
): Frame
	local d = Instance.new("Frame")
	d.Name = "Detail"
	d.Size = size
	d.Position = position
	d.BackgroundColor3 = color
	d.BackgroundTransparency = transparency
	d.BorderSizePixel = 0
	d.ZIndex = 0
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = d
	end
	d.Parent = target
	return d
end

-- Small shapes drawn in code that sell the material: plank seams, corner
-- rivets, brick studs, rune diamonds, a top highlight. They sit under the
-- surface's own children (ZIndex 0), and only on frames built once, never on
-- list rows or cards.
local function addDetails(target: GuiObject, material: string, m: Material, base: Color3)
	if material == "wood" then
		for _, y in { 0.34, 0.67 } do
			detail(target, UDim2.new(1, -8, 0, 2), UDim2.new(0, 4, y, 0), m.edge, 0.55, false)
		end
	elseif material == "metal" then
		local inset = 5
		for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
			local rivet = detail(
				target,
				UDim2.fromOffset(5, 5),
				UDim2.new(
					corner.X,
					if corner.X == 0 then inset else -inset,
					corner.Y,
					if corner.Y == 0 then inset else -inset
				),
				Color3.fromRGB(200, 208, 220),
				0.2,
				true
			)
			rivet.AnchorPoint = corner
		end
	elseif material == "studs" then
		-- Studs stand up off the top edge, like a toy brick seen from the side.
		for _, x in { 0.2, 0.5, 0.8 } do
			local stud = detail(
				target,
				UDim2.fromOffset(12, 5),
				UDim2.new(x, 0, 0, 1),
				base:Lerp(Color3.new(1, 1, 1), 0.18),
				0,
				false
			)
			stud.AnchorPoint = Vector2.new(0.5, 1)
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 2)
			c.Parent = stud
		end
	elseif material == "plate" then
		-- Embossed studs across the whole plate: a staggered grid, lighter than
		-- the plate and faint enough that text stays above 4.5:1. The public
		-- stud tile (6927295847) loaded but drew blank in Studio (no permission
		-- for our place), so they are drawn in code.
		local columns, rows = 12, 9
		for row = 0, rows - 1 do
			for column = 0, columns - 1 do
				local stud = detail(
					target,
					UDim2.fromOffset(16, 16),
					UDim2.new((column + 0.5 + (row % 2) * 0.5) / (columns + 0.5), 0, (row + 0.5) / rows, 0),
					base:Lerp(Color3.new(1, 1, 1), 0.3),
					0.55,
					true
				)
				stud.AnchorPoint = Vector2.new(0.5, 0.5)
			end
		end
	elseif material == "gem" then
		-- A glossy top half and a carved rune diamond at each end.
		local gloss =
			detail(target, UDim2.new(1, -10, 0.42, 0), UDim2.fromOffset(5, 3), Color3.new(1, 1, 1), 0.86, false)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = gloss
		for _, x in { 0, 1 } do
			local rune = detail(
				target,
				UDim2.fromOffset(9, 9),
				UDim2.new(x, if x == 0 then 9 else -9, 0.5, 0),
				Color3.new(1, 1, 1),
				0.55,
				false
			)
			rune.AnchorPoint = Vector2.new(0.5, 0.5)
			rune.Rotation = 45
		end
	end
	-- A thin light line along the top reads as a bevel on every material.
	detail(target, UDim2.new(1, -12, 0, 1), UDim2.fromOffset(6, 2), Color3.new(1, 1, 1), 0.82, false)
end

-- Dresses a frame or button in a material. Safe to call again to change it.
-- `tint` swaps the base color (a style, a header, a rarity) and keeps the
-- grain. `details` adds the code-drawn shapes above. Returns the edge stroke
-- so callers can recolor it (rune glow, gold rim, rarity border). A text
-- outline stroke (named "Outline") is left alone.
function Ui.surface(
	target: GuiObject,
	material: string,
	options: { tint: Color3?, details: boolean?, lip: boolean? }?
): UIStroke
	local m = Ui.Materials[material]
	local opts: { tint: Color3?, details: boolean?, lip: boolean? } = options or {}
	for _, name in SURFACE_PARTS do
		for _, child in target:GetChildren() do
			if child.Name == name then
				child:Destroy()
			end
		end
	end
	for _, child in target:GetChildren() do
		if
			(child:IsA("UIStroke") and child.Name ~= "Outline") or (child:IsA("UIGradient") and child.Name ~= "Gloss")
		then
			child:Destroy()
		end
	end

	local base = opts.tint or m.color
	target.BackgroundColor3 = base
	-- Keep the panel's own transparency, scaled by PreferredTransparency.
	local own = target:GetAttribute("BaseTransparency")
	if type(own) ~= "number" then
		own = target.BackgroundTransparency
		target:SetAttribute("BaseTransparency", own)
	end
	target.BackgroundTransparency = Ui.transparency(own :: number)
	local onText = isTextObject(target)

	local keypoints = {}
	for index, value in m.grain do
		local v = if onText then math.max(value, TEXT_GRAIN_FLOOR) else value
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#m.grain - 1), Color3.new(v, v, v)))
	end
	local grain = Instance.new("UIGradient")
	grain.Name = "Grain"
	grain.Rotation = m.rotation
	grain.Color = ColorSequence.new(keypoints)
	grain.Parent = target

	local edge = Instance.new("UIStroke")
	edge.Name = "Edge"
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = m.edge
	edge.Thickness = m.edgeWidth
	edge.Parent = target

	local imageId = Config.UiTextures[m.texture or material]
	if imageId and imageId ~= 0 and not onText then
		local texture = Instance.new("ImageLabel")
		texture.Name = "Texture"
		texture.BackgroundTransparency = 1
		texture.Size = UDim2.fromScale(1, 1)
		texture.Image = `rbxassetid://{imageId}`
		texture.ScaleType = Enum.ScaleType.Tile
		texture.TileSize = UDim2.fromOffset(m.tile, m.tile)
		texture.ImageColor3 = base
		texture.ImageTransparency = m.imageTransparency
		texture.ZIndex = 0
		local corner = target:FindFirstChildOfClass("UICorner")
		if corner then
			corner:Clone().Parent = texture
		end
		texture.Parent = target
	end

	-- The stud look: a darker band of the same hue along the bottom of every
	-- button and header bar, as if the face sat on a thicker base.
	if material == "gem" and not onText and opts.lip ~= false then
		local lip = Instance.new("Frame")
		lip.Name = "Lip"
		lip.Size = UDim2.new(1, -6, 0.14, 0)
		lip.Position = UDim2.new(0, 3, 0.86, -2)
		lip.BackgroundColor3 = base:Lerp(Color3.new(0, 0, 0), 0.5)
		lip.BorderSizePixel = 0
		lip.ZIndex = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = lip
		lip.Parent = target
	end

	if opts.details then
		addDetails(target, material, m, base)
	end
	return edge
end

-- Bar fills get a glossy top and a darker base so they read as liquid or
-- light inside the bar frame.
function Ui.fill(target: GuiObject, color: Color3)
	target.BackgroundColor3 = color
	local old = target:FindFirstChild("Gloss")
	if old then
		old:Destroy()
	end
	local gloss = Instance.new("UIGradient")
	gloss.Name = "Gloss"
	gloss.Rotation = 90
	gloss.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.35, Color3.new(0.92, 0.92, 0.92)),
		ColorSequenceKeypoint.new(1, Color3.new(0.68, 0.68, 0.68)),
	})
	gloss.Parent = target
end

---------------------------------------------------------------- text

-- The thick near-black outline every label gets. A UIStroke in Contextual
-- mode outlines the text itself, not the box.
function Ui.outline(target: GuiObject, thickness: number?): UIStroke
	local old = target:FindFirstChild("Outline")
	if old then
		old:Destroy()
	end
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Ui.Colors.outline
	stroke.Thickness = thickness or 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = target
	return stroke
end

-- A text size that fits a fixed-height box, never below body size.
local function fitSize(size: UDim2): number
	local height = size.Y.Offset
	if size.Y.Scale ~= 0 or height <= 0 then
		return Ui.TextSize.body
	end
	return math.clamp(math.floor(height * 0.82), Ui.TextSize.body, 40)
end

-- An outlined label. `props` sets any TextLabel property; `Title = true`
-- picks the heavy title font. Text wraps, and the size is fixed so the
-- player's text-size setting still applies.
function Ui.label(parent: Instance, text: string, size: UDim2, position: UDim2, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.Text = text
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.TextColor3 = Ui.Colors.text
	l.FontFace = Ui.Fonts.body
	l.TextSize = fitSize(size)
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	Ui.outline(l, if l.TextSize >= Ui.TextSize.big then 3 else 2)
	for key, value in props or ({} :: any) do
		if key == "Title" then
			l.FontFace = Ui.Fonts.title
		else
			(l :: any)[key] = value
		end
	end
	l.Parent = parent
	return l
end

-- A label that grows to fit its text: full width of its parent column.
function Ui.text(parent: Instance, text: string, textSize: number, props: { [string]: any }?): TextLabel
	local l = Ui.label(parent, text, UDim2.fromScale(1, 0), UDim2.new(), props)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextSize = textSize
	Ui.outline(l, if textSize >= Ui.TextSize.big then 3 else 2)
	return l
end

-- Short numbers for big amounts: 950, 1.2K, 34K, 5.6M, 7.8B, 9.1T.
function Ui.short(value: number): string
	local n = math.floor(value)
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		return sign .. tostring(n)
	end
	local units: { { size: number, suffix: string } } = {
		{ size = 1e12, suffix = "T" },
		{ size = 1e9, suffix = "B" },
		{ size = 1e6, suffix = "M" },
		{ size = 1e3, suffix = "K" },
	}
	for _, unit in units do
		local size, suffix = unit.size, unit.suffix
		if n >= size then
			local scaled = n / size
			local digits = if scaled >= 100 then "%.0f" elseif scaled >= 10 then "%.1f" else "%.2f"
			local s = string.format(digits, math.floor(scaled * 100) / 100)
			if string.find(s, ".", 1, true) then
				s = (string.gsub(s, "0+$", ""))
				s = (string.gsub(s, "%.$", ""))
			end
			return sign .. s .. suffix
		end
	end
	return sign .. tostring(n)
end

---------------------------------------------------------------- buttons

-- "primary", "secondary", "robux" or "danger" (see Ui.Styles).
export type ButtonStyle = string

-- Sets the visible words on a kit button (the text lives in a child label
-- so the button can carry a texture under outlined text).
function Ui.setText(button: GuiObject, text: string)
	local label = button:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

-- A chunky button. `style` picks its color (primary green by default); a
-- disabled button is dull gray with quiet text and ignores taps. A robux
-- button shows the Robux icon before its price, always.
function Ui.button(
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2,
	enabled: boolean,
	onClick: () -> (),
	style: ButtonStyle?
): TextButton
	local kind: ButtonStyle = style or "primary"
	local b = Instance.new("TextButton")
	b.Text = ""
	b.Size = size
	b.Position = position
	b.AutoButtonColor = enabled
	b.Parent = parent
	Ui.corner(b, 10)
	Ui.surface(b, "gem", { tint = if enabled then Ui.Styles[kind] else Ui.Styles.disabled })
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(48, 48)
	minimum.Parent = b

	local inset = 8
	if kind == "robux" then
		local icon = Icons.create(b, "robux", 24, UDim2.new(0, 8, 0.5, 0))
		icon.AnchorPoint = Vector2.new(0, 0.5)
		inset = 34
	end
	local label = Ui.label(b, text, UDim2.new(1, -inset - 6, 1, -4), UDim2.fromOffset(inset, 2), {
		Name = "Label",
		Title = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = if enabled then Ui.Colors.text else Ui.Colors.quiet,
		TextSize = 20,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	label.ZIndex = b.ZIndex + 1
	-- Short labels like "OK" or "Max" read better a touch bigger.
	if #text <= 3 then
		label.TextSize = 22
	end
	if enabled then
		-- Hover and press feedback is the scale; with Reduced Motion on, the
		-- built-in color change stays instead.
		b.AutoButtonColor = Ui.reducedMotion()
		Ui.pressable(b)
		b.Activated:Connect(function()
			Sfx.play("click")
			onClick()
		end)
	end
	return b
end

-- The square red X every window and dialog closes with.
function Ui.closeButton(parent: Instance, position: UDim2, onClick: () -> ()): TextButton
	local close = Ui.button(parent, "", UDim2.fromOffset(48, 48), position, true, onClick, "danger")
	close.Name = "Close"
	local icon = Icons.create(close, "close", 30, UDim2.fromScale(0.5, 0.5))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	return close
end

-- A red "!" badge on a button's top-right corner when something is ready.
-- It is a symbol as well as a color.
function Ui.badge(target: GuiObject, visible: boolean)
	local badge = target:FindFirstChild("Badge") :: GuiObject?
	if not badge then
		local b = Instance.new("TextLabel")
		b.Name = "Badge"
		b.Text = "!"
		b.FontFace = Ui.Fonts.title
		b.TextSize = 20
		b.TextColor3 = Ui.Colors.text
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.new(1, -4, 0, 4)
		b.Size = UDim2.fromOffset(26, 26)
		b.BackgroundColor3 = Ui.Colors.bad
		b.ZIndex = target.ZIndex + 5
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = b
		local ring = Instance.new("UIStroke")
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Color = Ui.Colors.outline
		ring.Thickness = 3
		ring.Parent = b
		b.Parent = target
		badge = b
	end
	(badge :: GuiObject).Visible = visible
end

-- A small colored chip with words, for tags like "Leader" or "Friend".
function Ui.chip(parent: Instance, text: string, color: Color3, order: number?): Frame
	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, 28)
	chip.BackgroundColor3 = color
	chip.LayoutOrder = order or 0
	chip.Parent = parent
	Ui.corner(chip, 8)
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color = Ui.Colors.outline
	rim.Thickness = 2
	rim.Parent = chip
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, 10)
	p.PaddingRight = UDim.new(0, 10)
	p.Parent = chip
	local l = Ui.label(chip, text, UDim2.fromScale(0, 1), UDim2.new(), { TextSize = Ui.TextSize.body, Title = true })
	l.AutomaticSize = Enum.AutomaticSize.X
	l.TextWrapped = false
	return chip
end

---------------------------------------------------------------- window

export type Window = {
	frame: Frame,
	header: Frame,
	title: TextLabel,
	body: Frame,
	close: TextButton,
	setTheme: (title: string, color: Color3, icon: string?) -> (),
}

local HEADER_HEIGHT = 60

-- A menu window: a dark stud plate, a chunky colored header bar with an icon
-- slot, a big title and the red X. Put content in `body`.
function Ui.window(parent: Instance, title: string, color: Color3, icon: string?, onClose: () -> ()): Window
	local frame = Instance.new("Frame")
	frame.Name = "Window"
	frame.BackgroundTransparency = 0.02
	frame.Parent = parent
	Ui.corner(frame, 16)
	Ui.surface(frame, "plate", { details = true })

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, -12, 0, HEADER_HEIGHT)
	header.Position = UDim2.fromOffset(6, 6)
	header.ZIndex = 2
	header.Parent = frame
	Ui.corner(header, 12)

	local titleLabel = Ui.label(header, title, UDim2.new(1, -140, 1, 0), UDim2.fromOffset(66, 0), {
		Name = "Title",
		Title = true,
		TextSize = Ui.TextSize.title,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		ZIndex = 3,
	})
	Ui.outline(titleLabel, 3)

	local close = Ui.closeButton(header, UDim2.new(1, -54, 0.5, -24), onClose)
	close.ZIndex = 3

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -20, 1, -HEADER_HEIGHT - 22)
	body.Position = UDim2.fromOffset(10, HEADER_HEIGHT + 14)
	body.Parent = frame

	local iconObject: GuiObject? = nil
	local function setTheme(text: string, tint: Color3, iconKey: string?)
		titleLabel.Text = string.upper(text)
		Ui.surface(header, "gem", { tint = tint, details = true })
		if iconObject then
			iconObject:Destroy()
			iconObject = nil
		end
		if iconKey then
			local made = Icons.create(header, iconKey, 44, UDim2.new(0, 14, 0.5, 0))
			made.AnchorPoint = Vector2.new(0, 0.5)
			made.ZIndex = 3
			iconObject = made
		end
	end
	setTheme(title, color, icon)

	return {
		frame = frame,
		header = header,
		title = titleLabel,
		body = body,
		close = close,
		setTheme = setTheme,
	}
end

-- A scrolling list for a window body, rows stacked top to bottom.
function Ui.scrollList(parent: Instance): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = Ui.Colors.quiet
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = parent
	local layout = Ui.listLayout(list, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 6)
	p.PaddingBottom = UDim.new(0, 10)
	p.PaddingRight = UDim.new(0, 6)
	p.Parent = list
	return list
end

---------------------------------------------------------------- progress

export type ProgressOptions = {
	label: string?,
	current: number,
	max: number,
	icon: string?,
	hint: string?,
	color: Color3?,
	order: number?,
	-- What a finished bar says on the right; "DONE!" by default.
	doneText: string?,
}

-- A labelled bar: label on the left, "N TO GO" on the right, the numbers in
-- the bar, an icon at the start and an optional hint underneath.
function Ui.progress(parent: Instance, opts: ProgressOptions): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Progress"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = opts.order or 0
	frame.Parent = parent
	Ui.listLayout(frame, 4)

	local max = math.max(opts.max, 1)
	local current = math.clamp(opts.current, 0, max)
	local left = max - current
	local hasLabel = opts.label ~= nil

	if hasLabel then
		local top = Instance.new("Frame")
		top.BackgroundTransparency = 1
		top.Size = UDim2.new(1, 0, 0, 26)
		top.LayoutOrder = 1
		top.Parent = frame
		local inset = 0
		if opts.icon then
			local icon = Icons.create(top, opts.icon, 26, UDim2.new())
			icon.ZIndex = top.ZIndex + 1
			inset = 32
		end
		Ui.label(top, string.upper(opts.label or ""), UDim2.new(0.6, -inset, 1, 0), UDim2.fromOffset(inset, 0), {
			Title = true,
			TextSize = Ui.TextSize.body,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
		})
		Ui.label(
			top,
			if left <= 0 then (opts.doneText or "DONE!") else `{Ui.short(left)} TO GO`,
			UDim2.new(0.4, 0, 1, 0),
			UDim2.fromScale(0.6, 0),
			{
				Title = true,
				TextSize = Ui.TextSize.body,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = if left <= 0 then Ui.Colors.good else Ui.Colors.gold,
				TextWrapped = false,
			}
		)
	end

	local back = Instance.new("Frame")
	back.Name = "Bar"
	back.Size = UDim2.new(1, 0, 0, 28)
	back.LayoutOrder = 2
	back.Parent = frame
	Ui.corner(back, 10)
	local rim = Ui.surface(back, "metal", { tint = Color3.fromRGB(20, 22, 32) })
	rim.Color = Ui.Colors.outline
	rim.Thickness = 3
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(current / max, 1)
	fill.ZIndex = back.ZIndex + 1
	fill.Parent = back
	Ui.corner(fill, 10)
	Ui.fill(fill, opts.color or (if left <= 0 then Ui.Colors.good else Ui.Colors.rune))
	if not hasLabel and opts.icon then
		local icon = Icons.create(back, opts.icon, 26, UDim2.new(0, 2, 0.5, 0))
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.ZIndex = back.ZIndex + 3
	end
	Ui.label(back, `{Ui.short(current)} / {Ui.short(max)}`, UDim2.fromScale(1, 1), UDim2.new(), {
		Title = true,
		TextSize = Ui.TextSize.body,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = back.ZIndex + 2,
		TextWrapped = false,
	})

	if opts.hint then
		local hint = Ui.text(frame, opts.hint, Ui.TextSize.body, { TextColor3 = Ui.Colors.quiet })
		hint.LayoutOrder = 3
	end
	return frame
end

---------------------------------------------------------------- checklist

-- Up to three steps: done ones get a tick, the current one a gold dot, later
-- ones are dimmed but readable.
function Ui.checklist(parent: Instance, steps: { string }, current: number, order: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Checklist"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order or 0
	frame.Parent = parent
	Ui.listLayout(frame, 4)
	for index, step in steps do
		if index > 3 then
			break
		end
		local done = index < current
		local now = index == current
		local line = Instance.new("Frame")
		line.BackgroundTransparency = 1
		line.Size = UDim2.fromScale(1, 0)
		line.AutomaticSize = Enum.AutomaticSize.Y
		line.LayoutOrder = index
		line.Parent = frame

		local marker = Instance.new("Frame")
		marker.Size = UDim2.fromOffset(24, 24)
		marker.Position = UDim2.fromOffset(0, 1)
		marker.BackgroundColor3 = if done then Ui.Styles.primary elseif now then Ui.Colors.gold else Ui.Colors.row
		marker.Parent = line
		Ui.corner(marker, 12)
		local ring = Instance.new("UIStroke")
		ring.Color = if now then Ui.Colors.outline else Ui.Colors.dim
		ring.Thickness = 2
		ring.Parent = marker
		if done then
			local tick = Icons.create(marker, "tick", 20, UDim2.fromScale(0.5, 0.5))
			tick.AnchorPoint = Vector2.new(0.5, 0.5)
		end

		local l = Ui.label(line, step, UDim2.new(1, -34, 0, 0), UDim2.fromOffset(34, 0), {
			TextSize = Ui.TextSize.body,
			TextColor3 = if now then Ui.Colors.text elseif done then Ui.Colors.quiet else Ui.Colors.dim,
			AutomaticSize = Enum.AutomaticSize.Y,
		})
		if now then
			l.FontFace = Ui.Fonts.title
		end
	end
	return frame
end

---------------------------------------------------------------- lists

-- A section heading inside a list, with an optional icon.
function Ui.heading(parent: Instance, order: number, text: string, icon: string?): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Heading"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, -8, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.Parent = parent
	local inset = 0
	if icon then
		Icons.create(frame, icon, 32, UDim2.fromOffset(0, 2))
		inset = 40
	end
	local l = Ui.label(frame, text, UDim2.new(1, -inset, 0, 0), UDim2.fromOffset(inset, 0), {
		Title = true,
		TextSize = Ui.TextSize.heading,
		TextColor3 = Ui.Colors.gold,
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Ui.outline(l, 3)
	return frame
end

-- A line of big stat chips at the top of a menu ("3 / 5 equipped").
function Ui.summary(parent: Instance, order: number, items: { { icon: string?, text: string } }): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Summary"
	frame.Size = UDim2.new(1, -8, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.Parent = parent
	Ui.corner(frame, 12)
	Ui.surface(frame, "studs", { tint = Ui.Colors.card })
	Ui.padding(frame, 8)
	local layout = Ui.listLayout(frame, 10, true)
	layout.Wraps = true
	for index, item in items do
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1
		cell.AutomaticSize = Enum.AutomaticSize.X
		cell.Size = UDim2.fromOffset(0, 36)
		cell.LayoutOrder = index
		cell.Parent = frame
		local inset = 0
		if item.icon then
			local icon = Icons.create(cell, item.icon, 32, UDim2.new(0, 0, 0.5, 0))
			icon.AnchorPoint = Vector2.new(0, 0.5)
			inset = 38
		end
		local l = Ui.label(cell, item.text, UDim2.fromScale(0, 1), UDim2.fromOffset(inset, 0), {
			Title = true,
			TextSize = Ui.TextSize.big,
			TextWrapped = false,
		})
		l.AutomaticSize = Enum.AutomaticSize.X
		Ui.outline(l, 3)
	end
	return frame
end

export type Action = {
	text: string,
	enabled: boolean?,
	style: ButtonStyle?,
	onClick: (() -> ())?,
}

export type ItemOptions = {
	title: string,
	subtitle: string?,
	icon: string?,
	-- A colored stripe down the left edge (island color, tier color).
	accent: Color3?,
	-- A gold rim when something here is ready to collect.
	ready: boolean?,
	tint: Color3?,
	action: Action?,
	second: Action?,
	progress: ProgressOptions?,
	chips: { { text: string, color: Color3 } }?,
}

local ACTION_WIDTH = 124
local SECOND_WIDTH = 104

-- A list row: an icon, a bold title, a quieter line, an optional progress
-- bar or chips, and up to two buttons on the right. Grows to fit its text.
function Ui.item(parent: Instance, order: number, opts: ItemOptions): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Row"
	frame.Size = UDim2.new(1, -8, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.Parent = parent
	Ui.corner(frame, 12)
	local edge = Ui.surface(frame, "studs", { tint = opts.tint or Ui.Colors.row })
	if opts.ready then
		edge.Color = Ui.Colors.gold
		edge.Thickness = 3
	end
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 8)
	p.PaddingBottom = UDim.new(0, 8)
	p.PaddingLeft = UDim.new(0, if opts.accent then 16 else 10)
	p.PaddingRight = UDim.new(0, 8)
	p.Parent = frame
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(0, 64)
	minimum.Parent = frame

	if opts.accent then
		local stripe = Instance.new("Frame")
		stripe.Name = "Accent"
		stripe.BackgroundColor3 = opts.accent
		stripe.BorderSizePixel = 0
		stripe.Size = UDim2.new(0, 6, 1, 0)
		stripe.Position = UDim2.fromOffset(-10, 0)
		stripe.Parent = frame
		Ui.corner(stripe, 3)
	end

	local inset = 0
	if opts.icon then
		Icons.create(frame, opts.icon, 40, UDim2.fromOffset(0, 4))
		inset = 50
	end
	local right = (if opts.action then ACTION_WIDTH else 0) + (if opts.second then SECOND_WIDTH else 0)

	local column = Instance.new("Frame")
	column.Name = "Text"
	column.BackgroundTransparency = 1
	column.Position = UDim2.fromOffset(inset, 0)
	column.Size = UDim2.new(1, -inset - right, 0, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.Parent = frame
	Ui.listLayout(column, 4)

	local title = Ui.text(column, opts.title, 20, { Title = true, Name = "Title" })
	title.LayoutOrder = 1
	if opts.subtitle and opts.subtitle ~= "" then
		local sub =
			Ui.text(column, opts.subtitle, Ui.TextSize.body, { TextColor3 = Ui.Colors.quiet, Name = "Subtitle" })
		sub.LayoutOrder = 2
	end
	if opts.chips and #opts.chips > 0 then
		local chips = Instance.new("Frame")
		chips.BackgroundTransparency = 1
		chips.Size = UDim2.new(1, 0, 0, 28)
		chips.LayoutOrder = 3
		chips.Parent = column
		Ui.listLayout(chips, 6, true)
		for index, chip in opts.chips do
			Ui.chip(chips, chip.text, chip.color, index)
		end
	end
	if opts.progress then
		local progressOpts = table.clone(opts.progress)
		progressOpts.order = 4
		Ui.progress(column, progressOpts)
	end

	local function place(action: Action, width: number, x: number, name: string)
		local b = Ui.button(
			frame,
			action.text,
			UDim2.fromOffset(width - 8, 48),
			UDim2.new(1, -x, 0, 0),
			action.enabled ~= false,
			action.onClick or function() end,
			action.style
		)
		b.Name = name
	end
	if opts.action then
		place(opts.action, ACTION_WIDTH, ACTION_WIDTH - 8, "Action")
	end
	if opts.second then
		place(opts.second, SECOND_WIDTH, right - 8, "Second")
	end
	return frame
end

-- The older row call, kept so screens can move to Ui.item one at a time.
function Ui.row(
	parent: Instance,
	order: number,
	title: string,
	subtitle: string?,
	buttonText: string?,
	enabled: boolean?,
	onClick: (() -> ())?,
	iconKey: string?
): Frame
	return Ui.item(parent, order, {
		title = title,
		subtitle = subtitle,
		icon = iconKey,
		action = if buttonText then { text = buttonText, enabled = enabled == true, onClick = onClick } else nil,
	})
end

-- A friendly empty state: what's missing, then what to do.
function Ui.empty(parent: Instance, order: number, line1: string, line2: string?, action: Action?): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Empty"
	frame.Size = UDim2.new(1, -8, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.Parent = parent
	Ui.corner(frame, 12)
	Ui.surface(frame, "studs", { tint = Ui.Colors.card })
	Ui.padding(frame, 16)
	local layout = Ui.listLayout(frame, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local first = Ui.text(frame, line1, Ui.TextSize.big, { Title = true, TextXAlignment = Enum.TextXAlignment.Center })
	first.LayoutOrder = 1
	if line2 then
		local second = Ui.text(
			frame,
			line2,
			Ui.TextSize.body,
			{ TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Ui.Colors.quiet }
		)
		second.LayoutOrder = 2
	end
	if action then
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(200, 52)
		holder.LayoutOrder = 3
		holder.Parent = frame
		Ui.button(
			holder,
			action.text,
			UDim2.fromOffset(200, 48),
			UDim2.fromOffset(0, 4),
			action.enabled ~= false,
			action.onClick or function() end,
			action.style
		)
	end
	return frame
end

-- A grid of cards inside a list. Cells are `cell` pixels.
function Ui.grid(parent: Instance, order: number, cell: Vector2): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Grid"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, -8, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.Parent = parent
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = frame
	return frame
end

-- A row of toggle buttons (sort or filter). The chosen one is primary.
function Ui.toggles(
	parent: Instance,
	order: number,
	options: { { id: string, text: string } },
	chosen: string,
	onPick: (id: string) -> ()
): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Toggles"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, -8, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.Parent = parent
	local layout = Ui.listLayout(frame, 8, true)
	layout.Wraps = true
	for index, option in options do
		local b = Ui.button(frame, option.text, UDim2.fromOffset(120, 48), UDim2.new(), true, function()
			onPick(option.id)
		end, if option.id == chosen then "primary" else "secondary")
		b.LayoutOrder = index
	end
	return frame
end

---------------------------------------------------------------- rarity

export type Rarity = { name: string, color: Color3, dark: Color3, icon: string }

-- The shared rarity table (Config.Rarities): color, dark card color, name.
function Ui.rarity(id: string?): Rarity
	local entry = id and (Config.Rarities :: any)[id]
	if entry then
		return { name = entry.name, color = entry.color, dark = entry.dark, icon = id :: string }
	end
	return { name = "", color = Ui.Colors.dim, dark = Ui.Colors.card, icon = "common" }
end

export type CardOptions = {
	title: string,
	-- A rarity id from Config.Rarities, or nil for a plain card.
	rarity: string?,
	-- Colors when the card isn't a rarity (a tier, a locked item).
	color: Color3?,
	dark: Color3?,
	-- The small line under the title; the rarity name is added in front.
	line: string?,
	icon: string?,
	stat: string?,
	statColor: Color3?,
	ticked: boolean?,
	locked: boolean?,
	order: number?,
	buttons: { Action }?,
}

Ui.CardSize = Vector2.new(180, 252)

-- A tall item card. Its border and background take the rarity color, the
-- rarity is always named next to its symbol, the picture sits in the middle,
-- the stat in big text, then up to two buttons.
function Ui.card(parent: Instance, opts: CardOptions): Frame
	local rarity = if opts.rarity then Ui.rarity(opts.rarity) else nil
	local color = if opts.locked
		then Color3.fromRGB(90, 96, 112)
		else (if rarity then rarity.color else opts.color or Ui.Colors.dim)
	local dark = if opts.locked
		then Color3.fromRGB(30, 34, 46)
		else (if rarity then rarity.dark else opts.dark or Ui.Colors.card)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromOffset(Ui.CardSize.X, Ui.CardSize.Y)
	card.LayoutOrder = opts.order or 0
	card.Parent = parent
	Ui.corner(card, 14)
	local edge = Ui.surface(card, "studs", { tint = dark })
	edge.Color = color
	edge.Thickness = 4

	local y = 8
	local title = Ui.label(card, opts.title, UDim2.new(1, -16, 0, 44), UDim2.fromOffset(8, y), {
		Title = true,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	title.Name = "Title"
	y += 46

	local lineText = opts.line or ""
	if rarity then
		lineText = if lineText ~= "" then `{rarity.name} · {lineText}` else rarity.name
	end
	if lineText ~= "" then
		local inset = 0
		if rarity then
			Icons.create(card, rarity.icon, 22, UDim2.fromOffset(10, y), color)
			inset = 26
		end
		Ui.label(card, lineText, UDim2.new(1, -20 - inset, 0, 22), UDim2.fromOffset(10 + inset, y), {
			TextSize = Ui.TextSize.body,
			TextColor3 = if rarity then color:Lerp(Color3.new(1, 1, 1), 0.45) else Ui.Colors.quiet,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			TextXAlignment = if rarity then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		})
	end
	y += 26

	-- The picture: the item's icon on a soft glow, or a big "?" when unknown.
	local glow = Instance.new("Frame")
	glow.Name = "Picture"
	glow.AnchorPoint = Vector2.new(0.5, 0)
	glow.Position = UDim2.new(0.5, 0, 0, y)
	glow.Size = UDim2.fromOffset(64, 64)
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = if opts.locked then 0.8 else 0.6
	glow.Parent = card
	Ui.corner(glow, 32)
	if opts.locked then
		local mark = Ui.label(glow, "?", UDim2.fromScale(1, 1), UDim2.new(), {
			Title = true,
			TextSize = 44,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Ui.Colors.quiet,
		})
		Ui.outline(mark, 3)
	elseif opts.icon then
		local icon = Icons.create(glow, opts.icon, 52, UDim2.fromScale(0.5, 0.5))
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	y += 68

	if opts.stat then
		local stat = Ui.label(card, opts.stat, UDim2.new(1, -16, 0, 46), UDim2.fromOffset(8, y), {
			Title = true,
			TextSize = if #opts.stat > 16 then Ui.TextSize.body else 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextColor3 = opts.statColor or (if opts.locked then Ui.Colors.quiet else Ui.Colors.good),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		stat.Name = "Stat"
	end

	local buttons = opts.buttons or {}
	if #buttons > 0 then
		local count = math.min(#buttons, 2)
		local width = (Ui.CardSize.X - 16 - (count - 1) * 6) / count
		for index = 1, count do
			local action = buttons[index]
			Ui.button(
				card,
				action.text,
				UDim2.fromOffset(width, 48),
				UDim2.new(0, 8 + (index - 1) * (width + 6), 1, -56),
				action.enabled ~= false,
				action.onClick or function() end,
				action.style
			)
		end
	end

	if opts.ticked then
		local tick = Instance.new("Frame")
		tick.Name = "Tick"
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.new(1, -8, 0, 8)
		tick.Size = UDim2.fromOffset(30, 30)
		tick.BackgroundColor3 = Ui.Styles.primary
		tick.ZIndex = card.ZIndex + 4
		tick.Parent = card
		Ui.corner(tick, 15)
		local ring = Instance.new("UIStroke")
		ring.Color = Ui.Colors.outline
		ring.Thickness = 3
		ring.Parent = tick
		local icon = Icons.create(tick, "tick", 24, UDim2.fromScale(0.5, 0.5))
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	return card
end

---------------------------------------------------------------- dialog

export type DialogOptions = {
	name: string,
	portrait: string?,
	text: string,
	progress: ProgressOptions?,
	confirmText: string?,
	confirmStyle: ButtonStyle?,
	onConfirm: (() -> ())?,
	cancelText: string?,
	color: Color3?,
}

local dialogGui: ScreenGui? = nil
local openDialogs: { () -> () } = {}

local function getDialogGui(): ScreenGui
	if dialogGui and dialogGui.Parent then
		return dialogGui
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "GolemDialogs"
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	dialogGui = gui
	return gui
end

-- A speech-bubble dialog: a portrait with a name tag, a cream bubble with one
-- or two friendly sentences, an optional progress bar, and a "Got it!"
-- button. Closes with the button, the X, Escape or gamepad B (Ui.closeTop).
-- Returns a function that closes it.
function Ui.dialog(opts: DialogOptions): () -> ()
	local gui = getDialogGui()
	local shade = Instance.new("TextButton")
	shade.Name = "DialogShade"
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.Parent = gui

	local window = Ui.window(shade, opts.name, opts.color or Ui.Headers.guide, opts.portrait, function() end)
	local panel = window.frame
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.9, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, math.huge)
	limit.Parent = panel
	local body = window.body
	body.Size = UDim2.new(1, -20, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	local bottom = Instance.new("UIPadding")
	bottom.PaddingBottom = UDim.new(0, 12)
	bottom.Parent = body
	Ui.listLayout(body, 10)

	-- The portrait and its name tag, beside the bubble.
	local top = Instance.new("Frame")
	top.BackgroundTransparency = 1
	top.Size = UDim2.fromScale(1, 0)
	top.AutomaticSize = Enum.AutomaticSize.Y
	top.LayoutOrder = 1
	top.Parent = body
	local portrait = Instance.new("Frame")
	portrait.Size = UDim2.fromOffset(84, 84)
	portrait.BackgroundColor3 = Ui.Colors.card
	portrait.Parent = top
	Ui.corner(portrait, 42)
	local portraitRim = Instance.new("UIStroke")
	portraitRim.Color = Ui.Colors.gold
	portraitRim.Thickness = 3
	portraitRim.Parent = portrait
	local face = Icons.create(portrait, opts.portrait or "guide", 68, UDim2.fromScale(0.5, 0.5))
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	local tag = Ui.chip(top, opts.name, Ui.Headers.guide)
	tag.AnchorPoint = Vector2.new(0.5, 0)
	tag.Position = UDim2.fromOffset(42, 80)

	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.BackgroundColor3 = Ui.Colors.bubble
	bubble.Position = UDim2.fromOffset(104, 0)
	bubble.Size = UDim2.new(1, -104, 0, 0)
	bubble.AutomaticSize = Enum.AutomaticSize.Y
	bubble.Parent = top
	Ui.corner(bubble, 14)
	Ui.padding(bubble, 12)
	local bubbleRim = Instance.new("UIStroke")
	bubbleRim.Color = Ui.Colors.outline
	bubbleRim.Thickness = 3
	bubbleRim.Parent = bubble
	local tail = Instance.new("Frame")
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.fromOffset(-12, 30)
	tail.Size = UDim2.fromOffset(16, 16)
	tail.Rotation = 45
	tail.BackgroundColor3 = Ui.Colors.bubble
	tail.BorderSizePixel = 0
	tail.Parent = bubble
	local words = Ui.label(bubble, opts.text, UDim2.fromScale(1, 0), UDim2.new(), {
		TextSize = 20,
		TextColor3 = Ui.Colors.bubbleText,
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	-- Dark text on cream needs no outline.
	local outline = words:FindFirstChild("Outline")
	if outline then
		outline:Destroy()
	end
	-- Leave room under the portrait's name tag.
	local spacer = Instance.new("Frame")
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.fromOffset(1, 112)
	spacer.Parent = top

	if opts.progress then
		local progressOpts = table.clone(opts.progress)
		progressOpts.order = 2
		Ui.progress(body, progressOpts)
	end

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		local index = table.find(openDialogs, close)
		if index then
			table.remove(openDialogs, index)
		end
		shade:Destroy()
	end
	table.insert(openDialogs, close)
	window.close.Activated:Connect(close)

	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.Size = UDim2.new(1, 0, 0, 52)
	buttons.LayoutOrder = 3
	buttons.Parent = body
	local confirm = Ui.button(
		buttons,
		opts.confirmText or "Got it!",
		UDim2.fromOffset(180, 48),
		UDim2.new(1, -180, 0, 2),
		true,
		function()
			close()
			if opts.onConfirm then
				opts.onConfirm()
			end
		end,
		opts.confirmStyle
	)
	confirm.Name = "Confirm"
	if opts.cancelText then
		Ui.button(
			buttons,
			opts.cancelText,
			UDim2.fromOffset(150, 48),
			UDim2.new(1, -340, 0, 2),
			true,
			close,
			"secondary"
		)
	end
	pcall(function()
		GuiService.SelectedObject = confirm
	end)
	return close
end

-- Closes the newest dialog, if any. Returns true when one closed.
function Ui.closeTop(): boolean
	local close = openDialogs[#openDialogs]
	if close then
		close()
		return true
	end
	return false
end

---------------------------------------------------------------- words

function Ui.costText(cost: { [string]: number }): string
	local parts = {}
	for _, id in Config.MineralOrder do
		if cost[id] then
			table.insert(parts, `{Ui.short(cost[id])} {Config.Minerals[id].displayName}`)
		end
	end
	return table.concat(parts, ", ")
end

local STAT_NAMES = {
	health = "health",
	damage = "damage",
	attackSpeed = "attack speed",
	mining = "mining",
	minerals = "minerals",
	speed = "speed",
	luck = "luck",
	spellPower = "spell power",
	spellHaste = "spell cooldowns",
	regen = "regen",
	xp = "XP",
}

function Ui.bonusText(bonus: { [string]: number }): string
	local parts = {}
	for stat, amount in bonus do
		table.insert(parts, `+{amount}% {STAT_NAMES[stat] or stat}`)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

function Ui.rewardText(reward: any): string
	local parts = {}
	if reward.minerals then
		table.insert(parts, Ui.costText(reward.minerals))
	end
	if reward.xp then
		table.insert(parts, `{Ui.short(reward.xp)} XP`)
	end
	return table.concat(parts, ", ")
end

-- The icon for a reward: its first mineral, or XP.
function Ui.rewardIcon(reward: any): string
	if reward.minerals then
		for _, id in Config.MineralOrder do
			if reward.minerals[id] then
				return id
			end
		end
	end
	return "xp"
end

-- Event modifiers like { minerals = 2 } as "2x minerals".
function Ui.modifierText(modifiers: { [string]: number }?): string
	local parts = {}
	for stat, mult in modifiers or ({} :: any) do
		table.insert(parts, `{mult}x {if stat == "xp" then "XP" else stat}`)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

function Ui.duration(seconds: number): string
	seconds = math.max(math.floor(seconds), 0)
	if seconds >= 86400 then
		return string.format("%dd %02dh", seconds // 86400, (seconds % 86400) // 3600)
	end
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Time left in plain words: "3 days left", "5 hours left", "12 minutes left".
function Ui.timeLeft(seconds: number): string
	seconds = math.max(math.floor(seconds), 0)
	local function plural(n: number, word: string): string
		return `{n} {word}{if n == 1 then "" else "s"} left`
	end
	if seconds >= 2 * 86400 then
		return plural(seconds // 86400, "day")
	elseif seconds >= 2 * 3600 then
		return plural(seconds // 3600, "hour")
	elseif seconds >= 120 then
		return plural(seconds // 60, "minute")
	end
	return plural(seconds, "second")
end

return Ui
