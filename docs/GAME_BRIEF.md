# Burrow Wars: brief for planning features and art direction

Paste this into an AI chat before asking it for ideas. It describes the game as it exists today.

## The pitch

Burrow Wars is a team-based multiplayer voxel digging game. Two rival rat civilizations, Blue and
Red, tunnel through a destructible block world to find golden cheese and haul it home. It plays like
a capture-the-flag race crossed with a mining-and-building sandbox. The tone is playful and
slapstick: nobody gets hurt, rats get **bonked**, drop their cheese and scramble.

- **Engine:** Godot 4.7 (GDScript), Compatibility renderer so it runs on low-end PCs and in browsers.
- **Platforms:** Windows, Linux, macOS, web browser (itch.io). Steam Deck Verified is a goal. Full
  controller support. Android is undecided.
- **Players:** 8v8 in games hosted by players, 16v16 on dedicated servers. Bots fill empty seats.
  Cross-play between desktop and browser. In-game public server browser.
- **Business plan:** a free alpha on itch with donations, then a free Steam Playtest, then either
  $4.99-9.99 or free with cosmetic supporter packs, depending on traction. Cosmetics must never be
  pay-to-win.
- **No mods at launch.** Achievements are planned for Steam.

## The core loop

1. **Dig** through dirt, stone and deeper layers to find golden cheese. Each cheese block is one
   cheese.
2. **Carry it home.** Carrying makes you crawl, so you need a plan: dash, lay highways (fast plank
   roads), use conveyors, springs or teleporters, or bring an escort.
3. **Bonk** enemy rats to make them drop a cheese. Steal it back.
4. **Mine scrap** (orange ore) and spend it at your base's **workshop** on gadgets, traps, gear and
   siege machines. Every banked cheese raises the value of newly mined scrap, so matches speed up.
5. **Raid** the enemy base: stand inside it for 3 seconds to steal a banked cheese. A defender at
   home locks the vault.
6. First team to the cheese goal wins. Rounds are short, so you play many in a row.

## Classes

| Class | Identity |
|---|---|
| Digger | Slow, big stamina, carries 3 cheese. The miner |
| Scout | Fastest, swims well. The runner and thief |
| Builder | Can use the workshop anywhere. The engineer |
| Saboteur | Traps and trickery |

Each class has two abilities (E and F). Everyone shares the basics: jump, double jump, a ground
pound, dash, climbing and swimming.

## Things you can buy and build

- **Mobility:** ladders, springs, wall springs, highways, conveyors, one-way team teleporters,
  impulse grenades (push-only blast for launching yourself or others; no terrain damage).
- **Traps:** mouse traps (stun plus a dropped cheese), squeaker pads (alarms), TNT, team gates.
- **Decoys:** cheese decoys and a wind-up decoy that walks around; bots fall for them.
- **Gear:** jetpack (half strength while carrying cheese), Rat Knight Shield, Bubble Shoes.
- **Siege machines:** a scrap cannon (2 scrap a shot, big knockback blast), a crane with a wrecking
  ball that smashes through several blocks, and a turnable bulldozer. You can carry them on
  conveyors. Mobile TNT bounces.
- **Building:** place dirt, stone, ice, obsidian, painted blocks and glass (36 colours). A chisel
  carves and adds microvoxels. A "pantograph" copies, rotates, mirrors and pastes structures.
- **World:** water and lava flow and spread, caves get richer the deeper you go, and cheese
  carriers leave a crumb trail.

## Modes

- **Cheese Race:** the main competitive mode.
- **Free Build:** a creative sandbox with flight, saving and loading maps.
- **Lobby playground:** a free-for-all warm-up while players gather.
- **Tutorial:** a guided first match.

## Current look

- **World:** a 3D voxel world of solid-coloured blocks. Only scrap has a texture so far; the rest
  are flat colours with shading. Water and lava have sloped edges.
- **Rats:** 2D pixel-art sprites standing in the 3D world, like Paper Mario or Don't Starve. Each
  class has side, front and back sheets (72x72 frames: idle, run, jump, dig, attack, hurt, build,
  use, down). Team colour comes from magenta areas the game tints blue or red.
- **Effects:** pixel-art sprite animations (explosions, block-coloured break bursts, dust, splashes,
  jetpack flame, fireworks when cheese is banked).
- **UI:** a wooden 9-slice panel with a blue/red frame, and 16x16 pixel icons for every item.
- **Camera:** first or third person.

**All current art and sound are placeholders** (free-licence or AI-made), except the MIT pixel
effects, and are being replaced with original work. The plan is to **keep the pixel-sprite-in-voxel
style** and give it a distinctive coat of paint. The asset list is in `ART_TO_MAKE.md` and the
sound list in `SOUND_LIST.md`.

## Limits to respect when suggesting things

- It must run in a browser and on a Steam Deck. That means a light renderer, modest polygon counts,
  no heavy shaders and small downloads.
- Everything is server-authoritative multiplayer with anti-cheat. New mechanics need to work over
  the network for 32 players.
- One main developer making their own art and sound, so cheap-to-make, high-impact ideas beat big
  content pipelines.
- The tone is family-friendly slapstick, with no blood or deaths.

## Questions I want help with

- New features, modes, gadgets or traps that deepen the dig, haul, raid and defend loop.
- An art direction for the world, rats, UI and effects that's distinctive and a solo artist can
  make.
- Cosmetics people would happily pay for, without pay-to-win.
- What would make streamers and new players "get it" in the first 30 seconds.
