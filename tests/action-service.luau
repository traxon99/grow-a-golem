-- Action dispatch (ActionService): registering a handler, routing a request
-- to it, catching handler errors, and the per-player rate limit. The check
-- script bundles the real Config above this file and loads the real
-- ActionService with its requires replaced by the mocks below and a
-- test-controlled os.clock.
--
-- onRequest is local, but .start() wires it to Remotes.Request.OnServerInvoke,
-- so the mock Request table below is just a plain mutable table whose field
-- the test reads after .start() and calls directly, the same way the real
-- RemoteFunction would.
do
	local removingHandlers = {}
	local clockNow = 0
	local request = {}

	local actions = loadActionService({
		Remotes = { Request = request },
	}, {
		GetService = function(_, name)
			if name == "Players" then
				return {
					PlayerRemoving = {
						Connect = function(_, fn)
							table.insert(removingHandlers, fn)
						end,
					},
				}
			end
			return {
				WaitForChild = function()
					return {}
				end,
			}
		end,
	}, function()
		return clockNow
	end)
	actions.start()
	local invoke = request.OnServerInvoke
	assert(invoke ~= nil, "start() wires Remotes.Request.OnServerInvoke")
	assert(#removingHandlers == 1, "ActionService connects one PlayerRemoving handler")

	local nextId = 0
	local function join()
		nextId += 1
		return { UserId = nextId, Name = "P" .. nextId }
	end

	--------------------------------------------------------------- register
	do
		local calls = {}
		actions.register("ping", function(player, extra)
			table.insert(calls, { player = player, extra = extra })
			return true, "pong"
		end)
		local player = join()
		local ok, message = invoke(player, "ping", "hi")
		assert(ok == true and message == "pong")
		assert(#calls == 1 and calls[1].player == player and calls[1].extra == "hi")
	end

	do
		local okDupe, err = pcall(function()
			actions.register("ping", function() end)
		end)
		assert(okDupe == false and string.find(err, "registered twice") ~= nil, "a name can only be registered once")
	end

	--------------------------------------------------------------- unknown actions
	do
		local player = join()
		local ok, message = invoke(player, "noSuchAction")
		assert(ok == false and message == "Unknown action")

		local okBadType, messageBadType = invoke(player, 5 :: any)
		assert(okBadType == false and messageBadType == "Unknown action", "a non-string action name is unknown too")
	end

	--------------------------------------------------------------- handler errors
	do
		actions.register("explode", function()
			error("boom")
		end)
		local player = join()
		local ok, message = invoke(player, "explode")
		assert(ok == false and message == "Something went wrong", "a handler error doesn't propagate")
	end

	--------------------------------------------------------------- rate limiting
	do
		actions.register("noop", function()
			return true, nil
		end)
		local player = join()
		for _ = 1, 8 do
			local ok = invoke(player, "noop")
			assert(ok == true, "the first 8 requests in a second all go through")
		end
		local okNinth, messageNinth = invoke(player, "noop")
		assert(okNinth == false, "the 9th request in the same second is throttled")
		assert(messageNinth == "Slow down a little!")

		-- A different player gets their own window.
		local other = join()
		local okOther = invoke(other, "noop")
		assert(okOther == true, "rate limiting is tracked per player")

		-- Once the window rolls over, the count resets.
		clockNow += 1
		local okAfter = invoke(player, "noop")
		assert(okAfter == true, "a new one-second window resets the count")
	end

	--------------------------------------------------------------- disconnect cleanup
	do
		actions.register("noop2", function()
			return true, nil
		end)
		local player = join()
		for _ = 1, 8 do
			invoke(player, "noop2")
		end
		local okThrottled = invoke(player, "noop2")
		assert(okThrottled == false, "the window is full before the disconnect")
		removingHandlers[1](player)
		local okAfterLeaving = invoke(player, "noop2")
		assert(okAfterLeaving == true, "disconnecting clears the player's rate-limit window")
	end

	print("action-service: ok")
end
