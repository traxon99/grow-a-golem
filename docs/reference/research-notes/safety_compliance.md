# Roblox Safety & Compliance for 9-15 Audiences (2025-2026)

Context: idle auto-battler with random artifact drops, paid 2x luck boost, codes, events. Research date: 2026-10-27. Several create.roblox.com pages (monetization-policies, the right-to-erasure data store page) and the en.help Experience Guidelines article failed to fetch. Where that happened I used sibling pages or flagged the gap.

## 1. Paid random items (loot boxes), odds disclosure, PolicyService, and whether a paid luck boost counts

### Takeaway
Roblox treats anything random that is bought with Robux, or with currency bought with Robux, as a paid random item, and that includes "probability modifiers" like luck potions. A paid 2x luck boost is explicitly covered. Its effect must be stated as a number before purchase, and while it is active the displayed odds must update to show the player's real odds. Players flagged by `PolicyService` (`ArePaidRandomItemsRestricted`) must get a non-random alternative or be kept out of the mechanic.

### Cited Findings
- Paid random items are items with random outcomes bought with Robux or with Robux-purchased in-game currency, including indirect purchases (keys, spin tickets). Roblox's examples include prize wheels, egg hatching, chests, enhancement/upgrade items with uncertain results, combination items, and **probability modifiers**. — [Roblox Creator Hub: Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
- Under the Terms of Use and Community Standards, every possible outcome and its numerical odds must be shown **before purchase**, as percentages that add up to 100%. Rounding is allowed with a disclaimer. If the list is too long for the main view, an itemized "Info"/"Details" pop-up is acceptable, but a bare (i) icon is not enough. If an outcome can only be won once, the remaining odds must update for that user. — [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
- Randomized rewards earned purely through gameplay, with no Robux or Robux-bought currency involved, do **not** require odds disclosure. — [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
- **Luck boosts:** items that improve the odds of other random outcomes (luck boosts, pity systems, enhanced resource drops, rate-up scrolls, "lucky potion", "magic fishing rod") must be explained before purchase, with the effect stated numerically. While the boost is active, the odds shown must update dynamically to the user's actual odds. — [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
- `PolicyService:GetPolicyInfoForPlayerAsync()` returns `ArePaidRandomItemsRestricted`. If it is true, the player can't use paid random item generators. Creators must then do one of the following:
  - offer a free, earnable path;
  - use a predetermined, disclosed, non-random order;
  - offer a guaranteed direct purchase priced at expected value;
  - or hide/remove the item, block the purchase with an error, or move the user out of those areas.
  — [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
- `IsPaidItemTradingAllowed`: if false, creators must not let the user trade paid random item outcomes or other paid items. — [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
- The PolicyService API reference code samples also show `IsEligibleToPurchaseCommerceProduct`. The reference page does not document the full return dictionary. — [PolicyService API reference](https://create.roblox.com/docs/reference/engine/classes/PolicyService)
- Roblox does not publish a country list. It says rules vary by country and that per-user restrictions come from the API. — [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
- Rewarded video rewards must be predetermined. Random items and chance-based mechanics are not allowed as ad rewards. — [Roblox Advertising Standards](https://en.help.roblox.com/hc/en-us/articles/13722260778260-Advertising-Standards)

### Inferences
- **Artifact drops.** If drops come only from idle play, odds disclosure isn't required by Roblox (it's still good practice). Once the 2x luck boost is sold for Robux, those drops become paid-random-adjacent. At that point the game needs:
  - a numeric "2x" explanation, ideally with a before/after odds table;
  - live updating of the displayed odds while the boost is active;
  - PolicyService gating for restricted users. Safest options: hide the boost for them, or sell a deterministic alternative.
- **Inspectable odds.** Keep the drop table data-driven, so the same table drives both the RNG and the UI odds display. This avoids drift between what is shown and what actually happens.
- **Trading.** If artifacts become tradable, check `IsPaidItemTradingAllowed` before allowing trades of boosted or paid outcomes.
- **Rewarded ads.** Never use a rewarded ad to grant a random artifact or a luck boost tied to RNG.

### Gaps
- The complete field list for `GetPolicyInfoForPlayerAsync` could not be confirmed this session. From memory (unverified), it also includes `AllowedExternalLinkReferences`, `IsContentSharingAllowed`, `IsSubjectToChinaPolicies`, `AreAdsAllowed` and `IsEligibleToPurchaseSubscription`. Verify on the API reference before relying on any of these.
- No official Roblox list of countries where `ArePaidRandomItemsRestricted` returns true.

## 2. Content Maturity Labels, questionnaire, the likely rating for an idle combat game, and 2024-2026 platform changes

### Takeaway
Since mid-2026 the main audience framework is age-based accounts: Roblox Kids (5-8), Roblox Select (9-15) and standard Roblox (16+). To reach 9-15 players, a game needs:
- a Minimal, Mild or Moderate label from the **full** Maturity & Compliance Questionnaire;
- an ID-verified creator with 2FA;
- a subscription or a refundable publishing fee;
- a pass through Roblox's engagement and safety evaluation.

Unrated games are no longer playable by anyone except their developers. A cartoon idle combat game should land at Minimal or Mild.

### Cited Findings
- **Label criteria:**
  - Minimal: occasional mild violence and/or light unrealistic blood.
  - Mild: repeated mild violence, heavy unrealistic blood, and/or mild fear.
  - Moderate: moderate non-graphic, realistic-looking violence, light realistic blood, and/or moderate fear.
  - Restricted: strong or graphic violence, heavy realistic blood, romance, alcohol, strong language.

  — [Creator Hub: Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)
- **Who can see each label:**
  - Minimal and Mild: Roblox Kids (5-8) and Roblox Select (9-15), subject to additional publishing requirements.
  - Moderate: Select and 16+.
  - "Content May Vary": age-checked 16+ users only.
  - Restricted: ID-verified 18+ users only, and servers remove players who aren't verified.

  — [Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)
- Games without maturity information "are restricted from playability on the platform for all players". Creators targeting Kids or Select, or regions with specific content policies, must complete the full questionnaire. Inaccurate answers can lead to moderation. — [Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)
- **Change history:** On Aug 15, 2025, Roblox announced that unrated experiences, which had been limited to 13+, would be restricted to their developers "in the coming months". It also limited social hangouts depicting private spaces, and adult settings, to ID-verified 17+ users. — [Roblox newsroom, Aug 2025](https://about.roblox.com/newsroom/2025/08/extending-roblox-policy-on-romantic-and-sexual-content)
- **Kids / Select requirements:**
  - Kids games must be Minimal or Mild; Select games can be Minimal, Mild or Moderate.
  - The creator account must be in good standing, verified by facial age estimation (under 18) or government ID (18+), and have 2FA.
  - The creator needs either a one-time refundable per-game fee or two consecutive months of Roblox Plus/Premium.
  - Optional expedited review costs a refundable 50,000 Robux.

  — [Creator Hub: Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select)
- **Evaluation pipeline for Kids / Select:**
  1. Trial: the game is visible to age-checked 16+ users only.
  2. Hourly engagement analysis (account age, play history, spend).
  3. Safety review of moderation reports and gameplay.
  4. Threshold: 250 unique plays by "highly engaged" age-checked users within 60 days.

  Progress shows on the Audience Reach dashboard. Parents can manually allow specific games through the "Approved Experience" control. — [Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select)
- Kids and Select accounts launched globally on **June 16, 2026**, after earlier rollouts in Australia, Indonesia, the Netherlands and New Zealand.
  - Users without an age check are placed by self-declared age and cannot chat.
  - Games with social hangout or free-form drawing features, or sensitive issues, are excluded from these accounts.
  - Social media links are viewable only by age-checked 16+ users.
  - Parents of under-13s can set spend limits.

  — [Roblox newsroom, June 2026](https://about.roblox.com/newsroom/2026/06/age-based-roblox-kids-and-select-accounts-now-globally-available)
- **Age checks for chat:**
  - Facial age estimation (vendor Persona; images deleted after processing) or ID for 13+ is required to use chat.
  - Voluntary checks started Nov 19, 2025. Enforcement began in the first week of December 2025 in AU/NZ/NL and worldwide in early January 2026.
  - Users fall into six age bands (under 9, 9-12, 13-15, 16-17, 18-20, 21+) and can chat only with similar bands.
  - Experience chat is off by default for under-9s without parental consent.

  — [Roblox newsroom, Nov 2025](https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat)

### Inferences
- **Expected rating.** A stylized idle auto-battler with no blood and cartoon hits should answer the questionnaire as Minimal ("occasional mild violence") or Mild ("repeated mild violence"). Constant combat suggests Mild is the honest answer. Either label is eligible for Select (9-15) and Kids (5-8).
- **Launch timeline.** The game will first be visible only to age-checked 16+ users until it passes the 250-engaged-player threshold. A target audience of 9-15 therefore needs a seeding plan, or the expedited review.
- **Feature scope.** Avoid free-form drawing or "hangout" features; they would exclude the game from Kids/Select.

### Gaps
- The help-center Experience Guidelines article failed to load, so I could not confirm the exact questionnaire wording or whether it contains a monetization/paid-random-items question.
- The date when unrated experiences were fully locked to developers is not stated. The Creator Hub page now treats it as in effect.

## 3. Community Standards and Terms on monetization: required purchases, misleading ads, off-platform and social links, rewards for likes/favorites/follows, codes

### Takeaway
The official sources I could confirm cover advertising and social links:
- No "free Robux" claims.
- No fake system UI.
- No urging kids to buy, and no "only/just" price framing aimed at under-18s.
- No rewards to under-13s for engaging with ads.
- Since early 2026, no social media links inside experiences, and social links are visible only to age-checked 16+ users.

I could not confirm an official rule on rewarding likes or favorites. Community opinion treats rewarding likes as disallowed and group joins as acceptable.

### Cited Findings
- **Ads aimed at under-18s may not:**
  - directly urge children to buy, or to ask their parents to buy;
  - describe a price with "only" or "just";
  - imply that a product grants special skills or status;
  - be personalized.

  — [Roblox Advertising Standards](https://en.help.roblox.com/hc/en-us/articles/13722260778260-Advertising-Standards)
- **Ads may not:**
  - make deceptive claims, including free Robux;
  - mimic system features such as buttons or notifications that don't work;
  - hide ad disclosures;
  - include unapproved URLs, partial links or QR codes.

  Approved social link platforms are YouTube, Twitch, Facebook, Instagram, Snapchat, Discord and X. — [Advertising Standards](https://en.help.roblox.com/hc/en-us/articles/13722260778260-Advertising-Standards)
- From early 2026, creators may not share or post social media links in experiences (paid official ads are excepted). Age checks are required to see social links on profiles, communities and experience detail pages. — [Roblox newsroom, Nov 2025](https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat); confirmed in [June 2026 newsroom](https://about.roblox.com/newsroom/2026/06/age-based-roblox-kids-and-select-accounts-now-globally-available) (links viewable only by age-checked 16+ users)
- **Rewards for likes/favorites (community opinion only):** a DevForum thread with no staff answer. Its consensus is that rewarding likes is not allowed (it quotes a policy phrase about votes "in exchange for something (e.g., in exchange for a thumb up on your game)" without naming the document), group-join perks are acceptable, and favorites are a gray area. — [DevForum thread](https://devforum.roblox.com/t/is-rewarding-players-for-liking-favoriting-a-game-allowed/2926286)

### Inferences
- **Codes.** Release codes in-game (event banners, update logs) and on official Roblox community pages. Do not build "follow our X/TikTok for codes" flows into the game: in-experience social links are banned and social links are hidden from users under 16.
- **Likes and favorites.** Never gate rewards on likes or favorites. A neutral, unrewarded "Enjoying the game?" prompt is the low-risk choice.
- **Paywalls.** Avoid paywalling core progression. For 9-15 players, treat purchases as optional convenience.

### Gaps
- The Creator Hub monetization-policies page failed to fetch, so I could not confirm the current official wording on required purchases, misleading item claims, or engagement incentives (likes, favorites, group joins).
- The Community Standards text on "vote manipulation" was not retrieved directly.

## 4. Text filtering, chat, data and privacy (COPPA, GDPR-K, UK Children's Code), right-to-erasure for DataStores

### Takeaway
Any player-entered text that other players see (pet or artifact names, signs) must go through `TextService` filtering on the server, after submission, and stored text should be filtered again when it is read back. Games that skip filtering are removed until it is fixed. Creators must act on Roblox's daily right-to-be-forgotten (RTBF) inbox messages, using DataStore deletion templates or the Right to Erasure webhook.

### Cited Findings
- **Who filters what.** Roblox filters in-game chat automatically. Creators must filter any other displayed text they don't control: TextBox and custom GUI input, randomly generated words, external web content, and stored text such as pet names in data stores. — [Creator Hub: Text filtering](https://create.roblox.com/docs/ui/text-filtering.md)
- **How to filter:**
  - Call `TextService:FilterStringAsync(text, userId)`, which returns a `TextFilterResult`.
  - `GetNonChatStringForBroadcastAsync()` gives text that is safe to show to everyone (e.g. signs). `GetNonChatStringForUserAsync()` filters per viewer, based on factors such as age.
  - Filter on submit, not per keystroke.
  - Stored data-store text should be filtered when it is retrieved.

  — [Text filtering](https://create.roblox.com/docs/ui/text-filtering.md)
- If reports or detection show a game isn't filtering, the game is removed until filtering is added. — [Text filtering](https://create.roblox.com/docs/ui/text-filtering.md)
- Chat is limited by age band, and users without an age check cannot chat. — [Roblox newsroom, Nov 2025](https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat)
- **RTBF:**
  - Roblox sends a daily automated inbox message listing RTBF requests and the affected games.
  - Creators must permanently delete all personal data in scope, including data outside data stores.
  - Tools: data store RTBF deletion templates (automatic deletion of matching keys) and a "Right to Erasure Request" webhook for custom logic.

  — [Creator Hub: RTBF and creators](https://create.roblox.com/docs/production/publishing/RTBF-and-creators.md); also [Automate right to erasure](https://create.roblox.com/docs/cloud/webhooks/automate-right-to-erasure) and [Data store RTBF](https://create.roblox.com/docs/cloud-services/data-stores/right-to-be-forgotten)
- **UK Children's Code (ICO guidance for game developers, Feb 2023):**
  - privacy settings high by default and geolocation off;
  - behavioural profiling for marketing off by default;
  - no nudge techniques with children;
  - identify under-18 players with a "reasonable degree of certainty";
  - games should not harm children's well-being.

  — [Nelsons summary of ICO guidance](https://www.nelsonslaw.co.uk/ico-guidance-to-game-developers/) (secondary source; the ICO original was not fetched)
- **COPPA precedent:** Epic paid a $275M civil penalty for COPPA violations in the 2022/2023 FTC settlement. — [FTC](https://www.ftc.gov/node/80648)

### Inferences
- **Filtering in this game.** Route any naming feature (renaming artifacts or golems, guild names) through server-side `FilterStringAsync`. Use the broadcast variant if other players can see the name. Store the raw text keyed by UserId and filter again on load.
- **Data-store layout.** Key player data by UserId, so RTBF templates can delete it cleanly. Avoid putting UserIds inside shared or global keys (leaderboards or trade logs), or include those in the webhook deletion logic.
- **Data minimization.** Collect no personal data beyond what Roblox provides. No external analytics that identify children.

### Gaps
- No primary source fetched on the 2025 COPPA Rule amendments (the FTC finalized changes in 2025, from memory; verify), GDPR Art. 8 / GDPR-K, or the exact RTBF response deadline. The RTBF page gives no deadline.
- The ICO primary guidance was not fetched.

## 5. Outside regulation and research on dark patterns and loot boxes for children

### Takeaway
Regulators focus on five things:
- clear real-money prices (EU CPC);
- no exploiting children's vulnerabilities, time pressure or confusing purchase flows (FTC v. Epic, EU CPC);
- loot boxes sold only to suitable ages (Australia requires at least an M rating since Sept 2024);
- loot boxes treated as gambling in Belgium;
- (in the Netherlands, loot boxes are not automatically gambling since the 2022 Council of State ruling, but a political push for a ban continues.)

For a 9-15 audience, avoid all of the following:
- fake near-misses;
- countdown purchase pressure;
- prices shown only in currency;
- nagging pop-ups;
- one-tap accidental purchases.

### Cited Findings
- **FTC v. Epic (finalized March 2023):**
  - $245M in consumer refunds, plus a $275M COPPA penalty.
  - The FTC cited "counterintuitive, inconsistent, and confusing button configuration" that led to charges from a single button press, children buying without parental consent, and accounts locked after chargebacks.
  - The order bans charging through dark patterns or without affirmative consent, and blocking account access during disputes.

  — [FTC press release](https://www.ftc.gov/node/80648)
- **EU CPC Network key principles on in-game virtual currencies:**
  1. Show prices in real-world money.
  2. Don't obscure cost; avoid mixing currencies or chaining exchanges.
  3. Let players buy the amount of currency they need (fair purchase options).
  4. Give clear pre-contract information, including the 14-day withdrawal right.
  5. Use plain-language terms.
  6. Respect the withdrawal/refund right.
  7. Don't exploit children's or vulnerable players' vulnerabilities or unfairly influence their spending.

  The principles are non-binding. They cover currencies used to buy digital content, not gameplay-only currencies. The Star Stable enforcement action alleged time pressure was used to drive sales. — [Linklaters, 27 Mar 2025](https://techinsights.linklaters.com/post/102k6t4/game-changer-eu-introduces-consumer-protection-guidance-for-in-game-virtual-curr); also [Lewis Silkin, Mar 2025](https://www.lewissilkin.com/insights/2025/03/26/eu-bodies-act-against-gaming-companies-to-protect-children-from-in-game-purchase-102k658)
- **Australia:** from September 2024, games with in-game purchases tied to chance (paid loot boxes) get at least an M classification ("not recommended for children under 15"). Simulated gambling (e.g. social casino) gets a mandatory R18+. — [Australian Dept of Infrastructure / Classification](https://www.infrastructure.gov.au/department/media/news/new-mandatory-minimum-classifications-gambling-games-content)
- **Belgium:**
  - In 2018 the Belgian Gaming Commission said paid loot boxes are gambling and need a licence that can't be obtained, so they are effectively banned.
  - Research by Leon Y. Xiao (QMUL) found the ban was poorly enforced and that a country-wide ban isn't "practically achievable".

  — [QMUL](https://qmul.ac.uk/law/news/2022/items/study-claims-country-wide-loot-box-ban-isnt-practically-achievable.html)
- **Netherlands:**
  - On 9 March 2022, the Council of State ruled that loot boxes "do not automatically qualify as games of chance", overturning the FIFA loot box penalty.
  - Several Dutch parties back a proposed ban.

  — [Bird & Bird](https://www.twobirds.com/en/insights/2022/netherlands/fifa-22-loot-boxes-no-longer-regarded-as-gambling-in-the-netherlands-as-ban-overturned); [VGC](https://www.videogameschronicle.com/news/six-dutch-political-parties-unite-behind-proposed-loot-box-ban)
- **UK:** the ICO Children's Code bans nudge techniques with children. — [Nelsons](https://www.nelsonslaw.co.uk/ico-guidance-to-game-developers/)

### Inferences
- **Australia rating.** Because Roblox Select covers 9-15, a paid luck boost that changes chance-based drops could arguably make the game "loot-box-like" under Australia's M-rating test. Roblox handles this through `PolicyService`, which reinforces gating or offering a deterministic alternative.
- **Practical design rules:**
  - Show the Robux price on every purchase button, with no currency-only prices.
  - Use a confirm step and avoid fast double-taps on purchase buttons.
  - No rigged "almost got legendary" reveal animations.
  - Event timers are fine for gameplay, but don't attach countdowns to purchase offers.
  - Cap shop pop-ups, and never show them on login or after a loss.
  - Earnable alternatives for every boost.
  - No "only X Robux" wording.

### Gaps
- Not retrieved:
  - the primary European Commission page with the original date of the CPC principles (I believe early 2024; the secondary sources here are from Mar 2025);
  - the UK government/DCMS loot box position (industry self-regulation guidance, 2023);
  - academic studies on near-miss effects in children.
- Belgium's legal basis is contested: QMUL describes a "2018 law", while other accounts describe a Gaming Commission interpretation of the existing Gaming Act. Unverified.

## 6. Roblox ads to under-13s and rewarded video restrictions

### Takeaway
Rewarded Video is 13+ only, and publishers may not misuse `PolicyService` to show ads to under-13s. No user under 13 may be rewarded for engaging with ads. Rewarded-video rewards must be opt-in, disclosed in advance, predetermined (not random), granted immediately, and never used as a forced progress gate.

### Cited Findings
- **Under-13s:** no rewards to users under 13 for engaging with any advertising. Rewarded Video is limited to 13+, and publishers may not misuse tools like `PolicyService` to show ads to under-13s. — [Advertising Standards](https://en.help.roblox.com/hc/en-us/articles/13722260778260-Advertising-Standards)
- **Rewarded video rules:**
  - clear disclosure of the reward and the required action;
  - opt-in with a click;
  - predetermined rewards, no random or chance mechanics;
  - reward granted immediately;
  - not a forced progress gate (no taking over the screen or movement);
  - no fraudulent rewards.

  — [Advertising Standards](https://en.help.roblox.com/hc/en-us/articles/13722260778260-Advertising-Standards)
- **Ad targeting:**
  - no ad personalization for users under 18;
  - restricted ad categories for under-13s (toys, entertainment by age band 5-8 / 9-12, food and beverage, social media, AI chatbots, and others).

  Reward mechanisms for Portal Ads have been banned since Oct 29, 2025. — [Advertising Standards](https://en.help.roblox.com/hc/en-us/articles/13722260778260-Advertising-Standards)

### Inferences
- **Two audience bands for ads.** Within Select (9-15), players aged 13-15 can see rewarded video and players aged 9-12 cannot. Build the "watch ad for 2x" button behind PolicyService/ads eligibility so it never appears for under-13s.
- **Fixed ad rewards.** An ad reward must be a fixed boost (for example, "2x idle earnings for 15 min"), never a random artifact roll.

### Gaps
- The exact PolicyService field for ad eligibility (`AreAdsAllowed`, from memory) was not confirmed.
