--!strict
-- Shared #83 sprite renderer for the menu kit (#82) and menu restyles.
-- Always keep a word label beside interactive icons. No uploaded ID means text.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Icons = {}

function Icons.create(parent: Instance, key: string, size: number, position: UDim2, tint: Color3?): GuiObject
	local entry = Config.UiIcons.entries[key]
	local official = key == "robux"
	local id = if official then Config.UiIcons.robux else if tint then Config.UiIcons.mono else Config.UiIcons.color
	local icon: GuiObject
	if type(id) == "number" and id > 0 and (entry or official) then
		local image = Instance.new("ImageLabel")
		image.Image = `rbxassetid://{id}`
		image.ScaleType = Enum.ScaleType.Fit
		if not official then
			image.ImageRectOffset = Vector2.new(entry.x, entry.y)
			image.ImageRectSize = Vector2.new(Config.UiIcons.cellSize, Config.UiIcons.cellSize)
			image.ImageColor3 = tint or Color3.new(1, 1, 1)
		end
		icon = image
	else
		local label = Instance.new("TextLabel")
		label.Text = if official then "R$" else if entry then entry.fallback else "?"
		label.Font = Enum.Font.GothamBold
		label.TextSize = math.max(12, math.floor(size * 0.45))
		label.TextColor3 = tint or Color3.fromRGB(244, 246, 255)
		label.TextStrokeColor3 = Color3.fromRGB(17, 24, 39)
		label.TextStrokeTransparency = 0
		icon = label
	end
	icon.Name = `Icon_{key}`
	icon.Size = UDim2.fromOffset(size, size)
	icon.Position = position
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Active = false
	icon.Selectable = false
	if parent:IsA("GuiObject") then
		icon.ZIndex = parent.ZIndex + 1
	end
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = icon
	icon.Parent = parent
	return icon
end

return Icons
