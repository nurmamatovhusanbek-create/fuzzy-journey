// node tools/flags/rasterize.mjs coldwar : flags/src/*.svg -> godot/assets/flags/<era>/<nation>.png (192x128, aspect kept, transparent letterbox)
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import fs from 'fs'; import path from 'path';
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..');
const era = process.argv[2];
const M = JSON.parse(fs.readFileSync(path.join(root, 'tools/flags', era + '_map.json'), 'utf8'));
const slug = t => t.slice(0, -4).replace(/[^A-Za-z0-9]+/g, '_').replace(/^_|_$/g, '').toLowerCase();
const outDir = path.join(root, 'godot/assets/flags', era); fs.mkdirSync(outDir, { recursive: true });
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
const p = await b.newPage();
await p.setContent('<canvas id=c width=192 height=128></canvas>');
let ok = 0, miss = [];
for (const [nat, v] of Object.entries(M)) {
  let svg;
  if (v.title) { const f = path.join(root, 'flags/src', slug(v.title) + '.svg'); if (!fs.existsSync(f)) { miss.push(nat); continue; } svg = fs.readFileSync(f, 'utf8'); }
  else { const f = path.join(root, 'flags/authored', nat + '.svg'); if (!fs.existsSync(f)) { miss.push(nat); continue; } svg = fs.readFileSync(f, 'utf8'); }
  const png = await p.evaluate(async (svg) => {
    const m = svg.match(/viewBox="([\d.\s-]+)"/); let w = 300, h = 200;
    if (m) { const a = m[1].trim().split(/\s+/).map(Number); w = a[2]; h = a[3]; }
    else { const mw = svg.match(/<svg[^>]*\swidth="([\d.]+)/), mh = svg.match(/<svg[^>]*\sheight="([\d.]+)/); if (mw && mh) { w = +mw[1]; h = +mh[1]; } }
    const url = URL.createObjectURL(new Blob([svg.replace(/<svg([^>]*?)\swidth="[^"]*"/, '<svg$1').replace(/<svg([^>]*?)\sheight="[^"]*"/, '<svg$1').replace('<svg', `<svg width="${w}" height="${h}"`)], { type: 'image/svg+xml' }));
    const img = new Image(); img.src = url; await img.decode().catch(() => {});
    const c = document.getElementById('c'), x = c.getContext('2d'); x.clearRect(0, 0, 192, 128);
    const s = Math.min(190 / w, 126 / h), dw = w * s, dh = h * s;
    x.imageSmoothingQuality = 'high'; x.drawImage(img, (192 - dw) / 2, (128 - dh) / 2, dw, dh);
    return c.toDataURL('image/png').split(',')[1];
  }, svg);
  fs.writeFileSync(path.join(outDir, nat + '.png'), Buffer.from(png, 'base64')); ok++;
}
console.log('rasterised', ok, 'missing', miss.join(','));
await b.close();
