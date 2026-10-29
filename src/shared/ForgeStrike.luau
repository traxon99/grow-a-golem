--!strict
-- Pure, deterministic rules for the optional post-forge anvil strike.
-- Only the server's receipt time grades an attempt; clients send no timestamp.

local ForgeStrike = {}

function ForgeStrike.isPerfect(now: number, targetAt: number, halfWindow: number): boolean
	if now ~= now or targetAt ~= targetAt or halfWindow <= 0 or halfWindow ~= halfWindow then
		return false
	end
	return now >= targetAt - halfWindow and now <= targetAt + halfWindow
end

-- Fixed mineral refund disclosed before the strike. Never a random stat roll.
function ForgeStrike.refund(cost: { [string]: number }, fraction: number): { [string]: number }
	local result: { [string]: number } = {}
	if fraction <= 0 or fraction > 1 then
		return result
	end
	for mineral, amount in cost do
		if amount > 0 then
			result[mineral] = math.max(1, math.floor(amount * fraction))
		end
	end
	return result
end

return ForgeStrike
