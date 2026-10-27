--!strict
-- One RemoteFunction for every menu action ("craft this part", "learn this
-- skill"...). Services register a handler; each handler validates its own
-- arguments and returns (ok, message). Requests are rate-limited per player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local MAX_REQUESTS_PER_SECOND = 8

local ActionService = {}

local handlers: { [string]: (Player, ...any) -> (boolean, string?) } = {}
local windows: { [Player]: { start: number, count: number } } = {}

function ActionService.register(name: string, handler: (Player, ...any) -> (boolean, string?))
	assert(handlers[name] == nil, `Action {name} registered twice`)
	handlers[name] = handler
end

local function onRequest(player: Player, name: any, ...: any): (boolean, string?)
	local now = os.clock()
	local existing = windows[player]
	local window = if existing and now - existing.start < 1 then existing else { start = now, count = 0 }
	windows[player] = window
	window.count += 1
	if window.count > MAX_REQUESTS_PER_SECOND then
		return false, "Slow down a little!"
	end

	if type(name) ~= "string" or handlers[name] == nil then
		return false, "Unknown action"
	end
	local ok, success, message = pcall(handlers[name], player, ...)
	if not ok then
		warn(`[ActionService] {name} failed for {player.Name}: {success}`)
		return false, "Something went wrong"
	end
	return success, message
end

function ActionService.start()
	Remotes.Request.OnServerInvoke = onRequest
	Players.PlayerRemoving:Connect(function(player)
		windows[player] = nil
	end)
end

return ActionService
