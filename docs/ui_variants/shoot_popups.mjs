import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import fs from 'fs'; import path from 'path';
const here = path.dirname(new URL(import.meta.url).pathname);
const out = process.argv[2] || '/tmp/pb/pop'; fs.mkdirSync(out, { recursive: true });
const modes = process.argv[3] ? process.argv[3].split(',') : ['war1','war2','war3','ev1','ev2','evglyphs','battle','treaty','summary','win','lose','ch0','ch1','ch2','ch3','ch4'];
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
const p = await b.newPage({ viewport: { width: 1920, height: 1080 } });
p.on('pageerror', e => console.log('PAGEERROR', e.message));
p.on('console', m => { if (m.type() === 'error') console.log('CONSOLE', m.text()); });
for (const m of modes) { await p.goto('file://' + path.join(here, 'bezel_popups.html') + '?m=' + m); await p.waitForTimeout(500); await p.screenshot({ path: path.join(out, `${m}.png`) }); }
await b.close();
