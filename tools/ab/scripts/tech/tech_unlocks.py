import re,glob,os,sys,statistics as st
from collections import defaultdict
root=sys.argv[1]
# what each item's first appearance in a city's PRE list says was researched (BNW tech tree, unchanged by CP)
UNLOCK={'Building, Library,':'Writing','Building, Market,':'Currency','Unit, Catapult,':'Mathematics',
 'Building, Colosseum,':'Construction','Building, Temple,':'Philosophy','Building, Amphitheater,':'Drama&Poetry',
 'Building, University,':'Education','Building, Aqueduct,':'Engineering','Unit, Pikeman,':'Civil Service',
 'Unit, Crossbowman,':'Machinery','Unit, Trebuchet,':'Physics','Building, Castle,':'Chivalry','Building, Garden,':'Theology',
 'Building, Bank,':'Banking','Building, Barracks,':'Bronze Working','Building, Caravansary,':'Horseback Riding',
 'Building, Workshop,':'Metal Casting','Building, Opera House,':'Acoustics','Building, Armory,':'Steel',
 'Unit, Composite Bowman,':'Construction','Building, Walls,':'Masonry','Unit, Archer,':'Archery','Building, Circus,':'Trapping',
 'Building, Shrine,':'Pottery','Unit, Chariot Archer,':'The Wheel','Building, Stone Works,':'Calendar'}
PURS={0:'domination',1:'diplomacy',2:'culture',3:'science'}
PRE=re.compile(r'^(\d+), ([^,]+), [^,]+, PRE: (Unit|Building) \d+, ([^,]+),')
data=[]
for d in sorted(glob.glob(root+'/logs_*')):
    sp=d+'/StrategyProfile_Log.csv'; pr=d+'/CityStrategyAIProductionLog.csv'
    if not (os.path.exists(sp) and os.path.exists(pr)): continue
    prof={}
    for l in open(sp,encoding='latin-1'):
        p=l.split(', ')
        if len(p)>5 and p[0]=='001':
            m=re.search(r'pursuits (-?\d+)/(-?\d+)',l)
            prof[p[1]]=(int(m.group(1)),int(m.group(2)),p[5])
    first=defaultdict(dict)
    for l in open(pr,encoding='latin-1'):
        m=PRE.match(l)
        if not m: continue
        t,civ,kind,item=int(m.group(1)),m.group(2),m.group(3),m.group(4)
        key='%s, %s,'%(kind,item)
        tech=UNLOCK.get(key)
        if tech and tech not in first[civ]: first[civ][tech]=t
    for civ,f in first.items():
        if civ in prof: data.append((os.path.basename(d),civ,prof[civ],f))
print('civ-games:',len(data))
techs=['Pottery','Archery','The Wheel','Bronze Working','Masonry','Writing','Calendar','Mathematics','Currency','Horseback Riding','Trapping','Philosophy','Construction','Drama&Poetry','Engineering','Metal Casting','Civil Service','Theology','Education','Machinery','Physics','Chivalry','Banking','Acoustics','Steel']
by=defaultdict(list)
for g,civ,(p1,p2,arch),f in data: by[PURS.get(p1,'?')].append(f)
print('median turn first available (share of civ-games that had it by T150)')
hdr='%-17s'%'tech'+''.join('%-16s'%k for k in ['domination','diplomacy','culture','science'])
print(hdr)
for t in techs:
    row='%-17s'%t
    for k in ['domination','diplomacy','culture','science']:
        v=[f[t] for f in by[k] if t in f]
        row+='%-16s'%(('%3d (%2d%%)'%(st.median(v),100*len(v)//max(1,len(by[k])))) if v else '-')
    print(row)
print({k:len(v) for k,v in by.items()})
# "off-path before on-path" checks
def share(k,a,b):
    fs=[f for f in by[k] if a in f or b in f]
    n=sum(1 for f in fs if f.get(a,999)<f.get(b,999))
    return n,len(fs)
checks=[('science','Physics','Education'),('science','Chivalry','Education'),('science','Mathematics','Writing'),('science','Construction','Philosophy'),
 ('culture','Physics','Drama&Poetry'),('culture','Chivalry','Theology'),('culture','Mathematics','Philosophy'),
 ('diplomacy','Chivalry','Banking'),('diplomacy','Physics','Currency'),
 ('domination','Drama&Poetry','Mathematics'),('domination','Theology','Physics'),('domination','Education','Physics'),('domination','Philosophy','Construction'),('domination','Acoustics','Chivalry')]
print()
for k,a,b in checks:
    n,m=share(k,a,b); print('%-10s %-14s before %-14s %3d of %3d (%d%%)'%(k,a,b,n,m,100*n//max(1,m)))
