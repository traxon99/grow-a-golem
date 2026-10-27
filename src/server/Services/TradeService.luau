--!strict
-- Trading spare artifact copies between two players. It's built so a kid can't
-- be rushed or tricked, and so nothing can be duplicated:
--   * Roblox's policy check must allow trading (fail closed, PolicyService).
--   * Only friends or party members can trade, and both accounts must be old
--     enough (Config.Trading.minAccountAgeDays). A daily limit caps it.
--   * Only spare copies move, never the first copy of an artifact, never
--     minerals or cosmetics. Spares found under Robux-bought 2x Luck are bound.
--   * Both players press Ready, wait out a countdown, then both press Confirm.
--     Any change to either side resets everything.
--   * The swap re-checks both saves and applies both sides in one go with no
--     waiting in between, so a player leaving mid-trade can't duplicate items.
--   * Each trade is logged in both saves, keyed by UserId.
-- There is no text input anywhere in a trade.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local ActionService = require(script.Parent.ActionService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local ArtifactService = require(script.Parent.ArtifactService)
local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)
local GolemService = require(script.Parent.GolemService)
local PartyService = require(script.Parent.PartyService)
local PolicyService = require(script.Parent.PolicyService)

type Trade = {
	a: Player,
	b: Player,
	offers: { [Player]: { [string]: boolean } },
	ready: { [Player]: boolean },
	confirmed: { [Player]: boolean },
	confirmAt: number?, -- os.clock() after which Confirm is allowed
	confirmAtTime: number?, -- the same moment in os.time(), for the client
	expiresAt: number,
}

local TradeService = {}

local tradeOf: { [Player]: Trade } = {}
local requests: { [Player]: { [Player]: number } } = {} -- target -> requester -> expiry (os.clock)
local lastRequest: { [Player]: number } = {}

local function today(): number
	return os.time() // 86400
end

local function tradesLeft(data: any): number
	local trades = data.trades
	if trades.day ~= today() then
		return Config.Trading.dailyLimit
	end
	return math.max(Config.Trading.dailyLimit - trades.count, 0)
end

-- Why this player can't trade right now, or nil if they can. Anything unknown
-- counts as "can't".
local function blockReason(player: Player): string?
	local profile = DataService.getSession(player)
	if not profile then
		return "Your golem is still loading"
	end
	if not profile.canSave then
		return "Trading needs your progress to save, and it isn't saving here"
	end
	if not PolicyService.isReady(player) then
		return "Checking your account, try again in a moment"
	end
	if not PolicyService.paidTradingAllowed(player) then
		return "Trading isn't available for your account"
	end
	if player.AccountAge < Config.Trading.minAccountAgeDays then
		return `Trading opens when your Roblox account is {Config.Trading.minAccountAgeDays} days old`
	end
	if tradesLeft(profile.data) <= 0 then
		return "You've reached today's trade limit. Come back tomorrow!"
	end
	return nil
end

-- Friends or party members only. `wait` is true in handlers (which may wait
-- for the friend lookup) and false in snapshots (which must not).
local function mayTradeWith(a: Player, b: Player, wait: boolean): boolean
	if PartyService.sameParty(a, b) then
		return true
	end
	return if wait then PartyService.areFriends(a, b) else PartyService.friendNow(a, b)
end

local function partnerOf(trade: Trade, player: Player): Player
	return if trade.a == player then trade.b else trade.a
end

local function touch(trade: Trade)
	trade.expiresAt = os.clock() + Config.Trading.idleTimeout
end

local function refresh(trade: Trade)
	DataService.markChanged(trade.a)
	DataService.markChanged(trade.b)
end

local function say(player: Player, text: string)
	Remotes.Notify:FireClient(player, "message", text)
end

local function close(trade: Trade)
	tradeOf[trade.a] = nil
	tradeOf[trade.b] = nil
	refresh(trade)
end

local function cancel(trade: Trade, reason: string)
	close(trade)
	say(trade.a, reason)
	say(trade.b, reason)
end

-- Any change to either side starts the Ready / countdown / Confirm over.
local function reset(trade: Trade)
	trade.ready = {}
	trade.confirmed = {}
	trade.confirmAt = nil
	trade.confirmAtTime = nil
	touch(trade)
end

local function offerList(trade: Trade, player: Player): { string }
	local list = {}
	for _, id in Config.ArtifactOrder do
		if trade.offers[player][id] then
			table.insert(list, id)
		end
	end
	return list
end

local function valueOf(ids: { string }): number
	local total = 0
	for _, id in ids do
		total += Config.Trading.value[Config.Artifacts[id].source] or 1
	end
	return total
end

local function lopsided(giveValue: number, getValue: number): boolean
	return giveValue > 0 and giveValue > getValue * Config.Trading.lopsidedRatio
end

---------------------------------------------------------------- the swap

-- Runs with no waiting from the first check to the last write.
local function commit(trade: Trade)
	local a, b = trade.a, trade.b
	local dataA, dataB = DataService.get(a), DataService.get(b)
	if not dataA or not dataB or not a.Parent or not b.Parent then
		cancel(trade, "The trade was cancelled.")
		return
	end
	local blocked = blockReason(a) or blockReason(b)
	if blocked or not mayTradeWith(a, b, false) then
		cancel(trade, "The trade was cancelled because one of you can't trade right now.")
		return
	end
	local give = { [a] = offerList(trade, a), [b] = offerList(trade, b) }
	if #give[a] == 0 and #give[b] == 0 then
		cancel(trade, "The trade was cancelled: nothing was offered.")
		return
	end
	for player, data in { [a] = dataA, [b] = dataB } do
		for _, id in give[player] do
			if Stats.tradableSpares(data, id) < 1 then
				cancel(trade, "The trade was cancelled: an offered artifact isn't available any more.")
				return
			end
		end
	end

	local day = today()
	local function apply(player: Player, other: Player, sends: { string }, gets: { string })
		local golem = GolemService.get(player)
		local slots = if golem then golem.stats.artifactSlots else Config.Golem.baseArtifactSlots
		DataService.update(player, function(d)
			for _, id in sends do
				local left = d.artifacts.spares[id] - 1
				d.artifacts.spares[id] = if left > 0 then left else nil
				if (d.artifacts.boundSpares[id] or 0) > left then
					d.artifacts.boundSpares[id] = if left > 0 then left else nil
				end
			end
			for _, id in gets do
				ArtifactService.addCopy(d, id, slots, false)
			end
			local trades = d.trades
			if trades.day ~= day then
				trades.day = day
				trades.count = 0
			end
			trades.count += 1
			table.insert(trades.log, { t = os.time(), with = other.UserId, gave = sends, got = gets })
			while #trades.log > Config.Trading.logKept do
				table.remove(trades.log, 1)
			end
		end)
	end
	apply(a, b, give[a], give[b])
	apply(b, a, give[b], give[a])
	close(trade)
	say(a, `Trade complete with {b.DisplayName}!`)
	say(b, `Trade complete with {a.DisplayName}!`)
	Events.fire("traded", a, b)
	AnalyticsService.custom(a, "TradeCompleted", 1)
	AnalyticsService.custom(b, "TradeCompleted", 1)

	-- Write both saves right away so a crash can't leave one side undone.
	for _, player in { a, b } do
		task.spawn(function()
			if not DataService.saveNow(player) then
				warn(`[TradeService] couldn't save {player.UserId} right after a trade`)
			end
		end)
	end
end

---------------------------------------------------------------- actions

local function findPlayer(userId: any): Player?
	return if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function request(player: Player, userId: any): (boolean, string?)
	local target = findPlayer(userId)
	if not target or target == player then
		return false, "That player isn't here"
	end
	if tradeOf[player] then
		return false, "Finish or cancel your current trade first"
	end
	if tradeOf[target] then
		return false, `{target.DisplayName} is busy trading`
	end
	local now = os.clock()
	if now - (lastRequest[player] or -100) < Config.Trading.requestCooldown then
		return false, "Slow down a little!"
	end
	lastRequest[player] = now
	local mine = blockReason(player)
	if mine then
		return false, mine
	end
	if blockReason(target) then
		return false, `{target.DisplayName} can't trade right now`
	end
	if not mayTradeWith(player, target, true) then
		return false, "You can trade with friends and party members. Invite them to a party first."
	end
	requests[target] = requests[target] or {}
	requests[target][player] = now + Config.Trading.requestTimeout
	say(target, `{player.DisplayName} wants to trade! Open Trade to answer.`)
	DataService.markChanged(target)
	return true, `Trade request sent to {target.DisplayName}`
end

local function accept(player: Player, userId: any): (boolean, string?)
	local other = findPlayer(userId)
	local pending = requests[player]
	if not other or not pending or (pending[other] or 0) < os.clock() then
		return false, "That request expired"
	end
	pending[other] = nil
	if tradeOf[player] or tradeOf[other] then
		return false, "One of you is already in a trade"
	end
	if blockReason(player) or blockReason(other) or not mayTradeWith(player, other, true) then
		return false, "You can't trade with them right now"
	end
	local trade: Trade = {
		a = other,
		b = player,
		offers = { [other] = {}, [player] = {} },
		ready = {},
		confirmed = {},
		expiresAt = os.clock() + Config.Trading.idleTimeout,
	}
	tradeOf[other] = trade
	tradeOf[player] = trade
	say(other, `{player.DisplayName} accepted! Add artifacts to trade.`)
	refresh(trade)
	return true, `Trading with {other.DisplayName}`
end

local function decline(player: Player, userId: any): (boolean, string?)
	local other = findPlayer(userId)
	if other and requests[player] then
		requests[player][other] = nil
	end
	DataService.markChanged(player)
	return true, nil
end

local function offer(player: Player, artifactId: any): (boolean, string?)
	local trade = tradeOf[player]
	local data = DataService.get(player)
	if not trade or not data or type(artifactId) ~= "string" or not Config.Artifacts[artifactId] then
		return false, "Not ready"
	end
	if trade.offers[player][artifactId] then
		return false, "Already offered"
	end
	if #offerList(trade, player) >= Config.Trading.maxItems then
		return false, `You can offer up to {Config.Trading.maxItems} artifacts`
	end
	if Stats.tradableSpares(data, artifactId) < 1 then
		return false, "You have no spare copy of that to trade"
	end
	trade.offers[player][artifactId] = true
	reset(trade)
	refresh(trade)
	return true, nil
end

local function remove(player: Player, artifactId: any): (boolean, string?)
	local trade = tradeOf[player]
	if not trade or type(artifactId) ~= "string" or not trade.offers[player][artifactId] then
		return false, "Not offered"
	end
	trade.offers[player][artifactId] = nil
	reset(trade)
	refresh(trade)
	return true, nil
end

local function setReady(player: Player, on: any): (boolean, string?)
	local trade = tradeOf[player]
	if not trade or type(on) ~= "boolean" then
		return false, "Not ready"
	end
	if on then
		if #offerList(trade, trade.a) == 0 and #offerList(trade, trade.b) == 0 then
			return false, "Add an artifact to trade first"
		end
		trade.ready[player] = true
		if trade.ready[trade.a] and trade.ready[trade.b] then
			-- Both ready: a countdown starts, and Confirm opens after it.
			trade.confirmed = {}
			trade.confirmAt = os.clock() + Config.Trading.countdownSeconds
			trade.confirmAtTime = os.time() + Config.Trading.countdownSeconds + 1
		end
	else
		trade.ready[player] = nil
		trade.confirmed = {}
		trade.confirmAt = nil
		trade.confirmAtTime = nil
	end
	touch(trade)
	refresh(trade)
	return true, nil
end

local function confirm(player: Player): (boolean, string?)
	local trade = tradeOf[player]
	if not trade or not trade.ready[trade.a] or not trade.ready[trade.b] or not trade.confirmAt then
		return false, "Both of you need to be Ready first"
	end
	if os.clock() < trade.confirmAt then
		return false, "Take a moment to check the trade"
	end
	trade.confirmed[player] = true
	touch(trade)
	if trade.confirmed[trade.a] and trade.confirmed[trade.b] then
		commit(trade)
	else
		say(partnerOf(trade, player), `{player.DisplayName} confirmed. Check the trade, then confirm.`)
		refresh(trade)
	end
	return true, nil
end

local function cancelAction(player: Player): (boolean, string?)
	local trade = tradeOf[player]
	if not trade then
		return false, "You aren't trading"
	end
	cancel(trade, `{player.DisplayName} cancelled the trade.`)
	return true, nil
end

---------------------------------------------------------------- snapshot

local function snapshot(player: Player): any
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local reason = blockReason(player)
	local spares = {}
	for _, id in Config.ArtifactOrder do
		local total = data.artifacts.spares[id] or 0
		if total > 0 then
			table.insert(spares, { id = id, name = Config.Artifacts[id].name, tradable = Stats.tradableSpares(data, id), bound = total - Stats.tradableSpares(data, id) })
		end
	end

	local partners = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and DataService.get(other) and (PartyService.sameParty(player, other) or PartyService.friendNow(player, other)) then
			table.insert(partners, { userId = other.UserId, name = other.DisplayName, busy = tradeOf[other] ~= nil })
		end
	end
	local incoming = {}
	local now = os.clock()
	for requester, expiry in requests[player] or {} do
		if expiry > now and requester.Parent then
			table.insert(incoming, { userId = requester.UserId, name = requester.DisplayName })
		end
	end

	local view = nil
	local trade = tradeOf[player]
	if trade then
		local other = partnerOf(trade, player)
		local mine, theirs = offerList(trade, player), offerList(trade, other)
		local function named(ids: { string }): { any }
			local list = {}
			for _, id in ids do
				table.insert(list, { id = id, name = Config.Artifacts[id].name, source = Config.Artifacts[id].source })
			end
			return list
		end
		view = {
			partner = { userId = other.UserId, name = other.DisplayName },
			mine = named(mine),
			theirs = named(theirs),
			myReady = trade.ready[player] == true,
			theirReady = trade.ready[other] == true,
			myConfirmed = trade.confirmed[player] == true,
			theirConfirmed = trade.confirmed[other] == true,
			confirmAt = trade.confirmAtTime,
			lopsided = lopsided(valueOf(mine), valueOf(theirs)),
		}
	end

	return {
		blocked = reason,
		left = tradesLeft(data),
		spares = spares,
		partners = partners,
		incoming = incoming,
		trade = view,
	}
end

function TradeService.start()
	DataService.addProvider("trade", snapshot)
	ActionService.register("tradeRequest", request)
	ActionService.register("tradeAccept", accept)
	ActionService.register("tradeDecline", decline)
	ActionService.register("tradeOffer", offer)
	ActionService.register("tradeRemove", remove)
	ActionService.register("tradeReady", setReady)
	ActionService.register("tradeConfirm", confirm)
	ActionService.register("tradeCancel", cancelAction)

	-- Open trades don't sit around forever.
	task.spawn(function()
		while true do
			task.wait(5)
			local seen: { [Trade]: boolean } = {}
			for _, trade in tradeOf do
				if not seen[trade] then
					seen[trade] = true
					if os.clock() > trade.expiresAt then
						cancel(trade, "The trade timed out.")
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Leaving cancels the trade before anything has moved.
		local trade = tradeOf[player]
		if trade then
			cancel(trade, `{player.DisplayName} left, so the trade was cancelled.`)
		end
		requests[player] = nil
		lastRequest[player] = nil
		for _, pending in requests do
			pending[player] = nil
		end
	end)
end

return TradeService
