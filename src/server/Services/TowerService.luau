--!strict
-- The Golem Tower (#62; design in docs/expansion-design.md): a private,
-- ten-wave challenge for a party or a solo player, started from Travel.
--   * The leader (or a solo player) picks a route: one island they have
--     unlocked. Its waves use that island's enemies, with its boss on the
--     waves in Config.Tower.bossWaves.
--   * Every party member must press Accept, and each one must be present,
--     standing, and have the route unlocked. The party is fixed at entry.
--   * Each run gets its own arena (a zone id above Config.TowerZoneBase), so
--     nothing is shared with other runs or with the islands.
--   * Tower enemies drop nothing. Each cleared wave pays every member still in
--     the run a fixed reward (Stats.towerWaveReward, shown before entry), once.
--   * Leaving, travelling away or disconnecting forfeits the waves not yet
--     cleared; rewards already paid are kept. If every golem in the run is
--     knocked out at once, the run ends.
-- No paid tickets, revives or random rewards, and no text anywhere.
-- Off unless Config.Tower.enabled is true.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MarbleBag = require(Shared:WaitForChild("MarbleBag"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local ActionService = require(script.Parent.ActionService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local EnemyService = require(script.Parent.EnemyService)
local GolemService = require(script.Parent.GolemService)
local PartyService = require(script.Parent.PartyService)
local WorldService = require(script.Parent.WorldService)

type Run = {
	arena: number, -- the arena's zone id
	route: number, -- the island id the waves come from
	leader: Player,
	members: { Player }, -- fixed when the run is set up
	accepted: { [Player]: boolean },
	present: { [Player]: boolean }, -- members still in the run once it starts
	state: string, -- "inviting", "break", "fighting" or "ended"
	inviteEndsAt: number, -- os.clock()
	nextAt: number, -- os.clock() when the break or the ending finishes
	wave: number, -- the wave being fought, or the last one cleared during a break
	cleared: number,
	toSpawn: number, -- regular enemies of this wave not spawned yet
	waveTotal: number, -- enemies in this wave, boss included
	bossPending: boolean,
	alive: { [Model]: boolean },
	paid: { [string]: boolean }, -- "<wave>:<UserId>" once paid
	endText: string?,
}

local TowerService = {}

local runOf: { [Player]: Run } = {}
local runs: { [number]: Run } = {} -- arena zone id -> run

local function say(player: Player, text: string)
	Remotes.Notify:FireClient(player, "message", text)
end

local function refresh(run: Run)
	for _, member in run.members do
		DataService.markChanged(member)
	end
end

local function arenaCenter(index: number): Vector3
	return Config.Tower.arenaOrigin + Vector3.new((index - 1) * Config.Tower.arenaSpacing, 0, 0)
end

local function freeArena(): number?
	for index = 1, Config.Tower.arenas do
		local zoneId = Config.TowerZoneBase + index
		if not runs[zoneId] then
			return zoneId
		end
	end
	return nil
end

-- Why this player can't take part in a run on this route now, or nil.
-- `own` is the run being set up, which doesn't count as "already in".
local function blockReason(player: Player, route: number, own: Run?): string?
	local data = DataService.get(player)
	local golem = GolemService.get(player)
	if not data or not golem or not player.Parent then
		return `{player.DisplayName} isn't ready`
	end
	if runOf[player] and runOf[player] ~= own then
		return `{player.DisplayName} is already in the tower`
	end
	if not GolemService.isActive(golem) then
		return `{player.DisplayName}'s golem is reforming`
	end
	local unlocked = Stats.zoneUnlocked(data, route)
	if not unlocked then
		return `{player.DisplayName} hasn't unlocked {(Config.Zones[route] :: any).name}`
	end
	return nil
end

local function release(run: Run)
	if runs[run.arena] == run then
		runs[run.arena] = nil
	end
	for _, member in run.members do
		if runOf[member] == run then
			runOf[member] = nil
		end
	end
	refresh(run)
end

-- Sends a golem back to the route's island if it's still in this arena.
local function sendHome(run: Run, player: Player)
	local golem = GolemService.get(player)
	if golem and golem.zoneId == run.arena then
		GolemService.sendToZone(golem, run.route)
	end
end

local function cancelInvite(run: Run, text: string)
	for _, member in run.members do
		if member.Parent then
			say(member, text)
		end
	end
	release(run)
end

local function endRun(run: Run, text: string)
	if run.state == "ended" then
		return
	end
	run.state = "ended"
	run.endText = text
	run.nextAt = os.clock() + Config.Tower.returnSeconds
	EnemyService.clearZone(run.arena)
	for player in run.present do
		say(player, text)
		AnalyticsService.custom(player, "TowerRunEnded", run.cleared)
	end
	refresh(run)
end

-- Takes a member out of a started run. Their paid waves stay paid.
local function leaveRun(run: Run, player: Player, text: string?)
	if not run.present[player] then
		return
	end
	run.present[player] = nil
	runOf[player] = nil
	if player.Parent then
		sendHome(run, player)
		if text then
			say(player, text)
		end
	end
	for other in run.present do
		say(other, `{player.DisplayName} left the tower.`)
	end
	DataService.markChanged(player)
	refresh(run)
	if next(run.present) == nil and run.state ~= "ended" then
		-- Nobody left to fight: free the arena straight away.
		run.state = "ended"
		EnemyService.clearZone(run.arena)
		release(run)
	end
end

local function startWave(run: Run, wave: number)
	local players = 0
	for _ in run.present do
		players += 1
	end
	run.state = "fighting"
	run.wave = wave
	run.toSpawn = Stats.towerWaveEnemies(wave, players)
	run.bossPending = Stats.towerBossFraction(wave) ~= nil and (Config.Bosses :: any)[run.route] ~= nil
	run.waveTotal = run.toSpawn + (if run.bossPending then 1 else 0)
	run.alive = {}
	for player in run.present do
		say(player, `Wave {wave} of {Config.Tower.waves}!`)
	end
	refresh(run)
end

-- Moves everyone into the arena. False if someone can't go (the run is cancelled).
local function begin(run: Run): boolean
	for _, member in run.members do
		local reason = blockReason(member, run.route, run)
		if not reason and member ~= run.leader and not PartyService.sameParty(run.leader, member) then
			reason = `{member.DisplayName} left the party`
		end
		if reason then
			cancelInvite(run, `The tower run was cancelled: {reason}.`)
			return false
		end
	end
	local index = run.arena - Config.TowerZoneBase
	WorldService.addArena(run.arena, arenaCenter(index), Config.Tower.arenaSize, Config.Tower.name)
	for _, member in run.members do
		run.present[member] = true
		local golem = GolemService.get(member)
		if golem then
			GolemService.sendToZone(golem, run.arena)
		end
		say(member, `Welcome to the {Config.Tower.name}! The first wave is coming.`)
	end
	run.state = "break"
	run.wave = 0
	run.nextAt = os.clock() + Config.Tower.waveBreakSeconds
	refresh(run)
	return true
end

local function payWave(run: Run)
	local reward = Stats.towerWaveReward(run.route, run.wave)
	for player in run.present do
		local key = `{run.wave}:{player.UserId}`
		if not run.paid[key] then
			run.paid[key] = true
			EconomyService.grantFlat(player, { minerals = reward.minerals, xp = reward.xp }, "tower")
			AnalyticsService.custom(player, "TowerWaveCleared", run.wave)
			say(player, `Wave {run.wave} cleared!`)
		end
	end
end

local enemyBags: { [number]: MarbleBag.Bag<string> } = {} -- which enemy comes next, per route

local function pickEnemy(route: number): string
	local bag = enemyBags[route]
	if not bag then
		local zone: any = Config.Zones[route]
		local entries = {}
		for _, id in zone.enemies do
			table.insert(entries, { value = id, weight = (Config.Enemies[id] :: any).spawnWeight or 1 })
		end
		bag = MarbleBag.new(entries)
		enemyBags[route] = bag
	end
	return bag:draw()
end

local function spawnPoint(run: Run): Vector3?
	local minDistance = (Config.Zones[run.route] :: any).minSpawnDistance
	for _ = 1, 6 do
		local point = WorldService.randomPoint(run.arena, 12)
		local clear = true
		for player in run.present do
			local golem = GolemService.get(player)
			if golem and (golem.root.Position - point).Magnitude < minDistance then
				clear = false
				break
			end
		end
		if clear then
			return point
		end
	end
	return nil
end

local function onDefeated(run: Run): (any) -> ()
	return function(enemy: any)
		run.alive[enemy.model] = nil
		refresh(run)
	end
end

local function spawnSome(run: Run)
	if run.bossPending then
		run.bossPending = false
		local fraction = Stats.towerBossFraction(run.wave) or 1
		local model = EnemyService.spawnInArena(
			run.arena,
			"boss" .. run.route,
			Config.Bosses[run.route] :: any,
			WorldService.getBossPoint(run.arena),
			true,
			fraction,
			onDefeated(run)
		).model
		run.alive[model] = true
	end
	local zone: any = Config.Zones[run.route]
	local players = 0
	for _ in run.present do
		players += 1
	end
	local cap = zone.maxEnemies + zone.extraEnemiesPerPlayer * (players - 1)
	local alive = 0
	for _ in run.alive do
		alive += 1
	end
	-- A few per tick, so a big wave doesn't build in one frame.
	for _ = 1, 3 do
		if run.toSpawn <= 0 or alive >= cap then
			return
		end
		local point = spawnPoint(run)
		if not point then
			return
		end
		local id = pickEnemy(run.route)
		local health = 1 + Config.Tower.healthPerWave * (run.wave - 1)
		local model = EnemyService.spawnInArena(
			run.arena,
			id,
			Config.Enemies[id] :: any,
			point,
			false,
			health,
			onDefeated(run)
		).model
		run.alive[model] = true
		run.toSpawn -= 1
		alive += 1
	end
end

local function tickRun(run: Run, now: number)
	if run.state == "inviting" then
		if now >= run.inviteEndsAt then
			cancelInvite(run, "The tower run was cancelled: not everyone accepted in time.")
		end
		return
	end
	if run.state == "ended" then
		if now >= run.nextAt then
			for player in run.present do
				runOf[player] = nil
				if player.Parent then
					sendHome(run, player)
				end
			end
			release(run)
		end
		return
	end

	-- Anyone who left the arena (travel, disconnect) has left the run.
	for player in run.present do
		local golem = GolemService.get(player)
		if not player.Parent or not golem or golem.zoneId ~= run.arena then
			leaveRun(run, player, `You left the {Config.Tower.name}. Rewards for cleared waves are yours to keep.`)
		end
	end
	if run.state == "ended" or next(run.present) == nil then
		return
	end
	local standing = false
	for player in run.present do
		local golem = GolemService.get(player)
		if golem and GolemService.isActive(golem) then
			standing = true
			break
		end
	end
	if not standing then
		endRun(run, `Every golem was knocked out on wave {run.wave}. You cleared {run.cleared} waves.`)
		return
	end

	if run.state == "break" then
		if now >= run.nextAt then
			startWave(run, run.wave + 1)
			spawnSome(run) -- the first enemies arrive with the wave call
		end
		return
	end

	-- Fighting. Enemies that fell off the arena are gone too.
	for model in run.alive do
		if model.Parent == nil then
			run.alive[model] = nil
		end
	end
	spawnSome(run)
	if run.toSpawn <= 0 and not run.bossPending and next(run.alive) == nil then
		run.cleared = run.wave
		payWave(run)
		if run.wave >= Config.Tower.waves then
			endRun(run, `You cleared all {Config.Tower.waves} waves of the {Config.Tower.name}!`)
		else
			run.state = "break"
			run.nextAt = now + Config.Tower.waveBreakSeconds
			refresh(run)
		end
	end
end

-- Runs every Config.Tower.tickSeconds; public so tests can drive it.
function TowerService.tick()
	local now = os.clock()
	for _, run in runs do
		local ok, err = pcall(function(): any
			tickRun(run, now)
			return nil
		end)
		if not ok then
			warn(`[TowerService] tower run in zone {run.arena} failed: {err}`)
			endRun(run, "The tower run had a problem and ended. Waves you cleared were paid.")
		end
	end
end

---------------------------------------------------------------- actions

local function start(player: Player, route: any): (boolean, string?)
	if not Config.Tower.enabled then
		return false, `The {Config.Tower.name} isn't open yet`
	end
	if type(route) ~= "number" or (Config.Zones :: any)[route] == nil then
		return false, "Pick an island"
	end
	if runOf[player] then
		return false, "You're already in a tower run"
	end
	if not PartyService.isLeader(player) then
		return false, "Your party leader starts tower runs"
	end
	local members = table.clone(PartyService.members(player))
	for _, member in members do
		local reason = blockReason(member, route)
		if reason then
			return false, reason
		end
	end
	local arena = freeArena()
	if not arena then
		return false, `The {Config.Tower.name} is full right now. Try again in a few minutes.`
	end
	local run: Run = {
		arena = arena,
		route = route,
		leader = player,
		members = members,
		accepted = { [player] = true },
		present = {},
		state = "inviting",
		inviteEndsAt = os.clock() + Config.Tower.inviteSeconds,
		nextAt = 0,
		wave = 0,
		cleared = 0,
		toSpawn = 0,
		waveTotal = 0,
		bossPending = false,
		alive = {},
		paid = {},
		endText = nil,
	}
	runs[arena] = run
	for _, member in members do
		runOf[member] = run
	end
	if #members == 1 then
		return begin(run), nil
	end
	for _, member in members do
		if member ~= player then
			say(member, `{player.DisplayName} wants to climb the {Config.Tower.name}! Open Travel to accept.`)
		end
	end
	refresh(run)
	return true, "Waiting for your party to accept"
end

local function accept(player: Player): (boolean, string?)
	local run = runOf[player]
	if not run or run.state ~= "inviting" then
		return false, "There's no tower invite to accept"
	end
	run.accepted[player] = true
	for _, member in run.members do
		if not run.accepted[member] then
			refresh(run)
			return true, "Waiting for the rest of your party"
		end
	end
	return begin(run), nil
end

local function decline(player: Player): (boolean, string?)
	local run = runOf[player]
	if not run or run.state ~= "inviting" then
		return false, "There's no tower invite"
	end
	cancelInvite(run, `{player.DisplayName} said no, so the tower run was cancelled.`)
	return true, nil
end

local function leave(player: Player): (boolean, string?)
	local run = runOf[player]
	if not run then
		return false, "You aren't in the tower"
	end
	if run.state == "inviting" then
		cancelInvite(run, `{player.DisplayName} cancelled the tower run.`)
		return true, nil
	end
	leaveRun(run, player, `You left the {Config.Tower.name}. Rewards for cleared waves are yours to keep.`)
	return true, nil
end

---------------------------------------------------------------- snapshot

local function snapshot(player: Player): any
	if not Config.Tower.enabled then
		return { enabled = false }
	end
	local view: any = nil
	local run = runOf[player]
	if run then
		local members = {}
		for _, member in run.members do
			table.insert(members, {
				name = member.DisplayName,
				accepted = run.accepted[member] == true,
				present = run.present[member] == true,
			})
		end
		local remaining = run.toSpawn + (if run.bossPending then 1 else 0)
		for _ in run.alive do
			remaining += 1
		end
		view = {
			state = run.state,
			route = run.route,
			wave = run.wave,
			cleared = run.cleared,
			remaining = remaining,
			waveTotal = run.waveTotal,
			isLeader = run.leader == player,
			leaderName = run.leader.DisplayName,
			inviteLeft = math.max(math.ceil(run.inviteEndsAt - os.clock()), 0),
			members = members,
			endText = run.endText,
		}
	end
	return {
		enabled = true,
		run = view,
		isLeader = PartyService.isLeader(player),
		partySize = #PartyService.members(player),
		full = freeArena() == nil,
	}
end

function TowerService.start()
	DataService.addProvider("tower", snapshot)
	ActionService.register("towerStart", start)
	ActionService.register("towerAccept", accept)
	ActionService.register("towerDecline", decline)
	ActionService.register("towerLeave", leave)

	Players.PlayerRemoving:Connect(function(player)
		local run = runOf[player]
		if not run then
			return
		end
		if run.state == "inviting" then
			cancelInvite(run, `{player.DisplayName} left, so the tower run was cancelled.`)
		else
			leaveRun(run, player, nil)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Tower.tickSeconds)
			TowerService.tick()
		end
	end)
end

return TowerService
