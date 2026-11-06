"""Attack funnel: where does each aggressor's attack die, counted over every logged bully game.

The user (2026-11-04): don't play whack-a-mole with single games; look for patterns over many matches. This reads every
results/logs_<GameId>/ folder whose game has an aggressor (Role = aggressor in a results CSV) and puts each game at the
deepest stage its aggressor reached:

  1 no build-up     no TimingBuildup window ever opened (first games) / no attack operation ever formed (flipped games)
  2 no attack op    a window opened, but no city attack operation formed
  3 no war          attack operations formed, but the aggressor declared no war
  4 never at walls  at war, but its units never got a city in reach (no capture attempt, no zone refusal)
  5 refused         at war, but tactics only refused cities ("enemy dominated zone - won't try to capture"); the
                    refusals can include its own cities' defence, so read it as "never tried a capture"
  6 not taken       capture attempts, no city taken
  7 captured        took at least one city (with the first snapshot turn that shows a capture; snapshots are every
                    10 turns, so "T100" means the city fell between T91 and T100)

For each stage it also counts the signals that point at causes: window pauses for gold, "too weak" give-ups, windows
ended with no war, and how the aggressor's city attack operations ended (TimedOut, NoUnits, DiploOpinionChange, ...).
First games (RoleFixes) and flipped games (CP's AI) are counted apart, by build.

    python3 tools/ab/attack_funnel.py [results dir]
"""
import collections
import csv
import glob
import os
import re
import sys

RESULTS = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
STAGES = ["no build-up", "no attack op", "no war", "never at walls", "refused", "not taken", "captured", "attacked first"]
ATTACK_OP = re.compile(r"OP_CITY_ATTACK_\w+")


def games_from_csvs():
    """GameId -> (aggressor civ key, build, run name) from every results CSV with an aggressor role."""
    out = {}
    first_capture = {}   # GameId -> first snapshot turn with CitiesCaptured > 0
    for f in glob.glob(os.path.join(RESULTS, "AIABTest_*.csv")):
        run = os.path.basename(f)[len("AIABTest_"):-4]
        with open(f, encoding="utf-8-sig", newline="") as fh:
            for r in csv.DictReader(fh):
                if r.get("Role") != "aggressor":
                    continue
                g = r["GameId"]
                t = int(r["Turn"] or 0)
                if int(r.get("CitiesCaptured") or 0) > 0:
                    first_capture[g] = min(first_capture.get(g, t), t)
                prev = out.get(g)
                if prev is None or t >= prev["turn"]:
                    out[g] = {"civ": r["Civ"].replace("CIVILIZATION_", ""), "build": run.split("@")[0],
                              "run": run, "turn": t, "wars": int(r.get("WarsDeclared") or 0),
                              "captured": int(r.get("CitiesCaptured") or 0),
                              "warsOnUs": int(r.get("WarsOnUs") or 0)}
    for g, t in first_capture.items():
        if g in out:
            out[g]["firstCapture"] = t
    return out


def log_name_matches(civkey):
    """A matcher for the civ's name as the logs write it ("The_Aztecs", "Mongolia", "The Zulus")."""
    stem = civkey.lower()[:5]
    return lambda name: stem in name.lower().replace("_", " ").replace("the ", "")


def lines(path, is_ours):
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            parts = line.split(",", 2)
            if len(parts) == 3 and is_ours(parts[1]):
                yield parts[2]


def classify(gdir, info):
    ours = log_name_matches(info["civ"])
    sig = collections.Counter()
    ends = collections.Counter()
    window = attack_op = False
    for path in glob.glob(os.path.join(gdir, "*.csv")):
        for rest in lines(path, ours):
            if "TimingBuildup: window opens" in rest:
                window = True
            if "window paused, units unaffordable" in rest:
                sig["window paused for gold (turns)"] += 1
            if "no war 3 windows after the build-up" in rest:
                sig["gave up: no war after 3 windows"] += 1
            if "SiegeArmy: still too weak" in rest:
                sig["SiegeArmy too weak, gave up"] += 1
            if "won't try to capture" in rest:
                sig["zone refusals (turns)"] += 1
            if "attempting capture of" in rest:
                sig["capture attempts"] += 1
            m = ATTACK_OP.search(rest)
            if m:
                attack_op = True
                e = re.search(r"Ended: (\w+)", rest)
                if e:
                    ends[e.group(1)] += 1
    flip = len(os.path.basename(gdir)) == len("logs_") + 17   # 16 hex digits, plus F for the flipped game
    if info["captured"] > 0:
        stage = 6
    elif sig["capture attempts"]:
        stage = 5
    elif sig["zone refusals (turns)"] and info["wars"]:
        stage = 4
    elif info["wars"]:
        stage = 3
    elif info["warsOnUs"]:
        stage = 7   # declared no war itself, but was at war: declared on first (Diplomacy, 2026-11-05)
    elif attack_op:
        stage = 2
    elif window:
        stage = 1
    else:
        stage = 0
    return stage, sig, ends


def main():
    games = games_from_csvs()
    table = collections.defaultdict(lambda: {"n": 0, "stages": collections.Counter(), "sig": collections.Counter(),
                                             "ends": collections.Counter(), "games": collections.defaultdict(list),
                                             "capTurns": []})
    for gdir in sorted(glob.glob(os.path.join(RESULTS, "logs_*"))):
        gid = os.path.basename(gdir)[len("logs_"):]
        info = games.get(gid)
        if not info:
            continue
        kind = "flipped" if len(gid) == 17 else "first"
        stage, sig, ends = classify(gdir, info)
        key = (info["build"], kind)
        t = table[key]
        t["n"] += 1
        t["stages"][stage] += 1
        t["sig"].update(sig)
        t["ends"].update(ends)
        t["games"][stage].append("%s %s" % (gid[:8], info["civ"].title()))
        if "firstCapture" in info:
            t["capTurns"].append(info["firstCapture"])
    for (build, kind), t in sorted(table.items()):
        print("== run %s, %s games (%s): %d logged" % (build, kind, "RoleFixes" if kind == "first" else "CP's AI", t["n"]))
        for i, name in enumerate(STAGES):
            if t["stages"][i]:
                print("   %d. %-15s %2d  %s" % (i + 1, name, t["stages"][i], ", ".join(t["games"][i][:6])))
        if t["sig"]:
            print("   signals: " + "; ".join("%s %d" % kv for kv in sorted(t["sig"].items())))
        if t["capTurns"]:
            ct = sorted(t["capTurns"])
            print("   first capture by snapshot turn: %s (by T100: %d of %d logged)" % (
                ", ".join("T%d" % x for x in ct), sum(1 for x in ct if x <= 100), t["n"]))
        if t["ends"]:
            print("   attack ops ended: " + ", ".join("%s %d" % kv for kv in t["ends"].most_common()))
    print()
    for want, label in (("first", "first games (RoleFixes)"), ("flipped", "flipped games (CP's AI)")):
        tot, sig, ends, n = collections.Counter(), collections.Counter(), collections.Counter(), 0
        for (build, kind), t in table.items():
            if kind == want:
                tot.update(t["stages"]); sig.update(t["sig"]); ends.update(t["ends"]); n += t["n"]
        print("All %s, every run: %d logged" % (label, n))
        for i, name in enumerate(STAGES):
            print("   %d. %-15s %2d" % (i + 1, name, tot[i]))
        print("   signals: " + "; ".join("%s %d" % kv for kv in sorted(sig.items())))
        print("   attack ops ended: " + ", ".join("%s %d" % kv for kv in ends.most_common()))


if __name__ == "__main__":
    main()
