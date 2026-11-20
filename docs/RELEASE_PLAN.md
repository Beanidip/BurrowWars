# Release plan

Decided 2026-11-20: release in three phases and pick the price from what players do, not up front.
This file turns that into checklists for this project. Facts about stores that I couldn't
confirm from the official pages are marked **(unverified)**.

## Phase 1: free public alpha on itch.io

Free to play, with optional donations. Goal: a small community, and real games to test
multiplayer, mining and traps.

**Before going live**
- [ ] **Art and sound you're allowed to ship.** `docs/ASSET_LICENSES.md` lists the rat side views,
      menu art, most sounds and the music as *legacy placeholders* from v0.15.1 with unknown origin,
      marked "must not ship". Even a free alpha distributes them. Either confirm they're yours
      (or properly licensed) and note it in the ledger, or wait for the redraw.
- [ ] **Builds:**
      - the browser build with `tools/web_build.sh`, uploading the **no-threads** zip for now
        (`docs/ITCH.md` says why);
      - the Windows and Linux downloads exported from the editor.
- [ ] **itch page:**
      - pricing **"$0 or donate"** (free, with an optional tip);
      - embed settings and uploads as in `docs/ITCH.md`;
      - say "alpha" in the title or tagline, and in the description what to test.
- [ ] **Somewhere to hear back:** itch's community board for the page (a setting on itch), or a
      Discord. Say in the description where bug reports go.
- [ ] **One or two public servers:** a VPS each, run with `--transport ws` behind Caddy for `wss://`
      (`docs/MULTIPLAYER.md`). List them in `servers.json` on `main`, so every copy of the game
      finds them. Browser players can only play online on these.
- [ ] **Try it end to end yourself:** the itch page in Chrome, Firefox and Safari, a desktop
      download, and a browser player and a desktop player in one game on your server.

**While it runs**
- Each server logs `anti-cheat:` lines. Lots from honest players means a check is too strict:
  send me the lines.
- Each server's status page (`https://<your domain>/status`) shows who's playing.
- Bump the version (Project Settings > Application > Config > Version) for every upload.
  Players on an older version can't join a newer server: the list says "Needs version ...".
- `tools/itch_push.sh` uploads new builds with butler; itch players get them automatically.

## Phase 2: free Steam Playtest

Players request access and invite friends while balance and stability get better, without
committing to a free release.

How Steam Playtest works (Steamworks docs, as summarised by search; I couldn't open the page itself):
- It's a **separate app attached to your main game**, with its own builds and the same
  Steamworks features, but no store page of its own. Sign-up shows as a section on the main
  game's page, or players get keys.
- It's **free for you and for testers**, and **can't be monetised in any way** (no paid access,
  no selling keys).
- You still need the **main game's app**, so the **$100 Steam Direct fee** (one per app). Valve's
  page says the store page doesn't have to be public to run a playtest with keys **(unverified)**.

**To do**
- [ ] Steamworks partner account: identity, tax and bank details. This takes days to weeks, so
      start before Phase 1 ends.
- [ ] Pay the Steam Direct fee for Burrow Wars and set up the Playtest app.
- [ ] Steam integration (GodotSteam): friend invites and Steam lobbies (design in
      `docs/RELEASE_REVIEW.md` §4b), the Deck's on-screen keyboard for text boxes, achievements,
      and Steam Input glyph art.
- [ ] Steam Deck check on a borrowed Deck. Everything already works with a controller and has a
      test at 1280x800.
- [ ] Playtest builds go up with SteamCMD / ContentBuilder. I'll write the script once there's
      an AppID.

## Phase 3: decide on traction

| If... | Then |
|---|---|
| Players love it and keep coming back | A **one-time purchase, about $4.99-9.99**. The soundtrack add-on can still be the "give more" option. |
| It grows best as a free game | **Free**, with optional **cosmetic supporter packs**. |

Things to know before choosing:
- **Cosmetics don't exist yet.** Hats, rat skins, trails and so on would be a new feature. Who owns
  which pack would come from Steam DLC ownership. On itch or in a browser there's no ownership
  check, so packs could only be "honour system" or Steam-only.
- **Paid on Steam while the itch version stays free:** the earlier review noted developers report
  Valve objecting when the same game is free elsewhere **(unverified)**. If you go paid, the usual
  answer is to keep only an older build or a clearly limited demo free on itch.
- Either way, keep the **public servers cross-play** (Steam, itch desktop and browser on the same
  servers). Splitting a small community hurts more than any price.

## Not in the plan yet

- Android and mobile: asked earlier, still open.
- macOS: needs an Apple Developer ID ($99/year) for signing and notarisation, and a Mac to test on.
