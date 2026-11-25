# Sound list: everything to make, and what it's for

For whoever helps you make the sounds: every sound file the game plays, when it plays, how long
it is now, and what it should feel like. Replace a file by saving yours under the **same name** in
`assets/sfx/` (or `assets/music/`); no code changes. Section 3 lists sounds the game doesn't have
yet; send me those files and I'll hook them up.

## Format

- **WAV, 16-bit, mono, 44.1 kHz** (today's files are 22.05 kHz; either works). Music: **Ogg Vorbis**
  (`.ogg`) is much smaller; stereo is fine for music.
- **Peaks around -1 dBFS**, and make all effects roughly equally loud: the game sets each one's
  volume itself (`scripts/match/match_view.gd`), so I can rebalance any that end up too loud or quiet.
- **Short and dry**, no long reverb tails: the game adds distance, so a sound gets quieter farther away.
- **Neutral pitch** for anything that repeats a lot (digging, placing): the game varies the pitch
  slightly each time so repeats don't sound robotic.
- Style: a cartoon rat war in a voxel world. Chunky, toy-like, a bit clockwork and scrapyard;
  nothing gory.

**Status** today: **Old** = from earlier versions (free-licence or AI-made: replace). **Synth** =
synthesised placeholder made by `tools/make_sfx.py` (replace when you can).

## 1. Sound effects: `assets/sfx/` (30 files)

### Digging and building

| File | Plays when | Now | Status | What it should be |
|---|---|---:|---|---|
| `mine_dirt.wav` | Each dig hit on dirt, grass, cheese, team blocks, paint; also landing from a jump | 0.18 s | Old | Short soft thud of a trowel in earth |
| `mine_stone.wav` | Each dig hit on stone, brick, ice, glow crystal | 0.17 s | Old | Pick on rock: hard "tok" |
| `mine_scrap.wav` | Each dig hit on scrap ore, springs, conveyors | 0.17 s | Old | Clank of metal junk |
| `mine_obsidian.wav` | Each dig hit on obsidian, bases, gates; also borrowed (see section 2) | 0.21 s | Old | Glassy, very hard "tink" |
| `mine_wood.wav` | Each dig hit on wood, ladders, highways, traps; also Mobile TNT ticking and an Impulse Grenade sticking | 0.14 s | Old | Knock on wood |
| `break_dirt.wav` | A dirt-like block breaking | 0.23 s | Old | Crumbling clod |
| `break_stone.wav` | A stone-like block breaking | 0.29 s | Old | Rock cracking apart |
| `break_scrap.wav` | Scrap ore or a metal gadget breaking | 0.30 s | Old | Junk clattering apart |
| `break_obsidian.wav` | Obsidian breaking | 0.35 s | Old | Glass-like shatter, deep |
| `break_wood.wav` | Wood or a wooden gadget breaking | 0.24 s | Old | Planks snapping |
| `block_place.wav` | Placing a block or gadget; also borrowed for throws, respawns, springs (section 2) | 0.26 s | Old | Satisfying "thunk" of a block set down |

### Rats and cheese

| File | Plays when | Now | Status | What it should be |
|---|---|---:|---|---|
| `bonk.wav` | Bonking a rat; a mouse trap snapping on one | 0.21 s | Old | Comic bonk on the head: cartoony, not painful |
| `cheese_munch.wav` | Picking up cheese | 0.57 s | Old | Happy grab / nibble |
| `cheese_deposit_fanfare.wav` | Banking cheese at your base | 1.55 s | Old | Short triumphant jingle (plays often: keep it pleasant) |
| `team_victory_fanfare.wav` | A team wins the match (everyone hears it today, see section 3) | 3.60 s | Old | Big celebratory fanfare |
| `discovery_chime.wav` | Finding scrap, buying something, using an ability, a tutorial step done, the volume test | 0.55 s | Old | Bright "ding" of a reward |
| `alarm.wav` | Someone is raiding a vault (heard by everyone) | 1.60 s | Synth | Soft but urgent alarm bell; heard a lot, so not harsh |
| `squeak.wav` | An enemy steps on a Squeaker Pad | 0.36 s | Synth | Rubber squeaky toy |
| `toot.wav` | A Cheese Decoy goes off in someone's face | 0.75 s | Synth | Comic stink "toot" / party horn |
| `windup.wav` | Winding up a Wind-up Decoy; faster when it's about to blow | 0.62 s | Synth | Clockwork key winding, ratchet clicks |

### Gadgets, gear and the world

| File | Plays when | Now | Status | What it should be |
|---|---|---:|---|---|
| `jetratpack_flame.wav` | Jetpack burst (and borrowed for dash) | 2.50 s | Old | Rocket whoosh with a sputter; up to 1.1 s of thrust, fades out |
| `splash.wav` | Going into or out of water | 0.55 s | Synth | Splash |
| `sizzle.wav` | Touching lava; lava and water meeting | 0.70 s | Synth | Hiss and sizzle |
| `pop.wav` | A Bubble Shoes bubble appearing or popping | 0.12 s | Synth | Soap-bubble pop |
| `teleport.wav` | A teleporter trip (played at both pads) | 0.70 s | Synth | Sci-fi warp "vwoom" |
| `impulse.wav` | An Impulse Grenade bursting | 0.75 s | Synth | Air-pressure "fwump", no explosion |
| `tnt_pop.wav` | TNT and Mobile TNT exploding (layered with `siege_impact`) | 0.56 s | Old | Cartoon explosion: punchy pop |

### Siege machines

| File | Plays when | Now | Status | What it should be |
|---|---|---:|---|---|
| `siege_cannon.wav` | Scrap Cannon firing | 0.80 s | Old | Cannon boom with a metallic clank |
| `siege_impact.wav` | Cannonball, wrecking ball or blast hitting; ground pound | 0.55 s | Old | Heavy crunching impact |
| `siege_grind.wav` | Crane pumped, bulldozer ramming or turning; also placed TNT being lit | 1.20 s | Old | Gears grinding / machine effort |

## 2. Events that borrow another sound today

The game has these moments, but they reuse a sound made for something else. Each could have its
own; send any of these (same format) and I'll switch them over.

| Event | Borrows now | Suggested new file | What it should be |
|---|---|---|---|
| A meteor appearing (Meteor Shower) | `siege_grind` pitched up | `meteor_whistle.wav` | A falling whistle over about 3 s, heard from far away |
| A meteor striking | `tnt_pop` + `siege_impact`, pitched down | `meteor_impact.wav` | Deep, heavy boom with rumble and debris |
| Banking scrap / grabbing loose scrap (Scrap Race) | `discovery_chime` | `scrap_bank.wav` | A rattle of metal bits poured into a bin |
| Landing on a Spring / being launched | `block_place` | `spring.wav` | "Boing" |
| Throwing dynamite or a grenade | `block_place` | `throw.wav` | Quick whoosh |
| Respawning at base | `block_place` | `respawn.wav` | Little "pop in" / poof |
| Placing a teleporter pad | `block_place` | `tele_place.wav` | Small electric hum on |
| Picking up a dropped stash | `block_place` | `stash_pickup.wav` | Rummage / bag grab |
| Dash | `jetratpack_flame` | `dash.wav` | Short fast swish |
| Landing from a jump (jumping itself is silent) | `mine_dirt` | `land.wav` (and `jump.wav`) | Soft landing thump; a light hop |
| Raising the Rat Knight Shield | `mine_obsidian` | `shield_up.wav` | Shield clank up |
| A hit bouncing off the shield | `mine_obsidian` | `shield_block.wav` | Ringing metal deflect |
| A Team Gate taking a hit | `mine_obsidian` | `gate_hit.wav` | Heavy door thud |
| "Can't teleport with cheese" | `mine_obsidian` | `denied.wav` | Short buzzer "nope" (also useful for any refused action) |
| Impulse Grenade sticking | `mine_wood` | `stick.wav` | Sticky "thwap" |
| Placed TNT lit / Mobile TNT ticking | `siege_grind` / `mine_wood` | `fuse.wav`, `tick.wav` | Hissing fuse; a clockwork tick |
| Bulldozer turning | `siege_grind` | `dozer_turn.wav` | Treads squeaking round |
| Cheat code entered (lobby) | `team_victory_fanfare` / `discovery_chime` | `cheat_on.wav`, `cheat_off.wav` | Retro arcade power-up; and a sad descending blip |

## 3. Sounds the game doesn't have yet

| Suggested file | Would play when | Notes |
|---|---|---|
| `defeat.wav` | Your team loses. Today the victory fanfare plays for both teams | A comic "wah-wah"; short |
| `ui_click.wav`, `ui_hover.wav` | Menu buttons pressed / focused | Very short and soft (the menus are silent now) |
| `footstep_1..4.wav` | Rats walking and running | Tiny paw pats, a few variations |
| `round_start.wav` | A match starting (or the lobby countdown ending) | Whistle or bell |
| `countdown_tick.wav` | Last seconds of a dedicated server's lobby countdown | Clock tick |
| `cheese_drop.wav` | A bonk knocks cheese out of someone's paws | Plop |
| `stamina_empty.wav` | Trying to dash or double jump without stamina | Puff of tiredness |
| Ambience loops (`amb_surface.ogg`, `amb_cave.ogg`) | In the open / underground | Wind and birds; drips and echo. Optional |

## 4. Music: `assets/music/`

| File | Plays when | Now | Status |
|---|---|---:|---|
| `clockwork_colony.wav` | Everywhere: menus, lobby and matches, looping | 15.5 s loop | Old |

What a full set could be (send them as `.ogg` and tell me which is which; I'll switch tracks by
situation):
- **Menu theme**: calm, inviting, loops cleanly.
- **Match loop(s)**: energetic but not tiring for 10-20 minutes; two or three to rotate.
- **Playground lobby**: playful, lighter.
- **Victory and defeat stings**: 3-6 s each.

The same tracks can go into the Steam soundtrack add-on later; keep the full-quality
masters (WAV) for that.

## 5. Volume

Each sound's loudness relative to the others is set in code (`gain` values in
`scripts/match/match_view.gd`), and players have Master, Music and Effects sliders in Settings. If
a new sound is too loud or quiet next to the rest, tell me which and I'll rebalance it: no need to
re-export it.
