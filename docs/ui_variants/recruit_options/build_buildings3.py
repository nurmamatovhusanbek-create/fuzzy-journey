#!/usr/bin/env python3
"""Build tab, the chosen showcase (N1) taken further: two refinements. Reuses build_buildings2 (data, scenario, classes); writes ../building_options/new_N1a_*.html, new_N1b_*.html"""
src=open('build_buildings2.py').read()
exec(src[:src.index("for n,h in [('N1_showcase_library'")])
CSS3="""
.nb-disc .s{font:600 12px/1 Alegreya;height:12px;white-space:nowrap;color:var(--dim)}
.nb-disc .s.built{color:var(--good)} .nb-disc .s.busy{color:#e5c77a}
.nb-disc{gap:8px}
.nb-foot{display:flex;align-items:center;gap:28px;margin-top:22px;padding-top:20px;border-top:1px solid #3a2f1d}
.nb-foot .nb-need{flex:1}
.nb-foot .nb-act{margin-top:0;flex:0 0 360px}
.nb-chips{display:flex;gap:10px;margin-top:20px}
.nb-chip{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;height:62px;box-sizing:border-box;background:#100d09;box-shadow:inset 0 0 0 1px #2e2517}
.nb-chip b{font:700 18px/1 Alegreya;color:var(--ivory)} .nb-chip small{font:600 10px/1 Cinzel;letter-spacing:.16em;color:var(--dim);text-transform:uppercase}
.nb-head{display:flex;align-items:center;gap:22px;margin-top:22px;padding-top:22px;border-top:1px solid #3a2f1d}
.nb-head .tx{flex:1;min-width:0}
.nb-tl{position:relative;display:grid;grid-template-columns:repeat(var(--n),1fr);margin-top:26px}
.nb-tl:before{content:"";position:absolute;left:calc(50%/var(--n));right:calc(50%/var(--n));top:19px;height:2px;background:#3a2f1d}
.nb-st3{position:relative;display:flex;flex-direction:column;align-items:center;gap:10px;text-align:center;padding:0 6px}
.nb-st3 .n{width:40px;height:40px;border-radius:50%;box-sizing:border-box;display:grid;place-items:center;font:700 16px/1 Alegreya;color:var(--dim);background:#0f0c09;box-shadow:inset 0 0 0 1.5px #4a3f28;position:relative}
.nb-st3.cur .n{color:#1b1408;background:linear-gradient(#EBCF85,#B38F3E);box-shadow:none}
.nb-st3.nxt .n{color:var(--hi);box-shadow:inset 0 0 0 2px var(--hi),0 0 0 4px rgba(229,199,122,.22)}
.nb-st3 .e{font:400 14.5px/1.25 Alegreya;color:var(--ivory);height:22px;display:flex;align-items:flex-start;justify-content:center}
.nb-st3 .c{font:700 13.5px/1 Alegreya;color:var(--ivory);white-space:nowrap} .nb-st3 .c small{font:400 12px/1 Alegreya;color:var(--dim);margin-left:6px}
.nb-st3.nxt .e{color:#EBCF85}
"""
def page10(t,inner):
    return page9(t,inner).replace('</style>',CSS3+'</style>',1)
def disc_state(b):
    if b['busy']: return ('Building','busy')
    if b['cur']>0: return ('Level %d / %d'%(b['cur'],b['n']),'built')
    return ('%d gold'%b['cost'],'')
def discs(sel):
    out=[]
    for i in ORDER:
        b=info(i); s=disc_state(b)
        out.append('<div class="nb-disc%s">%s<span class="l">%s</span><span class="s %s">%s</span></div>'%(' sel' if i==sel else '',emblem(b,60,26),b['name'],s[1],s[0]))
    return '<div style="display:flex;justify-content:space-between;padding:0 6px">%s</div>'%''.join(out)
def eff(b): return b['fx'][b['cur'] if b['cur']<b['n'] else b['n']-1]
def foot(b): return '<div class="nb-foot"><div class="nb-need">%s</div><div class="nb-act">%s</div></div>'%(checks(b),buttons(b))
def chips(b): return '<div class="nb-chips"><div class="nb-chip"><b>%d</b><small>Gold</small></div><div class="nb-chip"><b>%d</b><small>%s</small></div><div class="nb-chip"><b>%d</b><small>%s</small></div></div>'%(b['cost'],b['turns'],'Turn' if b['turns']==1 else 'Turns',b['mv'],'Move' if b['mv']==1 else 'Moves')
# N1a: the showcase with a state line under every disc, the cost chips filling the left column, and one footer for needs + buttons
def n1a(sel):
    b=info(sel); st=state_of(b)
    left=('<div class="nb-big">%s<div><h3>%s</h3><div style="margin-top:10px;display:flex;align-items:center;gap:12px">%s<span class="nb-st %s">%s</span></div></div></div>'
          '<div class="nb-eff" style="margin-top:18px;height:24px">%s</div>%s')%(emblem(b,84,36),b['name'],pips(b['n'],b['cur']),st[1],st[0],eff(b),chips(b))
    right='<div class="nb-sec" style="margin-top:20px">Levels</div>'+ladder(b)
    return '<div class="nb-card">'+plate(head()+discs(sel)+'<div class="nb-feat" style="margin-top:20px;padding-top:2px;border-top:1px solid #3a2f1d"><div>%s</div><div>%s</div></div>%s'%(left,right,foot(b)),900,12)+'</div>'
# N1b: the levels become a timeline across the whole width, the feature header sits on one line
def n1b(sel):
    b=info(sel); st=state_of(b)
    steps=''.join('<div class="nb-st3 %s"><span class="n">%s</span><span class="e">%s</span><span class="c">%s</span></div>'%('cur' if k+1<=b['cur'] else ('nxt' if k+1==b['cur']+1 else ''),'✓' if k+1<=b['cur'] else k+1,b['fx'][k],'built' if k+1<=b['cur'] else '%d gold<small>%d turn%s</small>'%(b['lv'][k][0],b['lv'][k][1],'' if b['lv'][k][1]==1 else 's')) for k in range(b['n']))
    hd='<div class="nb-head">%s<div class="tx"><h3 style="margin:0;font:900 24px/1.05 Cinzel;letter-spacing:.08em;color:var(--ivory);text-transform:uppercase">%s</h3><div style="margin-top:10px;display:flex;align-items:center;gap:12px">%s<span class="nb-st %s">%s</span></div></div><div class="nb-eff" style="flex:0 0 330px;text-align:right">%s</div></div>'%(emblem(b,76,34),b['name'],pips(b['n'],b['cur']),st[1],st[0],eff(b))
    tl='<div class="nb-tl" style="--n:%d">%s</div>'%(b['n'],steps)
    return '<div class="nb-card">'+plate(head()+discs(sel)+hd+tl+foot(b),900,12)+'</div>'
for n,h in [('N1a_library',n1a('library')),('N1a_farm',n1a('farm')),('N1b_library',n1b('library')),('N1b_farm',n1b('farm'))]:
    open(OUT+'new_%s_desk.html'%n,'w').write(page10(n,h))
print('ok')
