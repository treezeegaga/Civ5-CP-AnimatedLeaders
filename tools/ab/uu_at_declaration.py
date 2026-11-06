"""Capture rate by whether the aggressor's unique unit was buildable at its first declaration (first games)."""
import sys,os,glob,re,csv,collections,statistics as st
sys.path.insert(0,'tools/ab'); sys.argv=['x']
import attack_funnel as af
games=af.games_from_csvs()
# unique units: unit names that only one civ ever lists as buildable (PRE lines), over every production log
who=collections.defaultdict(set)
for f in glob.glob('tools/ab/results/logs_*/CityStrategyAIProductionLog.csv'):
    for l in open(f,errors='replace'):
        p=l.split(', ')
        if len(p)>4 and p[3].startswith('PRE: Unit'):
            who[p[4]].add(p[1].lower().replace('the ','').replace('_',' ').strip()[:5])
UU={u:list(c)[0] for u,c in who.items() if len(c)==1}
civuu=collections.defaultdict(list)
for u,c in UU.items(): civuu[c].append(u)
G=collections.defaultdict(dict)
for f in glob.glob('tools/ab/results/AIABTest_*.csv'):
    for r in csv.DictReader(open(f,encoding='utf-8-sig')):
        if r.get('Role')=='aggressor' and len(r['GameId'])==16: G[r['GameId']][int(r['Turn'] or 0)]=r
rows=[]
for gdir in sorted(glob.glob('tools/ab/results/logs_*')):
    gid=os.path.basename(gdir)[5:]; info=games.get(gid)
    if not info or len(gid)!=16 or gid not in G: continue
    wt=[t for t in sorted(G[gid]) if (G[gid][t].get('WarsDeclared') or '0') not in ('','0')]
    if not wt: continue
    d=wt[0]; ours=af.log_name_matches(info['civ']); stem=info['civ'].lower()[:5]
    uus=next((v for k,v in civuu.items() if k[:4]==stem[:4]),[])
    first=None; inarmy=None
    for l in open(os.path.join(gdir,'CityStrategyAIProductionLog.csv'),errors='replace'):
        p=l.split(', ')
        if len(p)>4 and p[3].startswith('PRE: Unit') and p[4] in uus and ours(p[1]):
            first=int(p[0]); break
    for l in open(os.path.join(gdir,'PlayerTacticalAILog.csv'),errors='replace'):
        p=l.split(',',2)
        if len(p)==3 and ours(p[1]) and 'army at the declaration on' in p[2]:
            inarmy=any(u in p[2] for u in uus); break
    rows.append(dict(gid=gid[:8],civ=info['civ'],uus=uus,first=first,decl=d,avail=first is not None and first<=d,capt=info['captured'],inarmy=inarmy))
print('unique units found for %d civs, e.g.'%len(civuu),dict(list(civuu.items())[:6]))
print('first games at war with logs:',len(rows),'| civs without a unique unit found:',sorted({r['civ'] for r in rows if not r['uus']}))
for label,L in (('UU buildable by the first declaration',[r for r in rows if r['avail']]),('UU not yet buildable',[r for r in rows if r['uus'] and not r['avail']]),('no UU found',[r for r in rows if not r['uus']])):
    print('  %-38s %3d games, captured in %2d (%d%%), cities %d'%(label,len(L),sum(r['capt']>0 for r in L),100*sum(r['capt']>0 for r in L)//max(1,len(L)),sum(r['capt'] for r in L)))
A=[r for r in rows if r['inarmy'] is not None]
for v in (True,False):
    L=[r for r in A if r['inarmy']==v]
    print('  UU in the army at the declaration = %-5s (army line games): %d games, captured in %d'%(v,len(L),sum(r['capt']>0 for r in L)))
lag=[r['decl']-r['first'] for r in rows if r['first'] is not None]
for lo,hi in ((-99,0),(0,20),(20,40),(40,999)):
    L=[r for r in rows if r['first'] is not None and lo<=r['decl']-r['first']<hi]
    print('  declared %s to %s turns after the UU became buildable: %d games, captured in %d'%(lo,hi,len(L),sum(r['capt']>0 for r in L)))
print('  first declaration minus the UU becoming buildable: median %s turns'%(st.median(lag) if lag else '-'))
