# Burrow Wars in the browser and on itch.io

The game runs in a browser from the same project. On itch.io players press **Run game** on the
page; no download, no install.

## What's different in a browser

- **Same game:** bot matches, Learn to Play, Free Build, settings, controllers.
- **Online:** a browser can only **join** servers, and only `wss://` ones: a public dedicated
  server set up as in [MULTIPLAYER.md](MULTIPLAYER.md#browsers-need-wss). It can't host a game,
  so the Host buttons aren't shown. Servers that only speak ENet (UDP) show "Desktop only" in the list.
- **The mouse:** the browser owns it. Click the game to start playing. **Esc** first gives the
  mouse back to the page and the game **pauses** when that happens; **P** also pauses. After
  pausing, click **Resume** (or click the game) to carry on.
- **Files:** settings and saved maps live in the browser's storage, so there's no Maps folder button.
  **Export map** also downloads the `.bwmap` file.
- **No Quit button** (close the tab), and no window-mode or V-Sync settings (the browser decides).

## The two builds

`tools/web_build.sh /path/to/godot` makes both, zips them, and boots each one in headless Chromium
to check it (the game starts, a Cheese Race loads, no errors).

| Build | Folder / zip | Needs | Use it |
|---|---|---|---|
| **No threads** | `build/web-nothreads/`, `build/BurrowWars_web_nothreads.zip` | nothing | **For the public alpha.** Runs in every browser, Safari included, with no experimental itch option. Loads a little slower and may hitch for a moment when a block breaks. |
| Threaded | `build/web/`, `build/BurrowWars_web.zip` | itch's **SharedArrayBuffer support** option (below) | Smoother: the map is built on several cores. Try it once you know your players' browsers. |

Why the alpha uses the no-threads build: itch's SharedArrayBuffer option is marked
**experimental** by itch, and it works by sending a header (`Cross-Origin-Embedder-Policy:
credentialless`) that, according to itch forum reports, **Safari doesn't support (unverified)**. A
public alpha should run for everyone, so the build without threads is the safe default.

Both are about 14 MB zipped (42 MB unpacked, most of it the engine).

## Try it on your own machine first

```bash
tools/web_build.sh /path/to/godot
```

```bash
python3 tools/serve_web.py build/web
```

Then open <http://localhost:8060> in Chrome, Edge or Firefox. The little server sends the same
headers itch.io's SharedArrayBuffer option does. Opening `index.html` straight from the folder does
**not** work: browsers won't run it from a file.

From the Godot editor: once the Web preset exists, a **Run in Browser** button appears with the
remote-deploy icons at the top right; it exports and opens the game in your browser.

## Putting it on itch.io

1. **Create a new project** on itch.io: Kind of project **HTML**. Pricing: **$0 or donate** (the
   free alpha with optional donations, `docs/RELEASE_PLAN.md`).
2. **Upload** `build/BurrowWars_web_nothreads.zip` and tick **This file will be played in the browser**.
3. Under **Embed options**:
   - Viewport dimensions **1280 x 720**;
   - **Fullscreen button**: on;
   - **Mobile friendly**: off (the game needs a keyboard and mouse or a controller);
   - **Automatically start on page load**: off (the click on Run game also lets the sound start);
   - **SharedArrayBuffer support**: leave it **off** for the no-threads build. Only the threaded
     build needs it. It's in the **Embed options** section, marked experimental (per itch's own
     forum posts; I couldn't open the edit page itself).
4. **Downloads** for desktop players: upload the Windows `.exe` (or a zip of it) and the Linux
   build as separate files and set their platform icons.
5. Save, open the page, press Run game, and play a match. If you upload the threaded build
   instead and the page shows an error about missing features (SharedArrayBuffer), the option in
   step 3 is off.

### Later updates with butler

[butler](https://itch.io/docs/butler/) uploads only what changed and keeps each download up to date.
Install it, run `butler login` once, then after building:

```bash
tools/itch_push.sh your-itch-name/burrow-wars
```

It pushes the no-threads build to the `html5` channel (`BW_WEB=threaded` in front pushes the
threaded one) and the Windows and Linux builds to `windows` and
`linux`, tagged with the game's version. The first time, mark the `html5` upload as "played in the
browser" on the itch page as in step 2.

## Checked so far, and what isn't

- **Checked here:** both builds export from Godot 4.7.2 and boot in headless Chromium with software
  rendering; the menu takes keyboard input, a Cheese Race loads (about 6 s threaded, 9 s without
  threads, with software rendering), P pauses, no console errors.
- **Not checked here:** real GPUs and frame rates, Firefox, Safari and the itch.io page itself (it
  needs your account). Please try it on your machine and on itch before announcing it, especially
  in Safari, where the threaded build depends on the SharedArrayBuffer option.
