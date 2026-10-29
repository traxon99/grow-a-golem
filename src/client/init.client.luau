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

Hud.start() -- sets up the toast handler State uses
WorldBeatHud.start() -- separate gameplay banner; no overlap with #175's HUD restyle
QuakeTimingHud.start() -- separate timing cue; no overlap with the claimed HUD restyle
RuneCastingHud.start() -- separate optional rune activity; touch, PC and gamepad
ForgeTimingHud.start() -- after manual forging, a fixed-refund optional strike
Menus.start()
Moments.start()
Tutorial.start()
State.start()
Controls.start()
Riding.start()
Animator.start()
Sfx.start()
Fx.start()
