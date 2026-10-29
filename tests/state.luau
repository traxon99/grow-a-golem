-- Sparse server packets must preserve the last slow-moving provider value.
do
	local handler
	local changed = 0
	local signal = {
		Connect = function(_, fn)
			handler = fn
		end,
	}
	local mockInstance = {
		new = function()
			return {
				Event = {
					Connect = function(_, fn)
						signal.listener = fn
					end,
				},
				Fire = function()
					changed += 1
				end,
			}
		end,
	}
	local mockGame = {
		GetService = function()
			return {
				WaitForChild = function()
					return {}
				end,
			}
		end,
	}
	local state = loadClientState({
		Remotes = { StateUpdate = { OnClientEvent = signal } },
		Stats = Stats,
	}, mockGame, mockInstance)
	state.start()
	assert(handler)
	handler({
		data = { minerals = { stone = 1 } },
		serverTime = os.time(),
		hub = { others = { { name = "Test" } } },
		leaderboards = { level = { { name = "Test", value = 1 } } },
	})
	local first = state.snapshot
	handler({ data = { minerals = { stone = 2 } }, serverTime = os.time() })
	assert(state.snapshot == first and state.snapshot.data.minerals.stone == 2)
	assert(state.snapshot.hub.others[1].name == "Test")
	assert(state.snapshot.leaderboards.level[1].value == 1)
	handler({ data = { minerals = { stone = 3 } }, serverTime = os.time(), hub = { others = {} } })
	assert(#state.snapshot.hub.others == 0 and changed == 3)
	print("PASS: sparse client state updates retain and replace provider values")
end
