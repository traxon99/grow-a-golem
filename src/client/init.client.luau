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

Hud.start() -- sets up the toast handler State uses
Menus.start()
Moments.start()
Tutorial.start()
State.start()
Controls.start()
Riding.start()
Animator.start()
Sfx.start()
Fx.start()
