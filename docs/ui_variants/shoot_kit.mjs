// node shoot_kit.mjs <out.png> [file=bezel_kitparity.html] [w=1280] [h=1180] : the kit specimen sheet at 1 css px = 1 design unit (compare with godot/tests/kit_parity.gd)
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import path from 'path';
const here = path.dirname(new URL(import.meta.url).pathname);
const out = process.argv[2] || '/tmp/kit_ref.png'; const file = process.argv[3] || 'bezel_kitparity.html';
const W = +(process.argv[4] || 1280), H = +(process.argv[5] || 1180); const q = process.argv[6] ? '?' + process.argv[6] : '';   // 6th arg: 'phone' for the phone variant of the sheet
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
const p = await b.newPage({ viewport: { width: W, height: H } });
p.on('pageerror', e => console.log('PAGEERROR', e.message)); p.on('console', m => { if (m.type() === 'error') console.log('CONSOLE', m.text()); });
await p.goto('file://' + path.join(here, file) + q); await p.waitForTimeout(700);
await p.screenshot({ path: out });
await b.close();
