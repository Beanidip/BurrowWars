# Burrow Wars: Release Review (Steam, itch.io, mobile)

Reviewed: 2026-11-19, branch `water-and-multiplayer` at `dc1635f` (game version 2.1.0, network protocol 9),
Godot 4.7.2. This is a read-only review: no game code was changed. Measurements were taken on
a 4-core cloud Linux machine with software (CPU) rendering, so **frame rates here say nothing
about GPUs**. CPU-side numbers (meshing, simulation, memory) are meaningful.

## 1. Verdict

The game is **closer to shippable than most solo projects at this stage**. The core loop, bots,
rules, effects and an authoritative online mode are done, and there are 955 automated checks plus
real-process network tests. Memory stays flat over a full match, and digging never rebuilds
colliders. What stands between it and a store release is **mostly packaging, not game code**:

- a credits/licence screen;
- an asset-rights audit;
- a final name and icon;
- display settings and a fullscreen default;
- moving runtime chunk re-meshing off the main thread;
- basic onboarding.

**Steam friend-invite multiplayer is the largest single job.** Today the transport is hard-wired to
ENet direct IP with port forwarding. The good news: the game already uses Godot's high-level
multiplayer API with one authority. A Steam `MultiplayerPeer` can slot in behind a small transport
abstraction, so no gameplay rewrite is needed.

Realistic estimate for a solo developer:
- **4–6 weeks of work** to a Steam Early Access–quality build with invites;
- an itch.io build shortly after;
- **mobile: not now**.

## 2. Project map (Phase 1)

**Scene tree and autoloads**
- `scenes/main.tscn` is one `Node` running `scripts/core/main.gd`. Everything else is built in code.
- Autoloads (`project.godot:14-20`):
  - `Log`: stdout plus a ring buffer;
  - `Config`: `user://settings.cfg` and tuning constants;
  - `Inputs`: the key registry and rebinding;
  - `Sfx`;
  - `Net`: the connection and all RPC endpoints.
- `Main` swaps between:
  - `MainMenu` (`scripts/core/main.gd:31-39`);
  - a `LoadingScreen`;
  - a `GameSession` (`scripts/core/main.gd:58-76`), which builds, in order:
    - the `Match` (`scripts/match/game_session.gd:60`);
    - a `NetClient` (`:68`) or `NetServer` (`:88`);
    - `PlayerController` (`:94`), `MatchView` (`:99`), `ContraptionView` (`:105`) and `Hud` (`:110`).
- Started with `-- --server`, `Main` runs `DedicatedServer` instead (`scripts/core/main.gd:21-26`).

**Gameplay loop**
- `Match.step(dt)` (`scripts/match/match.gd:263`) runs on the authority at the physics rate:
  - bots think, then rats move with a custom grid AABB solver (`scripts/actors/rat.gd:1-8`; no Godot physics);
  - hazards, teleporters and raids;
  - pickups, TNT, Mobile TNT and impulse grenades, wind-ups, crumbs, siege machines, liquids and markers.
- Scoring happens when a carrier enters its own base (`scripts/match/match.gd:511-521`). A team
  reaching `goal` emits `won`, which opens the results screen (`scripts/ui/hud.gd:843-849`).

**Voxel terrain**
- Storage: `VoxelWorld` is 128×64×128 cells (`scripts/world/voxel_world.gd:12-15`), one byte per
  cell in a `PackedByteArray` (~1 MB).
- Chunks: 16³, so 256 chunks.
- Extra state:
  - 7³ microvoxel carvings in a `Dictionary` of 343-byte masks (`:25`);
  - team-gate layers;
  - per-cell damage.
- Editing: all edits go through `set_block` (`:94-119`), which marks chunks dirty (`:339-349`) and
  emits `block_changed`. Liquids, match bookkeeping and the network stream listen to that signal.
- Meshing: `ChunkMesher.build_arrays` is thread-safe GDScript producing vertex-coloured surfaces.
  - The first full mesh runs on `WorkerThreadPool` behind the loading screen (`:407-470`).
  - Runtime edits are re-meshed on the main thread, 6 chunks per frame (`:383-388`).

**Teams, rats, cheese**
- 2 teams; 4 classes (`scripts/match/class_defs.gd:4-9`); bots use exactly the player rules.
- Cheese blocks become carried cheese, which is deposited at the team's own base. Vault raids,
  bonks, gadgets and siege machines all feed into that.

**Networking**
- No MultiplayerSpawner or MultiplayerSynchronizer: a hand-written RPC protocol on `/root/Net`
  (`scripts/net/net.gd:133-210`).
- Transport: `ENetMultiplayerPeer` (`:56`, `:71`).
- The server runs every rule (`scripts/net/net_server.gd:237-328`).
- What it sends:
  - a reliable batch of block deltas, effects and toasts every tick (`:373-391`);
  - an unreliable 20 Hz snapshot (`:394-415`);
  - per-player inventory at 4 Hz;
  - "kicks" when the authority moves a player (`:201-205`).
- Clients:
  - simulate only their own rat and send it at 30 Hz (`scripts/net/net_client.gd:82-96`);
  - receive the whole world on join (`scripts/world/voxel_world.gd:503-509`).
- Also present: a headless dedicated server (`scripts/net/dedicated_server.gd`) and a public server
  list fetched from GitHub (`scripts/ui/main_menu.gd:65`, `:496-505`).

**Export presets** (`export_presets.cfg`)
- Windows Desktop and Linux, both x86_64 with the PCK embedded in the binary.
- PCK encryption is off.
- There is no macOS, web, Android, iOS or dedicated-server preset.

**Addons and third-party content**
- There is no `addons/` folder.
- The effect sheets in `assets/fx/` are rendered from pixelfx (MIT; `assets/fx/LICENSE-pixelfx.txt`).
- `tools/` uses Python (PIL, numpy) and Node at development time only; exports exclude `tools/*`.
- The Godot engine itself is MIT, plus third-party notices.
- According to `README.md:92-93`, rat sprites, UI icons, most sound effects and the music are "the project owner's own
  assets, carried over from v0.15.1". **Their origin and licence are not recorded anywhere**
  (see the legal findings).

## 3. Findings

**P0** = blocks release, **P1** = fix before launch, **P2** = polish. Effort: S ≤ 1 day, M = 2–5 days, L = 1–3 weeks.

| Priority | Area | File:line | Problem | Fix | Effort |
|---|---|---|---|---|---|
| P0 | Legal | `README.md:90-97`, `scripts/ui/main_menu.gd:128-141` (no credits entry), `export_presets.cfg:9` | No in-game licence notices. Godot's MIT licence and its third-party notices (FreeType, ENet, mbed TLS and others) must ship with the game. The pixelfx MIT text is only packed inside the PCK, where players can't read it. | Add a Credits/Licences screen built from `Engine.get_license_text()`, `Engine.get_copyright_info()` and `Engine.get_license_info()`, plus the pixelfx text. Ship `GODOT_COPYRIGHT.txt` next to the exe. | S |
| P0 | Legal | `README.md:92-93` | Rat art, music and most sound effects have no recorded source or licence. Steam's content survey asks about AI-generated player-facing content (rules clarified Jan 2026, per press reports). | Write `docs/ASSET_LICENSES.md` with file, author, source, licence and whether AI was used, for every asset. Replace anything without commercial rights. | S (your input) |
| P0 | Release | `project.godot:7-10`, `export_presets.cfg:27,30` | The product name is still "Burrow Wars: Jam Edition". There's no `config/icon`, and `application/modify_resources=false`, so the Windows exe shows Godot's icon and no file version. | Pick the final name and add a 256 px icon plus `.ico`. Set `modify_resources=true` and fill in the version fields. Check the name for trademark clashes. | S |
| P0 (for Steam MP) | Multiplayer | `scripts/net/net.gd:53-85`, `:121` | Online play needs the host to forward UDP 24565. There is no NAT traversal, relay or invites, and the advertised Steam feature doesn't exist yet. | Add a `NetworkBackend` with an ENet backend and a Steam backend (lobbies + Steam MultiplayerPeer over Steam Datagram Relay); see §4. | L |
| P1 | UX | `scripts/ui/settings_panel.gd:12-23`, `project.godot:22-27` | No display settings (window/fullscreen, resolution or UI scale, vsync, fps cap). The game starts in a 1280×720 window. Volume is master + music only: there's no SFX slider. | Add a Display section (`DisplayServer.window_set_mode`, vsync, `Engine.max_fps`), default to fullscreen, and add an SFX bus and slider. | M |
| P1 | Input | `scripts/core/inputs.gd:7-59`, `scripts/ui/settings_panel.gd:67-79` | Keyboard and mouse only: no joypad events, no controller UI navigation, and rebinding accepts keys only. Steam Deck Verified expects controller play (secondary sources); without it, expect "Playable" at best. | Add joypad bindings and stick look, UI focus navigation, and controller glyphs in prompts. Ship a Steam Input template meanwhile. | L |
| P1 | Netcode / cheating | `scripts/net/net_server.gd:168-180` | Player movement is trusted within 40 blocks/s with no collision or gravity check. A modified client can walk through walls, fly, or speed to cheese and home, and the server then grants pickups and scoring from that position. | Fine for friends-only lobbies. Before public matchmaking, reject reported positions inside solid blocks (`Rat.blocked_at`), cap vertical gain unless a spring or jetpack fired, and sanity-check pickup distance. | M |
| P1 | Netcode | `scripts/net/net.gd:153-156`, `scripts/net/net_server.gd:237-328` (e.g. `:262` `try_place_mat`, `:313` `stash_move`) | No per-peer rate limit on reliable action RPCs. Some actions have no cooldown, so a modified client can flood the host. | Add a token bucket per peer in `on_act` (about 30 actions/s, burst 60) and kick on sustained abuse. | S |
| P1 | Performance | `scripts/world/voxel_world.gd:383-388`, `:391-392` | Re-meshing after digs runs on the main thread, up to 6 chunks per frame. Measured 6.9 ms per chunk on average and 17.5 ms worst case, so a TNT blast spanning 4–8 chunks hitches for about 30–100 ms. | Reuse the worker path (`start_prebuild`, `:407-470`) for runtime edits: mesh dirty chunks on `WorkerThreadPool` from a copy of the neighbourhood, then swap meshes on the main thread. | M |
| P1 | Performance | `scripts/world/chunk_mesher.gd:318`, `:360-373` | About 1.03 million triangles for the full map (measured) with no greedy meshing. Stone, brick and obsidian faces are split into 4 quads each for mottling. All 256 chunks are always resident, with no view distance or LOD. 270–375 draw calls per frame. Probably fine on discrete GPUs; **unmeasured on integrated GPUs and Steam Deck**. | Greedy-merge same-colour faces. Do the rock mottling with per-vertex colour on 1 quad, or a tiny texture. Test on a Deck and an old iGPU before naming a minimum spec. | M |
| P1 | Onboarding | `scripts/ui/main_menu.gd:7-39`, `scripts/core/inputs.gd:7-43` | "How to Play" is a wall of text, and there are 30+ bindings with no tutorial. Store reviews punish this hard. | Add a short guided first match: dig, pick up cheese, carry it home, bonk, workshop. Show contextual prompts the first time each system appears. | M |
| P1 | Release | `scripts/ui/main_menu.gd:63-65`, `:496-505` | The server list URL is hard-coded to the raw `main` branch of your GitHub repo. It breaks if the repo is renamed or made private, and it's an undisclosed network call. | In Steam builds replace it with the Steam lobby list; in the itch build, host it on your own domain or remove it. | S |
| P1 | Steam Deck | `scripts/ui/hud.gd:162,186,284,736` | The smallest text is 11–12 px on the 1280×720 canvas. That's above Valve's 9 px minimum at 1280×800 but below the 12 px recommendation. Body text in dialogs is 13–15 px. | Raise the minimum to 12 px and add a UI scale option. Verify on device. | S |
| P2 | Persistence | `scripts/core/config.gd:125-128`, `scripts/world/voxel_world.gd:480-500` | Settings and map exports are written in place. A crash mid-write corrupts the file. Loading does fall back safely (`config.gd:103`, `voxel_world.gd:675-699`), so the risk is losing data, not crashing. No settings schema version. | Write to `*.tmp`, then `DirAccess.rename`. Add `"version"` to `settings.cfg`. | S |
| P2 | Stability | `scripts/actors/rat_sprite.gd:33-35`, `scripts/match/fx_sprite.gd:17`, `scripts/world/block_textures.gd:13`, `scripts/ui/icons.gd:12` | At exit: 41 ObjectDB instances, 18 GL textures and 1 CanvasItem RID are reported as leaked, plus 1 orphan node after returning to the menu (soak run). These are static caches that are never cleared. Harmless, but noisy in logs. | Clear the caches on `NOTIFICATION_WM_CLOSE_REQUEST`. Find the orphan with `--verbose`. | S |
| P2 | Netcode bandwidth | `scripts/net/net_server.gd:394-415`, `docs/MULTIPLAYER.md:91` | The 20 Hz snapshot resends every rat's name and class strings and full-precision vectors: about 32 KB/s per player at 4v4, so about 2 Mbit/s of host upload for 8 players. | Send names and classes only when they change, quantize positions, and skip unchanged machines. That roughly halves the bandwidth. | M |
| P2 | Netcode | `scripts/world/voxel_world.gd:503-509` | The join snapshot compresses blocks but sends carving masks raw (343 bytes per carved cell). A heavily chiselled map makes the welcome packet large. | Compress the mask dictionary (zstd) inside the snapshot. | S |
| P2 | Netcode | `scripts/net/net.gd:124-128` | When the host quits, clients are dropped to the menu with a generic message. There's no host migration (normal for listen servers). | Show "The host left the game", and with Steam, return players to the Steam lobby rather than the main menu. | S |
| P2 | UX | `scripts/ui/hud.gd:821-824` | The pause menu has no "Quit to desktop". | Add the button, with a confirmation dialog. | S |
| P2 | Release | `export_presets.cfg` | No macOS, web or dedicated-server presets. The Linux build doubles as the server (works). | Decide on platforms (see §6). Optionally add a `dedicated_server` preset that strips visuals. | S |
| P2 | Localization | `scripts/ui/main_menu.gd:7-39`, `scripts/match/class_defs.gd` | All text is hard-coded English with no `tr()`. Store pages list supported languages. | Launch English-only; move strings to a CSV translation table before adding languages. | M |
| P2 | Accessibility | `scripts/actors/rat_sprite.gd` (team tint), `scripts/ui/ui_kit.gd` | Teams are told apart mainly by blue vs red. | Add a colour-blind palette option and team icons on name tags. | S |
| P2 | Steam extras | n/a | No achievements, stats or cloud saves. | Steam Auto-Cloud for `user://settings.cfg` and `user://maps` needs no code. Add 8–12 achievements later. | S–M |

**Good things already in place**
- Every client request is type-checked (`scripts/net/net_server.gd:210-235`).
- `bytes_to_var` never decodes objects (`scripts/net/net.gd:173-178`).
- Player names are sanitised (`scripts/net/net.gd:42-48`).
- A protocol version check refuses mismatched clients (`scripts/net/net.gd:139-141`).
- A bot takes over when a player leaves, and rejoining reuses the seat (`scripts/net/net_server.gd:106-120`).
- Superseded loads are cancelled (`scripts/core/main.gd:62-68`).
- Worker threads are joined on exit (`scripts/world/voxel_world.gd:474-475`).
- Freed follow-targets are checked (`scripts/match/fx_sprite.gd:99-100`).
- Corrupt saves and snapshots are rejected rather than half-applied (`scripts/world/voxel_world.gd:512-530`, `:675-699`).
- Digging never rebuilds colliders, because there are no physics colliders at all.

**Measurements** (this machine)
- Map generation plus threaded meshing: about 3.7 s from "start" to playable in a 4v4 match.
- Full-map mesh on one thread: 1.77 s for 256 chunks.
- A 3-minute rendered 4v4 bot match:
  - memory steady at about 63.5 MB static RAM;
  - about 2,900 objects and about 500 nodes, with no growth;
  - simulation 1–8 ms per physics frame.

**Minimum spec I'd propose**, to be confirmed on hardware first:
- 4-core x86-64 CPU from 2015 or later;
- 4 GB RAM;
- OpenGL 3.3 GPU: an Intel UHD 620 class iGPU at 720p, or a GTX 750 class card at 1080p;
- Steam Deck as the reference handheld.

Treat this as a **target to test**, not a measured fact.

## 4. Multiplayer architecture (Phase 3)

### 4a. Netcode audit

- **Authority: the host's game or a dedicated server.**
  - The server alone decides digging, placement, gadgets, bonks, pickups, deposits, raids, shop
    purchases and scores (`scripts/net/net_server.gd:237-328`; every `Match.try_*` checks `remote` first).
  - Teams: the client may *ask* for a team and class (`:67-74`); the server seats them, falling back
    to the other team when one is full.
  - **Client-trusted:** your own rat's movement (`:168-180`). This is the main cheat vector
    (P1 above), along with client-side hiding of enemy name tags.
- **Voxel sync: deltas, not chunks.**
  - Each block change goes out as 4 × int32, i.e. 16 bytes (`:333-334`), batched per tick and sent reliably.
  - Carvings are sent as cell + 343-byte mask per changed cell (`:376-378`).
  - Late joiners get the whole world once: zstd-compressed blocks (~16 KB measured), plus raw
    carving masks and gate layers (`scripts/world/voxel_world.gd:503-509`).
- **Bandwidth.**
  - Digging is cheap. 8 players each breaking about 2 blocks/s is about 16 × 16 B = 256 B/s of
    deltas (plus effect events), which is tiny next to the snapshot.
  - Dominant cost: the 20 Hz snapshot at about 1.5 KB per 4v4 frame, roughly **32 KB/s down per player**.
  - Host upload: 2 players about 64 KB/s, 4 players about 128 KB/s, 8 players about 256 KB/s
    (~2 Mbit/s). That fits home upload and Steam relays; trimming it is P2.
  - Client upload: about 30 × 100 B, roughly 3 KB/s.
- **Validation and limits.**
  - Present: argument type checks, an effect whitelist with 150 ms rate limiting (`:31`, `:184-191`),
    and a speed limit with snap-back (`:168-172`).
  - Missing: an action rate limit (P1) and any server-side collision check (P1 for public play).
- **Disconnects.**
  - A player leaving hands their rat to a bot (`:106-120`), and rejoining finds the seat again (tested).
  - The host leaving ends the game for everyone (`scripts/net/net.gd:124-128`).
  - A dedicated server keeps rounds rolling (`scripts/net/dedicated_server.gd:97-130`).
- **Transport separation.**
  - The good part: `NetServer` and `NetClient` only use peer ids, RPCs and `multiplayer`, so they
    don't care what the transport is.
  - The coupling: peer creation, connect/disconnect wiring and error text live in `Net.host()` /
    `Net.join()` (`scripts/net/net.gd:53-99`), hard-wired to ENet.
  - This is the only part to abstract.

**Proposed abstraction:** keep `Net` (it owns the RPC endpoints at `/root/Net`) and move transport
into a `NetworkBackend` interface chosen at startup.

```
NetworkBackend (RefCounted)
  host(options) -> String        # "" or an error; makes a MultiplayerPeer and assigns it
  join(target) -> String         # target = "ip:port" (ENet) or a Steam lobby id
  close()
  invite_friends()               # Steam: overlay invite dialog; ENet: shows your address
  set_status(text, players)      # Steam rich presence; ENet: no-op
  signals: lobby_ready, join_requested(target), member_list_changed
EnetBackend   - today's code from net.gd, plus LAN discovery later
SteamBackend  - GodotSteam lobbies + Steam MultiplayerPeer
```

`Net.host()` / `Net.join()` delegate to the active backend. Everything above them stays as it is.

### 4b. Steam invite multiplayer (design)

**Which GodotSteam build.**
- Verified on GitHub on 2026-11-19:
  - the latest release is **GodotSteam 4.24 (8 Nov 2026), "Godot 4.x – Steamworks 1.65"**;
  - the GitHub repo was **archived on 10 Nov 2026 and moved to Codeberg** (`codeberg.org/godotsteam/godotsteam`).
- Per the retired Codeberg MultiplayerPeer repo, the **MultiplayerPeer code was merged into the
  main GodotSteam 4.x branch**.
- UNVERIFIED (the docs site and Codeberg were unreachable from this session):
  - whether the **GDExtension** build includes the MultiplayerPeer;
  - whether a build exists for exactly **Godot 4.7.2**.
- Rule of thumb either way:
  - **prefer the GDExtension** if it includes the MultiplayerPeer and supports 4.7.x. You keep the official
    editor and export templates, and the itch build can simply leave the extension out;
  - otherwise use GodotSteam's **pre-compiled editor plus matching export templates** for 4.7.x. Then
    CI and tests must use that binary, and the itch build must still run with Steam absent.
  - Don't stack the GDExtension on top of a pre-compiled GodotSteam editor. Maintainers report that
    causes errors.
- The standalone expressobits SteamMultiplayerPeer GDExtension is **paused by its author**; avoid it.

**Flow** (GodotSteam API names below follow the Steamworks API and **must be checked against your
installed version**; UNVERIFIED in this session):

```mermaid
sequenceDiagram
    participant H as Host (Steam)
    participant S as Steam
    participant F as Friend (Steam)
    H->>S: createLobby(friends-only, 8)
    S-->>H: lobby_created(lobby_id)
    H->>S: setLobbyData("ver","9"), setRichPresence(...)
    H->>H: SteamMultiplayerPeer.create_host() -> multiplayer_peer<br/>start the lobby playground (existing)
    H->>S: activateGameOverlayInviteDialog(lobby_id)
    S-->>F: invite in Steam chat / overlay
    F->>S: accept (game running: join_requested signal;<br/>not running: Steam launches with +connect_lobby id)
    F->>S: joinLobby(lobby_id)
    S-->>F: lobby_joined -> getLobbyOwner()
    F->>H: SteamMultiplayerPeer.create_client(owner) over Steam Datagram Relay
    F->>H: existing _c_hello -> _s_welcome (world snapshot), unchanged
```

- **Ready-up.** You already have the right room: the **lobby playground**
  (`scripts/core/main.gd:49-52`). Map the Steam lobby onto it: everyone joins the playground and
  the host presses Enter.
  - Use lobby data for "ready" flags, or simply let the host start.
  - Lobby chat (`sendLobbyChatMsg`) is optional; the game has no chat UI today.
- **`+connect_lobby`.** Parse `OS.get_cmdline_args()` at startup, next to `DedicatedServer.parse_args`
  (`scripts/net/dedicated_server.gd:24-43`), which currently only knows `--key value`.
- **Rich Presence.**
  - Set `steam_display` to a localization token, e.g. `#Status_Match`, with `%players%` "3v3" and
    `%mode%`, defined in the Steamworks Rich Presence file.
  - Set `connect` to `+connect_lobby <id>` so "Join Game" works from the friends list.
- **Public lobby browser (optional, later).**
  - Use `requestLobbyList` with a string filter `ver=9` and the default distance filter.
  - Show name, players and mode.
  - It replaces `servers.json`.
- **Worth doing at launch:**
  - Steam Auto-Cloud for `user://settings.cfg` and `user://maps/*.bwmap` (configured in Steamworks,
    no code);
  - 8–12 simple achievements: first cheese, first win, a raid, 10 bonks, a teleporter trip, a self-launch.
- **Skip at launch:** stats and leaderboards.

**Testing**
- Use **AppID 480 (Spacewar)** with a `steam_appid.txt` next to the executable during development.
  - Steam's docs say not to ship that file.
  - 480 is shared by everyone, so tag your lobbies (`setLobbyData("game","burrowwars")`) and filter on it.
  - Developers report 480 lobbies being unreliable at times (UNVERIFIED); switch to your own AppID as
    soon as you have it.
- You need **two Steam accounts on two machines** (one Steam client per OS user); a cheap second
  laptop is enough.
- **Test cases:**
  - invite while the game is closed (the `+connect_lobby` path);
  - invite while it's running (`join_requested`);
  - host quits;
  - friend drops and rejoins;
  - mismatched versions.
- **Once your real AppID exists:**
  - replace 480;
  - upload builds with SteamPipe (depots per OS);
  - configure Rich Presence tokens, achievements and Auto-Cloud paths;
  - add a Steam Input default configuration;
  - make sure the shipped build does not contain `steam_appid.txt`.

### 4c. Do you need your own servers?

```mermaid
flowchart LR
    subgraph Steam build
        A[Host player's game<br/>real Match + NetServer] <-- Steam Datagram Relay --> B[Friend 1<br/>replica + NetClient]
        A <-- Steam Datagram Relay --> C[Friend 2..7]
        A -.lobby, invites, presence.-> S[(Steam backend)]
    end
    subgraph itch build
        D[Host: ENet, port 24565] <-- direct UDP / LAN --> E[Friend]
    end
    subgraph Later, only if needed
        G[Headless dedicated server<br/>existing --server mode] <-- ENet or Steam game server --> H[Public players]
    end
```

**1. Listen server with Steam P2P over Steam Datagram Relay (recommended for launch).**
- **Cost:** no server bills. Valve's relay network is widely reported as free for Steam games;
  official pricing is UNVERIFIED in this session.
- **NAT traversal:** SDR relays traffic over Valve's backbone, so nobody forwards ports.
- **Privacy:** it prevents IP addresses being revealed (Valve docs, via search).
- **Cheating:** the host is the authority, so a cheating host can do anything. Friends-only lobbies
  make that a social problem, not a technical one. Clients can still abuse trusted movement (P1 fix).
- **Host quits:** the match ends for everyone. That's acceptable for 10–20 minute matches; offer a
  rematch in the Steam lobby.

**2. Dedicated servers you host.**
- **Only needed for:** persistent worlds (you have none), ranked play, large public 24/7 lobbies, or
  anti-cheat beyond what a friends game needs.
- **The code already supports it:** the headless `--server` mode, tested.
- **Rough cost** (estimates, not quotes):
  - one 4v4 match used about 1–8 ms of a CPU core per 60 Hz tick here, so a small 2 vCPU / 4 GB
    VPS could likely host 2–4 matches;
  - a full 8-player match uses about 2 Mbit/s, roughly 650 GB/month if it runs 24/7;
  - budget about $10–40 per month per region at hobby scale (UNVERIFIED prices).
- **The real cost is ops:** patching every release, monitoring, regions, abuse and DDoS.
  **Not worth it for a solo launch.**

**3. Third-party relays and backends for non-Steam players.**
- **Epic Online Services:** reported as free, usable without the Epic Games Store, with P2P that
  falls back to relays when NAT punch-through fails (secondary sources; UNVERIFIED against Epic's docs).
- **Ways to use it:**
  - the itch build only;
  - or cross-play between Steam and itch, which doubles the integration and test work.
- **Paid relay services** such as Edgegap exist as an alternative (pricing UNVERIFIED).

**Recommendation**
- **Launch:** Steam lobbies plus Steam MultiplayerPeer, host-player authority, friends-only by
  default. The itch build keeps direct-IP ENet and LAN.
- **If the game takes off:**
  1. Add a public lobby browser.
  2. Fix movement trust (P1).
  3. Then consider a few official dedicated servers in the regions where players are, running the
     existing `--server` build, for public quick-play.
  4. Consider EOS cross-play only if itch or other storefronts bring meaningful numbers.

## 5. Platform answers (Phase 4)

### Own servers? **No (for launch).** Revisit if public matchmaking demand appears; see §4c.

### itch.io? **Yes**, same codebase, plus a direct-IP and LAN fallback.

**Keeping one codebase**
- **Build flag:** give Steam export presets `custom_features="steam"`, and branch on
  `OS.has_feature("steam")`.
- **No hard references to Steam:** only touch it through
  `Engine.has_singleton("Steam")` / `Engine.get_singleton("Steam")`, so scripts still parse and
  run without GodotSteam.
- **Steam not running:** if `steamInit` fails, fall back to `EnetBackend` with a notice, and never crash.
- **itch build:**
  - no Steam library at all;
  - the online menu shows "Host (direct IP)", "Join by address" and "LAN"; LAN is a small UDP
    broadcast discovery, about 1 day of work;
  - no achievements or invites.

**Fees and rules**
- **Revenue share:** itch.io's default is 10% and creators can set it themselves (itch.io).
- **Pricing:** paid, pay-what-you-want with a minimum, or free; a free demo download can sit on the
  same page (UNVERIFIED wording).
- **Upload with butler.** Syntax from memory, UNVERIFIED (itch.io docs were unreachable):

  ```bash
  butler push build/windows user/burrow-wars:windows --userversion 2.2.0
  ```

  Use one channel per platform (`windows`, `linux`, plus `windows-demo` if needed); a channel
  name containing the OS name gets tagged with that platform.
- **Selling on other stores:** Valve allows it. Its key guidelines ask that you **don't give Steam
  customers a worse deal** than buyers elsewhere: price parity for the same product, discounts
  mirrored within a reasonable time. That's per secondary sources quoting Steamworks;
  UNVERIFIED wording.
  - Safest: same price on both stores.
  - Only hand out Steam keys to itch buyers who paid at least the Steam price.

**Web (HTML5) demo: not now, maybe later as a bots-only demo.**
- **Threads:** Godot's threaded web export needs SharedArrayBuffer and cross-origin isolation.
  itch.io has an opt-in option for it. Godot 4.3+ can export without threads (Godot docs, 4.4 version).
- **Loading time:** without threads, the full-map meshing (1.77 s native, single-threaded) plus
  generation would be noticeably slower in WebAssembly. My estimate is roughly 5–10 s, UNMEASURED.
- **Multiplayer:** ENet is not available in browsers (WebSocket/WebRTC only; UNVERIFIED in this
  session), so it would need a second transport.
- **Verdict:** possible as a single-player "dig a cheese vs bots" demo after the meshing work
  (greedy meshing) lands. Not worth it for launch.

### Mobile? **Later, as a separate adaptation, not a launch target. Effort: High.**

- **Performance**
  - About 1 million triangles, all 256 chunks always loaded, and GDScript meshing at about 7 ms per
    chunk on a desktop CPU. All of that is too heavy for mid-range phones without greedy meshing,
    a view distance, and probably a smaller map or chunk streaming.
  - The Compatibility renderer you already use is the right choice for older phones; Godot's own
    guidance was not reachable here (UNVERIFIED).
- **Controls**
  - 30+ keyboard actions (`scripts/core/inputs.gd:7-43`), mouse aim, a hotbar and multiple dialogs
    all need redesign for touch: virtual stick, tap-to-dig, radial gadget menu, bigger UI.
  - Thermals and battery from continuous meshing and simulation are a real concern.
- **Multiplayer:** no Steam. You'd use EOS P2P (free per secondary sources) or LAN.
  - Cross-play with PC means shipping EOS on PC too. I'd skip cross-play.
- **Stores and costs**
  - **Google Play:**
    - one-time registration fee, $25 per secondary sources (UNVERIFIED);
    - new personal accounts must run a **closed test with at least 12 testers for 14 days**
      before production access (Google support page);
    - new apps and updates must target **Android 16 / API level 36 from 31 Aug 2026**
      (developer.android.com).
  - **Apple:**
    - **$99/year** (developer.apple.com);
    - **App Privacy details are required** to submit apps and updates;
    - iOS builds need a Mac with Xcode (UNVERIFIED in this session; standard for Godot iOS export).
  - **Age ratings:** both stores require a content rating questionnaire (Google uses IARC; UNVERIFIED here).
- **Recommendation:** ship on PC first. If the game finds an audience, consider a mobile spin-off
  with a smaller map, simplified tools and touch-first design. Budget **2–4 months** for that.

## 6. Phased roadmap

Efforts assume one developer working full-time, with me doing the code. Calendar time depends on
art and your testing time.

**A. Must-fix before any release** (about 1.5–2.5 weeks)
- Credits and licences screen, plus an asset-licence audit and the AI disclosure answers (P0).
- Final name, icon and version stamping (P0).
- Display settings, fullscreen default and SFX volume (P1).
- Threaded runtime re-meshing, plus greedy meshing or cheaper rock faces (P1).
- Action rate limiting (P1).
- Basic onboarding: a guided first match (P1).
- Atomic saves, cache cleanup and a quit-to-desktop button (P2, cheap).
- Re-run the full test gate after each item.

**B. Steam multiplayer** (about 2–3 weeks)
- `NetworkBackend` refactor with ENet behind it; tests must stay green (2–3 days).
- GodotSteam setup for 4.7.x and the export pipeline with AppID 480 (1–2 days).
- Lobbies, invites, `+connect_lobby`, `join_requested` and rich presence, mapped onto the existing
  playground lobby (4–6 days).
- Two-machine testing and fixes (2–3 days).
- Achievements and Auto-Cloud (1–2 days).
- Movement sanity checks, if you plan public lobbies (2–4 days).

**C. itch.io build** (about 1 week)
- Feature flags and the no-Steam fallback (1–2 days).
- LAN discovery (1 day).
- butler channels and a build script (½ day).
- Store page and pricing (1 day).
- Optional free demo build: limited goal, bots only (1 day).

**D. Steam store page and launch checklist** (4–8 weeks of calendar time, about 1–2 weeks of work)
- Pay the Steam Direct fee: **$100 per app, recoupable after $1,000 adjusted gross revenue**
  (Steamworks docs via search).
- Complete the store page:
  - capsule art in all sizes;
  - 5+ screenshots;
  - a 30–60 s trailer;
  - description, tags and the content survey, including AI disclosure.
- Submit the store page for review **at least 7 days ahead** (review typically takes 3–5 business days).
- Keep it **Coming Soon for at least 2 weeks** before release (Steamworks docs). Use that time for
  wishlists and Steam Next Fest if the dates line up.
- Builds:
  - SteamPipe depots for Windows and Linux;
  - a test on Steam Deck;
  - a Steam Input template;
  - build review.
- Decide between Early Access and full release. Early Access suits a multiplayer game that's still growing.
- **Launch day:** watch logs (Godot file logging is on by default), have a hotfix pipeline ready, and
  post known issues.

**E. Mobile** (only if A–D succeed; 2–4 months)
- Performance pass: greedy meshing, view distance, a smaller map.
- Touch UI and controls.
- EOS or LAN multiplayer.
- Store accounts and compliance.
- Closed test: 12 testers for 14 days on Google Play.

## 7. Open questions for you

1. **Final name.** Is "Jam Edition" staying? Have you checked "Burrow Wars" for trademark or store
   name clashes?
2. **Asset provenance.** Who made the rat sprites, the music and the original sound effects, and
   under what terms? Were any generated with AI tools? (This decides Steam's AI disclosure and
   whether anything needs replacing.)
3. **Price model.** Paid (what price?), free, or free with paid supporter pack? Early Access or full release?
4. **Platforms.** Windows and Linux only (my recommendation), or macOS too? macOS needs signing and
   notarization; details UNVERIFIED here.
5. **Do you want public matchmaking at launch, or friends-only invites?** This decides whether the
   movement anti-cheat work is P1 or can wait.
6. **Max players per match** for the Steam lobby: 8 (4v4) or 16? 16 roughly doubles host upload.
7. **Controller support:** is Steam Deck Verified a goal? It's the biggest single UX job (about 1–2 weeks).
8. **Cross-play between Steam and itch:** needed? My recommendation is no; it'd require EOS.
9. **Do you already have a Steamworks account and AppID?** Until then, Steam work uses AppID 480.
10. **Mobile:** is a phone version a real goal for 2027, or a curiosity? It changes how much I
    invest in greedy meshing and chunk streaming now.

## 8. Verification status of external facts

Checked on 2026-11-19. Several official sites were not reachable from this session (Steamworks
docs, godotsteam.com, itch.io docs, Godot docs, Epic docs, Google support). For those, I relied on
search results summarising the official pages and marked anything not confirmed as UNVERIFIED.

**Verified (official page read, or official page quoted in search results)**
- Godot 4.7.2 stable, released Aug 2026 ([godotengine.org](https://godotengine.org/article/maintenance-release-godot-4-7-2/)).
- GodotSteam 4.24, 8 Nov 2026, "Godot 4.x – Steamworks 1.65"; the GitHub repo was archived on
  10 Nov 2026 and moved to Codeberg ([GitHub releases](https://github.com/GodotSteam/GodotSteam/releases)).
- The MultiplayerPeer repo is retired and merged into GodotSteam 4.x ([Codeberg](https://codeberg.org/godotsteam/multiplayerpeer), via search).
- Steam Direct: $100, recoupable after $1,000 AGR ([Steamworks](https://partner.steamgames.com/doc/gettingstarted/appfee), via search).
- Coming Soon for at least 2 weeks; store review typically 3–5 business days ([Steamworks](https://partner.steamgames.com/doc/store/coming_soon), via search).
- Steam Deck: 9 px minimum text at 1280×800, 12 px recommended ([Steamworks](https://partner.steamgames.com/doc/steamdeck/compat), via search).
- SDR hides IPs and relays P2P traffic ([Steamworks](https://partner.steamgames.com/doc/features/multiplayer/steamdatagramrelay), via search).
- `steam_appid.txt` is for development only; don't ship it (Steamworks getting started, via search).
- itch.io: 10% default revenue share, configurable ([itch.io](https://itch.io/updates/open-revenue-sharing)).
- Godot licence compliance: include Godot's licence text plus third-party notices; a credits screen
  or bundled `COPYRIGHT.txt` both qualify ([Godot docs](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html), via search).
- Godot web export: threads need SharedArrayBuffer; a no-threads option exists ([Godot docs 4.4](https://docs.godotengine.org/en/4.4/tutorials/export/exporting_for_web.html), via search).
- Google Play: 12 testers for 14 days for new personal accounts ([Google](https://support.google.com/googleplay/android-developer/answer/14151465), via search).
- Android: target API 36 from 31 Aug 2026 ([developer.android.com](https://developer.android.com/google/play/requirements/target-sdk)).
- Apple: $99 per year ([developer.apple.com](https://developer.apple.com/support/enrollment/)); App Privacy details required ([developer.apple.com](https://developer.apple.com/app-store/app-privacy-details/)).

**UNVERIFIED (secondary sources or my knowledge only)**
- GodotSteam:
  - whether the GDExtension includes the MultiplayerPeer;
  - whether a build exists for exactly 4.7.2;
  - exact API and signal names.
- Steam:
  - SDR being free of charge;
  - the exact wording of the price-parity rules;
  - Deck controller criteria;
  - AppID 480 lobby reliability;
  - AI disclosure details (press reports of the Jan 2026 update).
- itch.io: butler syntax and channel tagging; HTML5 size limits.
- Godot: no ENet on the web.
- Google Play: the $25 fee; IARC ratings.
- iOS: needing a Mac and Xcode.
- Epic Online Services: free, relay fallback, no Epic Games Store requirement.
- All server hosting prices.
