--!strict
-- Holds the latest state snapshot from the server and wraps menu requests.
-- UI code reads from here and re-renders when `Changed` fires.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(Shared:WaitForChild("Stats"))

local State = {}

State.snapshot = nil :: any
-- Difference between server and client clocks, so timers line up.
State.clockOffset = 0

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

local toastHandler: ((string) -> ())? = nil

function State.setToastHandler(handler: (string) -> ())
	toastHandler = handler
end

function State.toast(text: string)
	if toastHandler then
		toastHandler(text)
	end
end

function State.serverNow(): number
	return os.time() + State.clockOffset
end

function State.context(): Stats.Context
	local snap = State.snapshot
	return { passes = if snap and snap.passes then snap.passes else {}, now = State.serverNow() }
end

function State.stats(): Stats.GolemStats?
	local snap = State.snapshot
	if not snap then
		return nil
	end
	return Stats.compute(snap.data, State.context())
end

-- Sends a menu action to the server and shows its message.
function State.request(action: string, ...: any): boolean
	local ok, success, message = pcall(function(...)
		return Remotes.Request:InvokeServer(action, ...)
	end, ...)
	if not ok then
		State.toast("Couldn't reach the server, try again")
		return false
	end
	if message then
		State.toast(message)
	end
	return success == true
end

function State.start()
	Remotes.StateUpdate.OnClientEvent:Connect(function(snapshot)
		-- Slow-moving providers are sparse: retain the last value when a
		-- packet omits that field. Data and timestamps arrive every packet.
		if State.snapshot then
			for key, value in snapshot do
				State.snapshot[key] = value
			end
		else
			State.snapshot = snapshot
		end
		State.clockOffset = snapshot.serverTime - os.time()
		changed:Fire()
	end)
end

return State
