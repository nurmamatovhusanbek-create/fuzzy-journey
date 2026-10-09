import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import path from 'path';
const here = path.dirname(new URL(import.meta.url).pathname);
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--no-sandbox'] });
for (const [w,h] of [[1920,1080],[844,390]]) {
  const p = await b.newPage({ viewport: { width: w, height: h } }); const errs=[];
  p.on('pageerror', e => errs.push(e.message)); p.on('console', m => { if (m.type()==='error') errs.push(m.text()) });
  await p.goto('file://' + path.join(here, 'bezel_demo.html')); await p.waitForTimeout(500);
  const act = async (f) => { await p.evaluate(f); await p.waitForTimeout(150) };
  await act(() => document.querySelector('[data-verb=move]').dispatchEvent(new MouseEvent('click',{bubbles:true})));
  await act(() => paths.kingdom_of_sardinia.dispatchEvent(new MouseEvent('click',{bubbles:true})));
  await act(() => document.querySelector('[data-act=confirm-move]').click());
  await p.waitForTimeout(300);
  console.log(w,'after attack screen=',await p.evaluate(()=>S.screen), 'own',await p.evaluate(()=>[...S.own].join()));
  await act(()=>document.querySelector('[data-act=close]').click());
  await act(()=>document.querySelector('[data-act=nations]').click()); await act(()=>document.querySelector('[data-nat=prussia]').click());
  await act(()=>document.querySelector('[data-act=dip-pact]').click()); await act(()=>document.querySelector('[data-act=close]').click());
  await act(()=>document.querySelector('[data-act=budget]').click()); await act(()=>document.querySelector('[data-bud="tax:5"]').click());
  console.log(w,'net',await p.evaluate(()=>net()));
  await act(()=>document.querySelector('[data-act=close]').click());
  await p.mouse.move(w/2,h/2); await p.mouse.wheel(0,-300); await p.mouse.down(); await p.mouse.move(w/2+80,h/2+40); await p.mouse.up();
  await act(()=>document.querySelector('#chg').dispatchEvent(new MouseEvent('click',{bubbles:true}))); await p.waitForTimeout(1300);
  console.log(w,'turn',await p.evaluate(()=>S.turn),'errors',errs.slice(0,5));
  await p.screenshot({path:`/tmp/claude-0/bz/after_${w}.png`}); await p.close();
}
await b.close();
