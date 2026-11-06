import json, collections, os
deals=json.load(open('deals.json')); rows=json.load(open('dealrows.json'))
civs=collections.defaultdict(set); span={}
for g in os.listdir('deals'):
    f=f'deals/{g}/dip.csv'
    if not os.path.exists(f) or os.path.getsize(f)==0: continue
    ts=[]
    for line in open(f,encoding='latin-1'):
        p=line.split(',')
        if len(p)<5: continue
        ts.append(int(p[0])); civs[g].add(p[1].strip())
    span[g]=(min(ts),max(ts))
ph=collections.defaultdict(collections.Counter); phct=collections.Counter()
for g,t,k,rn in rows:
    b='renewal' if rn else ('embassy' if k=='embassy swap' else 'new')
    ph[min(t//25,5)][b]+=1
for g in span:
    for t in range(span[g][0],span[g][1]+1): phct[min(t//25,5)]+=len(civs[g])
print('per civ per 10 turns by phase (new deals / renewals / embassies):')
for p in sorted(ph): print(f'  T{25*p:3d}-{25*p+24:3d}: new {20*ph[p]["new"]/phct[p]:.2f}  renewals {20*ph[p]["renewal"]/phct[p]:.2f}  embassies {20*ph[p]["embassy"]/phct[p]:.2f}')
# redone before expiry: same pair + same category while one is active
deals=[d for d in deals if d['g'] in span]
act={}; early=collections.Counter(); n=collections.Counter()
catmap={(g,t):k for g,t,k,rn in rows}
for d in sorted(deals,key=lambda d:(d['g'],d['t'])):
    pr=frozenset(i[1] for i in d['items'])|frozenset(i[2] for i in d['items'])
    k=catmap.get((d['g'],d['t']))
    # category recomputed cheaply: kinds signature
    sigk=tuple(sorted(set(i[3] for i in d['items'])))
    key=(d['g'],pr,sigk); n[sigk]+=1
    if key in act and d['t']-act[key] < 24: early[sigk]+=1
    act[key]=d['t']
print('\nsame pair, same kind of deal made again while the earlier one would still run (<24 turns):')
for s,c in early.most_common(8): print(f'  {"+".join(s):20s} {c:5d} of {n[s]:5d} ({100*c/n[s]:.0f}%)')
# GPT sizes
g=collections.Counter(i[4] for d in deals for i in d['items'] if i[3]=='gpt')
tot=sum(g.values()); print('\nGPT per deal item:', ', '.join(f'{k}: {100*v/tot:.0f}%' for k,v in sorted(g.items())[:8]))
# items per luxury sale
lux=[d for d in deals if set(i[3] for i in d['items'])=={'lux','gpt'}]
print('luxury sales:',len(lux),' with 1 luxury:',sum(1 for d in lux if sum(i[3]=='lux' for i in d['items'])==1))
# pairs: how many distinct partner pairs trade per game
pp=collections.Counter()
for d in deals: pp[(d['g'],frozenset([d['items'][0][1],d['items'][0][2]]))]+=1
v=sorted(pp.values()); print('deals per trading pair over a game: median',v[len(v)//2],' p90',v[int(.9*len(v))],' max',v[-1])
