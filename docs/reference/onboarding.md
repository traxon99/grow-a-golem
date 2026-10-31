# Onboarding (first-time user experience)

Last updated: 2026-10-27.

## Rules for agents

1. **Reach the fun in 5 minutes or less;** for us, the golem should be fighting within about 10 seconds of spawn ([Roblox Docs: Retention](https://create.roblox.com/docs/en-us/production/analytics/retention.md); 10 s target is inference).
2. **Let players act before they read.** Short tooltips and pointers over long text; the tutorial stays skippable ([Roblox Docs: Onboarding](https://create.roblox.com/docs/production/game-design/onboarding.md)).
3. **Teach what to do and why** for the core loop: fight/mine, collect minerals, forge, grow, unlock zone (same source).
4. **Keep early XP thresholds low** and give enough starter minerals for a first forge quickly (same source).
5. **End the first loop with a designed "moment of joy":** reward, animation, sound (same source). Gate motion on ReducedMotion.
6. **Show short, mid and long-term goals** from the first minute (next forge part, next size step, next island) (same source).
7. **Log every onboarding step as a funnel event** and fix the biggest drop-off first ([Retention](https://create.roblox.com/docs/en-us/production/analytics/retention.md)).
8. **No shop prompts during onboarding** (house rule, see [safety-compliance.md](safety-compliance.md)).
9. **Tune with Configs/Experiments, not redeploys,** where possible (same Roblox sources).

## What top games do

- **Roblox's FTUE guidance:** teach controls and the core loop; low early thresholds and moderate starter items; visible goals (Jailbreak's season-pass popup is their example); end with a moment of joy; their sample A/B test compares a shorter dialogue against a guided arrow ([Onboarding](https://create.roblox.com/docs/production/game-design/onboarding.md)).
- **For D1:** short tutorial or tooltips, avoid long tutorials, a satisfying moment after the first loop, show future progress, test performance across devices ([Retention](https://create.roblox.com/docs/en-us/production/analytics/retention.md)).
- **Funnel method:** list core-loop steps, log each as a funnel event, fix the biggest drop (for example a location players cannot find) (same source).
- **First 90 seconds (opinion, low confidence):** Adopt Me! puts a baby in your hands at spawn; use environmental cues (glowing doors, arrows, NPCs walking a direction) over text ([RoWatcher](https://rowatcher.com/news/your-first-90-seconds-are-destroying-roblox-retention)).
- **Fisch** has an in-game tutorial a reviewer called good but incomplete ([Destructoid](https://www.destructoid.com/fisch-roblox-beginners-guide/)).
- **Stakes:** median D1 is only about 4-11% depending on session length; 90th percentile is about 9-19% ([GameAnalytics 2025](https://investgame.net/wp-content/uploads/2025/09/2025-Roblox-Benchmark-Report.pdf)).
- No primary data was found on forced vs skippable tutorials on Roblox, or on first-60-second breakdowns of specific top games.

### Suggested golem FTUE (inference)
| Time | Beat |
|---|---|
| 0-10 s | Spawn on the golem's shoulder; golem starts fighting a weak enemy |
| under 30 s | First mineral pickup with a pointer/Beam toward the forge |
| under 2 min | First forge part crafted; visible power jump plus celebration |
| 2-5 min | Goal tracker shows next size step and the boss/zone gate |
| 5 min | Playtime gift lands as a second reward beat |

## Grow A Golem today

- `TutorialService`: 5-step skippable tutorial with pointers, already emitting onboarding funnel events.
- Goal card (top right): one short sentence, up to three checklist steps and a "to go" bar; tapping it opens the menu it points to (#85). The tutorial sign shows "STEP N OF M", a key cap for the input and step text aiming for fewer than 8 words, using plain language for ages 9–14 (#96; reading pass 2026-10-30).
- Level-up banner and artifact reveal card exist as reward moments; 5-minute playtime gift.
- XP curve (`Config.LevelCurve`, total XP to reach a level) `25*(level-1)^1.6`: level 2 = 25, level 5 about 230, level 10 about 840, level 20 about 2,780. Early steps are short, which matches Roblox's advice; real time-per-level depends on XP per kill (measure in #9).
- Unknown until playtest (#9): time to first fight, first mineral, first forge; whether the funnel events reach an analytics sink (#11).

## Gaps worth closing

1. **P0 (#9):** Time the first session with a stopwatch: first fight under 10 s, first forge under 2 min. Record results in this doc.
2. **P0 (#11):** Confirm funnel events are recorded and viewable; add step timing.
3. **P1:** Make the first forge a designed moment of joy (VFX, sound, size bump or stat pop).
4. **P1:** Replace any text-heavy tutorial step with a pointer or world cue.
5. **P2:** A/B test tutorial variants (short dialogue vs arrow only) once traffic exists.

## Sources

All accessed 2026-10.
- Roblox Creator Docs, Onboarding: https://create.roblox.com/docs/production/game-design/onboarding.md
- Roblox Creator Docs, Retention: https://create.roblox.com/docs/en-us/production/analytics/retention.md
- GameAnalytics 2025 Roblox Benchmark Report: https://investgame.net/wp-content/uploads/2025/09/2025-Roblox-Benchmark-Report.pdf
- RoWatcher, first 90 seconds (opinion, low confidence): https://rowatcher.com/news/your-first-90-seconds-are-destroying-roblox-retention
- Destructoid, Fisch beginner guide: https://www.destructoid.com/fisch-roblox-beginners-guide/
