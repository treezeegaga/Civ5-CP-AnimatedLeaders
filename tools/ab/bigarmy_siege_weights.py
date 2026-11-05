import sys,os,glob,re,collections,statistics as st
sys.path.insert(0,'tools/ab'); sys.argv=['x']
import attack_funnel as af
games=af.games_from_csvs()
SIEGE=re.compile(r'Catapult|Ballista|Trebuchet|Cannon|Hwacha|Artillery')
skip=collections.Counter(); top=collections.Counter(); gap=[]; n=0
for gdir in sorted(glob.glob('tools/ab/results/logs_*')):
    gid=os.path.basename(gdir)[5:]; info=games.get(gid)
    if not info or info['build'] not in ('bullyabort13','bullygreedy15') or len(gid)!=16: continue
    ours=af.log_name_matches(info['civ']); win=[]
    for l in open(os.path.join(gdir,'PlayerTacticalAILog.csv'),errors='replace'):
        p=l.split(',',2)
        if len(p)<3 or not p[0].strip().isdigit() or not ours(p[1]): continue
        t=int(p[0]); r=p[2]
        if 'window opens' in r: win.append([t,999])
        if ('at war, window closed' in r or 'back to the peace army' in r) and win and win[-1][1]==999: win[-1][1]=t
    inwin=lambda t:any(a<=t<=b for a,b in win)
    post=collections.defaultdict(dict)
    for l in open(os.path.join(gdir,'CityStrategyAIProductionLog.csv'),errors='replace'):
        p=l.rstrip('\n').split(', ')
        if len(p)<6 or not ours(p[1]) or not inwin(int(p[0])): continue
        if p[3].startswith('SKIPPED: Unit') and SIEGE.search(p[4]): skip[p[5]]+=1
        if p[3].startswith('POST: Unit'): post[(p[0],p[2])][p[4]]=int(p[5])
    for k,d in post.items():
        s=[w for u,w in d.items() if SIEGE.search(u)]
        if not s: top['no siege in POST']+=1; continue
        best=max(d.items(),key=lambda x:x[1]); n+=1
        if SIEGE.search(best[0]): top['siege first']+=1
        else: top['first: '+best[0]]+=1; gap.append(100*max(s)//best[1])
print('siege SKIPPED reasons in the window:',dict(skip))
print('city-turns',n,dict(top.most_common(12)))
print('siege weight as % of the top unit when not first: median',st.median(gap),'p25',sorted(gap)[len(gap)//4],'p75',sorted(gap)[3*len(gap)//4])
