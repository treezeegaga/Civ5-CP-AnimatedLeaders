"""What an early-spike aggressor's units do before its build-up window (first games): explore, garrison, fortify, hunt."""
import sys,os,glob,re,collections,statistics as st
sys.path.insert(0,'tools/ab'); sys.argv=['x']
import attack_funnel as af, walls
games=af.games_from_csvs()
Q={'AZTEC','POLYNESIA','BABYLON','INCA','MAYA','GREECE','PERSIA','CELTS','HUNS','EGYPT','INDIA'}
rows=[]
for gdir in sorted(glob.glob('tools/ab/results/logs_*')):
    gid=os.path.basename(gdir)[5:]; info=games.get(gid)
    if not info or len(gid)!=16: continue
    ours=af.log_name_matches(info['civ'])
    tl=list(walls.our_lines(os.path.join(gdir,'PlayerTacticalAILog.csv'),ours))
    w0=next((t for t,r in tl if 'window opens' in r),None)
    if w0 is None: continue
    c=collections.Counter()
    for t,r in tl:
        if t>=w0: break
        if 'Trying to remove barbarian camp' in r: c['camp attempts']+=1
        elif 'opportunity attack' in r: c['opportunity attacks']+=1
        elif r.startswith('KilledInCombat'): c['own units killed']+=1
        elif r.startswith('BarbKill:'):   # logged from ai/war 728495a5 on
            c['barbarian kills']+=1
            m=re.search(r'level (\d+)',r)
            if m: c['kills by a unit already promoted']+=int(m.group(1))>1
    for t,r in walls.our_lines(os.path.join(gdir,'PlayerHomelandAILog.csv'),ours):
        if t>=w0: break
        if re.match(r'(\w[\w ]*?) Explored to target',r) and not r.startswith('Scout'): c['military unit-turns exploring']+=1
        elif 'to garrison' in r: c['garrison moves']+=1
        elif 'Fortif' in r or 'Sentry' in r or 'fortif' in r: c['fortify/sentry']+=1
        elif 'patrol' in r.lower(): c['patrol']+=1
    rows.append((info['civ'] in Q,info['civ'],w0,c,info['captured']))
for q in (True,False):
    R=[r for r in rows if r[0]==q]
    print('%s aggressors: %d games, window opens median T%s'%('early-spike' if q else 'other',len(R),st.median([r[2] for r in R])))
    keys=sorted({k for r in R for k in r[3]})
    for k in keys:
        v=[r[3][k] for r in R]; print('   %-32s median %s, mean %.1f, games with any %d'%(k,st.median(v),sum(v)/len(v),sum(1 for x in v if x)))
