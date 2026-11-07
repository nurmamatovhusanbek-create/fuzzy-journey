const { chromium } = require('playwright'); const fs = require('fs'); const path = require('path');
(async () => { const b = await chromium.launch();
  for (const f of fs.readdirSync(__dirname).filter(f => f.startsWith('country_') && f.endsWith('.html'))) {
    const p = await b.newPage({ viewport: { width: 1280, height: 800 } });
    await p.goto('file://' + path.join(__dirname, f)); await p.waitForTimeout(500);
    await p.screenshot({ path: path.join(__dirname, f.replace('.html', '.png')) }); await p.close(); }
  await b.close(); })();
