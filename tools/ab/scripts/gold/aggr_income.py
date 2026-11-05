import re,glob,os,sys,statistics as st
from collections import defaultdict
SEED=re.compile(r'^(\d+), ([^,]+), ([^,]+), SEED: \d+, CHOSEN: ([^,]+), ([^,]+), .*GPT: (-?\d+)')
GOLDB={'Market','Mint','Bank','Caravansary','Harbor','Colossus','Petra','Machu Picchu','Great Lighthouse','Stock Exchange'}
TR=re.compile(r'^(\d+), (\S+), Establishing (\w+) trade route')
rows=[]
for root in sys.argv[1:]:
  for d in sorted(glob.glob(root+'/logs_*')):
    tac=d+'/PlayerTacticalAILog.csv'; pr=d+'/CityStrategyAIProductionLog.csv'; hm=d+'/PlayerHomelandAILog.csv'
    if not (os.path.exists(tac) and os.path.exists(pr)): continue
    ag=None
    for l in open(tac,encoding='latin-1'):
        m=re.match(r'^\d+, (\S+), (WarBudget|BigArmy|TimingBuildup):',l)
        if m: ag=m.group(1).replace('_',' '); break
    if not ag: continue
    sp=d+'/StrategyProfile_Log.csv'
    majors=set(l.split(', ')[1] for l in open(sp,encoding='latin-1') if l.startswith('001, ')) if os.path.exists(sp) else None
    gpt=defaultdict(dict); gb=defaultdict(lambda: defaultdict(int)); car=defaultdict(lambda: defaultdict(int)); cities=defaultdict(lambda: defaultdict(set))
    for l in open(pr,encoding='latin-1'):
        m=SEED.match(l)
        if not m: continue
        t,civ,city,kind,item,g=int(m.group(1)),m.group(2),m.group(3),m.group(4),m.group(5),int(m.group(6))
        for T in (30,40,50,75,100):
            if t<=T: gpt[civ][T]=g; cities[civ][T].add(city)
            if t<=T and item in GOLDB: gb[civ][T]+=1
            if t<=T and item in ('Caravan','Cargo Ship'): car[civ][T]+=1
    trs=defaultdict(lambda: defaultdict(int))
    if os.path.exists(hm):
        for l in open(hm,encoding='latin-1'):
            m=TR.match(l)
            if m:
                t=int(m.group(1)); civ=m.group(2).replace('_',' ')
                for T in (30,40,50,75,100):
                    if t<=T: trs[civ][T]+=1
    for civ in gpt:
        if majors is not None and civ not in majors: continue
        rows.append((os.path.basename(root),os.path.basename(d),civ,civ==ag,{T:(gpt[civ].get(T),len(cities[civ][T]),gb[civ][T],car[civ][T],trs[civ][T]) for T in (30,40,50,75,100)}))
def summ(sel,label):
    print(label, 'civ-games', len(sel))
    for T in (30,40,50,75,100):
        v=[r[4][T] for r in sel if r[4][T][0] is not None]
        if not v: continue
        print('  T%d: net gold/turn median %s (mean %.1f), cities %.1f, gold buildings chosen %.1f, caravans/cargo chosen %.1f, trade routes set up %.1f'%(
            T, st.median([x[0] for x in v]), st.mean([x[0] for x in v]), st.mean([x[1] for x in v]), st.mean([x[2] for x in v]), st.mean([x[3] for x in v]), st.mean([x[4] for x in v])))
for setname in sorted(set(r[0] for r in rows)):
    sub=[r for r in rows if r[0]==setname]
    print('==',setname, len(set(r[1] for r in sub)),'games')
    summ([r for r in sub if r[3]],' aggressor')
    summ([r for r in sub if not r[3]],' others   ')
