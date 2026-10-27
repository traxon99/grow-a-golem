--!strict
-- Small helpers for building the placeholder UI in code. Everything here is
-- easy to swap for Studio-designed GUIs later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local Ui = {}

Ui.Colors = {
	panel = Color3.fromRGB(30, 34, 40),
	row = Color3.fromRGB(44, 50, 58),
	text = Color3.fromRGB(240, 240, 240),
	quiet = Color3.fromRGB(170, 176, 186),
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
	for key, value in props or {} do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

function Ui.button(parent: Instance, text: string, size: UDim2, position: UDim2, enabled: boolean, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Text = text
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = if enabled then Ui.Colors.button else Ui.Colors.disabled
	b.TextColor3 = if enabled then Ui.Colors.text else Ui.Colors.quiet
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.AutoButtonColor = enabled
	b.Parent = parent
	Ui.corner(b, 8)
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
function Ui.row(parent: Instance, order: number, title: string, subtitle: string?, buttonText: string?, enabled: boolean?, onClick: (() -> ())?): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, if subtitle then 58 else 40)
	frame.BackgroundColor3 = Ui.Colors.row
	frame.LayoutOrder = order
	frame.Parent = parent
	Ui.corner(frame, 8)

	local textWidth = if buttonText then UDim2.new(1, -140, 0, 22) else UDim2.new(1, -20, 0, 22)
	Ui.label(frame, title, textWidth, UDim2.fromOffset(10, if subtitle then 6 else 9))
	if subtitle then
		local sub = Ui.label(frame, subtitle, UDim2.new(textWidth.X.Scale, textWidth.X.Offset, 0, 18), UDim2.fromOffset(10, 32))
		sub.Font = Enum.Font.Gotham
		sub.TextColor3 = Ui.Colors.quiet
	end
	if buttonText then
		local b = Ui.button(frame, buttonText, UDim2.new(0, 120, 1, -12), UDim2.new(1, -126, 0, 6), enabled == true, onClick or function() end)
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
	for stat, mult in modifiers or {} do
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
