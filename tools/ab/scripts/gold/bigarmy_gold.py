import re,glob,os,sys,statistics as st
root=sys.argv[1]
W=re.compile(r'^(\d+), (\S+), BigArmy: upkeep waived (-?\d+) \(phase (\d), gold (-?\d+), (-?\d+) a turn\)')
A=re.compile(r'^(\d+), (\S+), BigArmy: army in the window \(turn (\d+)\): (\d+) land \((\d+) siege')
P=re.compile(r'^(\d+), (\S+), (Pillage|Plunder) gold: (\d+)')
rows=[]
for d in sorted(glob.glob(root+'/logs_*')):
    g=os.path.basename(d)[5:]
    tac=open(d+'/PlayerTacticalAILog.csv',encoding='latin-1').read().splitlines()
    ws=[W.match(l) for l in tac]; ws=[m for m in ws if m]
    if not ws: print(g,'no BigArmy lines'); continue
    civ=ws[0].group(2)
    ws=[m for m in ws if m.group(2)==civ]
    arm=[A.match(l) for l in tac]; arm=[m for m in arm if m and m.group(2)==civ]
    pil=sum(int(m.group(4)) for m in (P.match(l) for l in tac) if m and m.group(2)==civ)
    hom=open(d+'/PlayerHomelandAILog.csv',encoding='latin-1').read().splitlines() if os.path.exists(d+'/PlayerHomelandAILog.csv') else []
    pil+=sum(int(m.group(4)) for m in (P.match(l) for l in hom) if m and m.group(2)==civ)
    t0=int(ws[0].group(1))
    buys=[]
    for l in hom:
        parts=l.split(', ',2)
        if len(parts)<3 or parts[1]!=civ or int(parts[0])<t0: continue
        m=re.search(r'(MOD - Buying unit: |MOD - Investing in \w+: |WAR CHEST - Bought |EXPANSION SETTLER - Bought|Buying plot)(.*?)(?:Cost: (\d+)| for (\d+) gold)?',parts[2])
        if m and ('Cost' in parts[2] or 'gold' in parts[2] or 'plot' in parts[2]):
            c=re.search(r'Cost: (\d+)|for (\d+) gold',parts[2])
            buys.append((parts[2][:50], int(c.group(1) or c.group(2)) if c else 0))
    ph={}
    for m in ws: ph.setdefault(int(m.group(4)),[]).append(m)
    def s(ms):
        X=[int(m.group(3)) for m in ms]; Y=[int(m.group(6)) for m in ms]
        return len(ms), st.mean(X), st.mean(Y), st.mean([y-x for x,y in zip(X,Y)])
    out=dict(game=g,civ=civ,t0=t0,tend=int(ws[-1].group(1)),gold0=int(ws[0].group(5)),goldend=int(ws[-1].group(5)),
             maxland=max([int(m.group(4)) for m in arm] or [0]),pillage=pil,buys=sum(c for _,c in buys),nbuys=len(buys),
             buylist=buys)
    for p in (3,4,5):
        if p in ph: out['p%d'%p]=s(ph[p])
    rows.append(out)
for r in rows:
    line='%s %-14s T%d-%d gold %d->%d land<=%d pillage %d buys %d (%d)'%(r['game'][:8]+('F' if r['game'].endswith('F') else ' '),r['civ'],r['t0'],r['tend'],r['gold0'],r['goldend'],r['maxland'],r['pillage'],r['buys'],r['nbuys'])
    for p,name in ((3,'window'),(4,'march'),(5,'war')):
        if 'p%d'%p in r:
            n,x,y,net=r['p%d'%p]; line+=' | %s %dt upkeep %.0f net %.0f real %.0f'%(name,n,x,y,net)
    print(line)
allm=[]
for p,name in ((3,'window'),(4,'march'),(5,'war')):
    ns=[r['p%d'%p] for r in rows if 'p%d'%p in r]
    if ns:
        T=sum(n for n,*_ in ns)
        print('%s: %d games, %d turns, upkeep %.1f, net-with-waiver %.1f, real net %.1f (turn-weighted)'%(name,len(ns),T,sum(n*x for n,x,y,z in ns)/T,sum(n*y for n,x,y,z in ns)/T,sum(n*z for n,x,y,z in ns)/T))
from collections import Counter
c=Counter()
for r in rows:
    for b,cost in r['buylist']: c[re.sub(r' in .*','',b)]+=cost
print(c.most_common(15))
print()
U=re.compile(r'^(\d+), (\S+), Upgrading unit from type')
for r in rows:
    d=root+'/logs_'+r['game']
    hom=open(d+'/PlayerHomelandAILog.csv',encoding='latin-1').read().splitlines()
    tac=open(d+'/PlayerTacticalAILog.csv',encoding='latin-1').read().splitlines()
    ws=[m for m in (W.match(l) for l in tac) if m and m.group(2)==r['civ']]
    inflow=sum(int(m.group(6)) for m in ws)  # net with waiver, summed over turns
    ups=sum(1 for l in hom+tac if (lambda m: m and m.group(2)==r['civ'] and int(m.group(1))>=r['t0'])(U.match(l)))
    other=inflow+r['pillage']-(r['goldend']-r['gold0'])-r['buys']
    print('%s %-12s net-with-waiver summed %5d + pillage %4d - treasury change %5d - logged buys %4d = other spending %5d ; upgrades %d'%(r['game'][:8],r['civ'],inflow,r['pillage'],r['goldend']-r['gold0'],r['buys'],other,ups))
print()
C=re.compile(r'^(\d+), (\S+), BigArmy: army at the first capture attempt on (\S+)')
for r in rows:
    d=root+'/logs_'+r['game']
    tac=open(d+'/PlayerTacticalAILog.csv',encoding='latin-1').read().splitlines()
    ws=[m for m in (W.match(l) for l in tac) if m and m.group(2)==r['civ']]
    cap=[m for m in (C.match(l) for l in tac) if m and m.group(2)==r['civ']]
    tw=[int(m.group(1)) for m in ws if m.group(4)=='5']
    tc=int(cap[0].group(1)) if cap else None
    def deficit(t1):
        return sum(int(m.group(3))-int(m.group(6)) for m in ws if t1 is None or int(m.group(1))<=t1)
    def wdeficit(t1):
        return sum(int(m.group(3))-int(m.group(6)) for m in ws if m.group(4)=='3')
    print('%s %-12s window T%d, war T%s, first capture attempt %s; real deficit: window %d, window to capture attempt %s, whole %d'%(
        r['game'][:8],r['civ'],r['t0'],tw[0] if tw else '-', 'T%d'%tc if tc else '-', wdeficit(None), deficit(tc) if tc else '-', deficit(None)))
