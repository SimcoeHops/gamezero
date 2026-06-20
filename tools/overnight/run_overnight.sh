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
MAX_NOPROGRESS=3         # stop after this many iters in a row with no committable progress

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
ITER=0; PASSES=0; FAILS=0; NOPROG=0
STOP_REASON="time budget reached"
# Phrases that mean Claude hit a usage / rate-limit / overload wall (expected on a
# plan without extra context once the 5-hour window is exhausted).
WALL_RE="usage limit|rate limit|rate.?limited|limit reached|limit will reset|resets at|out of (usage|tokens)|insufficient quota|quota exceeded|overloaded|too many requests|status (429|529)|error: ?(429|529)"

while [ "$(date +%s)" -lt "$END" ]; do
  ITER=$((ITER+1))
  log "===== Iteration $ITER (branch $BRANCH) ====="

  # Capture this iteration's output so we can inspect it for a usage wall.
  ITER_OUT="$LOG_DIR/iter-$TS-$ITER.out"
  claude -p "$(cat "$PROJECT/tools/overnight/AGENT_BRIEF.md")" \
    --dangerously-skip-permissions \
    --model "$MODEL" \
    --max-turns "$MAX_TURNS" \
    >"$ITER_OUT" 2>&1
  CC_EXIT=$?
  cat "$ITER_OUT" >>"$RUN_LOG"
  log "Claude Code finished iteration $ITER (exit $CC_EXIT)"

  WALL=0
  grep -qiE "$WALL_RE" "$ITER_OUT" && WALL=1

  # Gate whatever ended up on disk — this still saves good *partial* work if Claude
  # was cut off mid-task, and reverts anything broken.
  COMMITTED=0
  if bash "$PROJECT/tools/overnight/smoke_test.sh" >>"$RUN_LOG" 2>&1; then
    git add -A
    if git commit -qm "overnight iter $ITER: passed smoke ($(date +%H:%M))" 2>/dev/null; then
      PASSES=$((PASSES+1)); COMMITTED=1; log "Smoke PASS — committed"
      git push origin "$BRANCH" >>"$RUN_LOG" 2>&1 && log "pushed" || log "WARN: push failed"
    else
      log "Smoke PASS — nothing changed this iteration"
    fi
  else
    FAILS=$((FAILS+1))
    log "Smoke FAIL — reverting iteration $ITER to last good commit"
    git reset --hard HEAD >>"$RUN_LOG" 2>&1
    git clean -fd        >>"$RUN_LOG" 2>&1   # ignored files (logs) are preserved
  fi
  rm -f "$ITER_OUT"

  # --- stop conditions ---
  if [ "$WALL" -eq 1 ]; then
    STOP_REASON="hit Claude usage / rate-limit wall at iteration $ITER"
    log "Detected a Claude usage/limit wall — stopping cleanly (resume in the morning)."
    break
  fi
  if [ "$COMMITTED" -eq 1 ]; then NOPROG=0; else NOPROG=$((NOPROG+1)); fi
  if [ "$NOPROG" -ge "$MAX_NOPROGRESS" ]; then
    STOP_REASON="$NOPROG iterations made no committable progress (likely a usage wall or stuck) — stopped at iteration $ITER"
    log "$STOP_REASON"
    break
  fi

  sleep "$SLEEP_BETWEEN"
done

# ---- wrap up ---------------------------------------------------------------
{
  echo ""
  echo "## $(date '+%Y-%m-%d %H:%M') — overnight run ended"
  echo "Reason: $STOP_REASON"
  echo "Iterations: $ITER ($PASSES committed, $FAILS reverted). Branch: $BRANCH"
  if echo "$STOP_REASON" | grep -qiE "wall|no committable"; then
    echo "This is expected without extra context: the ~5-hour usage window was exhausted."
    echo "Resume any time (the window resets within ~5h) with:"
    echo "    caffeinate -i bash tools/overnight/run_overnight.sh <hours>"
    echo "A fresh overnight/<timestamp> branch starts and work continues from BACKLOG.md / JOURNAL.md."
  fi
} >> "$PROJECT/tools/overnight/JOURNAL.md"
# Preserve the summary note on the branch too.
git add tools/overnight/JOURNAL.md >/dev/null 2>&1 \
  && git commit -qm "overnight: run summary ($(date +%H:%M))" >/dev/null 2>&1 \
  && git push origin "$BRANCH" >>"$RUN_LOG" 2>&1 || true

log "=========================================================="
log "Done. Reason: $STOP_REASON"
log "$ITER iterations: $PASSES committed, $FAILS reverted. Branch: $BRANCH"
log "Review:  git log --oneline $BRANCH   |   git diff main..$BRANCH"
log "Resume:  caffeinate -i bash tools/overnight/run_overnight.sh <hours>"
log "The 8am digest will summarize JOURNAL.md. Open Godot to playtest."
