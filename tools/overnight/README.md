# Overnight autonomous dev loop

Lets Claude Code keep improving Crashman while you sleep — picking tasks, implementing them,
verifying headless, and committing only what passes. Runs on YOUR Mac (it needs Godot +
the `claude` CLI), not in the cloud.

## One-time check
- `claude` CLI installed and logged in (your Max plan): run `claude` once interactively first.
- Godot at `/Applications/Godot.app/Contents/MacOS/Godot` (edit the path in the scripts if not).
- Git can push to `github.com/SimcoeHops/gamezero` (run `git push` once manually to confirm auth).

## Launch (before bed)
```bash
cd /Users/beng/Development/crashman/crashman
chmod +x tools/overnight/*.sh          # first time only
bash tools/overnight/run_overnight.sh 6   # run for ~6 hours
```
Leave the terminal open and stop your Mac from sleeping (e.g. `caffeinate -i bash tools/overnight/run_overnight.sh 6`).

## What happens
- Creates a dated branch `overnight/<timestamp>` — your main branch is never touched.
- Loop: Claude Code does one task → `smoke_test.sh` gate → commit + push if it passes,
  hard-revert if it fails. Repeats until the time budget runs out.
- Direction comes from `BACKLOG.md`; behavior rules from `AGENT_BRIEF.md`; a log of each
  iteration lands in `JOURNAL.md`. Full run output is in `tools/overnight/logs/`.

## In the morning
```bash
git log --oneline overnight/<timestamp>     # see what got done
cat tools/overnight/JOURNAL.md              # readable summary
```
Open the project in Godot and playtest. Merge or cherry-pick what you like; delete the
branch if a night was a bust. Nothing is ever forced onto your main branch.

## Knobs
- `bash tools/overnight/run_overnight.sh 8 claude-opus-4-8` — hours + model.
- Inside `run_overnight.sh`: `MAX_TURNS` (cost cap per iteration), `SLEEP_BETWEEN`.

## Safety notes
- It edits game code autonomously with `--dangerously-skip-permissions`. The guardrails are:
  separate branch, smoke-test gate, auto-revert of failures, and git history. Review before merging.
- A tight loop can use a lot of plan quota overnight — `MAX_TURNS` and the run hours bound it.
- The smoke test only proves the game **boots without script errors** — it does not prove a
  feature is *fun* or visually correct. That's your morning playtest.
