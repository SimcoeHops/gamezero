# Crashman — Vision & Quality Bar

**Goal:** a world-class, top-10-App-Store / Apple-Arcade level endless runner. We may never
ship there, but every decision is judged against that bar. Three things, in order:
**(1) FUN TO PLAY, (2) how it FEELS, (3) how it LOOKS.** A gorgeous game that isn't fun is a
failure; a fun game that feels mushy is a failure. Polish serves fun — never the reverse.

This file is the north star for the overnight loop. Read it every iteration. When in doubt,
ask: "would this survive on the App Store top-10 charts?" If not, it's not done.

## Design pillars (what Crashman IS)
1. **Speed you can feel.** The core fantasy is sprinting impossibly fast through traffic.
   Every system should amplify the sensation of speed and the terror/thrill of near-death.
2. **Spectacular failure.** Crashing should be a *reward* to watch — ragdoll, deform, slow-mo,
   debris. Death is a punchline, not just a fail state. Players should want to crash sometimes.
3. **The build-a-loadout power fantasy.** The auto-fire gun system (Vampire-Survivors DNA) is
   the depth engine. Escalating, screen-filling carnage from stacking guns is the hook that
   turns "one more run" into an hour. Lean into meaningful choices and visible power growth.
4. **Readable chaos.** No matter how much is on screen, the next obstacle and the safe gap are
   always instantly readable. Juice never costs clarity.
5. **Pick-up-and-play, hard-to-master.** Trivial first 10 seconds; deep mastery ceiling
   (timing, routing, build optimization, risk/reward greed).

## Anti-goals
- No feature creep that muddies the core loop. No menus that aren't fun to touch.
- No "asset-flip" look: the Kenney kits must be unified by lighting, grading, and effects so
  it reads as one art-directed world, not a parts bin.
- No jank: dropped frames, input lag, or pop-in break the spell more than missing content.

## The quality rubric (score each 1–5 during audits)
Use this in the deep-audit iterations (see AGENT_BRIEF.md). 5 = top-10 App Store quality.
Be a harsh critic. The point is to find the **weakest** category and attack it.

1. **Core fun & game loop** — Is "one more run" irresistible? Meaningful choices? Flow state?
2. **Game feel / responsiveness** — Controls crisp? Input buffering/coyote time? Camera
   intentional? 60fps-smooth? Does speed *feel* fast?
3. **Juice & feedback** — Does every action (jump, stomp, near-miss, pickup, crash, level-up)
   have layered aud-visual-haptic payoff? Hit-stop, shake, particles, screen FX, sound?
4. **Visual polish & art direction** — Cohesive grading/lighting/post? Particles & atmosphere?
   Does each biome have a strong identity? Does it look *designed*, not assembled?
5. **Audio** — Adaptive music? Full, varied, satisfying SFX coverage? Mix balance? Stingers?
6. **Progression & retention** — Reasons to come back: meta-currency, unlocks, upgrade choices,
   missions/dailies, goals, leaderboards. Does power persist and grow visibly?
7. **Onboarding & UX** — First-run clarity, menu polish, transitions, typography, iconography.
8. **Difficulty & balance** — Smooth ramp, fair deaths, dynamic pacing, satisfying mastery.
9. **Performance & stability** — Pooling, draw calls, frame pacing, no pop-in, no errors.
10. **Accessibility & options** — Shake/haptics toggles, colorblind-safe, remappable, scalable.

## How to use this in the loop
- Most iterations: take the highest-leverage item from BACKLOG.md and execute it to a high
  finish — not "it works" but "it feels great." Add the juice; don't leave it bare.
- Audit iterations: score the rubric, write the scorecard to JOURNAL.md, and convert the
  lowest-scoring categories into 3–5 concrete, scoped BACKLOG items at the top of "Now".
- Always prefer **depth over breadth**: one feature taken to top-10 polish beats three
  half-done features. Reverted work is wasted; ship small, complete, juicy increments.
