import sys, glob, re, collections, statistics as st
base = sys.argv[1]
runs = 0; ended_with_buy = 0; ended_settler = 0; spent = []; held = []; what = collections.Counter()
for d in sorted(glob.glob(base + '/logs_*')):
    try: lines = open(d + '/PlayerHomelandAILog.csv', encoding='latin-1').read().splitlines()
    except OSError: continue
    sav = collections.defaultdict(dict); buys = collections.defaultdict(list)
    for line in lines:
        m = re.match(r'\s*(\d+), ([^,]+), EXPANSION SETTLER - Saving: (\d+) of', line)
        if m: sav[m.group(2)][int(m.group(1))] = int(m.group(3)); continue
        m = re.match(r'\s*(\d+), ([^,]+), MOD - Buying (?:unit|building)[^:]*: ([^,]+?) in [^.]*\. Cost: (\d+)', line)
        if m: buys[m.group(2)].append((int(m.group(1)), m.group(3), int(m.group(4))))
    for civ, d2 in sav.items():
        ts = sorted(d2); start = ts[0]
        for i, t in enumerate(ts):
            last = (i == len(ts)-1) or (ts[i+1] - t > 1)
            if not last: continue
            runs += 1; held.append(d2[t])
            after = [b for b in buys[civ] if t < b[0] <= t + 3]
            if after:
                ended_with_buy += 1; spent.append(sum(b[2] for b in after))
                for b in after: what[b[1]] += 1
                if any(b[1] == 'Settler' for b in after): ended_settler += 1
print(f'saving runs (a stretch of turns saving for a settler): {runs}')
print(f'  gold held when a run stopped: median {st.median(held)}')
print(f'  runs followed within 3 turns by hurry purchases: {ended_with_buy} ({ended_with_buy*100//runs}%), {sum(spent)} gold, median {st.median(spent) if spent else 0} per run')
print(f'  of those, runs that ended in a bought settler: {ended_settler}')
print('  what was bought:', ', '.join(f'{k} {v}' for k, v in what.most_common(10)))
