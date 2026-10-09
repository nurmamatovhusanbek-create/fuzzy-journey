"""Merge tools/flags/<era>_draft.json (from resolve.py) with <era>_override.json into <era>_map.json, the table fetch.py / rasterize.mjs read.
override entries: "nation": {"title": "Flag of X (1914–1918).svg", "note": ".."} | {"as": "other_nation", "note": ".."} | {"emblem": true, "note": ".."} | {"skip": true}
Nations still unresolved get a generated emblem (flags/authored/<nation>.svg) so the era never shows a random flag."""
import sys,os,re,json,hashlib
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'..','..'))
era=sys.argv[1]; here=os.path.join(root,'tools/flags')
D=json.load(open(os.path.join(here,era+'_draft.json')))
O=json.load(open(os.path.join(here,era+'_override.json'))) if os.path.exists(os.path.join(here,era+'_override.json')) else {}
E={n['id']:n for n in json.load(open(os.path.join(root,'godot/data/eras',era+'.json')))['nations']}
cf=json.load(open('/home/user/hampusborgos/country-flags/countries.json')) if os.path.exists('/home/user/hampusborgos/country-flags/countries.json') else {}
norm=lambda s:re.sub(r'[^a-z]','',s.lower())
ISO={norm(v):k.lower() for k,v in cf.items()}; ISO.update({'unitedstates':'us','unitedkingdom':'gb','russia':'ru','southkorea':'kr','northkorea':'kp','iran':'ir','syria':'sy','vietnam':'vn','laos':'la','bolivia':'bo','venezuela':'ve','tanzania':'tz','moldova':'md','czechia':'cz','thailand':'th','thegambia':'gm','bahamas':'bs','netherlands':'nl','philippines':'ph'})
def emblem(nat,name):
    h=int(hashlib.md5(nat.encode()).hexdigest(),16); hue=h%360; g=(h>>9)%6
    bg=f'hsl({hue},38%,22%)'; fg=f'hsl({(hue+25)%360},45%,72%)'
    glyph=['<circle cx="1.5" cy="1" r=".42" fill="none" stroke="%s" stroke-width=".07"/><circle cx="1.5" cy="1" r=".12" fill="%s"/>'%(fg,fg),
           '<path d="M1.5 .5 2.05 1.4H.95z" fill="none" stroke="%s" stroke-width=".07" stroke-linejoin="round"/>'%fg,
           '<path d="M1.5 .45l.14.44.46.01-.37.27.14.44-.37-.27-.37.27.14-.44-.37-.27.46-.01z" fill="%s"/>'%fg,
           '<path d="M1.2 .55v.9M1.5 .55v.9M1.8 .55v.9" stroke="%s" stroke-width=".09"/>'%fg,
           '<path d="M1.5 .45 2.05 1 1.5 1.55.95 1z" fill="none" stroke="%s" stroke-width=".07"/><circle cx="1.5" cy="1" r=".1" fill="%s"/>'%(fg,fg),
           '<path d="M.95 1.35 1.5 .55 2.05 1.35M1.15 1.35 1.5 .85 1.85 1.35" fill="none" stroke="%s" stroke-width=".07" stroke-linejoin="round"/>'%fg][g]
    os.makedirs(os.path.join(root,'flags/authored'),exist_ok=True)
    open(os.path.join(root,'flags/authored',nat+'.svg'),'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3 2"><rect width="3" height="2" fill="{bg}"/><rect x=".08" y=".08" width="2.84" height="1.84" fill="none" stroke="{fg}" stroke-opacity=".45" stroke-width=".03"/>{glyph}</svg>')
M={}
for nat,n in E.items():
    d=D.get(nat,{}); o=O.get(nat,{})
    if o.get('skip'): continue
    if 'as' in o and o['as'] in D or ('as' in o and o['as'] in M): 
        src=o['as']; base=O.get(src) or {}
        t=base.get('title') or D.get(src,{}).get('title'); M[nat]={'title':t,'note':o.get('note','shows the flag of '+src)}; continue
    t=o.get('title') or (None if o.get('emblem') else d.get('title'))
    note=o.get('note','' if d.get('conf')!='plain' else 'current flag of the same name: check it was in use')
    if t:
        M[nat]={'title':t,'note':note}
        m=re.fullmatch(r'Flag of (the )?([^()]+)\.svg',t)
        if m and norm(m.group(2)) in ISO: M[nat]['iso']=ISO[norm(m.group(2))]
    else:
        emblem(nat,n['name']); M[nat]={'title':None,'note':o.get('note','no flag in this era: generated emblem')}
json.dump(M,open(os.path.join(here,era+'_map.json'),'w'),ensure_ascii=False,indent=1)
print(era,len(M),'nations;',sum(1 for v in M.values() if v['title']),'with a Commons file;',sum(1 for v in M.values() if not v['title']),'emblems')
