import json, collections, os, csv, glob, re
D=25
deals=json.load(open('deals.json'))
# war state and approaches
war=collections.defaultdict(set); appr={}; games_dip=set(); turns_by_game=collections.defaultdict(set)
for g in os.listdir('deals'):
    f=f'deals/{g}/dip.csv'
    if not os.path.exists(f) or os.path.getsize(f)==0: continue
    games_dip.add(g)
    for line in open(f,encoding='latin-1'):
        p=line.rstrip('\n').split(',')
        if len(p)<5: continue
        t=int(p[0]); a=p[1].strip(); b=p[2].strip()
        turns_by_game[g].add(t)
        if p[3]=='AT WAR': war[(g,frozenset((a,b)))].add(t)
        appr[(g,t,a,b)]=p[4].replace('*','')
warstarts=collections.defaultdict(list)
for (g,pr),ts in war.items():
    for t in sorted(ts):
        if t-1 not in ts: warstarts[(g,pr)].append(t)
def war_within(g,a,b,t,n):
    for s in warstarts.get((g,frozenset((a,b))),[]):
        if t < s <= t+n: return s
    return None
def at_war(g,a,b,t): return t in war.get((g,frozenset((a,b))),())
deals=[d for d in deals if d['g'] in games_dip]
print('deals in games with diplomacy logs:',len(deals))
# ---------- 1. luxury duplicates
imports=collections.defaultdict(list); exports=collections.defaultdict(list)
for d in deals:
    for t,a,b,k,r,v in d['items']:
        if k=='lux':
            exports[(d['g'],a,r)].append((t,b)); imports[(d['g'],b,r)].append((t,a))
def active(lst,t,me,excl_partner=None):
    # entries (t0,partner) active at t (started before t, within D, not cancelled by war)
    out=[]
    for t0,p in lst:
        if t0<t<t0+D and not any(t0<s<=t for s in warstarts.get((g_,frozenset((me,p))),[])): out.append((t0,p))
    return out
dup=0; churn=0; owned=0; tot=0; ex_dup=[]; gpt_dup=0
for d in deals:
    for t,a,b,k,r,v in d['items']:
        if k!='lux': continue
        g_=d['g']; tot+=1
        prev=[x for x in active(imports[(g_,b,r)],t,b) if x[1]!=a]
        exp_now=active(exports[(g_,b,r)],t,b)
        exp_before=[x for x in exports[(g_,b,r)] if x[0]<t]
        if prev:
            dup+=1
            if len(ex_dup)<6: ex_dup.append((g_,t,b,r,'from',a,'already from',prev[0]))
            gpt_dup+=sum(i[4] for i in d['items'] if i[3]=='gpt' and i[1]==b)
        elif exp_now: churn+=1
        elif exp_before: owned+=1
print(f'\n1. LUXURY IMPORTS: {tot}')
print(f'  bought a luxury it was already importing from someone else (active deal): {dup} ({100*dup/tot:.1f}%), paying {gpt_dup} GPT total in those deals')
print(f'  bought a luxury while selling the same luxury to someone (churn): {churn} ({100*churn/tot:.1f}%)')
print(f'  bought a luxury it had sold earlier (so owns a copy), not selling it now: {owned} ({100*owned/tot:.1f}%)')
for e in ex_dup: print('   e.g.',e)
json.dump({'n':len(deals)},open('/dev/null','w'))
# ---------- 2. giving things to a civ you're soon at war with
print('\n2. GIVEN TO A CIV THAT IS AT WAR WITH THE GIVER WITHIN 25 TURNS (deal length)')
# baseline: random at-peace pair-turns in these games
import random; random.seed(1)
pairs=collections.defaultdict(set)
for (g,t,a,b) in appr: pairs[g].add((a,b))
base_n=0; base_w=0
for g in games_dip:
    ts=sorted(turns_by_game[g]); P=list(pairs[g])
    for _ in range(400):
        a,b=random.choice(P); t=random.choice(ts)
        if t>140 or at_war(g,a,b,t): continue
        base_n+=1; base_w+= war_within(g,a,b,t,D) is not None
print(f'  baseline: a random pair of civs at peace goes to war within 25 turns {100*base_w/base_n:.1f}% of the time')
kinds=collections.defaultdict(lambda:[0,0,0,0])  # n, war, givers own approach WAR, receiver approach WAR (toward giver)
examples=collections.defaultdict(list)
for d in deals:
    g=d['g']
    if d['t']>140: continue
    kinds_in=set(i[3] for i in d['items'])
    if 'peace' in kinds_in or any(i[3]=='other' for i in d['items']): continue
    for t,a,b,k,r,v in d['items']:
        if k in ('emb',): continue
        if k=='ob': lab='open borders granted'
        elif k=='strat': lab='strategic resource sold ('+r+')'
        elif k=='lux': lab='luxury sold'
        elif k=='gpt': lab='gold per turn paid'
        elif k=='gold': lab='lump-sum gold paid'
        elif k=='ra': lab='research agreement'
        elif k=='dp': lab='defensive pact'
        else: continue
        s=war_within(g,a,b,t,D)
        ga=appr.get((g,t,a,b),''); ra=appr.get((g,t,b,a),'')
        K=kinds[lab]; K[0]+=1; K[1]+= s is not None; K[2]+= ga.startswith('WAR'); K[3]+= ra.startswith('WAR')
        if ga.startswith('WAR') and len(examples[lab])<3: examples[lab].append((g,t,a,'->',b,r,'war at',s))
print(f'  {"item (giver -> receiver)":34s} {"n":>6s} {"war<=25t":>9s} {"giver planning war on receiver":>31s} {"receiver planning war on giver":>31s}')
for lab,(n,w,gw,rw) in sorted(kinds.items(), key=lambda kv:-kv[1][0]):
    print(f'  {lab:34s} {n:6d} {100*w/n:8.1f}% {gw:20d} ({100*gw/n:4.1f}%) {rw:20d} ({100*rw/n:4.1f}%)')
for lab,ex in examples.items():
    for e in ex: print('   giver planning war, e.g.',lab,e)
# ---------- 3. who gets fed: score rank of receiver vs giver
score=collections.defaultdict(dict); role={}
def norm(c): return c.replace('CIVILIZATION_','').replace('_',' ').lower()
for f in glob.glob('csv/*.csv'):
    try: rows=list(csv.DictReader(open(f,encoding='utf-8-sig',errors='replace')))
    except Exception: continue
    if not rows or 'Score' not in rows[0]: continue
    for r in rows:
        if r.get('Alive')!='1': continue
        try: score[(r['GameId'],int(r['Turn']))][norm(r['Civ'])]=int(r['Score'])
        except: pass
        if r.get('Role'): role[(r['GameId'],norm(r['Civ']))]=r['Role']
def lname(n): n=n.lower(); return n[4:] if n.startswith('the ') else n
alias={'inca':'inca','iroquois':'iroquois','shoshone':'shoshone','maya':'maya','huns':'huns','zulus':'zulu','ottomans':'ottoman','aztecs':'aztec','celts':'celts','netherlands':'netherlands','polynesia':'polynesia'}
def cname(n):
    n=lname(n); return alias.get(n,n)
def sc(gid,t,c):
    tt=(t//10)*10
    s=score.get((gid,tt)); 
    if not s: return None,None
    k=[x for x in s if x==c or x.startswith(c) or c.startswith(x)]
    if not k: return None,None
    v=s[k[0]]; rank=1+sum(1 for x in s.values() if x>v); lead=max(s.values())
    return rank, v/ max(1,sorted(s.values())[-2] if v==lead else lead)
print('\n3. WHO RECEIVES (score rank at the time, 1 = leader)')
recv=collections.defaultdict(collections.Counter); matched=0
lead_big=collections.Counter(); agg=collections.Counter(); aggn=collections.Counter()
for d in deals:
    gid=d['g'][5:]
    for t,a,b,k,r,v in d['items']:
        if k not in ('gpt','gold','strat','lux','ra'): continue
        rk,ratio=sc(gid,t,cname(b)); ga,_=sc(gid,t,cname(a))
        if rk is None or ga is None: continue
        matched+=1
        lab={'gpt':'gold per turn','gold':'lump-sum gold','strat':'strategic resource','lux':'luxury','ra':'research agreement'}[k]
        recv[lab][min(rk,4)]+=1
        if rk==1 and ratio and ratio>=1.25: lead_big[lab]+=1
        rb=role.get((gid,cname(b)),''); ra_=role.get((gid,cname(a)),'')
        if rb or ra_:
            aggn[lab]+=1
            if rb=='aggressor': agg[lab]+=1
print('  items matched to scores:',matched)
for lab,c in recv.items():
    n=sum(c.values()); print(f'  {lab:20s} n={n:6d}  to leader {100*c[1]/n:4.1f}%  2nd {100*c[2]/n:4.1f}%  3rd {100*c[3]/n:4.1f}%  4th+ {100*c[4]/n:4.1f}%   to a leader 25%+ ahead: {lead_big[lab]}')
print('  bully games: share of items going TO the aggressor:', {k:f'{agg[k]}/{aggn[k]}' for k in aggn})
print('\n4. BULLY GAMES: THE AGGRESSOR AS A TRADER')
flow=collections.defaultdict(lambda: collections.Counter()); games_b=set(); ncivs=collections.Counter()
for (gid,c),rl in role.items():
    if rl=='aggressor': games_b.add(gid)
for (gid,t),s in score.items():
    if gid in games_b: ncivs[gid]=max(ncivs[gid],len(s))
for d in deals:
    gid=d['g'][5:]
    if gid not in games_b: continue
    for t,a,b,k,r,v in d['items']:
        ra_=role.get((gid,cname(a)),'')=='aggressor'; rb=role.get((gid,cname(b)),'')=='aggressor'
        who='agg' if (ra_ or rb) else 'oth'
        amt = r*D if k=='gpt' else (r if k=='gold' else 1)
        if ra_: flow[k]['agg_gives']+=amt
        if rb: flow[k]['agg_gets']+=amt
        if not ra_ and not rb: flow[k]['others_avg_gives']+=amt
print(f'  {len(games_b)} bully games with deals; civs per game ~{sum(ncivs.values())/max(1,len(ncivs)):.1f}')
for k in ('lux','gpt','gold','strat','ob','ra','dp','emb'):
    f=flow[k]; per_other=f['others_avg_gives']/ (sum(ncivs[g]-1 for g in games_b) or 1)
    print(f'  {k:5s} aggressor gives {f["agg_gives"]/len(games_b):7.1f}/game, gets {f["agg_gets"]/len(games_b):7.1f}/game; an average other civ gives {per_other:7.1f}/game (to non-aggressors)')
print('\n4b. per civ, bully games with deal logs')
gl=set(d['g'][5:] for d in deals) & games_b
per=collections.defaultdict(lambda: collections.Counter())
for d in deals:
    gid=d['g'][5:]
    if gid not in gl: continue
    for t,a,b,k,r,v in d['items']:
        amt = r*D if k=='gpt' else (r if k=='gold' else 1)
        per[(gid,a)][k+'_give']+=amt; per[(gid,b)][k+'_get']+=amt
import statistics
agg=[c for (g,a),c in per.items() if role.get((g,cname(a)))=='aggressor']
oth=[c for (g,a),c in per.items() if role.get((g,cname(a))) and role.get((g,cname(a)))!='aggressor']
print(f'  games {len(gl)}, aggressors {len(agg)}, others {len(oth)}')
for k in ('lux','gpt','gold','strat','ob','dp'):
    for side in ('give','get'):
        A=[c[k+'_'+side] for c in agg]; O=[c[k+'_'+side] for c in oth]
        print(f'  {k:5s} {side:4s}: aggressor mean {statistics.mean(A):7.1f}  others mean {statistics.mean(O):7.1f}')
print('\n5. lump-sum gold gifts (help requests): is the receiver ahead of the giver?')
n=0; ahead=0; amt=0; amt_ahead=0; far=0
for d in deals:
    its=d['items']
    if [i[3] for i in its]!=['gold']: continue
    t,a,b,k,r,v=its[0]; gid=d['g'][5:]
    s=score.get((gid,(t//10)*10)) or {}
    def g_(c):
        k_=[x for x in s if x==cname(c) or x.startswith(cname(c)) or cname(c).startswith(x)]; return s[k_[0]] if k_ else None
    sa,sb=g_(a),g_(b)
    if sa is None or sb is None: continue
    n+=1; amt+=r
    if sb>sa: ahead+=1; amt_ahead+=r
    if sb>=1.25*sa: far+=1
print(f'  {n} gifts, {amt} gold; receiver had the higher score in {ahead} ({100*ahead/max(1,n):.0f}%), {amt_ahead} gold; 25%+ higher in {far}')
