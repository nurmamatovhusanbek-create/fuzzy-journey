"""Download every Commons file title that starts with 'Flag of ' (a few tens of thousands, 500 per call) into tools/flags/commons_titles.json,
so resolve.py can pick flags offline. usage: python3 tools/flags/index_titles.py"""
import sys,os,json,time
sys.path.insert(0,os.path.dirname(__file__))
from api import get
out=os.path.join(os.path.dirname(__file__),'commons_titles.json')
titles=json.load(open(out)) if os.path.exists(out) else {'titles':[],'next':None}
cont=titles['next']; n=0
while True:
    p={'action':'query','list':'allpages','apnamespace':6,'apprefix':'Flag of ','aplimit':500,'format':'json'}
    if cont: p['apcontinue']=cont
    d=get(p)
    titles['titles']+= [x['title'][5:] for x in d['query']['allpages'] if x['title'].endswith('.svg')]
    cont=d.get('continue',{}).get('apcontinue'); titles['next']=cont; n+=1
    json.dump(titles,open(out,'w'),ensure_ascii=False)
    print(n,len(titles['titles']),cont,flush=True)
    if not cont: break
print('done')
