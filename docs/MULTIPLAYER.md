# Multiplayer

Burrow Wars plays online over one of two transports, carrying exactly the same game:

| Transport | Used by | Address looks like |
|---|---|---|
| **ENet** (UDP) | games hosted from the menu, LAN and direct-IP play | `1.2.3.4` or `1.2.3.4:24565` |
| **WebSocket** (TCP) | public dedicated servers; the only kind a **browser** can join | `ws://1.2.3.4:24565` or `wss://play.example.org` |

Desktop players can join both. A server runs one transport. A dedicated server holds up to
**16v16** (31 players and bots in the empty seats); a game hosted from the menu up to **8v8**
(15 players join the host). Humans take bot seats as they join, and a bot takes the seat back
when they leave, so teams always stay full.

## Playing

**Join a game:** main menu > **Play Online**. Type a name, pick a preferred team and class,
then press **Join** on a server in the list, or type an address (`1.2.3.4`, `1.2.3.4:24565`,
or a `ws://` / `wss://` address for a WebSocket server) and press **Join**. A controller can do
all of this: a name is suggested for you, and the list's Join buttons need no typing.

**Host a game for friends:** **Play Online** > **Host a Race...** sets up a Cheese Race or a Scrap Race
and opens a server on your machine (default UDP port **24565**). You play in it like any other
match.
- **Lobby** (on by default in the host options): instead of starting straight away, you and
  everyone who joins wait in the **playground**, a small island with a trampoline park, a
  conveyor loop, a cannon battery anyone can man, a bullseye wall to fling each other at, a lava
  hot tub, a tower of blocks to knock down and a diving tower over the lake. Everyone wears a
  jetpack, everything is free, and bonks and cannonballs hit teammates too (twice as hard).
  The match starts only when the host presses **Enter** (rebindable: "Lobby: start the match").
  Untick Lobby to start the match as soon as you open the server, as before.
- **After a match** the results screen shows everyone's tallies, and you (the host) choose:
  **Next game** (a new map, straight in), **Back to the lobby** (everyone to the playground
  first), or **Main menu**, which ends the game for everyone. Your friends see "Waiting for the
  host" and stay connected for either of the first two. Everyone can emote meanwhile (W A S D,
  Space).
  - **Cheat code (host only):** in the playground, the host types **Up Up Down Down Left Right
    Left Right B A**: the arrow keys and B, A, or a controller's D-pad and B, A. The match it
    starts gives **everyone** (bots too) infinite scrap, materials and gadgets: everything in the
    workshop is free and nothing runs out. Digging, cheese and winning work as usual. Everyone
    hears it and the playground banner shows it. Typing it again turns it off. It stays on for
    "Back to the lobby" rounds until the host turns it off. A guest who types it gets a "nice
    try". Dedicated servers have no host, so there it does nothing.
- Same Wi-Fi/LAN: friends join with your local address (for example `192.168.1.20`).
- Over the internet: forward **UDP 24565** on your router to your PC, allow Burrow Wars through
  Windows Firewall when asked, and give friends your public IP address. There is no NAT
  punch-through or relay yet, so without port forwarding only LAN play works.
- Pausing (Esc) does not stop an online game. Quitting to the menu ends the game for everyone.

Players must run the same version. A different version is refused with a message saying which
version the server runs.

## Public servers (always on, anyone can join)

A **dedicated server** is the same game started headless with `--server`: no window, no local
player, teams filled with bots, and a new round on a new map after each win. Before each round,
everyone waits 30 seconds in the playground lobby (see `--lobby`). When nobody is connected the
world holds still.

```bash
# from the exported Linux build
./BurrowWars.x86_64 --headless -- --server --name "Burrow Wars EU #1"
```

```bash
# or from the project folder with the Godot 4.7.2 editor binary
godot --headless --path . -- --server --name "Burrow Wars EU #1"
```

On Windows: `BurrowWars.exe --headless -- --server`.

| Option | Default | Meaning |
|---|---|---|
| `--port N` | 24565 | UDP port. Run several servers on one machine with different ports. |
| `--name "..."` | Burrow Wars server | Shown to players (16 characters max). |
| `--mode scrap` | race | Scrap Race instead of a Cheese Race: teams race to bank scrap. |
| `--mutators meteors,lava_rise` | none | Match options (Extras), comma-separated: `meteors` (Meteor Shower), `lava_rise`, `flash_freeze`, `fungal` (Fungal Outbreak). |
| `--goal N` | 10 | Cheese to win a round (1-250). The map always holds at least 2.5x the goal. With `--mode scrap`, the scrap goal (default 300). |
| `--team-size N` | 4 | Seats per team, bots included (1-16). |
| `--skill 0/1/2` | 1 | Bot skill: relaxed, normal, fierce. |
| `--round-break S` | 15 | Seconds between a win and the next map. |
| `--lobby S` | 30 | Seconds in the playground before each round (the countdown only runs while someone is connected). `0` = no lobby. Ignored with `--free`. |
| `--seed N` | random | Fix the first map (later rounds are random). |
| `--free` | off | Run Free Build instead of Cheese Race. |
| `--map FILE` | none | Start every round on a saved/exported `.bwmap` (from Esc > Export map) instead of a new map. |
| `--transport ws` | ENet (UDP) | Listen for **WebSocket** (TCP) instead: browsers can join, and so can desktop players with a `ws://` / `wss://` address. Use this for public servers. |
| `--tls-cert FILE --tls-key FILE` | none | With `--transport ws`: serve `wss://` directly with this PEM certificate and key. Usually simpler: put Caddy in front (below). |
| `--status-port N` | game port + 1 | TCP port of the **status page** (`GET /status`, JSON) the server list reads: name, version, players, mode, score. |
| `--no-status` | off | No status page. The server list then shows "not answering" for it. |

### Browsers need `wss://`

A browser page served over https (itch.io is) may only open **secure** WebSockets: `wss://`,
with a certificate for a real domain name. Plain `ws://` works from desktop builds and from a
browser on the same machine (`localhost`), but not from itch.io. So a server that browser players
can join needs:
1. a domain name (or subdomain) pointing at the server, for example `play.example.org`;
2. a certificate for it. The easiest way is [Caddy](https://caddyserver.com), which gets and
   renews a free Let's Encrypt certificate by itself and passes WebSocket connections through.

Run the game server on WebSocket, listening only for Caddy:

```bash
./BurrowWars.x86_64 --headless -- --server --transport ws --port 24565 --name "Burrow Wars EU #1"
```

and give Caddy this `/etc/caddy/Caddyfile` (the game on 24565, its status page on 24566):

```
play.example.org {
	handle /status {
		reverse_proxy 127.0.0.1:24566
	}
	handle {
		reverse_proxy 127.0.0.1:24565
	}
}
```

Several servers on one machine can share the name, one path each (give each its own ports):

```
play.example.org {
	handle_path /eu1/status {
		reverse_proxy 127.0.0.1:24566
	}
	handle_path /eu1 {
		reverse_proxy 127.0.0.1:24565
	}
	handle_path /eu2/status {
		reverse_proxy 127.0.0.1:24576
	}
	handle_path /eu2 {
		reverse_proxy 127.0.0.1:24575
	}
}
```

Players then join `wss://play.example.org` (or `wss://play.example.org/eu1`), and the list reads
`https://play.example.org/status` (or `.../eu1/status`). Open TCP **80** and
**443** in the firewall (Caddy needs 80 to get the certificate) and keep the game's own port closed
to the outside. To skip Caddy, pass your own certificate with `--tls-cert` / `--tls-key` and open
the game's TCP port instead; the address is then `wss://play.example.org:24565`.

### Hosting one on a VPS

Any small Linux VPS works (1 vCPU, 1 GB RAM is plenty; one server process uses a few percent
of a core). Open the port in the provider's firewall (UDP for ENet; for WebSocket, TCP 80 and 443
with Caddy as above), copy the Linux build over, and keep it running with systemd:

```ini
# /etc/systemd/system/burrowwars.service
[Unit]
Description=Burrow Wars dedicated server
After=network-online.target

[Service]
User=burrow
WorkingDirectory=/opt/burrowwars
ExecStart=/opt/burrowwars/BurrowWars.x86_64 --headless -- --server --transport ws --name "Burrow Wars #1"
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable --now burrowwars
```

**Bandwidth** (measured): each rat travels as a 27-byte record and names only when they change,
so a snapshot of a full **16v16** match is about **1.1 KB** (it was about 4.9 KB), sent 20 times a
second, plus about 0.4 KB of private inventory 4 times a second: roughly **24 KB/s per connected
player**, about **6 Mbit/s** for a full server of 31. Joining sends the whole map once: about
110 KB for a fresh map, more for a heavily carved one, in 48 KB parts.

**CPU** (measured on the test machine): a 16v16 match with 30 bots takes about 6 ms per tick on
average (worst about 19 ms) of the 16.7 ms a 60 Hz tick has, nearly all of it the bots thinking.
Each human who joins replaces a bot, so a full server of players costs less. A 1-vCPU VPS runs
one full server; give it 2 vCPUs to run two.

### Keeping an eye on it

Every minute (`--log-every S` to change) the server writes a **health** line to its log:

```
health: 4 players, 28 bots, round 12 (race, 2-1, t=95s), mem 50.3 MB, objects 1764, nodes 58,
orphans 0, sim 9.8 ms avg / 46.0 max, net 0.3 ms avg / 16.6 max, tps 60.0,
reports 3664 ok / 0 stale / 0 after a server move / 0 dropped / 0 refused
```

- **mem, objects, nodes** should stay level over hours; steady growth means a leak. **orphans**
  should stay 0.
- **sim / net**: time per tick for the match and for networking. 60 ticks a second means the two
  together must stay well under 16.7 ms on average; **tps** below 60 means the machine is too slow.
- **reports**: players' movement reports. **refused** ones failed an anti-cheat check (each also
  logs an `anti-cheat:` line saying where and why).

`journalctl -u burrowwars -f` shows the log live with the systemd setup above.

### Soak test before you open it to the public

`tools/soak_test.py` runs a full 16v16 WebSocket server with short rounds and scripted players who
join, play, leave and rejoin, then reports memory and CPU over time, rounds played, errors and any
anti-cheat action against those honest players:

```bash
python3 tools/soak_test.py /path/to/godot 45 6
```

(45 minutes, 6 players; the report is `build/soak/report.md`). Running it on your VPS also tells you
whether that machine keeps up. The rest of the 32 seats are filled by bots, so the server works as
hard as a full one. Each test player is a whole copy of the game (about 150 MB and a fair share of a
core), so run them on the VPS only if it has room, or point them at it from another computer:
`BW_URL=wss://play.example.org BW_SOAK_ID=1 BW_SOAK_SECONDS=1800 godot --headless --path .
res://tests/soak_client.tscn`.

The report ends in **PASS** or lists the problems. What a healthy run looked like here (45 minutes,
21 rounds, 370 joins, 152 leaves):

- the process grew from 155 to 170 MB, then levelled off (each 10 minutes added less: +9, +3, +2,
  +1 MB); Godot's own count went from 52.9 to 54.4 MB, and the object count stayed level
- about 42% of one core on average, 59% at the busiest, and a steady 60 ticks a second
- no errors, no lost connections, no failed joins, and no honest test player removed

Memory that keeps climbing at the same rate, ticks below 60, or players removed by anti-cheat are
the things to look into before strangers play. Give it at least 30 minutes: the process total
creeps up for the first quarter of an hour or so as it settles, so a shorter run only notes it and
judges leaks by the game's own memory and object counts.

### Listing it in the game

The **Public servers** list in the menu is read from [`servers.json`](../servers.json) on the
`main` branch of this repository (or from the URL in the project setting
`burrow_wars/server_list_url`). To list a server, add an entry and push:

```json
{
  "servers": [
    {"name": "Burrow Wars EU #1", "region": "EU", "url": "wss://play.example.org"},
    {"name": "LAN party box", "region": "EU", "address": "203.0.113.10", "port": 24565}
  ]
}
```

- `url` is a WebSocket server (`wss://` for browsers); `address` + `port` an ENet (UDP) server,
  which browsers can't join (their row says "Desktop only").
- Each row asks the server's **status page** how it's doing and shows the players, the mode and
  score, and a ping (estimated from how long the status took). A server running another version
  shows "Needs version ..." and a full one "Full", instead of Join. **Refresh** asks again.
- Where the status page is, unless the entry gives `"status": "https://..."`:
  - `wss://host/path` -> `https://host/path/status` (the Caddy setup above);
  - `ws://host:port` and `address` + `port` -> `http://host:<port + 1>/status` (the game's own
    status port; open it in the firewall).
- To try a list of your own before pushing it: `BW_SERVER_LIST=/path/to/servers.json` (a file or
  a URL) when starting the game.

## How it works (for developers)

- **One authority.** The host's game or the dedicated server runs the real `Match`. A client
  runs a *replica* `Match` (`Match.replica`): it draws the world and moves only its own rat.
- **Requests.** Every rule-changing call (`try_dig`, `try_place_mat`, `try_use_equipped`,
  `use_ability`, `try_buy`, siege controls...) checks `Match.remote` first; on a client it is sent
  to the server, which runs the same validated method for that player's rat (`NetServer.on_act`,
  with type checks on every argument). Refusals come back as notices.
- **Movement.** Your own rat moves locally for instant response and reports its state 30 times a
  second. The server checks every report (`scripts/net/anti_cheat.gd`) and puts the rat back where
  it last was legally if it fails:
  - speed: at most 40 blocks/s;
  - **walls**: a rat may not stand inside solid ground for more than 0.2 s (someone may just
    have built there), nor pass through more than 0.45 blocks of it between two reports;
  - **height**: since it last stood on something, a rat can rise only as high as a jump and a
    double jump (3.4 blocks), a spring (6.8) or a jetpack (11.8 more, if it wears one) carry it,
    or as a throw from the server allows, and after that it must be falling. That catches flying
    and hovering. Ladders and water count as standing; classes that fly (Free Build) are free to;
  - **stamina** refills no faster than it really does.
  When the authority moves a rat itself (bonk, blast, trap, lava, respawn, teleport, stamina spent
  on an ability), the player gets a *kick* with the new state, and reports sent before that kick
  are ignored. That includes changes made between ticks (a respawn request, another player's bonk).
- **Rate limits.** Requests: 30 a second (bursts of 60). Movement reports and aim: 45 a second
  (bursts of 90). The rest of a flood is dropped.
- **Strikes.** Each failed check is a strike, logged with the reason (`anti-cheat: peer ...`).
  One strike fades every 30 s. On a dedicated server a player who reaches 8 is removed with a
  message saying why (they can rejoin). A player-hosted game only corrects; it never removes
  anyone.
- **Streams.** Reliable: block and carving changes, effects, toasts and the win, batched once
  per tick. Unreliable 20 Hz: rats (binary records, `net_codec.gd`: position to 1/128 block,
  velocity to 1/256 block/s, names in a roster sent for a second after any change and once a
  second), pickups, markers, machines, shots, Mobile TNT, scores.
  Reliable 4 Hz (and right after each request): the player's own inventory.
- **Joining.** The welcome comes first, then the map in 48 KB parts. On WebSocket each player's
  send buffer is 1 MB: map parts wait for room, a snapshot is skipped for a player whose buffer
  is three-quarters full (the next one replaces it), and a player who stops reading for 15 s is
  dropped. The client checks the parts' order, count and size before building anything.
- **Files.** `scripts/net/net.gd` (autoload, transports, joining, RPC endpoints),
  `net_server.gd`, `net_client.gd`, `dedicated_server.gd`.
- **Status page.** `status_server.gd`: a minimal HTTP server on its own TCP port answering
  `GET /status` with JSON (`Access-Control-Allow-Origin: *`, so a browser build may read it), and
  404 to anything else; at most 16 connections, 4 KB requests, 3 s each.
- **Tests.** `tools/net_check.sh` (run by `tools/check.sh`) starts real processes on localhost:
  dedicated server + scripted client (over ENet, and again over WebSocket), a 16v16 WebSocket
  server, the server list (live status, ping, join from the list), a `wss://` join with a
  throwaway certificate, player-hosted game + client, and a dedicated server rolling a connected
  player onto a new map after a win.

## Limits (honest list)

- Hiding enemy names out of sight is done by each player's game; the server still sends every rat's position, so a modified client could show them.
- Movement is checked against walls, height and speed (above), with generous margins so lag never
  costs an honest player more than a rare correction. Inside those margins a modified client can
  still cheat a little: move at the top speed all the time, or skip a dash's stamina cost on its
  own side. Everything else (digging, building, scores, inventories) is validated by the server.
- Removed players are not banned: a public server sees every WebSocket player arrive from its
  proxy's address, so there is nothing reliable to ban by yet. Accounts (Steam) would fix that.
- No accounts, kick or ban commands or chat yet.
- Player-hosted games need port forwarding for internet play (no relay or NAT punch-through).
- ENet and `ws://` traffic is not encrypted; `wss://` is. Nothing secret is sent either way.
- WebSocket runs over TCP, so a lost packet holds up the ones behind it: on a bad connection
  other rats can stutter more than over ENet.
- Other rats are drawn by smoothing toward the latest snapshot (no lag compensation), so a
  bonk on a fast-moving rat at high ping can miss; the server allows 0.7 blocks of slack.
