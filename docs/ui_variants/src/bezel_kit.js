// ===== Bezel kit: icon set (24x24 grid, 1.7 stroke, round caps) + SVG primitives =====
const IC = {
  nations: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3v18M6.5 6q5.500 6 11 0M6.500 18q5.500-6 11 0"/>',
  treasury: '<ellipse cx="12" cy="7" rx="7" ry="3"/><path d="M5 7v5q0 3 7 3t7-3V7M5 12v5q0 3 7 3t7-3v-5"/>',
  decrees: '<path d="M12 3v18M6 21h12M4 7h16M4 7l-2.500 7h5zM20 7l-2.500 7h5z"/>',
  council: '<path d="M3 9l9-5 9 5zM5 20h14M6 9v8M10 9v8M14 9v8M18 9v8"/>',
  annals: '<path d="M3 5q4.500-1.500 9 1.500q4.500-3 9-1.500v13q-4.500-1.500-9 1.500q-4.500-3-9-1.500zM12 6.500v13"/>',
  goals: '<path d="M7 4h10v6q0 5-5 5t-5-5zM7 6.500H4q0 4 3 4.500M17 6.500h3q0 4-3 4.500M12 15v4M8 20h8"/>',
  army: '<path d="M5 19L18 6M18 6h-4M18 6v4M19 19L6 6M6 6h4M6 6v4M3.500 17.500l3 3M20.500 17.500l-3 3"/>',
  people: '<circle cx="9" cy="8" r="3.200"/><path d="M3 20q0-6 6-6t6 6M16 5.500a3 3 0 010 5.500M18 14q3 1 3 6"/>',
  envoys: '<rect x="3" y="6" width="18" height="13" rx="1.500"/><path d="M3.500 7l8.500 7 8.500-7"/>',
  gold: '<circle cx="12" cy="12" r="9"/><path d="M12 7v10M9.500 9.500q0-2 2.500-2t2.500 1.800q0 1.700-2.500 2.200t-2.500 2.200q0 1.800 2.500 1.800t2.500-2"/>',
  move: '<path d="M3 12h16M13 6l6 6-6 6"/>',
  recruit: '<circle cx="12" cy="12" r="9"/><path d="M12 7.500v9M7.500 12h9"/>',
  build: '<path d="M4 20V10l8-6 8 6v10zM10 20v-6h4v6"/>',
  fortify: '<path d="M4 20V7h3v3h2.500V7h5v3H17V7h3v13zM10 20v-4h4v4"/>',
  attack: '<path d="M4 20L16 8M16 8h-4M16 8v4M20 20L8 8M8 8h4M8 8v4"/>',
  pact: '<circle cx="9" cy="12" r="5.500"/><circle cx="15" cy="12" r="5.500"/>',
  trade: '<path d="M4 8h14M14 4l4 4-4 4M20 16H6M10 12l-4 4 4 4"/>',
  spy: '<path d="M2 12q4.500-7 10-7t10 7q-4.500 7-10 7T2 12z"/><circle cx="12" cy="12" r="3"/>',
  war: '<path d="M4 20L16 8M16 8h-4M16 8v4M20 20L8 8M8 8h4M8 8v4"/>',
  settings: '<circle cx="12" cy="12" r="3.500"/><path d="M12 2.500v3M12 18.500v3M2.500 12h3M18.500 12h3M5.300 5.300l2.100 2.100M16.600 16.600l2.100 2.100M5.300 18.700l2.100-2.100M16.600 7.400l2.100-2.100"/>',
  save: '<path d="M12 4v11M7 11l5 5 5-5M4 20h16"/>',
  load: '<path d="M12 16V5M7 9l5-5 5 5M4 20h16"/>',
  close: '<path d="M6 6l12 12M18 6L6 18"/>',
  warn: '<path d="M12 3L22 20H2zM12 10v5M12 17.500v.5"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.500v.5"/>',
  check: '<path d="M4 12.500l5 5L20 6.500"/>',
  star: '<path d="M12 3l2.600 5.600 6.100.7-4.500 4.200 1.200 6L12 16.500 6.600 19.500l1.200-6L3.300 9.300l6.100-.7z"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.500 2"/>',
  research: '<path d="M12 3v4M12 7L6 21M12 7l6 14M8.500 16h7"/><circle cx="12" cy="4" r="1.200"/>',
  invest: '<path d="M4 19l5-6 4 3 7-9M15 7h5v5"/>',
  tax: '<circle cx="8" cy="8" r="2.500"/><circle cx="16" cy="16" r="2.500"/><path d="M18 5L6 19"/>',
  happy: '<circle cx="12" cy="12" r="9"/><path d="M8 14q4 4 8 0M9 9.500v.5M15 9.500v.5"/>',
  terrain: '<path d="M2 19l7-12 4 7 3-4 6 9z"/>',
  menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
  flag: '<path d="M5 21V4M5 5h13l-3 4 3 4H5"/>',
  lock: '<rect x="5" y="11" width="14" height="9" rx="1.500"/><path d="M8 11V8a4 4 0 018 0v3"/>',
  crown: '<path d="M3 18l1.500-10 5 4L12 5l2.500 7 5-4L21 18zM4 21h16"/>',
  skull: '<path d="M12 3q8 0 8 8 0 3-2 4.500V20H6v-4.500Q4 14 4 11q0-8 8-8zM9 12v1M15 12v1M10 17v3M14 17v3"/>',
  heart: '<path d="M12 20S3 14 3 8.500A4.500 4.500 0 0112 7a4.500 4.500 0 019 1.500C21 14 12 20 12 20z"/>',
  ship: '<path d="M3 15h18l-2.500 5h-13zM12 3v12M12 4l6 8h-6M12 6L7 12h5"/>',
};
const ico = (n, s = 22, w = 1.7, extra = '') => `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round" ${extra}>${IC[n] || ''}</svg>`;
// ===== SVG primitives (string builders) =====
const rad = d => d * Math.PI / 180;
const P = (cx, cy, r, a) => [cx + r * Math.sin(rad(a)), cy - r * Math.cos(rad(a))];
function arcD(cx, cy, r, a0, a1) { const [x0, y0] = P(cx, cy, r, a0), [x1, y1] = P(cx, cy, r, a1); return `M${x0.toFixed(2)} ${y0.toFixed(2)}A${r} ${r} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${x1.toFixed(2)} ${y1.toFixed(2)}`; }
function tickMarks(cx, cy, r, n, len, major, col = '#C9A24B', w = 1, a0 = 0, span = 360) {
  let d = ''; const cnt = span === 360 ? n - 1 : n;
  for (let i = 0; i <= cnt; i++) { const a = a0 + span * i / n, l = i % major === 0 ? len * 1.7 : len; const [x0, y0] = P(cx, cy, r, a), [x1, y1] = P(cx, cy, r - l, a); d += `M${x0.toFixed(1)} ${y0.toFixed(1)}L${x1.toFixed(1)} ${y1.toFixed(1)}`; }
  return `<path d="${d}" stroke="${col}" stroke-width="${w}" fill="none"/>`;
}
const DEFS = `<svg width="0" height="0" style="position:absolute"><defs>
<linearGradient id="gBrass" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#EBCF85"/><stop offset=".5" stop-color="#B38F3E"/><stop offset="1" stop-color="#6F5A27"/></linearGradient>
<linearGradient id="gBrassH" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E5C77A"/><stop offset="1" stop-color="#9c7a30"/></linearGradient>
<radialGradient id="gFace" cx="40%" cy="35%" r="80%"><stop offset="0" stop-color="#2a2218"/><stop offset="1" stop-color="#0f0c09"/></radialGradient>
<filter id="fGlow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs></svg>`;
// round bezel (outer ring + face). returns svg string for a <g>
function bezelSvg(cx, cy, r, nt = 60, face = '#0f0c09') {
  return `<circle cx="${cx}" cy="${cy}" r="${r + 3}" fill="#050403" opacity=".5"/><circle cx="${cx}" cy="${cy}" r="${r}" fill="url(#gBrass)"/><circle cx="${cx}" cy="${cy}" r="${r - 5}" fill="${face}"/><circle cx="${cx}" cy="${cy}" r="${r - 6}" fill="none" stroke="#E5C77A" stroke-width=".6"/>${tickMarks(cx, cy, r - 6, nt, 5, 5, '#C9A24B', .8)}<path d="${arcD(cx, cy, r - 1.5, -70, 25)}" stroke="rgba(255,244,210,.55)" stroke-width="1.4" fill="none" stroke-linecap="round"/><path d="${arcD(cx, cy, r - 1.5, 110, 205)}" stroke="rgba(0,0,0,.35)" stroke-width="1.6" fill="none" stroke-linecap="round"/>`;
}
// arc gauge 270deg. returns <svg> string of size 2*(r+10)
function gaugeSvg({ r = 52, v = '100', d = '', f = .5, col = '#C9A24B', label = '', id = '' }) {
  const s = 2 * (r + 12), c = s / 2;
  return `<svg width="${s}" height="${s}" viewBox="0 0 ${s} ${s}" ${id ? `id="${id}"` : ''}>${bezelSvg(c, c, r + 8, 0)}<path d="${arcD(c, c, r - 4, -135, 135)}" stroke="#2a2318" stroke-width="7" fill="none"/><path class="gv" d="${arcD(c, c, r - 4, -135, -135 + 270 * Math.max(.001, f))}" stroke="${col}" stroke-width="7" fill="none" stroke-linecap="round"/>${tickMarks(c, c, r + 1, 20, 4, 5, '#7F6A33', .8, -135, 270)}<text x="${c}" y="${c + r * .12}" text-anchor="middle" font-family="Alegreya" font-weight="700" font-size="${((String(v).length > 3 ? .78 : 1) * Math.max(11, r * .6)).toFixed(1)}" fill="#EFE6CF">${v}</text>${d ? `<text x="${c}" y="${c + r * .52}" text-anchor="middle" font-family="Alegreya" font-size="${Math.max(9, r * .27).toFixed(1)}" fill="${col}">${d}</text>` : ''}</svg>`;
}
// medallion with flag (circle crop)
const FLAGS = { FR: ['#2F4E9E', '#F3EEE3', '#C8372D'], AT: ['#E8E8E8', '#C8372D', '#E8E8E8'], PR: ['#222', '#EEE', '#222'], UK: ['#2A3F8F', '#C8372D', '#2A3F8F'], ES: ['#C8372D', '#E3B93C', '#C8372D'], RU: ['#EEE', '#2A4FA0', '#C8372D'], OT: ['#B22A2A', '#B22A2A', '#B22A2A'], SA: ['#2A4FA0', '#EEE', '#2A4FA0'], NA: ['#1f7a4a', '#EEE', '#C8372D'] };
function flagMedal(code, size = 44, ring = '#C9A24B') {
  const f = FLAGS[code] || FLAGS.FR, r = size / 2;
  return `<svg class="medal" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}"><defs><clipPath id="mc${code}${size}"><circle cx="${r}" cy="${r}" r="${r - 4}"/></clipPath></defs><circle cx="${r}" cy="${r}" r="${r - .5}" fill="url(#gBrass)"/><g clip-path="url(#mc${code}${size})"><rect x="0" width="${size / 3 + 1}" height="${size}" fill="${f[0]}"/><rect x="${size / 3}" width="${size / 3 + 1}" height="${size}" fill="${f[1]}"/><rect x="${2 * size / 3}" width="${size / 3 + 1}" height="${size}" fill="${f[2]}"/></g><circle cx="${r}" cy="${r}" r="${r - 4}" fill="none" stroke="rgba(0,0,0,.55)" stroke-width="1.5"/></svg>`;
}
// chamfered plate: wraps html in two nested clip-path boxes to get a 1px brass hairline on a notched shape
const cham = c => `polygon(${c}px 0,calc(100% - ${c}px) 0,100% ${c}px,100% calc(100% - ${c}px),calc(100% - ${c}px) 100%,${c}px 100%,0 calc(100% - ${c}px),0 ${c}px)`;
function plate(html, cls = '', style = '', c = 10) { return `<div class="pw ${cls}" style="${style}"><div class="plate" style="--c:${c}px"><div class="pin">${html}</div></div></div>`; }
// graduated rule (ticks) as css background
const RULE = 'repeating-linear-gradient(90deg,#7F6A33 0 1px,transparent 1px 8px),repeating-linear-gradient(90deg,#C9A24B 0 1px,transparent 1px 40px)';
