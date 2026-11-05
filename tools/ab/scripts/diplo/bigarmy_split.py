import csv, glob, collections, sys
games={}
for f in sys.argv[1:]:
    for r in csv.DictReader(open(f,encoding='utf-8-sig')):
        if '1750459' not in r['Build'] or r['Mode']!='bully': continue
        g=(f.split('@')[1][:3],r['GameId'],r['Flip'])
        G=games.setdefault(g,{'turns':collections.defaultdict(list),'agg':None,'final':{}})
        try: t=int(r['Turn']); m=float(r['Military'])
        except: continue
        if r['Alive']=='1': G['turns'][t].append((m,r['Role']=='aggressor',r['Civ']))
        if r['Role']=='aggressor':
            G['agg']=r['Civ']
            if t>=max(G['final'].get('_t',-1),t): G['final']=dict(r); G['final']['_t']=t
rows=[]
for g,G in games.items():
    best=0; bt=None; first50=None
    for t in sorted(G['turns']):
        L=G['turns'][t]; tot=sum(m for m,_,_ in L) or 1
        a=[m for m,ag,_ in L if ag]
        if not a: continue
        s=a[0]/tot
        if s>best: best,bt=s,t
        if s>=.5 and first50 is None: first50=t
    F=G['final']
    rows.append(dict(pc=g[0],gid=g[1],flip=g[2],civ=(G['agg'] or '').replace('CIVILIZATION_',''),share=best,bt=bt,first50=first50,
        cap=int(F.get('CitiesCaptured',0) or 0),declared=int(F.get('WarsDeclared',0) or 0),onus=int(F.get('WarsOnUs',0) or 0),
        deals=int(F.get('Deals',0) or 0),friends=int(F.get('Friends',0) or 0),pacts=int(F.get('Pacts',0) or 0),lost=int(F.get('CitiesLost',0) or 0),cities=int(F.get('Cities',0) or 0)))
for flip in ('0','1'):
    R=[r for r in rows if r['flip']==flip]
    print(f'==== Flip={flip} ({"BigArmy" if flip=="0" else "flip"}): {len(R)} games')
    for grp,sel in (('crossed 50%',lambda r:r['share']>=.5),('stayed below',lambda r:r['share']<.5)):
        X=[r for r in R if sel(r)]
        if not X: print(f'  {grp}: 0'); continue
        n=len(X); m=lambda k: sum(r[k] for r in X)/n
        print(f'  {grp:13s} n={n:2d}  capture games {sum(r["cap"]>0 for r in X):2d}  cities captured {sum(r["cap"] for r in X):2d}  wars declared {m("declared"):.1f}  wars on it {m("onus"):.1f}  deals {m("deals"):.1f}  friends {m("friends"):.1f}  pacts {m("pacts"):.1f}  cities lost {sum(r["lost"] for r in X)}')
    for r in sorted(R,key=lambda r:-r['share']):
        print(f'   {r["pc"]} {r["gid"][:8]} {r["civ"]:10s} max share {r["share"]:.0%} (T{r["bt"]}) first>=50% {r["first50"]}  cap {r["cap"]} decl {r["declared"]} onus {r["onus"]} deals {r["deals"]} friends {r["friends"]}')
