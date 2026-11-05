import sys,os,glob,re,collections
sys.path.insert(0,'tools/ab'); sys.argv=['x']
import attack_funnel as af
games=af.games_from_csvs()
tot=collections.Counter()
for gdir in sorted(glob.glob('tools/ab/results/logs_*')):
    gid=os.path.basename(gdir)[5:]; info=games.get(gid)
    if not info or info['build'] not in ('bullyabort14','bullygreedy16'): continue
    ours=af.log_name_matches(info['civ'])
    win=[];decl=[];scrap=[];army={}
    for l in open(os.path.join(gdir,'PlayerTacticalAILog.csv'),errors='replace'):
        p=l.split(',',2)
        if len(p)<3 or not p[0].strip().isdigit() or not ours(p[1]): continue
        t=int(p[0]); r=p[2]
        if 'window opens' in r: win.append([t,999])
        if ('at war, window closed' in r or 'back to the peace army' in r) and win and win[-1][1]==999: win[-1][1]=t
        m=re.search(r'WarBudget: army (at the declaration on .+?|at the first capture attempt on [^(]+|in the window \(turn \d+\)): (\d+) land \((\d+) siege',r)
        if m and 'declaration' in m.group(1): decl.append((t,int(m.group(2))))
        if m and 'capture' in m.group(1): army.setdefault('first capture',(t,int(m.group(2))))
        m=re.search(r'ArmyScrap: dropping (.+?) at .*gold (-?\d+)',r)
        if m: scrap.append((t,m.group(1),int(m.group(2))))
    d0=decl[0][0] if decl else 999
    ph=lambda t:'war' if t>=d0 else ('window' if any(a<=t<b for a,b in win) else 'attack/other')
    c=collections.Counter(ph(t) for t,_,_ in scrap); tot.update(c)
    kind='flip' if len(gid)==17 else 'first'
    print(gid[:8],kind,info['build'],info['civ'].title(),'capt',info['captured'],'| decl',decl[:2],'| first capture',army.get('first capture'),'| scraps',dict(c),[(t,u) for t,u,g in scrap][:12])
print('total',dict(tot))
