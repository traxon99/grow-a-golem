--!strict
-- Redeemable codes from Config.Codes. Each code works once per player and
-- can expire. Attempts are rate-limited so codes can't be guessed by spamming.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local CodeService = {}

type Attempts = { last: number, failures: number, lockedUntil: number }

local attempts: { [Player]: Attempts } = {}

-- What the player typed, trimmed and upper-cased. Nil if it can't be a code.
local function normalize(input: any): string?
	if type(input) ~= "string" or #input > 64 then
		return nil
	end
	local code = string.upper((string.gsub(input, "%s", "")))
	if code == "" or #code > Config.CodeLimits.maxLength or string.find(code, "[^%w]") then
		return nil
	end
	return code
end

local function redeem(player: Player, input: any): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Not ready"
	end
	local now = os.clock()
	local state = attempts[player] or { last = 0, failures = 0, lockedUntil = 0 }
	attempts[player] = state
	if now < state.lockedUntil then
		return false, `Too many tries. Wait {math.ceil(state.lockedUntil - now)}s and check the spelling.`
	end
	if now - state.last < Config.CodeLimits.cooldown then
		return false, "One moment..."
	end
	state.last = now

	local function fail(message: string): (boolean, string?)
		state.failures += 1
		if state.failures >= Config.CodeLimits.maxFailures then
			state.failures = 0
			state.lockedUntil = now + Config.CodeLimits.lockoutSeconds
		end
		return false, message
	end

	local code = normalize(input)
	local entry = code and Config.Codes[code]
	if not code or not entry then
		return fail("That code doesn't exist. Check the spelling!")
	end
	if entry.expires and os.time() >= entry.expires then
		return fail("That code has expired. Watch for new ones with each update!")
	end
	if data.codesRedeemed[code] then
		return false, "You already used that code."
	end

	state.failures = 0
	DataService.update(player, function(d)
		d.codesRedeemed[code] = os.time()
	end)
	EconomyService.grantFlat(player, entry.reward)
	task.spawn(DataService.saveNow, player)
	return true, `Code redeemed! You got {CodeService.rewardText(entry.reward)}.`
end

function CodeService.rewardText(reward: any): string
	local parts = {}
	for _, id in Config.MineralOrder do
		local amount = reward.minerals and reward.minerals[id]
		if amount then
			table.insert(parts, `{amount} {Config.Minerals[id].displayName}`)
		end
	end
	if reward.xp then
		table.insert(parts, `{reward.xp} XP`)
	end
	return table.concat(parts, ", ")
end

function CodeService.start()
	ActionService.register("redeemCode", redeem)
	Players.PlayerRemoving:Connect(function(player)
		attempts[player] = nil
	end)
end

return CodeService
