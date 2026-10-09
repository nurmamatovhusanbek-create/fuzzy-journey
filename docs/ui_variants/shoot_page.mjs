import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import path from 'path';
const here = path.dirname(new URL(import.meta.url).pathname);
const [file, out, w = 1400, h = 1000, full = '1'] = process.argv.slice(2);
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
const p = await b.newPage({ viewport: { width: +w, height: +h } });
p.on('pageerror', e => console.log('PAGEERROR', e.message));
await p.goto('file://' + path.join(here, file)); await p.waitForTimeout(600);
await p.screenshot({ path: out, fullPage: full === '1' }); await b.close();
