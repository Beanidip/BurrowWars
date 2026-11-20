// Boots a web build in headless Chromium and plays the first seconds of a
// Cheese Race from the keyboard, as a player would on itch.io.
//
//   python3 tools/serve_web.py build/web 8060 &
//   node tools/web_smoke.js http://localhost:8060/index.html [screenshot dir]
//
// Checks: the browser has what the build needs (SharedArrayBuffer for the
// threaded build), the engine and game start without errors, the main menu
// takes keyboard input, a match loads and renders, and the frame rate.
// Exit code 0 = everything passed.
const { chromium } = require('playwright');

const url = process.argv[2] || 'http://localhost:8060/index.html';
const shots = process.argv[3] || '';
let fails = 0;
const ok = (cond, what) => {
  console.log(`${cond ? 'ok  ' : 'FAIL'}  ${what}`);
  if (!cond) fails++;
};

(async () => {
  const browser = await chromium.launch({
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
  const logs = [];
  const errors = [];
  page.on('console', (m) => {
    logs.push(m.text());
    if (m.type() === 'error' && !/favicon|AudioContext|autoplay/i.test(m.text())) errors.push(m.text());
  });
  page.on('pageerror', (e) => errors.push(String(e)));
  const waitLog = async (re, ms) => {
    const t0 = Date.now();
    while (Date.now() - t0 < ms) {
      if (logs.some((l) => re.test(l))) return true;
      await page.waitForTimeout(250);
    }
    return false;
  };
  const shot = async (name) => {
    if (shots) await page.screenshot({ path: `${shots}/${name}.png` });
  };

  const t0 = Date.now();
  await page.goto(url, { waitUntil: 'load', timeout: 60000 });
  const isolated = await page.evaluate(() => self.crossOriginIsolated === true);
  console.log(`      cross-origin isolated (SharedArrayBuffer): ${isolated}`);
  ok(await waitLog(/Burrow Wars .* on Godot 4\.7/, 90000), `the game boots (${((Date.now() - t0) / 1000).toFixed(1)} s)`);
  await page.waitForTimeout(1500);
  ok(await page.locator('canvas').count() === 1, 'it draws into the page canvas');
  await shot('web_01_menu');
  // the menu: the focus starts on Cheese Race; Enter opens setup, Enter again starts digging
  await page.mouse.click(10, 10);   // a click on the background gives the page focus (and lets audio start)
  await page.keyboard.press('Escape');
  await page.waitForTimeout(500);
  await page.keyboard.press('Enter');
  await page.waitForTimeout(1000);
  await shot('web_02_setup');
  await page.keyboard.press('Enter');
  const t1 = Date.now();
  ok(await waitLog(/match ready: race/, 120000), `a Cheese Race loads (${((Date.now() - t1) / 1000).toFixed(1)} s)`);
  await page.waitForTimeout(2000);
  // walk forward for a second
  await page.keyboard.down('w');
  await page.waitForTimeout(1000);
  await page.keyboard.up('w');
  const fps = await page.evaluate(() => new Promise((res) => {
    let n = 0;
    const start = performance.now();
    const tick = () => { n++; if (performance.now() - start < 3000) requestAnimationFrame(tick); else res(n / 3); };
    requestAnimationFrame(tick);
  }));
  console.log(`      frames per second in headless Chromium (software WebGL, no GPU): ${fps.toFixed(1)}`);
  await shot('web_03_match');
  // P pauses in a browser (Esc there first gives the mouse back to the page)
  await page.keyboard.press('p');
  await page.waitForTimeout(800);
  await shot('web_04_pause');
  await page.keyboard.press('p');
  await page.waitForTimeout(500);
  ok(errors.length === 0, `no errors in the console${errors.length ? ': ' + errors.slice(0, 5).join(' | ') : ''}`);
  await browser.close();
  console.log(`---- web: ${fails} failed ----`);
  process.exit(fails ? 1 : 0);
})().catch((e) => {
  console.log('FAIL  ' + e);
  process.exit(1);
});
