"""list the Commons file titles under several 'Flag of ...' prefixes (svg only) -> /tmp/fl/stems.json. usage: python3 tools/flags/stems.py "Flag of Persia" ..."""
import sys,os,json
sys.path.insert(0,os.path.dirname(__file__))
from api import prefix
out={}
for p in sys.argv[1:]:
    try: out[p]=[x for x in prefix(p,80) if x.endswith('.svg')]
    except Exception as e: out[p]=['ERR '+str(e)[:50]]
    print(p,len(out[p]),flush=True)
    json.dump(out,open('/tmp/fl/stems.json','w'),ensure_ascii=False,indent=0)
