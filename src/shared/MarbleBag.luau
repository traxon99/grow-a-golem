--!strict
-- Marble bags: every random pick in the game draws a marble from a bag
-- without putting it back, and the bag refills once it's empty. The average
-- rate matches the weights, but streaks can't run long: a bag always holds
-- its winners, so the chance of a find goes up with every miss and a find is
-- sure before the bag runs out.
--
-- Two shapes:
-- * Weighted bags (MarbleBag.new) live in server memory: which enemy spawns,
--   which mineral a node holds. A weight is how many marbles that entry puts
--   in the bag.
-- * Winner bags (MarbleBag.count / MarbleBag.after) are plain { drawn, wins }
--   tables saved in player data, for artifact finds. Stats and the menus read
--   the same counts the server draws from, so the odds shown are the real
--   odds.

local MarbleBag = {}

export type Entry<T> = { value: T, weight: number }
export type Bag<T> = { draw: (self: Bag<T>) -> T }
export type Winners = { drawn: number, wins: number }

local function fill<T>(entries: { Entry<T> }): ({ number }, number)
	local left, total = {}, 0
	for i, entry in entries do
		local marbles = math.max(math.floor(entry.weight + 0.5), 0)
		left[i] = marbles
		total += marbles
	end
	return left, total
end

-- A bag holding `weight` marbles of each entry's value.
function MarbleBag.new<T>(entries: { Entry<T> }): Bag<T>
	assert(#entries > 0, "a marble bag needs at least one entry")
	local left, total = fill(entries)
	local bag = {}
	function bag.draw(_self: Bag<T>): T
		if total <= 0 then
			left, total = fill(entries)
			if total <= 0 then
				return entries[#entries].value
			end
		end
		local pick = math.random(1, total)
		for i, marbles in left do
			if pick <= marbles then
				left[i] -= 1
				total -= 1
				return entries[i].value
			end
			pick -= marbles
		end
		return entries[#entries].value
	end
	return bag :: any
end

-- Draws one value from a saved list of what's left, refilling it from `all`
-- when it's empty, so every value comes up once before any repeats. Returns
-- the value and the list to save.
function MarbleBag.drawFromList<T>(left: { T }?, all: { T }): (T, { T })
	local valid = {}
	local saved: { T } = left or {}
	for _, value in saved do
		if table.find(all, value) then
			table.insert(valid, value)
		end
	end
	if #valid == 0 then
		valid = table.clone(all)
	end
	local value = table.remove(valid, math.random(1, #valid)) :: T
	return value, valid
end

-- A saved bag's counts before the next draw. A bag drawn to its end starts
-- fresh. When luck shrank the bag below what's already drawn, the winners
-- still in it are owed, so they become the only marbles left.
local function current(state: Winners?, size: number, winners: number): (number, number)
	local drawn = if state then state.drawn else 0
	local wins = if state then state.wins else 0
	if drawn >= size then
		if wins < winners then
			return size - (winners - wins), wins
		end
		return 0, 0
	end
	return drawn, wins
end

-- What's left in a saved winner bag of `size` marbles holding `winners`
-- winners: marbles left and winners left.
function MarbleBag.count(state: Winners?, size: number, winners: number): (number, number)
	local drawn, wins = current(state, size, winners)
	local marblesLeft = size - drawn
	return marblesLeft, math.min(math.max(winners - wins, 0), marblesLeft)
end

-- The saved state after one more draw.
function MarbleBag.after(state: Winners?, size: number, winners: number, won: boolean): Winners
	local drawn, wins = current(state, size, winners)
	drawn += 1
	if won then
		wins += 1
	end
	if drawn >= size then
		return { drawn = 0, wins = 0 }
	end
	return { drawn = drawn, wins = wins }
end

return MarbleBag
