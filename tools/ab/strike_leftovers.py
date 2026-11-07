# The lead's review of 6bf8952 (Nov 7): how often the two leftovers fire on the 993343d build. Usage:
#   python3 -I tools/ab/strike_leftovers.py tools/ab/results/logs_<game> [...]
# 1. Deadlock candidates: a strike civ still in BUILDUP at the end of the log, for 15+ turns, whose last WarBudget lines
#    show nothing more affordable and net gold <= 0 (the stall), with no BUILDUP -> OVER or -> WAR after it.
# 2. No land zone: a strike civ in WAR whose target city never gets a "Zone N, land, city of <target>" line while it has
#    water-zone lines (the strike counted it unblocked; the tactical AI uses the water zone).
import sys, re, os

def lines(d, f):
    p = os.path.join(d, f)
    return open(p, encoding='utf-8', errors='replace').read().splitlines() if os.path.exists(p) else []

def turn(l):
    m = re.match(r'\s*(\d+),', l)
    return int(m.group(1)) if m else -1

for d in sys.argv[1:]:
    tac = lines(d, 'PlayerTacticalAILog.csv')
    if not tac:
        continue
    last = max(turn(l) for l in tac)
    game = os.path.basename(d.rstrip('/'))[5:13]
    state, since = {}, {}
    for l in tac:
        m = re.match(r'\s*(\d+), (\S+), Strike: (\w+) -> (\w+)', l)
        if m:
            state[m.group(2)] = m.group(4)
            since[m.group(2)] = int(m.group(1))
    for civ, st in state.items():
        if st != 'BUILDUP' or last - since[civ] < 15:
            continue
        wb = [l for l in tac if (', %s, WarBudget:' % civ) in l]
        tail = wb[-3:]
        aff = [int(x) for l in tail for x in re.findall(r'affordable (-?\d+) more', l)]
        net = [int(x) for l in tail for x in re.findall(r'gold \d+, (-?\d+) a turn', l)]
        stalled = aff and net and max(aff) <= 0 and max(net) <= 0
        nr = [l for l in tac if (', %s, Strike: not ready' % civ) in l]
        takes = 'takes it' in nr[-1] if nr else None
        print(f"{game} deadlock? {civ}: BUILDUP since T{since[civ]} to T{last}; stalled-looking {bool(stalled)} "
              f"(affordable {aff}, net {net}); plan army {'takes' if takes else 'can not take' if takes is False else '-'} the target")
    # WAR targets with no land zone line
    for l in tac:
        m = re.match(r'\s*(\d+), (\S+), Strike: \w+ -> WAR', l)
        if not m:
            continue
        civ, t0 = m.group(2), int(m.group(1))
        tgt = None
        for l2 in tac:
            m2 = re.match(r'\s*(\d+), %s, Strike: no attack under way on (.+?);' % re.escape(civ), l2)
            if m2 and int(m2.group(1)) >= t0:
                tgt = m2.group(2).replace(' ', '_')
                break
        if not tgt:
            continue
        land = sum(1 for l2 in tac if (', %s, Zone ' % civ) in l2 and (', land, city of %s,' % tgt) in l2 and turn(l2) >= t0)
        water = sum(1 for l2 in tac if (', %s, Zone ' % civ) in l2 and (', water, city of %s,' % tgt) in l2 and turn(l2) >= t0)
        if land == 0:
            print(f"{game} no land zone: {civ} vs {tgt} from T{t0}: land-zone lines 0, water-zone lines {water}")
