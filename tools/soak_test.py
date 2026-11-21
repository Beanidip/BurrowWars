#!/usr/bin/env python3
"""Long-running server soak test: a 16v16 WebSocket dedicated server with
short rounds, and scripted players that join, play, leave and rejoin.

    python3 tools/soak_test.py /path/to/godot [minutes] [players]

Defaults: 45 minutes, 6 players. Samples the server's memory and CPU every
30 s, then reads every log and writes build/soak/report.md (also printed):
memory and object growth, CPU, tick time, rounds played, joins and leaves,
errors, anti-cheat actions against the (honest) test players. Exit code 0 when
nothing went wrong. Runs on your VPS too, before opening a server to the public.
"""
import os
import pathlib
import re
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "soak"
PORT = 24580
CLK = os.sysconf("SC_CLK_TCK")
NOISE = re.compile(r"leaked|still in use|at exit|resource\.cpp|cleanup|ObjectDB")


def proc_stat(pid):
    """(cpu ticks used, resident MB) of a process, or None once it's gone."""
    try:
        fields = pathlib.Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        rss_pages = int(pathlib.Path(f"/proc/{pid}/statm").read_text().split()[1])
        return int(fields[11]) + int(fields[12]), rss_pages * os.sysconf("SC_PAGE_SIZE") / 1048576.0
    except (FileNotFoundError, ProcessLookupError, IndexError):
        return None


def slope_per_hour(samples):
    """Least-squares growth of (seconds, MB) samples, in MB per hour."""
    if len(samples) < 3:
        return 0.0
    n = len(samples)
    mx = sum(s[0] for s in samples) / n
    my = sum(s[1] for s in samples) / n
    den = sum((s[0] - mx) ** 2 for s in samples)
    return 0.0 if den == 0 else sum((s[0] - mx) * (s[1] - my) for s in samples) / den * 3600.0


def main():
    godot = sys.argv[1] if len(sys.argv) > 1 else "godot"
    minutes = float(sys.argv[2]) if len(sys.argv) > 2 else 45.0
    players = int(sys.argv[3]) if len(sys.argv) > 3 else 6
    seconds = int(minutes * 60)
    OUT.mkdir(parents=True, exist_ok=True)
    for f in OUT.glob("*.log"):
        f.unlink()
    env = dict(os.environ)
    server_log = open(OUT / "server.log", "w")
    server = subprocess.Popen([godot, "--headless", "--path", str(ROOT), "--", "--server", "--transport", "ws",
                               "--port", str(PORT), "--team-size", "16", "--goal", os.environ.get("SOAK_GOAL", "3"),
                               "--lobby", "10", "--round-break", "5", "--name", "Soak test", "--log-every", "30"],
                              stdout=server_log, stderr=subprocess.STDOUT, cwd=ROOT)
    time.sleep(4)
    clients = []
    for i in range(1, players + 1):
        cenv = dict(env, BW_URL=f"ws://127.0.0.1:{PORT}", BW_SOAK_ID=str(i), BW_SOAK_SECONDS=str(seconds))
        log = open(OUT / f"client{i}.log", "w")
        clients.append((subprocess.Popen([godot, "--headless", "--path", str(ROOT), "res://tests/soak_client.tscn"],
                                         stdout=log, stderr=subprocess.STDOUT, cwd=ROOT, env=cenv), log))
    print(f"soak: server pid {server.pid}, {players} players, {minutes:g} minutes; logs in {OUT}", flush=True)

    samples = []          # (t, server MB, server cpu %, players' MB total)
    start = time.time()
    last = proc_stat(server.pid)
    last_t = start
    while time.time() - start < seconds + 90:
        time.sleep(30)
        now = time.time()
        cur = proc_stat(server.pid)
        if cur is None:
            print("soak: the server process is gone", flush=True)
            break
        cpu = (cur[0] - last[0]) / CLK / (now - last_t) * 100.0
        last, last_t = cur, now
        cmb = sum((proc_stat(c.pid) or (0, 0.0))[1] for c, _ in clients)
        samples.append((now - start, cur[1], cpu, cmb))
        print(f"soak: {int(now - start):5d}s server {cur[1]:6.1f} MB {cpu:5.1f}% cpu, players {cmb:7.1f} MB", flush=True)
        if all(c.poll() is not None for c, _ in clients):
            break
    exits = []
    for c, log in clients:
        try:
            exits.append(c.wait(timeout=180))
        except subprocess.TimeoutExpired:
            c.kill()
            exits.append("hung")
        log.close()
    server_alive = server.poll() is None
    server.terminate()
    try:
        server.wait(timeout=20)
    except subprocess.TimeoutExpired:
        server.kill()
    server_log.close()
    sys.exit(report(samples, exits, server_alive, minutes, players))


def report(samples, exits, server_alive, minutes, players):
    slog = (OUT / "server.log").read_text(errors="replace").splitlines()
    health = []
    for line in slog:
        m = re.search(r"health: (\d+) players, (\d+) bots, round (\d+) .*mem ([\d.]+) MB, objects (\d+), nodes (\d+), orphans (\d+), sim ([\d.]+) ms avg / ([\d.]+) max, net ([\d.]+) ms avg / ([\d.]+) max, tps ([\d.]+)", line)
        t = re.match(r"\[\s*([\d.]+)\]", line)
        if m and t:
            health.append((float(t.group(1)),) + tuple(float(x) for x in m.groups()))
    errors = [l for l in slog if ("SCRIPT ERROR" in l or "ERROR:" in l) and not NOISE.search(l)]
    strikes = [l for l in slog if "anti-cheat:" in l and "removing" not in l]
    removals = [l for l in slog if "anti-cheat: removing" in l]
    seated = sum(1 for l in slog if "seated as" in l)
    left = sum(1 for l in slog if re.search(r"peer \d+ left", l))
    rounds = max((int(h[3]) for h in health), default=0)
    builds = [m.group(1) for m in (re.search(r"built a new map in (\d+) ms", l) for l in slog) if m]
    wins = sum(1 for l in slog if "round won by" in l)

    client_lines = []
    client_errors = []
    summaries = []
    for i in range(1, players + 1):
        text = (OUT / f"client{i}.log").read_text(errors="replace").splitlines()
        client_errors += [f"client{i}: {l}" for l in text if ("SCRIPT ERROR" in l or "ERROR:" in l) and not NOISE.search(l)]
        summaries += [l for l in text if l.startswith("soak-summary:")]
        client_lines += [l for l in text if l.startswith("soak: client")]

    warm = [s for s in samples if s[0] >= 300] or samples
    rss = [s[1] for s in samples]
    cpu = [s[2] for s in samples]
    hwarm = [h for h in health if h[0] >= 300] or health
    if hwarm and min(h[12] for h in hwarm) < 55.0:
        pass  # (reported below)
    problems = []
    if not server_alive:
        problems.append("the server process died before the end")
    if errors:
        problems.append(f"{len(errors)} error lines in the server log")
    if client_errors:
        problems.append(f"{len(client_errors)} error lines in player logs")
    if removals:
        problems.append(f"{len(removals)} honest test players removed by anti-cheat")
    if any(e != 0 for e in exits):
        problems.append(f"player processes ended badly: {exits}")
    if not summaries or any("PROBLEMS" in s for s in summaries):
        problems.append("a test player reported problems (see its summary)")
    grow = slope_per_hour([(s[0], s[1]) for s in warm])
    obj_grow = slope_per_hour([(h[0], h[5]) for h in hwarm])
    if grow > 30.0:
        problems.append(f"server memory keeps growing ({grow:.0f} MB/hour after warm-up)")
    if hwarm and min(h[12] for h in hwarm) < 55.0:
        problems.append(f"the server fell behind (only {min(h[12] for h in hwarm):.0f} ticks a second at worst; 60 is on time)")
    if hwarm and max(h[7] for h in hwarm) > 0:
        problems.append(f"orphan nodes on the server (up to {int(max(h[7] for h in hwarm))})")

    lines = [f"# Soak test report", "",
             f"{minutes:g} minutes, a 16v16 WebSocket dedicated server (goal {os.environ.get('SOAK_GOAL', '3')}, 10 s lobby, 5 s between rounds), "
             f"{players} scripted players joining, playing, leaving and rejoining.", "",
             f"**Result: {'PASS' if not problems else 'PROBLEMS'}**" + ("" if not problems else ": " + "; ".join(problems)), "",
             "## Server", "",
             f"- Alive to the end: {'yes' if server_alive else 'NO'}",
             f"- Rounds started: {rounds} ({wins} won, the rest still running or cut short by the end)",
             f"- Players seated: {seated}, players left: {left}",
             f"- Memory (process): start {rss[0]:.0f} MB, peak {max(rss):.0f} MB, end {rss[-1]:.0f} MB; "
             f"growth after the first 5 minutes {grow:+.1f} MB/hour" if rss else "- Memory: no samples",
             f"- Godot memory / objects / nodes (health lines): first {health[0][4]:.1f} MB / {int(health[0][5])} / {int(health[0][6])}, "
             f"last {health[-1][4]:.1f} MB / {int(health[-1][5])} / {int(health[-1][6])}; objects {obj_grow:+.0f}/hour after warm-up; "
             f"orphan nodes max {int(max(h[7] for h in health))}" if health else "- No health lines",
             f"- CPU: average {sum(cpu) / len(cpu):.0f}% of one core, peak {max(cpu):.0f}% (30 s intervals)" if cpu else "- CPU: no samples",
             f"- Time per tick (60 a second, so 16.7 ms is the budget): match {sum(h[8] for h in health) / len(health):.2f} ms on average (worst {max(h[9] for h in health):.1f} ms), "
             f"network {sum(h[10] for h in health) / len(health):.2f} ms (worst {max(h[11] for h in health):.1f} ms)" if health else "",
             f"- Ticks actually run: {min(h[12] for h in hwarm):.1f} to {max(h[12] for h in hwarm):.1f} a second (60 is on time)" if hwarm else "",
             f"- New maps took {', '.join(builds[:3])}{'...' if len(builds) > 3 else ''} ms to build (the server pauses meanwhile)" if builds else "",
             f"- Errors in the log: {len(errors)}",
             f"- Anti-cheat on honest players: {len(strikes)} strikes, {len(removals)} removals", ""]
    if strikes:
        lines += ["Strikes (first 10):", ""] + [f"    {l.strip()}" for l in strikes[:10]] + [""]
    if errors:
        lines += ["Errors (first 15):", ""] + [f"    {l.strip()}" for l in errors[:15]] + [""]
    lines += ["## Players", ""] + [f"- {s.replace('soak-summary: ', '')}" for s in summaries]
    if client_errors:
        lines += ["", "Player errors (first 15):", ""] + [f"    {l.strip()}" for l in client_errors[:15]]
    lines += ["", "## Samples (every 30 s)", "", "| Time | Server MB | Server CPU % | Players MB |", "|---:|---:|---:|---:|"]
    lines += [f"| {int(s[0] // 60)}:{int(s[0] % 60):02d} | {s[1]:.0f} | {s[2]:.0f} | {s[3]:.0f} |" for s in samples]
    text = "\n".join(lines) + "\n"
    (OUT / "report.md").write_text(text)
    print(text)
    return 0 if not problems else 1


if __name__ == "__main__":
    main()
