// Converts reference/i18n/{en,ru}.js (default export dict) -> godot/data/i18n/*.json
import fs from 'node:fs';
for (const l of ['en', 'ru']) {
  const m = await import(`../reference/i18n/${l}.js`);
  fs.writeFileSync(`godot/data/i18n/${l}.json`, JSON.stringify(m.default));
}
console.log('i18n ok');
