#!/usr/bin/env python3
"""Placeholder app icon (a golden cheese wedge), until the new art arrives:

    assets/ui/app_icon.png   256x256, used for the window and the macOS/Linux builds
    assets/ui/app_icon.ico   16-256 px sizes, embedded in the Windows exe

Drawn at 32x32 and scaled up with nearest-neighbour so it stays crisp.
Replace both files with your own art any time (keep the names).

    python3 tools/make_app_icon.py
"""
import os
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "ui")
N = 32
O = (40, 26, 14, 255)
Y = {"h": (255, 236, 140, 255), "l": (250, 206, 72, 255), "m": (232, 170, 40, 255), "d": (178, 112, 24, 255)}
HOLE = (176, 110, 30, 255)


def draw() -> Image.Image:
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    px = img.load()
    # a wedge: top face slanting up to the right, front face below it
    for y in range(N):
        for x in range(N):
            top_y = 13 - (x - 3) * 0.32           # the slanted top edge
            if 3 <= x <= 28 and top_y <= y <= 26:
                if y < top_y + 5:
                    c = Y["h"] if y < top_y + 1.5 else Y["l"]   # the top face, lit
                elif x > 24:
                    c = Y["d"]                                  # the cut side, in shade
                else:
                    c = Y["m"]
                px[x, y] = c
    for cx, cy, r in ((9, 19, 2.2), (17, 22, 1.6), (21, 16, 1.3), (12, 24, 1.1)):
        for y in range(N):
            for x in range(N):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r and px[x, y][3]:
                    px[x, y] = HOLE
    # outline
    out = img.copy()
    po = out.load()
    for y in range(N):
        for x in range(N):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < N and 0 <= yy < N and px[xx, yy][3]:
                    po[x, y] = O
                    break
    return out


def main() -> None:
    img = draw().resize((256, 256), Image.NEAREST)
    img.save(os.path.join(OUT, "app_icon.png"))
    img.save(os.path.join(OUT, "app_icon.ico"), sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("wrote assets/ui/app_icon.png and app_icon.ico")


if __name__ == "__main__":
    main()
