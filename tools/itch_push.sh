#!/usr/bin/env bash
# Uploads builds to itch.io with butler (https://itch.io/docs/butler/).
#   tools/itch_push.sh <itch-user>/<game-page> [version]
# Run `butler login` once first (or set BUTLER_API_KEY). Pushes whatever is in build/:
#   build/web-nothreads/  -> channel "html5"   (mark it "playable in the browser" on itch once;
#                            BW_WEB=threaded pushes build/web instead, see docs/ITCH.md)
#   build/BurrowWars.exe  -> channel "windows"
#   build/BurrowWars.x86_64 -> channel "linux"
# butler only uploads what changed, and itch keeps the channel's download up to date.
set -eu
TARGET="${1:?usage: tools/itch_push.sh <itch-user>/<game-page> [version]}"
cd "$(dirname "$0")/.."
VERSION="${2:-$(grep -m1 '^config/version=' project.godot | cut -d'"' -f2)}"
command -v butler >/dev/null || { echo "butler is not installed: https://itch.io/docs/butler/installing.html"; exit 1; }
pushed=0
WEB_DIR=build/web-nothreads
[ "${BW_WEB:-}" = threaded ] && WEB_DIR=build/web
if [ -f "$WEB_DIR/index.html" ]; then
  butler push "$WEB_DIR" "$TARGET:html5" --userversion "$VERSION"; pushed=1
fi
if [ -f build/BurrowWars.exe ]; then
  mkdir -p build/itch-windows && cp build/BurrowWars.exe build/itch-windows/
  butler push build/itch-windows "$TARGET:windows" --userversion "$VERSION"; pushed=1
fi
if [ -f build/BurrowWars.x86_64 ]; then
  mkdir -p build/itch-linux && cp build/BurrowWars.x86_64 build/itch-linux/ && chmod +x build/itch-linux/BurrowWars.x86_64
  butler push build/itch-linux "$TARGET:linux" --userversion "$VERSION"; pushed=1
fi
[ $pushed = 1 ] || { echo "Nothing in build/ to push: run tools/web_build.sh and export the desktop builds first."; exit 1; }
echo "Pushed version $VERSION to $TARGET"
