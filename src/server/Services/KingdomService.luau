--!strict
-- Kingdom obstacles (#216): the cracked wall now, and later the fallen gate,
-- hidden road, storm machinery and flooded city through the same contract.
-- The client only asks "use obstacle <id>"; the server checks the id, that
-- the player's own golem is active, in the obstacle's region and within
-- reach, that they have the tool and every first-time need (KingdomRules),
-- and a per-player cooldown. The golem then plays one untimed action; when
-- it finishes, everything is checked again and the obstacle is recorded as
-- open for that player once. Nothing is charged or paid, so an interrupted
-- or repeated request has nothing to lose or double.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local KingdomRules = require(Shared:WaitForChild("KingdomRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)

local KingdomService = {}

type Pending = { id: string, token: number }

local pending: { [Player]: Pending } = {}
local nextAllowed: { [Player]: number } = {}
local tokens = 0

local FLAT = Vector3.new(1, 0, 1)

-- Whether the golem can act on the obstacle right now. Returns the golem.
local function reachable(player: Player, obstacle: any): (any?, string?)
	local golem = GolemService.get(player)
	if not golem or not GolemService.isActive(golem) then
		return nil, "Wait for your golem to rebuild."
	end
	if golem.zoneId ~= obstacle.zoneId then
		return nil, "Your golem needs to be closer."
	end
	local reach = obstacle.approachRadius + Config.Golem.dismountOffset * golem.stats.scale
	if ((golem.root.Position - obstacle.position) * FLAT).Magnitude > reach then
		return nil, "Your golem needs to be closer."
	end
	return golem, nil
end

-- The golem's action finished: check again, then record it once.
function KingdomService.finish(player: Player, token: number): boolean
	local job = pending[player]
	if not job or job.token ~= token then
		return false
	end
	pending[player] = nil
	local obstacle = Config.Kingdom.obstacles[job.id]
	local data = DataService.get(player)
	local golem = reachable(player, obstacle)
	-- Steering, a knock-out or walking away clears the hold (CombatService).
	local held = golem ~= nil and golem.busyUntil > 0
	if golem then
		golem.busyUntil = 0
	end
	if not data or not held or KingdomRules.obstacleStatus(data, job.id) ~= "ready" then
		-- Nothing was spent, so the player can simply try again.
		Remotes.Notify:FireClient(player, "message", "Your golem was interrupted. Try again.")
		return false
	end
	DataService.update(player, function(d)
		d.campaign.obstacles[job.id] = true
		if obstacle.opensRegion then
			d.campaign.regions[tostring(obstacle.opensRegion)] = true
		end
	end)
	Events.fire("obstacleOpened", player, job.id)
	Remotes.Notify:FireClient(player, "obstacleOpened", job.id)
	return true
end

local function useObstacle(player: Player, id: any): (boolean, string?)
	if not Config.Kingdom.enabled then
		return false, "Not available yet."
	end
	local obstacle = if type(id) == "string" then Config.Kingdom.obstacles[id] else nil
	local data = DataService.get(player)
	if not obstacle or not data then
		return false, "Not ready"
	end
	local status, missing = KingdomRules.obstacleStatus(data, id)
	if status == "done" then
		return false, "Already open."
	elseif status == "locked" then
		return false, missing
	end
	if pending[player] then
		return false, "Your golem is already on it."
	end
	local now = os.clock()
	if now < (nextAllowed[player] or 0) then
		return false, "Give your golem a moment."
	end
	local golem, reason = reachable(player, obstacle)
	if not golem then
		return false, reason
	end
	nextAllowed[player] = now + obstacle.cooldownSeconds
	tokens += 1
	local token = tokens
	pending[player] = { id = id, token = token }
	golem.busyUntil = now + obstacle.actionSeconds + 1 -- a little slack past the finish
	golem.model:SetAttribute("AttackKind", "mine")
	golem.model:SetAttribute("Attack", ((golem.model:GetAttribute("Attack") :: number?) or 0) + 1)
	task.delay(obstacle.actionSeconds, KingdomService.finish, player, token)
	return true, `{obstacle.verb}!`
end

function KingdomService.start()
	ActionService.register("useObstacle", useObstacle)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		nextAllowed[player] = nil
	end)
end

return KingdomService
