"""Build tools/flags/<era>_map.json from the hand-written tools/flags/specs/<era>.json.
spec entry per nation id:  {"iso": "fr"}  a modern flag that was also the flag of that era (copied from flag-icons, no download)
                           {"c": ["Flag of X (1936–1945).svg", ...], "note": ".."}  Commons titles to try, first that exists wins (one API call checks 40)
                           {"as": "other_nation"}   {"emblem": true}
usage: python3 tools/flags/build_map.py ww2"""
import sys,os,re,json,hashlib
sys.path.insert(0,os.path.dirname(__file__))
from api import exists
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'..','..')); here=os.path.join(root,'tools/flags'); era=sys.argv[1]
S=json.load(open(os.path.join(here,'specs',era+'.json')))
E=[n for n in json.load(open(os.path.join(root,'godot/data/eras',era+'.json')))['nations']]
cf=json.load(open('/home/user/hampusborgos/country-flags/countries.json'))
cache_p=os.path.join(here,'exists_cache.json'); cache=json.load(open(cache_p)) if os.path.exists(cache_p) else {}
allc=sorted({'File:'+t for v in S.values() for t in v.get('c',[])}-set(cache))
for i in range(0,len(allc),40):
    try: r=exists(allc[i:i+40])
    except Exception as e: print('Commons unreachable, taking the first candidate unverified:',str(e)[:60]); break
    for k,(ok,res) in r.items(): cache[k]=[ok,res]
    json.dump(cache,open(cache_p,'w'),ensure_ascii=False)
def emblem(nat):
    h=int(hashlib.md5(nat.encode()).hexdigest(),16); hue=h%360; g=(h>>9)%6
    bg=f'hsl({hue},38%,22%)'; fg=f'hsl({(hue+25)%360},45%,72%)'
    glyph=['<circle cx="1.5" cy="1" r=".42" fill="none" stroke="%s" stroke-width=".07"/><circle cx="1.5" cy="1" r=".12" fill="%s"/>'%(fg,fg),'<path d="M1.5 .5 2.05 1.4H.95z" fill="none" stroke="%s" stroke-width=".07" stroke-linejoin="round"/>'%fg,'<path d="M1.5 .45l.14.44.46.01-.37.27.14.44-.37-.27-.37.27.14-.44-.37-.27.46-.01z" fill="%s"/>'%fg,'<path d="M1.2 .55v.9M1.5 .55v.9M1.8 .55v.9" stroke="%s" stroke-width=".09"/>'%fg,'<path d="M1.5 .45 2.05 1 1.5 1.55.95 1z" fill="none" stroke="%s" stroke-width=".07"/><circle cx="1.5" cy="1" r=".1" fill="%s"/>'%(fg,fg),'<path d="M.95 1.35 1.5 .55 2.05 1.35M1.15 1.35 1.5 .85 1.85 1.35" fill="none" stroke="%s" stroke-width=".07" stroke-linejoin="round"/>'%fg][g]
    os.makedirs(os.path.join(root,'flags/authored'),exist_ok=True)
    open(os.path.join(root,'flags/authored',nat+'.svg'),'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3 2"><rect width="3" height="2" fill="{bg}"/><rect x=".08" y=".08" width="2.84" height="1.84" fill="none" stroke="{fg}" stroke-opacity=".45" stroke-width=".03"/>{glyph}</svg>')
M={}; todo=[]
for n in E:
    nat=n['id']; s=S.get(nat)
    if s is None: emblem(nat); M[nat]={'title':None,'note':'no flag in this era: generated emblem'}; continue
    if 'as' in s: continue
    if s.get('emblem'): emblem(nat); M[nat]={'title':None,'note':s.get('note','no flag in this era: generated emblem')}; continue
    if 'svg' in s:                                                  # a simple flag (tricolour, bicolour) drawn from its documented colours
        d=os.path.join(root,'flags/authored',era); os.makedirs(d,exist_ok=True); open(os.path.join(d,nat+'.svg'),'w').write(s['svg']); M[nat]={'title':None,'note':s.get('note','authored from the documented design')}; continue
    if 'iso' in s:
        name=cf[s['iso'].upper()]; M[nat]={'title':f'Flag of {name}.svg','iso':s['iso'],'source':'flag-icons','note':s.get('note','')}; continue
    t=next((cache['File:'+c][1][5:] for c in s.get('c',[]) if cache.get('File:'+c,[False])[0]),None)
    if not t and any('File:'+c not in cache for c in s.get('c',[])) and s.get('c'): t=s['c'][0]          # unverified (offline): fetch.py will report it if it does not exist
    if t: M[nat]={'title':t,'note':s.get('note','')}; emblem(nat) if not os.path.exists(os.path.join(root,'flags/authored',nat+'.svg')) else None   # the emblem is the fallback while the file is not downloaded
    else: M[nat]={'title':None,'note':'NOT FOUND on Commons: '+' | '.join(s.get('c',[]))}; todo.append(nat); emblem(nat)
for n in E:
    s=S.get(n['id'],{})
    if 'as' in s: M[n['id']]=dict(M.get(s['as'],{'title':None,'note':''}),note=s.get('note',f"shows the flag of {s['as']}"))
json.dump(M,open(os.path.join(here,era+'_map.json'),'w'),ensure_ascii=False,indent=1)
print(era,len(M),'nations;',sum(1 for v in M.values() if v['title']),'with a file;',len(todo),'to fix:',todo)
