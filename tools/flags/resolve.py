"""Draft the nation -> Wikimedia Commons flag file table for an era, by the era's year.
usage: python3 tools/flags/resolve.py ww2      -> tools/flags/ww2_draft.json (review, then write overrides in <era>_override.json and run finalize.py)
For each nation it lists `Flag of <name>*.svg` on Commons and keeps the file whose year range (in the title) covers the era year."""
import sys,os,re,json
sys.path.insert(0,os.path.dirname(__file__))
from api import prefix,get
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'..','..'))
era=sys.argv[1]
E=json.load(open(os.path.join(root,'godot/data/eras',era+'.json'))); year=E['year']
BAD=re.compile(r'proposal|vertical|stretched|unofficial|alternative|colou?ring|construction|variant|WFB|factbook|pantone|upside|gif|aspect|\(3-2|, 3-2|2-3|1-1|2-1|mirror|reversed|logo|simplified|no coat|without|old version|\bsvg\b.*svg',re.I)
ALIAS={'ussr':['the Soviet Union'],'usa':['the United States'],'united_states':['the United States'],'british_empire':['the United Kingdom'],'empire_of_japan':['Japan'],'siam':['Thailand','Siam'],
 'gambia_the':['The Gambia'],'union_of_south_africa':['South Africa'],'dominion_of_newfoundland':['Newfoundland'],'trucial_oman':['the Trucial States'],'germany':['Germany'],'china':['the Republic of China'],
 'zaire':['the Democratic Republic of the Congo'],'congo':['the Republic of the Congo'],'burma':['Burma'],'trinidad':['Trinidad and Tobago'],'netherlands':['the Netherlands'],'philippines':['the Philippines'],
 'bahamas':['the Bahamas'],'ceylon':['Ceylon'],'laos':['Laos'],'czechoslovakia':['Czechoslovakia'],'yugoslavia':['Yugoslavia'],'malaysia':['Malaya','Malaysia'],'uae':['the United Arab Emirates']}
def bases(n):
    nm=n['name']; out=[]
    for a in ALIAS.get(n['id'],[]): out.append(a)
    out.append(nm)
    for pre in ('Dominion of ','Kingdom of ','Republic of ','Empire of ','Union of ','Sultanate of ','Emirate of ','Khanate of '):
        if nm.startswith(pre): out.append(nm[len(pre):])
    seen=[]; [seen.append(x) for x in out if x not in seen]; return seen
def ranges(t):
    r=[]
    for m in re.finditer(r'(\d{3,4})\s*[–\-—]\s*(\d{3,4}|present)?',t):
        a=int(m.group(1)); b=int(m.group(2)) if m.group(2) and m.group(2)!='present' else 9999; r.append((a,b))
    for m in re.finditer(r'\((\d{3,4})\)',t): r.append((int(m.group(1)),int(m.group(1))))
    return r
out={}
for n in E['nations']:
    cands=[]
    for b in bases(n):
        for pre in (f'Flag of {b}',):
            try: cands+= [x for x in prefix(pre,60) if x.endswith('.svg')]
            except Exception as e: print('ERR',pre,e)
    cands=[c for c in dict.fromkeys(cands) if not BAD.search(c)]
    best=None; conf='none'
    ranged=[]
    for c in cands:
        rs=ranges(c)
        hit=[(b-a) for a,b in rs if a<=year<=b]
        if hit: ranged.append((min(hit),len(c),c))
    if ranged: ranged.sort(); best=ranged[0][2]; conf='year'
    else:
        plain=[c for c in cands if re.fullmatch(r'Flag of (the )?[^()]+\.svg',c)]
        if plain: best=sorted(plain,key=len)[0]; conf='plain'
    out[n['id']]={'name':n['name'],'title':best,'conf':conf,'alts':[c for c in cands if c!=best][:6]}
    print(n['id'],conf,best,flush=True)
json.dump(out,open(os.path.join(root,'tools/flags',era+'_draft.json'),'w'),ensure_ascii=False,indent=1)
