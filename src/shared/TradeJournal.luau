--!strict
-- Pure rules for crash-safe trades, shared with the offline regression suite.
-- A trade changes two players' saves, and no single DataStore write covers two
-- records. So a trade runs in three steps:
--   1. prepare: each side's offered spares leave their inventory and wait in
--      `trades.pending` (escrow). Both saves are written before going on.
--   2. decide: one journal record, keyed by the trade's random id, is set to
--      "committed" or "aborted" with UpdateAsync. That single write is the
--      moment the trade happens. A record that already holds a decision keeps it.
--   3. resolve: each side applies the decision to its own save. Committed hands
--      over the other side's artifacts; aborted gives the escrowed ones back.
-- If a server dies at any point, a save that still holds `pending` resolves on
-- its next load by asking the journal, writing "aborted" if nothing was
-- decided yet. Each side's half lives in one record, so it applies exactly once.
-- Journal records hold only the decision and a time, no user ids.
local TradeJournal = {}

type Pending = {
	id: string, -- journal key suffix
	with: number, -- the other player's UserId, for the trade log
	gave: { string }, -- artifact ids this side sends (held in escrow)
	got: { string }, -- artifact ids this side receives if committed
	day: number, -- UTC day the trade was made, for the daily limit
	at: number, -- os.time() the trade was made
}

local function tradable(data: any, id: string): number
	local spares = data.artifacts.spares[id] or 0
	local bound = data.artifacts.boundSpares[id] or 0
	return math.max(spares - bound, 0)
end

local function copyList(list: { string }): { string }
	local result = {}
	for _, id in list do
		table.insert(result, id)
	end
	return result
end

-- Moves the offered spares into escrow. Returns false, changing nothing, if a
-- trade is already pending or any offered copy isn't a tradable spare.
function TradeJournal.prepare(data: any, pending: Pending): boolean
	if data.trades.pending ~= nil then
		return false
	end
	local need: { [string]: number } = {}
	for _, id in pending.gave do
		need[id] = (need[id] or 0) + 1
	end
	for id, count in need do
		if tradable(data, id) < count then
			return false
		end
	end
	for _, id in pending.gave do
		local left = data.artifacts.spares[id] - 1
		data.artifacts.spares[id] = if left > 0 then left else nil
		if (data.artifacts.boundSpares[id] or 0) > left then
			data.artifacts.boundSpares[id] = if left > 0 then left else nil
		end
	end
	data.trades.pending = {
		id = pending.id,
		with = pending.with,
		gave = copyList(pending.gave),
		got = copyList(pending.got),
		day = pending.day,
		at = pending.at,
	}
	return true
end

-- The UpdateAsync transform for a journal record. An existing decision always
-- wins; otherwise `wanted` is written. Always returns a record, so the caller
-- reads the final decision from what UpdateAsync returns.
function TradeJournal.decide(record: any, wanted: string, now: number): any
	if TradeJournal.status(record) then
		return record
	end
	return { status = wanted, at = now }
end

-- "committed", "aborted", or nil if the record holds no decision.
function TradeJournal.status(record: any): string?
	if type(record) == "table" and (record.status == "committed" or record.status == "aborted") then
		return record.status
	end
	return nil
end

-- Applies a decision to this side's save and clears `pending`. `addCopy` gives
-- one received artifact. Returns false if nothing was pending or the status
-- isn't a decision.
function TradeJournal.resolve(data: any, status: string, addCopy: (any, string) -> (), logKept: number): boolean
	local pending = data.trades.pending
	if type(pending) ~= "table" or (status ~= "committed" and status ~= "aborted") then
		return false
	end
	if status == "committed" then
		for _, id in pending.got do
			addCopy(data, id)
		end
		local trades = data.trades
		if trades.day == pending.day then
			trades.count += 1
		elseif pending.day > trades.day then
			trades.day = pending.day
			trades.count = 1
		end
		table.insert(trades.log, { t = pending.at, with = pending.with, gave = pending.gave, got = pending.got })
		while #trades.log > logKept do
			table.remove(trades.log, 1)
		end
	else
		for _, id in pending.gave do
			data.artifacts.spares[id] = (data.artifacts.spares[id] or 0) + 1
		end
	end
	data.trades.pending = nil
	return true
end

return TradeJournal
