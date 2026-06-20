#!/usr/bin/env bash
# Crashman overnight autonomous dev loop.
#
#   Usage:  bash tools/overnight/run_overnight.sh [HOURS] [MODEL]
#   e.g.    bash tools/overnight/run_overnight.sh 6
#
# Each iteration:
#   1. Hands AGENT_BRIEF.md to Claude Code headless (autonomous, no prompts).
#   2. Runs smoke_test.sh as a gate.
#   3. PASS  -> commit + push to GitHub.
#      FAIL  -> hard-revert to the last good commit (the bad attempt is discarded).
#
# Everything happens on a dated branch (overnight/<timestamp>) so your working
# branch is never touched. Review in the morning, cherry-pick or merge what you like.
set -uo pipefail

PROJECT="/Users/beng/Development/crashman/crashman"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
REMOTE_URL="https://github.com/SimcoeHops/gamezero.git"

HOURS="${1:-6}"            # how long to run
MODEL="${2:-claude-opus-4-8}"
MAX_TURNS=40              # per-iteration cap so one task can't burn the whole quota
SLEEP_BETWEEN=15         # breather between iterations

cd "$PROJECT" || { echo "FATAL: $PROJECT not found"; exit 1; }

LOG_DIR="$PROJECT/tools/overnight/logs"
mkdir -p "$LOG_DIR"
TS="$(date +%Y%m%d-%H%M%S)"
RUN_LOG="$LOG_DIR/run-$TS.log"
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$RUN_LOG"; }

# ---- preflight -------------------------------------------------------------
command -v claude >/dev/null 2>&1 || { log "FATAL: 'claude' CLI not on PATH"; exit 1; }
command -v git    >/dev/null 2>&1 || { log "FATAL: 'git' not on PATH"; exit 1; }
[ -x "$GODOT" ] || { log "FATAL: Godot not found at $GODOT"; exit 1; }

# ---- git setup -------------------------------------------------------------
if [ ! -d .git ]; then
  log "Initializing git repo"
  git init -q
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  log "Adding origin -> $REMOTE_URL"
  git remote add origin "$REMOTE_URL"
fi

# Make a 'last known good' baseline from whatever is on disk right now.
git add -A
git commit -qm "overnight baseline snapshot ($TS)" 2>/dev/null || log "(nothing new to snapshot)"

BRANCH="overnight/$TS"
git checkout -qb "$BRANCH"
log "Working on branch: $BRANCH"
git push -u origin "$BRANCH" >>"$RUN_LOG" 2>&1 && log "Pushed branch to GitHub" \
  || log "WARN: initial push failed (check 'git push' auth) — will keep retrying"

# ---- the loop --------------------------------------------------------------
END=$(( $(date +%s) + HOURS*3600 ))
ITER=0
PASSES=0
FAILS=0

while [ "$(date +%s)" -lt "$END" ]; do
  ITER=$((ITER+1))
  log "===== Iteration $ITER (branch $BRANCH) ====="

  claude -p "$(cat "$PROJECT/tools/overnight/AGENT_BRIEF.md")" \
    --dangerously-skip-permissions \
    --model "$MODEL" \
    --max-turns "$MAX_TURNS" \
    >>"$RUN_LOG" 2>&1
  log "Claude Code finished iteration $ITER (exit $?)"

  if bash "$PROJECT/tools/overnight/smoke_test.sh" >>"$RUN_LOG" 2>&1; then
    PASSES=$((PASSES+1))
    log "Smoke PASS — committing"
    git add -A
    git commit -qm "overnight iter $ITER: passed smoke ($(date +%H:%M))" 2>/dev/null \
      && log "committed" || log "(no changes to commit this iter)"
    git push origin "$BRANCH" >>"$RUN_LOG" 2>&1 && log "pushed" || log "WARN: push failed"
  else
    FAILS=$((FAILS+1))
    log "Smoke FAIL — reverting iteration $ITER to last good commit"
    git reset --hard HEAD >>"$RUN_LOG" 2>&1
    git clean -fd        >>"$RUN_LOG" 2>&1   # ignored files (logs) are preserved
  fi

  sleep "$SLEEP_BETWEEN"
done

log "=========================================================="
log "Done. $ITER iterations: $PASSES passed, $FAILS reverted."
log "Branch: $BRANCH"
log "Review:  git log --oneline $BRANCH"
log "         git diff main..$BRANCH      (then merge/cherry-pick what you like)"
log "Open the project in Godot to playtest. Journal: tools/overnight/JOURNAL.md"
