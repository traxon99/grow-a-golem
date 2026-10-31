--!strict
-- The first-time tutorial. Owns each player's step (saved in data.tutorial,
-- which reaches the client in the normal snapshot) and advances it from real
-- game events, so it never changes how the game itself plays. Steps are
-- listed in Config.Tutorial.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local ActionService = require(script.Parent.ActionService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)

local POLL_INTERVAL = 0.25

local TutorialService = {}

local steered: { [Player]: number } = {} -- seconds of steering in the first step

local function logStep(player: Player, step: number, name: string)
	-- Shows up in the Creator Dashboard's onboarding funnel. Steps after the
	-- tutorial (first boss) are logged by AnalyticsService.
	AnalyticsService.onboardingStep(player, step, name)
end

local function currentStep(player: Player): (any?, number)
	local data = DataService.get(player)
	if not data or data.tutorial.done or data.tutorial.step < 1 then
		return nil, 0
	end
	return Config.Tutorial.steps[data.tutorial.step], data.tutorial.step
end

-- Runs when a step begins, to make sure it can always be finished.
local function enterStep(player: Player, index: number)
	local step = Config.Tutorial.steps[index]
	local data = DataService.get(player)
	if not step or not data then
		return
	end
	if step.topUpStone then
		-- Guarantee the first part: top stone up to the cheapest stone part.
		local cheapest = math.huge
		for _, slot in Config.SlotOrder do
			cheapest = math.min(cheapest, Stats.partCost(slot, "stone").stone)
		end
		local missing = cheapest - (data.minerals.stone or 0)
		if missing > 0 then
			EconomyService.grantFlat(player, { minerals = { stone = missing } }, "tutorial")
		end
	end
end

local function finish(player: Player, skipped: boolean)
	DataService.update(player, function(data)
		data.tutorial.done = true
	end)
	steered[player] = nil
	if not skipped then
		logStep(player, #Config.Tutorial.steps + 1, "done")
		Remotes.Notify:FireClient(player, "tutorialDone")
	end
end

-- Completes the given step if it's the one the player is on.
local function complete(player: Player, id: string)
	local step, index = currentStep(player)
	if not step or step.id ~= id then
		return
	end
	if step.reward then
		EconomyService.grantFlat(player, step.reward, "tutorial")
	end
	Remotes.Notify:FireClient(player, "tutorialStep", index)
	if index >= #Config.Tutorial.steps then
		finish(player, false)
		return
	end
	DataService.update(player, function(data)
		data.tutorial.step = index + 1
	end)
	logStep(player, index + 1, Config.Tutorial.steps[index + 1].id)
	enterStep(player, index + 1)
	TutorialService.check(player)
end

-- Steps that finish on a state rather than an event (reaching level 2).
function TutorialService.check(player: Player)
	local step = currentStep(player)
	local data = DataService.get(player)
	if step and data and step.id == "level" and Stats.levelForXp(data.golem.xp) >= 2 then
		complete(player, "level")
	end
end

local function onLoaded(player: Player)
	local data = DataService.get(player)
	if not data or data.tutorial.done then
		return
	end
	if data.tutorial.step == 0 then
		-- Saves from before the tutorial existed: those players already know the game.
		if data.golem.xp > 0 or next(data.golem.parts) ~= nil or data.awakening.count > 0 then
			DataService.update(player, function(d)
				d.tutorial.done = true
			end)
			return
		end
		DataService.update(player, function(d)
			d.tutorial.step = 1
		end)
		logStep(player, 1, Config.Tutorial.steps[1].id)
	end
	enterStep(player, data.tutorial.step)
	TutorialService.check(player)
end

function TutorialService.start()
	DataService.ProfileLoaded:Connect(onLoaded)
	DataService.Changed:Connect(TutorialService.check)

	Events.connect("nodeMined", function(player)
		complete(player, "mine")
	end)
	Events.connect("partCrafted", function(player)
		complete(player, "forge")
	end)
	Events.connect("spellCast", function(player, spellId)
		local step = currentStep(player)
		if step and step.spell == spellId then
			complete(player, step.id)
		end
	end)

	-- For returning players on a new device, or anyone who'd rather explore.
	ActionService.register("skipTutorial", function(player)
		local step = currentStep(player)
		if not step then
			return false, nil
		end
		finish(player, true)
		return true, "Tutorial skipped. Follow your Goal card!"
	end)

	task.spawn(function()
		while true do
			task.wait(POLL_INTERVAL)
			for player, golem in GolemService.all() do
				local step = currentStep(player)
				if step and step.id == "steer" and GolemService.getSteer(golem).Magnitude > 0 then
					steered[player] = (steered[player] or 0) + POLL_INTERVAL
					if steered[player] >= Config.Tutorial.steerSeconds then
						complete(player, "steer")
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		steered[player] = nil
	end)
end

return TutorialService
