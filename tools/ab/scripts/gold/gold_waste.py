import sys, glob, re, collections, csv, statistics as st
base = sys.argv[1]
settler = collections.defaultdict(list)   # (game,civ) -> [(turn, saved, needed)]
upg = collections.defaultdict(list)       # (game,civ,unit) -> [(turn, avail, needed)]
games = 0
for d in sorted(glob.glob(base + '/logs_*')):
    try: f = open(d + '/PlayerHomelandAILog.csv', encoding='latin-1')
    except OSError: continue
    games += 1
    g = d.split('logs_')[1]
    for line in f:
        m = re.match(r'\s*(\d+), ([^,]+), EXPANSION SETTLER - Saving: (\d+) of (\d+) gold', line)
        if m:
            settler[(g, m.group(2))].append((int(m.group(1)), int(m.group(3)), int(m.group(4)))); continue
        m = re.match(r'\s*(\d+), ([^,]+), Need gold for (.+?) upgrade, GOLD: Available = (\d+), Needed = (\d+)', line)
        if m:
            upg[(g, m.group(2), m.group(3))].append((int(m.group(1)), int(m.group(4)), int(m.group(5))))
print('logged games read:', games)
# settler saving
spans = []; reached = 0; neverreached = 0; maxsaved = []
for k, v in settler.items():
    turns = sorted(set(t for t, _, _ in v))
    spans.append(len(turns))
    if any(s >= n for _, s, n in v): reached += 1
    else: neverreached += 1
    maxsaved.append(max(s for _, s, _ in v))
print(f'\nSETTLER SAVING: {len(settler)} civ-games save for a settler purchase; turns spent saving: median {st.median(spans)}, max {max(spans)}')
print(f'  reached the price at least once: {reached}; never reached it: {neverreached}; largest amount held: median {st.median(maxsaved)}, max {max(maxsaved)}')
lastturn = [max(t for t,_,_ in v) for v in settler.values()]
print(f'  last turn still saving: median T{st.median(lastturn)}, {sum(1 for t in lastturn if t>=100)} civ-games still saving at T100+')
# upgrades
stuck = 0; stuck_turns = []; ex = []
for k, v in upg.items():
    rich = sorted(set(t for t, a, n in v if a >= n))
    if len(rich) >= 5:
        stuck += 1; stuck_turns.append(len(rich))
        if len(ex) < 5: ex.append((k, rich[0], rich[-1], len(rich), v[0][1], v[0][2]))
print(f'\nUPGRADE SAVING: {len(upg)} (game, civ, unit type) requests; {stuck} logged 5+ turns with enough gold available but still asking')
if stuck_turns: print(f'  those turns: median {st.median(stuck_turns)}, max {max(stuck_turns)}')
for e in ex: print('  e.g.', e)
# treasuries from results files
rows = []
for fn in glob.glob(base + '/*.csv'):
    try:
        for r in csv.DictReader(open(fn, encoding='latin-1')):
            if r.get('Gold') and r.get('Turn') and r.get('Alive','1') != '0': rows.append((fn, r.get('GameId'), r.get('Civ'), int(r['Turn']), int(float(r['Gold']))))
    except Exception: pass
for T in (50, 100, 150):
    gs = [x[4] for x in rows if abs(x[3]-T) <= 1]
    if gs:
        gs.sort()
        print(f'\nTREASURY at T{T}: {len(gs)} civ-rows, median {st.median(gs)}, 75th pct {gs[int(len(gs)*.75)]}, 90th {gs[int(len(gs)*.9)]}, max {gs[-1]}; share holding 500+: {sum(1 for x in gs if x>=500)*100//len(gs)}%, 1000+: {sum(1 for x in gs if x>=1000)*100//len(gs)}%')
