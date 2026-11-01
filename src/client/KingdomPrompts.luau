--!strict
-- The prompt on each kingdom obstacle (#216). It shows this player's own
-- state from the shared KingdomRules resolver: the tool's verb when the
-- golem is ready, the first missing requirement when it isn't, and nothing
-- once they opened it (the obstacle is hidden for them alone). Pressing it
-- only asks the server; the server re-checks everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local KingdomRules = require(Shared:WaitForChild("KingdomRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local State = require(script.Parent:WaitForChild("State"))

local KingdomPrompts = {}

local function attach(part: BasePart, id: string)
	local obstacle = Config.Kingdom.obstacles[id]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ObstaclePrompt"
	prompt.ObjectText = obstacle.name
	prompt.MaxActivationDistance = obstacle.approachRadius + obstacle.promptSlack
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = part

	local status: KingdomRules.Status = "locked"
	local missing: string? = nil
	local function refresh()
		local data = State.snapshot and State.snapshot.data
		if not data then
			return
		end
		status, missing = KingdomRules.obstacleStatus(data, id)
		prompt.Enabled = status ~= "done"
		prompt.ActionText = if status == "ready" then obstacle.verb else (missing or "Locked")
		part.LocalTransparencyModifier = if status == "done" then 1 else 0
	end
	prompt.Triggered:Connect(function()
		if status == "ready" then
			State.request("useObstacle", id)
		elseif missing then
			State.toast(missing)
		end
	end)
	State.Changed:Connect(refresh)
	refresh()
end

function KingdomPrompts.start()
	if not Config.Kingdom.enabled then
		return
	end
	Remotes.Notify.OnClientEvent:Connect(function(kind: string, id: any)
		local obstacle = if kind == "obstacleOpened" and type(id) == "string" then Config.Kingdom.obstacles[id] else nil
		if obstacle then
			State.toast(`The {obstacle.name} is open!`)
		end
	end)
	task.spawn(function()
		local kingdom = workspace:WaitForChild("Kingdom")
		local folder = kingdom:WaitForChild("Obstacles")
		for _, id in Config.Kingdom.obstacleOrder do
			local part = folder:WaitForChild(id)
			if part:IsA("BasePart") then
				attach(part, id)
			end
		end
	end)
end

return KingdomPrompts
