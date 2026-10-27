--!strict
-- Small helpers for building the UI in code: labels, buttons, list rows and
-- themed material surfaces (wood, stone, metal, studs, crystal). Everything
-- here is easy to swap for Studio-designed GUIs later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local Ui = {}

Ui.Colors = {
	panel = Color3.fromRGB(30, 34, 40),
	row = Color3.fromRGB(44, 50, 58),
	text = Color3.fromRGB(240, 240, 240),
	quiet = Color3.fromRGB(186, 192, 202),
	rune = Color3.fromRGB(90, 200, 255),
	good = Color3.fromRGB(110, 200, 90),
	warn = Color3.fromRGB(240, 190, 70),
	button = Color3.fromRGB(64, 120, 200),
	disabled = Color3.fromRGB(70, 74, 80),
}

function Ui.corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
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
}

Ui.Materials = {
	-- Planks: menus, the tutorial callout, the event notice board.
	wood = {
		color = Color3.fromRGB(96, 64, 42),
		edge = Color3.fromRGB(46, 30, 20),
		edgeWidth = 3,
		rotation = 90,
		grain = { 1, 0.84, 0.97, 0.82, 0.94, 1 },
		tile = 96,
		imageTransparency = 0.45,
	},
	-- Cut stone: the HUD stats slab, runestone spell buttons, boss bar, inputs.
	stone = {
		color = Color3.fromRGB(66, 70, 78),
		edge = Color3.fromRGB(34, 36, 42),
		edgeWidth = 2,
		rotation = 30,
		grain = { 1, 0.88, 0.96, 0.84, 0.94, 1 },
		tile = 80,
		imageTransparency = 0.45,
	},
	-- Riveted iron: bar frames and the close button.
	metal = {
		color = Color3.fromRGB(92, 102, 116),
		edge = Color3.fromRGB(34, 38, 46),
		edgeWidth = 2,
		rotation = 90,
		grain = { 1, 0.78, 0.88, 0.92, 0.8, 0.65 },
		tile = 64,
		imageTransparency = 0.55,
	},
	-- Building-brick plate: menu tabs and list rows.
	studs = {
		color = Color3.fromRGB(58, 66, 80),
		edge = Color3.fromRGB(30, 34, 42),
		edgeWidth = 2,
		rotation = 90,
		grain = { 1, 0.94, 0.9, 0.86 },
		tile = 48,
		imageTransparency = 0.4,
	},
	-- Rune crystal: action buttons and the artifact reveal card.
	crystal = {
		color = Color3.fromRGB(48, 98, 178),
		edge = Color3.fromRGB(150, 215, 255),
		edgeWidth = 2,
		rotation = 45,
		grain = { 1, 0.8, 0.96, 0.78, 0.94, 0.86 },
		tile = 96,
		imageTransparency = 0.5,
	},
} :: { [string]: Material }

-- A gradient on a text object also tints its text, so text surfaces get a
-- shallower grain and no image layer.
local TEXT_GRAIN_FLOOR = 0.82
local SURFACE_PARTS = { "Grain", "Edge", "Texture", "Detail" }

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
-- rivets, brick studs, a top highlight. They sit under the surface's own
-- children (ZIndex 0), and only on frames built once, never on list rows.
local function addDetails(target: GuiObject, material: string, m: Material)
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
				m.color:Lerp(Color3.new(1, 1, 1), 0.18),
				0,
				false
			)
			stud.AnchorPoint = Vector2.new(0.5, 1)
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 2)
			c.Parent = stud
		end
	end
	-- A thin light line along the top reads as a bevel on every material.
	detail(target, UDim2.new(1, -12, 0, 1), UDim2.fromOffset(6, 2), Color3.new(1, 1, 1), 0.82, false)
end

-- Dresses a frame or button in a material. Safe to call again to change it.
-- `tint` swaps the base color (a disabled button, a gold card) and keeps the
-- grain. `details` adds the code-drawn shapes above. Returns the edge stroke
-- so callers can recolor it (rune glow, gold rim).
function Ui.surface(target: GuiObject, material: string, options: { tint: Color3?, details: boolean? }?): UIStroke
	local m = Ui.Materials[material]
	local opts: { tint: Color3?, details: boolean? } = options or {}
	for _, name in SURFACE_PARTS do
		for _, child in target:GetChildren() do
			if child.Name == name then
				child:Destroy()
			end
		end
	end
	for _, child in target:GetChildren() do
		if child:IsA("UIStroke") or child:IsA("UIGradient") then
			child:Destroy()
		end
	end

	local base = opts.tint or m.color
	target.BackgroundColor3 = base
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

	local imageId = Config.UiTextures[material]
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

	if opts.details then
		addDetails(target, material, m)
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

function Ui.label(parent: Instance, text: string, size: UDim2, position: UDim2, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.Text = text
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.TextColor3 = Ui.Colors.text
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	-- A soft dark outline keeps text readable over textured surfaces.
	l.TextStrokeColor3 = Color3.fromRGB(16, 12, 10)
	l.TextStrokeTransparency = 0.55
	for key, value in props or ({} :: any) do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

function Ui.button(
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2,
	enabled: boolean,
	onClick: () -> ()
): TextButton
	local b = Instance.new("TextButton")
	b.Text = text
	b.Size = size
	b.Position = position
	b.TextColor3 = if enabled then Ui.Colors.text else Ui.Colors.quiet
	b.TextStrokeColor3 = Color3.fromRGB(16, 12, 10)
	b.TextStrokeTransparency = 0.45
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.AutoButtonColor = enabled
	b.Parent = parent
	Ui.corner(b, 8)
	-- Live buttons are rune crystal; disabled ones are dull stone.
	if enabled then
		Ui.surface(b, "crystal")
	else
		Ui.surface(b, "stone", { tint = Ui.Colors.disabled })
	end
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = b
	if enabled then
		b.Activated:Connect(function()
			Sfx.play("click")
			onClick()
		end)
	end
	return b
end

-- A list row: title, a quieter second line, and an optional button on the right.
function Ui.row(
	parent: Instance,
	order: number,
	title: string,
	subtitle: string?,
	buttonText: string?,
	enabled: boolean?,
	onClick: (() -> ())?
): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, if subtitle then 58 else 40)
	frame.LayoutOrder = order
	frame.Parent = parent
	Ui.corner(frame, 8)
	Ui.surface(frame, "studs")

	local textWidth = if buttonText then UDim2.new(1, -140, 0, 22) else UDim2.new(1, -20, 0, 22)
	Ui.label(frame, title, textWidth, UDim2.fromOffset(10, if subtitle then 6 else 9))
	if subtitle then
		local sub =
			Ui.label(frame, subtitle, UDim2.new(textWidth.X.Scale, textWidth.X.Offset, 0, 18), UDim2.fromOffset(10, 32))
		sub.Font = Enum.Font.Gotham
		sub.TextColor3 = Ui.Colors.quiet
	end
	if buttonText then
		local b = Ui.button(
			frame,
			buttonText,
			UDim2.new(0, 120, 1, -12),
			UDim2.new(1, -126, 0, 6),
			enabled == true,
			onClick or function() end
		)
		b.Name = "Action"
	end
	return frame
end

-- A section heading inside a list.
function Ui.heading(parent: Instance, order: number, text: string): TextLabel
	local l = Ui.label(parent, text, UDim2.new(1, -8, 0, 26), UDim2.new(), { TextColor3 = Ui.Colors.rune })
	l.LayoutOrder = order
	return l
end

function Ui.costText(cost: { [string]: number }): string
	local parts = {}
	for _, id in Config.MineralOrder do
		if cost[id] then
			table.insert(parts, `{cost[id]} {Config.Minerals[id].displayName}`)
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
		table.insert(parts, `{reward.xp} XP`)
	end
	return table.concat(parts, ", ")
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

return Ui
