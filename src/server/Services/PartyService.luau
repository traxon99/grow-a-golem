--!strict
-- Co-op parties of up to Config.Party.maxSize players. Party members near a
-- kill share its rewards, and every friend in your party adds a mineral bonus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)

type Party = { leader: Player, members: { Player } }

local PartyService = {}

local partyOf: { [Player]: Party } = {}
local invites: { [Player]: { [Player]: number } } = {} -- target -> inviter -> expiry (os.clock)
local inviteSentAt: { [Player]: { [Player]: number } } = {} -- inviter -> target -> last new invite
local friendCache: { [Player]: { [number]: boolean } } = {}
local friendCheckedAt: { [Player]: { [number]: number } } = {}
local friendPending: { [Player]: { [number]: boolean } } = {}
local FALSE_CACHE_SECONDS = 300 -- Retry negative answers so newly added friends count without rejoining.

local function refreshAll(party: Party?)
	if party then
		for _, member in party.members do
			DataService.markChanged(member)
		end
	end
end

-- Read the cache without yielding. Negative answers eventually expire so a
-- friendship made during this session can start earning its party bonus.
local function cachedFriend(a: Player, b: Player): boolean?
	local cache = friendCache[a]
	if not cache then
		return nil
	end
	local answer = cache[b.UserId]
	if answer == false then
		local checked = friendCheckedAt[a]
		if not checked or checked[b.UserId] == nil or os.clock() - checked[b.UserId] >= FALSE_CACHE_SECONDS then
			return nil
		end
	end
	return answer
end

local function isFriend(a: Player, b: Player): boolean
	local cached = cachedFriend(a, b)
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(function()
		return a:IsFriendsWithAsync(b.UserId)
	end)
	local answer = ok and result == true
	friendCache[a] = friendCache[a] or {}
	friendCache[a][b.UserId] = answer
	friendCheckedAt[a] = friendCheckedAt[a] or {}
	friendCheckedAt[a][b.UserId] = os.clock()
	return answer
end

-- Whether two players are Roblox friends (looked up once, then remembered).
function PartyService.areFriends(a: Player, b: Player): boolean
	return isFriend(a, b)
end

-- Never yield from a snapshot or reward calculation. Only one background
-- lookup per ordered pair may be outstanding, even if snapshots arrive often.
function PartyService.friendNow(a: Player, b: Player): boolean
	local cached = cachedFriend(a, b)
	if cached ~= nil then
		return cached
	end
	if not a.Parent or not b.Parent then
		return false
	end
	local pending = friendPending[a]
	if not pending then
		pending = {}
		friendPending[a] = pending
	end
	if not pending[b.UserId] then
		pending[b.UserId] = true
		task.spawn(function()
			isFriend(a, b)
			pending[b.UserId] = nil
			if a.Parent then
				DataService.markChanged(a)
			end
		end)
	end
	return false
end

-- Start friend lookups when a party forms or grows, not when the next reward
-- or state push needs the answer. Each result refreshes its owner's snapshot.
local function warmPartyFriends(party: Party)
	for _, member in party.members do
		for _, other in party.members do
			if other ~= member then
				PartyService.friendNow(member, other)
			end
		end
	end
end

function PartyService.sameParty(a: Player, b: Player): boolean
	return partyOf[a] ~= nil and partyOf[a] == partyOf[b]
end

function PartyService.members(player: Player): { Player }
	local party = partyOf[player]
	return if party then party.members else { player }
end

-- True if the player leads a party, or isn't in one (a party of one).
function PartyService.isLeader(player: Player): boolean
	local party = partyOf[player]
	return party == nil or party.leader == player
end

-- % mineral bonus from friends in the same party.
function PartyService.friendBonus(player: Player): number
	local bonus = 0
	for _, member in PartyService.members(player) do
		if member ~= player and PartyService.friendNow(player, member) then
			bonus += Config.Party.friendBonusPerFriend
		end
	end
	return math.min(bonus, Config.Party.maxFriendBonus)
end

-- Players who share a reward earned by `player` at `position`.
-- `isNear(member)` lets the caller decide what "near" means (same zone, in range).
function PartyService.shareWith(player: Player, isNear: (Player) -> boolean): { Player }
	local result = { player }
	for _, member in PartyService.members(player) do
		if member ~= player and isNear(member) then
			table.insert(result, member)
		end
	end
	return result
end

local function leave(player: Player)
	local party = partyOf[player]
	if not party then
		return
	end
	partyOf[player] = nil
	local index = table.find(party.members, player)
	if index then
		table.remove(party.members, index)
	end
	if #party.members <= 1 then
		for _, member in party.members do
			partyOf[member] = nil
		end
	elseif party.leader == player then
		party.leader = party.members[1]
	end
	refreshAll(party)
	DataService.markChanged(player)
	for _, member in party.members do
		Remotes.Notify:FireClient(member, "message", `{player.DisplayName} left the party.`)
	end
end

local function snapshot(player: Player): any
	local party = partyOf[player]
	local members = {}
	for _, member in PartyService.members(player) do
		table.insert(members, {
			userId = member.UserId,
			name = member.DisplayName,
			leader = party ~= nil and party.leader == member,
			friend = member ~= player and PartyService.friendNow(player, member),
		})
	end
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(others, { userId = other.UserId, name = other.DisplayName, inParty = partyOf[other] ~= nil })
		end
	end
	local pending = {}
	local now = os.clock()
	for inviter, expiry in invites[player] or ({} :: any) do
		if expiry > now and inviter.Parent then
			table.insert(pending, { userId = inviter.UserId, name = inviter.DisplayName })
		end
	end
	return {
		members = members,
		inParty = party ~= nil,
		friendBonus = PartyService.friendBonus(player),
		others = others,
		invites = pending,
	}
end

function PartyService.start()
	DataService.addProvider("party", snapshot)

	ActionService.register("partyInvite", function(player, userId)
		if type(userId) ~= "number" then
			return false, "Pick a player"
		end
		local target = Players:GetPlayerByUserId(userId)
		if not target or target == player then
			return false, "That player isn't here"
		end
		if partyOf[target] then
			return false, `{target.DisplayName} is already in a party`
		end
		if #PartyService.members(player) >= Config.Party.maxSize then
			return false, "Your party is full"
		end
		local data = DataService.get(target)
		if not data then
			return false, "That player isn't ready"
		end
		local mode = data.social and data.social.partyInvites or "friends"
		if mode == "off" then
			return false, "That player has party invites off"
		end
		if mode ~= "everyone" and not PartyService.areFriends(target, player) then
			return false, "That player accepts friends' invites only."
		end

		local now = os.clock()
		invites[target] = invites[target] or {}
		if (invites[target][player] or 0) > now then
			-- Refresh the existing invite silently: never send a second toast.
			invites[target][player] = now + Config.Party.inviteTimeout
			return true, `Already invited {target.DisplayName}.`
		end
		local lastSent = inviteSentAt[player] and inviteSentAt[player][target]
		if lastSent and now - lastSent < Config.Party.inviteCooldown then
			return false, "Wait before inviting that player again"
		end
		local open = 0
		for other, pending in invites do
			if other.Parent and (pending[player] or 0) > now then
				open += 1
			end
		end
		if open >= Config.Party.maxOutgoingInvites then
			return false, "Too many open party invites"
		end
		inviteSentAt[player] = inviteSentAt[player] or {}
		inviteSentAt[player][target] = now
		invites[target][player] = now + Config.Party.inviteTimeout
		Remotes.Notify:FireClient(target, "message", `{player.DisplayName} invited you!\nOpen Party to join.`)
		DataService.markChanged(target)
		return true, `Invite sent to {target.DisplayName}`
	end)

	ActionService.register("partyAccept", function(player, userId)
		local inviter = type(userId) == "number" and Players:GetPlayerByUserId(userId)
		local pending = invites[player]
		if not inviter or not pending or (pending[inviter] or 0) < os.clock() then
			return false, "That invite expired"
		end
		local party = partyOf[inviter]
		-- Check capacity before leaving the player's current party.
		if party and #party.members >= Config.Party.maxSize then
			return false, "That party is full"
		end
		pending[inviter] = nil
		if partyOf[player] then
			leave(player)
		end
		local destination: Party
		if party then
			destination = party
		else
			destination = { leader = inviter, members = { inviter } }
			partyOf[inviter] = destination
		end
		table.insert(destination.members, player)
		partyOf[player] = destination
		warmPartyFriends(destination)
		refreshAll(destination)
		for _, member in destination.members do
			Remotes.Notify:FireClient(member, "message", `{player.DisplayName} joined the party!`)
		end
		Events.fire("partyJoined", player, #destination.members)
		return true, nil
	end)

	ActionService.register("setPartyInvites", function(player, mode)
		if mode ~= "everyone" and mode ~= "friends" and mode ~= "off" then
			return false, "Choose an invite setting"
		end
		if not DataService.get(player) then
			return false, "Not ready"
		end
		DataService.update(player, function(data)
			data.social.partyInvites = mode
		end)
		return true, "Party invite setting saved."
	end)

	ActionService.register("partyDecline", function(player, userId)
		local inviter = type(userId) == "number" and Players:GetPlayerByUserId(userId)
		if inviter and invites[player] then
			invites[player][inviter] = nil
		end
		DataService.markChanged(player)
		return true, nil
	end)

	ActionService.register("partyLeave", function(player)
		leave(player)
		return true, "You left the party"
	end)

	Players.PlayerAdded:Connect(function()
		-- Refresh everyone's invite list.
		for _, other in Players:GetPlayers() do
			DataService.markChanged(other)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		invites[player] = nil
		inviteSentAt[player] = nil
		for _, sent in inviteSentAt do
			sent[player] = nil
		end
		friendCache[player] = nil
		friendCheckedAt[player] = nil
		friendPending[player] = nil
		for _, pending in invites do
			pending[player] = nil
		end
		for _, other in Players:GetPlayers() do
			if other ~= player then
				DataService.markChanged(other)
			end
		end
	end)
end

return PartyService
