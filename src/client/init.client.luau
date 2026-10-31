--!strict
-- Client entry point.

local Animator = require(script:WaitForChild("Animator"))
local Controls = require(script:WaitForChild("Controls"))
local Fx = require(script:WaitForChild("Fx"))
local Hud = require(script:WaitForChild("Hud"))
local Menus = require(script:WaitForChild("Menus"))
local Moments = require(script:WaitForChild("Moments"))
local Riding = require(script:WaitForChild("Riding"))
local Sfx = require(script:WaitForChild("Sfx"))
local State = require(script:WaitForChild("State"))
local Tutorial = require(script:WaitForChild("Tutorial"))
local WorldBeatHud = require(script:WaitForChild("WorldBeatHud"))
local QuakeTimingHud = require(script:WaitForChild("QuakeTimingHud"))
local RuneCastingHud = require(script:WaitForChild("RuneCastingHud"))
local ForgeTimingHud = require(script:WaitForChild("ForgeTimingHud"))
local GauntletHud = require(script:WaitForChild("GauntletHud"))

-- ScreenGuis survive character respawns and can also outlive a LocalScript
-- replaced by Rojo during a Studio playtest. Clear this client's old copies
-- before the current modules rebuild their UI, so an obsolete full-height HUD
-- panel can't remain over the live layout.
local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
for _, name in {
	"GolemHud",
	"WorldBeatHud",
	"QuakeTimingHud",
	"RuneCastingHud",
	"ForgeTimingHud",
	"GauntletHud",
	"GolemMenus",
	"GolemDialogs",
	"GolemMoments",
	"GolemTutorial",
} do
	local old = playerGui:FindFirstChild(name)
	if old and old:IsA("ScreenGui") then
		old:Destroy()
	end
end

Hud.start() -- sets up the toast handler State uses
WorldBeatHud.start() -- separate gameplay banner; no overlap with #175's HUD restyle
QuakeTimingHud.start() -- separate timing cue; no overlap with the claimed HUD restyle
RuneCastingHud.start() -- separate optional rune activity; touch, PC and gamepad
ForgeTimingHud.start() -- after manual forging, a fixed-refund optional strike
GauntletHud.start() -- independent course timer; avoids the claimed HUD restyle
Menus.start()
Moments.start()
Tutorial.start()
State.start()
Controls.start()
Riding.start()
Animator.start()
Sfx.start()
Fx.start()
