import csv, glob, collections, sys
best=collections.defaultdict(lambda:(0,None)); n=0
hits=collections.Counter(); games=set(); hitgames=collections.defaultdict(set)
for f in glob.glob(sys.argv[1]+'/*.csv'):
    try: rows=list(csv.DictReader(open(f,encoding='utf-8-sig',errors='replace')))
    except Exception: continue
    if not rows or 'Military' not in rows[0]: continue
    by=collections.defaultdict(list)
    for r in rows:
        if r.get('Alive')!='1': continue
        try: m=float(r['Military']); t=int(r['Turn'])
        except: continue
        by[(r['GameId'],r.get('Flip',''),t)].append((m,r['Civ'],r.get('Role',''),r.get('Mode','')))
    for (g,fl,t),L in by.items():
        if len(L)<4: continue
        tot=sum(x[0] for x in L) or 1
        m,c,role,mode=max(L)
        sh=m/tot; games.add((g,fl))
        for th in (0.3,0.4,0.5):
            if sh>=th: hitgames[th].add((g,fl))
        if sh>best[(g,fl)][0]: best[(g,fl)]=(sh,(t,c,role,mode))
print('games',len(games))
for th in (0.3,0.4,0.5): print(f'any civ >= {th:.0%} of the military at some logged turn: {len(hitgames[th])} games')
top=sorted(best.items(),key=lambda kv:-kv[1][0])[:12]
for k,v in top: print(k, f'{v[0]:.0%}', v[1])
