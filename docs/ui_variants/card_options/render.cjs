const { chromium } = require('playwright'); const fs = require('fs'); const path = require('path');
// renders every rel_*.html and checks the alignment on the real layout: equal row heights, flags centred on their rows, nothing wider than its box, nothing overlapping a sibling
(async () => { const b = await chromium.launch(); let bad = 0;
  for (const f of fs.readdirSync(__dirname).filter(f => f.startsWith('rel_') && f.endsWith('.html'))) {
    const p = await b.newPage({ viewport: { width: 1280, height: 800 } });
    await p.goto('file://' + path.join(__dirname, f)); await p.waitForTimeout(500);
    const res = await p.evaluate(() => {
      const out = []; const r = e => e.getBoundingClientRect(); const cy = e => (r(e).top + r(e).bottom) / 2;
      const card = document.querySelector('.rl-card .pin') || document.querySelector('.rl-card'); const cr = r(card);
      document.querySelectorAll('.rl-row,.rl-tr,.rl-line').forEach(row => {
        const rr = r(row);
        row.querySelectorAll('.rl-fl,.rl-nm,.rl-ct,.rl-ty,.rl-r,.rl-p,.rl-lab').forEach(c => {
          if (Math.abs(cy(c) - cy(row)) > 0.75) out.push('not centred on its row: ' + (c.className || c.tagName) + ' ' + (cy(c) - cy(row)).toFixed(2));
          if (r(c).right > rr.right + 0.5 || r(c).left < rr.left - 0.5) out.push('outside its row: ' + c.className);
          if (c.scrollHeight > c.clientHeight + 1 && c.classList.contains('rl-nm')) out.push('name cut: ' + c.textContent);
        });
        const kids = [...row.children].map(r); for (let i = 1; i < kids.length; i++) if (kids[i].left < kids[i - 1].right - 0.5 && kids[i].width > 0 && kids[i-1].width > 0) out.push('overlap in a row near ' + row.textContent.slice(0, 30));
      });
      const hs = {}; document.querySelectorAll('.rl-row').forEach(x => hs[Math.round(r(x).height)] = 1); if (Object.keys(hs).length > 1) out.push('rows of different heights ' + Object.keys(hs));
      document.querySelectorAll('.rl-card *').forEach(e => { if (r(e).right > cr.right + 1 || r(e).left < cr.left - 1) out.push('sticks out of the card: ' + (e.className || e.tagName)); });
      // right edges of the contact column share one line
      const ct = [...document.querySelectorAll('.rl-g2 .rl-ct')].map(e => Math.round(r(e).right)); const cols = [...new Set(ct)]; if (cols.length > 2) out.push('contact tags do not share two right edges ' + cols);
      return out; });
    console.log(f, res.length ? res : 'aligned');
    if (res.length) bad++;
    await p.screenshot({ path: path.join(__dirname, f.replace('.html', '.png')) }); await p.close(); }
  await b.close(); process.exit(bad ? 1 : 0); })();
