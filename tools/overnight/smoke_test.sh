#!/usr/bin/env bash
# Crashman smoke test — the safety gate for each overnight iteration.
# Exit 0 = project imports + boots headless with no script/parse errors.
# Exit 1 = real error detected (the loop will revert this iteration).
#
# Notes (from CLAUDE.md):
#   - No `timeout` on macOS — use Godot's --quit-after so it self-quits.
#   - Always use an absolute --path.
#   - "N resources still in use at exit" is a benign shutdown warning, not a failure.
set -uo pipefail

PROJECT="/Users/beng/Development/crashman/crashman"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

TMP="$(mktemp -d)"
IMPORT_LOG="$TMP/import.log"
BOOT_LOG="$TMP/boot.log"

# 1) Import any new/changed assets & scripts (needed before they can load()).
"$GODOT" --headless --path "$PROJECT" --import >"$IMPORT_LOG" 2>&1

# 2) Boot the main scene briefly; --quit-after makes Godot self-quit.
"$GODOT" --headless --path "$PROJECT" --quit-after 180 >"$BOOT_LOG" 2>&1

ERR_PATTERN="SCRIPT ERROR|Parse Error|Parser Error|invalid call|nonexistent function|null instance|Failed to load|Can't open|Cannot open file"

if grep -Eih "$ERR_PATTERN" "$IMPORT_LOG" "$BOOT_LOG" | grep -viq "resources still in use"; then
  echo "[smoke] FAIL — errors detected:"
  grep -Eih "$ERR_PATTERN" "$IMPORT_LOG" "$BOOT_LOG" | grep -vi "resources still in use" | head -25
  echo "[smoke] (full logs: $IMPORT_LOG  $BOOT_LOG)"
  exit 1
fi

echo "[smoke] OK"
exit 0
