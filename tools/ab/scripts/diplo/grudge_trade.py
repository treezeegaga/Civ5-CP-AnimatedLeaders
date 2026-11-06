import json, collections, os, csv, glob
exec(open('dealan.py').read().split('# ---------- 1.')[0].replace("print('deals in games","pass #"))
opn={}
for g in games_dip:
    for line in open(f'deals/{g}/dip.csv',encoding='latin-1'):
        p=line.rstrip('\n').split(',')
        if len(p)<8: continue
        opn[(g,int(p[0]),p[1].strip(),p[2].strip())]=p[7].replace('OPN','').replace('*','').strip()
score=collections.defaultdict(dict)
def norm(c): return c.replace('CIVILIZATION_','').replace('_',' ').lower()
for f in glob.glob('csv/*.csv'):
    try: rows=list(csv.DictReader(open(f,encoding='utf-8-sig',errors='replace')))
    except Exception: continue
    if not rows or 'Score' not in rows[0]: continue
    for r in rows:
        if r.get('Alive')!='1': continue
        try: score[(r['GameId'],int(r['Turn']))][norm(r['Civ'])]=int(r['Score'])
        except: pass
alias={'zulus':'zulu','ottomans':'ottoman','aztecs':'aztec'}
def cn(n):
    n=n.lower(); n=n[4:] if n.startswith('the ') else n; return alias.get(n,n)
def sc(gid,t,c):
    s=score.get((gid,(t//10)*10)) or {}
    k=[x for x in s if x==cn(c) or x.startswith(cn(c)) or cn(c).startswith(x)]
    return (s[k[0]], max(s.values())) if k else (None,None)
tab=collections.defaultdict(collections.Counter)
for d in deals:
    gid=d['g'][5:]
    if any(i[3] in ('peace','other') for i in d['items']): continue
    for t,a,b,k,r,v in d['items']:
        if k not in ('lux','strat','ob','gold','ra','gpt'): continue
        o=opn.get((d['g'],t,a,b))
        if o is None: continue
        o={'N':'neutral','':'neutral'}.get(o,o)
        sa,top=sc(gid,t,a); sb,_=sc(gid,t,b)
        if sa is None or sb is None: continue
        ahead='receiver ahead of giver' if sb>sa*1.1 else 'not ahead'
        lab='gives '+{'lux':'luxury','strat':'strategic','ob':'open borders','gold':'gold','ra':'research agr.','gpt':'GPT'}[k]
        tab[(o,ahead)][lab]+=1
order=['ALLY','FRIEND','Favorable','neutral','Competitor','ENEMY','UNFORGIVABLE']
print('items given, by the GIVER\'s opinion of the receiver, and whether the receiver outscores the giver by 10%+')
for o in order:
    for ah in ('receiver ahead of giver','not ahead'):
        c=tab.get((o,ah))
        if c: print(f'  {o:12s} {ah:24s} n={sum(c.values()):5d}  '+', '.join(f'{k} {v}' for k,v in c.most_common()))
