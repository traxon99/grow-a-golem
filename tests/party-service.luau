-- Party membership (PartyService): the invite/accept/decline/leave action
-- handlers, the per-friend mineral bonus, and the friend-lookup cache. The
-- check script bundles the real Config above this file and loads the real
-- PartyService with its requires replaced by the mocks below, plus a
-- test-controlled os.clock and a mocked Players service players register
-- themselves with.
--
-- Out of scope here: the real IsFriendsWithAsync Roblox API itself (mocked
-- below as a plain function on each player table).
do
	local handlers = {}
	local fired = {}
	local notified = {}
	local changed = {}
	local providers = {}

	local clockNow = 0
	local playersList = {}
	local addedHandlers = {}
	local removingHandlers = {}
	local friendsOf = {} -- player -> set of userIds it's friends with
	local friendCalls = {}

	local function makeFriends(a, b)
		friendsOf[a] = friendsOf[a] or {}
		friendsOf[a][b.UserId] = true
		friendsOf[b] = friendsOf[b] or {}
		friendsOf[b][a.UserId] = true
	end

	local nextId = 0
	local function join()
		nextId += 1
		local player = {
			UserId = nextId,
			DisplayName = "P" .. nextId,
			Parent = {}, -- truthy: "still in the game" for friendNow's early-out
		}
		player.IsFriendsWithAsync = function(self, otherUserId)
			table.insert(friendCalls, { who = self, otherUserId = otherUserId })
			return (friendsOf[self] or {})[otherUserId] == true
		end
		table.insert(playersList, player)
		return player
	end

	local party = loadPartyService({
		Config = Config,
		Remotes = {
			Notify = {
				FireClient = function(_, player, kind, msg)
					table.insert(notified, { player = player, kind = kind, msg = msg })
				end,
			},
		},
		ActionService = {
			register = function(name, fn)
				handlers[name] = fn
			end,
		},
		DataService = {
			markChanged = function(player)
				table.insert(changed, player)
			end,
			addProvider = function(name, fn)
				providers[name] = fn
			end,
		},
		Events = {
			fire = function(name, player, arg)
				table.insert(fired, { name = name, player = player, arg = arg })
			end,
		},
	}, {
		GetService = function(_, name)
			if name == "Players" then
				return {
					GetPlayerByUserId = function(_, userId)
						for _, p in playersList do
							if p.UserId == userId then
								return p
							end
						end
						return nil
					end,
					GetPlayers = function()
						return playersList
					end,
					PlayerAdded = {
						Connect = function(_, fn)
							table.insert(addedHandlers, fn)
						end,
					},
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
	}, {
		-- friendNow's background lookup runs synchronously in this test, so
		-- its cache-fill effect is visible right after the call returns.
		spawn = function(fn, ...)
			fn(...)
		end,
	}, function()
		return clockNow
	end)
	party.start()
	local invite = handlers.partyInvite
	local accept = handlers.partyAccept
	local decline = handlers.partyDecline
	local leave = handlers.partyLeave
	assert(invite and accept and decline and leave, "all four party actions are registered")

	---------------------------------------------------------------- building a party
	local p1, p2, p3, p4 = join(), join(), join(), join()
	do
		local ok, msg = invite(p1, p2.UserId)
		assert(ok == true and msg == "Invite sent to P2")
		assert(notified[#notified].player == p2 and notified[#notified].kind == "message")
		local okAccept = accept(p2, p1.UserId)
		assert(okAccept == true)
		assert(fired[#fired].name == "partyJoined" and fired[#fired].player == p2 and fired[#fired].arg == 2)
	end
	assert(invite(p1, p3.UserId) == true and accept(p3, p1.UserId) == true)
	assert(invite(p1, p4.UserId) == true and accept(p4, p1.UserId) == true)
	assert(#party.members(p1) == 4, "all four joined the same party")
	assert(party.sameParty(p1, p4) == true)
	assert(party.isLeader(p1) == true and party.isLeader(p2) == false)

	---------------------------------------------------------------- invite refusals
	do
		local okNotNumber = invite(p1, "nope" :: any)
		assert(okNotNumber == false, "a non-number id is refused")

		local okSelf, msgSelf = invite(p1, p1.UserId)
		assert(okSelf == false and msgSelf == "That player isn't here")

		local okTaken, msgTaken = invite(p1, p2.UserId)
		assert(okTaken == false and string.find(msgTaken, "already in a party") ~= nil)

		local p5 = join()
		local okFull, msgFull = invite(p1, p5.UserId)
		assert(okFull == false and msgFull == "Your party is full", "the party is already at Config.Party.maxSize")
	end

	---------------------------------------------------------------- friendBonus
	-- isFriend's cache locks in a pair's answer on its first lookup and never
	-- re-queries it (the real source only clears a player's slot on
	-- PlayerRemoving), so each case below uses its own fresh players and
	-- calls makeFriends before anything -- friendBonus, areFriends, or
	-- friendNow -- ever looks that pair up; flipping friendsOf afterwards
	-- wouldn't be seen.
	do
		local solo = join()
		assert(party.friendBonus(solo) == 0, "a party of one has no one to be friends with")
	end

	do
		local leader, m2, m3, m4 = join(), join(), join(), join()
		invite(leader, m2.UserId)
		accept(m2, leader.UserId)
		invite(leader, m3.UserId)
		accept(m3, leader.UserId)
		invite(leader, m4.UserId)
		accept(m4, leader.UserId)
		assert(party.friendBonus(leader) == 0, "no friends yet: no bonus")
	end

	do
		local leader, friend, m2, m3 = join(), join(), join(), join()
		makeFriends(leader, friend)
		invite(leader, friend.UserId)
		accept(friend, leader.UserId)
		invite(leader, m2.UserId)
		accept(m2, leader.UserId)
		invite(leader, m3.UserId)
		accept(m3, leader.UserId)
		assert(party.friendBonus(leader) == Config.Party.friendBonusPerFriend, "one friend: one increment")
	end

	do
		local leader, f1, f2, f3 = join(), join(), join(), join()
		makeFriends(leader, f1)
		makeFriends(leader, f2)
		makeFriends(leader, f3)
		invite(leader, f1.UserId)
		accept(f1, leader.UserId)
		invite(leader, f2.UserId)
		accept(f2, leader.UserId)
		invite(leader, f3.UserId)
		accept(f3, leader.UserId)
		assert(
			party.friendBonus(leader) == 3 * Config.Party.friendBonusPerFriend,
			"three friends in a full party of four"
		)

		-- Temporarily lower the cap to prove the clamp actually engages (with
		-- the real Config, three friends at 10 each lands exactly on the real
		-- cap of 30 without ever needing to clamp).
		local savedCap = Config.Party.maxFriendBonus
		Config.Party.maxFriendBonus = 15
		assert(party.friendBonus(leader) == 15, "the bonus clamps to the cap even when friends would earn more")
		Config.Party.maxFriendBonus = savedCap
	end

	---------------------------------------------------------------- areFriends caching
	do
		local a, b = join(), join()
		local before = #friendCalls
		local answer = party.areFriends(a, b)
		assert(answer == false and #friendCalls == before + 1, "the first lookup calls the API")
		local againBefore = #friendCalls
		assert(party.areFriends(a, b) == answer, "a cached lookup still gives the same answer")
		assert(#friendCalls == againBefore, "a cached lookup doesn't call it again")
	end

	---------------------------------------------------------------- friendNow
	do
		local stranger1, stranger2 = join(), join()
		makeFriends(stranger1, stranger2)
		local changedBefore = #changed
		assert(party.friendNow(stranger1, stranger2) == false, "an uncached pair reads as not-friends at first")
		assert(#changed > changedBefore and changed[#changed] == stranger1, "the background fill marks it changed")
		assert(party.friendNow(stranger1, stranger2) == true, "now cached, the real answer comes back")
	end

	---------------------------------------------------------------- invite expiry
	-- Left advanced afterwards, on purpose: os.clock() only moves forward in
	-- real play, and a cleared invite slot (nil, read back as 0 by `pending[
	-- inviter] or 0`) must compare against a clock that's actually past 0 to
	-- read as expired, the same as it would after the server's been up a
	-- while.
	do
		local inviter, target = join(), join()
		invite(inviter, target.UserId)
		clockNow += Config.Party.inviteTimeout + 1
		local ok, msg = accept(target, inviter.UserId)
		assert(ok == false and msg == "That invite expired")
	end

	do
		local target = join()
		local ok, msg = accept(target, 999999 :: any)
		assert(ok == false and msg == "That invite expired", "no pending invite reads the same as an expired one")
	end

	---------------------------------------------------------------- party full at accept time
	do
		-- The maxSize check on invite only sees the party as it is *then*; a
		-- party can still fill up between an invite going out and it being
		-- accepted, which is what the second accept() below has to catch.
		local leader, m2, m3, lateJoiner, tooLate = join(), join(), join(), join(), join()
		invite(leader, m2.UserId)
		accept(m2, leader.UserId)
		invite(leader, m3.UserId)
		accept(m3, leader.UserId)
		invite(leader, lateJoiner.UserId) -- sent while the party has 3 of 4 seats
		invite(leader, tooLate.UserId) -- sent at the same moment, same seat count
		accept(lateJoiner, leader.UserId) -- takes the last seat
		local ok, msg = accept(tooLate, leader.UserId)
		assert(ok == false and msg == "That party is full", "the party filled up between invite and accept")
	end

	---------------------------------------------------------------- partyDecline
	do
		local inviter, target = join(), join()
		invite(inviter, target.UserId)
		local changedBefore = #changed
		assert(decline(target, inviter.UserId) == true)
		assert(#changed > changedBefore and changed[#changed] == target)
		local okAccept, msgAccept = accept(target, inviter.UserId)
		assert(okAccept == false and msgAccept == "That invite expired", "a declined invite is simply gone")
	end

	---------------------------------------------------------------- leave: leadership passes on
	do
		local leader, m2, m3 = join(), join(), join()
		invite(leader, m2.UserId)
		accept(m2, leader.UserId)
		invite(leader, m3.UserId)
		accept(m3, leader.UserId)
		assert(party.isLeader(leader) == true)
		leave(leader)
		assert(party.sameParty(leader, m2) == false, "the old leader is out of the party")
		assert(party.isLeader(m2) == true, "leadership passes to the next member")
		assert(#party.members(m2) == 2)
	end

	---------------------------------------------------------------- leave: dissolves at one member
	do
		local a, b = join(), join()
		invite(a, b.UserId)
		accept(b, a.UserId)
		leave(b)
		assert(party.sameParty(a, b) == false)
		assert(#party.members(a) == 1 and party.isLeader(a) == true, "a lone remaining member's party dissolves")
	end

	---------------------------------------------------------------- switching parties
	do
		local leaderA, leaderB, switcher = join(), join(), join()
		invite(leaderA, switcher.UserId)
		accept(switcher, leaderA.UserId)
		assert(party.sameParty(leaderA, switcher) == true)
		invite(leaderB, switcher.UserId)
		accept(switcher, leaderB.UserId)
		assert(party.sameParty(leaderA, switcher) == false, "accepting a new invite leaves the old party first")
		assert(party.sameParty(leaderB, switcher) == true)
	end

	---------------------------------------------------------------- shareWith
	do
		local leader, near, far = join(), join(), join()
		invite(leader, near.UserId)
		accept(near, leader.UserId)
		invite(leader, far.UserId)
		accept(far, leader.UserId)
		local sharers = party.shareWith(leader, function(member)
			return member == near
		end)
		assert(#sharers == 2 and sharers[1] == leader and table.find(sharers, near) ~= nil)
		assert(table.find(sharers, far) == nil, "isNear decides who else shares the reward")
	end

	---------------------------------------------------------------- snapshot
	do
		assert(providers.party ~= nil, "PartyService registers a DataService provider")
		local leader, member = join(), join()
		invite(leader, member.UserId)
		accept(member, leader.UserId)
		makeFriends(leader, member)
		local snap = providers.party(leader)
		assert(snap.inParty == true and #snap.members == 2)
		assert(snap.friendBonus == Config.Party.friendBonusPerFriend)
		local foundMember = false
		for _, m in snap.members do
			if m.userId == member.UserId then
				foundMember = true
				assert(m.friend == true)
			end
		end
		assert(foundMember, "the other member shows up in the snapshot")
	end

	---------------------------------------------------------------- disconnect cleanup
	do
		assert(#removingHandlers == 1, "PartyService connects exactly one PlayerRemoving handler")
		local leader, member = join(), join()
		invite(leader, member.UserId)
		accept(member, leader.UserId)
		local stranger = join()
		invite(stranger, leader.UserId) -- a pending invite the leaving player holds
		removingHandlers[1](leader)
		assert(party.sameParty(leader, member) == false, "the party is cleaned up when a member disconnects")
		assert(party.isLeader(member) == true)
		local ok = accept(leader, stranger.UserId)
		assert(ok == false, "a disconnected player's own pending invites are cleared too")
	end

	print("party-service: ok")
end
