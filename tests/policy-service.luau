-- The fail-closed paid-random/trading gate (PolicyService). docs/reference/
-- safety-compliance.md rule 10: 2x Luck and trading stay off until Roblox's
-- policy lookup explicitly allows them, and stay off if the lookup never
-- resolves. The check script bundles the real Config above this file and
-- loads the real PolicyService with its requires replaced by the mocks
-- below. check() isn't exported and is only reachable through the
-- DataService.ProfileLoaded callback .start() registers, so here (unlike
-- every other service test in this bundle) task.spawn actually runs its
-- callback instead of being a no-op; task.wait stays a no-op so the retry
-- loop's real-second delays never happen.
do
	local function signal()
		local listeners = {}
		return {
			Connect = function(_, fn)
				table.insert(listeners, fn)
			end,
			Fire = function(_, ...)
				for _, fn in listeners do
					fn(...)
				end
			end,
		}
	end

	local removing = signal()
	local providers = {}
	local changed = {}
	local profileLoaded
	-- [player] = a queue of { ok, info?, leaveAfter? } popped one per
	-- GetPolicyInfoForPlayerAsync call for that player.
	local queues = {}
	local calls = {}

	local policy = loadPolicyService({
		Config = Config,
		DataService = {
			addProvider = function(name, fn)
				providers[name] = fn
			end,
			ProfileLoaded = {
				Connect = function(_, fn)
					profileLoaded = fn
				end,
			},
			markChanged = function(player)
				changed[player] = (changed[player] or 0) + 1
			end,
		},
	}, {
		GetService = function()
			return {
				PlayerRemoving = removing,
				WaitForChild = function()
					return {}
				end,
				GetPolicyInfoForPlayerAsync = function(_self, player)
					calls[player] = (calls[player] or 0) + 1
					local queue = queues[player]
					local step = queue and table.remove(queue, 1)
					assert(step, "a mock result was queued for every call this test makes")
					if step.leaveAfter then
						player.Parent = nil
					end
					if not step.ok then
						error("policy lookup failed")
					end
					return step.info
				end,
			}
		end,
	}, {
		spawn = function(fn, ...)
			fn(...)
		end,
		wait = function() end,
	})
	policy.start()
	assert(profileLoaded, "ProfileLoaded is connected")

	local nextId = 0
	local function join()
		nextId += 1
		return { UserId = nextId, DisplayName = "P" .. nextId, Parent = true }
	end

	--------------------------------------------------------- default, unresolved
	do
		local player = join()
		assert(policy.isReady(player) == false, "a player never checked is not ready")
		assert(policy.paidRandomAllowed(player) == false, "stays off before resolution")
		assert(policy.paidTradingAllowed(player) == false, "stays off before resolution")
	end

	--------------------------------------------------------- success on the first try
	do
		local player = join()
		queues[player] = {
			{ ok = true, info = { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true } },
		}
		assert(policy.isReady(player) == false)
		profileLoaded(player)
		assert(policy.isReady(player) == true, "resolves after the callback runs")
		assert(policy.paidRandomAllowed(player) == true)
		assert(policy.paidTradingAllowed(player) == true)
		assert(calls[player] == 1, "a first-try success makes exactly one call")
		assert((changed[player] or 0) > 0, "DataService.markChanged fires once resolved")
	end

	--------------------------------------------------------- only an explicit allow turns it on
	do
		-- ArePaidRandomItemsRestricted missing, true, or non-boolean: all stay off.
		for _, restricted in { nil, true, "not a boolean" } do
			local player = join()
			queues[player] = {
				{ ok = true, info = { ArePaidRandomItemsRestricted = restricted, IsPaidItemTradingAllowed = true } },
			}
			profileLoaded(player)
			assert(policy.paidRandomAllowed(player) == false, "only an explicit false turns paid random items on")
		end
		-- IsPaidItemTradingAllowed missing, false, or non-boolean: all stay off.
		for _, allowed in { nil, false, "not a boolean" } do
			local player = join()
			queues[player] = {
				{ ok = true, info = { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = allowed } },
			}
			profileLoaded(player)
			assert(policy.paidTradingAllowed(player) == false, "only an explicit true turns trading on")
		end
	end

	--------------------------------------------------------- every attempt fails
	do
		local player = join()
		queues[player] = {}
		for _ = 1, Config.PolicyCheck.attempts do
			table.insert(queues[player], { ok = false })
		end
		profileLoaded(player)
		assert(calls[player] == Config.PolicyCheck.attempts, "retries exactly attempts times, then gives up")
		assert(policy.isReady(player) == true, "settles rather than leaving isReady stuck false forever")
		assert(policy.paidRandomAllowed(player) == false)
		assert(policy.paidTradingAllowed(player) == false)
	end

	--------------------------------------------------------- fails, then succeeds, then stops
	do
		local player = join()
		queues[player] = {
			{ ok = false },
			{ ok = true, info = { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true } },
		}
		profileLoaded(player)
		assert(calls[player] == 2, "stops retrying as soon as a later attempt succeeds")
		assert(policy.paidRandomAllowed(player) == true)
	end

	--------------------------------------------------------- the player leaves mid-retry
	do
		local player = join()
		queues[player] = { { ok = false, leaveAfter = true }, { ok = true, info = {} } }
		profileLoaded(player)
		assert(calls[player] == 1, "stops immediately once the player has left, without trying again")
		assert(policy.isReady(player) == false, "an unresolved check stays unresolved, not resolved to off")
	end

	print("policy-service: ok")
end
