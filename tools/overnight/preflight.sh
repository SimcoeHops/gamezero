#!/usr/bin/env bash
# Crashman overnight PREFLIGHT — proves the pipeline works in ~1 minute.
# Non-destructive: does NOT commit, push, or change game code. Run this before
# trusting a full overnight run.
#
#   bash tools/overnight/preflight.sh
set -uo pipefail

PROJECT="/Users/beng/Development/crashman/crashman"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
REMOTE_URL="https://github.com/SimcoeHops/gamezero.git"

cd "$PROJECT" || { echo "FAIL: project dir not found: $PROJECT"; exit 1; }
PASS=0; FAIL=0
ok(){ echo "  PASS: $*"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $*"; FAIL=$((FAIL+1)); }

echo "1) claude CLI present"
if command -v claude >/dev/null 2>&1; then ok "$(command -v claude)"; else no "'claude' not on PATH — install it / open it once"; fi

echo "2) claude headless + plan auth (tiny live call)"
if command -v claude >/dev/null 2>&1; then
  OUT="$(claude -p 'Reply with exactly: PREFLIGHT_OK' --max-turns 1 2>/tmp/cm_claude_err.log || true)"
  if echo "$OUT" | grep -q "PREFLIGHT_OK"; then ok "headless call works (Max plan auth OK)";
  else no "headless call failed — run 'claude' once interactively to log in. err: $(head -3 /tmp/cm_claude_err.log)"; fi
else no "skipped (no claude)"; fi

echo "3) Godot binary present"
if [ -x "$GODOT" ]; then ok "$GODOT"; else no "not at $GODOT — edit the GODOT path in the scripts"; fi

echo "4) Smoke test (boots the actual game headless — the per-iteration gate)"
if [ -x "$GODOT" ]; then
  if bash "$PROJECT/tools/overnight/smoke_test.sh"; then ok "game boots clean, no script errors";
  else no "smoke test reported errors (see above) — fix before running overnight"; fi
else no "skipped (no Godot)"; fi

echo "5) git + GitHub push auth"
if command -v git >/dev/null 2>&1; then ok "git found"; else no "git not on PATH"; fi
if git ls-remote "$REMOTE_URL" >/dev/null 2>&1; then ok "can reach + auth to $REMOTE_URL";
else no "cannot reach/auth $REMOTE_URL — run 'git push' once to set up credentials"; fi

echo
echo "===== preflight: $PASS passed, $FAIL failed ====="
if [ "$FAIL" -eq 0 ]; then
  echo "All green. Safe to run:  caffeinate -i bash tools/overnight/run_overnight.sh 6"
else
  echo "Fix the FAIL items above, then re-run:  bash tools/overnight/preflight.sh"
fi
exit 0
