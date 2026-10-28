// node tools/flags/sheet.mjs out.png [cols] id1 id2 ... : contact sheet of flags/authored/<id>.svg at game sizes (big + 192x128 + 48x32 + medal crop) for review
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import fs from 'fs'; import path from 'path';
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..');
const [out, cols, ...ids] = process.argv.slice(2);
const names = JSON.parse(fs.readFileSync(path.join(root, 'tools/flags/names.json'), 'utf8'));
const list = ids.length ? ids : Object.keys(names).sort();
const cell = id => { const f = path.join(process.env.FLAGDIR || path.join(root, 'flags/authored'), id + '.svg'); if (!fs.existsSync(f)) return ''; const u = 'data:image/svg+xml;base64,' + fs.readFileSync(f).toString('base64');
  return `<div class=c><img class=b src="${u}"><div class=r><img class=m src="${u}"><img class=s src="${u}"><div class=k style="background:url(${u}) center/auto 100%"></div></div><span>${id}</span></div>`; };
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
const p = await b.newPage({ viewport: { width: 1600, height: 800 } });
await p.setContent(`<style>body{margin:0;background:#15171c;color:#9aa;font:11px sans-serif}.g{display:grid;grid-template-columns:repeat(${cols || 6},1fr);gap:10px;padding:10px}.c{background:#1d2027;padding:6px;border-radius:6px}.b{width:100%;display:block}.r{display:flex;gap:8px;align-items:center;margin-top:5px}.m{width:96px}.s{width:48px;height:32px}.k{width:34px;height:34px;border-radius:50%}</style><div class=g>${list.map(cell).join('')}</div>`);
await p.waitForTimeout(400);
await p.screenshot({ path: out, fullPage: true });
await b.close();
