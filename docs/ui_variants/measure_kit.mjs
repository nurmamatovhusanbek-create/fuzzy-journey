// node measure_kit.mjs '<css selector>' [file] : prints x y w h of every match on the kit parity sheet (1 css px = 1 design unit)
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import path from 'path';
const here = path.dirname(new URL(import.meta.url).pathname);
const sel = process.argv[2] || '.bt'; const file = process.argv[3] || 'bezel_kitparity.html';
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
const p = await b.newPage({ viewport: { width: 1280, height: 1180 } });
await p.goto('file://' + path.join(here, file)); await p.waitForTimeout(500);
const r = await p.evaluate(s => [...document.querySelectorAll(s)].map(e => { const q = e.getBoundingClientRect(); return [e.textContent.trim().slice(0, 18), +q.x.toFixed(2), +q.y.toFixed(2), +q.width.toFixed(2), +q.height.toFixed(2)]; }), sel);
for (const x of r) console.log(x.join('\t'));
await b.close();
