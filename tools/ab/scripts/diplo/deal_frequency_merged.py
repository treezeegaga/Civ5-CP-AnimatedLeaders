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
deals=[d for d in deals if d['g'] in span]
civturns=sum(len(civs[g])*(span[g][1]-span[g][0]+1) for g in span)/10
info={(r[0],r[1],i):r for i,r in enumerate(rows)}
ds=sorted(deals,key=lambda d:(d['g'],d['t']))
assert len(ds)==len(rows)
# same pair, other luxury sale active (different luxury) at the time of a new luxury sale
active=collections.defaultdict(list); concurrent=0; nl=0
for d,r in zip(ds,rows):
    if r[2]!='luxury sale (for GPT)': continue
    pr=frozenset([d['items'][0][1],d['items'][0][2]]); key=(d['g'],pr)
    lx=[i[4] for i in d['items'] if i[3]=='lux']
    live=[x for x in active[key] if d['t']-x[0]<25 and x[1]!=lx]
    nl+=1; concurrent+= bool(live)
    active[key].append((d['t'],lx))
print(f'luxury sales made while the same pair already had another luxury deal running: {concurrent} of {nl} ({100*concurrent/nl:.0f}%)')
# merged count: one "trade event" per pair per 5-turn window, excluding renewals and embassies
ev=set(); n_new=0
for d,r in zip(ds,rows):
    if r[3] or r[2]=='embassy swap': continue
    n_new+=1
    pr=frozenset([d['items'][0][1],d['items'][0][2]])
    ev.add((d['g'],pr,d['t']//5))
print(f'new deals (no renewals, no embassies): {2*n_new/civturns:.2f} per civ per 10 turns; merged into one per pair per 5 turns: {2*len(ev)/civturns:.2f}')
# Deals column check against the CSV-based measure isn't needed: same counter.
