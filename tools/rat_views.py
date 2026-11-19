#!/usr/bin/env python3
"""Front and back views of the rats, so you can tell which way a rat is facing
(and whether it's looking at you). The original drawings in assets/rats/<class>.png
are the SIDE view (turned to the right; the game mirrors them for the left).
This draws two more sheets per class, in the same layout and colours:

    assets/rats/<class>_front.png   facing you: both eyes, nose and whiskers
    assets/rats/<class>_back.png    walking away: back of the head, tail

Same 72 x 72 cells, same rows (see tools/rat_sheets.py). Only idle, run and jump
are drawn; every other row is left empty, and the game falls back to the side
view for an empty cell (a rat digging or bonking shows its side). Paint over
these, or fill in more rows, any time: anything MAGENTA is team colour, exactly
like the side sheets.

Every rat is built from simple shaded shapes (lit from the upper left, like the
side art), outlined in the same dark brown, and posed per frame.

    python3 tools/rat_views.py              # all classes
    python3 tools/rat_views.py preview DIR  # also DIR/views_<class>.png, enlarged, side by side
"""
import colorsys
import math
import os
import sys
from PIL import Image

CELL = 72
COLS = 4
ANIMS = ["idle", "run", "jump", "dig", "attack", "hurt", "build", "use", "down"]
DRAWN = {"idle": 2, "run": 4, "jump": 3}
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
RATS = os.path.join(ROOT, "assets", "rats")
CX = 35.5                          # the figure's centre line (pixel x mirrors to 71 - x)
OUTLINE = (28, 22, 27)
LIGHT = (-0.5, -0.62, 0.6)         # from the upper left and in front, like the side art


def ramp(rgb, spread=1.0):
    """Five tones, darkest first. Shadows lean purple, highlights lean warm."""
    h, s, v = colorsys.rgb_to_hsv(*[c / 255 for c in rgb])
    out = []
    for dv, ds, dh in ((-0.5, 0.12, -0.03), (-0.27, 0.07, -0.015), (0, 0, 0), (0.16, -0.08, 0.012), (0.3, -0.16, 0.022)):
        hh = (h + dh * spread) % 1.0
        ss = min(1.0, max(0.0, s + ds * spread))
        vv = min(1.0, max(0.04, v * (1 + dv * spread) if dv < 0 else v + (1 - v) * dv * spread * 1.6))
        r, g, b = colorsys.hsv_to_rgb(hh, ss, vv)
        out.append((round(r * 255), round(g * 255), round(b * 255)))
    return out


def team_ramp():
    """Magenta: the game swaps this hue for Blue or Red (keep it 0.76-0.90)."""
    return [(80, 16, 84), (128, 26, 134), (178, 36, 182), (226, 74, 230), (245, 140, 246)]


# ---------------------------------------------------------------- classes

FUR = {"digger": (128, 112, 126), "scout": (150, 118, 128), "builder": (176, 124, 108), "saboteur": (150, 116, 128)}
PANTS = {"digger": (112, 100, 118), "scout": (118, 104, 116), "builder": (140, 128, 138), "saboteur": (120, 106, 118)}
SHOE = (214, 150, 104)
SKIN = (226, 170, 156)             # ears, nose, paws, tail
MUZZLE = (240, 222, 206)


# ---------------------------------------------------------------- drawing

class Canvas:
    def __init__(self):
        self.col = [[None] * CELL for _ in range(CELL)]
        self.z = [[-1] * CELL for _ in range(CELL)]
        self.part = [[0] * CELL for _ in range(CELL)]
        self.lines = [[True] * CELL for _ in range(CELL)]   # may carry an inner outline
        self.next_part = 1

    def new_part(self):
        self.next_part += 1
        return self.next_part - 1

    def put(self, x, y, c, z, pid, lines=True):
        if 0 <= x < CELL and 0 <= y < CELL and z >= self.z[y][x]:
            self.col[y][x] = c
            self.z[y][x] = z
            self.part[y][x] = pid
            self.lines[y][x] = lines


def shade(tones, nx, ny, nz, bias=0.0):
    l = math.sqrt(sum(c * c for c in LIGHT))
    k = (nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]) / l + bias
    if k < -0.05:
        return tones[0]
    if k < 0.3:
        return tones[1]
    if k < 0.62:
        return tones[2]
    if k < 0.86:
        return tones[3]
    return tones[4]


def blob(cv, cx, cy, rx, ry, tones, z, p=2.0, clip=None, bias=0.0, lines=True, flat=False):
    """A shaded superellipse (p=2 ellipse, bigger p = boxier)."""
    pid = cv.new_part()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx = (x + 0.5 - cx) / rx
            dy = (y + 0.5 - cy) / ry
            d = abs(dx) ** p + abs(dy) ** p
            if d > 1.0 or (clip and not clip(x, y)):
                continue
            if flat:
                c = tones[2]
            else:
                nz = math.sqrt(max(0.0, 1.0 - min(1.0, d)))
                c = shade(tones, dx * 0.9, dy * 0.9, nz, bias)
            cv.put(x, y, c, z, pid, lines)
    return pid


def dot(cv, x, y, c, z, pid=0):
    cv.put(int(x), int(y), c, z, pid, False)


def sym(cv, x, y, c, z, pid=0):
    """A detail pixel and its mirror image."""
    dot(cv, x, y, c, z, pid)
    dot(cv, 71 - x, y, c, z, pid)


def finish(cv):
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()
    for y in range(CELL):
        for x in range(CELL):
            c = cv.col[y][x]
            if c is None:
                # outline: any empty pixel touching the figure (8 ways, for a bold edge)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < CELL and 0 <= yy < CELL and cv.col[yy][xx] is not None:
                            c = OUTLINE
                if c is not None:
                    px[x, y] = c + (255,)
                continue
            # inner lines: the edge of a lower part where a higher part lies on it
            if cv.lines[y][x]:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < CELL and 0 <= yy < CELL and cv.col[yy][xx] is not None \
                            and cv.part[yy][xx] != cv.part[y][x] and cv.z[yy][xx] > cv.z[y][x] and cv.lines[yy][xx]:
                        c = tuple((a + b) // 2 for a, b in zip(OUTLINE, c))
                        c = tuple((a * 3 + b) // 4 for a, b in zip(OUTLINE, c))
                        break
            px[x, y] = c + (255,)
    return img


# ---------------------------------------------------------------- the rat

class Pose:
    def __init__(self, body=0, head=0, lfoot=0, rfoot=0, larm=0, rarm=0, tail=0.0, squat=0, arms_up=False, spread=0):
        self.body = body        # torso drop (+ = down)
        self.head = head        # extra head drop
        self.lfoot = lfoot      # foot lift (+ = up)
        self.rfoot = rfoot
        self.larm = larm        # paw lift
        self.rarm = rarm
        self.tail = tail        # tail swing, -1..1
        self.squat = squat      # legs bent: torso lower, feet wider
        self.arms_up = arms_up
        self.spread = spread    # feet apart


POSES = {
    "idle": [Pose(), Pose(body=1, head=0)],
    "run": [Pose(body=-1, lfoot=3, rfoot=0, larm=-2, rarm=2, tail=-1.0), Pose(body=0, tail=0.0),
            Pose(body=-1, lfoot=0, rfoot=3, larm=2, rarm=-2, tail=1.0), Pose(body=0, tail=0.0)],
    "jump": [Pose(body=3, squat=2, larm=2, rarm=2, spread=1), Pose(body=-1, lfoot=2, rfoot=2, arms_up=True, tail=0.6),
             Pose(body=0, lfoot=3, rfoot=1, larm=-3, rarm=-3, tail=-0.6, spread=1)],
}


def draw_rat(cls, view, pose):
    cv = Canvas()
    fur = ramp(FUR[cls])
    pants = ramp(PANTS[cls])
    shoe = ramp(SHOE)
    skin = ramp(SKIN)
    team = team_ramp()
    front = view == "front"
    b = pose.body + pose.squat
    hy = b + pose.head            # head offset
    # feet and legs
    for side in (-1, 1):
        lift = pose.lfoot if side < 0 else pose.rfoot
        fx = CX + side * (4.6 + pose.spread + pose.squat * 0.5)
        blob(cv, fx, 56.4 + b * 0.5 - lift * 0.6, 2.7, 3.8 - pose.squat * 0.6, pants, 10, p=2.6)
        blob(cv, fx + side * (0.6 if front else 0.0), 60.7 - lift, 3.9 if front else 3.4, 2.1, shoe, 12, p=2.2, bias=0.1)
    # torso: shirt, with the pants below
    blob(cv, CX, 47.0 + b, 8.0, 7.6, team, 20, p=2.4)
    blob(cv, CX, 52.2 + b, 7.6, 3.0, pants, 21, p=2.6, clip=lambda x, y: y >= 51 + b)
    # arms hang at the sides: fur, a short sleeve on top, a paw below
    for side in (-1, 1):
        up = pose.larm if side < 0 else pose.rarm
        ax = CX + side * 8.6
        if pose.arms_up:
            blob(cv, ax + side * 1.2, 38.5 + b, 2.1, 4.6, fur, 30, p=2.2)
            blob(cv, ax + side * 0.6, 42.4 + b, 2.6, 2.4, team, 31)
            blob(cv, ax + side * 1.4, 34.2 + b, 2.2, 2.1, skin, 32)
        else:
            blob(cv, ax, 46.6 + b - up * 0.5, 2.2, 4.8, fur, 30, p=2.2)
            blob(cv, ax - side * 0.2, 42.6 + b - up * 0.3, 2.6, 2.4, team, 31)
            blob(cv, ax + side * 0.3, 51.0 + b - up, 2.1, 2.0, skin, 32, bias=0.1)
    # the tail: out of the lower back and curling up past the side, seen from behind
    if not front:
        pid = cv.new_part()
        sw = pose.tail
        for i in range(41):
            t = i / 40
            x = CX - 1.0 - 12.0 * t + sw * 2.0 * t * t
            y = 51.5 + b + 6.0 * math.sin(t * 2.6) - 13.0 * t * t
            th = 1.5 - 0.6 * t
            for yy in range(int(y - th) - 1, int(y + th) + 2):
                for xx in range(int(x - th) - 1, int(x + th) + 2):
                    if (xx + 0.5 - x) ** 2 + (yy + 0.5 - y) ** 2 <= th * th:
                        cv.put(xx, yy, skin[3] if yy + 0.5 < y else skin[2], 65, pid)
    # head
    for side in (-1, 1):   # ears
        ex = CX + side * 13.6
        blob(cv, ex, 25.6 + hy, 5.6, 5.6, fur, 38, bias=0.05)
        if front:
            blob(cv, ex + side * 0.4, 26.2 + hy, 3.5, 3.6, skin, 39, bias=0.15, lines=False)
    blob(cv, CX, 31.0 + hy, 13.4, 10.2, fur, 40, bias=0.12 if front else 0.22)
    if front:
        blob(cv, CX, 36.4 + hy, 4.2, 2.8, ramp((222, 196, 190)), 41, bias=0.15, lines=False)
        for side in (-1, 1):   # eyes, with a catch light
            ex = CX + side * 5.2
            for y in range(int(30.2 + hy), int(33.2 + hy) + 1):
                for x in (int(ex - 0.5), int(ex + 0.5)):
                    dot(cv, x, y, (20, 14, 18), 45)
            dot(cv, int(ex - 0.5 * side), int(30.2 + hy), (250, 248, 240), 46)
            dot(cv, int(ex + 0.5 * side), int(33.2 + hy), (66, 50, 64), 46)
        # nose, mouth, whiskers
        for x, y, c in ((-1, 0, skin[1]), (0, 0, skin[1]), (-1, -1, skin[3]), (0, -1, skin[2]), (-1, 1, skin[0]), (0, 1, skin[0])):
            dot(cv, CX + x + 0.5, 35.2 + hy + y, c, 47)
        sym(cv, 35, int(37.6 + hy), (96, 56, 66), 47)
        sym(cv, 34, int(37.6 + hy), (150, 110, 116), 47)
        for wx, wy in ((28, 36), (27, 35), (28, 38), (27, 39)):
            sym(cv, wx, int(wy + hy), (210, 198, 200), 48)
    hat(cv, cls, front, hy)
    if cls == "builder":
        backpack(cv, front, b)
    if cls == "digger":
        belt(cv, front, b)
    return finish(cv)


def hat(cv, cls, front, hy):
    if cls == "digger":
        yel = ramp((240, 186, 50))
        blob(cv, CX, 24.4 + hy, 12.8, 8.8, yel, 60, clip=lambda x, y: y <= 26 + hy)
        blob(cv, CX, 26.8 + hy, 15.6, 2.3, ramp((246, 206, 72)), 61, p=2.4, bias=0.1)
        if front:   # the lamp
            blob(cv, CX, 21.4 + hy, 3.4, 3.1, ramp((150, 110, 70)), 62, flat=True)
            blob(cv, CX, 21.4 + hy, 2.3, 2.1, ramp((255, 246, 214)), 63, bias=0.4, lines=False)
            dot(cv, CX - 1, 20.4 + hy, (255, 255, 255), 64)
        else:
            for x in range(int(CX - 7), int(CX + 8)):
                dot(cv, x, 25 + hy, yel[1], 62)
    elif cls in ("scout", "saboteur"):
        if cls == "saboteur":   # a team beanie
            blob(cv, CX, 25.0 + hy, 13.0, 8.8, team_ramp(), 60, clip=lambda x, y: y <= 27 + hy)
            for x in range(int(CX - 12), int(CX + 13)):
                dot(cv, x, 27 + hy, team_ramp()[1] if x % 2 else team_ramp()[2], 61)
        strap = ramp((170, 92, 40))
        gy = 24.2 + hy
        for x in range(int(CX - 13), int(CX + 14)):
            dot(cv, x, gy, strap[2], 62)
            dot(cv, x, gy + 1, strap[1], 62)
        if front:   # the goggles, pushed up on the forehead
            for side in (-1, 1):
                gx = CX + side * 4.6
                blob(cv, gx, gy + 0.2, 4.2, 3.9, ramp((214, 124, 46)), 63, flat=False)
                blob(cv, gx, gy + 0.2, 2.7, 2.5, team_ramp(), 64, bias=0.3, lines=False)
                dot(cv, gx - 1, gy - 1, (255, 220, 255), 65)
        else:   # the buckle at the back
            blob(cv, CX, gy + 0.5, 2.0, 1.6, ramp((190, 190, 200)), 63, flat=True)
    elif cls == "builder":   # a team cap with a peak
        blob(cv, CX, 24.2 + hy, 13.0, 8.8, team_ramp(), 60, clip=lambda x, y: y <= 26 + hy)
        dot(cv, CX, 16 + hy, team_ramp()[4], 61)
        if front:
            blob(cv, CX, 26.6 + hy, 12.0, 1.9, ramp((168, 206, 230)), 61, p=2.2, bias=0.1)
            blob(cv, CX, 21.4 + hy, 2.4, 2.4, ramp((236, 236, 240)), 62, flat=True, lines=False)
        else:   # the strap gap
            for y in range(int(23 + hy), int(26 + hy)):
                dot(cv, CX, y, team_ramp()[0], 61)
                dot(cv, CX + 1, y, (60, 40, 50), 61)


def backpack(cv, front, b):
    pack = ramp((198, 120, 56))
    if front:   # just the straps over the shoulders
        for side in (-1, 1):
            for y in range(int(39 + b), int(47 + b)):
                dot(cv, CX + side * 5.5 + (0.5 if side > 0 else -0.5), y, pack[1], 35)
    else:
        blob(cv, CX, 46.0 + b, 8.4, 7.6, pack, 70, p=3.0)
        blob(cv, CX, 49.0 + b, 6.0, 3.2, ramp((176, 100, 44)), 71, p=3.0)
        for x in range(int(CX - 7), int(CX + 8)):
            dot(cv, x, 42 + b, pack[1], 72)
        dot(cv, CX, 43 + b, (230, 220, 160), 73)


def belt(cv, front, b):
    tone = ramp((150, 92, 52))
    for x in range(int(CX - 9), int(CX + 10)):
        dot(cv, x, 50 + b, tone[2], 25)
        dot(cv, x, 51 + b, tone[1], 25)
    if front:
        for x, y in ((0, 0), (1, 0), (0, 1), (1, 1)):
            dot(cv, CX - 0.5 + x, 50 + b + y, (236, 196, 90), 26)
    else:
        for side in (-1, 1):   # a hammer and a pick handle tucked in the belt
            for y in range(int(46 + b), int(52 + b)):
                dot(cv, CX + side * 6.5, y, tone[3], 26)


def sheet(cls, view):
    img = Image.new("RGBA", (COLS * CELL, len(ANIMS) * CELL), (0, 0, 0, 0))
    for row, anim in enumerate(ANIMS):
        for f, pose in enumerate(POSES.get(anim, [])):
            img.alpha_composite(draw_rat(cls, view, pose), (f * CELL, row * CELL))
    return img


def main(argv):
    classes = ["digger", "scout", "builder", "saboteur"]
    preview = argv[2] if len(argv) > 2 and argv[1] == "preview" else None
    for cls in classes:
        sheets = {}
        for view in ("front", "back"):
            sheets[view] = sheet(cls, view)
            sheets[view].save(os.path.join(RATS, "%s_%s.png" % (cls, view)))
        if preview:
            side = Image.open(os.path.join(RATS, "%s.png" % cls)).convert("RGBA")
            s = 4
            out = Image.new("RGBA", (COLS * CELL * s, 3 * 3 * CELL * s), (70, 92, 70, 255))
            for k, img in enumerate((side, sheets["front"], sheets["back"])):
                part = img.crop((0, 0, COLS * CELL, 3 * CELL)).resize((COLS * CELL * s, 3 * CELL * s), Image.NEAREST)
                out.alpha_composite(part, (0, k * 3 * CELL * s))
            out.save(os.path.join(preview, "views_%s.png" % cls))
        print("wrote assets/rats/%s_front.png, %s_back.png" % (cls, cls))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
