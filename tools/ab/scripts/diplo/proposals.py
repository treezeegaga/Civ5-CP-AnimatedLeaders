import os, collections, json
span={}; civs=collections.defaultdict(set)
for g in os.listdir('deals'):
    f=f'deals/{g}/dip.csv'
    if not os.path.exists(f) or os.path.getsize(f)==0: continue
    ts=[]
    for line in open(f,encoding='latin-1'):
        p=line.split(',')
        if len(p)<5: continue
        ts.append(int(p[0])); civs[g].add(p[1].strip())
    span[g]=(min(ts),max(ts))
civturns=sum(len(civs[g])*(span[g][1]-span[g][0]+1) for g in span)/10
OFFERS={'You have a Luxury I would like':'asks to buy a luxury','Open Borders Offer':'offers open borders','Open Borders Exchange':'asks for an open-borders swap',
 'Wants Research Agreement':'asks for a research agreement','Research Agreement Offer':'offers a research agreement','DOF offer':'offers friendship',
 'Defensive Pact Offer':'offers a defensive pact','Can you spare something':'asks for help','We would like to offer you a gift':'offers a gift',
 'Strategic Resource Trade':'asks to buy a strategic resource','Renew Deal':'asks to renew a deal','Embassy Exchange':'asks for an embassy swap','Wanna team up':'offers friendship (DoF statement)'}
c=collections.Counter(); pairs=collections.Counter()
for g in span:
    for line in open(f'deals/{g}/DiplomacyAI_Messages_Log.csv',encoding='latin-1'):
        p=[x.strip() for x in line.split(',')]
        if len(p)<4: continue
        for k,lab in OFFERS.items():
            if k in line: c[lab]+=1; pairs[(g,p[1],p[2],lab)]+=1; break
tot=sum(c.values())
print(f'proposals per civ per 10 turns (sent): {tot/civturns:.2f}')
for k,v in c.most_common(): print(f'  {k:34s} {v/civturns:.2f}')
