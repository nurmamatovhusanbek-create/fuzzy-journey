#!/usr/bin/env python3
"""Themes a built demo: swaps the display/reading faces (Cormorant SC + EB Garamond under the Cinzel / Alegreya names) and the status palette.
usage: python3 theme.py bezel_demo2.html out.html [p1|p2|none]"""
import re,sys,base64,os
src,out,pal=sys.argv[1],sys.argv[2],(sys.argv[3] if len(sys.argv)>3 else 'none')
h=open(src).read()
def face(fam,fid,wt,style,sub):
    p=f'/tmp/xf/{fid}-{sub}-{wt}-{style}.woff2'
    if not os.path.exists(p): return ''
    ur='U+0000-00FF,U+0131,U+0152-0153,U+2000-206F,U+2212,U+2215' if sub=='latin' else 'U+0301,U+0400-045F,U+0490-0491,U+04B0-04B1,U+2116'
    b=base64.b64encode(open(p,'rb').read()).decode()
    return f"@font-face{{font-family:'{fam}';font-weight:{wt};font-style:{style};src:url(data:font/woff2;base64,{b}) format('woff2');unicode-range:{ur}}}"
h=re.sub(r"@font-face\{font-family:'(Cinzel|Alegreya)';[^}]*\}","",h)
new=[]
for sub in ('latin','cyrillic'):
    for wt in (500,700): new.append(face('Cinzel','cormorant-sc',wt,'normal',sub))
    for wt in (400,500,700): new.append(face('Alegreya','eb-garamond',wt,'normal',sub))
    new.append(face('Alegreya','eb-garamond',400,'italic',sub))
h=h.replace('<style>','<style>\n'+'\n'.join(x for x in new if x),1)
P={'p1':{'#69B3A2':'#E5C77A','#D2603F':'#4F73A8','#7a3a28':'#24385A','#a8442b':'#24385A','#ee8a68':'#8FB0E0','#E4A94B':'#D98A4A','--good':'#E5C77A','--bad':'#4F73A8','--warn':'#D98A4A'},
   'p2':{'#69B3A2':'#EFE6CF','#D2603F':'#5B7099','#7a3a28':'#233250','#a8442b':'#233250','#ee8a68':'#C98A92','#E4A94B':'#C9A24B','--good':'#EFE6CF','--bad':'#5B7099','--warn':'#C9A24B'}}
if pal in P:
    m=P[pal]
    for k,v in m.items():
        if k.startswith('--'): h=re.sub(r'(%s:)#[0-9A-Fa-f]{6}'%re.escape(k),r'\g<1>'+v,h,count=1)
        else: h=h.replace(k,v)
open(out,'w').write(h)
