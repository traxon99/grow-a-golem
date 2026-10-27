# Safety and compliance (ages 9-15)

Last updated: 2026-10-27. **This doc overrides every other doc in this library.** If a top game does something this doc forbids, we do not do it.

## Rules for agents

These are non-negotiable for Grow A Golem. Some come straight from Roblox rules (cited below); others are our stricter house policy for a 9-15 audience (marked "house rule").

1. **Show real odds before any paid random item, including luck boosts.** Every outcome with a percentage, totals summing to 100% (rounding allowed with a note). A bare (i) icon is not enough. The 2x Luck product must state its effect as a number before purchase ([Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)).
2. **Odds update live while a boost is active.** When 2x Luck is on, the Artifacts menu and Shop must show the player's actual current odds, not the base odds ([Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)). One-time outcomes must update remaining odds for that user.
3. **Pity timers on random rewards** (house rule). Every random reward table has a guaranteed drop after N misses, and the pity count is visible to the player. Pity is itself a probability modifier, so explain it numerically wherever odds are shown.
4. **No fake or rigged near-misses** (house rule). Reveal animations never show a higher-rarity item "almost" landing. What the animation shows is what the server rolled.
5. **No paid random rewards for cosmetics** (house rule, backlog #14). Cosmetics and pets are sold by direct purchase only, at a fixed shown price.
6. **No countdown timers on purchases and no "today only" Robux offers** (house rule, based on regulator focus on time pressure; see below). Event timers for gameplay are fine; never put a purchase button next to one.
7. **No "only X Robux" or "just X Robux" wording**, and no copy that urges kids to buy or to ask parents ([Advertising Standards](https://en.help.roblox.com/hc/en-us/articles/13722260778260-Advertising-Standards)).
8. **Codes are always free** and never require following, liking, favoriting, joining off-platform channels, or buying anything (house rule).
9. **No rewards for likes or favorites** (house rule; Roblox wording not confirmed, see below). An unrewarded "Enjoying the game?" prompt is the most we do. Group-join rewards are acceptable per community consensus (unverified).
10. **Check PolicyService before showing paid random items or allowing trades.** Call `PolicyService:GetPolicyInfoForPlayerAsync()` on the server. If `ArePaidRandomItemsRestricted` is true, hide or block 2x Luck (or offer a deterministic alternative). If `IsPaidItemTradingAllowed` is false, block trading of paid items and outcomes ([Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)). Fail closed: if the call errors, treat both as restricted.
11. **Filter all player-entered text with TextService** on the server, on submit, and again when stored text is read back. Use the broadcast variant for text others see ([Text filtering](https://create.roblox.com/docs/ui/text-filtering.md)).
12. **No social media links in-experience** (Discord, X, YouTube, etc.) ([Roblox newsroom, Nov 2025](https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat)).
13. **Rewarded ads only for 13+, with fixed rewards.** Never a random artifact or luck roll as an ad reward ([Advertising Standards](https://en.help.roblox.com/hc/en-us/articles/13722260778260-Advertising-Standards)).
14. **Answer the maturity questionnaire honestly.** Expect Minimal or Mild for cartoon combat with no blood. Do not under-report to reach a wider audience ([Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)).

Testable checks: grep for `PolicyService` in server code before any shop/trade feature ships; every purchase button string contains the Robux price; no string in `src/` matches `only|just` next to `R$`/Robux; no `Countdown` UI parented to a shop frame.

## What Roblox and regulators require

### Paid random items and luck boosts
- Paid random items are random outcomes bought with Robux or with Robux-bought currency, including keys and tickets. Roblox's list includes prize wheels, eggs, chests, upgrade items with uncertain results, and **probability modifiers** ([Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)).
- Luck boosts, pity systems, enhanced drop rates and similar items must be explained numerically before purchase, and displayed odds must update to the user's actual odds while active (same source).
- Random rewards earned only through gameplay, with no Robux involved, do not legally require disclosure. We show them anyway (house rule).
- When `ArePaidRandomItemsRestricted` is true, the game must offer a free earnable path, a disclosed non-random order, a guaranteed direct purchase priced at expected value, or hide/block the item. Roblox publishes no country list; rely on the API per user (same source).
- Korean loot box rules pushed Roblox toward worldwide odds disclosure (reported June 2026) ([Tech Times](https://www.techtimes.com/articles/319148/20260626/koreas-loot-box-rules-push-roblox-disclose-item-odds-worldwide.htm)).
- `PolicyService` reference samples also show `IsEligibleToPurchaseCommerceProduct` ([PolicyService API](https://create.roblox.com/docs/reference/engine/classes/PolicyService)). Other fields such as `AreAdsAllowed` and `AllowedExternalLinkReferences` are from memory (unverified); check the API page before using them.

### Maturity labels and audience accounts
- Minimal: occasional mild violence. Mild: repeated mild violence and/or mild fear. Moderate: realistic-looking non-graphic violence ([Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)).
- Minimal and Mild reach Roblox Kids (5-8) and Roblox Select (9-15); Moderate reaches Select and 16+. Unrated games are not playable by anyone but their developers (same source).
- Kids/Select accounts launched globally June 16, 2026. Games with hangout or free-form drawing features are excluded ([Roblox newsroom, June 2026](https://about.roblox.com/newsroom/2026/06/age-based-roblox-kids-and-select-accounts-now-globally-available)).
- To reach Select: full questionnaire, ID-verified creator with 2FA, a refundable per-game fee or two months of Plus/Premium, then a trial visible only to age-checked 16+ users until 250 unique plays by highly engaged users within 60 days. Expedited review costs a refundable R$50,000 ([Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select)).
- Inference: constant auto-combat suggests **Mild** is the honest answer; Minimal is possible if hits stay very light.

### Ads, links, wording
- Ads aimed at under-18s may not urge kids to buy, use "only"/"just" price framing, imply special status, or be personalized. No free-Robux claims and no fake system UI ([Advertising Standards](https://en.help.roblox.com/hc/en-us/articles/13722260778260-Advertising-Standards)).
- Rewarded video: 13+ only; opt-in; disclosed, predetermined, immediate rewards; not a forced gate. No rewards to under-13s for any ad engagement. Portal-ad rewards banned since Oct 29, 2025 (same source).
- Since early 2026, creators may not post social media links inside experiences ([Roblox newsroom, Nov 2025](https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat)).
- Likes/favorites: only a DevForum thread with no staff answer; consensus says rewarding likes is not allowed and group perks are fine ([DevForum](https://devforum.roblox.com/t/is-rewarding-players-for-liking-favoriting-a-game-allowed/2926286)). Official wording unverified.
- Notifications may not use false time pressure or misleading free-reward offers ([Experience notifications](https://create.roblox.com/docs/production/promotion/experience-notifications.md)).
- Roblox monetization guidance says to avoid pushy or urgent language with minors ([Monetization](https://create.roblox.com/docs/en-us/production/monetization.md)).

### Text, chat, data
- Creators must filter any displayed text they do not control, using `TextService:FilterStringAsync`; games that skip it are removed until fixed ([Text filtering](https://create.roblox.com/docs/ui/text-filtering.md)).
- Chat needs an age check and is limited to similar age bands (under 9, 9-12, 13-15, 16-17, 18-20, 21+), enforced globally from early January 2026 ([Roblox newsroom, Nov 2025](https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat)).
- Right to be forgotten: Roblox sends daily RTBF inbox messages; creators must delete the user's personal data, using DataStore deletion templates or the Right to Erasure webhook ([RTBF and creators](https://create.roblox.com/docs/production/publishing/RTBF-and-creators.md); [Data store RTBF](https://create.roblox.com/docs/cloud-services/data-stores/right-to-be-forgotten)). Key player data by UserId so deletion is clean (inference).

### Outside regulation (context for house rules)
- FTC v. Epic (2023): $245M refunds plus $275M COPPA penalty; the FTC cited confusing button layouts that caused one-press charges ([FTC](https://www.ftc.gov/node/80648)). House rule: confirm step on every purchase, debounce taps.
- EU CPC principles (non-binding): show real-money prices, don't obscure cost, don't exploit children; the Star Stable action alleged time pressure ([Linklaters, Mar 2025](https://techinsights.linklaters.com/post/102k6t4/game-changer-eu-introduces-consumer-protection-guidance-for-in-game-virtual-curr)).
- Australia: since Sept 2024, paid loot boxes force at least an M rating ([Australian Classification](https://www.infrastructure.gov.au/department/media/news/new-mandatory-minimum-classifications-gambling-games-content)). Belgium treats paid loot boxes as gambling ([QMUL](https://qmul.ac.uk/law/news/2022/items/study-claims-country-wide-loot-box-ban-isnt-practically-achievable.html)).
- UK Children's Code bans nudge techniques with children ([Nelsons summary](https://www.nelsonslaw.co.uk/ico-guidance-to-game-developers/), secondary source).

## Grow A Golem today

- Artifact drops have published odds (0.6% per enemy, 30% per boss) and pity (300 enemy rolls, 4 boss rolls), shown in the Artifacts menu and Shop. Good baseline.
- **2x Luck 30 min (R$39) is a paid probability modifier.** It is covered by Roblox's rules. We have not confirmed that displayed odds update live while it is active.
- **No `PolicyService` usage found.** 2x Luck and any future trading are therefore not gated.
- Only player-entered text is redeem codes (not shown to others). No TextService filtering needed yet, but required before any naming feature.
- Codes are rate-limited. No social links in-game found.
- No ads. No subscriptions. Group join reward exists (group id not set).
- Server-authoritative: client only sends intents. Good for honest RNG.
- Analytics (#11) and Studio playtest (#9) not done; maturity questionnaire not yet answered.

## Gaps worth closing

1. **P0: Add server-side PolicyService check** and hide/block 2x Luck when `ArePaidRandomItemsRestricted`; fail closed. Required before monetization goes live.
2. **P0: Live odds while 2x Luck active.** Drive both the RNG and the odds UI from the same Config table so they cannot drift; show pity progress.
3. **P0 (#9): Playtest audit** of shop copy against rules 6-7 and of the reveal card against rule 4.
4. **P1 (#13): Gate trading** on `IsPaidItemTradingAllowed`; never trade paid outcomes for restricted users.
5. **P1 (#14): Cosmetics/pets direct purchase only.** No eggs or crates for Robux.
6. **P1 (#12): Codes** stay free, posted in-game and on the Roblox group page, never "follow us for codes".
7. **P1: Questionnaire and Select eligibility plan** (honest Mild/Minimal, 2FA/ID, seeding to 250 engaged plays).
8. **P2: RTBF readiness:** confirm DataStore keys are per UserId and leaderboards can drop a user.

## Sources

All accessed 2026-10.
- Roblox Creator Docs, Paid random items: https://create.roblox.com/docs/production/monetization/paid-random-items
- Roblox Creator Docs, PolicyService: https://create.roblox.com/docs/reference/engine/classes/PolicyService
- Roblox Creator Docs, Content maturity: https://create.roblox.com/docs/production/promotion/content-maturity
- Roblox Creator Docs, Kids and Select: https://create.roblox.com/docs/production/publishing/kids-and-select
- Roblox Creator Docs, Text filtering: https://create.roblox.com/docs/ui/text-filtering.md
- Roblox Creator Docs, Monetization: https://create.roblox.com/docs/en-us/production/monetization.md
- Roblox Creator Docs, Experience notifications: https://create.roblox.com/docs/production/promotion/experience-notifications.md
- Roblox Creator Docs, RTBF and creators: https://create.roblox.com/docs/production/publishing/RTBF-and-creators.md
- Roblox Creator Docs, Data store RTBF: https://create.roblox.com/docs/cloud-services/data-stores/right-to-be-forgotten
- Roblox Creator Docs, Automate right to erasure: https://create.roblox.com/docs/cloud/webhooks/automate-right-to-erasure
- Roblox Help, Advertising Standards: https://en.help.roblox.com/hc/en-us/articles/13722260778260-Advertising-Standards
- Roblox newsroom, age checks and chat (Nov 2025): https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat
- Roblox newsroom, Kids and Select accounts (June 2026): https://about.roblox.com/newsroom/2026/06/age-based-roblox-kids-and-select-accounts-now-globally-available
- Roblox newsroom, romantic/sexual content policy (Aug 2025): https://about.roblox.com/newsroom/2025/08/extending-roblox-policy-on-romantic-and-sexual-content
- DevForum, rewarding likes/favorites: https://devforum.roblox.com/t/is-rewarding-players-for-liking-favoriting-a-game-allowed/2926286
- Tech Times, Korea loot box rules (June 2026): https://www.techtimes.com/articles/319148/20260626/koreas-loot-box-rules-push-roblox-disclose-item-odds-worldwide.htm
- FTC, Epic settlement: https://www.ftc.gov/node/80648
- Linklaters, EU CPC virtual currency principles: https://techinsights.linklaters.com/post/102k6t4/game-changer-eu-introduces-consumer-protection-guidance-for-in-game-virtual-curr
- Lewis Silkin, EU action on in-game purchases: https://www.lewissilkin.com/insights/2025/03/26/eu-bodies-act-against-gaming-companies-to-protect-children-from-in-game-purchase-102k658
- Australian Classification, gambling content minimums: https://www.infrastructure.gov.au/department/media/news/new-mandatory-minimum-classifications-gambling-games-content
- QMUL, Belgium loot box ban study: https://qmul.ac.uk/law/news/2022/items/study-claims-country-wide-loot-box-ban-isnt-practically-achievable.html
- Bird & Bird, Netherlands ruling: https://www.twobirds.com/en/insights/2022/netherlands/fifa-22-loot-boxes-no-longer-regarded-as-gambling-in-the-netherlands-as-ban-overturned
- Nelsons, ICO guidance summary: https://www.nelsonslaw.co.uk/ico-guidance-to-game-developers/
