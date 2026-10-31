#!/usr/bin/env python3
"""Mockups: five ways to make the Settings tab calmer. Writes opt_*.html next to this file; render.js turns them into PNGs."""
import os
F = "../../../godot/assets/fonts/"
CSS = """
@font-face{font-family:Cinzel;font-weight:500;src:url(@F@cinzel-latin-500-normal.woff2)}
@font-face{font-family:Cinzel;font-weight:900;src:url(@F@cinzel-latin-900-normal.woff2)}
@font-face{font-family:Alegreya;font-weight:400;src:url(@F@alegreya-latin-400-normal.woff2)}
@font-face{font-family:Alegreya;font-weight:500;src:url(@F@alegreya-latin-500-normal.woff2)}
:root{--bg:#0A0D12;--panel:#17130F;--panel2:#211B14;--brass:#C9A24B;--hi:#E5C77A;--lo:#7F6A33;--ivory:#EFE6CF;--dim:#A89C80;--dim2:#7d735c;--good:#69B3A2;--bad:#D2603F;--info:#7FA8E8}
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1280px;height:720px;background:radial-gradient(1200px 700px at 30% 20%,#15202c,#070a0f);font-family:Alegreya,Georgia,serif;color:var(--ivory);overflow:hidden}
.cap{font-family:Cinzel,Georgia,serif;font-weight:500;letter-spacing:.14em;text-transform:uppercase;font-size:11px;color:var(--hi)}
.win{position:absolute;left:260px;top:60px;width:760px;height:600px;background:linear-gradient(#1b1610,#14100b);border:1px solid var(--lo);box-shadow:0 20px 60px #000c;display:flex;flex-direction:column}
.hd{height:58px;display:flex;align-items:center;gap:14px;padding:0 18px;border-bottom:1px solid #3a2f1b}
.hd .ic{width:36px;height:36px;border:1px solid var(--brass);border-radius:50%;display:grid;place-items:center;color:var(--hi)}
.hd h1{font-family:Cinzel;font-weight:900;letter-spacing:.14em;font-size:19px;color:var(--ivory)}
.hd .x{margin-left:auto;width:32px;height:32px;border:1px solid var(--lo);border-radius:50%;display:grid;place-items:center;color:var(--dim)}
.tabs{display:flex;padding:0 18px;border-bottom:1px solid #2c2416}
.tabs div{flex:1;text-align:center;padding:12px 0 10px;font-family:Cinzel;font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:var(--dim2);position:relative}
.tabs div.on{color:var(--ivory)}
.tabs div.on:after{content:"";position:absolute;left:30%;right:30%;bottom:-1px;height:2px;background:var(--hi)}
.body{flex:1;overflow:hidden;padding:16px 20px;position:relative}
.ft{height:54px;border-top:1px solid #3a2f1b;display:flex;align-items:center;justify-content:space-between;padding:0 18px}
.btn{font-family:Cinzel;font-size:10.5px;letter-spacing:.14em;text-transform:uppercase;padding:9px 16px;border:1px solid var(--lo);color:var(--hi);background:#1c160e;clip-path:polygon(7px 0,100% 0,100% calc(100% - 7px),calc(100% - 7px) 100%,0 100%,0 7px)}
.btn.pri{background:linear-gradient(#e0c06e,#b38f3e);color:#1b1408;border-color:#e0c06e;font-weight:900}
.row{display:flex;align-items:center;gap:14px;min-height:40px;border-bottom:1px solid #2a2216;padding:4px 2px}
.row .l{flex:1;font-size:16px;color:var(--ivory)} .row .l small{display:block;font-size:12.5px;color:var(--dim2);margin-top:-1px}
.pill{display:inline-flex;align-items:center;gap:8px;border:1px solid var(--lo);background:#1c160e;padding:5px 12px;font-family:Cinzel;font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--hi);border-radius:3px;min-width:116px;justify-content:space-between}
.pill i{font-style:normal;color:var(--dim2);font-size:9px}
.seg{display:inline-flex;border:1px solid var(--lo);border-radius:3px;overflow:hidden}
.seg b{font-family:Cinzel;font-weight:500;font-size:10.5px;letter-spacing:.1em;text-transform:uppercase;padding:6px 11px;color:var(--dim);border-left:1px solid #3a2f1b}
.seg b:first-child{border-left:0} .seg b.on{background:linear-gradient(#e0c06e,#b38f3e);color:#1b1408;font-weight:900}
.tg{width:42px;height:22px;border:1px solid var(--lo);border-radius:12px;background:#1c160e;position:relative}
.tg:after{content:"";position:absolute;top:3px;left:3px;width:14px;height:14px;border-radius:50%;background:var(--dim2)}
.tg.on{background:#5a4620;border-color:var(--hi)} .tg.on:after{left:23px;background:var(--hi)}
.sl{width:170px;height:22px;position:relative}
.sl:before{content:"";position:absolute;left:0;right:0;top:10px;height:3px;background:#3a2f1b}
.sl u{position:absolute;left:0;top:10px;height:3px;background:var(--hi)} .sl s{position:absolute;top:4px;width:15px;height:15px;border-radius:50%;background:var(--brass);border:2px solid #1b1408}
.stp{display:inline-flex;align-items:center;gap:10px;font-family:Cinzel;font-size:12px;letter-spacing:.08em;color:var(--ivory)}
.stp a{width:26px;height:26px;border:1px solid var(--lo);display:grid;place-items:center;color:var(--hi);border-radius:3px;font-size:11px}
.val{font-family:Cinzel;font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--hi)}
.chev{color:var(--dim2);margin-left:8px}
.sec{font-family:Cinzel;font-size:11px;letter-spacing:.16em;text-transform:uppercase;color:var(--hi);padding:14px 2px 6px}
.note{position:absolute;left:0;right:0;bottom:-34px;text-align:center;color:#8f836a;font-size:13px}
.tag{position:absolute;left:30px;top:16px;font-family:Cinzel;letter-spacing:.16em;font-size:12px;color:var(--hi)}
.tag b{display:block;font-size:22px;color:var(--ivory);letter-spacing:.1em;margin-top:4px}
.tag span{display:block;font-family:Alegreya;letter-spacing:0;text-transform:none;font-size:14px;color:var(--dim);margin-top:6px;max-width:215px;line-height:1.35}
""".replace("@F@",F)

def seg(opts, on): return '<span class="seg">'+''.join('<b class="%s">%s</b>'%('on' if o==on else '',o) for o in opts)+'</span>'
def pill(v): return '<span class="pill">%s<i>▾</i></span>'%v
def tg(on): return '<span class="tg %s"></span>'%('on' if on else '')
def sl(p): return '<span class="sl"><u style="width:%d%%"></u><s style="left:calc(%d%% - 7px)"></s></span>'%(p,p)
def stp(v): return '<span class="stp"><a>◀</a>%s<a>▶</a></span>'%v
def row(label, ctrl, hint=''): return '<div class="row"><div class="l">%s%s</div>%s</div>'%(label,('<small>%s</small>'%hint) if hint else '',ctrl)
def lrow(label, value, hint=''): return '<div class="row"><div class="l">%s%s</div><span class="val">%s</span><span class="chev">›</span></div>'%(label,('<small>%s</small>'%hint) if hint else '',value)

def page(title, body, tabs_on=1, extra='', foot=True):
    tabs=''.join('<div class="%s">%s</div>'%('on' if i==tabs_on else '',t) for i,t in enumerate(['Saves','Settings','How to play','Honours']))
    return ('<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>%s</style></head><body>'
        '<div class="win"><div class="hd"><div class="ic">☼</div><h1>MENU</h1><div class="x">×</div></div><div class="tabs">%s</div>'
        '<div class="body">%s</div>%s</div>%s</body></html>')%(title,CSS,tabs,body,'<div class="ft"><span class="btn">Main menu</span><span class="btn pri">Resume game</span></div>' if foot else '',extra)

out={}
# ---- A: category rail + calm rows
rail=''.join('<div style="padding:11px 14px;border-left:2px solid %s;background:%s;font-family:Cinzel;font-size:11.5px;letter-spacing:.14em;text-transform:uppercase;color:%s">%s</div>'%((('var(--hi)','#241d12','var(--ivory)') if i==0 else ('transparent','transparent','var(--dim)'))+(n,)) for i,n in enumerate(['Display','Map','Text &amp; comfort','Sound','Language','Advanced']))
rows=''.join([
 row('Quality',pill('Auto'),'Picks the best for this device'),
 row('Effects',pill('Light')),
 row('Interface size',pill('Normal')),
 row('Phone layout',pill('Desktop')),
 row('New-game screen',pill('Ring')),
 row('Hints &amp; tips',tg(True)),
])
out['opt_A_rail']=page('A',
 '<div style="display:flex;gap:18px;height:100%%"><div style="width:168px;border-right:1px solid #2c2416;padding-top:4px">%s</div><div style="flex:1"><div class="sec" style="padding-top:2px">Display</div>%s<div style="margin-top:16px;color:var(--dim2);font-size:13.5px;line-height:1.4">Six rows, one category at a time. Every choice with more than three options becomes a drop-down; yes/no choices become a switch.</div></div></div>'%(rail,rows))

# ---- B: essentials + folds
def fold(t,summary,n,open_=False,inner=''):
    return ('<div style="border:1px solid #3a2f1b;margin-top:10px;background:#17120c"><div style="display:flex;align-items:center;gap:10px;padding:11px 14px"><span class="cap" style="width:170px">%s</span><span style="flex:1;color:var(--dim);font-size:14px">%s</span><span class="val" style="color:var(--dim2)">%d</span><span class="chev">%s</span></div>%s</div>')%(t,summary,n,'⌄' if open_ else '›',('<div style="padding:2px 14px 8px;border-top:1px solid #2a2216">%s</div>'%inner) if open_ else '')
ess=''.join([row('Language',seg(['English','Русский','Oʻzbekcha'],'English')),row('Quality',pill('Auto')),row('Text size',stp('125 %')),row('Master volume',sl(70))])
out['opt_B_essentials']=page('B',
 '<div class="sec" style="padding-top:0">Essentials</div>%s%s%s%s%s'%(ess,fold('Display details','Globe · Standard map · Light effects',9),fold('Accessibility','Contrast off · Colours off · 2 switches on',9),fold('Audio mixer','Music 80 · Effects 80 · Interface 80',5),fold('Advanced','Performance overlay off',3)))
out['opt_B_essentials_open']=page('B2',
 '<div class="sec" style="padding-top:0">Essentials</div>%s%s%s'%(''.join([row('Language',seg(['English','Русский','Oʻzbekcha'],'English')),row('Text size',stp('125 %'))]),fold('Display details','Globe · Standard map · Light effects',9,True,''.join([row('Map view',seg(['Globe','Flat'],'Globe')),row('Map style',pill('Standard')),row('Effects',pill('Light')),row('Interface size',pill('Normal'))])),fold('Accessibility','Contrast off · Colours off · 2 switches on',9)+fold('Audio mixer','Music 80 · Effects 80 · Interface 80',5)))

# ---- C: presets
def card(t,sub,on=False,ic='◇'):
    return '<div style="flex:1;border:1px solid %s;background:%s;padding:14px 12px;min-height:128px;position:relative"><div style="font-size:22px;color:var(--hi)">%s</div><div class="cap" style="margin-top:8px;color:%s">%s</div><div style="font-size:13.5px;color:var(--dim);margin-top:6px;line-height:1.3">%s</div>%s</div>'%('var(--hi)' if on else '#3a2f1b','#241d12' if on else '#17120c',ic,'var(--ivory)' if on else 'var(--hi)',t,sub,'<div style="position:absolute;right:10px;top:10px;color:var(--hi);font-size:13px">✓</div>' if on else '')
chips=''.join('<span style="border:1px solid #3a2f1b;padding:4px 10px;margin:0 6px 6px 0;display:inline-block;font-size:13.5px;color:var(--dim)">%s</span>'%c for c in ['Quality auto','Globe','Light effects','Text 125 %','Normal interface','Sound on · 70'])
out['opt_C_presets']=page('C',
 '<div class="sec" style="padding-top:0">Pick how the game should feel</div><div style="display:flex;gap:10px">%s%s%s%s</div><div class="sec" style="padding-top:18px">What this sets</div><div>%s</div><div style="display:flex;gap:10px;margin-top:16px;align-items:center"><span class="btn">Customise every setting ›</span><span style="flex:1"></span>%s</div><div style="margin-top:18px">%s%s</div>'%(card('Balanced','Auto quality, light effects, normal text.',True,'◐'),card('Phone saver','Low quality, no effects, compact layout, less battery.',False,'▭'),card('Cinematic','High quality, full effects, parchment map.',False,'✦'),card('Comfort','Large text, high contrast, reduced motion, big buttons.',False,'◉'),chips,seg(['English','Русский','Oʻzbekcha'],'English'),row('Sound',tg(True),'Master volume 70'),''))

# ---- D: search + settings list
def hdr(t): return '<div class="sec" style="padding:12px 2px 4px">%s</div>'%t
search='<div style="border:1px solid var(--lo);background:#120e09;padding:9px 12px;font-size:15px;color:var(--dim2);display:flex;gap:10px">⌕ <span>Search settings: contrast, volume, text…</span></div>'
out['opt_D_list']=page('D',
 search+hdr('Display')+lrow('Quality','Auto')+lrow('Map','Globe · Standard')+lrow('Effects','Light')+lrow('Interface size','Normal')+hdr('Text &amp; comfort')+lrow('Text size','125 %')+lrow('Contrast &amp; colours','Off')+row('Reduce motion',tg(False))+hdr('Sound')+row('Sound',tg(True))+lrow('Volumes','Master 70'))
res=hdr('2 results for “contrast”')+lrow('High contrast','Off','Accessibility')+lrow('Map style','Standard','Display · “High contrast” map style')+'<div style="margin-top:14px;color:var(--dim2);font-size:13.5px">Pick a row: its choices open in a small sheet, so the page never shows all of them at once.</div>'
sheet='<div style="position:absolute;left:300px;top:128px;width:330px;border:1px solid var(--hi);background:#1d1710;box-shadow:0 14px 40px #000b;padding:14px"><div class="cap" style="margin-bottom:10px">High contrast</div>'+''.join('<div style="padding:10px 12px;border:1px solid %s;margin-bottom:6px;font-size:15px;background:%s;color:%s">%s</div>'%((('var(--hi)','#2a2113','var(--ivory)') if i==0 else ('#3a2f1b','transparent','var(--dim)'))+(t,)) for i,t in enumerate(['Off','Light','Dark']))+'</div>'
sbox='<div style="border:1px solid var(--hi);background:#120e09;padding:9px 12px;font-size:15px;color:var(--ivory);display:flex;gap:10px">⌕ <span>contrast</span><span style="margin-left:auto;color:var(--dim2)">×</span></div>'
out['opt_D_search']=page('D2',sbox+res+sheet)

# ---- E: tiles + focused page with preview
def tile(ic,t,sub,n): return '<div style="flex:1;border:1px solid #3a2f1b;background:#17120c;padding:16px;min-height:150px"><div style="font-size:26px;color:var(--hi)">%s</div><div class="cap" style="margin-top:10px;color:var(--ivory)">%s</div><div style="font-size:14px;color:var(--dim);margin-top:6px;line-height:1.35">%s</div><div class="val" style="margin-top:10px;color:var(--dim2)">%s settings ›</div></div>'%(ic,t,sub,n)
out['opt_E_tiles']=page('E',
 '<div style="display:flex;gap:12px">%s%s</div><div style="display:flex;gap:12px;margin-top:12px">%s%s</div><div style="display:flex;gap:10px;margin-top:16px;align-items:center"><span class="cap">Language</span>%s<span style="flex:1"></span><span class="btn">Reset comfort</span></div>'%(tile('◍','Look &amp; map','Globe · Standard map · Light effects · Normal interface',8),tile('Aa','Text &amp; comfort','Text 125 % · Contrast off · 2 switches on',9),tile('♪','Sound','Master 70 · Music 80 · Effects 80',6),tile('⚙','Advanced','Performance overlay off · Diagnostics',3),seg(['English','Русский','Oʻzbekcha'],'English')))
prev='<div style="width:230px;border:1px solid #3a2f1b;background:#120e09;padding:12px"><div class="cap" style="margin-bottom:8px">Preview</div><div style="height:96px;background:radial-gradient(circle at 40% 45%,#2d4a3a,#1a2a3a 60%,#0d1520);border:1px solid #2a2216;position:relative"><div style="position:absolute;left:10px;top:8px;font-family:Cinzel;font-size:12px;letter-spacing:.1em;color:var(--hi)">FRANCE</div><div style="position:absolute;right:8px;bottom:8px;border:1px solid var(--lo);padding:2px 8px;font-size:12px;background:#17120c">119</div></div><div style="margin-top:10px;font-size:17px;line-height:1.3">The quick brown army marches at dawn.</div><div style="font-size:12.5px;color:var(--dim2);margin-top:6px">Text 125 % · Normal interface</div></div>'
rows2=''.join([row('Quality',pill('Auto')),row('Map view',seg(['Globe','Flat'],'Globe')),row('Map style',pill('Standard')),row('Effects',pill('Light')),row('Interface size',pill('Normal')),row('Phone layout',pill('Desktop'))])
out['opt_E_page']=page('E2','<div style="display:flex;gap:6px;align-items:center;margin-bottom:6px;color:var(--dim)"><span class="chev" style="margin:0">‹</span><span class="cap">Look &amp; map</span></div><div style="display:flex;gap:18px"><div style="flex:1">%s</div>%s</div>'%(rows2,prev))


# ---- F: my suggestion: search + preset chips + essentials (drop-downs) + folds
def chip(t,on=False): return '<span style="border:1px solid %s;background:%s;padding:5px 12px;margin-right:8px;font-family:Cinzel;font-size:10.5px;letter-spacing:.1em;text-transform:uppercase;color:%s">%s</span>'%('var(--hi)' if on else '#3a2f1b','#2a2113' if on else 'transparent','var(--ivory)' if on else 'var(--dim)',t)
search_s='<div style="border:1px solid #3a2f1b;background:#120e09;padding:7px 12px;font-size:14.5px;color:var(--dim2);display:flex;gap:10px;margin-bottom:10px">⌕ <span>Search settings…</span></div>'
presets=('<div style="display:flex;align-items:center;margin-bottom:6px"><span class="cap" style="margin-right:12px;color:var(--dim)">Feel</span>%s%s%s%s</div>')%(chip('Balanced',True),chip('Phone saver'),chip('Cinematic'),chip('Comfort'))
ess2=''.join([row('Language',seg(['English','Русский','Oʻzbekcha'],'English')),row('Quality',pill('Auto')),row('Text size',pill('125 %')),row('Master volume',sl(70))])
def fold2(t,summary,n,open_=False,inner=''):
    return ('<div style="border:1px solid #3a2f1b;margin-top:8px;background:#17120c"><div style="display:flex;align-items:center;gap:10px;padding:9px 14px"><span class="cap" style="width:150px">%s</span><span style="flex:1;color:var(--dim);font-size:14px">%s</span><span class="val" style="color:var(--dim2)">%d</span><span class="chev">%s</span></div>%s</div>')%(t,summary,n,'⌄' if open_ else '›',('<div style="padding:0 14px 6px;border-top:1px solid #2a2216">%s</div>'%inner) if open_ else '')
out['opt_F_hybrid']=page('F',search_s+presets+'<div class="sec" style="padding:6px 2px 0">Essentials</div>'+ess2+fold2('Display details','Globe · Standard map · Light effects',9)+fold2('Accessibility','Contrast off · Colours off · 2 switches on',9)+fold2('Audio mixer','Music 80 · Effects 80 · Interface 80',5)+fold2('Advanced','Performance readout off',3))
acc=''.join([row('High contrast',pill('Off')),row('Colour vision',pill('Off')),row('Reduce motion',tg(False)),row('Large touch targets',tg(True)),row('Readable fonts',tg(False)),row('Confirm destructive actions',pill('Risky only'))])
out['opt_F_hybrid_open']=page('F2',search_s+'<div class="sec" style="padding:2px 2px 0">Essentials</div>'+row('Language',seg(['English','Русский','Oʻzbekcha'],'English'))+row('Text size',pill('125 %'))+fold2('Display details','Globe · Standard map · Light effects',9)+fold2('Accessibility','Contrast off · Colours off · 2 switches on',9,True,acc))
for k,v in out.items(): open(k+'.html','w').write(v)
print(len(out),'files')
