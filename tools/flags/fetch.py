"""Fetch the SVGs (and licence/author metadata) a <era>_map.json asks for from Wikimedia Commons.
usage: python3 tools/flags/fetch.py coldwar
Writes flags/src/<slug>.svg (originals, for provenance) and flags/meta/<era>.json. Throttled; safe to re-run (skips what exists)."""
import sys,os,json,re,time,urllib.request
sys.path.insert(0,os.path.dirname(__file__))
from api import get,UA
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'..','..'))
era=sys.argv[1]
M=json.load(open(os.path.join(root,'tools/flags',era+'_map.json')))
titles=sorted({v['title'] for v in M.values() if v['title']})
src=os.path.join(root,'flags/src'); os.makedirs(src,exist_ok=True); os.makedirs(os.path.join(root,'flags/meta'),exist_ok=True)
slug=lambda t:re.sub(r'[^A-Za-z0-9]+','_',t[:-4]).strip('_').lower()
meta={}
mp=os.path.join(root,'flags/meta',era+'.json')
if os.path.exists(mp): meta=json.load(open(mp))
need=[t for t in titles if t not in meta]
for i in range(0,len(need),20):
    d=get({'action':'query','titles':'|'.join('File:'+t for t in need[i:i+20]),'prop':'imageinfo','iiprop':'url|extmetadata','iiextmetadatafilter':'LicenseShortName|Artist|Credit|UsageTerms','format':'json','redirects':1})
    red={r['to']:r['from'] for r in d['query'].get('redirects',[])}
    for p in d['query']['pages'].values():
        if 'imageinfo' not in p: print('NO FILE',p['title']); continue
        t=p['title'][5:]; t=red.get('File:'+t,'File:'+t)[5:]
        ii=p['imageinfo'][0]; m=ii.get('extmetadata',{})
        strip=lambda s:re.sub(r'<[^>]+>','',s or '').strip()
        meta[t]={'url':ii['url'],'page':'https://commons.wikimedia.org/wiki/File:'+t.replace(' ','_'),'license':strip(m.get('LicenseShortName',{}).get('value')),'artist':strip(m.get('Artist',{}).get('value'))[:120],'resolved':p['title'][5:]}
    json.dump(meta,open(mp,'w'),ensure_ascii=False,indent=1)
def todo(): return [t for t in titles if t in meta and not (os.path.exists(os.path.join(src,slug(t)+'.svg')) and os.path.getsize(os.path.join(src,slug(t)+'.svg'))>50)]
for rnd in range(80):                      # one attempt per file per round: a throttled file never blocks the others
    left=todo()
    if not left: break
    got=0
    for t in left:
        time.sleep(12.0)
        try:
            data=urllib.request.urlopen(urllib.request.Request(meta[t]['url'].split('?')[0],headers=UA),timeout=60).read()
            open(os.path.join(src,slug(t)+'.svg'),'wb').write(data); got+=1; print('ok',t,flush=True)
        except Exception as e:
            print('throttled',t,str(e)[:40],flush=True); time.sleep(45)
    print('round',rnd,'got',got,'left',len(todo()),flush=True)
print('done',len(titles),'missing',len(todo()))
