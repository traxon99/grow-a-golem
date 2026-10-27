--!strict
-- Client entry point.

local Controls = require(script:WaitForChild("Controls"))
local Hud = require(script:WaitForChild("Hud"))
local Menus = require(script:WaitForChild("Menus"))
local State = require(script:WaitForChild("State"))

Hud.start() -- sets up the toast handler State uses
Menus.start()
State.start()
Controls.start()
