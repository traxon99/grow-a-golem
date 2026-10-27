--!strict
-- Client entry point.

local Animator = require(script:WaitForChild("Animator"))
local Controls = require(script:WaitForChild("Controls"))
local Hud = require(script:WaitForChild("Hud"))
local Menus = require(script:WaitForChild("Menus"))
local Moments = require(script:WaitForChild("Moments"))
local State = require(script:WaitForChild("State"))

Hud.start() -- sets up the toast handler State uses
Menus.start()
Moments.start()
State.start()
Controls.start()
Animator.start()
