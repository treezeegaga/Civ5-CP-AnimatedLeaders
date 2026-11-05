"""At the walls: what our armies look like when they reach a city, over every logged bully game.

War's study for the lead's attack funnel (attack_funnel.py): the funnel says most aggressors get a war and reach the
target region but can't hurt the city. This looks at the "refused" and "not taken" stages across all games, not one:

  - each city attack operation of the aggressor: its target, the units it recruited (types, siege count), how it ended
    and how far from the target it was handed over;
  - each capture attempt: expected damage against the city's HP, the damage done, units used, and the zone strengths
    where the build logs them (ab-7bb7885 on);
  - each refused city ("enemy dominated zone - won't try to capture") near one of our attacks;
  - the same for CP's flipped games, so the armies that captured can be compared with ours.

    python3 tools/ab/walls.py [results dir] [--games]
"""
import collections
import glob
import os
import re
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import attack_funnel as af  # noqa: E402

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
RESULTS = ARGS[0] if ARGS else af.RESULTS
af.RESULTS = RESULTS
SHOW_GAMES = "--games" in sys.argv

SIEGE = ("catapult", "ballista", "siege tower", "trebuchet", "mangonel", "cannon", "hwacha", "great bombard",
         "battering ram", "artillery")
RANGED = ("archer", "bowman", "slinger", "crossbow", "chu-ko-nu", "longbow", "keshik", "camel", "skirmish")
MOUNTED = ("horseman", "chariot", "knight", "companion", "cataphract", "lancer", "war elephant", "mandekalu",
           "conquistador", "hussar", "cavalry", "naresuan", "camel")
CIVILIAN = ("general", "admiral", "khan", "settler", "worker", "missionary", "prophet")

RE_ADDED = re.compile(r"OP_CITY_ATTACK_\w+, (\d+), Added (.+?) (\d+) to slot")
RE_FOUND = re.compile(r"OP_CITY_ATTACK_\w+, (\d+), Found \d+ potential units .* with target at \((\d+):(\d+)\)")
RE_ENDED = re.compile(r"OP_CITY_ATTACK_\w+, (\d+), Ended: (\w+)")
RE_FINISH = re.compile(r"OP_CITY_ATTACK_\w+, (\d+), Transition to finished stage; unit distance near (-?\d+); far (-?\d+)")
RE_HANDOVER = re.compile(r"OP_CITY_ATTACK_\w+, (\d+), MarchOn: stalled near the target at war, handing over")
RE_ATTEMPT = re.compile(r"Zone (-?\d+), attempting capture of (\S+), required damage (\d+), expected max damage per turn (\d+)")
RE_DONE = re.compile(r"capture attempt on (\S+) done: city HP (\d+) -> (\d+), (\d+) of (\d+) units used, agg (\d+)(, CAPTURED)?")
RE_TACTSIM = re.compile(r"tactsim around \((\d+):(\d+)\)")
RE_REFUSE = re.compile(r"City of (\S+), is in enemy dominated zone - won't try to capture, X: (\d+), Y: (\d+)")
RE_ZONE = re.compile(r"Zone (-?\d+), land, city of (\S+), posture (\w+), \d+ targets, friendly (\d+) \((\d+) units, melee (\d+), "
                     r"ranged (\d+)\), enemy (\d+) \((\d+) units, melee (\d+), ranged (\d+), city HP (\d+)/(\d+)\)")
RE_TOOEARLY = re.compile(r"too early for attacking (\S+), required damage (\d+), expected max damage per turn (\d+)")
RE_KILLED = re.compile(r"KilledInCombat (.+?), Domain")
# logging added in ai/war 249985284 (builds after it): the plan per unit, and the city's defence and garrison per attempt
RE_PLAN = re.compile(r"capture plan vs (\S+), agg (\d+): (\d+) units in the sim, (\d+) in the plan, (\d+) attacks \((\d+) on the city\)")
# pillage gold (ai/war 17504599c on); older builds only have "Pillaging <improvement>" without the gold
RE_PILLAGE_GOLD = re.compile(r"Pillage gold: (\d+) from")
RE_PLUNDER_GOLD = re.compile(r"Plunder gold: (\d+) from")
RE_DEFENCE = re.compile(r"city strength (\d+), walls \+(\d+), garrison (.+?) HP (\d+) -> (\d+)")


def kind_of(name):
    n = name.lower()
    if any(k in n for k in CIVILIAN):
        return "civilian"
    if any(k in n for k in SIEGE):
        return "siege"
    if any(k in n for k in RANGED):
        return "ranged"
    if any(k in n for k in MOUNTED):
        return "mounted"
    return "melee"


def our_lines(path, ours):
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            parts = line.split(",", 2)
            if len(parts) == 3 and ours(parts[1]):
                try:
                    turn = int(parts[0])
                except ValueError:
                    continue
                yield turn, parts[2].strip()


def plotdist(a, b):
    """Hex distance on Civ V's offset grid (odd rows shifted), close enough for 'near the target'."""
    (x1, y1), (x2, y2) = a, b
    def cube(x, y):
        q = x - (y - (y & 1)) // 2
        return q, y, -q - y
    q1, r1, s1 = cube(x1, y1)
    q2, r2, s2 = cube(x2, y2)
    return max(abs(q1 - q2), abs(r1 - r2), abs(s1 - s2))


def study(gdir, info):
    ours = af.log_name_matches(info["civ"])
    ops = collections.defaultdict(lambda: {"units": {}, "target": None, "start": None, "end": None, "reason": None,
                                           "near": None, "far": None})
    for t, rest in our_lines(os.path.join(gdir, "OperationalAILog.csv"), ours):
        m = RE_FOUND.search(rest)
        if m:
            o = ops[m.group(1)]
            o["target"] = (int(m.group(2)), int(m.group(3)))
            o["start"] = o["start"] if o["start"] is not None else t
        m = RE_ADDED.search(rest)
        if m:
            ops[m.group(1)]["units"][m.group(3)] = m.group(2)
        m = RE_FINISH.search(rest)
        if m:
            ops[m.group(1)]["near"], ops[m.group(1)]["far"] = int(m.group(2)), int(m.group(3))
        m = RE_ENDED.search(rest)
        if m:
            ops[m.group(1)]["end"], ops[m.group(1)]["reason"] = t, m.group(2)

    attempts, refusals, zones, tooearly, killed = [], collections.Counter(), {}, [], collections.Counter()
    loot = collections.Counter()  # pillages, pillage gold, plunders, plunder gold
    city_xy = {}
    pending = None
    for t, rest in our_lines(os.path.join(gdir, "PlayerTacticalAILog.csv"), ours):
        m = RE_ZONE.search(rest)
        if m:
            g = m.groups()
            zones[(t, g[1])] = {"posture": g[2], "fr": int(g[3]), "fr_n": int(g[4]), "fr_melee": int(g[5]),
                                "fr_ranged": int(g[6]), "en": int(g[7]), "en_n": int(g[8]), "en_melee": int(g[9]),
                                "en_ranged": int(g[10]), "hp": int(g[11]), "maxhp": int(g[12])}
            continue
        m = RE_ATTEMPT.search(rest)
        if m:
            pending = {"turn": t, "city": m.group(2), "req": int(m.group(3)), "exp": int(m.group(4)), "xy": None}
            continue
        m = RE_PLAN.search(rest)
        if m and pending and pending["city"] == m.group(1):
            pending.setdefault("plans", []).append({"sim": int(m.group(3)), "plan": int(m.group(4)),
                                                    "attacks": int(m.group(5)), "city_attacks": int(m.group(6))})
            continue
        m = RE_TACTSIM.search(rest)
        if m and pending and pending["xy"] is None:
            pending["xy"] = (int(m.group(1)), int(m.group(2)))
            continue
        m = RE_DONE.search(rest)
        if m:
            a = pending if pending and pending["city"] == m.group(1) else {"turn": t, "city": m.group(1), "req": None,
                                                                            "exp": None, "xy": None}
            a.update({"hp0": int(m.group(2)), "hp1": int(m.group(3)), "used": int(m.group(4)), "avail": int(m.group(5)),
                      "agg": int(m.group(6)), "captured": bool(m.group(7))})
            d = RE_DEFENCE.search(rest)
            if d:
                a.update({"strength": int(d.group(1)), "walls": int(d.group(2)), "garrison": d.group(3),
                          "ghp0": int(d.group(4)), "ghp1": int(d.group(5))})
            if a["xy"]:
                city_xy.setdefault(a["city"], a["xy"])
            attempts.append(a)
            pending = None
            continue
        m = RE_REFUSE.search(rest)
        if m:
            refusals[(t, m.group(1))] += 1
            city_xy.setdefault(m.group(1), (int(m.group(2)), int(m.group(3))))
            continue
        m = RE_TOOEARLY.search(rest)
        if m:
            tooearly.append((t, m.group(1), int(m.group(2)), int(m.group(3))))
            continue
        m = RE_KILLED.search(rest)
        if m:
            killed[kind_of(m.group(1))] += 1
            continue
        if rest.startswith("Pillaging "):
            loot["pillages"] += 1
            continue
        m = RE_PILLAGE_GOLD.search(rest)
        if m:
            loot["pillage gold lines"] += 1
            loot["pillage gold"] += int(m.group(1))
            continue
        m = RE_PLUNDER_GOLD.search(rest)
        if m:
            loot["plunders"] += 1
            loot["plunder gold"] += int(m.group(1))

    # the attack operations that went for a city we attacked or refused (target within 2 plots of the city)
    xy_city = {xy: c for c, xy in city_xy.items()}
    def op_city(o):
        if not o["target"]:
            return None
        best = None
        for c, xy in city_xy.items():
            d = plotdist(o["target"], xy)
            if d <= 2 and (best is None or d < best[0]):
                best = (d, c)
        return best[1] if best else None
    for o in ops.values():
        o["city"] = op_city(o)
        o["mix"] = collections.Counter(kind_of(n) for n in o["units"].values())
    return {"ops": dict(ops), "attempts": attempts, "refusals": refusals, "zones": zones, "tooearly": tooearly,
            "killed": killed, "city_xy": city_xy, "loot": loot}


def pct(a, b):
    return "%d%%" % round(100.0 * a / b) if b else "-"


def med(xs):
    return statistics.median(xs) if xs else 0


def main():
    games = af.games_from_csvs()
    rows = []
    for gdir in sorted(glob.glob(os.path.join(RESULTS, "logs_*"))):
        gid = os.path.basename(gdir)[len("logs_"):]
        info = games.get(gid)
        if not info:
            continue
        kind = "flipped" if len(gid) == 17 else "first"
        stage, _, _ = af.classify(gdir, info)
        s = study(gdir, info)
        s.update({"gid": gid, "kind": kind, "stage": stage, "info": info})
        rows.append(s)

    groups = collections.OrderedDict()
    for r in rows:
        key = "%s / %s" % ("first (RoleFixes)" if r["kind"] == "first" else "flipped (CP)",
                           "captured" if r["stage"] == 6 else "not taken" if r["stage"] == 5 else
                           "refused" if r["stage"] == 4 else "earlier")
        groups.setdefault(key, []).append(r)

    print("AT THE WALLS: %d logged bully games with an aggressor\n" % len(rows))
    for key in sorted(groups):
        rs = groups[key]
        ops = [o for r in rs for o in r["ops"].values() if o["units"]]
        att_ops = [o for o in ops if o["city"]]
        mixes = collections.Counter()
        for o in ops:
            mixes.update(o["mix"])
        sizes = [sum(v for k, v in o["mix"].items() if k != "civilian") for o in ops]
        sieges = [o["mix"]["siege"] for o in ops]
        reasons = collections.Counter(o["reason"] for o in ops if o["reason"])
        atts = [a for r in rs for a in r["attempts"]]
        with_exp = [a for a in atts if a.get("exp") is not None]
        dmg = [a["hp0"] - a["hp1"] for a in atts]
        print("== %s: %d games, %d attack ops with units (%d aimed at a city we later attacked/refused)" %
              (key, len(rs), len(ops), len(att_ops)))
        print("   army per op: median %s units (max %s), siege median %s, ops with 0 siege %s, with 2+ siege %s" %
              (med(sizes), max(sizes) if sizes else 0, med(sieges), pct(sum(1 for x in sieges if x == 0), len(sieges)),
               pct(sum(1 for x in sieges if x >= 2), len(sieges))))
        tot = sum(v for k, v in mixes.items() if k != "civilian")
        print("   unit mix recruited: " + ", ".join("%s %s" % (k, pct(mixes[k], tot)) for k in
                                                    ("melee", "ranged", "mounted", "siege")) + " (of %d)" % tot)
        print("   ops ended: " + ", ".join("%s %d" % kv for kv in reasons.most_common()))
        if atts:
            print("   capture attempts %d: expected >= city HP %s; expected median %s vs HP median %s; damage done median %s,"
                  " zero damage %s; units used median %s (0 used: %d)" %
                  (len(atts), pct(sum(1 for a in with_exp if a["exp"] >= a["req"]), len(with_exp)),
                   med([a["exp"] for a in with_exp]), med([a["req"] for a in with_exp]), med(dmg),
                   pct(sum(1 for d in dmg if d <= 0), len(dmg)), med([a["used"] for a in atts]),
                   sum(1 for a in atts if a["used"] == 0)))
            ratio = [(a["hp0"] - a["hp1"]) / a["exp"] for a in with_exp if a["exp"] > 0]
            print("   damage done / expected: median %.2f" % med(ratio))
            planned = [a for a in atts if a.get("plans")]
            if planned:
                atk = [sum(p["city_attacks"] for p in a["plans"]) for a in planned]
                print("   plans logged %d: attacks on the city per attempt median %s, attempts with none %s; units in the sim median %s"
                      % (len(planned), med(atk), pct(sum(1 for x in atk if x == 0), len(atk)),
                         med([a["plans"][0]["sim"] for a in planned])))
            dfn = [a for a in atts if "strength" in a]
            if dfn:
                print("   city defence at attempts (%d): strength median %s, walls in %s; garrison hit in %s, garrison HP lost median %s"
                      % (len(dfn), med([a["strength"] for a in dfn]), pct(sum(1 for a in dfn if a["walls"] > 0), len(dfn)),
                         pct(sum(1 for a in dfn if a["ghp0"] > a["ghp1"]), len(dfn)), med([a["ghp0"] - a["ghp1"] for a in dfn])))
        zs = [z for r in rs for z in r["zones"].values()]
        if zs:
            att_z = []
            for r in rs:
                for a in r["attempts"]:
                    z = r["zones"].get((a["turn"], a["city"]))
                    if z:
                        att_z.append(z)
            if att_z:
                print("   zone at attempts (%d): our units median %s vs theirs %s; our strength / theirs median %.2f; "
                      "city max HP median %s" % (len(att_z), med([z["fr_n"] for z in att_z]), med([z["en_n"] for z in att_z]),
                                                 med([z["fr"] / max(1, z["en"]) for z in att_z]), med([z["maxhp"] for z in att_z])))
        ref = collections.Counter()
        ref_z = []
        for r in rs:
            att_cities = {o["city"] for o in r["ops"].values() if o["city"]}
            for (t, c), n in r["refusals"].items():
                if c in att_cities:
                    ref[c] += 1
                    z = r["zones"].get((t, c))
                    if z:
                        ref_z.append(z)
        if ref:
            print("   refusals at cities our attacks aimed at: %d turns over %d cities" % (sum(ref.values()), len(ref)))
        if ref_z:
            print("   zone when refused (%d): our units median %s vs theirs %s (plus the city); our strength / theirs median %.2f"
                  % (len(ref_z), med([z["fr_n"] for z in ref_z]), med([z["en_n"] for z in ref_z]),
                     med([z["fr"] / max(1, z["en"]) for z in ref_z])))
        te = [x for r in rs for x in r["tooearly"]]
        if te:
            print("   'too early' (13-turn healing rule): %d turns, expected median %s vs HP %s" %
                  (len(te), med([x[3] for x in te]), med([x[2] for x in te])))
        lt = collections.Counter()
        for r in rs:
            lt.update(r["loot"])
        gold_games = sum(1 for r in rs if r["loot"]["pillage gold lines"] or r["loot"]["plunders"])
        print("   pillage: %d pillages (%.1f a game, games with none %d of %d)%s" %
              (lt["pillages"], lt["pillages"] / max(1, len(rs)), sum(1 for r in rs if not r["loot"]["pillages"]), len(rs),
               "; gold logged in %d games: pillage %d gold over %d pillages, plunder %d gold over %d routes" %
               (gold_games, lt["pillage gold"], lt["pillage gold lines"], lt["plunder gold"], lt["plunders"]) if gold_games else
               " (no pillage gold logged on these builds)"))
        k = collections.Counter()
        for r in rs:
            k.update(r["killed"])
        if k:
            print("   own units killed: " + ", ".join("%s %d" % kv for kv in k.most_common()))
        print()

    if SHOW_GAMES:
        for r in rows:
            print("-- %s %s %s stage %d (%s)" % (r["gid"], r["kind"], r["info"]["civ"], r["stage"] + 1, r["info"]["build"]))
            for oid, o in sorted(r["ops"].items(), key=lambda kv: kv[1]["start"] or 0):
                if not o["units"]:
                    continue
                print("   op %s T%s-%s %s -> %s, handed over near %s far %s: %s" %
                      (oid, o["start"], o["end"], o["reason"], o["city"] or o["target"], o["near"], o["far"],
                       ", ".join("%s %d" % kv for kv in o["mix"].most_common())))
            for a in r["attempts"]:
                print("   T%d %s: HP %d -> %d, expected %s, %d of %d used%s" %
                      (a["turn"], a["city"], a["hp0"], a["hp1"], a["exp"], a["used"], a["avail"],
                       ", CAPTURED" if a["captured"] else ""))


if __name__ == "__main__":
    main()
