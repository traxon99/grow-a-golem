--!strict
-- Creates the remotes on the server and waits for them on the client.
-- Client -> server remotes carry intents only; the server validates everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"MoveGolem", -- client -> server: Vector3 steering direction
	"CastSpell", -- client -> server: spell id string
	"StateUpdate", -- server -> client: full state snapshot
	"Notify", -- server -> client: (kind, ...) one-off events
}

local FUNCTIONS = {
	"Request", -- client -> server: (action, ...) -> (ok, message)
}

local folder: Instance
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in EVENTS do
	Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
end
local Functions = {}
for _, name in FUNCTIONS do
	Functions[name] = folder:WaitForChild(name) :: RemoteFunction
end

return {
	MoveGolem = Remotes.MoveGolem,
	CastSpell = Remotes.CastSpell,
	StateUpdate = Remotes.StateUpdate,
	Notify = Remotes.Notify,
	Request = Functions.Request,
}
