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

pair "net: dedicated server + client" "$GODOT" --headless --path . -- --server --port 24599 --seed 777 --goal 3 --team-size 2 --lobby 0 \
  :: BW_PORT=24599
WAIT_SERVER=1 pair "net: player-hosted game + client" "$GODOT" --headless --path . res://tests/net_host_test.tscn \
  :: BW_PORT=24598 BW_EXPECT_BOTS=2
pair "net: round ends, server rolls everyone onto a new map" "$GODOT" --headless --path . -- --server --port 24597 --goal 1 --team-size 1 --skill 2 --round-break 3 --lobby 3 \
  :: BW_PORT=24597 BW_NET_TEST=round BW_EXPECT_BOTS=1
WAIT_SERVER=1 pair "net: hosted lobby, the host starts the match" env BW_NET_TEST=lobby BW_PORT=24596 "$GODOT" --headless --path . res://tests/net_host_test.tscn \
  :: BW_PORT=24596 BW_NET_TEST=lobby
pair "net: WebSocket server + client (what browsers use)" "$GODOT" --headless --path . -- --server --transport ws --port 24595 --seed 777 --goal 3 --team-size 2 --lobby 0 \
  :: BW_URL=ws://127.0.0.1:24595
pair "net: 16v16 WebSocket server, a player joins" "$GODOT" --headless --path . -- --server --transport ws --port 24593 --team-size 16 --lobby 0 \
  :: BW_URL=ws://127.0.0.1:24593 BW_NET_TEST=join BW_EXPECT_RATS=32
printf '{"servers": [{"name": "Test Server", "region": "Local", "url": "ws://127.0.0.1:24590"}]}' > "$logdir/servers.json"
pair "net: server list shows live status and joins" "$GODOT" --headless --path . -- --server --transport ws --port 24590 --team-size 2 --lobby 0 \
  :: BW_URL=ws://127.0.0.1:24590 BW_NET_TEST=browser BW_SERVER_LIST="$logdir/servers.json"
if command -v openssl >/dev/null; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj "/CN=localhost" \
    -keyout "$logdir/key.pem" -out "$logdir/cert.pem" >/dev/null 2>&1
  pair "net: wss:// (TLS) server + client" "$GODOT" --headless --path . -- --server --transport ws --port 24594 --lobby 0 \
    --tls-cert "$logdir/cert.pem" --tls-key "$logdir/key.pem" \
    :: BW_URL=wss://localhost:24594 BW_TLS_UNSAFE=1 BW_NET_TEST=join
else
  echo "skip  net: wss:// (no openssl to make a test certificate)"
fi
rm -rf "$logdir"
exit $fail
