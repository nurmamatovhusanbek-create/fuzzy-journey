// Converts reference/i18n/{en,ru,uz}.js (default export dict) -> godot/data/i18n/*.json
// and reports missing keys / placeholder mismatches against English (missing keys fall back to English at runtime).
import fs from 'node:fs';
const en = (await import('../reference/i18n/en.js')).default;
const ph = (s) => (String(s).match(/\{\w+\}/g) || []).sort().join(',');
for (const l of ['en', 'ru', 'uz']) {
  const m = (await import(`../reference/i18n/${l}.js`)).default;
  fs.writeFileSync(`godot/data/i18n/${l}.json`, JSON.stringify(m));
  if (l === 'en') continue;
  const missing = Object.keys(en).filter((k) => !(k in m) && !k.startsWith('rn_'));
  const bad = Object.keys(m).filter((k) => k in en && ph(en[k]) !== ph(m[k]));
  if (missing.length) console.warn(`i18n ${l}: ${missing.length} keys fall back to English:`, missing.slice(0, 12).join(' '));
  if (bad.length) { console.error(`i18n ${l}: placeholder mismatch:`, bad.join(' ')); process.exitCode = 1; }
}
console.log('i18n ok');
