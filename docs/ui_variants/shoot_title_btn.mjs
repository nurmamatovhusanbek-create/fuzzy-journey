import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import fs from 'fs'; import path from 'path';
const here = path.dirname(new URL(import.meta.url).pathname);
const out = process.argv[2] || '/tmp/pb/title'; fs.mkdirSync(out, { recursive: true });
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
const p = await b.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 2 });
p.on('pageerror', e => console.log('PAGEERROR', e.message));
for (const n of [1,2,3,4,5]) { await p.goto('file://' + path.join(here, 'bezel_title.html') + '?m=m2&b=' + n); await p.waitForTimeout(400);
  await p.screenshot({ path: path.join(out, `btn_${n}.png`), clip: { x: 20, y: 270, width: 330, height: 250 } });
  await p.screenshot({ path: path.join(out, `btnfull_${n}.png`), clip: { x: 0, y: 0, width: 1280, height: 720 } }); }
await b.close();
