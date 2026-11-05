import sys, glob, re, collections
base = sys.argv[1]
buys = collections.Counter(); gold = collections.Counter(); during = collections.Counter(); kinds = collections.Counter()
for d in sorted(glob.glob(base + '/logs_*')):
    try: lines = open(d + '/PlayerHomelandAILog.csv', encoding='latin-1').read().splitlines()
    except OSError: continue
    saving = set()
    for line in lines:
        m = re.match(r'\s*(\d+), ([^,]+), EXPANSION SETTLER - Saving', line)
        if m: saving.add((int(m.group(1)), m.group(2)))
    for line in lines:
        m = re.match(r'\s*(\d+), ([^,]+), (MOD - Buying [a-z]+|Buying [a-z ]+?)[:,]? ?([^,]*?)(?: in [^.]*?)?\. Cost: (\d+)', line)
        if not m:
            m2 = re.match(r'\s*(\d+), ([^,]+), (.*?[Bb]uy.*)', line)
            if m2: kinds[re.sub(r'\d+','N',m2.group(3))[:70]] += 1
            continue
        t, civ, what, item, cost = int(m.group(1)), m.group(2), m.group(3), m.group(4).strip(), int(m.group(5))
        key = f'{what}: {item}'
        buys[key] += 1; gold[key] += cost
        # was this civ saving for a settler in the 3 turns before?
        if any((t - k, civ) in saving for k in (1, 2, 3)): during[key] += 1
print('PURCHASES (Homeland log, all logged games):')
for k, v in buys.most_common(15):
    print(f'  {v:5d} x {k:40s} {gold[k]:7d} gold, {during[k]:4d} made while saving for a settler')
print('  total', sum(buys.values()), 'purchases,', sum(gold.values()), 'gold;', sum(during.values()), 'while saving for a settler,', sum(gold[k]*during[k]//max(1,buys[k]) for k in buys), 'gold approx')
print('\nOTHER buy lines:')
for k, v in kinds.most_common(8): print(f'  {v:5d} | {k}')
