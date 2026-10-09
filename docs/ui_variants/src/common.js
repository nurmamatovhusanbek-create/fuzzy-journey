// shared demo scene: same game state for every variation so they can be compared fairly
const GAME = {
  nation: 'France', ruler: 'Emperor Napoleon', year: '1804 AD', turn: 1,
  gold: 100, goldD: '+731', people: 90, peopleD: '5%', army: '10/12', armyD: '+2.2', dip: 6, dipD: '+2',
  lens: ['Political', 'Diplomatic', 'Military', 'Terrain'],
  prov: { name: 'Bas-Rhin', owner: 'France', army: 35, def: 0, pop: 172, dev: 1, stab: 87, hap: 57, eco: 2, terrain: 'Plains', build: 'None', supply: 29 },
  verbs: [['Move army', 'M'], ['Recruit', 'R'], ['Build', 'B'], ['Fortify', 'F']],
  alerts: [['war', 'Austria masses troops on your border'], ['offer', 'Spain proposes a pact']],
};
const NAMES = { united_kingdom: 'United Kingdom', kingdom_of_ireland: 'Ireland', russian_empire: 'Russian Empire', ottoman_empire: 'Ottoman Empire', austrian_empire: 'Austrian Empire', kingdom_of_the_two_sicilies: 'Two Sicilies', kingdom_of_sardinia: 'Sardinia', helvetic_republic: 'Helvetic Rep.', batavian_republic: 'Batavian Rep.', austrian_netherlands: 'Austrian Netherlands', central_asian_khanates_2: 'Khanates' };
const LABELS = ['russian_empire', 'ottoman_empire', 'sweden', 'austrian_empire', 'spain', 'france', 'morocco', 'algiers', 'prussia', 'united_kingdom', 'portugal', 'kingdom_of_the_two_sicilies', 'tunis', 'tripolitania', 'bavaria', 'saxony', 'kingdom_of_sardinia', 'papal_states', 'persia', 'kingdom_of_ireland', 'swabia', 'helvetic_republic', 'batavian_republic', 'venetia'];
const nm = c => NAMES[c.id] || c.name;
const svgNS = 'http://www.w3.org/2000/svg';
function el(tag, attrs, parent, txt) {
  const e = document.createElementNS(svgNS, tag);
  for (const k in attrs) e.setAttribute(k, attrs[k]);
  if (txt !== undefined) e.textContent = txt;
  if (parent) parent.appendChild(e);
  return e;
}
// opts: fill(c)->css, stroke, strokeW, sea, coast:[[w,opacity,color]...], graticule:{step,color,w}, onPick(c), frDepts:true
function drawMap(svg, o) {
  svg.setAttribute('viewBox', `0 0 ${MAP.W} ${MAP.H}`);
  svg.setAttribute('preserveAspectRatio', 'xMidYMid slice');
  el('rect', { width: MAP.W, height: MAP.H, fill: o.sea }, svg);
  if (o.seaExtra) o.seaExtra(svg);
  const gr = el('g', { fill: 'none', stroke: o.graticule.color, 'stroke-width': o.graticule.w }, svg);
  for (let lon = -30; lon <= 60; lon += o.graticule.step) el('line', { x1: MAP.x(lon), y1: -50, x2: MAP.x(lon), y2: MAP.H + 50 }, gr);
  for (let lat = 20; lat <= 70; lat += o.graticule.step) el('line', { x1: -50, y1: MAP.y(lat), x2: MAP.W + 50, y2: MAP.y(lat) }, gr);
  const land = el('g', {}, svg);
  if (o.coast) for (const [w, op, col] of o.coast) {
    const g = el('g', { fill: 'none', stroke: col, 'stroke-width': w, 'stroke-opacity': op, 'stroke-linejoin': 'round' }, land);
    for (const c of MAP.countries) el('path', { d: c.d }, g);
  }
  const cg = el('g', { 'stroke-linejoin': 'round' }, land);
  const paths = {};
  for (const c of MAP.countries) {
    const p = el('path', { d: c.d, fill: o.fill(c), stroke: o.stroke(c), 'stroke-width': o.strokeW || 1 }, cg);
    p.dataset.id = c.id; paths[c.id] = p;
    if (o.onPick) { p.style.cursor = 'pointer'; p.addEventListener('click', () => o.onPick(c, p)); }
    if (o.onHover) { p.addEventListener('mouseenter', e => o.onHover(c, p, e)); p.addEventListener('mouseleave', () => o.onHover(null)); }
  }
  if (o.frDepts) {
    const fg = el('g', { fill: 'none', stroke: o.frDepts.stroke, 'stroke-width': o.frDepts.w, 'stroke-linejoin': 'round' }, svg);
    const dep = {};
    for (const d of MAP.france) { dep[d.name] = el('path', { d: d.d, fill: 'transparent' }, fg); dep[d.name].style.pointerEvents = 'all'; }
    paths.dept = dep;
  }
  return paths;
}
const FLAG_FR = (w = 36, h = 24) => `<svg width="${w}" height="${h}" viewBox="0 0 3 2"><rect width="1" height="2" fill="#2F4E9E"/><rect x="1" width="1" height="2" fill="#F3EEE3"/><rect x="2" width="1" height="2" fill="#C8372D"/></svg>`;
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
// scale the 1920x1080 stage to the window
function fit() { const s = Math.min(innerWidth / 1920, innerHeight / 1080); const st = $('#stage'); st.style.transform = `scale(${s})`; st.style.left = (innerWidth - 1920 * s) / 2 + 'px'; st.style.top = (innerHeight - 1080 * s) / 2 + 'px'; }
addEventListener('resize', () => { if ($('#stage')) fit(); });
