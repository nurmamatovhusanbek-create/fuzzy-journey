"""Copy the plain modern flags a <era>_map.json marks 'iso' from a flag-icons checkout (MIT) into flags/src, so they are not downloaded.
usage: python3 tools/flags/local_copy.py coldwar /path/to/flag-icons"""
import json,re,shutil,os,sys
era,fi=sys.argv[1],sys.argv[2]
root=os.path.abspath(os.path.join(os.path.dirname(__file__),'..','..'))
p=os.path.join(root,'tools/flags',era+'_map.json'); M=json.load(open(p))
slug=lambda t:re.sub(r'[^A-Za-z0-9]+','_',t[:-4]).strip('_').lower()
n=0
for nat,v in M.items():
    if not v.get('iso'): continue
    f=os.path.join(root,'flags/src',slug(v['title'])+'.svg'); sp=os.path.join(fi,'flags/4x3',v['iso']+'.svg')
    if os.path.exists(sp) and not os.path.exists(f): shutil.copy(sp,f); n+=1
    v['source']='flag-icons'
json.dump(M,open(p,'w'),ensure_ascii=False,indent=1)
need=sorted({v['title'] for v in M.values() if v['title'] and not os.path.exists(os.path.join(root,'flags/src',slug(v['title'])+'.svg'))})
print('copied',n,'still to download',len(need)); print(need)
