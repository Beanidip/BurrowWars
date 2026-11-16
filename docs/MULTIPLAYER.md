# Multiplayer

Burrow Wars plays online over UDP (Godot's ENet). Up to 16 rats per match; humans take bot
seats as they join, and a bot takes the seat back when they leave, so teams always stay full.

## Playing

**Join a game:** main menu > **Play Online**. Type a name, pick a preferred team and class,
then press **Join** on a server in the list, or type an address (`1.2.3.4` or `1.2.3.4:24565`)
and press **Join**.

**Host a game for friends:** **Play Online** > **Host a game...** sets up a normal Cheese Race
and opens a server on your machine (default UDP port **24565**). You play in it like any other
match.
- Same Wi-Fi/LAN: friends join with your local address (for example `192.168.1.20`).
- Over the internet: forward **UDP 24565** on your router to your PC, allow Burrow Wars through
  Windows Firewall when asked, and give friends your public IP address. There is no NAT
  punch-through or relay yet, so without port forwarding only LAN play works.
- Pausing (Esc) does not stop an online game. Rematch starts a new map and brings everyone
  along. Quitting to the menu ends the game for everyone.

Players must run the same version. A different version is refused with a message saying which
version the server runs.

## Public servers (always on, anyone can join)

A **dedicated server** is the same game started headless with `--server`: no window, no local
player, teams filled with bots, and a new round on a new map 15 seconds after each win. When
nobody is connected the world holds still.

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
| `--goal N` | 10 | Cheese to win a round (1-250). The map always holds at least 2.5x the goal. |
| `--team-size N` | 4 | Seats per team, bots included (1-8). |
| `--skill 0/1/2` | 1 | Bot skill: relaxed, normal, fierce. |
| `--round-break S` | 15 | Seconds between a win and the next map. |
| `--seed N` | random | Fix the first map (later rounds are random). |
| `--free` | off | Run Free Build instead of Cheese Race. |
| `--map FILE` | none | Start every round on a saved/exported `.bwmap` (from Esc > Export map) instead of a new map. |

### Hosting one on a VPS

Any small Linux VPS works (1 vCPU, 1 GB RAM is plenty; one server process uses a few percent
of a core). Open the UDP port in the provider's firewall, copy the Linux build over, and keep
it running with systemd:

```ini
# /etc/systemd/system/burrowwars.service
[Unit]
Description=Burrow Wars dedicated server
After=network-online.target

[Service]
User=burrow
WorkingDirectory=/opt/burrowwars
ExecStart=/opt/burrowwars/BurrowWars.x86_64 --headless -- --server --name "Burrow Wars #1"
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable --now burrowwars
```

**Bandwidth** (measured): a snapshot of a full 4v4 match is about 1.5 KB, sent 20 times a
second, plus about 0.4 KB of private inventory 4 times a second: roughly **32 KB/s per connected
player** (about 2 Mbit/s for 8 players). Joining sends the whole map once (about 16 KB).

### Listing it in the game

The **Public servers** list in the menu is read from [`servers.json`](../servers.json) on the
`main` branch of this repository. To list a server, add an entry and push:

```json
{
  "servers": [
    {"name": "Burrow Wars EU #1", "address": "203.0.113.10", "port": 24565, "region": "EU"}
  ]
}
```

The list shows name, address and region. It does not yet show live player counts or ping.

## How it works (for developers)

- **One authority.** The host's game or the dedicated server runs the real `Match`. A client
  runs a *replica* `Match` (`Match.replica`): it draws the world and moves only its own rat.
- **Requests.** Every rule-changing call (`try_dig`, `try_place_mat`, `try_use_equipped`,
  `use_ability`, `try_buy`, siege controls...) checks `Match.remote` first; on a client it is sent
  to the server, which runs the same validated method for that player's rat (`NetServer.on_act`,
  with type checks on every argument). Refusals come back as notices.
- **Movement.** Your own rat moves locally for instant response and reports its state 30 times a
  second. The server accepts it within a speed limit (40 blocks/s), otherwise snaps the rat back.
  When the authority moves a rat itself (bonk, blast, trap, lava, respawn, stamina spent on an
  ability), the player gets a *kick* with the new state, and reports sent before that kick are
  ignored.
- **Streams.** Reliable: block and carving changes, effects, toasts and the win, batched once
  per tick. Unreliable 20 Hz: rats, pickups, markers, machines, shots, Mobile TNT, scores.
  Reliable 4 Hz (and right after each request): the player's own inventory.
- **Files.** `scripts/net/net.gd` (autoload, connection and RPC endpoints),
  `net_server.gd`, `net_client.gd`, `dedicated_server.gd`.
- **Tests.** `tools/net_check.sh` (run by `tools/check.sh`) starts real processes on localhost:
  dedicated server + scripted client, player-hosted game + client, and a dedicated server
  rolling a connected player onto a new map after a win.

## Limits (honest list)

- Movement is trusted within the speed limit, so a modified client could still fly or walk
  through walls slowly. Everything else (digging, building, scores, inventories) is validated
  by the server.
- No accounts, kick or ban commands, chat, or player-count/ping in the server list yet.
- Player-hosted games need port forwarding for internet play (no relay or NAT punch-through).
- Traffic is not encrypted (ENet over plain UDP). Nothing secret is sent.
- Other rats are drawn by smoothing toward the latest snapshot (no lag compensation), so a
  bonk on a fast-moving rat at high ping can miss; the server allows 0.7 blocks of slack.
