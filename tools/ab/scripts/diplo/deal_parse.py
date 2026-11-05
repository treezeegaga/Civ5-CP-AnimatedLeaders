import os, re, collections, json, sys
base=sys.argv[1]
STRAT={'IRON','HORSES','COAL','OIL','ALUMINUM','URANIUM'}
out=[]
for g in sorted(os.listdir(base)):
    f=os.path.join(base,g,'DiplomacyAI_TradeAgreements_Log.csv')
    if not os.path.exists(f): continue
    cur=[]
    for line in open(f,encoding='latin-1'):
        if line.startswith('DEAL COMPLETE'):
            if cur: out.append({'g':g,'t':cur[0][0],'items':cur})
            cur=[]; continue
        p=[x.strip() for x in line.split(',')]
        if len(p)<6 or not p[0].isdigit(): continue
        t=int(p[0]); giver,recv,it=p[1],p[2],p[5]
        m=re.search(r'value (-?\d+)',line); v=int(m.group(1)) if m else None
        if 'Resource Trade' in it:
            r=re.search(r'RESOURCE_(\w+?) \*',it).group(1); kind='strat' if r in STRAT else 'lux'
        elif 'GPT Trade' in it: r=int(re.search(r'GPT Trade: (\d+)',it).group(1)); kind='gpt'
        elif 'Gold Trade' in it: r=int(re.search(r'Gold Trade: (\d+)',it).group(1)); kind='gold'
        elif 'Open Borders' in it: kind='ob'; r=None
        elif 'Embassy' in it: kind='emb'; r=None
        elif 'Defensive Pact' in it: kind='dp'; r=None
        elif 'Research Agreement' in it: kind='ra'; r=None
        elif 'Peace Treaty' in it: kind='peace'; r=None
        else: kind='other'; r=it
        cur.append((t,giver,recv,kind,r,v))
json.dump(out,open('deals.json','w'))
c=collections.Counter(tuple(sorted(set(k for _,_,_,k,_,_ in d['items']))) for d in out)
print(len(out),'deals in',len(set(d['g'] for d in out)),'games')
for k,v in c.most_common(20): print(v,k)
