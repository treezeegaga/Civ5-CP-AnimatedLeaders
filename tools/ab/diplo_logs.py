import sys, csv, collections, re, os
base = sys.argv[1]
games = ['02DEF5BF','02EA597F','02F5C9E3']
def clean(x): return x.strip().replace('*','')
for g in games:
    d = os.path.join(base, f'logs_{g}{g}')
    rows = []
    with open(os.path.join(d,'DiplomacyAI_Log.csv'), encoding='latin-1') as f:
        for line in f:
            p = [x.strip() for x in line.split(',')]
            if len(p) < 19 or not p[17].startswith('W_THT') or p[3].startswith('---'): continue
            rows.append(dict(turn=int(p[0]), obs=p[1], tgt=p[3], den=p[5], war=p[6]=='AT WAR', cw=p[7],
                app=clean(p[8]), opn=clean(p[9]).replace('OPN ',''), prx=p[10].replace('PRX ',''),
                wst=p[11].replace('WST ',''), estr=clean(p[12]).replace('ESTR ',''), mstr=clean(p[13]).replace('MSTR ',''),
                tgtv=clean(p[14]).replace('TGT ',''), wth=clean(p[17]).replace('W_THT ','')))
    print(f'===== game {g}: {len(rows)} major-pair rows, turns {min(r["turn"] for r in rows)}-{max(r["turn"] for r in rows)}')
    peace = [r for r in rows if not r['war']]
    c = collections.Counter(r['app'] for r in peace)
    tot = sum(c.values())
    print(' approach at peace:', ', '.join(f'{k} {v*100/tot:.1f}%' for k,v in c.most_common()))
    print(' warmonger threat (pair-turns):', dict(collections.Counter(r['wth'] for r in rows)))
    mx = {}
    for r in rows:
        lv = ['NONE','MINOR','MAJOR','SEVERE','CRITICAL'].index(r['wth']) if r['wth'] in ['NONE','MINOR','MAJOR','SEVERE','CRITICAL'] else -1
        k=(r['obs'],r['tgt']); mx[k]=max(mx.get(k,-1),lv)
    print(' pairs whose threat ever reached MAJOR+:', sum(1 for v in mx.values() if v>=2), ' SEVERE+:', sum(1 for v in mx.values() if v>=3), 'of', len(mx))
    af = [r for r in peace if r['app']=='AFRAID']
    print(' AFRAID pair-turns at peace:', len(af), ' with target MSTR:', dict(collections.Counter(r['mstr'] for r in af)), ' opinion:', dict(collections.Counter(r['opn'] for r in af)))
    afp = collections.Counter((r['obs'],r['tgt']) for r in af)
    print(' AFRAID pairs (turns):', afp.most_common(8))
    hostile_opn = [r for r in peace if r['opn'] in ('ENEMY','UNFORGIVABLE')]
    print(' at-peace pair-turns with opinion ENEMY/UNFORGIVABLE:', len(hostile_opn), ' their approaches:', dict(collections.Counter(r['app'] for r in hostile_opn)), ' MSTR:', dict(collections.Counter(r['mstr'] for r in hostile_opn)))
    # easy-target proxy
    weak = ('PATHETIC','WEAK','POOR','Pathetic','Weak','Poor')
    good = ('Favorable','Easy','Soft','Cakewalk','FAVORABLE','EASY','SOFT','CAKEWALK')
    near = ('Neighbors','Close')
    obs_atwar = collections.defaultdict(set)
    for r in rows:
        if r['war']: obs_atwar[(r['obs'],r['turn'])].add(r['tgt'])
    cand = [r for r in peace if r['mstr'] in weak and r['tgtv'] in good and r['prx'] in near]
    print(' easy-target proxy (at peace, close, weaker, target value favourable+): pair-turns', len(cand), ' pairs', len(set((r['obs'],r['tgt']) for r in cand)))
    print('   approaches then:', dict(collections.Counter(r['app'] for r in cand)), ' obs already at war elsewhere:', sum(1 for r in cand if obs_atwar[(r['obs'],r['turn'])]))
    # wars declared (pair goes from peace to war)
    seen = {}
    starts = []
    for r in sorted(rows, key=lambda r:(r['turn'])):
        k=(r['obs'],r['tgt'])
        if r['war'] and seen.get(k) is False: starts.append((r['turn'],)+k)
        seen[k]=r['war']
    print(' wars started (pair, first turn at war):', starts[:20])
    # messages
    msgs = collections.Counter()
    with open(os.path.join(d,'DiplomacyAI_Messages_Log.csv'), encoding='latin-1') as f:
        for line in f:
            for key in ['Wanna team up','Wants','gift','Can you spare','Luxury I would like','Renew Deal','Open Borders','Defensive Pact Offer','DOF offer','DENOUNCED','3rd Party WAR','request peace','Strategic Resource','Embassy Exchange','Research']:
                if key in line: msgs[key]+=1
    print(' messages:', dict(msgs))
    deals = 0
    with open(os.path.join(d,'DiplomacyAI_TradeAgreements_Log.csv'), encoding='latin-1') as f:
        txt=f.read()
    print(' trade log: DEAL COMPLETE lines', txt.count('DEAL COMPLETE'))

print('\n=== easy-target candidate pairs, observer not at war elsewhere ===')
for g in games:
    d = os.path.join(base, f'logs_{g}{g}')
    rows=[]
    with open(os.path.join(d,'DiplomacyAI_Log.csv'), encoding='latin-1') as f:
        for line in f:
            p=[x.strip() for x in line.split(',')]
            if len(p)<19 or p[2]!='Diplomacy' or p[3].startswith('---'): continue
            rows.append((int(p[0]),p[1],p[3],p[6]=='AT WAR',clean(p[8]),clean(p[13]).replace('MSTR ',''),clean(p[14]).replace('TGT ',''),p[10].replace('PRX ',''),clean(p[12]).replace('ESTR ',''),clean(p[9]).replace('OPN ','')))
    atwar=collections.defaultdict(bool)
    for t,o,tg,w,*_ in rows:
        if w: atwar[(o,t)]=True
    pairs=collections.defaultdict(list)
    for t,o,tg,w,app,ms,tv,px,es,op in rows:
        if not w and not atwar[(o,t)] and ms.upper() in ('PATHETIC','WEAK','POOR') and tv.upper() in ('FAVORABLE','EASY','SOFT','CAKEWALK') and px in ('Neighbors','Close'):
            pairs[(o,tg)].append((t,app,ms,tv,es,op))
    print(g)
    for k,v in sorted(pairs.items(), key=lambda kv:-len(kv[1])):
        apps=collections.Counter(x[1] for x in v)
        print(f'  {k[0]} -> {k[1]}: {len(v)} turns T{v[0][0]}-T{v[-1][0]}, approaches {dict(apps)}, MSTR {collections.Counter(x[2] for x in v).most_common(1)[0][0]}, TGT {collections.Counter(x[3] for x in v).most_common(1)[0][0]}, ESTR {collections.Counter(x[4] for x in v).most_common(1)[0][0]}, OPN {collections.Counter(x[5] for x in v).most_common(1)[0][0]}')

print('\n=== WAR approach held at peace: turns, and whether war came ===')
for g in games:
    d = os.path.join(base, f'logs_{g}{g}')
    rows=[]
    with open(os.path.join(d,'DiplomacyAI_Log.csv'), encoding='latin-1') as f:
        for line in f:
            p=[x.strip() for x in line.split(',')]
            if len(p)<19 or p[2]!='Diplomacy' or p[3].startswith('---'): continue
            rows.append((int(p[0]),p[1],p[3],p[6]=='AT WAR',clean(p[8]),clean(p[13]).replace('MSTR ','')))
    warturn={}
    for t,o,tg,w,a,m in rows:
        if w and (o,tg) not in warturn: warturn[(o,tg)]=t
    held=collections.defaultdict(list)
    for t,o,tg,w,a,m in rows:
        if not w and a.startswith('WAR'): held[(o,tg)].append((t,m))
    print(g)
    for k,v in sorted(held.items(), key=lambda kv:-len(kv[1])):
        wt=warturn.get(k)
        after=[x for x in v if wt is None or x[0]<wt]
        print(f'  {k[0]} -> {k[1]}: WAR approach on {len(v)} peace turns (T{v[0][0]}-T{v[-1][0]}), MSTR {collections.Counter(x[1] for x in v).most_common(2)}; war {"declared/at war from T%d"%wt if wt else "never"}')
