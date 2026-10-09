// node build.mjs : inlines map data, common.js and fonts into docs/ui_variants/*.html from src/v*.html
import fs from 'fs'; import path from 'path';
const here = path.dirname(new URL(import.meta.url).pathname);
const F = '../../godot/assets/fonts/';
const font = (fam, file, w, style = 'normal') => `@font-face{font-family:'${fam}';font-weight:${w};font-style:${style};src:url(data:font/woff2;base64,${fs.readFileSync(path.join(here, F, file)).toString('base64')}) format('woff2')}`;
const FONTS = [
  font('Cinzel', 'cinzel-latin-500-normal.woff2', 500), font('Cinzel', 'cinzel-latin-700-normal.woff2', 700),
  font('Alegreya', 'alegreya-latin-400-normal.woff2', 400), font('Alegreya', 'alegreya-latin-500-normal.woff2', 500), font('Alegreya', 'alegreya-latin-700-normal.woff2', 700), font('Alegreya', 'alegreya-latin-400-italic.woff2', 400, 'italic'),
  font('Inter', 'inter-latin-400-normal.woff2', 400), font('Inter', 'inter-latin-500-normal.woff2', 500), font('Inter', 'inter-latin-600-normal.woff2', 600),
  font('Barlow Condensed', 'barlow-condensed-latin-500-normal.woff2', 500), font('Barlow Condensed', 'barlow-condensed-latin-600-normal.woff2', 600),
  font('JetBrains Mono', 'jetbrains-mono-latin-400-normal.woff2', 400), font('JetBrains Mono', 'jetbrains-mono-latin-700-normal.woff2', 700),
].join('\n');
const data = fs.readFileSync(path.join(here, 'src/map_data.js'), 'utf8');
const common = fs.readFileSync(path.join(here, 'src/common.js'), 'utf8');
for (const f of fs.readdirSync(path.join(here, 'src')).filter(f => /^v\d.*\.html$/.test(f))) {
  let h = fs.readFileSync(path.join(here, 'src', f), 'utf8');
  h = h.replace('/*FONTS*/', () => FONTS).replace('/*MAPDATA*/', () => data + common);
  fs.writeFileSync(path.join(here, f.replace(/^v/, 'v')), h);
  console.log(f, (h.length / 1024).toFixed(0) + 'KB');
}
