#!/usr/bin/env bash
# Runs every unit/integration suite. Exit 0 only if all pass.
# Usage: bash tests/run_all.sh [path-to-godot]
GODOT="${1:-D:/Unreal Engine/GodotEngine/Godot_v4.7.2-stable_win64_console.exe}"
fail=0
for t in tests/unit/test_*.gd tests/integration/test_*.gd; do
  [ -e "$t" ] || continue
  out=$("$GODOT" --headless --script "res://$t" 2>&1)
  if echo "$out" | grep -qE "FAILED|Parse Error|SCRIPT ERROR"; then
    echo "FAIL  $t"; echo "$out" | grep -E "FAIL|Error" | head -5; fail=1
  else
    echo "pass  $t  $(echo "$out" | grep -oE '[A-Za-z]+ tests: PASS' | head -1)"
  fi
done
exit $fail
