import json,urllib.request,urllib.parse,time
UA={'User-Agent':'TerraBellumFlagTool/1.0 (https://github.com/nurmamatovhusanbek-create/fuzzy-journey; game asset build)'}
def get(params):
    q=urllib.parse.urlencode(params)
    time.sleep(1.2)
    for a in range(6):
        try:
            return json.load(urllib.request.urlopen(urllib.request.Request('https://commons.wikimedia.org/w/api.php?'+q,headers=UA),timeout=40))
        except Exception as e:
            err=e; time.sleep(12*(a+1) if '429' in str(e) else 2*(a+1))
    raise err
def exists(titles):
    out={}
    for i in range(0,len(titles),40):
        d=get({'action':'query','titles':'|'.join(titles[i:i+40]),'prop':'imageinfo','iiprop':'url','format':'json','redirects':1})
        red={r['from']:r['to'] for r in d['query'].get('redirects',[])}
        norm={r['from']:r['to'] for r in d['query'].get('normalized',[])}
        ok={p['title'] for p in d['query']['pages'].values() if 'imageinfo' in p}
        for t in titles[i:i+40]:
            n=norm.get(t,t); n=red.get(n,n); out[t]=(n in ok, n)
    return out
def search(q,n=8):
    d=get({'action':'query','list':'search','srnamespace':6,'srsearch':q,'srlimit':n,'format':'json'})
    return [x['title'] for x in d['query']['search']]

def prefix(p,n=40):
    d=get({'action':'query','list':'allpages','apnamespace':6,'apprefix':p,'aplimit':n,'format':'json'})
    return [x['title'][5:] for x in d['query']['allpages']]
