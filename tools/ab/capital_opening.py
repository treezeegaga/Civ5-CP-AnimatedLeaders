"""Capital build orders through T50 for our aggressors (first games), against the user's reference opening."""
import sys,os,glob,re,csv,collections,statistics as st
sys.path.insert(0,'tools/ab'); sys.argv=['x']
import attack_funnel as af
games=af.games_from_csvs()
CITIES={}
for f in glob.glob('tools/ab/results/AIABTest_*.csv'):
    for r in csv.DictReader(open(f,encoding='utf-8-sig')):
        if r.get('Role')=='aggressor' and len(r['GameId'])==16 and r['Turn'] in ('50','60'):
            CITIES[(r['GameId'],r['Turn'])]=int(r['Cities'] or 0)
UNITS=set()
MIL=('MilitaryMelee','MilitaryRanged','MilitaryMounted','MilitarySiege','MilitaryNaval')
for f in glob.glob('tools/ab/results/logs_*/CityStrategyAIProductionLog.csv')[:40]:
    for l in open(f,errors='replace'):
        m=re.search(r'CHOSEN: (Military\w+), ([^,]+),',l)
        if m: UNITS.add(m.group(2))
UNITS-= {'Scout'}
rows=[]
for gdir in sorted(glob.glob('tools/ab/results/logs_*')):
    gid=os.path.basename(gdir)[5:]; info=games.get(gid)
    if not info or len(gid)!=16: continue
    path=os.path.join(gdir,'CityStrategyAIProductionLog.csv')
    if not os.path.exists(path): continue
    ours=af.log_name_matches(info['civ']); cap=None; seq=[]; allcity=collections.Counter()
    for l in open(path,errors='replace'):
        p=l.rstrip('\n').split(', ')
        if len(p)<4 or not p[0].isdigit() or not ours(p[1]): continue
        t=int(p[0])
        if t>50: break
        if cap is None: cap=p[2]
        m=re.search(r'CHOSEN: (\w+), ([^,]+),',l)
        if not m: continue
        cat,name=m.group(1),m.group(2)
        kind='mil' if cat in MIL else ('settler' if name=='Settler' else ('worker' if name in ('Worker','Work Boat') else ('bld' if cat in ('Building','Wonder') or 'Building' in cat else cat)))
        if name=='Scout': kind='scout'
        allcity[kind]+=1
        if p[2]==cap: seq.append((t,kind,name))
    # the opening book's starts (CitySpecializationLog) come before CP's own choices
    book=[]
    for l in open(os.path.join(gdir,'CitySpecializationLog.csv'),errors='replace'):
        p=l.rstrip('\n').split(', ',3)
        if len(p)<4 or not p[0].isdigit() or not ours(p[1]) or int(p[0])>50: continue
        m=re.search(r'OPENING BOOK - Started (.+)$',p[3])
        if m and (cap is None or p[2]==cap):
            cap=cap or p[2]; n=m.group(1).strip()
            k='settler' if n=='Settler' else ('worker' if n in ('Worker','Work Boat') else ('scout' if n=='Scout' else ('mil' if n in UNITS else 'bld')))
            book.append((int(p[0]),k,n))
    seq=sorted(book+seq)
    if not seq or not book or seq[0][0]>5: continue   # the book logged from turn 0 (complete openings only)
    # a choice is re-made when the city switches; count distinct consecutive choices
    ded=seq
    c=collections.Counter(k for t,k,n in ded)
    first_set=next((t for t,k,n in ded if k=='settler'),None)
    first_mil=next((t for t,k,n in ded if k=='mil'),None)
    rows.append(dict(gid=gid[:8],civ=info['civ'].title(),build=info['build'],capt=info['captured'],mil=c['mil'],set=c['settler'],bld=c['bld'],wk=c['worker'],
        scout=c['scout'],first_set=first_set,first_mil=first_mil,cities50=CITIES.get((gid,'50')),allmil=allcity['mil'],order=[n for t,k,n in ded][:12]))
print('aggressor first games with a production log:',len(rows))
for k in ('mil','set','bld','wk','scout','allmil'):
    v=[r[k] for r in rows]; print('  capital %-6s choices by T50: median %s (min %s, max %s)'%(k,st.median(v),min(v),max(v)))
fs=[r['first_set'] for r in rows if r['first_set']]; fm=[r['first_mil'] for r in rows if r['first_mil']]
print('  first settler chosen in the capital: median T%s (%d of %d games); first military: median T%s'%(st.median(fs),len(fs),len(rows),st.median(fm)))
c50=[r['cities50'] for r in rows if r['cities50'] is not None]
print('  cities at T50: median %s (min %s, max %s)'%(st.median(c50),min(c50),max(c50)))
print('  capital military choices by T50 vs captures: ')
for lo,hi in ((0,3),(3,5),(5,8),(8,99)):
    L=[r for r in rows if lo<=r['mil']<hi]; print('    %d-%s: %d games, captured in %d'%(lo,hi-1 if hi<99 else '+',len(L),sum(r['capt']>0 for r in L)))
print('  by cities at T50:')
for lo,hi in ((0,3),(3,4),(4,5),(5,99)):
    L=[r for r in rows if r['cities50'] is not None and lo<=r['cities50']<hi]; print('    %d-%s: %d games, captured in %d'%(lo,hi-1 if hi<99 else '+',len(L),sum(r['capt']>0 for r in L)))
uu=[r for r in rows if r['civ'] in ('Aztec','Zulu','Huns','Mongol','Mongolia','Songhai','Assyria','Celts','Inca')]
print('  examples:')
for r in rows[-8:]: print('   ',r['gid'],r['civ'],r['build'],'capt',r['capt'],'cities50',r['cities50'],'|',', '.join(r['order']))
