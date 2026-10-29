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
--   * The swap re-checks both saves, then runs as a crash-safe journal trade
--     (TradeJournal): offered spares go into escrow in both saves, one journal
--     write decides the trade, and each save settles from that decision. A
--     crash or failed save at any step can't duplicate or lose an artifact.
--   * Each trade is logged in both saves without partner UserIds.
-- There is no text input anywhere in a trade.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))
local TradeJournal = require(Shared:WaitForChild("TradeJournal"))

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
local settling: { [Player]: boolean } = {} -- a pending trade is being finished for this player

-- GetDataStore throws in an unpublished place; trading then stays off.
local journalOk, journalOrError = pcall(function()
	return DataStoreService:GetDataStore(Config.Trading.journalStore)
end)
local journal: DataStore? = if journalOk then journalOrError :: any else nil

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
	if not profile.canSave or not journal then
		return "Trading needs your progress to save, and it isn't saving here"
	end
	if profile.data.trades.pending then
		return "Your last trade is still being saved. Your artifacts are safe."
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

local function receive(player: Player): (any, string) -> ()
	local golem = GolemService.get(player)
	local slots = if golem then golem.stats.artifactSlots else Config.Golem.baseArtifactSlots
	return function(data: any, id: string)
		ArtifactService.addCopy(data, id, slots, false)
	end
end

-- Saves one player, retrying. True only if this server wrote the save.
local function saveWithRetries(player: Player): boolean
	for attempt = 1, Config.Trading.saveAttempts do
		if DataService.saveNow(player) then
			return true
		end
		if not player.Parent or not DataService.get(player) then
			return false
		end
		task.wait(attempt * 2)
	end
	warn(`[TradeService] couldn't save {player.UserId} during a trade`)
	return false
end

-- Writes `wanted` into the trade's journal record unless it already holds a
-- decision, and returns the decision that stands. Nil if it couldn't be read.
local function decide(id: string, wanted: string): string?
	if not journal then
		return nil
	end
	local store = journal
	for attempt = 1, Config.Trading.saveAttempts do
		local ok, record = pcall(function()
			return store:UpdateAsync("trade_" .. id, function(current)
				return TradeJournal.decide(current, wanted, os.time())
			end)
		end)
		local status = if ok then TradeJournal.status(record) else nil
		if status then
			return status
		end
		warn(`[TradeService] journal write for trade {id} failed (attempt {attempt}): {record}`)
		task.wait(attempt * 2)
	end
	return nil
end

-- Marks one side of a decided trade settled; removes the record once both are.
-- Failing here only leaves a small record behind, so it doesn't retry for long.
local function markSettled(id: string, side: string)
	if not journal then
		return
	end
	local store = journal
	local key = "trade_" .. id
	local ok, record = pcall(function()
		return store:UpdateAsync(key, function(current)
			return TradeJournal.markSettled(current, side)
		end)
	end)
	if ok and TradeJournal.bothSettled(record) then
		pcall(function()
			store:RemoveAsync(key)
		end)
	end
end

-- Applies the decision to a loaded player's save if it still holds that trade.
local function settleLoaded(player: Player, id: string, status: string): boolean
	local data = DataService.get(player)
	local pending = data and data.trades.pending
	if not pending or pending.id ~= id then
		return false
	end
	local side = pending.side
	local addCopy = receive(player)
	local done = false
	DataService.update(player, function(d)
		done = TradeJournal.resolve(d, status, addCopy, Config.Trading.logKept)
	end)
	if done then
		task.spawn(function()
			-- Only once the save without `pending` is written may this side
			-- tell the journal it no longer needs the record.
			if saveWithRetries(player) and side then
				markSettled(id, side)
			end
		end)
	end
	return done
end

-- Finishes a trade left pending by an earlier session (a crash, a failed save
-- or a lost journal write). Writing "aborted" only takes effect if nothing was
-- decided; a trade that did commit still completes.
local function settle(player: Player)
	local data = DataService.get(player)
	local pending = data and data.trades.pending
	if not pending or settling[player] then
		return
	end
	settling[player] = true
	local status = decide(pending.id, "aborted")
	settling[player] = nil
	if not status then
		task.delay(Config.Trading.settleRetrySeconds, function()
			if player.Parent then
				settle(player)
			end
		end)
		return
	end
	if settleLoaded(player, pending.id, status) then
		say(
			player,
			if status == "committed"
				then "Your last trade finished. Check your artifacts!"
				else "Your last trade didn't go through, so your artifacts were returned."
		)
	end
end

-- After escrow: save both sides, decide, then settle whoever is still here.
-- Anyone who left settles from the journal the next time they load.
local function finish(a: Player, b: Player, id: string)
	local saved = saveWithRetries(a) and saveWithRetries(b)
	local status = decide(id, if saved then "committed" else "aborted")
	settling[a] = nil
	settling[b] = nil
	if not status then
		for _, player in { a, b } do
			if DataService.get(player) then
				say(player, "Your trade is still being saved. Your artifacts are safe, and it will finish soon.")
				task.delay(Config.Trading.settleRetrySeconds, function()
					if player.Parent then
						settle(player)
					end
				end)
			end
		end
		return
	end
	for _, player in { a, b } do
		local other = if player == a then b else a
		if settleLoaded(player, id, status) then
			say(
				player,
				if status == "committed"
					then `Trade complete with {other.DisplayName}!`
					else "The trade couldn't be saved, so it was cancelled. Your artifacts are back."
			)
		end
	end
	if status == "committed" then
		Events.fire("traded", a, b)
		for _, player in { a, b } do
			if player.Parent then
				AnalyticsService.custom(player, "TradeCompleted", 1)
			end
		end
	end
end

-- Runs with no waiting from the first check to escrow; finish() does the rest.
local function commit(trade: Trade)
	local a, b = trade.a, trade.b
	local dataA, dataB = DataService.get(a), DataService.get(b)
	if not dataA or not dataB or not a.Parent or not b.Parent then
		cancel(trade, "The trade was cancelled.")
		return
	end
	local blocked = blockReason(a) or blockReason(b)
	if blocked or not mayTradeWith(a, b, false) or settling[a] or settling[b] then
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

	local id = HttpService:GenerateGUID(false)
	local day, now = today(), os.time()
	local function entry(player: Player, other: Player): any
		return {
			id = id,
			gave = give[player],
			got = give[other],
			day = day,
			at = now,
			side = if player == a then "a" else "b",
		}
	end
	local okA, okB = false, false
	DataService.update(a, function(d)
		okA = TradeJournal.prepare(d, entry(a, b))
	end)
	if okA then
		DataService.update(b, function(d)
			okB = TradeJournal.prepare(d, entry(b, a))
		end)
	end
	if not okB then
		-- Nothing was saved yet, so undo a's escrow in memory and stop.
		if okA then
			DataService.update(a, function(d)
				TradeJournal.resolve(d, "aborted", function(_: any, _: string) end, Config.Trading.logKept)
			end)
		end
		cancel(trade, "The trade was cancelled: an offered artifact isn't available any more.")
		return
	end
	settling[a] = true
	settling[b] = true
	close(trade)
	say(a, "Saving your trade...")
	say(b, "Saving your trade...")
	task.spawn(finish, a, b, id)
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
	local data = DataService.get(player)
	if data and data.trades.pending and not settling[player] then
		task.spawn(settle, player) -- a trade from an earlier session is still open
	end
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
		if trade.ready[player] then
			return true, nil -- already Ready: don't restart the countdown
		end
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
			table.insert(spares, {
				id = id,
				name = Config.Artifacts[id].name,
				tradable = Stats.tradableSpares(data, id),
				bound = total - Stats.tradableSpares(data, id),
			})
		end
	end

	local partners = {}
	for _, other in Players:GetPlayers() do
		if
			other ~= player
			and DataService.get(other)
			and (PartyService.sameParty(player, other) or PartyService.friendNow(player, other))
		then
			table.insert(partners, { userId = other.UserId, name = other.DisplayName, busy = tradeOf[other] ~= nil })
		end
	end
	local incoming = {}
	local now = os.clock()
	for requester, expiry in requests[player] or ({} :: any) do
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

	-- A save can hold a trade that a crash or failed save left unfinished.
	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(settle, player)
	end)

	-- Open trades don't sit around forever.
	task.spawn(function()
		while true do
			task.wait(Config.Trading.sweepSeconds)
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
