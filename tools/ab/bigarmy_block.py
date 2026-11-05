import sys,os,glob,re,collections,statistics as st
sys.path.insert(0,'tools/ab'); sys.argv=['x']
import attack_funnel as af, walls
games=af.games_from_csvs()
GRP={'bullyabort11':'f6d1e84','bullygreedy13':'f6d1e84','bullyabort12':'850e142','bullygreedy14':'850e142','bullyabort13':'BigArmy','bullygreedy15':'BigArmy'}
RP=re.compile(r"capture plan vs (\S+), agg (\d+): (\d+) units in the sim, (\d+) in the plan, (\d+) attacks \((\d+) on the city\)")
out=collections.defaultdict(lambda: collections.defaultdict(list))
for gdir in sorted(glob.glob('tools/ab/results/logs_*')):
    gid=os.path.basename(gdir)[5:]; info=games.get(gid)
    if not info or info['build'] not in GRP: continue
    kind='flip' if len(gid)==17 else 'first'
    A=out[(GRP[info['build']],kind)]
    stage,sig,ends=af.classify(gdir,info); s=walls.study(gdir,info)
    A['games'].append(gid[:8]); A['capt'].append(info['captured']); A['war'].append(info['wars']>0); A['stage'].append(stage)
    A['handed'].append(sum(1 for o in s['ops'].values() if o['units'] and o['near'] is not None))
    A['att']+=[a['hp0']-a['hp1'] for a in s['attempts']]
    A['pill'].append(s['loot']['pillages']); A['pgold'].append(s['loot']['pillage gold']); A['plgold'].append(s['loot']['plunder gold'])
    ours=af.log_name_matches(info['civ'])
    for t,r in walls.our_lines(os.path.join(gdir,'PlayerTacticalAILog.csv'),ours):
        m=re.search(r'(?:BigArmy|WarBudget): army at the declaration on .+?: (\d+) land \((\d+) siege; target (\d+) siege, (\d+) others',r)
        if m: A['decl'].append(tuple(map(int,m.groups())))
        m=re.search(r'BigArmy: upkeep waived (\d+) \(phase 5',r)
        if m: A['waivedwar'].append(int(m.group(1)))
        m=RP.search(r)
        if m and int(m.group(2))>=2: A['plans'].append((int(m.group(3)),int(m.group(6))))
for key in sorted(out):
    A=out[key]; n=len(A['games'])
    sc=collections.Counter(A['stage'])
    print('==',key,n,'games | captured in',sum(c>0 for c in A['capt']),'games,',sum(A['capt']),'cities | war in',sum(A['war']),'| stages',', '.join('%s %d'%(af.STAGES[i],sc[i]) for i in sorted(sc)))
    print('   delivered %.1f a game (2+: %d)'%(st.mean(A['handed']),sum(x>=2 for x in A['handed'])))
    if A['att']: print('   attempts %d (%.1f a game), city lost HP %d%%, mean %.1f'%(len(A['att']),len(A['att'])/n,100*sum(x>0 for x in A['att'])/len(A['att']),st.mean(A['att'])))
    if A['plans']: print('   capture plans %d: sim median %s, with a city attack %d%%'%(len(A['plans']),st.median([p[0] for p in A['plans']]),100*sum(p[1]>0 for p in A['plans'])/len(A['plans'])))
    if A['decl']:
        d=A['decl']; print('   declarations %d: land median %s (target siege+others median %s), siege median %s, ready (both met) %d'%(len(d),st.median([x[0] for x in d]),st.median([x[2]+x[3] for x in d]),st.median([x[1] for x in d]),sum(1 for x in d if x[1]>=x[2] and x[0]-x[1]>=x[3])))
    if A['waivedwar']: print('   upkeep waived at war: median %s a turn over %d turns'%(st.median(A['waivedwar']),len(A['waivedwar'])))
    print('   pillages %.1f a game, pillage gold %.0f a game, plunder gold %.0f a game'%(st.mean(A['pill']),st.mean(A['pgold']),st.mean(A['plgold'])))
