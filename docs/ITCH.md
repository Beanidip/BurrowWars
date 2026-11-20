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
| **Threaded** | `build/web/`, `build/BurrowWars_web.zip` | itch's **SharedArrayBuffer support** option (below) | **Recommended.** The map is built on several cores, so it loads faster and digging never stutters. |
| No threads | `build/web-nothreads/`, `build/BurrowWars_web_nothreads.zip` | nothing | A fallback, if some players' browsers show an error with the threaded build. Loads a little slower and can hitch while digging. |

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

1. **Create a new project** on itch.io: Kind of project **HTML**. Pricing: **No payments** (free)
   or **Donations**, as you decided.
2. **Upload** `build/BurrowWars_web.zip` and tick **This file will be played in the browser**.
3. Under **Embed options**:
   - Viewport dimensions **1280 x 720**;
   - **Fullscreen button**: on;
   - **Mobile friendly**: off (the game needs a keyboard and mouse or a controller);
   - **Automatically start on page load**: off (the click on Run game also lets the sound start);
   - **SharedArrayBuffer support**: **on** (needed by the threaded build). I couldn't open itch's
     edit page from here, so where exactly the checkbox sits is **unverified**; it's among the
     embed / frame options.
4. **Downloads** for desktop players: upload the Windows `.exe` (or a zip of it) and the Linux
   build as separate files and set their platform icons.
5. Save, open the page, press Run game, and play a match. If it shows an error about missing
   features (SharedArrayBuffer), check the option in step 3, or upload the no-threads zip instead.

### Later updates with butler

[butler](https://itch.io/docs/butler/) uploads only what changed and keeps each download up to date.
Install it, run `butler login` once, then after building:

```bash
tools/itch_push.sh your-itch-name/burrow-wars
```

It pushes `build/web` to the `html5` channel and the Windows and Linux builds to `windows` and
`linux`, tagged with the game's version. The first time, mark the `html5` upload as "played in the
browser" on the itch page as in step 2.

## Checked so far, and what isn't

- **Checked here:** both builds export from Godot 4.7.2 and boot in headless Chromium with software
  rendering; the menu takes keyboard input, a Cheese Race loads (about 6 s threaded, 9 s without
  threads, with software rendering), P pauses, no console errors.
- **Not checked here:** real GPUs and frame rates, Firefox, Safari and the itch.io page itself (it
  needs your account). Please try it on your machine and on itch before announcing it, especially
  in Safari, where the threaded build depends on the SharedArrayBuffer option.
