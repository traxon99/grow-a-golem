--!strict
-- Pure lease rules, shared with the offline regression suite. The lease lives
-- inside the same DataStore record as progress, so ownership checks are atomic.
local SessionLease = {}

function SessionLease.canAcquire(record: any, token: string, now: number): boolean
	local lease = type(record) == "table" and record._session
	return type(lease) ~= "table"
		or lease.token == token
		or (type(lease.expiresAt) == "number" and lease.expiresAt <= now)
end

function SessionLease.owns(record: any, token: string): boolean
	return type(record) == "table" and type(record._session) == "table" and record._session.token == token
end

function SessionLease.copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = SessionLease.copy(child)
	end
	return result
end

return SessionLease
