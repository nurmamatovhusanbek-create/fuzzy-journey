import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import fs from 'fs'; import path from 'path';
const here = path.dirname(new URL(import.meta.url).pathname);
const out = process.argv[2] || '/tmp/claude-0/bezel'; fs.mkdirSync(out, { recursive: true });
const file = process.argv[3] || 'bezel_full.html'; const W = +(process.argv[4] || 1920), H = +(process.argv[5] || 1080);
const states = (process.argv[6] || 'map,move,preview,budget,nations,annals,decrees,council,goals,event,war,menu,tip2,lens').split(',');
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
const p = await b.newPage({ viewport: { width: W, height: H } });
p.on('pageerror', e => console.log('PAGEERROR', e.message)); p.on('console', m => { if (m.type() === 'error') console.log('CONSOLE', m.text()); });
await p.goto('file://' + path.join(here, file)); await p.waitForTimeout(600);
for (const s of states) { await p.evaluate(s => window.demo.go(s), s); await p.waitForTimeout(450); await p.screenshot({ path: path.join(out, `${file.replace('.html', '')}_${s}.png`) }); }
await b.close();
