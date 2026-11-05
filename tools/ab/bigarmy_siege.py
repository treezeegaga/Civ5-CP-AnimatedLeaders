import sys,os,glob,re,collections,statistics as st
sys.path.insert(0,'tools/ab'); sys.argv=['x']
import attack_funnel as af
games=af.games_from_csvs()
SIEGE=re.compile(r'Catapult|Ballista|Trebuchet|Cannon|Hwacha|Artillery|Siege Tower')
MIL=('MilitaryMelee','MilitaryRanged','MilitaryMounted','MilitarySiege')
rows=[]
for gdir in sorted(glob.glob('tools/ab/results/logs_*')):
    gid=os.path.basename(gdir)[5:]; info=games.get(gid)
    if not info or info['build'] not in ('bullyabort13','bullygreedy15') or len(gid)!=16: continue
    ours=af.log_name_matches(info['civ'])
    win=[];decl=[];notready=[]
    for t,line in ((int(l.split(',')[0]),l) for l in open(os.path.join(gdir,'PlayerTacticalAILog.csv'),errors='replace') if l[:3].isdigit()):
        p=line.split(',',2)
        if len(p)<3 or not ours(p[1]): continue
        r=p[2]
        if 'window opens' in r: win.append([t,None])
        if ('at war, window closed' in r or 'back to the peace army' in r) and win and win[-1][1] is None: win[-1][1]=t
        m=re.search(r'army at the declaration on (.+?): (\d+) land \((\d+) siege',r)
        if m: decl.append((t,int(m.group(2)),int(m.group(3)),m.group(1)))
    math=None; inwin=lambda t:any(a<=t<=(b if b is not None else 999) for a,b in win)
    ch=collections.Counter(); rank=[]; seen=set()
    cur=collections.defaultdict(dict)
    for l in open(os.path.join(gdir,'CityStrategyAIProductionLog.csv'),errors='replace'):
        p=l.rstrip('\n').split(', ')
        if len(p)<4 or not ours(p[1]): continue
        t=int(p[0])
        if 'PRE: Unit' in p[3] and math is None and SIEGE.search(p[4] if len(p)>4 else ''): math=t
        if not inwin(t): continue
        if p[3].startswith('POST: Unit') and len(p)>5:
            cur[(t,p[2])][p[4]]=int(p[5])
        if 'CHOSEN:' in l:
            m=re.search(r'CHOSEN: (\w+), ([^,]+),',l)
            if m and m.group(1) in MIL:
                ch['siege' if SIEGE.search(m.group(2)) else 'land']+=1
                if SIEGE.search(m.group(2)): ch['siege '+m.group(2)]+=1
                else: ch['land '+m.group(2)]+=1
            elif m: ch['other '+m.group(1)]+=1
    # rank of best siege among unit POST weights per city-turn
    for k,d in cur.items():
        s=[w for n,w in d.items() if SIEGE.search(n)]
        if s:
            rank.append(sorted(d.values(),reverse=True).index(max(s))+1)
    rows.append(dict(gid=gid[:8],civ=info['civ'].title(),capt=info['captured'],win=win,decl=decl,math=math,ch=ch,rank=rank))
for r in rows:
    d=r['decl'][0] if r['decl'] else None
    w0=r['win'][0][0] if r['win'] else None
    print('%s %-10s capt %d | win %s | math T%s | decl %s | window choices: siege %d land %d other %d | siege POST rank median %s (n %d)'%(
        r['gid'],r['civ'],r['capt'],[(a,b) for a,b in r['win']],r['math'],('T%d %d land %d siege'%d[:3]) if d else '-',
        r['ch']['siege'],r['ch']['land'],sum(v for k,v in r['ch'].items() if k.startswith('other ')),
        st.median(r['rank']) if r['rank'] else '-',len(r['rank'])))
tot=collections.Counter()
for r in rows: tot.update(r['ch'])
print({k:v for k,v in tot.most_common(25)})
