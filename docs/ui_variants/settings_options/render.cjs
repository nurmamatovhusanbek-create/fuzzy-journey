const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
  for (const f of fs.readdirSync(__dirname).filter(f => f.startsWith('opt_') && f.endsWith('.html'))) {
    await p.goto('file://' + path.join(__dirname, f)); await p.waitForTimeout(300);
    await p.screenshot({ path: path.join(__dirname, f.replace('.html', '.png')) });
  }
  await b.close();
})();
