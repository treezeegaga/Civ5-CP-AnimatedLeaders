import json, collections, os
D=25
deals=json.load(open('deals.json'))
# civs and turn span per game from the trade log + dip
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
def cat(d):
    ks=collections.Counter(i[3] for i in d['items'])
    s=set(ks)
    if 'peace' in s: return 'peace treaty'
    if s=={'emb'} or s=={'emb','gpt'}: return 'embassy swap'
    if s=={'other'}: return 'help request (gift)'
    if s=={'gold'}: return 'gold gift'
    if 'ra' in s: return 'research agreement'
    if 'dp' in s: return 'defensive pact'
    if 'strat' in s: return 'strategic resource'
    if 'lux' in s and 'ob' in s: return 'luxury + open borders'
    if 'lux' in s and ks['lux']>=2 and 'gpt' not in s: return 'luxury swap (lux for lux)'
    if 'lux' in s: return 'luxury sale (for GPT)'
    if s=={'ob'}: return 'open borders swap'
    if 'ob' in s: return 'open borders for GPT'
    return 'other: '+'+'.join(sorted(s))
def sig(d):
    return tuple(sorted((a,b,k,r if k!='gpt' else 'gpt') for t,a,b,k,r,v in d['items']))
last={}; rows=[]
for d in sorted(deals,key=lambda d:(d['g'],d['t'])):
    key=(d['g'],sig(d)); renew=False
    if key in last and D-1 <= d['t']-last[key] <= D+1: renew=True
    last[key]=d['t']
    rows.append((d['g'],d['t'],cat(d),renew))
civturns=sum(len(civs[g])*(span[g][1]-span[g][0]+1) for g in span)/10
tot=len(rows)*2
print(f'{len(span)} games, {len(rows)} deals; deals per civ per 10 turns (each deal counts for both civs, as the Deals column does): {tot/civturns:.2f}')
c=collections.Counter((r[2],r[3]) for r in rows); cc=collections.Counter(r[2] for r in rows)
print(f'  {"type":30s} {"per civ/10t":>11s} {"share":>6s} {"of which renewals":>18s}')
for k,n in cc.most_common():
    print(f'  {k:30s} {2*n/civturns:11.2f} {100*n/len(rows):5.1f}% {100*c[(k,True)]/n:16.0f}%')
ren=sum(1 for r in rows if r[3]); print(f'  renewals overall: {100*ren/len(rows):.0f}% of deals ({2*ren/civturns:.2f} per civ per 10 turns)')
# by phase
ph=collections.Counter(); phct=collections.Counter()
for g,t,k,rn in rows: ph[min(t//25,5)]+=1
for g in span:
    for t in range(span[g][0],span[g][1]+1): phct[min(t//25,5)]+=len(civs[g])
print('  by turn:', ', '.join(f'T{25*p}-{25*p+24}: {20*ph[p]/max(1,phct[p]):.2f}' for p in sorted(ph)))
# per game distribution
pg=collections.Counter(r[0] for r in rows)
v=sorted(2*pg[g]/(len(civs[g])*(span[g][1]-span[g][0]+1)/10) for g in span)
print(f'  per game: min {v[0]:.2f}, median {v[len(v)//2]:.2f}, max {v[-1]:.2f}')
json.dump(rows,open('dealrows.json','w'))
