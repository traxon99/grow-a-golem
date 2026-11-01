--!strict
-- Walking between regions of the connected kingdom (#214). A few times a
-- second, each golem's own server-side position decides its region. Walking
-- into a region the player has access to switches the golem there and fires
-- zoneEntered once; walking into one they can't enter yet returns the golem
-- to the nearest safe point of its current region. Client steering, a
-- dismounted character or another player's golem never grant access.
-- Island travel and arenas are untouched: only kingdom regions are checked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)
local WorldService = require(script.Parent.WorldService)

local CHECK_INTERVAL = 0.25

local RegionService = {}

local lastLockedMessage: { [Player]: number } = {}

-- One golem's boundary check. Returns "entered", "blocked" or nil.
function RegionService.check(player: Player, golem: any, now: number): string?
	if not GolemService.isActive(golem) or not WorldService.isKingdomZone(golem.zoneId) then
		return nil
	end
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local position = golem.root.Position
	local zoneId = WorldService.zoneAt(position)
	if zoneId == nil or zoneId == golem.zoneId or not WorldService.isKingdomZone(zoneId) then
		return nil
	end
	local allowed, reason = true, nil
	if zoneId ~= Config.HubZone then
		allowed, reason = Stats.travelUnlocked(data, zoneId)
	end
	if allowed then
		GolemService.setZone(golem, zoneId)
		DataService.markChanged(player)
		if zoneId ~= Config.HubZone then
			Events.fire("zoneEntered", player, zoneId)
		end
		return "entered"
	end
	local layout = Config.Kingdom.layout
	GolemService.placeAt(golem, WorldService.safePointNear(golem.zoneId, position, layout.pushBackMargin))
	local last = lastLockedMessage[player]
	if not last or now - last >= layout.lockedMessageSeconds then
		lastLockedMessage[player] = now
		Remotes.Notify:FireClient(player, "message", reason or "You can't go there yet.")
	end
	return "blocked"
end

function RegionService.start()
	if not Config.Kingdom.enabled then
		return
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastLockedMessage[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			local now = os.clock()
			for player, golem in GolemService.all() do
				RegionService.check(player, golem, now)
			end
		end
	end)
end

return RegionService
