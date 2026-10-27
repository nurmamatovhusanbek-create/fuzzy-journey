import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import fs from 'fs'; import path from 'path';
const here = path.dirname(new URL(import.meta.url).pathname);
const out = process.argv[2] || '/tmp/pb/ng'; fs.mkdirSync(out, { recursive: true });
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
p.on('pageerror', e => console.log('PAGEERROR', e.message));
for (const m of ['a3a','a3b','a4']) { await p.goto('file://' + path.join(here, 'bezel_newgame.html') + '?m=' + m); await p.waitForTimeout(500); await p.screenshot({ path: path.join(out, `${m}.png`) }); }
await b.close();
