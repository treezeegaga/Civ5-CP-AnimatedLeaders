# The strike's WAR-phase attack requests per logged game (War, Nov 7): python3 tools/ab/strike_requests.py tools/ab/results/logs_<game>
import sys, re, os
d = sys.argv[1]
def lines(f):
    p = os.path.join(d, f)
    return open(p, encoding='utf-8', errors='replace').read().splitlines() if os.path.exists(p) else []
def turn(l):
    m = re.match(r'\s*(\d+),', l); return int(m.group(1)) if m else None
tac, mil, op = lines('PlayerTacticalAILog.csv'), lines('MilitaryAILog.csv'), lines('OperationalAILog.csv')
last = max((turn(l) or 0) for l in tac)
for l in tac:
    m = re.match(r'\s*(\d+), (\S+), Strike: \w+ -> WAR', l)
    if not m: continue
    t0, civ = int(m.group(1)), m.group(2)
    # end of WAR
    tend = last
    for l2 in tac:
        m2 = re.match(r'\s*(\d+), %s, Strike: WAR -> ' % re.escape(civ), l2)
        if m2 and int(m2.group(1)) > t0: tend = int(m2.group(1)); break
    req = {}; tgt = None
    for l2 in tac:
        m2 = re.match(r'\s*(\d+), %s, Strike: no attack under way on (.+?); city attack requested \((.+)\)' % re.escape(civ), l2)
        if m2 and t0 <= int(m2.group(1)) <= tend:
            req[int(m2.group(1))] = m2.group(3); tgt = m2.group(2)
    if tgt is None:
        m3 = [re.search(r'declaration on (?:the city-state )?(.+?) (?:made|confirmed)', l2) for l2 in tac if civ in l2]
        m3 = [x for x in m3 if x]
        if not m3:
            m3 = [re.search(r'\(target (\S+) defence', l2) for l2 in tac if (', %s, ' % civ) in l2 and turn(l2) <= t0]
            m3 = [x for x in m3 if x]
        tgt = m3[-1].group(1).replace('_', ' ') if m3 else '?'
    tu = tgt.replace(' ', '_')
    lu = {turn(l2) for l2 in mil if (', %s, ' % civ) in l2 and 'lack of units' in l2 and tgt in l2}
    sf = {turn(l2) for l2 in mil if (', %s, ' % civ) in l2 and 'SiegeFeed: %s' % tu in l2}
    np = sorted(t for t, r in req.items() if 'not possible' in r)
    started = sorted(t for t, r in req.items() if r == 'started')
    # turns where an offensive op existed: city attack ops alive vs only rapid responses
    ops = {}
    for l2 in op:
        m4 = re.match(r'\s*(\d+), %s, (OP_\w+), (\d+), ' % re.escape(civ), l2)
        if not m4: continue
        t, ot, oid = int(m4.group(1)), m4.group(2), m4.group(3)
        if ot != 'OP_RAPID_RESPONSE' and not ot.startswith('OP_CITY_ATTACK'): continue
        o = ops.setdefault(oid, [ot, t, t, False]); o[2] = max(o[2], t)
        if 'Ended:' in l2: o[3] = True
    def alive(t, kinds):
        return any(o[0] in kinds and o[1] <= t <= o[2] and not (o[3] and o[2] == t and o[1] == t) for o in ops.values())
    rr_only = [t for t in range(t0 + 1, tend + 1) if t not in req and alive(t, ('OP_RAPID_RESPONSE',)) and not any(o[0].startswith('OP_CITY_ATTACK') and o[1] <= t <= o[2] for o in ops.values())]
    plans = [l2 for l2 in tac if ('%s, capture plan vs %s' % (civ, tu)) in l2 and t0 <= (turn(l2) or 0) <= tend]
    mel = sum(l2.count('MELEEATTACK(city') for l2 in plans); rng = sum(l2.count('RANGEATTACK(city') for l2 in plans)
    early = {turn(l2) for l2 in tac if (', %s, ' % civ) in l2 and 'too early for attacking %s' % tu in l2}
    hp = [int(x) for l2 in tac if (', %s, Zone' % civ) in l2 and ('city of %s,' % tu) in l2 for x in re.findall(r'city HP (\d+)/', l2)]
    caps = [l2[:120] for l2 in tac if civ in l2 and re.search(r'captured|Strike: WAR -> ', l2)][:3]
    print(f"{civ} vs {tgt}: WAR T{t0}-T{tend} ({tend - t0 + 1} turns); requests started {started}")
    print(f"  not possible: {len(np)} {np}; of them lack of units {[t for t in np if t in lu]}, SiegeFeed {[t for t in np if t in sf]}")
    print(f"  no request, only rapid responses alive: {len(rr_only)} turns {rr_only[:40]}")
    print(f"  capture plans: melee city attacks {mel}, ranged city attacks {rng}; too-early turns {len(early)}; min city HP {min(hp) if hp else '-'}")
    for c in caps: print('  ', c)
