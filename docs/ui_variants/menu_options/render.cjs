const { chromium } = require('playwright'); const fs = require('fs'); const path = require('path');
(async () => { const b = await chromium.launch();
  for (const f of fs.readdirSync(__dirname).filter(f => f.startsWith('menu_') && f.endsWith('.html'))) {
    const tall = f.includes('T1'); const p = await b.newPage({ viewport: { width: 1280, height: tall ? 2200 : 720 } });
    await p.goto('file://' + path.join(__dirname, f)); await p.waitForTimeout(600);
    await p.screenshot({ path: path.join(__dirname, f.replace('.html', '.png')), fullPage: false, clip: { x: 0, y: 0, width: 1280, height: tall ? 2200 : 720 } }); await p.close(); }
  await b.close(); })();
