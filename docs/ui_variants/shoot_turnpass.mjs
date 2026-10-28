import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import path from 'path';
const here = path.dirname(new URL(import.meta.url).pathname);
const out = process.argv[2] || '/tmp/c4.png';
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
const p = await b.newPage({ viewport: { width: 2020, height: 1400 } });
p.on('pageerror', e => console.log('PAGEERROR', e.message));
await p.goto('file://' + path.join(here, 'bezel_turnpass.html')); await p.waitForTimeout(600);
await p.screenshot({ path: out, fullPage: true }); await b.close();
