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
local Stats = require(Shared:WaitForChild("Stats"))

local Sfx = require(script.Parent:WaitForChild("Sfx"))
local State = require(script.Parent:WaitForChild("State"))
local Ui = require(script.Parent:WaitForChild("Ui"))

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

-- The hearth prompt on this player's own sanctuary plot (#218). It shows
-- the full cost up front; visitors' plots get no prompt. The server checks
-- ownership, distance and funds again.
local function attachHearth(model: Instance)
	local hearth = model:WaitForChild("Hearth", 10)
	if not hearth or not hearth:IsA("BasePart") then
		return
	end
	local config = Config.Kingdom.sanctuary.hearth
	local player = game:GetService("Players").LocalPlayer
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HearthPrompt"
	prompt.ObjectText = config.name
	prompt.ActionText = `Restore ({Stats.costText(config.cost)})`
	prompt.MaxActivationDistance = config.reachRadius + 16
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.5
	prompt.Parent = hearth
	local function refresh()
		prompt.Enabled = model:GetAttribute("OwnerId") == player.UserId and model:GetAttribute("Restored") ~= true
	end
	model:GetAttributeChangedSignal("OwnerId"):Connect(refresh)
	model:GetAttributeChangedSignal("Restored"):Connect(refresh)
	prompt.Triggered:Connect(function()
		State.request("restoreHearth")
	end)
	refresh()
end

-- The breakout moment: a short banner naming where to go next. The pop is
-- skipped under Reduced Motion (Ui.tween snaps).
local function reveal(title: string, text: string)
	local player = game:GetService("Players").LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "KingdomReveal"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")
	local banner = Ui.label(gui, title, UDim2.new(0.9, 0, 0, 64), UDim2.fromScale(0.5, 0.2), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Ui.Colors.gold,
		Title = true,
		TextScaled = true,
		TextWrapped = false,
	})
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 52
	size.Parent = banner
	local width = Instance.new("UISizeConstraint")
	width.MaxSize = Vector2.new(680, 64)
	width.Parent = banner
	Ui.outline(banner, 4)
	local sub = Ui.label(gui, text, UDim2.new(0.9, 0, 0, 40), UDim2.new(0.5, 0, 0.2, 38), {
		AnchorPoint = Vector2.new(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Title = true,
		TextSize = 26,
		AutomaticSize = Enum.AutomaticSize.Y, -- wraps to two lines on a phone
	})
	Ui.outline(sub, 3)
	local pop = Instance.new("UIScale")
	pop.Scale = if Ui.reducedMotion() then 1 else 0.4
	pop.Parent = banner
	Ui.tween(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	Sfx.moment("levelUp")
	task.delay(4, function()
		gui:Destroy()
	end)
end

function KingdomPrompts.start()
	if not Config.Kingdom.enabled then
		return
	end
	Remotes.Notify.OnClientEvent:Connect(function(kind: string, id: any)
		local obstacle = if kind == "obstacleOpened" and type(id) == "string" then Config.Kingdom.obstacles[id] else nil
		if obstacle and obstacle.revealTitle then
			reveal(obstacle.revealTitle, obstacle.revealText or "")
		elseif obstacle then
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
	task.spawn(function()
		local plots = workspace:WaitForChild("Kingdom"):WaitForChild("Plots")
		for _, model in plots:GetChildren() do
			task.spawn(attachHearth, model)
		end
		plots.ChildAdded:Connect(attachHearth)
	end)
end

return KingdomPrompts
