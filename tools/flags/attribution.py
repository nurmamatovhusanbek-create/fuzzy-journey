"""Write flags/credits_<era>.md: which file each nation's flag in an era comes from, its licence and author.
usage: python3 tools/flags/attribution.py coldwar"""
import json,os,sys
era=sys.argv[1]
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'..','..'))
M=json.load(open(os.path.join(root,'tools/flags',era+'_map.json'))); meta=json.load(open(os.path.join(root,'flags/meta',era+'.json')))
L=[f'# Flag credits: {era}','',"Each flag is the one flown in that era, rasterised to `godot/assets/flags/%s/<nation>.png` (192x128, aspect kept). Originals are in `flags/src/`."%era,'',
'| Nation | File | Licence | Source | Note |','|---|---|---|---|---|']
for nat,v in sorted(M.items()):
    if v['title']:
        m=meta.get(v['title'],{}); src='flag-icons (MIT)' if v.get('source')=='flag-icons' else '[Wikimedia Commons]('+m.get('page','')+')'
        L.append(f"| {nat} | {v['title']} | {m.get('license','?')} | {src} | {v['note']} |")
    else: L.append(f"| {nat} | (authored) | CC0 | this repo | {v['note']} |")
open(os.path.join(root,'flags',f'credits_{era}.md'),'w').write('\n'.join(L)+'\n'); print('wrote',len(M),'rows')
