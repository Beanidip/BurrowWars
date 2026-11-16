#!/usr/bin/env bash
# Burrow Wars verification gate. Usage: tools/check.sh /path/to/godot
# Fails on any script/parse error, missing resource, or failed assertion.
set -u
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
fail=0
run() {
  local name="$1"; shift
  local log; log="$(mktemp)"
  "$@" >"$log" 2>&1
  local code=$?
  if grep -vE "at exit|leaked" "$log" | grep -E "SCRIPT ERROR|Parse Error|Failed to load|ERROR:" >/dev/null; then code=1; fi
  if [ $code -ne 0 ]; then
    echo "FAIL  $name"; grep -E "SCRIPT ERROR|Parse Error|Failed|ERROR|ASSERT|at:" "$log" | head -40; fail=1
  else
    echo "PASS  $name"; grep -E "^(PASS|FAIL|----)|bots:" "$log"
  fi
  rm -f "$log"
}
run "import + editor validation" "$GODOT" --headless --path . --editor --quit
run "boot main scene (120 frames)" "$GODOT" --headless --path . --quit-after 120
run "smoke: menu -> match -> pause -> results" "$GODOT" --headless --path . res://tests/smoke_runner.tscn
run "gameplay regression suite" "$GODOT" --headless --path . res://tests/test_runner.tscn
exit $fail
