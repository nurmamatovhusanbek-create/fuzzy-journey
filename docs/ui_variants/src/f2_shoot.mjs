import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
const b = await chromium.launch(); const p = await b.newPage({viewport:{width:1920,height:1080}});
await p.goto('file:///home/user/fuzzy-journey/docs/ui_variants/src/f2_tips.html'); await p.waitForTimeout(600);
const els = await p.$$('.fig');
await els[0].screenshot({path:'/home/user/fuzzy-journey/docs/screens/f2/mock_tips_title.png'});
await els[1].screenshot({path:'/home/user/fuzzy-journey/docs/screens/f2/mock_tips_game.png'});
await b.close();
