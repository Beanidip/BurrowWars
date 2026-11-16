#!/usr/bin/env bash
# Multiplayer end-to-end checks: real processes talking ENet over localhost.
# Usage: tools/net_check.sh /path/to/godot   (called by tools/check.sh)
set -u
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
fail=0
logdir="$(mktemp -d)"

pair() {   # name, server command..., then "::" , client env...
  local name="$1"; shift
  local srv=() ; while [ "$1" != "::" ]; do srv+=("$1"); shift; done; shift
  timeout 200 "${srv[@]}" >"$logdir/server.log" 2>&1 &
  local spid=$!
  sleep 1
  env "$@" timeout 180 "$GODOT" --headless --path . res://tests/net_client_test.tscn >"$logdir/client.log" 2>&1
  local code=$?
  if [ "${WAIT_SERVER:-0}" = 1 ]; then wait $spid; local scode=$?; [ $scode -ne 0 ] && code=1; else kill $spid 2>/dev/null; wait $spid 2>/dev/null; fi
  if grep -E "SCRIPT ERROR|Parse Error" "$logdir/client.log" "$logdir/server.log" >/dev/null; then code=1; fi
  if [ $code -ne 0 ]; then
    echo "FAIL  $name"; grep -hE "FAIL|ERROR|at:|----" "$logdir/client.log" "$logdir/server.log" | grep -v "leaked\|still in use\|cleanup\|resource.cpp" | head -30; fail=1
  else
    echo "PASS  $name"; grep -hE "^(ok|FAIL|----)" "$logdir/server.log" "$logdir/client.log"
  fi
}

pair "net: dedicated server + client" "$GODOT" --headless --path . -- --server --port 24599 --seed 777 --goal 3 --team-size 2 \
  :: BW_PORT=24599
WAIT_SERVER=1 pair "net: player-hosted game + client" "$GODOT" --headless --path . res://tests/net_host_test.tscn \
  :: BW_PORT=24598 BW_EXPECT_BOTS=2
pair "net: round ends, server rolls everyone onto a new map" "$GODOT" --headless --path . -- --server --port 24597 --goal 1 --team-size 1 --skill 2 --round-break 3 \
  :: BW_PORT=24597 BW_NET_TEST=round BW_EXPECT_BOTS=1
rm -rf "$logdir"
exit $fail
