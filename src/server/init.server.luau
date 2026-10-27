--!strict
-- Server entry point. Starts every service in dependency order.

local Services = script:WaitForChild("Services")

local WorldService = require(Services:WaitForChild("WorldService"))
local DataService = require(Services:WaitForChild("DataService"))
local GolemService = require(Services:WaitForChild("GolemService"))
local MiningService = require(Services:WaitForChild("MiningService"))
local EnemyService = require(Services:WaitForChild("EnemyService"))
local CombatService = require(Services:WaitForChild("CombatService"))

WorldService.start()
GolemService.start() -- listens for loaded profiles, so it starts before DataService
DataService.start()
MiningService.start()
EnemyService.start()
CombatService.start()
