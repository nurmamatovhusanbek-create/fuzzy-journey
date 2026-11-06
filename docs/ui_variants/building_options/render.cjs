const { chromium } = require('playwright'); const fs = require('fs'); const path = require('path');
// renders every bld_*.html and checks the alignment on the real layout: rows of one height, icons centred in their circles and rows, text centred, nothing wider than its box, nothing overlapping a sibling
(async () => { const b = await chromium.launch(); let bad = 0;
  for (const f of fs.readdirSync(__dirname).filter(f => f.startsWith('bld_') && f.endsWith('.html'))) {
    const p = await b.newPage({ viewport: { width: 1280, height: 800 } });
    await p.goto('file://' + path.join(__dirname, f)); await p.waitForTimeout(500);
    const res = await p.evaluate(() => {
      const out = []; const r = e => e.getBoundingClientRect(); const cy = e => (r(e).top + r(e).bottom) / 2; const cx = e => (r(e).left + r(e).right) / 2;
      const card = document.querySelector('.bd-card .pin'); const cr = r(card);
      document.querySelectorAll('.bd-ic').forEach(ic => { const s = ic.querySelector('svg'); if (s && (Math.abs(cx(s) - cx(ic)) > 0.6 || Math.abs(cy(s) - cy(ic)) > 0.6)) out.push('icon not centred in its circle: ' + (cx(s) - cx(ic)).toFixed(2) + ',' + (cy(s) - cy(ic)).toFixed(2)); });
      document.querySelectorAll('.bd-row').forEach(row => { const ic = row.querySelector('.bd-ic'), tx = row.querySelector('.tx'), pr = row.querySelector('.bd-price');
        [ic, tx, pr].forEach(c => { if (c && Math.abs(cy(c) - cy(row)) > 0.8) out.push('not centred on its row: ' + c.className + ' ' + (cy(c) - cy(row)).toFixed(2)); }); });
      const hs = new Set(); document.querySelectorAll('.bd-row').forEach(x => hs.add(Math.round(r(x).height))); if (hs.size > 1) out.push('rows of different heights ' + [...hs]);
      const ts = new Set(); document.querySelectorAll('.bd-tile').forEach(x => ts.add(Math.round(r(x).height) + 'x' + Math.round(r(x).width))); if (ts.size > 1) out.push('tiles of different sizes ' + [...ts]);
      document.querySelectorAll('.bd-tile').forEach(t => { const kids = [...t.querySelectorAll('.bd-ic,.bd-nm,.bd-pips')]; kids.forEach(k => { if (Math.abs(cx(k) - cx(t)) > 0.8) out.push('tile content not centred: ' + k.className + ' ' + (cx(k) - cx(t)).toFixed(2)); }); });
      document.querySelectorAll('.bd-chk,.bd-led').forEach(x => { x.querySelectorAll('svg,span,b').forEach(c => { if (Math.abs(cy(c) - cy(x)) > 1.2) out.push('check/ledger part not on the line: ' + c.textContent.slice(0, 20)); }); });
      document.querySelectorAll('.bd-card *').forEach(e => { if (r(e).right > cr.right + 1 || r(e).left < cr.left - 1 || r(e).bottom > cr.bottom + 1) out.push('sticks out of the card: ' + (e.className || e.tagName)); });
      document.querySelectorAll('.bd-nm,.bd-sub,.bd-tag,.bd-chk span,.bd-eff').forEach(e => { if (e.scrollWidth > e.clientWidth + 1 && !e.classList.contains('bd-eff')) out.push('text cut: ' + e.textContent.slice(0, 30)); });
      document.querySelectorAll('.bd-btn').forEach(e => { if (e.scrollWidth > e.clientWidth + 1) out.push('button text cut: ' + e.textContent); const rg = document.createRange(); rg.selectNodeContents(e); const tr = rg.getBoundingClientRect(); if (Math.abs(cx(e) - (tr.left + tr.right) / 2) > 1.0 || Math.abs(cy(e) - (tr.top + tr.bottom) / 2) > 1.5) out.push('button text not centred: ' + e.textContent + ' ' + (cx(e) - (tr.left + tr.right) / 2).toFixed(2) + ',' + (cy(e) - (tr.top + tr.bottom) / 2).toFixed(2)); });
      return out; });
    console.log(f, res.length ? res : 'aligned'); if (res.length) bad++;
    await p.screenshot({ path: path.join(__dirname, f.replace('.html', '.png')) }); await p.close(); }
  await b.close(); process.exit(bad ? 1 : 0); })();
