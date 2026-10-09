// node shoot.mjs <outdir> [w h]   screenshots every built variation
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import fs from 'fs'; import path from 'path';
const here = path.dirname(new URL(import.meta.url).pathname);
const out = process.argv[2] || '/tmp/claude-0/variants'; fs.mkdirSync(out, { recursive: true });
const W = +(process.argv[3] || 1920), H = +(process.argv[4] || 1080);
const only = process.argv[5];
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
for (const f of fs.readdirSync(here).filter(f => /^v\d.*\.html$/.test(f))) {
  if (only && !f.startsWith(only)) continue;
  const p = await b.newPage({ viewport: { width: W, height: H } });
  p.on('pageerror', e => console.log('PAGEERROR', f, e.message)); p.on('console', m => { if (m.type() === 'error') console.log('CONSOLE', f, m.text()); });
  await p.goto('file://' + path.join(here, f)); await p.waitForTimeout(700);
  await p.screenshot({ path: path.join(out, f.replace('.html', `_${W}x${H}.png`)) });
  await p.close();
}
await b.close();
