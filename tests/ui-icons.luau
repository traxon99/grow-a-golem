-- check_ui_icons.py injects the real Config registry and Icons module above.
local created = {}
local Instance = {
	new = function(class)
		local object = { ClassName = class }
		table.insert(created, object)
		return object
	end,
}
local function pair(x, y)
	return { X = x, Y = y }
end
local Color3 = {
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}
Color3.fromRGB = function(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
local Enum = { ScaleType = { Fit = "Fit" }, Font = { GothamBold = "GothamBold" } }
local Icons = loadIcons(Instance, Enum, Color3, { new = pair }, { fromOffset = pair })
local parent = {
	ZIndex = 10,
	IsA = function(_, class)
		return class == "GuiObject"
	end,
}
local position = pair(8, 8)
-- The fallback checks run with no uploaded IDs, whatever production Config holds.
Config.UiIcons.color, Config.UiIcons.mono, Config.UiIcons.robux = 0, 0, 0
local count = 0
for key, entry in Config.UiIcons.entries do
	count += 1
	local fallback = Icons.create(parent, key, 32, position)
	assert(fallback.ClassName == "TextLabel" and fallback.Text == entry.fallback)
	assert(fallback.Parent == parent and fallback.Position == position)
	assert(fallback.Size.X == 32 and fallback.Size.Y == 32)
	assert(fallback.ZIndex == 11 and fallback.Active == false and fallback.Selectable == false)
	local aspect = created[#created]
	assert(aspect.ClassName == "UIAspectRatioConstraint" and aspect.Parent == fallback and aspect.AspectRatio == 1)
end
assert(count == 37)
Config.UiIcons.color = 123 -- Test fixture IDs only, never production assets.
Config.UiIcons.mono = 456
local tint = Color3.fromRGB(90, 200, 255)
for key, entry in Config.UiIcons.entries do
	local image = Icons.create(parent, key, 32, position)
	assert(image.ClassName == "ImageLabel" and image.Image == "rbxassetid://123")
	assert(image.ImageRectOffset.X == entry.x and image.ImageRectOffset.Y == entry.y)
	assert(image.ImageRectSize.X == 128 and image.ImageRectSize.Y == 128)
	assert(image.ImageColor3.R == 1 and image.ScaleType == "Fit")
	local mono = Icons.create(parent, key, 32, position, tint)
	assert(mono.Image == "rbxassetid://456" and mono.ImageColor3 == tint)
end
Config.UiIcons.mono = 0
assert(Icons.create(parent, "forge", 32, position, tint).ClassName == "TextLabel")
assert(Icons.create(parent, "unknown", 32, position).Text == "?")
assert(Icons.create(parent, "robux", 32, position).Text == "R$")
Config.UiIcons.robux = 789
local official = Icons.create(parent, "robux", 32, position, tint)
assert(official.Image == "rbxassetid://789" and official.ImageRectOffset == nil and official.ImageColor3 == nil)
for _, invalid in { -1, "123", false } do
	Config.UiIcons.color = invalid
	assert(Icons.create(parent, "forge", 32, position).ClassName == "TextLabel")
end
print(
	"PASS: all 37 icons: zero-ID fallback, sprite crops, tint selection, official Robux, invalid IDs, layering and aspect"
)
