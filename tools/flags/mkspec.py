"""helpers for hand-written era specs (tools/flags/specs/<era>.py -> specs/<era>.json)"""
import json,os
def V(base):                                   # en-dash / hyphen spellings of a Commons title
    return [base, base.replace('–','-')] if '–' in base else [base, base.replace('-','–')]
def D(*titles,note=''):
    out=[]
    for t in titles: out+= [x for x in V(t) if x not in out]
    return {'c':out,'note':note} if note else {'c':out}
def I(iso,note=''): return {'iso':iso,'note':note} if note else {'iso':iso}
def A(n,note=''): return {'as':n,'note':note} if note else {'as':n}
EMB={'emblem':True}
def save(era,S): json.dump(S,open(os.path.join(os.path.dirname(__file__),'specs',era+'.json'),'w'),ensure_ascii=False,indent=1)
