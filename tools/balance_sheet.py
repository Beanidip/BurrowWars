#!/usr/bin/env python3
"""Builds the balance chart from the code: every tunable number, what it does,
what it means in play, and the file and line to change it.

    python3 tools/balance_sheet.py

writes docs/BALANCE.md (to read) and docs/balance.csv (to open in a
spreadsheet, with a Notes column). Run it again after changing any value: the
chart always shows what the game really uses.
"""
import csv
import math
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONST_RE = re.compile(r"^(?:static )?const (\w+)\s*:?=\s*(.+?)\s*(?:#\s*(.*))?$")


def read_consts(rel):
    """name -> (value text, comment, line) for one-line constants in a file."""
    out = {}
    for i, line in enumerate((ROOT / rel).read_text().splitlines(), 1):
        m = CONST_RE.match(line)
        if m and not m.group(2).endswith(("{", "[")):
            out[m.group(1)] = (m.group(2).strip(), (m.group(3) or "").strip(), i)
    return out


def find_line(rel, pattern, after=None):
    """(captured value, line) of the first line matching a regex; with `after`,
    the first match at or below the first line matching that anchor."""
    lines = (ROOT / rel).read_text().splitlines()
    start = 0
    if after is not None:
        start = next((i for i, line in enumerate(lines) if re.search(after, line)), None)
        if start is None:
            raise SystemExit(f"balance_sheet: '{after}' not found in {rel} (the code moved: update this script)")
    for i in range(start, len(lines)):
        m = re.search(pattern, lines[i])
        if m:
            return (m.group(1) if m.groups() else m.group(0)).strip(), i + 1
    raise SystemExit(f"balance_sheet: '{pattern}' not found in {rel} (the code moved: update this script)")


def num(text):
    try:
        return float(text)
    except ValueError:
        return None


FILES = {
    "cfg": "scripts/core/config.gd",
    "rat": "scripts/actors/rat.gd",
    "siege": "scripts/match/siege.gd",
    "dyn": "scripts/match/dynamite.gd",
    "wind": "scripts/match/windup.gd",
    "bot": "scripts/actors/bot_brain.gd",
    "map": "scripts/world/map_generator.gd",
    "blocks": "scripts/world/blocks.gd",
    "ac": "scripts/net/anti_cheat.gd",
    "net": "scripts/net/net_server.gd",
    "crumbs": "scripts/match/crumb_trail.gd",
}
CONSTS = {k: read_consts(v) for k, v in FILES.items()}
C = CONSTS["cfg"]
R = CONSTS["rat"]
G = 24.0 if "GRAVITY" not in R else float(R["GRAVITY"][0])


def height(speed):
    return speed * speed / (2 * G)


# derived "what it means" notes, computed from the live values
def v(key, name):
    return num(CONSTS[key][name][0])


DERIVED = {
    ("rat", "JUMP_SPEED"): lambda: f"jumps {height(v('rat', 'JUMP_SPEED')):.1f} blocks high",
    ("rat", "DOUBLE_JUMP_SPEED"): lambda: f"+{height(v('rat', 'DOUBLE_JUMP_SPEED')):.1f} blocks from the top of a jump",
    ("rat", "SPRING_SPEED"): lambda: f"about {height(v('rat', 'SPRING_SPEED')):.1f} blocks up",
    ("cfg", "SPRING_SIDE_SPEED"): lambda: f"about {height(v('cfg', 'SPRING_SIDE_SPEED')):.1f} blocks up",
    ("cfg", "JETPACK_LIFT"): lambda: f"about {v('cfg', 'JETPACK_LIFT') * v('cfg', 'JETPACK_TIME') + height(v('cfg', 'JETPACK_LIFT')):.0f} blocks of climb per burn",
    ("cfg", "IMPULSE_MAX_UP"): lambda: f"about {height(v('cfg', 'IMPULSE_MAX_UP')):.1f} blocks up at most",
    ("cfg", "DIG_RATE"): lambda: f"dirt in {2 / v('cfg', 'DIG_RATE'):.2f} s, stone in {4 / v('cfg', 'DIG_RATE'):.2f} s",
    ("cfg", "STAMINA_REGEN"): lambda: f"a 100-stamina rat refills in {100 / v('cfg', 'STAMINA_REGEN'):.0f} s",
    ("cfg", "DASH_COST"): lambda: f"{int(100 // v('cfg', 'DASH_COST'))} dashes from a full 100 stamina ({int(150 // v('cfg', 'DASH_COST'))} for the Digger's 150)",
    ("cfg", "BASE_SPEED"): lambda: "see the class table for each class's speed",
    ("cfg", "CANNON_COOLDOWN"): lambda: f"at most {60 / v('cfg', 'CANNON_COOLDOWN'):.0f} shots a minute",
    ("cfg", "TELE_CHARGE"): lambda: f"one trip every {v('cfg', 'TELE_CHARGE') + v('cfg', 'TELE_WAIT'):.1f} s per entrance",
    ("cfg", "BUBBLE_COST"): lambda: "a 10-block bridge costs 20 scrap",
}

# Every row: (file key, constant, description). Section order is the chart's order.
SECTIONS = [
    ("Economy and scrap", "Scrap is the money; cheese banked by either team makes every scrap block worth more.", [
        ("cfg", "BASE_SCRAP_PER_BLOCK", "Scrap you get for mining one scrap block, before the multiplier."),
        ("cfg", "GROWTH_BONUS", "How fast scrap gains value as cheese is banked. Value = 1 + (cheese banked by both teams / goal) x this. At 1.5, scrap is worth 2.5x by the time a team wins."),
        ("cfg", "STACK_MAX", "Most of one gadget you can carry (a workshop item can set a lower 'max')."),
        ("cfg", "STASH_REACH", "How close (blocks) you must stand to a Team Stash to use it."),
        ("cfg", "STASH_BLASTS", "TNT blasts that break a Team Stash."),
        ("map", "CHEESE_PER_GOAL", "A Cheese Race map always holds at least this many cheese per point of goal (goal 8 -> 20+ cheese)."),
    ]),
    ("Movement and stamina", "Speeds are in blocks per second; 1 block is about one rat tall.", [
        ("cfg", "BASE_SPEED", "Walking speed at class speed 1.0 (each class multiplies it)."),
        ("cfg", "CARRY_SPEED", "Speed multiplier while carrying 0, 1, 2 and 3+ cheese."),
        ("rat", "GRAVITY", "How fast everything falls (also sets jump heights)."),
        ("rat", "JUMP_SPEED", "Upward speed of a jump."),
        ("rat", "DOUBLE_JUMP_SPEED", "Upward speed of the double jump (costs stamina, see below)."),
        ("cfg", "DOUBLE_JUMP_COST", "Stamina a double jump costs."),
        ("rat", "DASH_SPEED", "Speed of a dash burst."),
        ("cfg", "DASH_COST", "Stamina a dash costs when you carry no cheese."),
        ("cfg", "DASH_CARRY", "Dash strength while carrying 0, 1, 2 and 3+ cheese."),
        ("cfg", "DASH_CARRY_COST", "Stamina a dash costs while carrying any cheese."),
        ("cfg", "STAMINA_REGEN", "Stamina regained per second (not while dashing)."),
        ("rat", "SPRING_SPEED", "How hard a Spring launches whoever lands on it."),
        ("cfg", "SPRING_SIDE_SPEED", "Springs also fling anything standing right next to them, this hard."),
        ("cfg", "WALL_SPRING_SPEED", "How hard a Wall Spring shoves anyone within a block of it."),
        ("cfg", "POUND_HEIGHT", "Ground pound: a double jump landed flat thumps the block below if you got at least this share of its full height."),
        ("cfg", "POUND_COOLDOWN", "Seconds between ground pounds."),
    ]),
    ("Digging and building", "", [
        ("cfg", "DIG_RATE", "Dig hits per second while holding dig."),
        ("cfg", "DIG_REACH", "How far (blocks) you can dig, build and bonk from your eyes."),
        ("blocks", "OBSIDIAN_HITS", "Dig hits to break obsidian (other blocks are in the block table below)."),
        ("cfg", "CHISEL_RATE", "Chisel edits (one microvoxel each) per second."),
        ("cfg", "PANTOGRAPH_MAX", "Biggest blueprint the pantograph copies, in blocks per side."),
    ]),
    ("Cheese, bonks and raids", "", [
        ("cfg", "BONK_COOLDOWN", "Seconds between your bonks."),
        ("cfg", "BONK_RANGE", "How close (blocks) a rat must be to bonk it."),
        ("cfg", "BONK_PICKUP_LOCK", "Seconds a bonked rat can't pick its dropped cheese back up."),
        ("cfg", "RAID_TIME", "Seconds you stand in the enemy base to steal one cheese they banked (a defender in their base stops it)."),
        ("cfg", "LOBBY_LAUNCH", "In the playground lobby, bonks and cannonballs throw rats this many times harder."),
        ("cfg", "CRUMB_EVERY", "Blocks a cheese carrier walks between the crumbs they drop."),
        ("cfg", "CRUMB_TIME", "Seconds a crumb stays on the ground."),
    ]),
    ("Traps and tricks", "", [
        ("cfg", "TRAP_HITS_OWN", "Dig hits for a team to clear its own trap."),
        ("cfg", "TRAP_HITS_ENEMY", "Dig hits for the other team to clear a trap (a blast counts too)."),
        ("cfg", "DECOY_STUN", "Seconds an enemy is dazed after digging a Cheese Decoy."),
        ("cfg", "SQUEAKER_USES", "Squeaks before a Squeaker Pad is spent."),
        ("cfg", "SQUEAKER_REST", "Seconds between squeaks from one pad."),
        ("cfg", "SQUEAKER_MARK", "Seconds the beacon a squeak drops for its team lasts."),
        ("cfg", "WINDUP_FUSE", "Seconds a Wind-up Decoy marches before going off by itself."),
        ("wind", "BLINK", "Seconds of '!!' warning before a Wind-up goes off by itself."),
        ("cfg", "WINDUP_MAX_ACTIVE", "Wind-ups marching at once (both teams)."),
        ("cfg", "TELE_WAIT", "Seconds standing on a charged teleporter entrance before it sends you."),
        ("cfg", "TELE_CHARGE", "Seconds an entrance recharges after each trip."),
    ]),
    ("Explosives", "Blast power is in dig hits at the centre, falling to nothing at the radius.", [
        ("cfg", "TNT_RADIUS", "Placed TNT: blast radius in blocks."),
        ("cfg", "TNT_POWER", "Placed TNT: dig hits at the centre."),
        ("cfg", "DYNAMITE_RADIUS", "Mobile TNT: blast radius in blocks."),
        ("cfg", "DYNAMITE_POWER", "Mobile TNT: dig hits at the centre."),
        ("cfg", "DYNAMITE_FUSE", "Mobile TNT: seconds from throw to boom."),
        ("cfg", "DYNAMITE_THROW_SPEED", "Mobile TNT and Impulse Grenades: how hard they're thrown."),
        ("cfg", "DYNAMITE_MAX_ACTIVE", "Sticks and grenades in the air at once (everyone together)."),
        ("cfg", "IMPULSE_FUSE", "Impulse Grenade: seconds from sticking to bursting."),
        ("cfg", "IMPULSE_FLIGHT", "Impulse Grenade: bursts in mid-air after this long if it hits nothing."),
        ("cfg", "IMPULSE_RADIUS", "Impulse Grenade: blocks it pushes things within."),
        ("cfg", "IMPULSE_PUSH", "Impulse Grenade: speed it throws a rat at right beside it (half at the edge)."),
        ("cfg", "IMPULSE_LIFT", "Impulse Grenade: extra upward speed, scaled the same way."),
        ("cfg", "IMPULSE_MAX_UP", "Impulse Grenade: the most upward speed it can give."),
        ("cfg", "IMPULSE_CARRY", "Impulse Grenade: a cheese carrier is pushed this much as hard."),
        ("cfg", "GATE_HP", "Hits a Team Gate takes before breaking: wrecking ball hits count 1, a TNT blast 5."),
    ]),
    ("Gear", "One piece worn at a time; the gear button (J) uses it.", [
        ("cfg", "JETPACK_TIME", "Jetpack: seconds of thrust per use."),
        ("cfg", "JETPACK_LIFT", "Jetpack: upward speed while thrusting."),
        ("cfg", "JETPACK_COOLDOWN", "Jetpack: seconds after the thrust ends before it can fire again."),
        ("cfg", "JETPACK_CARRY", "Jetpack: lift while carrying cheese (0.5 = half)."),
        ("cfg", "SHIELD_TIME", "Rat Knight Shield: seconds it stays raised (bonks and cannonballs bounce off)."),
        ("cfg", "SHIELD_COOLDOWN", "Rat Knight Shield: seconds after it drops before you can raise it again."),
        ("cfg", "SHIELD_CARRY_SPEED", "Rat Knight Shield: speed while raised and carrying cheese."),
        ("cfg", "BUBBLE_COST", "Bubble Shoes: scrap per bubble you step onto."),
        ("cfg", "BUBBLE_TIME", "Bubble Shoes: seconds a bubble lasts before it pops."),
    ]),
    ("Siege machines", "", [
        ("cfg", "CANNON_SCRAP", "Scrap Cannon: scrap each shot costs the gunner (free in Free Build and the playground)."),
        ("cfg", "CANNON_COOLDOWN", "Scrap Cannon: seconds between shots."),
        ("cfg", "CANNON_SPEED", "Scrap Cannon: speed of the cannonball (higher = flatter, longer shots)."),
        ("siege", "SHOT_GRAVITY", "Scrap Cannon: how fast cannonballs drop."),
        ("cfg", "CANNON_HIT", "Scrap Cannon: dig hits on the struck block; the six touching it take 2, the rest of the 3x3x3 take 1."),
        ("cfg", "CANNON_PUSH", "Scrap Cannon: speed a direct hit throws a rat at."),
        ("cfg", "CANNON_LIFT", "Scrap Cannon: the upward part of that throw."),
        ("cfg", "CANNON_SPLASH", "Scrap Cannon: blocks from the impact the blast still shoves enemy rats."),
        ("cfg", "CRANE_MIN_SPEED", "Wrecking Crane: the ball must swing at least this fast (blocks/s) to do damage."),
        ("siege", "BALL_KEEP_BROKE", "Wrecking Crane: share of its speed the ball keeps after smashing a block to pieces."),
        ("siege", "BALL_KEEP_HELD", "Wrecking Crane: share it keeps after hitting a block that held (it still goes through)."),
        ("siege", "CRANE_CABLE", "Wrecking Crane: cable length (longer = wider, slower swing)."),
        ("siege", "CRANE_REACH", "Wrecking Crane: boom length (how far out the ball hangs)."),
        ("cfg", "CRANE_MAX_HIT", "Not used by the game any more (left over; safe to ignore)."),
        ("cfg", "DOZER_COOLDOWN", "Bulldozer: seconds between rams."),
        ("cfg", "DOZER_HIT", "Bulldozer: dig hits on each of the 6 blocks (3 wide, 2 high) in front of the blade."),
        ("cfg", "MACHINE_MOVE_TIME", "Seconds a machine takes to ride one block along a conveyor."),
    ]),
    ("Bots", "", [
        ("cfg", "BOT_RAID_GUARDED", "Bots give up raiding a base its team has stood guard in for this many seconds."),
        ("cfg", "WINDUP_CHASE", "Bots chase a cheese carrier (or a Wind-up that looks like one) within this many blocks."),
        ("bot", "SCRAP_REACH", "How far (blocks) a bot looks for scrap to mine on the side."),
        ("bot", "SCRAP_ENOUGH", "A bot this rich stops making detours for scrap."),
    ]),
    ("Map", "", [
        ("map", "FLAT_RADIUS", "Terrain is levelled this far (blocks) around each base."),
        ("map", "CAVE_SYSTEMS", "Cave networks per half of the map."),
        ("map", "CAVE_ENTRANCES", "Caves per half that climb out to the surface."),
        ("map", "CAVE_LAVA_Y", "Cave cells this deep (block height) fill with lava."),
        ("map", "BASE_SIZE", "Width of each base platform in blocks."),
    ]),
    ("Online: server checks (change with care)", "Generous on purpose: lag must never cost an honest player more than a rare correction. If you add a new way to move, raise the matching limit.", [
        ("net", "MAX_SPEED", "Fastest (blocks/s) a player's reported movement may be."),
        ("ac", "JUMP_RISE", "Highest (blocks) a rat may rise since it last stood on something, from jumps."),
        ("ac", "SPRING_RISE", "...near a spring."),
        ("ac", "JET_RISE", "...extra when wearing a jetpack."),
        ("ac", "INSIDE_GRACE", "Seconds a rat may report itself inside a block before it's put back."),
        ("ac", "STRIKE_LIMIT", "Strikes before a dedicated server removes a player."),
        ("ac", "STRIKE_FADE", "Seconds for one strike to be forgiven."),
        ("net", "SNAP_EVERY", "Physics frames between world updates to players (3 = 20 a second)."),
    ]),
]

# numbers written straight into the game logic: (label, file, regex capturing the value, description)
HARD_CODED = [
    ("Starting scrap", "scripts/match/match.gd", r"rat\.scrap = (\d+)", "Scrap every rat starts a match with."),
    ("Bonk throw (sideways)", "scripts/match/match.gd", r"target\.vel = \(dir \* ([\d.]+)", "How hard a bonk shoves the bonked rat away."),
    ("Bot rest times", "scripts/ui/main_menu.gd", r'"bot_rest": (\[[^\]]+\])', "Seconds bots pause between decisions for Relaxed, Normal and Fierce."),
    ("Default cheese goal", "scripts/core/config.gd", r'"goal": (\d+)', "Goal offered in the Cheese Race setup the first time (players can change it, 3-250)."),
    ("Highway speed boost", "scripts/actors/rat.gd", r"s \*= ([\d.]+)", "Speed multiplier while running on a Highway (1.6 = 60% faster).", r"== Blocks\.HIGHWAY"),
    ("Sticky Trap slow", "scripts/actors/rat.gd", r"s \*= ([\d.]+)", "Speed multiplier while stuck in an enemy Sticky Trap.", r"if slow > 0\.0:"),
]


def section_rows():
    rows = []
    for title, note, items in SECTIONS:
        for key, name, desc in items:
            if name not in CONSTS[key]:
                raise SystemExit(f"balance_sheet: {name} not found in {FILES[key]} (renamed? update this script)")
            value, comment, line = CONSTS[key][name]
            derived = DERIVED.get((key, name), lambda: "")()
            rows.append({"section": title, "name": name, "value": value, "meaning": derived,
                         "what": desc, "where": f"{FILES[key]}:{line}"})
    return rows


def hard_rows():
    rows = []
    for entry in HARD_CODED:
        label, rel, pattern, desc = entry[:4]
        value, line = find_line(rel, pattern, entry[4] if len(entry) > 4 else None)
        rows.append({"section": "Written into the code", "name": label, "value": value, "meaning": "",
                     "what": desc, "where": f"{rel}:{line}"})
    return rows


SHOP_RE = re.compile(r'\{"id": "(\w+)", "name": "([^"]+)", "kind": "(\w+)", "qty": (\d+), "cost": (\d+),(?: "max": (\d+),)? "cat": "(\w+)"')


def shop():
    rel = "scripts/match/class_defs.gd"
    lines = (ROOT / rel).read_text().splitlines()
    items = []
    for i, line in enumerate(lines):
        m = SHOP_RE.search(line)
        if not m:
            continue
        desc = ""
        dm = re.search(r'"desc": "(.*)"\}', lines[i + 1]) if i + 1 < len(lines) else None
        if dm:
            desc = dm.group(1).replace('\\"', '"')
        items.append({"id": m.group(1), "name": m.group(2), "kind": m.group(3), "qty": int(m.group(4)),
                      "cost": int(m.group(5)), "max": m.group(6) or "", "cat": m.group(7), "desc": desc, "line": i + 1})
    cats = re.search(r"const SHOP_CATS := \[([^\]]+)\]", "\n".join(lines)).group(1)
    order = [c.strip().strip('"') for c in cats.split(",")]
    items.sort(key=lambda it: (order.index(it["cat"]) if it["cat"] in order else 99))
    return items, rel


def classes():
    rel = "scripts/match/class_defs.gd"
    text = (ROOT / rel).read_text()
    out = []
    for m in re.finditer(r'\n\t"(\w+)": \{\n(.*?)\n\t\},', text, re.S):
        body = m.group(2)
        line = text[:m.start()].count("\n") + 2

        def field(name, b=body):
            fm = re.search(r'"%s": ([^,\n]+)' % name, b)
            return fm.group(1).strip() if fm else ""
        abil = re.findall(r'\["(\w+)", "([^"]+)", ([\d.]+), ([\d.]+)\]', body)
        kit = re.search(r'"kit": \{([^}]*)\}', body)
        disc = re.search(r'"discount": \{([^}]*)\}', body)
        out.append({"id": m.group(1), "name": field("name").strip('"'), "speed": float(field("speed")),
                    "stamina": float(field("stamina")), "carry": int(field("carry")), "water": float(field("water")),
                    "abilities": abil, "kit": kit.group(1) if kit else "", "discount": disc.group(1) if disc else "",
                    "remote_shop": field("remote_shop") == "true", "fly": field("fly") == "true", "line": line})
    return out, rel


def blocks():
    rel = "scripts/world/blocks.gd"
    lines = (ROOT / rel).read_text().splitlines()
    out = []
    obsidian = int(CONSTS["blocks"]["OBSIDIAN_HITS"][0])
    seen = set()
    for i, line in enumerate(lines, 1):
        m = re.match(r'\s*\["([^"]+)", (\w+), Color', line)
        if not m:
            continue
        name = m.group(1)
        hits = obsidian if m.group(2) == "OBSIDIAN_HITS" else int(m.group(2))
        if name in seen or name == "Air" or name.endswith("Block") and name not in ("Team Block",) or "Glass" in name:
            continue
        seen.add(name)
        out.append((name, hits, i))
    return out, rel


def ball_power(hits, name):
    if hits <= 0:
        return 0
    if name == "Obsidian":
        return (hits + 3) // 4
    if hits <= 3:
        return hits
    return (hits + 1) // 2


def md_escape(s):
    return str(s).replace("|", "\\|")


def main():
    rows = section_rows() + hard_rows()
    items, shop_rel = shop()
    cls, cls_rel = classes()
    blk, blk_rel = blocks()
    dig_rate = float(C["DIG_RATE"][0])
    base_speed = float(C["BASE_SPEED"][0])
    carry = [float(x) for x in C["CARRY_SPEED"][0].strip("[]").split(",")]

    md = ["# Balance chart", "",
          "Every number that shapes how Burrow Wars plays, what it does, and where to change it.",
          "**Generated from the code** by `tools/balance_sheet.py`: after changing a value, run",
          "`python3 tools/balance_sheet.py` and this chart (and `docs/balance.csv`, the same rows for a",
          "spreadsheet, with a Notes column) shows what the game really uses.", "",
          "- **Value** is exactly as written in the code. Speeds are blocks per second; times are seconds.",
          "- **In play** is worked out from the values where it helps (heights, times, rates).",
          "- **Where** is the file and line to edit. Change the value, save, and the game uses it next run.",
          "- Online, the server's values win: players only see a change once your server runs it.", ""]

    md += ["## Contents", ""]
    toc = ["Workshop prices", "Classes", "Block toughness"] + [s[0] for s in SECTIONS] + ["Written into the code"]
    for t in toc:
        anchor = re.sub(r"[^a-z0-9 -]", "", t.lower()).replace(" ", "-")
        md.append(f"- [{t}](#{anchor})")
    md.append("")

    # workshop
    md += ["## Workshop prices", "",
           f"In `{shop_rel}` (`SHOP`): **cost** is scrap for one purchase of **qty** pieces; **max** caps how many you can hold",
           f"(otherwise {C['STACK_MAX'][0]}). Builders pay less for some items (see Classes).", "",
           "| Item | Category | Cost | Qty | Scrap each | Max | What it does | Line |", "|---|---|---:|---:|---:|---:|---|---:|"]
    for it in items:
        each = it["cost"] / it["qty"]
        md.append(f"| {it['name']} | {it['cat']} | {it['cost']} | {it['qty']} | {each:.1f} | {it['max'] or '-'} | {md_escape(it['desc'])} | {it['line']} |")
    md.append("")

    # classes
    md += ["## Classes", "",
           f"In `{cls_rel}` (`CLASSES`). Speed multiplies the base walking speed ({base_speed:g} blocks/s).",
           "Abilities are listed as cooldown seconds / stamina cost.", "",
           "| Class | Speed | Walks at | With 1 / 2 / 3 cheese | Stamina | Carries | Swims | Abilities | Starts with | Notes | Line |",
           "|---|---:|---:|---|---:|---:|---:|---|---|---|---:|"]
    for c in cls:
        walk = base_speed * c["speed"]
        loaded = " / ".join(f"{walk * carry[min(n, len(carry) - 1)]:.1f}" for n in (1, 2, 3))
        ab = "; ".join(f"{a[1]} {float(a[2]):g} s / {float(a[3]):g}" for a in c["abilities"])
        kit = c["kit"].replace('"', "").replace(":", " x").strip() or "-"
        notes = []
        if c["discount"]:
            notes.append("pays less: " + c["discount"].replace('"', "").replace(":", " ="))
        if c["remote_shop"]:
            notes.append("shops anywhere")
        if c["fly"]:
            notes.append("flies (Free Build only)")
        md.append(f"| {c['name']} | {c['speed']:g} | {walk:.1f} | {loaded} | {c['stamina']:g} | {c['carry']} | {c['water']:g} | {ab} | {kit} | {', '.join(notes) or '-'} | {c['line']} |")
    md.append("")

    # blocks
    md += ["## Block toughness", "",
           f"In `{blk_rel}` (`DEFS`, the second column). Dig time at {dig_rate:g} hits a second; the wrecking ball's",
           "hits per blow come from its own rule (soft blocks in one blow, stone-like in two, obsidian in four).", "",
           "| Block | Dig hits | Dig time | Wrecking ball blows | Line |", "|---|---:|---:|---:|---:|"]
    special = {"Team Gate": f"broken by {C['GATE_HP'][0]} wrecking-ball hits or 2 TNT blasts (GATE_HP)",
               "Team Stash": f"broken by {C['STASH_BLASTS'][0]} TNT blasts (STASH_BLASTS)",
               "Scrap Cannon": "picked up by its owner, not dug", "Wrecking Crane": "picked up by its owner, not dug",
               "Bulldozer": "picked up by its owner, not dug", "Water": "liquid", "Lava": "liquid (sends rats home)",
               "Bedrock": "the map floor", "Blue Base": "base platform", "Red Base": "base platform"}
    for name, hits, line in blk:
        if hits <= 0:
            md.append(f"| {name} | can't be dug: {special.get(name, '-')} | - | - | {line} |")
        else:
            bp = ball_power(hits, name)
            md.append(f"| {name} | {hits} | {hits / dig_rate:.2f} s | {math.ceil(hits / bp)} | {line} |")
    md.append("")

    # sections
    for title, note, _ in SECTIONS:
        md += [f"## {title}", ""]
        if note:
            md += [note, ""]
        md += ["| Value | Setting | In play | What it does | Where |", "|---|---|---|---|---|"]
        for r in rows:
            if r["section"] == title:
                md.append(f"| `{md_escape(r['value'])}` | `{r['name']}` | {md_escape(r['meaning'])} | {md_escape(r['what'])} | `{r['where']}` |")
        md.append("")
    md += ["## Written into the code", "",
           "These are written straight into the game logic rather than named. Change them there; ask me to",
           "turn any of them into a named setting.", "",
           "| Value | What | What it does | Where |", "|---|---|---|---|"]
    for r in rows:
        if r["section"] == "Written into the code":
            md.append(f"| `{md_escape(r['value'])}` | {r['name']} | {md_escape(r['what'])} | `{r['where']}` |")
    md.append("")
    (ROOT / "docs/BALANCE.md").write_text("\n".join(md))

    with open(ROOT / "docs/balance.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["Section", "Setting", "Value", "In play", "What it does", "Where", "Notes"])
        for it in items:
            w.writerow(["Workshop", it["name"], f"{it['cost']} scrap for {it['qty']}" + (f" (max {it['max']})" if it["max"] else ""),
                        f"{it['cost'] / it['qty']:.1f} scrap each", it["desc"], f"{shop_rel}:{it['line']}", ""])
        for c in cls:
            w.writerow(["Classes", c["name"], f"speed {c['speed']:g}, stamina {c['stamina']:g}, carries {c['carry']}, swims {c['water']:g}",
                        f"walks {base_speed * c['speed']:.1f} blocks/s",
                        "; ".join(f"{a[1]}: {float(a[2]):g} s cooldown, {float(a[3]):g} stamina" for a in c["abilities"]),
                        f"{cls_rel}:{c['line']}", ""])
        for name, hits, line in blk:
            w.writerow(["Block toughness", name, hits if hits > 0 else "can't be dug",
                        f"{hits / dig_rate:.2f} s to dig" if hits > 0 else "", "", f"{blk_rel}:{line}", ""])
        for r in rows:
            w.writerow([r["section"], r["name"], r["value"], r["meaning"], r["what"], r["where"], ""])
    print(f"docs/BALANCE.md and docs/balance.csv: {len(items)} workshop items, {len(cls)} classes, "
          f"{len(blk)} blocks, {len(rows)} settings")


if __name__ == "__main__":
    main()
