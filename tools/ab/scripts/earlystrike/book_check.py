"""EarlyStrike book check (Economy): did the aggressor's capital follow the plan?

Usage: python3 -I book_check.py <folder with logs_* folders> [...]

Per game (the aggressor is the civ with EarlyStrike/WarBudget/TimingBuildup lines in PlayerTacticalAILog.csv):
  - capital book: items started by the opening book to T60 (CitySpecializationLog "OPENING BOOK - Started"),
    core units started before the first settler (N), cities at the declaration (K);
  - research, read from the first turn each unit is buildable (CityStrategyAIProductionLog PRE lines) and the
    first luxury improvement planned (PlayerHomelandAILog builder lines);
  - first policy branch (PolicyAILog.csv, if the PC kept it);
  - gold: purchases before the declaration (should be none), upgrades and the treasury around the declaration.
"""
import re, glob, os, sys
from collections import defaultdict

LUX_IMPROVEMENTS = ('PLANTATION', 'CAMP', 'QUARRY', 'MINE', 'PASTURE', 'FISHING_BOAT')
BUY = re.compile(r'MOD - Buying unit|MOD - Investing in|WAR CHEST - Bought|EXPANSION SETTLER - Bought|Buying plot|Emergency Gold Unit Purchased')

def read(path):
    return open(path, encoding='latin-1').read().splitlines() if os.path.exists(path) else []

def turn(line):
    try:
        return int(line.split(',', 1)[0])
    except ValueError:
        return None

for root in sys.argv[1:]:
    for d in sorted(glob.glob(os.path.join(root, 'logs_*'))):
        tac = read(d + '/PlayerTacticalAILog.csv')
        civ = None
        for l in tac:
            m = re.match(r'^\d+, (\S+), (EarlyStrike|WarBudget|TimingBuildup):', l)
            if m:
                civ = m.group(1)
                break
        if not civ:
            continue
        name = civ.replace('_', ' ')
        early = any(', %s, EarlyStrike:' % civ in l for l in tac)
        decl = [turn(l) for l in tac if l.split(', ')[1:2] == [civ] and ('at the declaration' in l or 'at war, window closed' in l)]
        tdecl = min(decl) if decl else None

        spec = [l for l in read(d + '/CitySpecializationLog.csv') if ', %s, ' % name in l and 'OPENING BOOK - Started' in l]
        capital = spec[0].split(', ')[2] if spec else None
        book = [(turn(l), l.split('Started ', 1)[1]) for l in spec if capital and l.split(', ')[2] == capital and turn(l) <= 60]
        first_settler = next((t for t, item in book if item == 'Settler'), None)

        prod = read(d + '/CityStrategyAIProductionLog.csv')
        first_offer = {}
        cities_at = defaultdict(set)
        for l in prod:
            p = l.split(', ')
            if len(p) < 5 or p[1] != name:
                continue
            t = turn(l)
            if t is None:
                continue
            cities_at[t].add(p[2])
            m = re.match(r'PRE: Unit \d+, ([^,]+)', p[3] + ', ' + p[4]) if p[3].startswith('PRE: Unit') else None
            if p[3].startswith('PRE: Unit'):
                unit = p[4]
                first_offer.setdefault(unit, t)
        cities = set()
        k_at_decl = None
        for t in sorted(cities_at):
            cities |= cities_at[t]
            if tdecl is not None and t <= tdecl:
                k_at_decl = len(cities)

        hom = read(d + '/PlayerHomelandAILog.csv')
        lux = None
        for l in hom:
            if ', %s, Planning to Construct a [LINK=IMPROVEMENT_' % civ in l:
                imp = l.split('IMPROVEMENT_', 1)[1].split(']', 1)[0]
                if imp in LUX_IMPROVEMENTS and lux is None:
                    lux = (turn(l), imp)
        buys = [l.split(', ', 2)[2][:60] for l in hom if l.split(', ')[1:2] == [civ] and BUY.search(l) and (tdecl is None or turn(l) < tdecl)]
        ups = [turn(l) for l in hom + tac if l.split(', ')[1:2] == [civ] and 'Upgrading unit' in l]
        gold = [(turn(l), int(m.group(1))) for l in tac + hom if l.split(', ')[1:2] == [civ]
                for m in [re.search(r'(?:gold|GOLD: Available =) (\d+)', l)] if m]

        pol = [l for l in read(d + '/PolicyAILog.csv') if name in l or civ in l]
        first_branch = next((l for l in pol if 'BRANCH' in l.upper()), None)

        print('== %s %s%s' % (os.path.basename(d)[5:], name, ' (EarlyStrike)' if early else ''))
        print('  capital %s book to T60: %s' % (capital, ', '.join('T%d %s' % x for x in book)))
        core_before = [item for t, item in book if first_settler is None or t < first_settler]
        print('  first settler T%s; units before it: %s; cities at the declaration (T%s): %s' % (
            first_settler, ', '.join(core_before), tdecl, k_at_decl))
        print('  buildable from: %s' % ', '.join('%s T%d' % (u, t) for u, t in sorted(first_offer.items(), key=lambda x: x[1])
                                               if u not in ('Settler', 'Worker', 'Work Boat', 'Scout')))
        print('  first luxury improvement planned: %s' % (('T%d %s' % lux) if lux else 'none'))
        print('  first policy branch: %s' % (first_branch.strip()[:100] if first_branch else 'no PolicyAILog.csv'))
        print('  purchases before the declaration: %d %s' % (len(buys), '; '.join(buys[:5])))
        near = [g for g in gold if tdecl is not None and tdecl - 15 <= g[0] <= tdecl + 2]
        print('  upgrades: %d (turns %s); gold near the declaration: %s' % (
            len(ups), ', '.join(str(t) for t in ups[:8]), ', '.join('T%d %d' % g for g in near[:12])))
