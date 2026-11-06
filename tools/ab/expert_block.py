"""The expert strike block (EarlyStrike + EarlyStrikeAggressor, ab-40203a3 and later): judged by captures per civ.

    python3 tools/ab/expert_block.py [run ...]      (default: bullyabort18 bullygreedy18)

Per aggressor (first games): captures and the first capture turn, the declaration turn, the plan (Personality's strike
plan line in StrategyProfile_Log), the build-up ("EarlyStrike: build-up opens"), upgrade and go, barbarian hunting
(BarbHunt / BarbKill before the window) and promotions at the declaration (the army line), melee in reach at each first
capture attempt, and where the strike exits:
  captured      took a city
  no capture    declared war, took nothing
  fell back     no war by the plan's fallback turn (or by T75 Quick without a plan line)
  no strike     no EarlyStrike build-up and no war
"""
import sys, os, glob, re, csv, collections, statistics as st
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
RUNS = sys.argv[1:] or ['bullyabort18', 'bullygreedy18']
sys.argv = sys.argv[:1]
import attack_funnel as af, walls

CAPTURER = re.compile(r"^(Warrior|Spearman|Pikeman|Swordsman|Longswordsman|Jaguar|Legion|Hoplite|Impi|Maori Warrior|Pictish Warrior|"
                      r"Mohawk Warrior|Kris Swordsman|Samurai|Berserker|Landsknecht|Mandekalu Cavalry|Horseman|Knight|Keshik|Cataphract|"
                      r"Companion Cavalry|Musketman|Tercio|Conquistador|Immortal|Sipahi|Lancer)$")
ARMY = re.compile(r"(?:BigArmy|WarBudget|EarlyStrike): army (at the declaration on .+?|at the first capture attempt on (\S+) \(in reach: ([^)]*)\)|in the window \(turn \d+\)): "
                  r"(\d+) land(?:.*?promoted (\d+) \((\d+) promotions, (\d+) XP\))?")
PLAN = re.compile(r"strike plan .*?open T(\d+), declare by T(\d+), fallback T(\d+)")
PLANFULL = re.compile(r"strike plan \w+: core (\S+) x(\d+), support (\S+) x(\d+), siege (\S+) x(\d+), upgrade (\S+) \((\d+) gold each\)")
med = lambda v: st.median(v) if v else '-'
# the lead (Nov 6, the user: "if they were 4 units short, they need to fix their start"): units on hand against the plan's
# counts at BUILDUP and WAR, and where the capital's and second city's production went before the war
CLASS_UNITS = {'SPEARMAN': ('Spearman', 'Hoplite', 'Immortal', 'Impi', 'Pikeman', 'Landsknecht'), 'ARCHER': ('Archer', 'Composite Bowman', 'Bowman'),
               'WARRIOR': ('Warrior', 'Jaguar', 'Maori Warrior', 'Pictish Warrior', 'Brute'), 'HORSEMAN': ('Horseman', 'Companion Cavalry', 'Knight', 'Keshik'),
               'CHARIOT_ARCHER': ('Chariot Archer', 'War Chariot', 'Hand-Axe'), 'CATAPULT': ('Catapult', 'Ballista'),
               'COMPOSITE_BOWMAN': ('Composite Bowman', 'Crossbowman', 'Chu-Ko-Nu'), 'SWORDSMAN': ('Swordsman', 'Legion', 'Berserker', 'Mohawk Warrior', 'Longswordsman', 'Samurai'),
               'CROSSBOWMAN': ('Crossbowman', 'Chu-Ko-Nu'), 'KNIGHT': ('Knight', 'Keshik', 'Mandekalu Cavalry', 'Camel Archer'), 'TREBUCHET': ('Trebuchet', 'Hwacha'),
               'SLINGER': ('Slinger', 'Archer', 'Composite Bowman')}
CIVILIAN = {'Worker', 'Settler', 'Work Boat', 'Scout', 'Caravan', 'Cargo Ship', 'Missionary', 'Inquisitor', 'Great Prophet', 'Pioneer', 'Colonist'}
MILITARY_EXTRA = re.compile(r"^(Archer|Composite Bowman|Slinger|Chariot Archer|War Chariot|Catapult|Ballista|Crossbowman|Chu-Ko-Nu|Trebuchet|Galley|Trireme|Bowman)$")
UNITLIST = re.compile(r"([A-Z][A-Za-z' -]+?) (\d+)(?:, |$)")
def army_units(r):
    tail = r.rsplit('): ', 1)[-1] if '): ' in r else r.rsplit(': ', 1)[-1]
    return {n.strip(): int(c) for n, c in UNITLIST.findall(tail)}
def class_count(units, cls):
    names = CLASS_UNITS.get(cls.replace('UNITCLASS_', ''), (cls.replace('UNITCLASS_', '').replace('_', ' ').title(),))
    return sum(c for n, c in units.items() if n in names)
# the plan's upgrade tech -> the units it upgrades into (to find the strike's own upgrade among CP's others)
UPGRADE_UNITS = {'TECH_CONSTRUCTION': ('Composite Bowman',), 'TECH_MACHINERY': ('Crossbowman', 'Chu-Ko-Nu'),
                 'TECH_CHIVALRY': ('Knight', 'Keshik', 'Mandekalu Cavalry', 'Camel Archer'), 'TECH_STEEL': ('Longswordsman', 'Samurai'),
                 'TECH_CIVIL_SERVICE': ('Pikeman', 'Impi'), 'TECH_METAL_CASTING': ('Swordsman', 'Berserker'), 'TECH_IRON_WORKING': ('Swordsman', 'Legion'),
                 'TECH_MATHEMATICS': ('Catapult', 'Ballista'), 'TECH_HORSEBACK_RIDING': ('Horseman',)}

games = af.games_from_csvs()
CSVROWS = collections.defaultdict(dict)
for f in glob.glob(os.path.join(af.RESULTS, 'AIABTest_*.csv')):
    run = os.path.basename(f)[9:-4].split('@')[0]
    if run not in RUNS:
        continue
    for r in csv.DictReader(open(f, encoding='utf-8-sig')):
        if r.get('Role') == 'aggressor':
            CSVROWS[r['GameId']][int(r['Turn'] or 0)] = r

rows = []
for gdir in sorted(glob.glob(os.path.join(af.RESULTS, 'logs_*'))):
    gid = os.path.basename(gdir)[5:]
    info = games.get(gid)
    if not info or info['build'] not in RUNS or len(gid) != 16:
        continue
    ours = af.log_name_matches(info['civ'])
    g = dict(gid=gid[:8], civ=info['civ'].title(), run=info['build'], capt=info['captured'], first_capt=None, decl=None,
             open=None, walled=None, upgrades=[], hunts=0, kills=0, kill_xp=[], decl_land=None, decl_promoted=None,
             decl_promotions=None, reach=[], plan=None, need_field=None, upgrade_tech=None,
             t_tech=None, t_gold=None, t_army=None, t_upgraded=None, states=[], plan_counts=None, armies=[], prod=None)
    for t, r in walls.our_lines(os.path.join(gdir, 'StrategyProfile_Log.csv'), ours):
        m = PLAN.search(r)
        if m:
            g['plan'] = tuple(map(int, m.groups()))
        m = PLANFULL.search(r)
        if m:
            g['need_field'] = int(m.group(2)) + int(m.group(4))
            g['plan_counts'] = [(m.group(1), int(m.group(2))), (m.group(3), int(m.group(4))), (m.group(5), int(m.group(6)))]
            g['upgrade_tech'] = None if m.group(7) == 'none' else m.group(7)
    for t, r in walls.our_lines(os.path.join(gdir, 'CitySpecializationLog.csv'), ours):
        if 'Update: Enemy city captured' in r and g['first_capt'] is None:
            g['first_capt'] = t
    # readiness (the lead, 10:35pm ET): when each condition was met, against the plan's turns
    upgraded_to = None
    for t, r in walls.our_lines(os.path.join(gdir, 'PlayerHomelandAILog.csv'), ours):
        m = re.search(r'Upgrading unit from type (.+?) to type (.+?), X:', r)
        want = UPGRADE_UNITS.get(g['upgrade_tech'] or '', None)
        if m and g['t_upgraded'] is None and (want is None or m.group(2) in want):
            g['t_upgraded'], upgraded_to = t, m.group(2)
    if upgraded_to:
        for l in open(os.path.join(gdir, 'CityStrategyAIProductionLog.csv'), errors='replace'):
            p = l.split(', ')
            if len(p) > 4 and p[3].startswith('PRE: Unit') and p[4] == upgraded_to and ours(p[1]):
                g['t_tech'] = int(p[0])
                break
    capt_cities = set()
    lines = list(walls.our_lines(os.path.join(gdir, 'PlayerTacticalAILog.csv'), ours))
    for t, r in lines:
        m = re.search(r'capture attempt on (\S+) done:.*CAPTURED', r)
        if m:
            capt_cities.add(m.group(1))
    for t, r in lines:
        if r.startswith('Strike: '):   # the strike state (ai/war 56e0cadc on): "Strike: OLD -> NEW (why; ...)"
            m = re.match(r'Strike: (\w+) -> (\w+) \((.*?);', r)
            if m:
                g['states'].append((t, m.group(2), m.group(3)))
        if r.startswith('EarlyStrike: build-up opens') and g['open'] is None:
            g['open'] = t
            g['walled'] = 'unwalled' not in r
        elif r.startswith('EarlyStrike: upgrade and go'):
            m = re.search(r'(\d+) units to upgrade for (\d+) gold \(gold (-?\d+)\)', r)
            if m:
                g['upgrades'].append((t, int(m.group(1)), int(m.group(2))))
                if g['t_gold'] is None and int(m.group(3)) >= int(m.group(2)):
                    g['t_gold'] = t
        elif r.startswith('BarbHunt:') and (g['open'] is None or t < g['open']):
            g['hunts'] += 1
        elif r.startswith('BarbKill:') and (g['open'] is None or t < g['open']):
            g['kills'] += 1
            m = re.search(r'XP (\d+)', r)
            if m:
                g['kill_xp'].append(int(m.group(1)))
        m = ARMY.search(r)
        if m:
            g['armies'].append((t, int(m.group(4)), army_units(r)))
            if m.group(1).startswith('at the declaration') and g['decl'] is None:
                g['decl'], g['decl_land'] = t, int(m.group(4))
                if m.group(5):
                    g['decl_promoted'], g['decl_promotions'] = int(m.group(5)), int(m.group(6))
            elif m.group(1).startswith('in the window') and g['t_army'] is None and g['need_field'] is not None:
                sm = re.search(r'\((\d+) siege', r)
                if sm and int(m.group(4)) - int(sm.group(1)) >= g['need_field']:
                    g['t_army'] = t
            elif m.group(2):
                units = [u.strip() for u in m.group(3).split(',') if u.strip()]
                g['reach'].append((m.group(2), sum(1 for u in units if CAPTURER.match(u)), m.group(2) in capt_cities))
    if g['decl'] is None:
        T = CSVROWS.get(gid, {})
        wt = [t for t in sorted(T) if (T[t].get('WarsDeclared') or '0') not in ('', '0')]
        g['decl'] = wt[0] if wt else None
    # production of the capital and the second city (the book's "Started" lines and CP's CHOSEN lines), up to the war
    t_build = next((x[0] for x in g['states'] if x[1] == 'BUILDUP'), g['open'])
    t_war = next((x[0] for x in g['states'] if x[1] == 'WAR'), g['decl'])
    cities, prod = [], collections.defaultdict(collections.Counter)
    def note(t, city, kind, name):
        if city not in cities:
            cities.append(city)
        if cities.index(city) > 1 or (t_war is not None and t > t_war) or (t_war is None and t > 100):
            return
        phase = 'to BUILDUP' if t_build is None or t < t_build else 'BUILDUP to WAR'
        if kind == 'book':
            kind = 'Civilian' if name in CIVILIAN else 'Military' if (CAPTURER.match(name) or MILITARY_EXTRA.match(name)) else 'Building'
        if kind == 'Civilian':
            kind = name if name in ('Worker', 'Settler') else 'Civilian other'
        prod[phase][kind.replace('MilitaryMelee', 'Military').replace('MilitaryRanged', 'Military')] += 1
    for t, r in walls.our_lines(os.path.join(gdir, 'CitySpecializationLog.csv'), ours):
        m = re.match(r'(\S+), OPENING BOOK - Started (.+)$', r)
        if m:
            note(t, m.group(1), 'book', m.group(2).strip())
    for l in open(os.path.join(gdir, 'CityStrategyAIProductionLog.csv'), errors='replace'):
        p = l.rstrip('\n').split(', ')
        if len(p) > 6 and ours(p[1]) and p[4].startswith('CHOSEN: '):
            note(int(p[0]), p[2], p[4][8:], p[5])
    g['prod'] = prod
    g['t_build'], g['t_war'] = t_build, t_war
    fallback = g['plan'][2] if g['plan'] else 75
    g['exit'] = ('captured' if g['capt'] > 0 else 'no capture' if g['decl'] is not None else
                 'no strike' if g['open'] is None else 'fell back')
    over = [x for x in g['states'] if x[1] == 'OVER']
    if over and g['capt'] == 0:
        g['exit'] = 'over: ' + over[0][2][:40]
    rows.append(g)

print('expert block: %d logged first games in %s' % (len(rows), ', '.join(RUNS)))
if not rows:
    sys.exit()
print('\nPer civ (captures are the measure):')
print('  %-10s %5s %8s %6s %10s %8s %10s %12s %10s' % ('civ', 'games', 'captured', 'cities', '1st capt T', 'decl T', 'BarbKills', 'promoted/land', 'exits'))
for civ in sorted({g['civ'] for g in rows}):
    L = [g for g in rows if g['civ'] == civ]
    prom = ['%d/%d' % (g['decl_promoted'], g['decl_land']) for g in L if g['decl_promoted'] is not None]
    ex = collections.Counter(g['exit'] for g in L)
    print('  %-10s %5d %8d %6d %10s %8s %10s %12s  %s' % (civ, len(L), sum(g['capt'] > 0 for g in L), sum(g['capt'] for g in L),
          med([g['first_capt'] for g in L if g['first_capt']]), med([g['decl'] for g in L if g['decl']]),
          '%.1f' % (sum(g['kills'] for g in L) / len(L)), ' '.join(prom) or '-', ', '.join('%s %d' % kv for kv in ex.most_common())))
print('\nAll: %d of %d games captured (%d cities); first capture median T%s; declaration median T%s' % (
    sum(g['capt'] > 0 for g in rows), len(rows), sum(g['capt'] for g in rows),
    med([g['first_capt'] for g in rows if g['first_capt']]), med([g['decl'] for g in rows if g['decl']])))
print('Exits:', dict(collections.Counter(g['exit'] for g in rows)))
B = [g for g in rows if g['open'] is not None]
print('EarlyStrike build-ups: %d (opened median T%s; target walled in %d)' % (len(B), med([g['open'] for g in B]), sum(1 for g in B if g['walled'])))
U = [u for g in rows for u in g['upgrades'][:1]]
print('Upgrade and go: %d games; first bill per unit median %s gold (research: 70-80)' % (len(U), med([u[2] // max(1, u[1]) for u in U])))
print('Barbarian hunting before the window: BarbHunt lines %.1f a game, kills %.1f a game, kill XP max median %s (cap 45)' % (
    sum(g['hunts'] for g in rows) / len(rows), sum(g['kills'] for g in rows) / len(rows), med([max(g['kill_xp']) for g in rows if g['kill_xp']])))
D = [g for g in rows if g['decl_promoted'] is not None]
print('Promotions at the declaration: %d games with the army line; promoted units median %s of land median %s; promotions median %s' % (
    len(D), med([g['decl_promoted'] for g in D]), med([g['decl_land'] for g in D]), med([g['decl_promotions'] for g in D])))
R = [x for g in rows for x in g['reach']]
for lo, hi, lab in ((0, 1, '0'), (1, 2, '1'), (2, 99, '2+')):
    S = [x for x in R if lo <= x[1] < hi]
    print('  melee in reach %-2s at a first capture attempt: %d attempts, taken by a CAPTURED attempt %d' % (lab, len(S), sum(x[2] for x in S)))
print('\nReadiness against the plan (the AI\'s pace; a dash: not met or not logged):')
print('  %-8s %-9s %5s %5s %5s | %6s %6s %6s %6s %6s %6s' % ('game', 'civ', 'open', 'decl-by', 'fallbk', 'window', 'tech', 'army', 'gold', 'upgr', 'decl'))
late = collections.Counter()
for g in rows:
    pl = g['plan'] or ('-', '-', '-')
    print('  %-8s %-9s %5s %5s %5s | %6s %6s %6s %6s %6s %6s' % (g['gid'], g['civ'], pl[0], pl[1], pl[2], g['open'] or '-', g['t_tech'] or '-',
          g['t_army'] or '-', g['t_gold'] or '-', g['t_upgraded'] or '-', g['decl'] or '-'))
    if g['plan']:
        for k in ('t_tech', 't_army', 't_gold', 't_upgraded'):
            if g[k] is None or g[k] > g['plan'][1]:
                late[k] += 1
        if g['decl'] is not None and (g['t_army'] is None or g['decl'] < g['t_army']):
            late['declared before the army was built'] += 1
P = sum(1 for g in rows if g['plan'])
if P:
    print('  of %d games with a plan line, met after the declare-by turn (or never): %s' % (P, dict(late)))

print('\nUnits on hand against the plan (the army line nearest at or after BUILDUP and WAR; plan core/support/siege):')
for g in rows:
    if not g['plan_counts']:
        continue
    out = []
    for lab, tt in (('BUILDUP', g['t_build']), ('WAR', g['t_war'])):
        A = [a for a in g['armies'] if tt is not None and tt <= a[0] <= tt + 2]
        if not A:
            out.append('%s -' % lab)
            continue
        t, land, units = A[0]
        out.append('%s T%d: %d land, %s' % (lab, t, land, ', '.join('%s %d/%d' % (c.replace('UNITCLASS_', '').title(), class_count(units, c), n)
                                                                     for c, n in g['plan_counts'] if n > 0)))
    print('  %s %-9s %s' % (g['gid'], g['civ'], ' | '.join(out)))
print('\nProduction of the capital and second city (before BUILDUP; BUILDUP to WAR), by kind:')
for g in rows:
    if g['prod']:
        print('  %s %-9s %s' % (g['gid'], g['civ'], ' | '.join('%s: %s' % (ph, ', '.join('%s %d' % kv for kv in sorted(g['prod'][ph].items())))
                                                         for ph in ('to BUILDUP', 'BUILDUP to WAR') if g['prod'].get(ph))))

S = [g for g in rows if g['states']]
if S:
    print('\nStrike states (%d games): ' % len(S))
    for g in S:
        print('  %s %-9s %s' % (g['gid'], g['civ'], ' | '.join('T%d %s (%s)' % x for x in g['states'])))
print('\nGames:')
for g in rows:
    print('  %s %-9s %-13s capt %d (T%s) decl T%s open T%s %s plan %s kills %d upgrades %s exit %s' % (
        g['gid'], g['civ'], g['run'], g['capt'], g['first_capt'], g['decl'], g['open'], '(walled)' if g['walled'] else '',
        g['plan'], g['kills'], g['upgrades'][:1], g['exit']))
