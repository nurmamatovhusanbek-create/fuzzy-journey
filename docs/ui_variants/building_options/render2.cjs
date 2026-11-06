const { chromium } = require('playwright'); const fs = require('fs'); const path = require('path');
// renders new_*.html (viewport 1280x900) and checks alignment on the real layout
(async () => { const b = await chromium.launch(); let bad = 0;
  for (const f of fs.readdirSync(__dirname).filter(f => f.startsWith('new_') && f.endsWith('.html'))) {
    const p = await b.newPage({ viewport: { width: 1280, height: 900 } });
    await p.goto('file://' + path.join(__dirname, f)); await p.waitForTimeout(500);
    const res = await p.evaluate(() => {
      const out = []; const r = e => e.getBoundingClientRect(); const cy = e => (r(e).top + r(e).bottom) / 2; const cx = e => (r(e).left + r(e).right) / 2;
      const card = document.querySelector('.nb-card .pin'); const cr = r(card);
      document.querySelectorAll('.nb-em').forEach(e => { const s = e.querySelector('svg'); if (s && (Math.abs(cx(s) - cx(e)) > 0.6 || Math.abs(cy(s) - cy(e)) > 0.6)) out.push('emblem icon not centred ' + (cx(s) - cx(e)).toFixed(2) + ',' + (cy(s) - cy(e)).toFixed(2)); });
      document.querySelectorAll('.nb-cd,.nb-ls,.nb-lv,.nb-bar').forEach(row => { [...row.children].forEach(c => { if (Math.abs(cy(c) - cy(row)) > 1.0) out.push('not centred on its row: ' + (c.className || c.tagName) + ' ' + (cy(c) - cy(row)).toFixed(2)); }); });
      const sz = (sel) => { const s = new Set(); document.querySelectorAll(sel).forEach(x => s.add(Math.round(r(x).width) + 'x' + Math.round(r(x).height))); return [...s]; };
      ['.nb-cd', '.nb-ls', '.nb-disc .nb-em', '.nb-lv'].forEach(q => { const s = sz(q); if (s.length > 1 && q !== '.nb-cd' && q !== '.nb-lv') out.push('different sizes ' + q + ' ' + s); });
      const cds = [...document.querySelectorAll('.nb-cd')].map(x => Math.round(r(x).height)); if (new Set(cds).size > 1) out.push('card heights differ');
      const dc = [...document.querySelectorAll('.nb-disc')].map(cx); for (let i = 2; i < dc.length; i++) if (Math.abs((dc[i] - dc[i - 1]) - (dc[1] - dc[0])) > 1.0) out.push('discs not evenly spaced');
      document.querySelectorAll('.nb-disc').forEach(d => { const k = [...d.children]; if (Math.abs(cx(k[0]) - cx(k[1])) > 0.8) out.push('disc label not centred under its disc'); });
      document.querySelectorAll('.nb-btn').forEach(e => { if (e.scrollWidth > e.clientWidth + 1) out.push('button text cut: ' + e.textContent); const rg = document.createRange(); rg.selectNodeContents(e); const tr = rg.getBoundingClientRect(); if (Math.abs(cx(e) - (tr.left + tr.right) / 2) > 1.0 || Math.abs(cy(e) - (tr.top + tr.bottom) / 2) > 1.5) out.push('button text not centred: ' + e.textContent); });
      document.querySelectorAll('.nb-ring').forEach(e => { const k = [...e.children]; if (Math.abs(cx(k[0]) - cx(k[1])) > 0.8) out.push('ring chip text not centred'); });
      document.querySelectorAll('.nb-nm,.nb-sm,.nb-st,.nb-lv .t,.nb-chk span').forEach(e => { if (e.scrollWidth > e.clientWidth + 1) out.push('text cut: ' + e.textContent.slice(0, 40)); });
      document.querySelectorAll('.nb-card *').forEach(e => { if (r(e).right > cr.right + 1 || r(e).left < cr.left - 1 || r(e).bottom > cr.bottom + 1 || r(e).top < cr.top - 1) out.push('sticks out of the card: ' + (e.className || e.tagName)); });
      document.querySelectorAll('.nb-eff').forEach(e => { if (e.scrollHeight > e.clientHeight + 1) out.push('effect text cut'); });
      document.querySelectorAll('.nb-cd,.nb-ls,.nb-lv,.nb-bar,.nb-disc,.nb-hd').forEach(row => { const tx = [...row.querySelectorAll('*')].filter(e => [...e.childNodes].some(n => n.nodeType === 3 && n.textContent.trim())).map(e => { const g = document.createRange(); g.selectNodeContents(e); return [e, g.getBoundingClientRect()]; }); for (let i = 0; i < tx.length; i++) for (let j = i + 1; j < tx.length; j++) { const a = tx[i][1], c = tx[j][1]; if (tx[i][0].contains(tx[j][0]) || tx[j][0].contains(tx[i][0])) continue; if (a.left < c.right - 0.5 && c.left < a.right - 0.5 && a.top < c.bottom - 0.5 && c.top < a.bottom - 0.5) out.push('TEXT OVERLAP: ' + tx[i][0].textContent.slice(0, 20) + ' / ' + tx[j][0].textContent.slice(0, 20)); } });
      const discs = [...document.querySelectorAll('.nb-disc .l')]; for (let i = 1; i < discs.length; i++) { const g1 = document.createRange(), g2 = document.createRange(); g1.selectNodeContents(discs[i - 1]); g2.selectNodeContents(discs[i]); if (g1.getBoundingClientRect().right + 4 > g2.getBoundingClientRect().left) out.push('disc labels touch: ' + discs[i - 1].textContent + '/' + discs[i].textContent); }
      document.querySelectorAll('.nb-cd,.nb-ls').forEach(row => { const tx = row.querySelector('.tx'); if (tx && [...tx.children].some(c => c.scrollWidth > tx.clientWidth + 1)) out.push('text wider than its box: ' + tx.textContent.slice(0, 30)); });
      return out; });
    console.log(f, res.length ? [...new Set(res)] : 'aligned'); if (res.length) bad++;
    await p.screenshot({ path: path.join(__dirname, f.replace('.html', '.png')) }); await p.close(); }
  await b.close(); process.exit(bad ? 1 : 0); })();
