#!/usr/bin/env bash
# Builds the browser versions and checks they boot.
#   tools/web_build.sh /path/to/godot [--no-test]
# Makes:
#   build/web/                       threaded build (needs SharedArrayBuffer: tick it on itch.io)
#   build/web-nothreads/             works on any host, a little slower to load, may stutter while digging
#   build/BurrowWars_web.zip         the threaded build, ready to upload to itch.io
#   build/BurrowWars_web_nothreads.zip
# Then boots each in headless Chromium (tools/web_smoke.js) unless --no-test.
# Needs the Godot 4.7.2 web export templates (web_release.zip, web_nothreads_release.zip).
set -u
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
mkdir -p build
touch build/.gdignore            # keep Godot from importing the build output
fail=0
for variant in "Web:build/web:BurrowWars_web.zip:8060" "Web (no threads):build/web-nothreads:BurrowWars_web_nothreads.zip:8061"; do
  IFS=: read -r preset dir zipname port <<<"$variant"
  rm -rf "$dir"; mkdir -p "$dir"
  if ! "$GODOT" --headless --path . --export-release "$preset" "$dir/index.html" >/dev/null 2>&1 || [ ! -f "$dir/index.wasm" ]; then
    echo "FAIL  export '$preset' (are the web export templates installed?)"; fail=1; continue
  fi
  rm -f "$dir"/*.import "build/$zipname"
  (cd "$dir" && zip -qr "../$zipname" .)
  echo "PASS  export '$preset' -> $dir ($(du -sh "$dir" | cut -f1)), build/$zipname"
  if [ "${2:-}" != "--no-test" ]; then
    python3 tools/serve_web.py "$dir" "$port" >/dev/null 2>&1 &
    spid=$!
    sleep 1
    if timeout 400 node tools/web_smoke.js "http://localhost:$port/index.html" >"build/web_smoke_$port.log" 2>&1; then
      echo "PASS  boots in Chromium: '$preset'"; grep -E "^(ok|FAIL|----)|      " "build/web_smoke_$port.log"
    else
      echo "FAIL  boots in Chromium: '$preset'"; cat "build/web_smoke_$port.log"; fail=1
    fi
    kill $spid 2>/dev/null; wait $spid 2>/dev/null
  fi
done
exit $fail
