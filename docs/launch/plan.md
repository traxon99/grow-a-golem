# Launch test plan (#16)

Draft; no group created, spend committed, posts sent or ads launched.

## Before public traffic

1. Finish docs/playtest.md, including three-client, save and device checks.
2. Drain old servers before enabling the lease-aware release. Publish privately,
   run a complete save/rejoin check, then consider a public release.
3. Choose a Roblox group name and create it using the owner's account. Copy its
   numeric ID into Config.Group.id; verify the group reward once on a test save.
4. Upload the original sounds, grant experience permissions and set real IDs.
   Audit asset moderation and every sound in a published private place.
5. Review the original model kit and replace weak pieces in Studio. Capture
   actual gameplay using game-page.md; upload an icon, ≥3 thumbnails and the
   verified description. Fill in the maturity questionnaire honestly.
6. Check that analytics events appear in Creator Dashboard; do not run paid
   acquisition before acquisition and D1 retention can be compared.

## Right to erasure (RTBF) operations (#137)

The owner checks Roblox's right-to-erasure notifications **daily** and verifies
the affected experience and numeric UserId. Keep a private audit of the request,
the deletion date and the result; do not put the UserId or API key in GitHub.
See [Roblox's RTBF guidance](https://create.roblox.com/docs/production/publishing/RTBF-and-creators)
and [Open Cloud storage API](https://create.roblox.com/docs/cloud/reference/features/storage).

1. Publish the partner-ID-free trade code and **drain older servers** before
   processing a request. Do not delete while the affected user is online:
   an active session could write the profile or leaderboard key back.
2. In Creator Dashboard, copy the **Universe ID** (not the start Place ID).
   Create an Open Cloud key restricted to this universe with standard DataStore
   entry-delete and ordered DataStore entry-write/delete permissions. Store the
   key outside the repository as `ROBLOX_OPEN_CLOUD_API_KEY`.
3. From the repo root, review the dry run:
   `python3 scripts/rtbf.py USER_ID --universe-id UNIVERSE_ID`.
   Confirm it names `Config.Data.storeName` and every store in
   `Config.Leaderboards.boards`, all with the `global` scope.
4. Execute with explicit confirmation:
   `python3 scripts/rtbf.py USER_ID --universe-id UNIVERSE_ID --execute --confirm-user-id USER_ID`.
   The script removes `player_USER_ID` from the standard store and `USER_ID`
   from each ordered leaderboard. If a request fails, fix permissions or
   availability and rerun; do not mark the request complete on partial success.
5. Record the completion privately. Check any other stores introduced later and
   keep the script in sync with their key formats. Roblox can also configure
   DataStore RTBF deletion templates or a verified webhook for automation.

Trade logs and pending escrow created by the new build no longer store the
partner's UserId. Existing trade records are redacted and persisted when their
owners next load. **Important:** an inactive player's legacy save can still
contain a partner UserId until that player returns. For older data, arrange a
separate audited backfill/scrub of inactive saves before claiming historical
partner references have been fully erased; the targeted deletion script alone
does not scan other players' profiles. Do not claim end-to-end RTBF completion
until that check is satisfied.

## Small Sponsored ad experiment

Proposed maximum **US$50 total**, subject to the owner's explicit spend approval
and Roblox's actual minimums/credit conversion. This is a planning ceiling, not
a claim that the platform accepts a particular daily budget. If the minimum
exceeds the approved ceiling, pause; do not automatically increase spend.

Use the available broad Roblox targeting for the experience's eligible audience.
No personalised targeting of minors, off-platform tracking, collected child
identifiers or incentives for clicking ads. Keep one geographic/language setup
constant for the initial test rather than dividing a small sample across many
segments. Roblox's live ad controls and eligibility are authoritative.

- Compare two honest creatives (ride vs boss) with equal allocations where the
  dashboard permits. Test icons separately so attribution is interpretable.
- Run the paid test for up to three days; stop automatically/manually at the
  approved spend cap. Check for crashes, purchase errors and save errors daily.
- Record impressions, click-through rate, attributed visits, cost per qualified
  play where available, onboarding completion, median session length and D1
  retention for each supported campaign cohort. If Dashboard does not expose a
  cohort split, mark the field unavailable; do not infer causation.
- Provisional internal decision: stop for any confirmed save-loss incident or
  startup blocker. Iterate onboarding if fewer than half of new players finish
  the tutorial. Treat D1 <15% or median sessions <8 minutes as a reason to fix
  the game before scaling. These are chosen experiment thresholds, not sourced
  Roblox or competitor benchmarks.
- Do not declare a winner with fewer than 100 attributed joins per creative or
  until the D1 window has elapsed. If the cap prevents that sample, call the
  result inconclusive. A CTR gain alone does not establish better retention.
- Increase spend only after the owner reviews actual spend, error reports,
  retention and costs and approves a new ceiling.

## Community and update clips

Start with a free Roblox group update using the verified copy. Jackson chooses
any external channels later; do not create accounts or post on their behalf.
Keep off-platform links out of the experience. Codes stay available in-game and
on the Roblox group, free of following or buying requirements.

Suggested 15-second gameplay clip: 0–3s shoulder ride, 3–7s mine and forge,
7–12s dodge a real boss slam, 12–15s show growth. No voice-over or claims of
recorded gameplay over concept art. Ask consent before featuring other players.
Run the platform's icon experiment once sufficient real traffic exists; keep
the game version, description and ad setup fixed during the comparison.

## Completion evidence

Record published place/version, actual group ID, approved icon/thumbnail IDs,
all audio IDs and permissions, private-place test results, campaign budget and
owner approval, then actual campaign results. Until these exist, #16 remains
open. #15 also stays open until measured free pacing meets agreed targets;
#9 stays open until actual Studio and published-place checks pass.
