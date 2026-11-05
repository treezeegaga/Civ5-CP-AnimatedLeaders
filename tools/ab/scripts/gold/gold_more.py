import sys, glob, re, collections, statistics as st
base = sys.argv[1]
plots = []; plot_during = 0; warrior_buys = 0; warrior_upgrade_civs = 0; buy_turns = []
for d in sorted(glob.glob(base + '/logs_*')):
    try: lines = open(d + '/PlayerHomelandAILog.csv', encoding='latin-1').read().splitlines()
    except OSError: continue
    saving = set(); wbuy = collections.defaultdict(list); wupg = collections.defaultdict(list)
    for line in lines:
        m = re.match(r'\s*(\d+), ([^,]+), EXPANSION SETTLER - Saving', line)
        if m: saving.add((int(m.group(1)), m.group(2)))
    for line in lines:
        m = re.match(r'\s*(\d+), ([^,]+), Buying plot, .*Cost: (\d+)', line)
        if m:
            t, c, cost = int(m.group(1)), m.group(2), int(m.group(3)); plots.append((t, cost))
            if any((t-k, c) in saving for k in (1,2,3)): plot_during += 1
        m = re.match(r'\s*(\d+), ([^,]+), MOD - Buying unit: (?:for sneak attack from City root function: )?Warrior\b', line)
        if m: wbuy[m.group(2)].append(int(m.group(1))); buy_turns.append(int(m.group(1)))
        m = re.match(r'\s*(\d+), ([^,]+), Need gold for Warrior upgrade', line)
        if m: wupg[m.group(2)].append(int(m.group(1)))
    for c, ts in wbuy.items():
        warrior_buys += len(ts)
        if c in wupg and min(wupg[c]) > min(ts): warrior_upgrade_civs += 1
print(f'PLOT PURCHASES: {len(plots)}, {sum(c for _,c in plots)} gold, median cost {st.median([c for _,c in plots])}, median turn T{st.median([t for t,_ in plots])}; {plot_during} while saving for a settler')
print(f'WARRIORS BOUGHT: {warrior_buys} (median turn T{st.median(buy_turns)}); civ-games that bought Warriors and later saved gold to upgrade Warriors: {warrior_upgrade_civs}')
