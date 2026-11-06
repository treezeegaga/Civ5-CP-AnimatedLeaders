import re,glob,os,sys
for root in sys.argv[1:]:
  for d in sorted(glob.glob(root+'/logs_*')):
    if d.endswith('F'): continue
    tac=open(d+'/PlayerTacticalAILog.csv',encoding='latin-1').read().splitlines()
    sp=open(d+'/StrategyProfile_Log.csv',encoding='latin-1').read().splitlines() if os.path.exists(d+'/StrategyProfile_Log.csv') else []
    civ=None
    for l in tac:
        m=re.match(r'^\d+, (\S+), (EarlyStrike|WarBudget):',l)
        if m: civ=m.group(1); break
    if not civ: continue
    name=civ.replace('_',' ')
    plan=next((l.split('strike plan ',1)[1][:150] for l in sp if l.startswith('001, %s, strike plan'%name)),'?')
    opens=[l for l in tac if l.startswith(tuple('%03d'%t for t in range(200))) and ', %s, '%civ in l and ('army in the window (turn 1)' in l)]
    decl=[l for l in tac if ', %s, '%civ in l and 'army at the declaration' in l]
    bu=[l for l in tac if ', %s, EarlyStrike: build-up opens'%civ in l]
    print('== %s %s | plan %s'%(os.path.basename(d)[5:13],name,plan))
    for lab,ls in (('build-up opens',bu[:1]),('window turn 1',opens[:1]),('declaration',decl[:1])):
        for l in ls:
            t=l.split(',')[0]; body=l.split(': ',1)[1]
            m=re.search(r'(\d+ land \(\d+ siege)',body); comp=body.rsplit(': ',1)[-1] if body.count(':') else ''
            print('  T%s %-15s %s | %s'%(t,lab,m.group(1)+')' if m else body[:60],comp[:110]))
