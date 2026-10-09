import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import path from 'path';
const here = path.dirname(new URL(import.meta.url).pathname);
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
const sizes = [[1920,1080],[1366,768],[2560,1080],[1440,900],[844,390],[740,360],[932,430],[2340,1080]];
for (const [w,h] of sizes) {
  const p = await b.newPage({ viewport: { width: w, height: h } });
  await p.goto('file://' + path.join(here, 'bezel_demo.html')); await p.waitForTimeout(400);
  const res = await p.evaluate(() => {
    const R = (el) => { const r = el.getBoundingClientRect(); return { x: r.left, y: r.top, w: r.width, h: r.height }; };
    const items = [];
    const add = (name, sel, all) => { const els = all ? [...document.querySelectorAll(sel)] : [document.querySelector(sel)]; els.forEach((e, i) => { if (e) items.push([name + (all ? i : ''), R(e)]); }); };
    add('medal', '[data-tip=nation]'); add('gauge', '#top .g', true); add('date', '[data-tip=date]'); add('gear', '#gear');
    add('alert', '#alerts .pill', true); add('rail', '.rail-b', true); add('mm', '#mm circle'); add('zoom', '#zoom button', true); add('tuner', '#tuner svg'); add('chrono', '#chg'); add('tag', '#tagbox > div'); add('endlbl', '#chrono svg text');
    const out = [];
    for (let i = 0; i < items.length; i++) for (let j = i + 1; j < items.length; j++) {
      const a = items[i][1], c = items[j][1];
      if (items[i][0].startsWith('endlbl') || items[j][0].startsWith('endlbl')) continue;
      const ox = Math.min(a.x + a.w, c.x + c.w) - Math.max(a.x, c.x), oy = Math.min(a.y + a.h, c.y + c.h) - Math.max(a.y, c.y);
      if (ox > 2 && oy > 2) out.push(`${items[i][0]} x ${items[j][0]} (${ox.toFixed(0)}x${oy.toFixed(0)})`);
    }
    const W = innerWidth, H = innerHeight, off = items.filter(([n, r]) => r.x < -1 || r.y < -1 || r.x + r.w > W + 1 || r.y + r.h > H + 1).map(i => i[0]);
    return { out, off };
  });
  console.log(w + 'x' + h, JSON.stringify(res));
  await p.close();
}
await b.close();
