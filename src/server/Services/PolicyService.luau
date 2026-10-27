--!strict
-- Roblox policy checks per player, looked up once per session on the server.
-- Paid random items (2x Luck changes random artifact odds, so it counts) are
-- hidden and blocked where Roblox says they're restricted. Everything fails
-- closed: until the lookup succeeds, or if it never does, they stay off.

local Players = game:GetService("Players")
local RobloxPolicy = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local DataService = require(script.Parent.DataService)

type Policy = { paidRandomItems: boolean, paidItemTrading: boolean }

local PolicyService = {}

local policies: { [Player]: Policy } = {}

-- True once the lookup has finished (or given up) for this session.
function PolicyService.isReady(player: Player): boolean
	return policies[player] ~= nil
end

-- Whether this player may buy or use paid random items like 2x Luck.
function PolicyService.paidRandomAllowed(player: Player): boolean
	local policy = policies[player]
	return policy ~= nil and policy.paidRandomItems
end

-- Whether this player may trade items or outcomes bought with Robux.
function PolicyService.paidTradingAllowed(player: Player): boolean
	local policy = policies[player]
	return policy ~= nil and policy.paidItemTrading
end

local function snapshot(player: Player): any
	local policy = policies[player]
	return {
		ready = policy ~= nil,
		paidRandomItems = policy ~= nil and policy.paidRandomItems,
	}
end

local function check(player: Player)
	local info: any = nil
	for attempt = 1, Config.PolicyCheck.attempts do
		local ok, result = pcall(function()
			return RobloxPolicy:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(result) == "table" then
			info = result
			break
		end
		warn(`[PolicyService] lookup {attempt} failed for {player.UserId}: {result}`)
		if attempt < Config.PolicyCheck.attempts then
			task.wait(Config.PolicyCheck.retrySeconds)
		end
		if not player.Parent then
			return
		end
	end
	if not player.Parent then
		return
	end
	-- Only an explicit "not restricted" / "allowed" turns a feature on.
	policies[player] = {
		paidRandomItems = info ~= nil and info.ArePaidRandomItemsRestricted == false,
		paidItemTrading = info ~= nil and info.IsPaidItemTradingAllowed == true,
	}
	DataService.markChanged(player)
end

function PolicyService.start()
	DataService.addProvider("policy", snapshot)
	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(check, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		policies[player] = nil
	end)
end

return PolicyService
