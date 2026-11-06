"""Early strike questions (the lead, from the user's human game): walls, siege, timing, barbarian hunting. First games only."""
import sys,os,glob,re,collections,statistics as st
sys.path.insert(0,'tools/ab'); sys.argv=['x']
import attack_funnel as af, walls
games=af.games_from_csvs()
SIEGE=re.compile(r'Catapult|Ballista|Trebuchet|Cannon|Hwacha|Artillery|Siege Tower|Battering Ram')
RP=re.compile(r'capture plan vs ([^,]+), agg \d+: .*?: (.*)$')
UNMATCHED=[0]
cities=[]   # one row per (game, city attacked with a logged defence)
gamerows=[]
for gdir in sorted(glob.glob('tools/ab/results/logs_*')):
    gid=os.path.basename(gdir)[5:]; info=games.get(gid)
    if not info or len(gid)!=16: continue
    s=walls.study(gdir,info)
    ours=af.log_name_matches(info['civ'])
    siege_in_plan=collections.Counter(); camps_before=0; decl=None; decl_army=None
    lines=list(walls.our_lines(os.path.join(gdir,'PlayerTacticalAILog.csv'),ours))
    for t,r in lines:
        m=re.search(r'army at the declaration on .+?: (\d+) land \((\d+) siege',r)
        if m and decl_army is None: decl_army=(t,int(m.group(1)),int(m.group(2)))
    for t,r in lines:
        m=RP.search(r)
        if m and SIEGE.search(m.group(2)): siege_in_plan[m.group(1)]+=1
    by=collections.defaultdict(list)
    for a in s['attempts']:
        if 'walls' in a: by[a['city']].append(a)
    # a city capture is logged as "Update: Enemy city captured": credit the city attempted last at or before that turn
    capt=set(); unmatched=0
    for t,r in walls.our_lines(os.path.join(gdir,'CitySpecializationLog.csv'),ours):
        if 'Update: Enemy city captured' in r:
            prev=[a for a in s['attempts'] if a['turn']<=t and a['turn']>=t-3]
            if prev: capt.add(max(prev,key=lambda a:a['turn'])['city'])
            else: unmatched+=1
    UNMATCHED[0]+=unmatched
    for c,L in by.items():
        L.sort(key=lambda a:a['turn'])
        cities.append(dict(gid=gid[:8],build=info['build'],civ=info['civ'],city=c,t0=L[0]['turn'],walled=L[0]['walls']>0,
            strength=L[0]['strength'],captured=c in capt or any(a['captured'] for a in L),n=len(L),siege=siege_in_plan[c]>0,
            decl_siege=decl_army[2] if decl_army else None))
    # barbarian camp attempts before the first declaration (CSV turn of first war, 10-turn resolution)
    gamerows.append((gid,info,lines,decl_army))
print('cities attacked with a logged defence:',len(cities),'in',len({c['gid'] for c in cities}),'games; captured',sum(c['captured'] for c in cities),'; captures with no attempt in the 3 turns before:',UNMATCHED[0])
def rate(L): return '%d/%d'%(sum(c['captured'] for c in L),len(L))
for w in (False,True):
    for sg in (False,True):
        L=[c for c in cities if c['walled']==w and c['siege']==sg]
        print('  walled %-5s siege in a plan %-5s: captured %s'%(w,sg,rate(L)))
print('  by first-attempt turn:')
for lo,hi in ((0,70),(70,90),(90,110),(110,130),(130,999)):
    L=[c for c in cities if lo<=c['t0']<hi]
    print('    T%d-%d: walled %d of %d; captured %s (unwalled %s, walled %s)'%(lo,hi,sum(c['walled'] for c in L),len(L),rate(L),
        rate([c for c in L if not c['walled']]),rate([c for c in L if c['walled']])))
L=[c for c in cities if c['decl_siege'] is not None]
print('  games with a declaration army line, by siege at the declaration (cities attacked):')
for lo,hi in ((0,1),(1,2),(2,3),(3,99)):
    M=[c for c in L if lo<=c['decl_siege']<hi]
    print('    siege %d%s: %s (unwalled %s, walled %s)'%(lo,'+' if hi==99 else '',rate(M),rate([c for c in M if not c['walled']]),rate([c for c in M if c['walled']])))
print('  city strength at the first attempt, captured vs not: median %s vs %s'%(
    st.median([c['strength'] for c in cities if c['captured']] or [0]),st.median([c['strength'] for c in cities if not c['captured']] or [0])))
