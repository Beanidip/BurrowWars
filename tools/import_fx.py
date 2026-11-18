#!/usr/bin/env python3
"""Imports pixel-art effects from the pixelfx library (MIT, github.com/patch-gg/pixelfx)
as sprite sheets the game plays: assets/fx/<name>.png plus scripts/match/fx_sheets.gd
(frame size, frame count, columns, fps, loop, pivot for each).

    git clone https://github.com/patch-gg/pixelfx /somewhere/pixelfx
    python3 tools/import_fx.py /somewhere/pixelfx

Needs Node 18+ (the pixelfx renderer uses only Node). Edit EFFECTS below to swap
an effect, recolour it (opts are the effect's own options, e.g. a palette ramp)
or add one, then rerun. Frames are cropped to the area the effect actually uses
and re-packed into a compact grid, at a lower frame rate where that is plenty.
Your own sheets work too: any PNG grid with a matching entry in fx_sheets.gd.
"""
import json
import math
import os
import shutil
import subprocess
import sys
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "fx")

DARK = ["#0c0814", "#1e1430", "#33224d", "#4f3a70", "#76609a", "#a28ec4", "#d2c4ee"]
EARTH = ["#140e0a", "#2a1e14", "#47321e", "#69492a", "#8e6638", "#b88a52", "#dcb47c"]
STONE = ["#0e0e12", "#1c1c24", "#2c2c38", "#42424f", "#5c5c6b", "#7d7d8c", "#a4a4b2", "#d0d0da"]
ICE = ["#0c1430", "#162c5c", "#1f4f94", "#2f7fcc", "#58b4ec", "#9bdcff", "#d8f4ff", "#ffffff"]
GOLD = ["#1e1206", "#4a2c08", "#86520c", "#c48412", "#f0b424", "#ffe066", "#fff6c4", "#ffffff"]
WOOD = ["#160c06", "#2e1a0c", "#4a2c14", "#6a421e", "#8e5c2c", "#b47c40", "#d8a464"]
LAVA = ["#1a0604", "#4a0e06", "#8a1c08", "#c83a0c", "#ec6a14", "#ffa02a", "#ffd86a", "#fff6d0"]

# name in the game        pixelfx id                    fps  max seconds  options  [import options]
# Import options: {"from": s, "to": s, "loop": True} keeps only that stretch of
# the effect (seconds) and makes it a loop, e.g. a shield held up.
EFFECTS = [
    ("explosion",   "explosions/dirt-explosion", 15, 2.6, {}),
    ("hit",         "impacts/hit-spark",         20, 0,   {}),
    ("break_dirt",  "impacts/blunt-hit",         15, 0,   {"palette": EARTH, "dust": "#8e6638", "clod": "#47321e"}),
    ("break_stone", "impacts/blunt-hit",         15, 0,   {"palette": STONE, "dust": "#7d7d8c", "clod": "#42424f"}),
    ("break_ice",   "impacts/blunt-hit",         15, 0,   {"palette": ICE, "dust": "#9bdcff", "clod": "#58b4ec"}),
    ("break_scrap", "impacts/blunt-hit",         15, 0,   {"palette": GOLD, "dust": "#c48412", "clod": "#86520c"}),
    ("break_wood",  "impacts/blunt-hit",         15, 0,   {"palette": WOOD, "dust": "#b47c40", "clod": "#6a421e"}),
    ("break_dark",  "impacts/blunt-hit",         15, 0,   {"palette": DARK, "dust": "#4f3a70", "clod": "#1e1430"}),
    ("dust",        "impacts/heavy-landing",     15, 0,   {}),
    ("dizzy",       "status/stunned",            15, 0,   {}),
    ("collect",     "pickups/collect-burst",     15, 0,   {}),
    ("poof",        "spawn/poof",                15, 0,   {}),
    ("firework",    "explosions/firework-burst", 12, 2.6, {}),
    ("jetpack",     "scifi/jetpack",             15, 0,   {}),
    ("splash",      "water/splash",              15, 1.8, {"stone": False}),
    ("splash_lava", "water/splash",              15, 1.8, {"stone": False, "palette": LAVA, "seed": 5}),
    ("dash",        "melee/spear-sweep",         15, 1.0, {}),
    ("pound",       "impacts/ground-slam",       15, 1.3, {}),
    ("shield_block", "impacts/shield-block",     15, 0,   {}),
    ("shield_up",   "impacts/shield-block",      15, 0,   {}, {"from": 0.36, "to": 0.62, "loop": True}),
]


def render(pixelfx: str, fx_id: str, fps: int, opts: dict, tmp: str) -> tuple:
    cmd = ["node", os.path.join(pixelfx, "tools", "render.mjs"), fx_id, "--sheet", "--no-actor", "--fps", str(fps), "--out", tmp]
    if opts:
        cmd += ["--opts", json.dumps(opts)]
    subprocess.run(cmd, cwd=pixelfx, check=True, stdout=subprocess.DEVNULL)
    name = fx_id.split("/")[-1]
    for root, _dirs, files in os.walk(tmp):
        if name + ".json" in files:
            return os.path.join(root, name + ".png"), os.path.join(root, name + ".json")
    raise SystemExit("pixelfx did not write a sheet for " + fx_id)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    pixelfx = os.path.abspath(sys.argv[1])
    os.makedirs(OUT, exist_ok=True)
    table = []
    for entry in EFFECTS:
        name, fx_id, fps, max_t, opts = entry[:5]
        extra = entry[5] if len(entry) > 5 else {}
        tmp = os.path.join(OUT, "_tmp")
        shutil.rmtree(tmp, ignore_errors=True)
        png, js = render(pixelfx, fx_id, fps, opts, tmp)
        meta = json.load(open(js))
        px = meta["meta"]["pixelfx"]
        w, h = px["frameSize"]
        sheet = Image.open(png).convert("RGBA")
        frames = [sheet.crop((f["frame"]["x"], f["frame"]["y"], f["frame"]["x"] + w, f["frame"]["y"] + h)) for f in meta["frames"]]
        loop = bool(px["loop"])
        if "from" in extra:
            frames = frames[int(round(extra["from"] * px["fps"])): int(round(extra["to"] * px["fps"]))]
            loop = bool(extra.get("loop", loop))
        if max_t > 0:
            frames = frames[: max(1, int(round(max_t * px["fps"])))]
        while len(frames) > 1 and frames[0].getbbox() is None:
            frames.pop(0)   # start on the first frame that shows something
        while len(frames) > 1 and frames[-1].getbbox() is None:
            frames.pop()    # and end on the last
        # crop every frame to the union of what is ever drawn
        box = None
        for f in frames:
            b = f.getbbox()
            if b:
                box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
        box = box or (0, 0, 1, 1)
        fw, fh = box[2] - box[0], box[3] - box[1]
        cols = max(1, math.ceil(math.sqrt(len(frames) * fh / max(fw, 1))))
        rows = math.ceil(len(frames) / cols)
        out = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            out.alpha_composite(f.crop(box), ((i % cols) * fw, (i // cols) * fh))
        out.save(os.path.join(OUT, name + ".png"))
        pivot = px.get("pivot") or [w / 2, h]
        table.append((name, fx_id, fw, fh, cols, len(frames), px["fps"], loop, pivot[0] - box[0], pivot[1] - box[1]))
        print("%-12s %-28s %3d frames %4dx%-4d -> %dx%d" % (name, fx_id, len(frames), fw, fh, out.size[0], out.size[1]))
        shutil.rmtree(tmp, ignore_errors=True)
    with open(os.path.join(ROOT, "scripts", "match", "fx_sheets.gd"), "w") as f:
        f.write("class_name FxSheets\n")
        f.write("## Generated by tools/import_fx.py: the effect sprite sheets in res://assets/fx/.\n")
        f.write("## Each: frame size, columns, frame count, fps, loop, pivot (pixels from the frame's\n")
        f.write("## top-left: the spot that sits on the effect's position, e.g. the ground under it).\n")
        f.write("## Effects from pixelfx (MIT): https://github.com/patch-gg/pixelfx\n\n")
        f.write("const SHEETS := {\n")
        for name, fx_id, fw, fh, cols, n, fps, loop, pvx, pvy in table:
            f.write('\t"%s": {"w": %d, "h": %d, "cols": %d, "frames": %d, "fps": %d, "loop": %s, "pivot": Vector2(%.1f, %.1f)},   # %s\n'
                    % (name, fw, fh, cols, n, fps, "true" if loop else "false", pvx, pvy, fx_id))
        f.write("}\n")
    print("wrote scripts/match/fx_sheets.gd")
    return 0


if __name__ == "__main__":
    sys.exit(main())
