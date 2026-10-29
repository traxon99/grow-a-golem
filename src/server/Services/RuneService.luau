--!strict
-- Optional three-rune casting challenge. The server picks the pattern,
-- grades each tap, and owns the temporary fixed auto-attack bonus.
-- No purchases, random reward rolls, or progression gates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RuneSequence = require(Shared:WaitForChild("RuneSequence"))

local GolemService = require(script.Parent.GolemService)

local RuneService = {}

type Active = {
	challenge: RuneSequence.Session,
	golem: GolemService.Golem,
}

local rng = Random.new()
local active: { [Player]: Active } = {}
local cooldownUntil: { [Player]: number } = {}
local boostUntil: { [Player]: number } = {}

function RuneService.attackMultiplier(player: Player, now: number): number
	return if now < (boostUntil[player] or 0) then Config.RuneCasting.attackMultiplier else 1
end

local function eligible(golem: GolemService.Golem?): boolean
	return golem ~= nil and golem.mounted and GolemService.isActive(golem)
end

local function onInput(player: Player, action: any, rune: any)
	local now = os.clock()
	local golem = GolemService.get(player)
	if action == "start" then
		local existing = active[player]
		if existing and now <= existing.challenge.expiresAt then
			return
		end
		active[player] = nil
		if not eligible(golem) then
			Remotes.Notify:FireClient(player, "runeResult", false, "Mount an active golem to cast")
			return
		end
		local remaining = (cooldownUntil[player] or 0) - now
		if remaining > 0 then
			Remotes.Notify:FireClient(player, "runeCooldown", remaining)
			return
		end
		local challenge = RuneSequence.new(rng, now, Config.RuneCasting.windowSeconds)
		active[player] = { challenge = challenge, golem = golem :: GolemService.Golem }
		cooldownUntil[player] = now + Config.RuneCasting.cooldownSeconds
		Remotes.Notify:FireClient(
			player,
			"runeStart",
			table.clone(challenge.sequence),
			workspace:GetServerTimeNow() + Config.RuneCasting.windowSeconds,
			Config.RuneCasting.cooldownSeconds
		)
	elseif action == "tap" then
		local attempt = active[player]
		if not attempt then
			return
		end
		if golem ~= attempt.golem or not eligible(golem) then
			active[player] = nil
			Remotes.Notify:FireClient(player, "runeResult", false, "Casting interrupted (no penalty)")
			return
		end
		local result = RuneSequence.press(attempt.challenge, rune, now)
		if result == "next" then
			Remotes.Notify:FireClient(player, "runeStep", attempt.challenge.nextIndex - 1)
		elseif result == "complete" then
			active[player] = nil
			boostUntil[player] = now + Config.RuneCasting.boostSeconds
			Remotes.Notify:FireClient(player, "runeResult", true, Config.RuneCasting.boostSeconds)
		elseif result ~= "ignored" then
			active[player] = nil
			Remotes.Notify:FireClient(player, "runeResult", false, "Rune missed (no penalty)")
		end
	end
end

function RuneService.start()
	Remotes.RuneInput.OnServerEvent:Connect(onInput)
	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
		cooldownUntil[player] = nil
		boostUntil[player] = nil
	end)
end

return RuneService
