import csv, glob, collections, sys
res=[]
for f in glob.glob(sys.argv[1]+'/*.csv'):
    try: rows=list(csv.DictReader(open(f,encoding='utf-8-sig',errors='replace')))
    except Exception: continue
    if not rows or 'Role' not in rows[0] or 'Military' not in rows[0]: continue
    by=collections.defaultdict(list)
    for r in rows:
        if r.get('Mode')!='bully' or r.get('Alive')!='1': continue
        try: by[(r['GameId'],int(r['Turn']))].append((float(r['Military']),r['Role']))
        except: pass
    for (g,t),L in by.items():
        if len(L)<4: continue
        tot=sum(m for m,_ in L) or 1
        ag=[m for m,r in L if r=='aggressor']
        if ag: res.append((g,t,ag[0]/tot))
games=collections.defaultdict(float)
for g,t,s in res:
    if t>=80: games[g]=max(games[g],s)
v=sorted(games.values())
print('bully games with T80+ rows:',len(v))
q=lambda p:v[int(p*(len(v)-1))]
print('aggressor max share T80+: median %.0f%%, p75 %.0f%%, p90 %.0f%%, max %.0f%%'%(100*q(.5),100*q(.75),100*q(.9),100*v[-1]))
print('>=50% now:',sum(s>=.5 for s in v), ' would be >=50% with a doubled army (2s/(1+s)):',sum(2*s/(1+s)>=.5 for s in v), ' i.e. share >= 33%')
