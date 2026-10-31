#!/usr/bin/env python3
"""Budget window: four layouts on one strict grid (8 px unit, one control height 28 / row 56, one control column). Writes bud_*.html; render.cjs renders each clean and with the grid overlaid."""
exec(open('_base.py').read())
EXTRA = """
:root{--u:8px}
.win{width:760px;left:260px;height:640px;top:40px}
.grid-on:after{content:"";position:fixed;inset:0;pointer-events:none;z-index:99;background-image:linear-gradient(to right,rgba(127,214,255,.22) 1px,transparent 1px),linear-gradient(to bottom,rgba(127,214,255,.22) 1px,transparent 1px);background-size:8px 8px;mix-blend-mode:screen}
.grid-on .win:before{content:"";position:absolute;left:20px;right:20px;top:0;bottom:0;border-left:1px solid rgba(255,90,90,.9);border-right:1px solid rgba(255,90,90,.9);z-index:98;pointer-events:none}
.stat{border:1px solid #3a2f1b;background:#17120c;padding:8px 12px;display:flex;flex-direction:column;justify-content:center;height:56px}
.stat .k{font-family:Cinzel;font-size:10px;letter-spacing:.14em;text-transform:uppercase;color:var(--dim2)} .stat .v{font-size:20px;font-family:Cinzel;color:var(--ivory)} .pos{color:var(--good)!important} .neg{color:var(--bad)!important}
.ico{width:32px;height:32px;border:1px solid var(--brass);border-radius:50%;display:grid;place-items:center;color:var(--hi);font-size:14px;flex:none}
.eff{font-style:italic;font-size:13.5px;color:var(--dim);line-height:1.25}
.name{font-family:Cinzel;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--ivory)}
.pct{font-family:Cinzel;font-size:20px;color:var(--ivory);text-align:right}
.trk{position:relative;height:28px}
.trk:before{content:"";position:absolute;left:0;right:0;top:12px;height:4px;background:#2d2415}
.trk u{position:absolute;left:0;top:12px;height:4px;background:linear-gradient(#e0c06e,#b38f3e)}
.trk s{position:absolute;top:5px;width:18px;height:18px;border-radius:50%;background:#1b1408;border:2px solid var(--brass)}
.trk i{position:absolute;top:12px;height:4px;background:repeating-linear-gradient(45deg,#7a3a24 0 3px,#3a1e14 3px 6px)}
.tick{display:flex;justify-content:space-between;font-size:10px;color:var(--dim2);margin-top:-4px;font-family:Cinzel;letter-spacing:.08em}
.sq{display:inline-grid;place-items:center;width:28px;height:28px;border:1px solid var(--lo);background:#1c160e;color:var(--hi);font-size:14px;border-radius:3px}
.hl{height:1px;background:#2a2216}
.vr{width:1px;background:#2a2216;align-self:stretch}
"""
def gauge(v='+566'):
    return '<div style="width:96px;height:96px;border-radius:50%%;border:2px solid #3a2f1b;position:relative;display:grid;place-items:center;background:conic-gradient(var(--good) 0 62%%,#241d12 62%% 100%%)"><div style="position:absolute;inset:6px;border-radius:50%%;background:#17120c;display:grid;place-items:center;text-align:center"><div><div style="font-family:Cinzel;font-size:20px;color:var(--ivory)">%s</div><div class="cap" style="font-size:9px;color:var(--good)">per turn</div></div></div></div>'%v
POL=[('%','Tax',50,'Taxes bring 98 gold a turn; above 50 % they upset the people',True),('☺','Public goods',20,'Contentment settles near 50 (neutral at 20 %)',False),('Å','Research',15,'About 6.5 research points a turn · next level in about 28 turns',False),('↗','Investment',15,'0.8 % chance a turn per province to improve',False)]
def trk(p,danger=False):
    d='<i style="left:50%%;right:0"></i>' if danger else ''
    return '<div><div class="trk">%s<u style="width:%d%%"></u><s style="left:calc(%d%% - 9px)"></s></div><div class="tick"><span>0</span><span>25</span><span>50</span><span>75</span><span>100</span></div></div>'%(d,p,p)
STATS=[('Taxes','+98','pos'),('Provinces','+833','pos'),('Army upkeep','−625','neg'),('Administration','−24','neg'),('Inflation','0',''),('Treasury','100','')]
def statgrid(cols=3,cells=STATS,h=56):
    return '<div style="display:grid;grid-template-columns:repeat(%d,1fr);gap:8px">%s</div>'%(cols,''.join('<div class="stat"><span class="k">%s</span><span class="v %s">%s</span></div>'%(k,c,v) for k,v,c in cells))
def pres(): return seg(['Balanced','War','Growth'],'')
FOOT_REV=''
out={}

# ---- V1: ledger table, one row grid
rows=''
for ic,nm,p,ef,dg in POL:
    rows+='<div style="display:grid;grid-template-columns:32px 1fr 232px 56px 64px;gap:16px;align-items:center;height:64px;border-bottom:1px solid #2a2216"><div class="ico">%s</div><div><div class="name">%s</div><div class="eff">%s</div></div>%s<div class="pct">%d%%</div><div style="display:flex;gap:8px"><span class="sq">−</span><span class="sq">+</span></div></div>'%(ic,nm,ef,trk(p,dg),p)
hdr='<div style="display:grid;grid-template-columns:32px 1fr 232px 56px 64px;gap:16px;height:24px;align-items:center;border-bottom:1px solid #3a2f1b"><span></span><span class="cap" style="color:var(--dim2)">Policy</span><span class="cap" style="color:var(--dim2)">Share of income</span><span class="cap" style="color:var(--dim2);text-align:right">Now</span><span></span></div>'
out['bud_V1_ledger']=page('V1','<div style="display:flex;gap:16px;align-items:center">%s<div style="flex:1">%s</div></div><div style="height:16px"></div>%s%s<div style="display:flex;align-items:center;gap:16px;height:56px"><span class="cap" style="width:96px">Preset</span><div style="width:300px">%s</div></div>'%(gauge(),statgrid(3,STATS),hdr,rows,pres()),1).replace('Settings','Budget').replace('MENU','BUDGET')

# ---- V2: Settings grammar (name + effect left, one 300 column: stepper)
rows=''
for ic,nm,p,ef,dg in POL:
    rows+='<div style="display:grid;grid-template-columns:1fr 300px;gap:16px;align-items:center;min-height:64px;border-bottom:1px solid #2a2216"><div><div class="name" style="font-size:13px">%s</div><div class="eff">%s</div></div><div style="display:grid;grid-template-columns:56px 1fr 56px;gap:8px;align-items:center"><span class="sq" style="width:56px">−</span><div class="pct" style="text-align:center;border:1px solid #3a2f1b;height:28px;line-height:26px;font-size:15px;background:#120e09">%d %%</div><span class="sq" style="width:56px">+</span></div></div>'%(nm,ef,p)
out['bud_V2_rows']=page('V2','<div style="margin-bottom:8px">%s</div><div style="display:grid;grid-template-columns:1fr 300px;gap:16px;align-items:center;height:56px;border-top:1px solid #2a2216;border-bottom:1px solid #2a2216"><span class="name" style="font-size:13px">Preset</span>%s</div>%s'%(statgrid(6,[(k.split()[0],v,c) for k,v,c in STATS]),pres(),rows),1).replace('MENU','BUDGET')

# ---- V3: four equal cards on a 2x2 grid
cards=''
for ic,nm,p,ef,dg in POL:
    cards+='<div style="border:1px solid #3a2f1b;background:#17120c;padding:16px;display:flex;flex-direction:column;gap:8px;height:192px"><div style="display:flex;align-items:center;gap:12px"><div class="ico">%s</div><div class="name" style="flex:1">%s</div><div class="pct">%d%%</div></div>%s<div class="eff" style="height:34px">%s</div><div style="display:flex;gap:8px"><span class="sq" style="flex:1;width:auto">−</span><span class="sq" style="flex:1;width:auto">+</span></div></div>'%(ic,nm,p,trk(p,dg),ef)
out['bud_V3_cards']=page('V3','%s<div style="height:16px"></div><div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">%s</div>'%(statgrid(6,[(k.split()[0],v,c) for k,v,c in STATS]),cards),1).replace('MENU','BUDGET')

# ---- V4: sliders + live consequence panel
rows=''
for ic,nm,p,ef,dg in POL:
    rows+='<div style="height:80px;border-bottom:1px solid #2a2216;display:grid;grid-template-columns:1fr 48px;gap:8px;align-items:center"><div><div class="name" style="font-size:12px">%s</div>%s</div><div class="pct">%d%%</div></div>'%(nm,trk(p,dg),p)
bars=''.join('<div style="display:grid;grid-template-columns:88px 1fr 48px;gap:8px;align-items:center;height:24px"><span class="k cap" style="font-size:10px;color:var(--dim)">%s</span><div style="height:8px;background:#2d2415"><div style="height:8px;width:%d%%;background:%s"></div></div><span style="text-align:right;font-family:Cinzel;font-size:12px;color:%s">%s</span></div>'%(k,w,c,tc,v) for k,w,c,tc,v in [('Taxes',20,'var(--good)','var(--good)','+98'),('Provinces',80,'var(--good)','var(--good)','+833'),('Upkeep',60,'var(--bad)','var(--bad)','−625'),('Admin',6,'var(--bad)','var(--bad)','−24')])
panel='<div style="border:1px solid #3a2f1b;background:#17120c;padding:16px;height:100%%;display:flex;flex-direction:column;gap:8px"><div style="display:flex;gap:16px;align-items:center">%s<div><div class="cap" style="color:var(--dim)">Net per turn</div><div style="font-size:26px;font-family:Cinzel;color:var(--good)">+566</div></div></div><div class="hl"></div>%s<div class="hl"></div><div class="cap" style="color:var(--dim)">If you raise Tax to 60 %%</div><div class="eff" style="font-size:14px;color:var(--ivory)">+19 gold a turn · contentment −6</div></div>'%(gauge('')[:0]+'',bars)
out['bud_V4_preview']=page('V4','<div style="display:grid;grid-template-columns:1fr 280px;gap:24px"><div>%s<div style="display:flex;align-items:center;gap:16px;height:56px"><span class="name" style="font-size:12px;width:72px">Preset</span><div style="flex:1">%s</div></div></div><div>%s</div></div>'%(rows,pres(),panel),1).replace('MENU','BUDGET')

for k,v in out.items():
    import re
    v=re.sub(r'<div class="tabs">.*?</div></div>(?=<div class="body">)','',v,count=1,flags=re.S)
    v=v.replace('</style>',EXTRA+'</style>',1).replace('<div class="x">×</div>','<div class="x">×</div>').replace('<div class="tabs"><div class="">Saves</div><div class="on">Settings</div><div class="">How to play</div><div class="">Honours</div></div>','<div class="tabs" style="height:0;padding:0;border:0;overflow:hidden"></div>').replace('<div class="ft"><span class="btn">Main menu</span><span class="btn pri">Resume game</span></div>','<div class="ft"><span class="btn">Revert</span><span class="btn pri">Done</span></div>')
    open(k+'.html','w').write(v)
print(len(out),'files')
