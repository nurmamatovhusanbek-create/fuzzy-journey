#!/usr/bin/env node
// Enforces docs/ARCHITECTURE.md's layering table by scanning godot/src/*.gd for `res://src/<layer>/` references (preload/load calls, and GDScript's
// implicit global `class_name` references leave no literal path to grep, so those are covered by the explicit allow-lists below instead) and for
// `extends Node` (or a Node subtype) inside the engine layer, which must stay headless (RefCounted only).
// Usage: node tools/check_layers.mjs   (exit 1 and a line per violation on failure; run by tools/test_all.sh)
import { readFileSync, readdirSync } from 'fs';
import { join } from 'path';

const ROOT = join(new URL('.', import.meta.url).pathname, '..', 'godot', 'src');

// docs/ARCHITECTURE.md's layering table: the layers a layer may depend on freely, plus (ALLOW_FILES) specific files it may reach into an
// otherwise-forbidden layer for — shared, read-only helpers (design tokens, fonts, the player's motion/accessibility prefs; the public multiplayer
// node, not net's own internals). Anything else in a forbidden layer (windows, modals, room/protocol internals, game mutation) is a violation.
const MAY_DEPEND = {
  engine: [],
  render: ['engine'],
  ui: ['engine', 'render'],
  net: ['engine'],
  i18n: [],
};
const ALLOW_FILES = {
  engine: [],
  render: ['ui/ui_kit.gd', 'ui/ui_tokens.gd'],
  ui: ['net/net.gd'],      // the public multiplayer node; room.gd / protocol.gd / server_main.gd are net's own internals
  net: [],
  i18n: [],
};
const LAYERS = Object.keys(MAY_DEPEND);

function files(dir) {
  const out = [];
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) out.push(...files(p));
    else if (e.name.endsWith('.gd')) out.push(p);
  }
  return out;
}

let bad = [];
for (const layer of LAYERS) {
  let list;
  try { list = files(join(ROOT, layer)); } catch { continue; }    // a layer folder that does not exist (yet) is not an error
  for (const f of list) {
    const rel = f.slice(ROOT.length + 1);
    const text = readFileSync(f, 'utf8');
    for (const other of LAYERS) {
      if (other === layer || MAY_DEPEND[layer].includes(other)) continue;
      const re = new RegExp(`res://src/${other}/([A-Za-z0-9_./-]+)`, 'g');
      let m;
      while ((m = re.exec(text))) {
        const target = `${other}/${m[1]}`;
        if (!ALLOW_FILES[layer].includes(target)) bad.push(`${rel}: depends on ${target} (layer '${layer}' may not depend on '${other}')`);
      }
    }
  }
}
// the engine stays headless: no Node (or a Node subtype) anywhere in it
try {
  for (const f of files(join(ROOT, 'engine'))) {
    const m = readFileSync(f, 'utf8').match(/^extends\s+(\w+)/m);
    if (m && m[1] !== 'RefCounted') bad.push(`engine/${f.slice(join(ROOT, 'engine').length + 1)}: extends ${m[1]}, not RefCounted (the engine must stay headless)`);
  }
} catch {}

if (bad.length) {
  console.log(`LAYERS FAIL (${bad.length})`);
  for (const b of bad) console.log('  ', b);
  process.exit(1);
}
console.log('LAYERS OK');
