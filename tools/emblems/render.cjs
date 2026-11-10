// Renders every symbol of emblems.svg to a 256 px white-on-transparent mask (the engraved cuts are knocked out), for godot/assets/emblems/<id>.png.
// Usage: NODE_PATH=$(npm root -g) node tools/emblems/render.cjs <outdir>      then  python3 tools/emblems/post.py <outdir>
const { chromium } = require('playwright'); const fs = require('fs'); const path = require('path');
const dir = __dirname; const out = process.argv[2]; fs.mkdirSync(out, { recursive: true });
const src = fs.readFileSync(path.join(dir, 'emblems.svg'), 'utf8'); const ids = fs.readFileSync(path.join(dir, 'ids.txt'), 'utf8').split('\n').filter(Boolean);
(async () => {
  const b = await chromium.launch(); const pg = await b.newPage({ viewport: { width: 300, height: 300 }, deviceScaleFactor: 1 });
  for (const id of ids) {
    const sym = src.match(new RegExp('id="[in]-' + id + '"'))[0].slice(4, -1);
    const html = `<style>html,body{margin:0;background:transparent}.a2{color:#fff;fill:#fff;stroke:#fff;stroke-width:1.1;stroke-linejoin:round}.k{stroke:#000;fill:none;stroke-linecap:round;stroke-linejoin:round}.kf{fill:#000;stroke:none}.sep{stroke:#000;stroke-width:2.4;paint-order:stroke}</style>${src}<svg id="s" class="a2" width="256" height="256" viewBox="-1 -1 50 50" style="display:block"><use href="#${sym}" width="48" height="48"/></svg>`;
    await pg.setContent(html);
    await pg.locator('#s').screenshot({ path: path.join(out, id + '.raw.png'), omitBackground: true });
  }
  await b.close();
})();
