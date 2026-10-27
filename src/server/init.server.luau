--!strict
-- Server entry point. Requires every service, then starts them in order.
-- Services that listen for loaded profiles start before DataService.

local Services = script:WaitForChild("Services")

local function load(name: string): any
	return require(Services:WaitForChild(name) :: ModuleScript)
end

local WorldService = load("WorldService")
local ActionService = load("ActionService")
local DataService = load("DataService")
local PassService = load("PassService")
local GolemService = load("GolemService")
local PartyService = load("PartyService")
local MiningService = load("MiningService")
local ArtifactService = load("ArtifactService")
local EnemyService = load("EnemyService")
local ProgressionService = load("ProgressionService")
local RewardService = load("RewardService")
local CodeService = load("CodeService")
local LeaderboardService = load("LeaderboardService")
local CombatService = load("CombatService")

WorldService.start()
ActionService.start()
PassService.start()
GolemService.start()
PartyService.start()
ProgressionService.start()
RewardService.start()
CodeService.start()
DataService.start()
MiningService.start()
ArtifactService.start()
EnemyService.start()
LeaderboardService.start()
CombatService.start()
