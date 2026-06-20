# Overnight agent brief — Crashman

You are working autonomously overnight on Crashman, a vibe-coded Godot 4.7 endless-runner.
The human's goal is explicit and ambitious: **wake up to a game that moves toward top-10
App Store / Apple Arcade quality** — in this order, FUN to play, how it FEELS, how it LOOKS.
A wrapper runs you once per iteration, runs a smoke test, then commits if it passes or reverts
if it fails. Make each iteration a real, complete, *polished* step toward that bar.

## Read first, every iteration
1. `tools/overnight/VISION.md` — the design pillars and the 10-category quality rubric. THIS
   is the standard you are held to. Judge your work against it.
2. `CLAUDE.md` — architecture, asset map, and the **Headless verification (macOS)** section.
   It is the source of truth for how the project works; follow its verification recipe exactly.
3. `BACKLOG.md` (priorities) and `tools/overnight/JOURNAL.md` (what prior iterations did).

## Choose what to do — TWO modes

### A) Build mode (most iterations)
Pick the single **highest-leverage** item — usually the top of BACKLOG "NOW", or the thing
that most raises the lowest rubric score. Then take it all the way:
- **Finish to polish, not to "it works."** A feature without its juice (feedback, sound,
  particles, game-feel) is not done — it's a liability that will get reverted. Add the layers.
- Keep changes **scoped**; respect autoload load order; don't refactor what you weren't asked
  to. This is a vibe-coded game: optimize for FUN and game-feel over architectural purity.
- One feature per iteration. Working, small, and *juicy* beats ambitious and broken.

### B) Deep-audit mode (do this when the iteration number is a multiple of 4, OR whenever
BACKLOG "NOW" is empty)
Genuinely dig deep — this is how we keep raising the ceiling:
1. Boot/exercise the game per CLAUDE.md's headless recipe (use the temporary `Main._ready`
   swap to run gameplay; restore it after). Read the relevant scripts critically.
2. Score all 10 rubric categories in VISION.md, 1–5, as a **harsh critic**. Write the
   scorecard + reasoning to JOURNAL.md.
3. Take the 2–3 **lowest-scoring** categories and write 3–5 concrete, scoped, ambitious
   BACKLOG items to the TOP of "NOW" that would move those scores toward 5.
4. If time remains, start the single best of those items. Don't just plan — ship something.

## Verify before you finish (non-negotiable)
- Run the headless check from CLAUDE.md. Confirm no `error|script|parse|invalid` lines
  (ignore "resources still in use at exit"). For gameplay features, use the documented
  `Main._ready` swap to actually exercise the feature, then RESTORE the original.
- Leave the working tree clean and buildable. The wrapper reverts anything that fails smoke.

## Before you stop, every iteration
- `BACKLOG.md`: check off `[x]` finished items (move to Done with a date); add follow-ups.
- `tools/overnight/JOURNAL.md`: append a short dated entry — what you changed, files touched,
  how you verified, the rubric scorecard if it was an audit iteration, and anything the human
  should playtest or decide. Be honest about what's unverified or risky.
- Do NOT run git yourself — the wrapper handles commits/branches/push.

## Hard rules
- Never delete/overwrite unfamiliar work without confirming it's safe (CLAUDE.md "Working
  agreement"). When unsure, leave it and note it in the journal.
- Never touch `tools/overnight/` (your own harness) or `.git`.
- Depth over breadth. Juice over features. Fun over everything.
