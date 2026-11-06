# AI A/B test results

## Scoreboard

One row per milestone build: where the AI stands against each goal in [AGENTS.md](AGENTS.md). Rows are filled
from `Summarize-ABTest.ps1 -MyGames tools\ab\results -Scoreboard`, which prints one row per results file.

| Build | Setup | Strength share (games) | Aggressor's share of all cities, end (bully test) | Cities per aggressor war | Coalition: civs at war with it at the end; turns from its first conquest to 2+ | Deals per civ per 10 turns | Banned behaviours per game | Seconds per AI turn |
|---|---|---|---|---|---|---|---|---|
| **Goal** (agreed with the players, 2026-11-02; strength raised to 60% on 2026-11-03) | King, even rules | **≥ 60%** against CP | **≤ 20%** (a fair share with 8 civs is 12.5%) | **≤ 1** | **2+ civs within 20 turns** | **0.5–2** (a lively world without spam; check against the first measurement) | **0** | **≤ 1.25× B's** |
| A: CP | | 50% (reference) | not measured | not measured | not measured | not measured | not measured | not measured |
| B: batch 2p (`24cc575`) | Prince, even rules, random maps, single games | 52.4% ± 0.7 against CP (5) | not measured | not measured | not measured | not measured | not measured | not measured |
| c4 (`ea22df3`), best C so far | same | 51.6% ± 1.1 against B (6) | not measured | not measured | not measured | not measured | not measured | not measured |
| c7c (`2e9fad1`), newest C | same | 49.4% ± 1.1 against B (10) | not measured | not measured | not measured | not measured | not measured | not measured |
| c7c_roles (`6b8ebde`): the bundle again, with every measure | King, even rules, Pangaea, Strategic Balance, no ruins, pairs | waiting for games | waiting for the bully test | | | | | |

- **The diplomacy, war and timing columns** only exist from build `c7c_roles` on. Older builds can't
  be filled in.
- **"Strength share" is against whatever the test group was compared with:** CP for stage 1, B for C builds.
  At King, "strength against CP" needs an A-vs-B build (`kABTestVersusBase = false`, AGENTS.md), so that
  number is re-measured when a milestone is frozen.
- **Done** when every goal holds in the same build, at King, under the standard setup, plus the friends'
  verdict after real multiplayer games (AGENTS.md: no obvious blunders, a conqueror pays for every city).

Everything the A/B test games have shown up to 2026-11-02: each build, its results, and what we learned.
[README.md](README.md) explains how to run the tests. [AUDIT.md](AUDIT.md) lists the batch 1 and batch 2a–2e fixes.

The raw results are in [results/](results/), one CSV per build, copied unchanged from
`Documents\My Games\Sid Meier's Civilization 5`. To re-run the summary on those copies:

```
powershell -ExecutionPolicy Bypass -File tools\ab\Summarize-ABTest.ps1 -MyGames tools\ab\results
```

## How games are judged

- **Test games:** AI-only, Prince, Standard map, 8 civs on separate teams, Quick pace, Quick Combat and
  Quick Movement on, observer mode. They stop at turn 150. Games that end before turn 100 aren't counted.
- **Strength share (the verdict).** For each of techs, population, land, military and cities, take the
  test group's total as a share of all major civs' total. The strength share is the mean of those five
  shares, from the last logged turn; 50% means even. Civ's own score is printed alongside but not used,
  because religion (20 points per belief) and wonders inflate score far more than they add power.
- **No-military share:** the same, without military. It was added for the greedy builds (c6 on), which
  skip units on purpose.
- **p-value:** a one-sided t-test on the per-game strength shares ("chance the new group is really no
  stronger"). The sign test on wins and losses is also printed, but it throws away the margins.
- **Bar to freeze a build:** p < 5%, which works out to roughly 9+ wins in 10 games, or a steady edge
  over about 5 games. The user's goal is to iterate until a build passes the bar, freeze it as the new
  base, and repeat.
- **How big a real edge is:** a good build sits around 51.5–52.5%. Single games swing ±5 points, so one
  game alone says almost nothing about a build.

## The A/B/C ladder

| Rung | What | Where |
|---|---|---|
| **A** | Community Patch's original AI ("cp") | fork `treezeegaga/Community-Patch-DLL`, code outside `UsesNewAI()` |
| **B** | batch 2p, frozen 2026-11-02 after beating A 5-0 (52.4% ± 0.7, p 1%) | fork commit `24cc575` on branch `claude/sleepy-hopper-x77moh` |
| **C** | candidate changes tested against B | fork branch `claude/ab-c1`, branched from `24cc575` |

Stage 1 compared the new AI against A. Stage 2 compares C against B.

### How groups are picked (fork `CvGameCoreDLL_Expansion2/CvPlayer.cpp`, near `CvPlayer::UsesNewAI`)

- `kABTestVersusBase` is a compile-time switch.
  - **false** (stage 1, branch `claude/sleepy-hopper-x77moh`): `UsesNewAI()` is true for a major civ
    when `(mapRandomSeed + playerID)` is odd. That's half the civs, flipping with the seed, so each slot
    plays both sides over many games. The CSV labels the groups `new` and `cp`.
  - **true** (stage 2, branch `claude/ab-c1`): `UsesNewAI()` is true for every civ, so everyone runs B.
    `UsesCandidateAI()` picks the half that also runs the C changes. The CSV labels the groups `c` and
    `b`.
- Outside a test game (`MOD_AI_AB_TEST` off), both functions return true for everyone.
  - **Caution:** a non-test pack built from `claude/ab-c1` would give every civ the C changes, untested
    ones included.

#### Warmonger-balanced split (`IsABTestCandidateSlot`, added in c4)

1. **Who counts as a warmonger** (`IsABTestWarmongerCiv`):
   - a civ with the warmonger trait; or
   - a civ whose `FLAVOR_OFFENSE` is 8 or more and at least its science and culture flavors, unless it
     has the nerd, smaller or tourism trait.
2. **Flavors vary per game.** They come from `GetPersonalityIndividualFlavor`, and CP shifts
   personality flavors by up to ±2 per game (`CvFlavorManager::RandomizeWeights`,
   `FLAVOR_RANDOMIZATION_RANGE`). So a borderline leader can count as a warmonger in one game and not
   the next. Trait warmongers always count.
3. **Ordering:**
   - Take the AI majors in two passes, warmongers first, then everyone else.
   - Within each pass, the order is rotated by the map seed: player `(seed + i) % MAX_MAJOR_CIVS`.
4. **Dealing:** go down that list, alternating c, b, c, b…
5. **Result:**
   - With 8 civs, each group always gets 4.
   - With W warmongers, c gets ceil(W/2) and b gets floor(W/2).
   - c has a warmonger whenever the game has any; b has one only when there are 2 or more.
6. **Recomputed every turn** (cached by seed and turn), so a reloaded save gets the same split.
7. **Observed draws:** every lineup checked from c4 on had at least one c warmonger.
   - c4 game 1: Poland (c) and the Huns (b).
   - c5 game 1: the Ottomans (c) and Assyria (b).
   - c5b game 1: the Aztecs and China (c).
   - c6 game 1: 3 in c, 2 in b.
   - c6 game 2: Persia and Japan (c).
   - c7 game 1: Denmark and the Mongols (c).
8. **b's warmongers are inferred.** The CSV has no warmonger column, and b's warmongers don't follow
   c's research line, so their tech picks don't reveal them.
9. **Why it exists:** before c4 the split was by parity, and random civ draws often gave c no warmonger,
   which left the conquest changes untested.

## Stage 1: new AI (B candidates) vs CP

Fork branch `claude/sleepy-hopper-x77moh`. CI publishes each push as release `ab-<sha>`, plus `ab-latest`.
Each batch includes everything before it.

| Batch | Fork commit | Change | Games | Strength share | p | Verdict |
|---|---|---|---|---|---|---|
| first build | `7aecbfe` | the split only, no AI changes (luck baseline) | — | no results file on this PC | | |
| 1 | `6fd3058` / `80746d8` | 11 audited bug fixes (AUDIT.md) | — | no results file on this PC | | |
| 2a, 2b | `5539cfb`, `8eaf65e` | opening book; fog cheats removed, 10 more fixes | 0 | don't compile (missing include, fixed in 2c) | | |
| 2c, 2d | `345b615`, `25c26d8` | settler escorts and travel time; nearby cities help build armies | 0 | replaced before their builds ran | | |
| 2e | `60b57a0` | combat scoring (danger, tied escape moves, wider search); first full bundle | 5 | 46.3% ± 3.6 | 82% | worse. New-AI civs often stalled on 1 city |
| 2f | `dbe370e`, `4edacf2` | settlers no longer idle when the site ranking finds nothing; direct-path travel times | 1 | 27.1% | | much worse (stall theory wrong) |
| 2g | `0c6a900`, `47b2d5f` | buy settlers with gold (none had ever been bought), no scout purchases, book settlers wait for growth | 1 | 43.8% | | worse |
| 2h | `fd2c64b` | one settler at a time | 0 | folded into 2i | | |
| 2i | `fb324ce` | **ROOT CAUSE FIX:** found-city operations no longer need a spare military unit | 1 | 48.0% | | close to even |
| 2j | `bc38d23` | save gold for the next settler first | 3 | 47.7% ± 4.1 | 69% | not better. Lost on score 0-3: CP founded 4 of 5 religions |
| 2k | `b38a4fa` | keep saving while a settler walks; conquest opening retired | 0 | folded into 2l | | |
| 2l | `f237af9` | early shrine in the opening book | 1 | 53.5% | | promising |
| 2m | `37572bb` | settlers go unescorted after 5 turns with no danger (max 15) | 5 | 50.4% ± 1.8 | 42% | even |
| 2n | `f07a917` | book settlers wait only for imminent growth | 4 | 50.7% ± 2.1 | 38% | even |
| 2o | `a899eaa` | book gives way to wonders for its later buildings | 2 | 51.6% ± 1.8 | 27% | slightly ahead |
| **2p** | **`24cc575`** | **warrior before the first settler** | **5** | **52.4% ± 0.7** | **1%** | **PASSED, 5-0. Frozen as B** |
| 2q | `7e0d730` | warmongers play the wide plan | 0 | moved into c1 | | |
| 2r | `b2cbf96` | expansionist culture civs play wide | 1 | 48.5% | | moved into c1 |
| 2s | `32433bf` | wide opening settles longer (to T130 Standard, 8 cities) | 0 | CI run cancelled; folded into 2t | | |
| 2t | `f956684` | early conquest decisions | 1 | 46.1% | | moved into c1/c3 |
| 2u | `1583e4a` | 10+ turns of idle settlers means no land left | 0 | moved into c1 | | |

Notes on stage 1:
- **Root cause of the 1-city stalls (found with diagnostic logging, fork `accdf8f`):**
  - `CvAIOperation::PreconditionsAreMet` never counts the settler for its own found-city operation,
    because `IsUnitSuitableForRecruitment` skips `UNITAI_SETTLE`.
  - So an operation only started if a spare military unit could be the escort.
  - The new AI's book built no early military, and its starting warrior explored. So `addAIOperation`
    silently discarded every operation; settlers stood idle and blocked more settlers
    (`ENOUGH_SETTLERS`).
  - Fixed in 2i: new-AI civilian operations need only a free civilian, and the book yields while a
    found-city operation waits for its escort.
- **Wrong theories before that:** `GetPlotsInReach` missing sites (2f replaced it with direct paths,
  which was harmless), the tiny-army penalty, and escorts alone.
- **After 2i, the new AI matched CP on cities, population and techs but lost on score:** CP founded 4 of
  5 religions, since the book built no shrine. The 2l shrine fixed it. A Maya settler once waited 80
  turns for an escort nobody built; that led to 2m.
- **Opening plans:** the conquest opening scored 10% against 13.4% for tall, and was retired in 2k. In
  2e–2p data, wide was the strongest plan (13.3% strength share, 5.3 cities, against 12.6% and 4.4 for
  tall).
- **2q–2u were never validated against CP.** Once 2p passed, they became c1's candidate bundle instead.

## Stage 2: C vs B

Fork branch `claude/ab-c1`. Its CI builds aren't published as releases; README.md explains how to
install one. Each C build includes everything before it unless noted. All changes apply to group c only.

| Build | Fork commit | Change | Games | c strength share | p | Verdict |
|---|---|---|---|---|---|---|
| c1 | `12aa2e1` | 2q + 2r + 2s + 2u: warmongers and expansionist culture civs wide, long wide opening, idle settler = no land | 5 | 49.1% ± 1.5 | 70% | not better |
| c2 | `3a30d17` | plan choices only (2q, 2r); long opening and idle-settler stop off | 5 | 49.0% ± 1.9 | 70% | not better |
| c3 | `d4e868b` | conquest (below) | 1 | 54.0% | | promising, but captured nothing |
| c3b | `3abbb4e` | commit to one target; skip targets with defensive allies | 1 | 39.8% | | bad game: c military 71 vs b 166 |
| **c4** | **`ea22df3`** | **warmonger siege timing attack; warmonger-balanced split** | **6** | **51.6% ± 1.1** | **10%** | **best so far, 5-1. Not frozen** |
| c5 | `effc678` | bigger warmonger army; Engineering and aqueduct x2 for all c civs | 1 | 50.0% | | even |
| c5b | `6c201ce` | Engineering and aqueducts for tall civs only | 1 | 52.3% | | ahead (no-military 52.8%) |
| c6 | `5ef069e` | greedy tall civs: army cap of cities + 1 | 3 | 46.5% ± 2.1 | 88% | worse, 0-3. Greedy civs drew wars |
| c7 | `0b3dda2` | greedy tall build order; warmongers target the greediest neighbour | 1 | 45.3% | | worse (cap still on) |
| c7b | `2caf9d0` | c7 with the army cap off | 0 | CI build hung; skipped | | |
| c7c | `2e9fad1` | c7b + can-win siege check + greedy civs refuse open borders | 7 | 50.0% ± 1.4 | 50% | not better: 3-4. SPRT gainer LLR −1.00, no-worse +0.74 (both still running) |
| c7c_flags | `46fc076`, `7097d49` | c7c with one flag per idea (see Fixes below) and a Warmonger column; `7097d49` adds paired games. With the bundle and `Flip = 0` it plays the same as c7c | 0 | | | superseded by c7c_settings before any games |
| c7c_settings | `24f6ba8`, `614af3d` | c7c_flags with the game's settings in every row (lead job 3); `614af3d` sets ruins and map options from `AIABTest.ini` (job 5). The same AI as c7c with the bundle | 0 | | | superseded by c7c_roles before any games |
| c7c_roles | `59888a3`, `4b37724`, `6b8ebde` | c7c_settings plus the bully and builders tests, diplomacy and war counts, and `TurnSecs` (lead jobs 10–11). The same AI as c7c with the bundle | 0 | | | built (CI run 41545004119); `claude/ab-c1` fast-forwarded to `6b8ebde`, so `ab-c-latest` is it once the push build finishes; the smoke-test pair and the King baseline run on it |

What each build does, in detail:
- **c1:** candidate `GetOpeningBook()`:
  - warmonger trait or expansionist → wide; nerd or smaller → tall;
  - tourism civs → wide if expansion ≥ culture;
  - offense ≥ 8 and ≥ science and culture → wide;
  - expansion ≥ 7 and > science and culture → wide;
  - otherwise tall.

  Also the long wide opening (2s) and the idle-settler stop (2u). In c1, c's tall civs ended with fewer
  cities (3.7 vs 4.4): stopping settlers after one stood idle 10 turns ended expansion that b's civs
  later completed. Switches `kCandidateLongWideOpening` (now false) and `kCandidateBoxedInBySettlers` (on
  again from c3) are in CvPlayer.cpp.
- **c3:** `CvDiplomacyAI::GetNewAIConquestTarget`. It logs `CONQUEST: going for X (reason)` lines in
  the AI logs.
  - **Expansionists** that are boxed in (no reachable site, or a settler idle 10+ turns) attack their
    blocker if it isn't stronger.
  - **Warmongers** start a timing attack from about T30 on Quick against their weakest close neighbour.
  - **Tall civs** start no wars.
  - **Why the wars now stick:** the target goes into `vPlanningWarPlayers` in `DoUpdateWarTargets`, the
    path CP uses for agreed coop wars, which skips the filters that had kept resetting 2t's WAR
    approach (`GetPlayerApproachValue(WAR) > 0`, `IsWarSane`, the early-era conflict limit).
- **c4:**
  - **Research:** warmongers go Pottery → The Wheel → Mathematics → Bronze Working → Archery → Writing.
  - **Capital book:** after the 2nd settler, 3 catapults (or the civ's own siege unit) and a spearman.
  - **When to declare:** once 2 `UNITAI_CITY_BOMBARD` units exist, with a fallback at turn 90 on
    Standard.
- **c5:**
  - **Bigger army:** the warmonger book adds 2 spearmen and 2 archers. The attack needs 2 siege units
    plus 4 other land units, or turn 90 on Standard. The first c5 commit, `e946f11`, was only this.
  - **Growth (user's idea, "growth is secretly OP"):** research Engineering once the capital is size 6
    and the book is done, and count the aqueduct's food-kept value twice.
- **c5b:** the growth push for tall-book civs only. The user's reasoning: warmongers' cities build the
  army, and wide civs build settlers.
- **c6:** tall c civs stop building land combat units once they have cities + 1, unless:
  - at war with a major; or
  - in `MILITARYAISTRATEGY_EMPIRE_DEFENSE(_CRITICAL)`; or
  - building escorts for operations.

  It's in `CvUnitProductionAI::CheckUnitBuildSanity`, behind `kCandidateGreedyArmyCap`. The user's
  reasoning: "in a world where no one is able to capture a city, the civ who builds the least military
  units wins".
- **c7:**
  - **Tall capital book (user's order):** Scout, Monument, Shrine, Warrior, Warrior, Settler, Worker,
    Settler, Settler, Library, National College, Aqueduct, University.
  - **Research:** Pottery, Writing, Philosophy, Engineering, Education.
  - **Book length:** the tall book runs to T130 Standard (about T87 on Quick).
  - **Targeting:** warmongers score targets by fewest land units per city, +50 for neighbours.
- **c7b:** `kCandidateGreedyArmyCap = false`.
- **c7c** (`04c954c` → `831ae8e` → `a8f4cf7` → final `2e9fad1`):
  - **Can-win check (user's "only fight battles you know you will win"):** `CanTakeNearestCity` in
    CvDiplomacyAI.cpp. It takes the target's city nearest our capital and needs 2+ melee units. It then
    simulates up to 20 turns:
    - every live ranged land unit fires (`GetRangeCombatDamage`);
    - the city heals `CITY_HIT_POINTS_HEALED_PER_TURN` (20 in CP);
    - the city hits our most damaging ranged unit for 1.5x its ranged damage, to cover the garrison.

    War only goes ahead if the city reaches 0 HP within 20 turns. Earlier versions used fire ≥ 40% of
    city HP per turn. The user corrected that: siege length doesn't matter, survivability does, and
    later sieges take longer.
  - **Closed borders (user: greedy players avoid open borders):** tall c civs never give open borders
    to majors (`CvDealAI::GetOpenBordersValue` returns `INT_MAX` for the giving side).

### c7c results

**Game 1** (`0222211E`, logging on): **c 52.9%** strength (no-military 52.8%), score c 580 vs b 560.
Its first launch failed ("main menu never showed"), and the retry ran normally.

| | Civs |
|---|---|
| **c** | China (warmonger, wide); Egypt, Sweden, India (tall, greedy) |
| **b** | Mongols, Polynesia, Iroquois (wide); Ethiopia (tall) |

- **The can-win check delayed the war.** China picked the Iroquois at T55 ("warmonger timing attack,
  greediest neighbour") but only declared at T81, 26 turns later, presumably waiting until the check
  passed.
  - It attempted Osininka from T81 to T102, with expected damage per turn of 55, 128, 73 and then 38
    against 200 needed. The usual bleed-out.
  - No city changed hands in the whole game.
  - China still finished with 6 cities, 52 population (the most) and military 194.
- **The greedy tall civs were left alone this time.**
  - Nobody declared on Egypt, Sweden or India. The only other war was India declaring on China at T144.
  - Egypt reached 6 cities, Sweden 47 population. The c7c closed-borders rule was in force.
- **The b Mongols stalled.** They were stuck on 8 techs from T60 to T150 and ended with 13 population and
  5 cities. That flatters c's share; the cause wasn't investigated.
- **Ethiopia (b) led on score (795)** through religion: first pantheon T10, first religion T37. It had
  4 cities but military 235. Polynesia (b) founded the other religion; c founded none.
- **One game is not a verdict.** c7c needs about 5 more games, with logging off after game 2.

## City captures

These are all the city losses in the result files: a civ's city count dropped between two 10-turn
snapshots. The "probable taker" is a civ that gained a city in the same window. That's an inference,
because a gain can also be a new settlement. Losses with no gainer could be to city-states or barbarians,
or a city razed.

| Results file | Game | When | Lost | Probable taker | What's known |
|---|---|---|---|---|---|
| batch2n | 02FB492B | T111–120 | Japan (cp) 6→5 | Spain (new) 5→6, military 193 vs 120 | logging off |
| batch2n | 031D3FCB | T141–150 | Carthage (new) 5→4 | none | |
| batch2t | 002FAEAF | T111–120 | Japan (new) 4→3, military 45 | Poland (new) 6→7 or Shoshone (new) 4→6 | Japan's 2t early conquest attacked fast-expanding Poland and was crushed |
| c1 | 004A8B99 | T91–110 | **Egypt (b) 3→0, eliminated** | **Huns (b)** 7→8→10, military 161–171 vs Egypt's 18–63; China (c) 5→7 and Korea (c) 3→4 in the same window | the only elimination. CP's own war logic (both civs b). The Huns ended with 11 cities, military 350 |
| c2 | 009C15B4 | T131–140 | Aztecs (b) 5→4, military 62 | China (b) 3→4, military 244, or Germany (b) 2→3 | logging off |
| c2 | 009C15B4 | T141–150 | China (b) 4→3 | none | |
| c2 | 00B10DE3 | T131–140 | Assyria (b) 3→2 | none | |
| c6 | 015D85F3 | ~T120 | Aztecs (c) lost Xochicalco, 7→6, military 69 | **Inca (b)**, per the AI log | Inca declared about T109. The Inca's city count didn't rise that window, so the city was probably razed or the count lagged |
| c7 | 01800DBC | T121–130, T141–150 | Denmark (c) 4→3→2, military 30→17 | **Mongols (c)** 5→6→7, military 182–206 | Denmark started its own war on Portugal (c) at T81, Egypt (b) joined T102, the Mongols declared T112 and besieged Kaupang for about 10 turns |

That's about 11 lost cities in about 60 games, and only one civ eliminated. **The candidate conquest code
(c3–c7) has never captured a city from b.** Its only capture was the Mongols (c) taking Denmark's cities,
and Denmark is also c.

### Why wars almost never take cities

These are seen in the AI logs (`PlayerTacticalAILog.csv`, `OperationalAILog.csv`, `MilitaryAILog.csv`)
unless marked as suspected.
1. **War is declared before the army exists.**
   - c4 game 2: Greece (Offense 10) got The Wheel at T19 and its first catapult at T58. It declared on
     the Iroquois at T77. The attack operation only formed at T85, with 2 catapults and a warrior in a
     9-slot formation filled to about 5 by T97, and it arrived at T101.
   - c3: England declared at T93 with almost no army. 59 military at T130.
2. **The tactical AI won't commit.** It logs "is in enemy dominated zone - won't try to capture". Melee
   units attack a city only if they deal more damage than they take. Siege units are held back from
   enemy-dominated zones.
3. **The army bleeds out.** c5 game 1, the first real siege:
   - The Ottoman army of 5 (2 warriors, a spearman, an archer, a catapult) formed at T56, before the
     war, and declared on Siam at T64.
   - The tactical AI planned "required damage 200, expected max damage per turn 161" on Muang Saluang.
   - By T66–74 that fell to about 65 a turn as units got hurt, below the city's healing. The city held.
4. **Ranges favour the city early.** In this pack (CP only), catapults, trebuchets and cannons have
   range 2, the same as cities. Artillery is the first siege unit with range 3. So every early siege
   takes city fire, and survivability decides it. Cities heal 20 HP a turn. The user suggested an
   artillery beeline for longer games, but at T150 Quick civs have only about 25–30 techs, so it's out
   of reach.
5. **Wrong targets.**
   - c warmongers often picked other c civs:
     - c5b: the Aztecs and China picked each other.
     - c6 game 1: China declared on Indonesia.
     - c7: Denmark picked Portugal, the "greediest neighbour", which was also c.
   - CP's own war logic also declares wars with no `CONQUEST` line (Japan in c6 game 2, Denmark in c3b),
     and those are usually two-front messes.
6. **Defensive pacts pull in third parties.** c3: Portugal joined England's war on Sweden. c3b skips
   targets with defensive allies.
7. **Short games.** At T150 on Quick, armies are still small.
8. **What the captures had in common:** the taker had 3–10x the defender's military, and the defender was
   usually already at war elsewhere (Huns 166 vs Egypt 18; Mongols 182 vs Denmark 30).
9. **Strength is judged with full knowledge:** CP uses `GetMilitaryMight`, so hiding units doesn't fool
   it.

### The greedy problem (c6, c7)

- **Greedy tall c civs drew wars.** In c6 game 3 Ethiopia was declared on by America, France and Assyria
  (twice). In c6 game 2 Japan (c) and later the Ottomans (b) attacked Egypt (c, greedy). Egypt ended with
  3 cities.
- **The cap traded economy for being a target.** c6's no-military share (48.1%) was also below 50%, so
  greed didn't even pay off in economy.
- **The user's model of the equilibrium:** all civs compete to be the most greedy until warmongers get a
  window to conquer them. So greedy civs need an alarm, and warmongers need to strike the greediest
  neighbour quickly.

## Ideas not built yet

- **c8:** keep the greedy army cap, but add an alarm: walls and archers when a close neighbour, especially
  a warmonger, masses an army or siege units.
- Declare war only once the attack army has gathered at its muster point.
- Warmongers target only b civs or a runaway leader: a coalition against the leader through CP's
  coop-war system.
- Unique-unit timing attacks (Zulu Impi at Civil Service, Hun battering rams).
- Artillery or Dynamite beeline as a later warmonger timing. Needs games longer than T150.
- A religion-free score, if score and strength keep diverging. The user decided against a
  "progress toward victory" metric.
- Culture and tourism measurement; city-state conquest.

## Dead ends and hung builds

- **2a and 2b don't compile** (missing include). **2c and 2d** were replaced before their builds ran.
  **2h and 2k** were folded into the next batch unplayed.
- **2s's CI run was cancelled** and folded into 2t. 2q–2u were never validated against CP.
- **c1 and c2:** plan changes alone don't help (both 49.0–49.1% over 5 games). A wide or aggressive
  plan only pays off if the civ actually conquers.
- **c6's greedy cap:** 0-3, see above.
- **c7b:** its CI MSVC build step hung for 47+ minutes, against about 8 normally. `gh run cancel` had no
  effect for 2 hours, and the hung run blocked the queue, so c7c sat "pending". It only cleared with
  `gh api -X POST repos/treezeegaga/Community-Patch-DLL/actions/runs/<id>/force-cancel`. c7c includes
  all of c7b, so c7b was never played.
- **Superseded downloads, never installed:** c5 `e946f11`, and the c7c intermediates `831ae8e` and
  `a8f4cf7`. Always check the artifact name's sha before installing (e.g.
  `VP_MSVC_Release_24cc575-15-g2e9fad187` = `2e9fad1`).

## Fragile or half-finished tooling

- **CI cancels:** a plain `gh run cancel` often doesn't stop a run, and runs on a branch queue behind each
  other. Use the force-cancel API above (README.md, "Stuck or queued runs"). Only one run per branch waits:
  a newer one replaces the pending one, which then shows as cancelled (seen 2026-11-02, harmless).
- **`Run-Games.ps1` click positions are hard-coded** for a 3840x2160 screen at 150% scaling, with Civ
  opening its window centred. Windowed Civ only takes clicks where it first opened, so setup happens
  there and the window is moved afterwards with title-bar-drag messages. Quick Combat and Quick
  Movement must be ticked every game.
- **Stalls:** after `-StallMinutes` (30) with no new results rows, `Run-Games.ps1` kills and restarts
  Civ. It saves `stall-*.png` and Civ's responding state.
- **AI logs are overwritten by each new game.** Copy `Logs\` between games if you need an earlier game's
  log (c4 game 1's log was lost this way). Logging costs about 15% speed, so the practice was: on for
  the first 2 games of a bundle, then off. Test games read `LoggingEnabled` and `AILog` from
  `config.ini` (fork `4cf291b`); before that, the test pack wrote no AI logs.
- **The results CSV had no warmonger column** before `c7c_flags`, so b's warmongers in older files can't be
  identified afterwards. The `Book` column records the opening plan.
- **`Summarize-ABTest.ps1` relabels B-vs-C files:** in its output, "new" means c and "cp" means b. It
  says so at the top of each B-vs-C section. Its parameters are `-Csv <file>` for one file and
  `-MyGames <folder>` for all files in a folder; there is no `-Path`.
- **`Run-ABTest.ps1` only downloads releases.** Fixed in lead job 9a: CI now publishes C and topic builds
  as releases (`ab-c-latest`, `ab-<commit>`). Builds up to `614af3d` still have to be installed by hand.
- **Side session's branch is unmerged:** pack branch `claude/angry-goodall-0e693c` ("per-change switches
  and diagnostic columns") built a batch 2r variant with per-change switches, published as fork release
  `ab-e9f7ecf`. That session reported its pack-repo changes as still unpushed, awaiting the user's OK.
  It is based on 2r, two batches behind the main line.

## Baseline

### Summary check (lead, 2026-11-02)

`Summarize-ABTest.ps1 -MyGames tools\ab\results` (run with PowerShell 7 on Linux) reproduces every
number in the stage 1 and stage 2 tables above: games, strength share, ± standard error, p and the
no-military shares, for all 22 files.

### σ: how much single games swing

Per-game spread of the strength share within a build, pooled over the 9 builds with 3+ games (each
build's own mean taken out, so real differences between builds don't count as noise):

| Data | Games | σ per game |
|---|---|---|
| All 9 builds (2e, 2j, 2m, 2n, 2p, c1, c2, c4, c6) | 41 | 4.6 points |
| Without 2e and 2j (the broken 1-city-stall builds) | 33 | 3.4 points |
| c7c, 7 games (2026-11-02) | 7 | 3.75 points |
| **King baseline (job 6): A/A pairs, standard setup** | waiting for games | σ per pair: ? |

These are old-setup numbers (random maps, unpaired, T150). The new setup (job 6) measures σ again,
per pair. What they imply for an unpaired SPRT at δ = 2 points (expected games ≈ 5.9 · σ² / δ²):
about 17 games at σ = 3.4, 31 at σ = 4.6. Paired games should cut that.

### SPRT settings checked against Stockfish (lead, 2026-11-02, before job 4)

Checked against official-stockfish.github.io (Fishtest docs) and Fishtest's source
(`official-stockfish/fishtest`: `server/fishtest/stats/sprt.py`, `stats/LLRcalc.py`,
`templates/tests_run.html.j2`). **chessprogramming.org could not be reached from this session**
(DNS lookup error; this session started before the network settings were changed), so it isn't
cross-checked.

| Setting | AGENTS.md | Fishtest | Verdict |
|---|---|---|---|
| Pass / fail thresholds | LLR ≥ +2.94 / ≤ −2.94 | α = β = 0.05; bounds ln(β/(1−α)) = −2.944 and ln((1−β)/α) = +2.944 | Same |
| Gainer test | H0 gain 0, H1 gain δ | "Standard STC" [0, 2], "Standard LTC" [0.5, 2.5] (normalized Elo) | Same shape. Fishtest's longer test starts H0 a little above 0 |
| No-worse test | H0 −δ, H1 0 | "Non-regression" [−1.75, +0.25]: the same width as the gainer test, but H1 is slightly **above** 0 | Close. Ours accepts a change that is exactly neutral a bit more easily. Job 4 uses Fishtest's shape: [−0.875δ, +0.125δ] |
| How pairs are scored | per pair: the average of the two games, minus 50% | Pentanomial: each pair of games (same opening, sides swapped) is one observation scored 0, ¼, ½, ¾ or 1; LLR = number of pairs × the per-pair LLR; per-game σ = √(2 · per-pair variance) | Same idea. Our pair result is continuous (the mean strength share of the two games), so the LLR uses Fishtest's normal approximation (`LLR_alt2`): LLR = N · (s1 − s0)(2·mean − s0 − s1) / (2·var), with var the variance of the pair results |
| Units for the bounds | strength-share points | "Normalized Elo", so a test's expected length depends only on its bounds, not on the noise | Ours are in raw points, so test length depends on σ. That's why σ is measured per setup (job 6) |

**Correction to AGENTS.md's games estimate.** Wald's approximation gives about **5.3 · σ²/δ² pairs**
when the true gain is 0 or δ, and up to **8.7 · σ²/δ²** when it sits halfway between them (the
slowest case). AGENTS.md says 5.9. I worked these out myself, not from the Stockfish pages, and
`Summarize-ABTest.ps1` prints them from job 4 on.

## Fixes

### Candidate flags (lead job 1, fork commit `46fc076`, build `c7c_flags`)

Every C idea so far now has its own flag, `UsesCandidateAI(FIX_xx)` (fork `CvPlayer.h`,
`CandidateFixTypes`). `AIABTest.ini` (see [AIABTest.ini.example](AIABTest.ini.example)) picks what
group c runs (`Fixes =`) and what is screened (`Screen =`: on for a random half of the AI civs, dealt
warmongers first and drawn separately for each flag from the map seed). The test game reads the file
once at the start and saves it with the game. **No file = the bundle = c7c.** Outside a test game every
civ runs the bundle.

| Flag | From | What it does | Off means | In the bundle | Evidence so far |
|---|---|---|---|---|---|
| `WidePlans` | c1/c2 (2q, 2r) | warmongers, aggressive and expansionist culture civs play the wide plan | B's plan choice | yes | c1, c2: 49.1%, 49.0% over 5 games each. Not better alone |
| `BoxedIn` | c1 (2u) | a settler idle 10+ turns means no land left (settling stops) | B: only "no site at all" | yes | c1: c's tall civs got fewer cities (3.7 vs 4.4) |
| `LongWide` | c1 (2s) | wide opening to 8 cities, T130 Standard | 6 cities, T100 | **no** | c1: no extra cities |
| `BoxedInWar` | c3 | a boxed-in wide civ attacks the nearest neighbour blocking it, if not stronger | no war | yes | none measured alone |
| `TimingAttack` | c3/c3b | a warmonger attacks a weak close neighbour; committed target; no targets with defensive allies | no war | yes | c3 54.0% (1 game), c3b 39.8% (1 game) |
| `SiegeTechs` | c4 | warmonger research: Pottery, Wheel, Mathematics, Bronze Working, Archery, Writing | B's book techs | yes | part of c4 (51.6%, 6 games) |
| `SiegeBook` | c4/c5 | warmonger capital: 3 catapults, 2 spearmen, 2 archers after the 2nd settler | B's book | yes | part of c4/c5. No longer needs `WidePlans` |
| `DeclareTiming` | c4/c5 | declare once 2 siege + 4 other land units (fallback T90 Standard) | from T45 Standard (c3) | yes | part of c4/c5 |
| `GrowthTech` | c5/c5b | tall civs head for Engineering once the capital is size 6 | no | yes | c5b 52.3% (1 game) |
| `AqueductValue` | c5/c5b | tall civs count the aqueduct's kept food twice | no | yes | with GrowthTech |
| `GreedyArmyCap` | c6 | tall civs keep cities + 1 land units outside war and emergencies | no cap | **no** | c6: 0-3, 46.5% |
| `GreedyBook` | c7 | tall capital book on to aqueduct and university, to T130 Standard; its techs | B's tall book, to T80 | yes | c7 45.3% (1 game, with the cap) |
| `GreedyTarget` | c7 | warmongers pick the neighbour with the fewest land units per city | the weakest (c4) | yes | none measured alone |
| `CanWin` | c7c | war only if the siege sketch brings down the nearest city within 20 turns | no check | yes | c7c 52.9% (1 game) |
| `ClosedBorders` | c7c | tall civs never give open borders to majors | B | yes | c7c 52.9% (1 game) |

Dependencies: `DeclareTiming`, `GreedyTarget` and `CanWin` only matter with `TimingAttack` on (and
`CanWin` with `BoxedInWar` too); the warmonger flags only touch warmongers; `GreedyBook`, `GrowthTech`,
`AqueductValue`, `ClosedBorders` and `GreedyArmyCap` only touch tall-plan civs, so which civs they reach
depends on `WidePlans`.

None of these has passed. Each will get a hypothesis entry (measure, δ, test) when it's queued for an
SPRT; the screening run (lead job 4 onwards) decides which go first.

### Paired games (lead job 2, fork commit `7097d49`)

- **Flip.** `Flip = 1` in `AIABTest.ini` swaps the groups. The c/b split deals b first, the new/cp parity
  inverts, and each screened flag goes to the other half of the civs. It's saved with the game. AGENTS.md
  called this a custom option (`AI_AB_FLIP`). It's an ini key instead, so `Run-Games.ps1` can switch it
  between games without rebuilding the pack.
- **Replay.** Every test game writes `AIABTest_lastgame.ini` when it starts: map and sync seeds, each major
  slot's civ and leader, each city-state slot's type. For the second game of a pair, `Run-Games.ps1` copies
  those keys into `AIABTest.ini` with `Flip = 1`.
  - The DLL applies them in `CvGame::init`, before the random generators are seeded and before
    `InitPlayers` and the map script run (`init2`). So the pair should share map, civs, city-states and
    starting spots.
  - CP's rolls hash the map seed with the turn (`CvGame::randCore`), so personality flavors match too. The
    warmonger set is then the same in both games, and the flipped split is the exact complement.
  - Random leaders are picked by Civ before the DLL runs, which is why civs and city-states are replayed as
    well as the seed.
- **Not verified in a real game yet.** Whether Civ honours a seed and civ swap at that point is what the
  smoke test checks. If it doesn't, the fallback is loading the turn-0 autosave for the second game.
- **GameIds.** A flipped game's GameId ends in `F`. The summary pairs games in job 4; until then it lists the
  two games separately.

### Settings in every row (lead job 3, fork commit `24f6ba8`, build `c7c_settings`)

New columns after `Warmonger`:

| Column | What |
|---|---|
| `Flip` | 1 for the second game of a pair (groups swapped) |
| `Fixes` | the candidate flags this civ ran, joined with `+`, or `none` |
| `Screen` | the game's screened flags, or `none` |
| `Map` | the map script's file name (e.g. `Pangaea`) |
| `MapOptions` | every map option as `name=value`, joined with `;` (resources, sea level, ...) |
| `Ruins`, `Barbarians` | 1 = on |
| `Pace`, `Difficulty`, `WorldSize` | e.g. `GAMESPEED_QUICK`, `HANDICAP_PRINCE`, `WORLDSIZE_STANDARD` |
| `StopTurn` | where `Run-Games.ps1` stops the game (it writes `StopTurn =` to `AIABTest.ini`); 0 = unknown |
| `Build` | the DLL's git describe, e.g. `...-g24f6ba8...` |

The header changed, so the file is `AIABTest_c7c_settings.csv`. `Summarize-ABTest.ps1` now lists each
file's setups and flag configurations, with the number of games and flipped games for each, and warns
when a file mixes them. Strategic Balance shows up in `MapOptions` once we know how Civ numbers it (the smoke
test reports it).

### SPRT, screening regression and the games estimate (lead job 4)

All in `Summarize-ABTest.ps1`, per setup and flag configuration (screened flags left out of the key):

- **SPRT.** Fishtest's normal approximation, LLR = N (s1 − s0)(2·mean − s0 − s1) / (2·var).
  - Gainer test: [0, δ]. No-worse test: [−0.875δ, +0.125δ].
  - Pass at +2.944, fail at −2.944. δ defaults to 2 points.
  - Results are pairs (mean c share of the two games, minus 50) when the file has complete pairs, and
    single games otherwise.
  - The LLR is shown from 2 results but only acted on from 5, because the variance comes from the data.
    With 2–4 results it swings wildly.
- **Games estimate.** 5.3 · σ²/δ² results at H0 or H1, up to 8.7 · σ²/δ², from the measured spread or
  `-Sigma`.
- **Screening regression.** Each civ's strength (its share of the game's five strength measures, so 12.5
  points on average with 8 civs) against the screened flags it ran.
  - With pairs: per civ, game 1 minus game 2, where every screened flag is swapped, so the civ and the map
    cancel out.
  - Without pairs: pooled, with an intercept and a warmonger term.
  - "As group share" converts a per-civ effect into what it would add to the group running the flag
    (n/4 × the effect).
- **`-AtTurn N`** judges games at turn N (for turn-100 screening and job 8).
- **Tested on synthetic data:** 20 pairs with known per-civ effects of +1.0, 0 and −0.5 came out at
  +0.89 ± 0.11, +0.04 ± 0.11 and −0.35 ± 0.11. Shares absorb part of an effect, because the civs that
  don't run the flag lose share too.

The SPRT run after the fact on the old files (unpaired single games, so only a rough guide; a real SPRT is
read as games arrive):

| Build | Games | Gainer LLR | No-worse LLR | Reading |
|---|---|---|---|---|
| 2p (B) | 5 | +6.05 | +13.75 | both pass: B's freeze stands |
| c4 | 6 | +0.98 | +4.05 | not worse than B; a gain of 2 points not shown yet |
| c1 | 5 | −1.58 | −0.11 | running |
| c2 | 5 | −1.18 | −0.16 | running |
| 2e | 5 | −0.72 | −0.45 | running |
| 2m | 5 | −0.35 | +0.67 | running |
| c6 | 3 | −2.10 | −1.29 | too few results |

### Decision: Pangaea only (user, 2026-11-02)

Test games are always played on Pangaea. The planned rotation with Continents for about 1 game in 5 is
dropped. The cost: naval and embarked-unit code isn't exercised by the test games, so a change that
breaks it would only show in real play. Job 5 now just makes sure every game is set to Pangaea,
Strategic Balance and no ruins.

Continents may come back in a later version, as an occasional check on naval and embarked-unit code. The
results rows already record `Map`, so Continents games would be kept apart from the Pangaea baseline
automatically. They'd need their own σ, and their own setup in `Run-Games.ps1`.

### Setup: Pangaea, Strategic Balance, no ruins (lead job 5, fork commit `614af3d`)

`Run-Games.ps1` doesn't click any new options. Civ forgets game options between games (Quick Combat has
to be re-ticked every game), and new click positions can't be checked from a cloud session. So:

- **Pangaea**, size, civs, pace and difficulty are remembered by Civ's setup screen. The PC runner sets
  them once by hand.
- **Ruins and resources** are set by the test DLL from `AIABTest.ini`, which `Run-Games.ps1` writes before
  every game:
  - `Ruins = 0` turns on "no ancient ruins". The map script's `AddGoodies` checks that option, and so does
    popping a hut.
  - `MapOption5 = 5` sets map option 5, the one `Map.GetCustomOption(5)` reads, to Strategic Balance.
    `AssignStartingPlots` treats `resource_setting == 5` as Strategic Balance, and Pangaea's 5th option is
    Resources.
  - Both are set in `CvGame::init`, before the map script runs.
  - New `Run-Games.ps1` parameters: `-Ruins` (default 0) and `-Resources` (default 5).
- **Check.** After a game logs turn 10, `Run-Games.ps1` compares its map, pace, difficulty, world size,
  civ count, ruins and option 5 with `-ExpectMap Pangaea`, `-ExpectPace GAMESPEED_QUICK`,
  `-ExpectDifficulty HANDICAP_PRINCE`, `-ExpectSize WORLDSIZE_STANDARD` and `-ExpectCivs 8`. If anything
  differs, it logs "WRONG SETUP" and stops.
- **Not yet confirmed in a real game:** that Pangaea reads its resources option as "5". The smoke test
  checks it by looking for horses and iron next to each capital.

### Does difficulty change AI logic beyond handicap bonuses? (lead job 7, open question 1)

**Yes, in combat and diplomacy.** These are from reading the fork (`CvGameCoreDLL_Expansion2/`) and CP's
`Database Changes/Difficulty/CoreDifficultyChanges.xml`. Besides the bonuses (cheaper units and
buildings, free XP, happiness), these difficulty fields steer decisions:

| What | Field | Prince | Deity | Whose difficulty |
|---|---|---|---|---|
| **Combat search size** (`CvTacticalAI.cpp` ~12252, ~12790) | `TacticalSimMaxCompletedPositions` | 256 | 2560 | the game's |
| | `TacticalSimMaxBranches`, `MaxChoicesPerUnit` | 4, 4 | 5, 5 | the game's |
| **War appetite** against civs it dislikes (`SelectBestApproachTowardsMajorCiv`, ~19655) | `AggressionIncrease` | 4 | 15 | target's if human, else the game's |
| **Peace lasts** before re-declaring (several places in `CvDiplomacyAI`) | `PeaceTreatyDampenerTurns` | 18 | 11 | the game's |
| **Competition sours opinion** (land, wonders, city-states, victory, tech, policy) | `*DisputePercent`, `*BlockPercent`, `*Mod` | 85–100% | 134–150% | target's if human, else the game's |
| **Human armies look stronger** (~11606) | `HumanStrengthPerceptionMod` | +20% | +50% | humans only |
| Opinion of humans | `HumanOpinionChange` | 0 | 0 | humans only (negative only below Prince) |

All levels in CP for reference:

| Field | Settler | Chieftain | Warlord | Prince | King | Emperor | Immortal | Deity |
|---|---|---|---|---|---|---|---|---|
| Search positions | 32 | 64 | 128 | 256 | 384 | 512 | 768 | 2560 |
| Branches / choices per unit | 3 | 3 | 3 | 4 | 4 | 4 | 5 | 5 |
| AggressionIncrease | 0 | 0 | 2 | 4 | 6 | 9 | 12 | 15 |
| PeaceTreatyDampenerTurns | 20 | 20 | 20 | 18 | 16 | 14 | 12 | 11 |
| Land/wonder/city-state dispute % | 50 | 60 | 70 | 85 | 100 | 110 | 125 | 134 |
| Victory/tech/policy block % | 50 | 60 | 80 | 100 | 110 | 125 | 134 | 150 |
| HumanStrengthPerceptionMod | 0 | 0 | 10 | 20 | 25 | 30 | 40 | 50 |

**The same at every level in CP:**
- The randomness of production, tech, policy and belief choices (`*ChoiceCutoffThreshold`, 90 everywhere).
- The approach biases (`AI*`/`Human*ApproachChange*`, 0 everywhere).
- `HumanTradeModifier` (0).
- The "medium city, high difficulty" city strategy (`GetID() > 4`, Emperor and up) has no entry in CP's
  database. It's probably inactive, but I didn't check the base game's data.

**What it means for testing**
- **AI-only test games use the game's difficulty for every AI-vs-AI decision.**
- **Correction (same day):** the pack builder's even rules (`CPModpack/README.md`) already give the even
  difficulty Deity's combat search budget. Every test pack so far was built with them, so test games were
  searching with Deity's 2560 positions, not Prince's 256. The search-size point below only matters for
  stock difficulties.
- **In multiplayer, AI-vs-human decisions use each human's own difficulty.** AI-vs-AI decisions use the
  game's, which the exe passes to `CvGame::init`. I couldn't see which one the exe uses in multiplayer.
- **Combat and war fixes should be confirmed at the difficulty the friends actually play**, if it isn't
  Prince. A fix that wins with 256 search positions may not win with 2560, and the reverse. Strength-share
  results from Prince games still hold for economy fixes. Bonuses apply to every AI alike in an AI-only
  game, so they shift pace, not the A/B comparison.
- **A note for Diplomacy:** `HumanStrengthPerceptionMod` makes AIs rate human armies 20–50% stronger than
  they are, and only humans'. That runs against goal 2 ("judged by behaviour, never by whether a player is
  human"). It may be one reason AIs hesitate to gang up on a human conqueror. Worth a look in their audit.
- **Turn time:** at Deity the combat search does up to 10× the work, so AI turns in big battles will be
  slower than in our Prince games.

**Settled:** everyone plays King (next section), so the friends, the AIs and the test games all use King's
row, and "which difficulty is the game's in multiplayer" no longer matters.

### Decision: everyone plays King, by the same rules (user, 2026-11-02)

The user's words: "I want all the humans and all the AI to play by all the exact same rules. Everyone gets
all the same advantages and disadvantages. Let's just have everyone play at King."

- **The pack.** `Build-CPModpack.ps1` now evens out King instead of Prince (`-EvenDifficulty`, default
  `KING`). `CPModpack/README.md` has the full list. On King, CP gave AIs:
  - 15% cheaper techs, buildings, units and great prophets; 25% cheaper policies; 62% cheaper upgrades;
  - half-price improvement maintenance; 10% faster growth; 20% faster workers;
  - 10 free XP on new units, an extra starting defender, more unit supply, 15 happiness against a
    human's 9;
  - and it rated human armies 25% stronger than they are.

  All of that becomes the human value. AI-only free techs and yields are left out, and the AI's
  human-only exceptions are off (`HUMAN_USES_AI_MECHANICS`).
- **Checked.** I ran the builder's real even-rules step against a database built from CP's difficulty
  data. It prints exactly the expected King edits, and `-EvenDifficulty Prince` still gives the old Prince
  list. Not yet run on a real game database.
- **Same for everyone at King:** the combat search (Deity's budget), aggression toward disliked civs (6),
  peace holding 16 turns, disputes weighing 100–110%. A human's own row and the game's row are both King,
  so the AI applies these to humans and AIs alike.
- **Testing moves to King.** `Run-Games.ps1` expects `HANDICAP_KING`. `Run-ABTest.ps1`, README.md and
  AGENTS.md say King.
- **A new baseline.** Every result before 2026-11-02 (B included) is from Prince with even rules. B stays
  the reference, but σ is measured again at King (job 6), and old and new results aren't pooled. The
  `Difficulty` column keeps them apart.
- **Players:** pick King when hosting. On other difficulties the AI keeps CP's usual bonuses. The pack's
  Readme.txt says so.

### Do turn-100 standings predict turn-150 ones? (lead job 8)

**Mostly yes.** Data: the 54 games in `results/` that logged both turns (22 files, Prince, random maps,
unpaired). Reproduce with `tools\ab\Compare-ABTurns.ps1`.

| Measure | Result |
|---|---|
| Group gain at T100 vs T150, per game | correlation 0.88, slope 0.97 |
| Build averages (9 builds with 3+ games) | correlation 0.92, slope 0.81 |
| Each civ's own share (432 civs) | correlation 0.86, slope 0.99 |
| Spread of one game within a build | 4.00 points at T100, 3.86 at T150 |
| Change from T100 to T150 in one game | spread 2.37 points, average −0.25 |

The side ahead at T100 was still ahead at T150 in 40 of 54 games. Every change of side came from a close
T100 result:

| T100 margin | Games | Changed side by T150 |
|---|---|---|
| 0–1 points | 11 | 7 |
| 1–2 points | 12 | 6 |
| 2–4 points | 14 | 0 |
| 4+ points | 17 | 1 |

Build averages at both turns (points of gain): 2p +2.51 / +2.38, c4 +0.93 / +1.55, c6 −3.08 / −3.53,
c1 −0.93 / −0.88, c2 +0.07 / −1.03, 2m +0.52 / +0.40, 2n +1.26 / +0.73.

**What it means**
- **Screening at turn 100 is sound for strength.** An edge at T100 is about the size it will be at T150,
  and T100 isn't noisier. For the same verdict, a T100 test needs about 1.1× (game-level slope) to 1.6×
  (build-level slope) as many games. It pays off if a T100 game takes less than about 60–90% of a T150
  game's time. Late turns are the slow ones, so it very likely does. `Run-Games.ps1` now logs
  "turn 100 after N minutes" to measure it.
- **War is the exception to watch.** c4's edge grew after T100 (+0.93 to +1.55), the only build that clearly
  did, and it's the conquest build. Fixes whose point is war (most of War's) may only show late. They get
  their SPRT at T150 or later, as AGENTS.md already says, and shouldn't be dropped on a T100 screen alone.
- **Use:** screening runs read with `Summarize-ABTest.ps1 -AtTurn 100`; the confirming SPRT reads the final
  turn. The two can come from the same games (Run-Games stops at T150 by default, and every game logs T100).
- **Caveat:** this is old-setup data (Prince, random maps, single games). Rerun `Compare-ABTurns.ps1` once
  about 20 King pairs are in.

### B is not re-proven fix by fix (lead job 9)

B (batch 2p, fork `24cc575`) passed as a whole, 5-0 at 52.4%. Run after the fact, the SPRT on its five
games passes both tests (gainer LLR +6.05, no-worse +13.75; job 4). It stays the reference. Its ~40 changes
aren't tested one at a time. An ablation (B with one fix taken out) is done only when a B fix is suspected
of hurting, with evidence.

**First suspect: audit item 26.** B makes an army abort below 2/3 of its required slots while gathering or
moving (CP: below half). That's one `UsesNewAI()` branch in `CvAIOperation.cpp` (~line 875), logged as
`Ended: HalfStrength`. If attacks keep dying before they reach a city, this rule could be part of
"cities almost never change hands".

- **Evidence first.** `Digest-ABLogs.ps1` now prints, per civ, how its military operations ended over the
  whole game (e.g. `military ops ended (whole game): HalfStrength 2, Success 1`). The PC runner's logged
  games show how often item 26 fires, for b and c alike. The War session should look at these counts before
  asking for an ablation.
- **If it's suspected,** the ablation is one candidate flag, e.g. `B26Off`, gated as
  `UsesNewAI() && !UsesCandidateAI(FIX_B26_OFF)`, so group c runs B without item 26 and group b runs B.
  Test it with the gainer SPRT on paired King games at T150 or later (war shows late; job 8). If c wins,
  dropping the rule becomes a candidate fix like any other.
- **For a wider ablation,** the side branch `claude/ab-switches-diagnostics-2r` (release `ab-e9f7ecf`)
  already has a switch for each of B's changes (`AIChangeTypes`, 38 switches). It's based on 2r and
  unmerged, so it would need porting onto `claude/ab-c1`'s flags. It's not needed now.

### C builds as releases (lead job 9a, fork commit `9348566`)

- **Publishing.** The fork's CI (`build_vp.yml`) publishes every build of a `claude/` or `ai/` branch as
  release `ab-<commit>`, titled with its branch. Each A/B branch also moves a "latest" release:

  | Release | Branch |
  |---|---|
  | `ab-c-latest` | `claude/ab-c1` |
  | `ab-ai-<topic>-latest` | `ai/<topic>` |
  | `ab-latest` | `claude/sleepy-hopper-x77moh` (unchanged) |

- **Builds on push.** Pushes to `claude/ab-c1` and `ai/**` build by themselves (path filter: DLL sources,
  build scripts or the workflow), so nobody has to start a run by hand.
- **`Run-ABTest.ps1`** installs `ab-c-latest` by default (`-Release ab-<commit>` for one build). It prints
  the release's title, which names the commit and branch, because a "latest" release moves with every
  build.
- **CI notes**, also in README.md:
  - A hung run blocks its branch. `gh run cancel` may not stop it; the force-cancel API does.
  - A newer pending run replaces an older pending one on the same branch.
  - The first build on a new branch spends about 12 minutes downloading the Windows SDK.
- **First run, verified:** the merge into `claude/ab-c1` started push run 41543426404, which published
  `ab-9348566` and `ab-c-latest` at 23:22, each with `CvGameCore_Expansion2.dll`. Its DLL is the same AI as
  `614af3d`; only the workflow changed.

### The bully test and the builders test (lead job 10, fork commit `59888a3`, build `c7c_roles`)

**Setup.** `Run-Games.ps1 -Mode bully` or `-Mode builders` writes `Mode =` to `AIABTest.ini`. The DLL picks
the roles from the map seed and the civs' personalities, so both games of a pair get the same ones:

| Mode | Roles | What they play |
|---|---|---|
| `bully` | **aggressor**: a warmonger (warmonger trait or offense flavor 8+), else the most offensive personality | its own personality, no head start (`HeadStartProduction` and `HeadStartGold` can add one; both default to 0) |
| | **tall**: the most science/culture-minded of the rest (nerd and smaller traits first) | the tall opening plan |
| `builders` | **two builders**: the two most science/culture-minded civs, warmongers last | the tall opening plan; they start no wars (`CvTeam::canDeclareWar`), but a defensive pact can still pull them in |

**How a test works.** The roles stay the same in both games of a pair; only the other
AI civs change.
- In these modes group c is every AI civ without a role, and the roles always run B.
- In the second game of a pair (`Flip = 1`) there's no c at all, so the other AIs run B as well.
- So a pair measures what the candidate changes do to the roles' games: how far the aggressor gets, and how
  much pressure the builders feel.
- The c/b strength split isn't used as a verdict in these modes, since the groups are 6 civs against 2.

**New columns** (`AIABTest_c7c_roles.csv`):
- `Mode`, `Role`.
- Running counts: `WarsDeclared` (not pact calls), `WarsOnUs`, `CitiesCaptured`, `CitiesLost` (between
  major civs), `Deals` (that went into effect), and the banned behaviours `WorkersStolen` (civilians captured
  from city-states) and `WonderChops` (forests or jungles chopped into a city building a world wonder).
- This turn's state toward the other major civs: `AtWar`, `AtWarAggressor`, `Pacts`, `Friends`,
  `Denouncing`, `Influential` (civs it's culturally influential on).

These are counted in the DLL rather than read from the AI logs, so they work with logging off and land
in the same file as the verdict. `Digest-ABLogs.ps1` still covers what only the logs show.

**`Summarize-ABTest.ps1`** prints, for bully games: the aggressor's share of all cities at T100 and at the
end, its captures, how many civs are at war with it, how many turns after its first capture two or more
civs were at war with it ("coalition"), and how the tall civ was treated (wars declared on it, friends,
pacts). For pairs, it prints the aggressor's end-of-game city share with c defenders minus without. For
builders games: wars declared on each builder, cities it lost, its deals, AI-vs-AI wars, cities changing
hands, and the leading AI's techs. For every file with the new columns: deals, wars declared and captures
per civ per 10 turns, friends, pacts, denouncements and influence, and the banned-behaviour totals, by
group. Tested on synthetic files only.

**Not built yet:**
- Requests and joint-war proposals (only in the AI logs or diplomacy state; Diplomacy can add them).
- Victory progress beyond techs and influence: delegates, spaceship. At T150 on Quick, no civ is near a
  victory anyway.
- An AI-turn-time column for the scoreboard (job 11).

**No head start** (user, 2026-11-02): "my friend isn't that good, he is just aggressive and the vanilla AI was
terrible". The aggressor is simply the most aggressive personality, playing B. Fork `4b37724` makes 0 the
default for both head-start keys, which remain available. If the aggressor never takes a city, even from B
defenders, the bully test has nothing to measure for now. That itself says the AIs already hold against a
plain aggressive AI, and the real test is games against the friend.

### The scoreboard (lead job 11)

- **The table** is at the top of this file, with one row per milestone build and a goal row.
- **`Summarize-ABTest.ps1 -Scoreboard`** prints one ready-made row per results file: games, strength share,
  the aggressor's city share at the end, cities per aggressor war, coalition size and speed,
  deals per civ per 10 turns, banned behaviours per game, and seconds per AI turn.
- **Seconds per AI turn** come from a new DLL column, `TurnSecs` (fork `6b8ebde`, still in `c7c_roles` since
  no games used that file yet). It's the real seconds per game turn since the last logged row, measured on
  the PC, so it compares builds only on the same PC and setup.
- **The goal numbers were agreed with the players on 2026-11-02:**
  - strength ≥ 55% against CP (raised to **60%** by the user on 2026-11-03);
  - the aggressor ≤ 20% of all cities at the end;
  - ≤ 1 city per war;
  - 2+ civs at war with it within 20 turns of its first conquest;
  - 0.5–2 deals per civ per 10 turns;
  - 0 banned behaviours;
  - AI turns no more than 25% slower than B.

  The deals band gets a second look once the first King games show what CP's AIs do.

### c7c after 10 games (PC runner, games 2–10 merged from `claude/sleepy-hopper-x77moh`)

| Game | c strength | No-military | Score c / b |
|---|---|---|---|
| 1 `0222211E` | 52.9% | 52.8% | 580 / 560 |
| 2 `02347593` | 46.5% | 45.5% | 551 / 595 |
| 3 `0240230B` | 53.8% | 52.2% | 554 / 549 |
| 4 `02497CC2` | 54.6% | 53.0% | 610 / 490 |
| 5 `0252DABA` | 48.7% | 50.8% | 600 / 596 |
| 6 `025C2A49` | 48.4% | 51.9% | 557 / 648 |
| 7 `02657620` | 45.1% | 47.5% | 581 / 615 |
| 8 `026E87CF` | 45.5% | 47.4% | 552 / 622 |
| 9 `02775318` | 52.0% | 51.0% | 533 / 614 |
| 10 `028C4E70` | 46.4% | 46.1% | 542 / 645 |

- **After 10 games (lead, 2026-11-03):** 49.4% ± 1.1, 4-6, p 70%; no-military 49.8%; score ahead 4-6. SPRT
  (δ = 2, unpaired, spread 3.62): gainer LLR **−2.47** (fails at −2.94, so about 2 more games like these end
  it), no-worse +0.20. c7c is stopped here: the bundle's flags get tested one by one on King with pairs, and
  the c7c_roles smoke pair plays the same bundle again. Its 4th city comes later than B's (T89 against T81),
  though more c civs get there (85% against 82%); Economy's settler flags aim at exactly that.
- **After 7 games:** 50.0% ± 1.4, 3-4, p 50%; no-military 50.5%. The 52.9% of game 1 was luck, as one game always
  can be. SPRT (δ = 2, unpaired): gainer LLR −1.00, no-worse +0.74, both still running. The spread is 3.75
  points per game, so a decision needs about 19–30 games.
- **Reading:** the c7c bundle isn't better than B. Its ideas are now separate flags (lead job 1), and the
  King setup with pairs is where they get tested one by one.
- **Speed:** these games took **10 minutes each** to turn 150 (Run-Games.log, 17:33–18:24), not the hour
  AGENTS.md assumed, so about 6 games an hour. That makes SPRTs of 20–40 pairs a matter of hours, and
  turn-100 screening less important.
- These are Prince games on the old setup (random maps, unpaired), so they don't go into the King baseline
  (job 6).

### The King baseline: plan (lead job 6)

**What it measures.** The noise every test under the new setup is judged against. It's an **A/A run**:
`-Fixes none`, so group c runs no candidate changes and every civ plays B. The setup is King with even
rules, Pangaea, Strategic Balance, no ruins, Standard, 8 civs, Quick, paired games, stopped at T150. From
it, in the summary's "c runs none" section:

- **σ per pair** ("spread of one result"). This sets every SPRT's expected length: 5.3 · σ²/δ² pairs at
  δ = 2. With the old per-game σ of 3.4–4.6 and pairs cutting it as hoped, a δ = 2 test should take 10–25
  pairs. This run says how many.
- **The average**, which should be 50% (gain 0): anything else is a bug in the split or the replay.
- **First games against flipped games.** The difference is the c/b split's built-in bias (c gets the
  extra warmonger when a game has an odd number). Pairs cancel it, but its size says how far unpaired old
  results could be off.
- **What pairing buys:** the summary now prints the single-game spread and how many unpaired games each
  paired game is worth.
- **T100 against T150 again** (`Compare-ABTurns.ps1`), on King pairs (job 8's recheck).
- **AI turn time** (`TurnSecs`) and the diplomacy rates: B's row of the scoreboard at King.

**Size.** 20 pairs gives σ to within about ±16%, which is enough to plan tests. It's about 7 hours at 10
minutes a game; King games may run a little longer.

**After it.**
- σ goes into the Baseline table, B's King row into the scoreboard, and δ is confirmed (2 points unless σ
  makes that impractical).
- Then the first single-flag SPRTs, and a first bully pair to see whether the aggressor takes anything.
  A screening run of all flags at T100 is optional at this game speed.

### Expansion pace: where the turns go, first pass (Economy, 2026-11-02)

No logged King game exists yet, so this is from the results files (2p, c4, c7c), the one digest
(`digest_c7c_game2.txt`) and the code. The logged games asked for under Requests confirm or correct it.

**Founding turns by plan** (Quick, last row per civ; the new AI's own groups; `n` = civs that got there):

| Build, group | 2nd city | 3rd city | 4th city | Cities at end |
|---|---|---|---|---|
| 2p new, wide (8) | T29 | T54 | T68 | 5.6 |
| 2p new, tall (16) | T38 | T60 | T87 (9 of 16) | 4.0 |
| c7c b, wide (9) | T27 | T57 | T76 | 5.4 |
| c7c b, tall (19) | T38 | T68 | T83 (13 of 19) | 4.4 |
| 2p cp (24) | T48 | T65 | T80 (13 of 24) | — |

- **The 2nd-to-3rd city gap is 25-30 turns for both plans**, even for wide civs whose book asks for
  settler after settler. Tall civs also start late: their 2nd city comes at T38.
- **Gold sits unspent.** The new AI holds 150-230 gold from T20 to T60, against 70-150 for CP's AI,
  while saving for a gold settler (about 370 on Quick). About one civ in two shows a 200+ drop before
  T80 (a settler bought). That's 2j/2k doing what it says, slowly. Not first: a fix here trades tiles
  and hurries for settlers, and the logs (`EXPANSION SETTLER - Saving/Bought`) should show how often
  the buy actually lands.

**What the code does between settlers** (`CvPlayer::GetOpeningBookProduction`, fork `9348566`):
1. **The books put buildings between settlers.** Wide capital: Scout, Warrior, Warrior, **Settler**,
   Worker, Shrine, **Settler**, Monument, **Settler** ×3, Library. Tall capital: Scout, Monument, Shrine,
   Warrior, Warrior, **Settler**, Worker, **Settler**, **Settler**. On Quick a worker, shrine or monument
   is 8-10 turns from a young capital, a settler 10-14. So the wide 2nd settler waits for a worker and a
   shrine (16-20 turns), and the tall first settler for a monument, shrine and two warriors.
2. **A held settler step falls through to the next building.** The book skips a settler while the last
   one is on the map *or in training* ("one settler at a time"), while the city is size 1, or while
   growth is ≤ 3 turns away, and then goes on down the list. The next item is usually a building, and
   the city doesn't choose again until it's done. So every settler walk (3-4 turns in the digest) costs
   a whole monument or library (8-20 turns) before the next settler starts. The digest has gaps that
   fit, but can't prove it: Austria's settlers were ordered at T26, T34 and T55 and its cities came at
   T42 and T89; Brazil's at T30 and T53, with one city, at T64. The logged games should show it.
3. Other suspects, not yet checked against logs: happiness stopping settlers (`IsEmpireUnhappy`),
   escorts (`IDLE SETTLER` turns: 3-10 per civ in the digest), and the book ending at T67 (wide) / T53
   (tall) on Quick, after which the base AI's expansion strategy takes over.

### SettlersFirst: the capital's book settlers come before its buildings (Economy)
- Hypothesis: settlers that don't queue behind a worker, shrine and monument found the 2nd and 3rd
  cities 10-15 turns sooner. Tall capital: Scout, Warrior, Warrior, Settler, Monument, Settler, Shrine,
  Worker, Settler, then B's later steps (greedy book: the same, then aqueduct and university). Wide
  capital: Scout, Warrior, Warrior, Settler, Settler, Worker, Settler, Shrine, Settler, Monument,
  Settler, Library. Warriors stay first (2p's escort lesson). Risk: a later shrine may cost a pantheon
  or religion (2l); strength share doesn't count religion, but watch the religion count.
- Measure: strength share at T100 (verdict); `City2Turn`–`City4Turn` and cities at T100 (mechanism).
  Expect the 3rd city by about T45 instead of T55-68.
- δ: +2 points of strength share.
- Build: fork commit `cbb3380` on `ai/economy` (patch 0001 applied by the lead on `6b8ebde`; flag `SettlersFirst`,
  `FIX_SETTLERS_FIRST`), release `ab-cbb3380` / `ab-ai-economy-latest` once CI passes. Not in the bundle, so games
  without `AIABTest.ini` still play c7c.
- Test: SPRT gainer, paired, standard King setup, T100 (`Summarize-ABTest.ps1 -AtTurn 100`), group c
  running `Fixes = SettlersFirst` against B. Or screened with `SettlerOverlap` in one run.
- Status: in screening run 1 (test build `claude/ab-screen1`, after the King baseline).
- Notes: Economy has no push access to the fork, so the commit goes to the lead as
  `tools/ab/patches/economy/0001-*.patch` (on `6b8ebde`); the lead applies it to `ai/economy`.

### SettlerOverlap: the next book settler trains while the last one walks (Economy)
- Hypothesis: with B's "one settler at a time", a settler in training or walking blocks the next, and
  the capital falls through to a 8-20-turn building. Counting only settlers in training (and at most one
  on the map) lets the next start at once, so each city after the 2nd comes about one walk-plus-building
  (5-15 turns) sooner. Independent of SettlersFirst: it removes the fall-through, SettlersFirst the
  built-in buildings.
- Measure: as SettlersFirst. Also idle-settler turns in the digest (two settlers on the map at once
  should stay rare).
- δ: +2 points of strength share.
- Build: same commit (`cbb3380`), flag `SettlerOverlap` (`FIX_SETTLER_OVERLAP`). Not in the bundle.
- Test: SPRT gainer, paired, T100, `Fixes = SettlerOverlap`.
- Status: in screening run 1 (test build `claude/ab-screen1`, after the King baseline).

### Expansion pace: how the logged games are read (Economy, fixed before the logs arrive)

**Source.** `digest_<GameId>.txt` from `Run-Games.ps1 -SaveLogs` (run with `-UpToTurn 80` or more), one block
per major civ. The lines read are:
- **`builds to T..`**: every production start, `*` = opening-book pick.
- **`settlers ordered T / found-city ops started T / cities founded T`**.
- **`settler timeline to T..`**: `settler (book) in <city>`, `settler (AI) in <city>`, `BOUGHT`, `op started`,
  `FOUNDED`, `op ended: <reason>`.
- **`saving gold for a settler: N turns (Ta-Tb)`**.
- **`IDLE SETTLER turns`**.
- **`ops aborted`** (e.g. `LostCivilian`).

From the results CSV: `City2Turn`-`City4Turn`, `Book`, `Gold`.

**Per settler** (founded cities 2-4 of each civ, first 80 turns), each settler's life is split into five
stretches. Read with care: "op started" is when the settler exists and has a target, so it stands in for "finished".
1. **Wait:** from the previous settler's `op started` (or, for the first settler, turn 0) to this settler's
   start. What the capital built in between is the **book's own steps** (cause 1) or **fall-through**
   (cause 2: book buildings started while the previous settler was between `op started` and `FOUNDED`).
2. **Train:** from the start to `op started`, or to `BOUGHT`.
3. **Idle:** a gap after training with no op (`IDLE SETTLER` turns), i.e. waiting for an escort or a target.
4. **Walk:** from `op started` to `FOUNDED`.
5. **Lost:** `op ended: LostCivilian` and a replacement settler.

**Readings for B (the baseline logged pair).** These say whether the diagnosis behind each flag is right,
before any flag is tested:

| Flag | Diagnosis is right if B shows | Wrong if |
|---|---|---|
| `SettlersFirst` | In the capital, the **wait** before book settlers 2 and 3 is mostly book steps (worker, shrine, monument; for tall civs also before settler 1): median ≥ 8 turns per settler | Waits are short (< 4 turns), or filled by non-book picks (wonders, AI units). Then reordering the book changes little |
| `SettlerOverlap` | At least one **fall-through** per civ in the first 80 turns (a book building started while a settler walked), each pushing the next settler's start ≥ 5 turns past the founding | Walks are 1-2 turns and the next settler starts right after founding |

The other causes, counted the same way, which become new flags only if they're large:
- **Idle (escorts):** more than 5 idle turns per settler on average.
- **Lost settlers:** `LostCivilian`.
- **Interrupted settlers:** a settler start followed by another start in the same city with no `op started`.
- **Gold.** The question: is saving locking gold away for nothing? It is if a civ shows ≥ 30 saving turns
  before T80 with no `BOUGHT`. Then spending it elsewhere (a worker, tiles) is the candidate fix. If most
  civs buy a settler within about 20 saving turns, saving works and stays.

**Readings for the flags (screening run 1, c against b).** `City2Turn`-`City4Turn` per plan: the mechanism
shows if c's 3rd city comes ≥ 5 turns earlier than b's, and c's fall-throughs drop to about 0 with
`SettlerOverlap`. The verdict is still strength share at T100.

**Tried on `digest_c7c_game2.txt`** (Prince, old digest without the timeline; 6 civs):
- **Cause 1 shows.**
  - Austria (wide): settler 1 started T7 and its op started at T16. Then came the worker, monument and
    shrine; settler 2 only started at T26 (a 10-turn wait).
  - Korea (tall): monument, shrine and two warriors came first, so settler 1 only started at T22.
- **Cause 2 likely shows, not provable.** Austria's monument started at T19, the turn its first settler
  founded, before the shrine. That fits a settler step held while the settler walked, and the book
  falling to the next building.
- **Things the procedure can't settle without one more field:**
  - Austria's settler started at T34 only founded at T89.
  - Brazil's settler started at T30 only got an op at T58. In between, a Great Library (Brazil T43,
    Austria T39) was started somewhere: the settler may have been **replaced by a wonder**, or finished
    and stood idle.
  - The old digest's build list doesn't say which city started what, so the capital's queue can't be told
    from the new cities'.
- **Korea's 2nd city was delayed by a lost settler.** Its op ran T31-T48, ended `LostCivilian`, and the
  replacement founded at T61. Escort and safety cost 30 turns there.

**The missing field is in** (lead, `974919d`): the `builds to` line now reads `builds to T<n> (capital <name>; other
cities named)`, and every build outside the capital ends in `(<City>)`. So the wait, fall-through and
interrupted-settler readings are exact from the logged King pair on.

**Why a settler was held, from builds with patch 0009 on** (Economy, logging only, no behaviour change; on
`d950f88`). The book logs `<city>, OPENING BOOK - Settler held (<reason>), size <n>, next <build>` in
`CitySpecializationLog.csv` whenever it passes over a settler step. The reason is the first one hit:
`size 1`, `unhappy`, `boxed in`, `growth due` or `one at a time`. `one at a time` followed by a building is
exactly `SettlerOverlap`'s fall-through, so with it the cause 2 count is direct instead of inferred. It also
gives city size at that moment, which the logs didn't have. The King baseline (`ab-6b8ebde`) predates it, so
the first logged pair is read with the inferred method above. The digest prints them per civ (lead): `book SETTLER HELD to T<n>: <count> (<reason>
<k>, ...)   built instead: <next> <k>, ...   first: T<t> <city> size <s> next <build> | ...`. The cause 2 count is the
`one at a time` holds whose `next` is a building.

### Expansion pace: first logged King games (Economy, 2026-11-03)

**Source:** the smoke-test pair `02A37B03` / `02A37B03F` (King, c7c bundle, logging on), digests in `results/`. The
digests list 6 major civs per game. The flags are judged against B, so the reading uses the 6 civs playing **B**:
- game 1: Germany (tall), Indonesia (wide), Songhai (tall);
- game 2: Assyria, China, Morocco (all tall).

These digests predate the city field and patch 0009, so the capital's queue is inferred from the book's step
order.

| B civ | 1st settler started | 2nd / 3rd / 4th city | Wait before settler 2 (capital), and what filled it | Saving gold |
|---|---|---|---|---|
| Germany (tall) | T17, after monument, warrior, shrine | T29 / T61 / T74 | 26 turns: worker\*, AI warrior, **Stonehenge** T39, **library\*** T43 | 35 turns, bought T65 |
| Songhai (tall) | T17, after monument, shrine, warrior | T35 / T47 / T72 | 9 turns (warrior, worker\*). Settler 3: **Great Library** T47, and the book ended at T53 before it | 53 turns, never bought |
| Assyria (tall) | T24, after monument, shrine, warrior | T38 / T87 / T104 | Never: worker\*, **Stonehenge** T39, **Royal Library\*** T39/T48. The book ended at T53 with settlers 2 and 3 unbuilt | 44 turns, never bought |
| China (tall) | T24, after monument, warrior, shrine, worker | T37 / T78 / T93 | 13 turns, **Stonehenge** T34. The settler started T47 is followed at T48 by **Great Library**, and the city that started it didn't found until T78 (likely replaced) | 59 turns, bought T79 |
| Morocco (tall) | T27, after monument, shrine, warrior, worker | T39 / T63 / T114 | 11 turns: **Stonehenge** T37, library\*, worker\* | 51 turns, bought T50 |
| Indonesia (wide) | T10 | T22 / T67 / T83 | Never from the book: worker\*, monument\*, shrine\*, then **Great Library** T34 (14 turns). AI settler at T48 | 25 turns, never bought |

(\* = opening-book pick.) Medians: 2nd city T37, 3rd T65, 4th T88. Walks are 2-3 turns, except Songhai (8) and
Morocco (12).

**Against the readings fixed beforehand:**
- **`SettlersFirst`: diagnosis right, for settler 1.** Every tall civ started its first settler at T17-T27, behind
  13-27 turns of monument, shrine, warriors and sometimes the worker. Indonesia (wide) started at T10. With
  the reordered book, tall civs should start settler 1 at about T8-12. For settler 2 it's only partly right:
  the book's own steps (worker) are a small part of the wait.
- **`SettlerOverlap`: diagnosis mostly wrong.** Walks are 2-3 turns. The long holds happen around T34-T48, when
  **no settler is on the map**, so the reason isn't "one at a time" (it must be growth due, unhappiness, or the
  book returning nothing). Expect a small effect. Keep it in screening run 2, but don't expect a pass.
- **The biggest delay wasn't on the list: wonders in the capital.** 6 of 6 B civs started Stonehenge or the Great
  Library at T34-T48, while the book still had settler steps to do. Settler 2 then waited for the wonder (or was
  replaced by it), and for all 5 tall civs the book ended at T53 (Quick) without starting its 3rd settler. The likely path
  (`CvCityAI::AI_chooseProduction`): a settler step is held (most likely growth due), the book falls through to
  its library, and the rule that lets the book's later buildings "give way to wonders" (2o) swaps the library
  for a wonder. The other possibility is the book returning nothing and the normal choice picking the wonder.
  Patch 0009's log line tells these apart.
- **Gold:** B civs saved for a settler 25-59 turns before T80. 3 of 6 never bought (Songhai, Assyria, Indonesia)
  and the others bought only at T50-T79. Saving locks 150-230 gold for 40-60 turns for at most one settler,
  usually late. The procedure's threshold (≥ 30 saving turns, no buy) is met by 2 of 6. A fix is reasonable
  but second to the wonders.
- **Also seen in a c civ** (c7c bundle): Songhai (c, wide) built its first settler by T18. Its found-city op then
  started and ended with `LostPath` every two turns from T18 to T34, the settler was killed (`LostCivilian`),
  and the 2nd city came at T54. An unreachable site re-picked every turn is a settler-operation bug to look at
  (`CvAIOperation`, settler operations: Economy's).
  - Reading the code (`CvAIOperationCivilianFoundCity::VerifyOrAdjustTarget`): a settler going without an escort
    plans with `MOVEFLAG_AI_ABORT_IN_DANGER`, under which an end-of-turn plot in danger is impassable in the next
    two turns. So a barbarian near the route leaves no path. The switch to a "better target" ignores
    `GeneratePath`'s result and then aborts with `LostPath`, and the next operation picks the same site again.
  - Still to confirm from `OperationalAILog.csv` (its "no path to city site" and "found target" lines) before
    coding a fix. Requested from the PC runner's log archive.

**What this changes.** Two new flags, both behind `UsesCandidateAI` with hypotheses below, and a request: put
patch 0009's logging (it only logs) into the screening run 2 build if it isn't too late, so that run's logged
games show the hold reasons directly.

**Update with all logged King games so far (19 B civ-games).** Sources: the smoke-test pair's b civs, the first
baseline pair `02C5BBF9` (counted once: both games are the same game), and the b civs of War's three logged games.
18 of the 19 played tall.

| Measure (B, tall) | Median | Note |
|---|---|---|
| 1st book settler started | T19 (T14-T33) | behind the tall book's monument, shrine and warriors |
| 2nd city | T35.5 | |
| 3rd city | T65.5 | 2 of 18 had no 3rd city by T80 |
| world wonder started in the capital by T53 | 17 of 19, median T35 | Stonehenge, Great Library, Temple of Artemis, Pyramids |
| book settlers started (tall book has 3) | 1 or 2, **never 3** (19 of 19) | the book always ended first |
| saved 30+ turns and never bought a settler by T80 | 7 of 19 | 10 of 19 bought one, usually at T42-T79 |

The same conclusions, on four times the data:
- The book's opening delays settler 1 (`SettlersFirst`).
- Capital wonders take the time of settler 2 (`SettlersBeforeWonders`).
- The book ends before its 3rd settler every time (`BookFinishesSettlers`).
- Gold saving pays off late or not at all in about a third of civs.

### SettlersBeforeWonders: no wonder in the capital while the book still has settlers to build (Economy)
- Hypothesis: B's capitals start Stonehenge or the Great Library at T34-T48 with book settlers pending (6 of 6 B
  civs in the first logged King pair), and the 2nd-to-3rd city gap is 25-45 turns. While the book is active
  and still has a settler step to do, the capital doesn't start a world wonder:
  - the book's later buildings don't give way to wonders;
  - the normal production choice skips world wonders in the capital.

  Expected: the 3rd city 10-20 turns earlier, at the cost of some early wonders. Wonders count for score, not
  for strength share.
- Measure: strength share at T100 (verdict). Mechanism: `City3Turn`, `City4Turn`, and the wonders count at T100.
- δ: 2 points of strength share.
- Build: DLL commit `1e45522` (on `dc117c9`), patch 0010, flag `SettlersBeforeWonders` (`FIX_SETTLERS_BEFORE_WONDERS`),
  not in the bundle. Files: `CvCityAI` (the book's swap to wonders), `CvBuildingProductionAI` (world wonders in the
  capital), `CvPlayer` (`HasUnstartedBookSettlers`).
- Test: in a screening run with `SettlersFirst` (they're independent), then SPRT gainer at T100 if it looks good.
- Status: coded, not built.

### BookFinishesSettlers: the opening book runs until its settlers are started (Economy)
- Hypothesis: the tall book ends at T80 Standard (T53 Quick), and none of the 5 B tall civs in the first logged pair
  had started its 3rd book settler by then (Assyria not even its 2nd; Germany's 3rd at T54 was the normal AI's). After that, settling falls to the
  normal economic AI, which is slower: 3rd city at T63-T87, 4th at T72-T114. With the flag, while any book
  settler step is unstarted, the book stays active up to T100 Standard (T67 Quick); after that the turn limit
  applies as before.
- Measure: strength share at T100. Mechanism: `City3Turn`, `City4Turn` for tall civs.
- δ: 2 points of strength share.
- Build: same patch 0010, flag `BookFinishesSettlers` (`FIX_BOOK_FINISHES_SETTLERS`), not in the bundle.
- Test: screening, then SPRT gainer at T100.
- Status: coded, not built.

### Found-city operations: three bugs from the logs (Economy, 2026-11-03)

From `OperationalAILog.csv` and `PlayerHomelandAILog.csv` of the smoke-test pair and War's three logged games (all
King, `results/logs_*`). The code is in `CvAIOperation.cpp` (settler operations are Economy's) and
`CvPlayer::GetBestSettlePlot` (settling: Economy's).

| Case | What the logs show | Cost |
|---|---|---|
| Songhai (c), `02A37B03F`, T18-T36 | The settler stands at (26:16), one tile from its site (26:15). On each tile it "can found 1". Eight operations in a row: started with **"Found 0 potential units"** (no escort) yet moved at once; "no path to city site (26:15)", every turn; then "found better target (26:14)" → `Ended: LostPath`. On T36 the settler is killed (`LostCivilian`) | 2nd city at T54 instead of about T21, and a settler lost |
| Germany (c), `02EA597F`, T29-T64 | One operation for 35 turns. Waited for an escort, went alone after 15 turns (2m), then **"no path to city site (50:28)" three times a turn for 20 turns**, each time re-picking (50:28). At T64 "found no suitable target in area"; then two operations a turn end `NoTarget` until T150 | **Germany ended the game with 1 city** |
| China (b, B's own code), `02A37B03F`, T80-T88 | Escorted ("Units Recruited 2"), path found, yet `Ended: LostPath; Duration 0`, the turn each operation starts, nine turns running, with no "no path" line | About 9 turns of the 3rd/4th city |

**The three bugs:**
- **A. Escort dropped next to danger.** `CvAIOperationCivilian::Init` clears the escort slot whenever the settler can
  reach the site this turn (`TurnsToReachTarget(...) < 1`), CP's shortcut. B added a safety test for its own
  no-escort rule (`SettlerTripLooksSafe`: no visible danger, no camp or enemy city within 5 tiles), but the CP
  shortcut bypasses it. (Songhai)
- **B. Site choice and movement disagree about danger.** A settler without an escort checks and plans its path with
  `MOVEFLAG_AI_ABORT_IN_DANGER` (`VerifyOrAdjustTarget`). Under that flag, a plot with danger above half the
  settler's HP is impassable for the next two turns. But `GetBestSettlePlot` checks reachability without it. So
  the site picked is one the settler then can't walk to, and `RetargetCivilian` picks it again, turn after turn.
  (Songhai, Germany)
- **C. A good path is called lost.** After the target check, `VerifyOrAdjustTarget` aborts with `LostPath` if
  `GetPathEndFirstTurnPlot()` is NULL. That's also the case when the path is fine but has no step this turn,
  e.g. a settler with no moves left when the operation is created, so the operation dies the turn it starts.
  It also ignores the result of the path refresh after switching to a "better target". (China; the Songhai
  switches)

All three are in B as well as C (A and C are CP's code paths). One flag each, out of the bundle, as patch 0011:
- **`SettlerEscortSafe`** (A): the "reachable this turn" shortcut drops the escort only if `SettlerTripLooksSafe`.
- **`SettlerSitePathFlags`** (B): `GetBestSettlePlot`, when picking for a found-city operation whose settler
  has no escort, checks paths with `MOVEFLAG_AI_ABORT_IN_DANGER` too. A site behind danger is skipped, so the
  settler goes elsewhere or the operation ends and waits.
- **`SettlerPathCheck`** (C): `LostPath` only when the settler really has no path to its (possibly new)
  target. After switching to a better target with no path, it keeps the old target if that one still has a
  path.

Hypothesis (all three): fewer settlers stuck or lost, earlier 2nd-4th cities for the civs that hit them. Most
civs never do, so the average effect is small but the tail is large (Germany: 1 city). Measure: strength share
at T100 (no-worse, δ = 2), plus `City2Turn`-`City4Turn` and the number of civs with ≤ 2 cities at T100
(mechanism). Test: screening (all three), then no-worse SPRTs. They're bug fixes, kept unless they hurt.

Build: DLL commit `a0d8fcb` (on `ai/economy` rebased onto `9fadf3d`), patch 0011. Files: `CvAIOperation.cpp` (A in
`CvAIOperationCivilian::Init`, C in `CvAIOperationCivilianFoundCity::VerifyOrAdjustTarget`), `CvPlayer.cpp` (B in
`GetBestSettlePlot`). Status: coded, not built. `SettlerPathCheck` logs "no path to better site (x:y), keeping (x:y)"
when it keeps the old target.

### Religion and faith in the logged King games (Economy, 2026-11-03, read-only)

**What the logs can show.** The copied logs have no religion log. Founding turns, prophet use and faith purchases of
missionaries and inquisitors are in `PlayerHomelandAILog.csv`. **Pantheons, beliefs, faith totals and faith
buildings are not.** They're in `ReligionLog.csv` (founding, beliefs, faith purchases) and
`PlayerBeliefReligionLog.csv` (belief scoring), from `CvReligionClasses.cpp`. Neither is in `Run-Games.ps1
-SaveLogs`'s list, and the results CSV has no faith column.

Per game (major civs with any religion activity; T = first "Great Prophet founding a religion", E = first
"enhancing", M = missionaries bought, I = inquisitors bought):

| Game | Civs |
|---|---|
| `02A37B03` | Celts T45 E104 M5; Songhai T55 E143 M4; Germany T67 E122 M4; Netherlands T70 E122 M6; Morocco T94 E138 M1 I1 |
| `02A37B03F` | Celts T45 E102 M9; China T68 M4; Netherlands T68 E115 M6; Morocco T76 M3; Germany T91 E148 M2; no religion: Assyria M1, Indonesia M1, Songhai M4 |
| `02DEF5BF` | Siam T55 E119 M1; Maya T58 E88 I2; Morocco T70 E141 M3; Zulus T80 M5; Huns T84 M1; none: Poland M2 |
| `02EA597F` | Ethiopia T42 E96 M10; Celts T49 E102 M8; Brazil T73 E148 M3; India T73 M3; Sweden T86 E144 M2; none: Shoshone M1 |
| `02F5C9E3` | Arabia T65 E128 M4; Babylon T66 E105 M5; Celts T73 M5; England T80 E133 M3; Spain T95 E143 M4; none: Sweden M1 |
| `043923C9` / `F` | Spain T38 E71 M11-12 I2; France T56 E114-125 M6-7; Ottomans T59 E117-131 M1; Germany T65 E117-127 M4-7; Assyria T77 E141-151 M2-3; none: Songhai, Portugal (M1-2) |

**Reading.**
- **Every slot gets filled.** All five religions are founded in every game, at T38-T95, and most are enhanced by T150.
  The religion's founder then buys 1-12 missionaries, spreading at home and to neighbours.
- **Faith spent on religions the civ doesn't own.** Civs without a religion still buy missionaries (Assyria,
  Indonesia, Songhai, Poland, Shoshone, Sweden, Portugal: 1-4 each). Those spread the majority religion in their
  cities, which is someone else's: faith spent spreading another civ's religion. That is likely a gap rather
  than a choice.
- **Little else gets bought with faith.** Apart from missionaries and inquisitors, the only faith-type
  purchases logged are a few plots (gold). No great people or faith buildings bought with faith appear. Either
  they aren't logged in the homeland log, or faith piles up after the religion slots fill (from about T95).
  The missing religion log would say which.

**Bad beliefs or wasted faith?** Can't be judged without `ReligionLog.csv` / `PlayerBeliefReligionLog.csv`. Nothing
in these logs points to a bug.

**Candidate gap: missionaries for a religion the civ doesn't own.** The likely place is the faith-purchase choice in
`CvReligionClasses.cpp` (`CvReligionAI::DoFaithPurchases` and its missionary checks). Beliefs are scored in
`CvReligionAI::ScoreBelief*`, in the same file.

### NoForeignMissionaries (Economy, patch 0012)
- **Hypothesis:** a civ with no religion of its own stops faith-buying missionaries, which only spread another civ's
  religion. A founder's own missionaries and all inquisitors are unchanged. Its faith then goes to faith buildings and great people instead. Small gain
  for 1-3 civs a game.
- **Measure:** strength share at T150 (no-worse). Mechanism: missionaries bought by civs without a religion
  (homeland log, should be 0) and faith spent on buildings (`ReligionLog.csv`, from build `02c8d38` on).
- **δ:** 2 points, no-worse.
- **Build:** patch 0012 (on 0011), flag `NoForeignMissionaries` (`FIX_NO_FOREIGN_MISSIONARIES`), not in the bundle.
  Applies cleanly with 0011 on `d4d4d70`. The guard is at the top of `CvReligionAI::BuyMissionary`
  (`CvReligionClasses.cpp`).
- **Status:** coded, not built. The user ruled it obviously right: it merges on code review and a clean smoke pair
  (lead), not an SPRT.

**Before deciding on a religion session:** add `ReligionLog.csv` and `PlayerBeliefReligionLog.csv` to `-SaveLogs`,
and a faith-stored column to the results CSV, then read one logged pair. That costs no extra games.

### Why warmongers don't build their army (Economy for War, 2026-11-03, read-only)

**Case:** `logs_0714EFCB0714EFCB`, Songhai's `OP_CITY_ATTACK_LAND_SNEAKY` 1713. It started at T80 with 5 of 9 slots
filled and ended T101 (`DiploOpinionChange`). It logged "SiegeArmy: waiting for more units, expected damage 16 a
turn, Athens needs 86" and "Found 0 potential units to recruit" every turn.
- **What Songhai's cities built at T80-T101:** settlers, workers, caravans, a market, a library, Temple of Artemis
  and **one warrior**.
- **No unit was ever requested:** in those 21 turns no city's production list held an "Operation unit" or "Army
  unit" entry (`CityStrategyAIProductionLog.csv`).

**Cause: nothing asks the cities for the missing units.** A city builds for an army through two entries in
`CvCityStrategyAI::ChooseProduction`:
1. **Operation unit** (weight 5000 + 250 × offense flavour): from `CvCity::GetUnitForOperation`, which reads the
   operation's `m_viListOfUnitsWeStillNeedToBuild`. `CvAIOperation::GrabUnitsFromTheReserves` rebuilds that list each
   recruiting turn with free slots **only if the slot is required** (`m_requiredSlot`).
2. **Army unit** (750 + 250 × offense): from `CvMilitaryAI::GetUnitTypeForArmy`, which uses
   `GetOpenSlots(true)`, i.e. **required slots only**.

With its required slots filled, the army has only optional slots free, so neither entry fires. Both channels would win
easily if asked (5000+ against buildings worth hundreds). But War's `SiegeArmy` wait wants more damage while the
production side sees nothing missing, so the army waits for units no city is told to build. Outside war, a
warmonger's normal production has no other push toward units: the war penalty on buildings and the tiny-army rule
only apply at war (`CvBuildingProductionAI`, B's change keeps peacetime to 1 unit per city).

**For War to decide (the operation code is War's):** while an operation is held by the siege wait (not enough
expected damage), put its free **optional** slots, or extra siege/ranged slots, into
`m_viListOfUnitsWeStillNeedToBuild`, so the "Operation unit" entry asks the cities for them. Production needs no
change for that: the 5000 weight already beats every building. If War prefers the production side, the alternative
is `GetUnitTypeForArmy` with `GetOpenSlots(false)` for armies waiting on the siege check (`CvMilitaryAI`, also War's).
Economy can measure it afterwards from the same log (operation-unit entries and military units built during the wait).

### CvPolicyAI audit (Economy, 2026-11-02)

`CvPolicyAI.cpp` read in full except `WeightPolicyAttributes` (lines 1037-4692, about 300 per-attribute
scores), which was scanned for scores whose condition tests one field and whose value uses another.
Fork `6b8ebde`; line numbers from there. In AUDIT.md's terms, all are **confirmed** (re-read, does what's
described); impact is a judgement.

| # | Where | Bug | Impact | Fix |
|---|---|---|---|---|
| P1 | `WeighPolicy`, ~4808 | "If we're itching to conquer a city-state, drop the diplomacy value" tests `GetCivApproach(eMinor) >= CIV_APPROACH_HOSTILE`. The enum runs WAR, HOSTILE, DECEPTIVE, GUARDED, AFRAID, NEUTRAL, FRIENDLY, so the test is true for every approach but WAR: the diplomacy-flavour value of a policy is dropped for nearly every civ, and kept only by civs planning war on a city-state. Every other approach test in the DLL uses `<=` | Medium, all game: Patronage and other diplomacy-flavoured policies undervalued by everyone, diplomat civs most | `<=`. Flag `DiploPolicyValue`, patch 0002 |
| P2 | `DoChooseIdeology`, ~600 | An ideology is "ruled out" by setting its score to 0 (it doesn't support our clearly preferred victory, or `CanAdoptIdeology` says no), and later steps skip zeros. But the relations step can push the others below 0 (−500 for a hostile neighbour's ideology, −500 again if that's the biggest competitor), and the final pick is a plain maximum starting from index 0, so a ruled-out ideology at 0 beats them | Low in test games (ideologies come after T150 on Quick); real in full games | Pick only among ideologies not ruled out (track a flag, not 0) |
| P3 | `PropagateWeights`, ~1027 | `PropagateWeights(..., iPropagationLevel++)`: AUDIT.md item 8's bug, in the policy copy. The first prerequisite recurses at the same level (one level deeper than intended), later ones a level shallower | Low: policy trees are shallow | `iPropagationLevel + 1` |
| P4 | `WeightPolicyAttributes`, 2323 | `GetPassiveEspionageBonusModifier() != 0` scores `GetRigElectionInfluenceModifier() / 10` (copy-paste) | Low: espionage, late game | Use the passive espionage value |

**Not bugs, but worth knowing** (design; tuning, not fixes):
- **Older branches are penalised twice.** An unopened branch from an earlier era has each policy divided by
  `max(2, era·5 − branch era)` in `WeighPolicy` (÷5 in the Classical era, ÷11 in the Medieval), then the
  branch's total by `2·(era − branch era)` in `ChooseNextPolicy`, after the ×10% every new branch gets
  (`POLICY_WEIGHT_PERCENT_DROP_NEW_BRANCH` = 90). A Tradition civ effectively can't pick up Liberty or Honor
  once out of the Ancient era.
- **Finishing first.** No new branch opens while any open branch can continue (`bNeedToFinish`), and
  policies in an open branch are multiplied by the number already owned there.
- `WeighBranch` counts a branch's opener twice (once in the loop over the branch's policies, once as
  `GetFreePolicy`), and `GetCulturePerWonder` / `GetCultureWonderMultiplier` add `iNumWonders` outside the
  product (`a * b + c`, probably meant `a * (b + c)`). Both small.
- `aLevel3Tenets` in `ChooseNextPolicy` is filled and never read.

**What to do:** P1 is the only one that touches T150 games, so it's the only one coded so far. P2-P4 are
one-line fixes for later, best bundled into a "late-game bugs" no-worse test once games run past T150.
Whether the policy AI picks well overall (which branches, in what order) needs `PolicyAILog` output from
logged games, not more reading.

### DiploPolicyValue: diplomacy-flavoured policies keep their value (Economy, audit P1)
- Hypothesis: with the inverted test fixed, civs value Patronage and other diplomacy policies as CP
  intended, so diplomat and city-state-friendly civs take them, earning more city-state allies (votes,
  yields). Expect a small strength effect at T100-150 and more city-state alliances.
- Measure: strength share at T150 (no-worse); policies taken by branch (`PolicyAILog`) and city-state
  allies where the digest has them (mechanism).
- δ: 2 points, as a **no-worse** test: it's a bug fix, kept unless it hurts.
- Build: fork commit `cfaf3db` on `ai/economy` (patch 0002 on `cbb3380`), flag `DiploPolicyValue`
  (`FIX_DIPLO_POLICY_VALUE`). Not in the bundle.
- Test: SPRT no-worse, paired, standard King setup, T150. Lower priority than the expansion flags.
- Status: in screening run 1 with SettlersFirst and SettlerOverlap (test build `claude/ab-screen1`, after the
  King baseline).

### Late-game victory push audit (Economy, 2026-11-02)

Read at fork `6b8ebde`: who picks the victory to push for (`CvDiplomacyAI::DoUpdateCurrentVictoryPursuit`,
`IsSeriousAboutVictory`, the `Get*VictoryProgress` / `IsCloseTo*` functions), and everything in Economy's
files that reacts to it (`CvEconomicAI` GS_* strategies and helpers, `CvTechClasses` grand-strategy tech
priorities, `CvCityStrategyAI` yield and building values, `CvUnitProductionAI` / `CvProjectProductionAI`
spaceship, archaeologist and Utopia weights, `CvPolicyAI`), plus `CvPlayerAI::AI_doSpaceshipAndUtopiaProduction`.

**How the push works.**
1. **The pursuit.** Each turn the civ's current victory pursuit is, in order:
   - its leader's eternal pursuit, if it has one;
   - otherwise the first victory it's "close to", checked in the order science, culture, diplomacy, conquest
     (thresholds: science 80, culture 60, diplomacy 55, domination 50; see below for what those measure);
   - otherwise, if it isn't **serious about winning**, its primary pursuit from flavours;
   - otherwise its active grand strategy.
2. **Serious about winning** needs a grand strategy with priority above 500, victory competition on, and
   for anything but conquest a **game era of Renaissance or later**. The game era is the rounded average of
   all civs' eras.
3. **What a pursuit changes:**
   - tech priorities (+1 per matching flavour);
   - city yield values (×2 for the pursuit's yields, another ×2 when close);
   - building values (non-pursuit victory values ÷ (era + 1));
   - policy weights (non-focus values halved);
   - spaceship-part and project weights (×10 when going for science, ×10 again after Apollo);
   - archaeologists (+5000 for culture);
   - diplomat purchases (×4 for diplomacy) and city-state influence (+5× desire);
   - disbanding aluminium units for spaceship parts.
4. **Spaceship parts are built whatever the pursuit.** `AI_doSpaceshipAndUtopiaProduction` takes over
   production in the best cities whenever any part can be built.

**Findings.**

| # | Where | What | Status | Impact |
|---|---|---|---|---|
| L1 | Test design, not code | Science, culture and diplomacy pursuits only become "serious" once the **average** era reaches Renaissance. In our games (T150 Quick, about 25-30 techs) that's rare, so every civ that isn't close to a victory plays its flavour-based primary pursuit, and most of the push above (the ×2/×10 terms, the serious-mode tech and policy focus) **never runs in test games**. Goal 6 ("an AI on track to win") can't be judged from T150 Quick games | confirmed | Large for goal 6: needs long games (Standard pace or late saves), not T150 Quick |
| L2 | `CvDiplomacyAI::GetScienceVictoryProgress` (Diplomacy's file), ~3195 | "Projects completed" counts **every** project the team has (Manhattan Project, Utopia, ...) against "projects required" from the spaceship thresholds, and counts Apollo a second time after the loop. Progress = min(techs %, 78 + 21 × completed ÷ required), so once a civ knows 80% of the techs, any one project makes it "close to a science victory" | code confirmed; whether Apollo also has a threshold in the base game's data (which would make the double count consistent) wasn't checked: the base XML isn't in the fork | Low: very late game. Count only projects with a space-race threshold, each capped at its threshold |
| L3 | `CvDiplomacyAI::GetDominationVictoryProgress` (Diplomacy's file), ~3104 | Domination progress is the larger of our share of the original capitals and **our share of all major civs' military might**. A civ with half the world's military is "close to world conquest" without having taken anything: it switches its pursuit to domination (unless close to another victory first), values production ×2, and others' endgame-aggression checks see it as near a win | design, confirmed | Matters for goals 2 and 7: a big army alone flips a builder into conquest mode, and makes it a target. For Diplomacy and Personality to weigh |

**No confirmed bugs in Economy's own files** in the push itself: the reactions listed above do what
their comments say. The spaceship-part takeover (point 4) clears and re-queues the best cities' production
every turn they aren't building a part, which is aggressive but deliberate.

**What follows.**
- **For the lead:** victory-push changes need a long-game test: Standard pace to a late turn, or saves from
  the Industrial era on. That needs a decision before Economy writes any victory-push fix.
- **For Diplomacy:** L2 (a counting fix) and L3 (a design question) are in Diplomacy's file. Both are under
  Requests.


**Lead's decision (2026-11-02): the victory push waits for phase 2.**
- It belongs to goal 6 ("bring the pressure when the humans don't"), and phase 1 is strength first.
- Testing it needs games that reach the Renaissance: Standard pace, or saves from later eras, played on
  for N turns. That's a new test setup, built when phase 2 starts.
- Until then, Economy's next work, in order:
  1. the two expansion flags' tests, after the King baseline;
  2. flags for the remaining confirmed `CvPolicyAI` bugs (P2–P4), each as a no-worse test at T150;
  3. the greedy-tall alarm together with War, once War has its first capture fixes.

### Diplomacy: audit, map and plan (Diplomacy session, 2026-11-02)

The audit is in [AUDIT.md](AUDIT.md), "Diplomacy audit": 13 confirmed bugs (D1-D13), the exploit checklist with a
verdict per trick, and the map of what CP has against a conqueror. No code yet.

**Why a conqueror isn't stopped today, in one line:** every AI hates it (warmonger threat reaches CRITICAL) but
judges the war one against one, so it picks AFRAID, and AFRAID switches off war targets, coop wars, sanctions and
denouncing. Coop wars and pacts also need an existing friendship, and per-pair peace plus a 16-turn dampener lets the
conqueror fight one civ at a time. Nothing in it is human-specific.

**Exploits:** the lump-sum-for-per-turn trick is already blocked in ordinary trades (`BlockTemporaryForPermanentTrade`),
but not in peace deals, where payments outlast the peace lock. Breaking deals by war costs no reputation. The
help-request re-roll is real. Bluffing works on perceived strength and units at the border. Cities are not cheap in
peace deals.

**Plan.** Bugs first, each with its own flag so they can be screened together (the regression screen gives each flag
its own estimate) and then confirmed one by one. Then game theory, one flag per idea:

| Flag | Idea | Hypothesis | Measure | δ / test |
|---|---|---|---|---|
| `FIX_EASY_TARGET` | D1 + D2: "easy target" works for civs at peace | Opportunists start wars against weak or overstretched neighbours, including a conqueror whose army is away | `WarsDeclared` per civ, `CitiesCaptured`; bully test: wars on the aggressor | No-worse on strength (δ 2); gainer if it shows |
| `FIX_DIPLO_BUGS` (ini name `DiploBugs`) | D3-D8, D12, D13 together (see the patch entry below for why they're grouped) | Correctness; no strength loss | Strength; mechanisms: war length (D3), wars on city-states (D4) | No-worse (δ 2) |
| `FIX_LUXURY_ASK` (`LuxuryAsk`) | D9 | More luxury swaps between AIs, no strength loss | `Deals` per civ per 10 turns (band 0.5-2) | No-worse |
| `FIX_CITY_STATE_BUGS` (`CityStateBugs`) | D10 + D11; game-wide (on when any major civ has it) | City-states react one by one to an aggressor; alliances pass to whoever overtakes | Bully pair: city-states at war with the aggressor | Bully test |
| `FIX_COALITION_STRENGTH` | Judge a SEVERE or CRITICAL warmonger against the coalition, not alone: our strength plus that of civs that are visibly against it (at war with it, denouncing it, or lost a city to it in the last 30 turns), minus its own friends and pact partners | AFRAID gives way to GUARDED/HOSTILE/WAR toward a runaway, only when the coalition could actually win | Bully test: civs at war with the aggressor at the end; turns from first conquest to 2+ at war | Goal row: 2+ within 20 turns; no-worse on strength |
| `FIX_COALITION_COOP` | Coop war against a SEVERE+ warmonger can be asked of any civ that is against it (not only friends), and the potential-war-target gate uses the coalition strength | More joint wars against the aggressor, none against a peaceful tall civ | Joint-war proposals (new count), coalition speed; the tall civ's wars | Bully and builders tests both |
| `FIX_COALITION_PACT` | Defensive pacts get a "common threat" term (both rate the same civ SEVERE+), and a third pact is allowed while such a threat exists | Pacts form against the conqueror before it reaches the next victim | `Pacts`, aggressor's cities per war | Bully test |
| `FIX_SANCTIONS` | World Congress counts warmonger threat whatever the approach (today only when worse than GUARDED) | Sanctions proposed and passed against a runaway | Sanction proposals (new count) | Bully test, long games |
| `FIX_PEACE_PAYMENTS` | Per-turn items in a peace deal are valued over the turns the payer is actually bound (the peace lock), not the full deal | The peace-deal version of lump-sum-for-per-turn stops paying | Scripted check | Exploit check + no-worse |
| `FIX_DEAL_REPUTATION` | Remember deals the other side cancelled by declaring war while it still owed payments: opinion penalty, and its per-turn promises are discounted by that record. Partners with a clean record get full value | Breaking deals costs trust; honest partners trade more (Cicero's lesson: be the partner others can rely on) | `Deals` per civ per 10 turns stays in the 0.5-2 band; scripted check | No-worse + exploit check |
| `FIX_DEMAND_BLUFF` | Demands are judged by whether the demander could actually take a city (`CanTakeNearestCity`, from c7c's `FIX_CAN_WIN`), not by perceived strength and units at the border | Bluffs stop paying; real threats still get appeased | Scripted check | Exploit check + no-worse |

All of these judge by behaviour (warmonger threat, cities taken, deals broken), never by who is human, and leave
the leader's personality in charge (boldness, warmonger hate, loyalty still weigh as before). The first bully
pairs (B everywhere) set the starting point for the coalition flags.

### Diplomacy: patches, exploit-check scenarios and answers (Diplomacy session, 2026-11-02)

**Patches** (format-patch files on pack branch `claude/ai-diplomacy`, each based on `claude/ab-c1` `6b8ebde`, applied
with `git am` and checked to apply cleanly; not compiled here, CI is the first compile):

| File | What | Goes to |
|---|---|---|
| `tools/ab/patches/diplomacy/counts/0001-...` | Measurement only: running counts per proposer of joint wars asked and agreed, and World Congress sanctions proposed and passed, each with a "vs the aggressor" variant (target's `GetABTestRole() == AB_ROLE_AGGRESSOR`). 8 columns at the end of the row: `CoopWarAsked`, `CoopWarAskedVsAggressor`, `CoopWarAgreed`, `CoopWarAgreedVsAggressor`, `SanctionsProposed`, `SanctionsProposedVsAggressor`, `SanctionsPassed`, `SanctionsPassedVsAggressor`. Batch `c7c_proposals`. "Asked" counts AI-to-AI and human-to-AI requests (in `RespondToCoopWarRequest`, after its validity check) and AI-to-human requests; "agreed" counts an immediate or "after preparing" yes | `claude/ab-c1` directly (lead's answer). `Summarize-ABTest.ps1` needs the new columns |
| `tools/ab/patches/diplomacy/fixes/0001-...` | The bug fixes behind four flags: `EasyTarget` (D1, D2), `DiploBugs` (D3-D8, D12, D13), `LuxuryAsk` (D9), `CityStateBugs` (D10, D11). All four are left out of `kCandidateFixBundle`, so a non-test pack and `Fixes = bundle` don't get them until they pass | `ai/diplomacy` |
| `tools/ab/patches/diplomacy/fixes/0002-...` | War's request: the committed conquest target (`GetNewAIConquestTarget`) becomes a saved `CvDiplomacyAI` member instead of a `static`. A save reload kept no target, so a battle test from a save could pick differently from its game; in real play the static survived into the next game in the same process. Test runs restart Civ every game, so pairs were never affected. **Saves made with earlier builds won't load with it** (one field appended to the save), so merge it before battle-test saves are made, or after they're no longer needed | `ai/diplomacy` (or `claude/ab-c1`, since it's War's code and changes no decision) |

| `tools/ab/patches/diplomacy/fixes/0003-...` | Flag `DealExploits`: (a) per-turn gold and resources the other side pays in a **peace deal** are valued for the peace treaty's turns plus half of the rest (CP valued all of them, though a war after the lock cancels them); (b) a **demand** is refused unless the demander's units that the AI can see could take one of its cities (the c7c siege sketch run on visible land units within 5 tiles of each city; CP gave in on perceived total strength and units at the border). Checked by exploit checks 1 and 3, plus a no-worse test (AI-to-AI demands now pay less often) | `ai/diplomacy` |
| `tools/ab/patches/diplomacy/fixes/0004-...` | Flag `CoalitionStrength`, the headline fix. Against a civ whose warmonger threat to us is SEVERE or CRITICAL, the strength estimate (`DoUpdatePlayerStrengthEstimates`) also counts the civs visibly against it: at war with it in full, denouncing it at half. Not its friends, pact partners, team or vassals, and only civs that can reach it. Only public facts. So AFRAID gives way when the coalition really could win, and the war-target and coop-war gates open with it. Hypothesis and measures: the `FIX_COALITION_STRENGTH` row of the plan above. Judged by the bully test once War's capture fixes work | `ai/diplomacy` |

**Why the bug fixes share flags.** Flags are bits of a 32-bit mask (`1 << eFix`), 15 are taken, War's patch adds 3,
and Economy and Personality will add more. One flag per bug (12) would use most of what's left. So:
- `EasyTarget` alone: it changes how often AIs start wars, so it needs its own verdict.
- `LuxuryAsk` alone: it changes trade, measured by deals.
- `CityStateBugs` alone: it's city-state behaviour, shared by everyone. It has to be game-wide, and only the bully
  pair (c in one game, none in the other) can measure it.
- `DiploBugs` for the rest: each is a plain correctness fix with a small effect, like batch 1 in B.

If `DiploBugs` fails its no-worse test, split it to find the culprit. **Merge note:** War's three flags and mine are
both appended after `FIX_CLOSED_BORDERS`, so the second branch merged into `claude/ab-c1` gets a conflict in the enum,
`kCandidateFixNames` and the bundle mask. Keep both lists, in either order: saved masks only matter within one build.

**Flag budget: solved** (lead, 2026-11-03: 64-bit masks, flags in one table, fork `27437f0`).

**More patches (2026-11-03), on the 64-bit base.**
- `fixes-64bit/0001-0004` are fixes 0001-0004 converted to the table format, based on `cca50d8` (64-bit masks plus the
  proposal counts). They apply cleanly; use them if that saves the conversion.
- `next/0005-0007` go on top of them. Against the lead's own conversion they may conflict only in the
  `kCandidateFixes` table line: keep every name, each `false`.

| Patch | Flag(s) | What | Hypothesis | Measure / test |
|---|---|---|---|---|
| `next/0005` | `CoalitionCoop` | Joint wars against a SEVERE or CRITICAL warmonger can be asked of any civ visibly against it (denounced it, or lost a city to it), not only friends; being wary or afraid of the target no longer stops the ask. The usual desire score still decides | More joint wars against the aggressor, none against a peaceful civ (no conquests = no threat) | `CoopWarAskedVsAggressor`, `CoopWarAgreedVsAggressor`; coalition speed; builders test: no wars on builders from it |
| `next/0005` | `Sanctions` | The World Congress AI counts the target's warmonger threat whatever its approach (CP: only when worse than GUARDED) | Sanctions proposed and passed against a runaway | `SanctionsProposedVsAggressor`, `SanctionsPassedVsAggressor`; needs games long enough for the Congress |
| `next/0006` | `CoalitionPact` | Defensive pacts with civs that share a SEVERE+ warmonger threat (denounced it, lost a city to it, or live close to it), friends or not; +40 per shared threat (up to two) in the pact score | Pacts form against the conqueror before its next war; a tall neighbour of a conqueror finds allies | `Pacts`; aggressor's cities per war; the tall civ's pacts |
| `next/0007` | `DealReputation` | Each civ remembers deals another civ ended by declaring war on it while still owing per-turn payments (saved, recorded whatever the flag). With the flag, that civ's per-turn promises are worth less: nothing after the peace lock in peace deals, otherwise -25% per broken deal (at most -50%) | Breaking a payment deal by war stops paying; honest partners keep full terms, so the deal rate doesn't drop | Exploit check 1 run twice in a row (the second peace should ask for more); `Deals` band; no-worse |

**Save layout:** `0002` adds one saved field and `0007` one saved array, both at the end of `CvDiplomacyAI`'s save.
Saves made before them won't load after them. Battle-test saves should be made with a build that already has both.

**Coalition flags together.** `CoalitionStrength` takes the fear away. `CoalitionCoop` and `CoalitionPact` give the
coalition a way to act, and `Sanctions` adds the World Congress. They're separate flags for SPRT, but in the bully test
they're worth one run all together first ("does any of it move the aggressor's share?"), then one at a time.

**Suggested tests.**
1. `EasyTarget`, `DiploBugs`, `LuxuryAsk`: one screening run with all three randomised per civ (lead job 4's
   regression), at T100. Then a no-worse SPRT at T150 on each flag that the screen doesn't flag as harmful. Read
   `WarsDeclared` for `EasyTarget`, and `Deals` for `LuxuryAsk`.
2. `CityStateBugs`: in the bully pairs, alongside the coalition flags later.

**Exploit checks: exact scenarios** (lead's request). Each needs a save made in a normal game with the test pack
installed, a human in slot 0 and King with even rules. Run each on two builds, B and `ai/diplomacy` with the flag
named, and reload the save before every try.

*Check 1: per-turn payments in a peace deal* (no fix coded yet; `FIX_PEACE_PAYMENTS` planned):
- **The save:** the human has been at war with one AI neighbour for at least 10 turns, and the AI is winning:
  war score 25 or more for the AI (the trade screen's peace tooltip shows it). At least one of the human's cities is
  under siege. The human makes 15+ gold per turn.
- **Turn 0:** the human offers peace in the trade screen and asks the AI what it wants ("What would make this work?").
  Record the AI's terms: gold per turn, for how many turns, plus any lump sum. Accept. Record the human's GPT and the
  AI's treasury.
- **Wait:** end turns until war can be declared on the AI again (the declare-war button is greyed out until the
  peace treaty ends). Record that turn. Then declare war on it.
- **Measure:** how many turns of GPT the AI received, divided by the deal's turns. Also note the AI leader's
  opinion of the human afterwards (diplomacy screen modifiers).
- **Verdict:** the exploit is real if the AI received less than half the payments it asked for and its terms were
  priced for the full deal. Pass with the fix: the terms ask for the payments over the turns the human is bound,
  or for a lump sum instead.

*Check 2: help-request re-roll* (`DiploBugs`, D13):
- **The save:** the human has a Declaration of Friendship with an AI that has at least 300 more gold than the
  human, and hasn't asked it for help in the last 30 turns.
- **Turn 0:** open the trade screen with the friend, put 50 of its gold on its side, and use "make a request".
  If it refuses, open the screen again and repeat, up to 10 tries in the same turn.
- **Measure:** the number of tries until it says yes, and what the reply was after the first refusal.
- **Verdict:** with B the expected result is a yes within a few tries. Pass with `DiploBugs`: after the first refusal,
  every later try that turn (and for the next 10 turns) gets "too soon".

*Check 3: a bluffed demand* (no fix coded yet; `FIX_DEMAND_BLUFF` planned):
- **The saves:** two, both with the human at peace with an AI neighbour that has walls in its border city and at
  least 3 archers or better. Neither has a friendship or denouncement with the other.
  - **Bluff save:** 5 warriors or spearmen, no siege, parked on the human's side of the border within 3 tiles of
    that city.
  - **Real save:** 4 catapults and 4 swordsmen (or that era's equivalent) parked in the same place.
- **Turn 0:** demand 100 gold, then reload and demand one of the AI's luxuries.
- **Measure:** accepted or refused, in each save.
- **Verdict:** the exploit is real if the AI pays in the bluff save. Pass with the fix: it refuses the bluff and
  still gives in to the real threat. If it refuses both even on B, bluffing isn't a live exploit and
  `FIX_DEMAND_BLUFF` can wait.

**Answers to the other requests.**
- **L3** (Economy: domination progress counts a share of world military might): it's part of the coalition problem.
  Others read a civ's domination progress in `IsCloseToWorldConquest` (needs 50) and endgame aggression. So a peaceful
  tall civ with a big defensive army reads as "close to world conquest", and gets targeted for its army rather than
  its deeds. Goal 2 says judge by behaviour. Plan: with `FIX_COALITION_STRENGTH`, a civ's military share counts only
  up to twice its share of original capitals held. A civ holding only its own capital (1 of 8) tops out at 25%;
  one holding 3 tops out at 75%. Coded with the coalition flags, after War's capture fixes. Its effect on the civ's
  own pursuit (it switches to domination at 50) goes to Personality.
- **L2** (science progress counts every project and Apollo twice): plausible but unverified. Whether Apollo has its
  own space-race threshold is in the base game's XML, which isn't in the fork. It only matters past ~80% of techs,
  which no test game reaches. Noted for phase 2 with the late-game tests.
- **War's second point** (joint wars, demands and city-state statements declare war without an army in place):
  agreed. As War said, the logged games first need to show it happening. I'll take it once they're in: the
  joint-war path (`DoStartCoopWar`) is the one that matters for coalitions.

### Diplomacy: gold gifts to city-states, measured, and a flag proposal `GiftsNeedPatronage` (Diplomacy session, 2026-11-04)

The user's idea: AIs should gift city-states mainly with the Patronage tree, since without it the gifts are poor value.

**Measured** (`DiplomacyAI_MinorCiv_Log.csv`, gifts that went through; "(SAVING)" lines are gold being set aside, not
gifts):

| Game | Gold gifted by all 8 civs by T150 | Biggest giver |
|---|---|---|
| `0879B791` | 3,750 (14 gifts) | Venice 1,500 (city-state trait) |
| `0879B791F` | 2,500 (8 gifts) | Arabia 1,000 |
| `0B09BFE1` | 1,250 (5 gifts) | Songhai 500 |
| `0B09BFE1F` | 1,250 (5 gifts) | Songhai 750 |

- **Gifts are rare and small:** 0-1,500 gold per civ in 150 turns, in 250 and 500 lumps. No unit gifts appear in the
  logs.
- **Who had Patronage can't be measured.** The results files only count policies, and no log records the branches.
  **Request for the lead:** a results column with the policy branches each civ has opened (e.g. `Branches` =
  `Tradition+Patronage`).

**How CP decides** (`CvDiplomacyAI::DoContactMinorCivs`, ~36200 and ~36695):
- **Whether to gift this turn:** almost always. Any of these is enough: diplomacy flavour 4 or more (most leaders), a
  diplomatic or culture victory pursuit, gold already saved for a gift, an active gold quest, or +100 gold a turn.
  Otherwise a random roll on the diplomacy flavour.
- **Which city-state:** scored by maritime growth, resources we lack (+80 each), gold and invest quests (+150, +100),
  victory focus, city-state traits, and proximity.
- **Whether the gift is worth it:** only when it makes us an ally or overtakes the current ally. That's why the totals
  are low.

**Is it poor value without Patronage?** Not always.
- **What an alliance pays:**
  - the ally bonus (a maritime ally feeds every city);
  - the city-state's luxuries and strategic resources;
  - its World Congress votes later.
- **What it costs:**
  - influence decays about 1 a turn, so 250-500 gold buys a few dozen turns of alliance;
  - an AI rival can outbid you.
- **What Patronage changes:** slower decay and more influence per gift, so the same gold lasts much longer.
- So without Patronage a gift is a short rental. It's worth it when the alliance brings something specific, and poor
  value as general goodwill. That's the user's rule plus its exceptions.

**Proposed flag `GiftsNeedPatronage`** (level 3, not coded yet).
- **The rule:** a civ that hasn't opened Patronage makes no gold gifts to city-states, unless one of these holds:
  1. **Traits that reward city-states:** a city-state friendship or bonus modifier (Greece, Siam), or Austria's buyout
     or Venice's (CP trait fields, so the list follows the data, not leader names).
  2. **Diplomatic victory:** pursuing one while the World Congress is in session (or the United Nations counts).
  3. **An ally worth keeping or taking:** the city-state is our ally or would become it with this gift, and it gives
     us a luxury or strategic resource we'd otherwise lack.
  4. **A quest that pays off:** the city-state's "give gold" or "invest" quest is active for us.
- **Hypothesis:** less gold wasted on short alliances, spent on buildings and units instead, with no loss of alliances
  that matter.
- **Measures:**
  - gold gifted per civ (from this log; or a `GoldGifted` count, for the lead);
  - city-state alliances held at T150;
  - strength share: a no-worse test, since the gold involved is small (about 300 gold per civ per 150 turns).
- **Expected effect: small,** because the AIs already gift little. If the user rules it obvious, it can go straight
  into the bundle after a crash check.
- **Decision (user, 2026-11-04): obvious, straight to the bundle.** Coded and pushed: `ai/diplomacy` `d635f51`, flag
  `GiftsNeedPatronage`, **in the bundle** (`true`), not compiled yet.
  - **The Patronage check:** `IsPolicyBranchUnlocked(POLICY_BRANCH_PATRONAGE)`.
  - **The trait exception:** reads CP's trait fields (city-state friendship or bonus modifier), so it covers whichever
    leaders have them in the data.
  - **Crash check:** gifts are decided only in major civs' diplomacy turns (`DoContactMinorCivs`), and the helper
    returns early for non-majors, so city-states running the bundle can't reach it.

### Diplomacy: flag `WarAppetite`, and bundle flags checked for city-states (Diplomacy session, 2026-11-04)

**City-state check** (the lead's C8 crash note: city-states run every bundle flag).
- Diplomacy's bundle flags are `EasyTarget`, `DiploBugs`, `LuxuryAsk` and `DealExploits`. None of their code runs for
  a city-state as the deciding player:
  - `CvDiplomacyAI::DoTurn` is only called for major civs (`CvPlayer.cpp` ~10291);
  - city-states don't trade (`CvDealAI`) or sit in the World Congress as AI voters;
  - help requests, demands and war-declaration memory are major-to-major.
- New Diplomacy flags check `isMajorCiv()` as well.

**`WarAppetite`** (pushed to `ai/diplomacy` `916925b`, on `claude/ab-c1` `af99bc1`; off in the bundle, not compiled).
- **What it does:** Personality's profile sets the war appetite. The WAR approach weight follows the meta position M:
  x0.5 at -100 (greedy), x1 at 0, x2 at +100 (aggressive), linear between. It applies after the opinion multipliers,
  so friends still count, just less overwhelmingly for a conqueror. M is the home position until `MetaAdapt` moves it.
- **Why:** the aggressor stays FRIENDLY to everyone (entry below). `TradeOpinion` removes the trade-made friendship;
  this one makes aggressive leaders want war more and greedy ones less, as the profile intends.
- **Hypothesis:** the bully aggressor (an aggressive archetype) declares its first war earlier, and greedy/tall civs
  start fewer wars.
- **Measures:** the aggressor's `WarsDeclared` and first-war turn (bully test, together with `TradeOpinion`); wars
  started by tall civs (builders test); no-worse on strength.
- **Not done here:** the profile's hard rules.
  - The archetype rules (`ExpansionistPeace`, `BuilderPeace`, `DiplomatWord`, ...) are Personality's step 5.
  - The everyone-rule "no war on a civ it's exchanging per-turn deal items with" needs a decision first. AIs nearly
    always have a luxury swap running with their neighbours, so as written it would forbid most wars and deepen the
    "nobody fights" problem.
  - A narrower version keeps the honesty: don't renew deals with a civ we plan to attack, and declare only once our own
    obligations have run out. That's for the user and Personality to decide.
- **Decision (user, 2026-11-04): no such rule.** An AI may declare war on a civ it's trading per-turn items with.
  Breaking a deal by war already costs trust: `DealReputation` discounts the breaker's promises, and with
  `TradeOpinion` the trade-partner opinion goes with the cancelled deals. **For Personality:** drop the deal clause from
  the everyone-rules in section 5 of the profile. The friendship clause (no war on a friend in the friendship's first
  15 turns) is unaffected.

### Diplomacy: why the failed Celtic war ran 35 turns, and flag `StaleWarPeace` (Diplomacy session, 2026-11-04)

From `DiplomacyAI_Peace_Log.csv` and `DiplomacyAI_Log.csv` of bully game `0879B791` (War's "Bully conquest, logged pair").

**It's the winner that kept the war going, not the failed attacker.**
- **The Celts were willing to make peace** on 10 turns from T116 on, with peace scores of 19-129 against a required
  17-20.
- **The Netherlands refused on every turn.** On 17 turns: "no good reason to consider peace" (before the 30-turn mark,
  or while its approach was WAR). On the rest, a peace score of -3 to -67 against 20.
- **It rated the Celts PATHETIC, but never attacked them.** War state Calm until T150, no captures.

**Why the winner holds out** (`DoUpdatePeaceTreatyWillingness`, part 8):
- **The hold-out term.** "They're in danger and we're not": `-5 × their danger × our multiplier`. The multiplier goes
  up by 1 for each of: they're weaker than average, they're an easy target, we have a preferred attack target in
  them, they're nearly beaten. Against a beaten neighbour that's up to ×5.
- **The war-state term.** Calm subtracts another 2 × the multiplier.
- **The pull toward peace is weaker.** Lack of progress against a neighbour adds only (war turns - 10), so +29 by T150.
- **The result.** Units parked near the Celtic cities count as leverage every turn, though the Dutch AI never uses
  them. The diplomacy side waits for a conquest the military side never attempts. It's the same mismatch as the WAR
  approach held for 20-56 turns without a declaration (earlier entry).

**Flag `StaleWarPeace`**: patch `tools/ab/patches/diplomacy/c13/0001-...`, on `claude/ab-c1` `c13eb1c`, off in the
bundle, not compiled.
- **When a war counts as stale:**
  - at least 20 turns of war;
  - no city has changed hands between the two civs, in either direction, for 20 turns;
  - we have no attack operation against them.
- **What it changes for a stale war:**
  - staleness alone is reason to consider peace;
  - the "they're in danger, hold out" term is dropped;
  - the lack-of-progress penalty counts twice.
- A winner that presses an attack, or has just taken a city, is unaffected.
- **Hypothesis:** wars where neither side takes anything end in peace within about 20 turns of the last capture. A
  losing civ stops bleeding units, and its army is free again.
- **Measures:**
  - turns at war per war without a capture in its last 20 turns (from `AtWar` and `CitiesCaptured`);
  - peace treaties per game;
  - strength: no-worse;
  - in the bully test, whether the aggressor's failed wars end sooner;
  - whether it makes peace more often against coalitions.
- **The trade-off to watch:** a coalition war against a conqueror can also be stale for a while, and ending it early
  helps the conqueror. Run the bully test with and without the coalition flags.

### Diplomacy: why even the aggressor almost never picks WAR (Diplomacy session, 2026-11-04)

The logged bully pair `07614B74` / `07614B74F` (ab-095144c), from `DiplomacyAI_Approach_Log.csv` and
`DiplomacyAI_Approach_Deltas_Log.csv`. Songhai, the aggressor, runs B.

**What the logs show.**
- **Songhai was FRIENDLY to every civ for most of the game:** 521 of 610 pair-turns.
- **Toward its neighbour Portugal,** the FRIENDLY score went from 107,599 at T79 to 330,163 at T126, against
  WAR at 4,977 and 1,314. Portugal became a friend (FRIEND by T101, ALLY by T126), which zeroes WAR outright.
- **Toward its other neighbour Arabia,** FRIENDLY led until T107 (HOSTILE), and WAR only won at T151.
- **No fear and no warmonger threat:** AFRAID 0 turns, threat NONE throughout. The warmonger and AFRAID
  mechanisms don't come into it.
- **Peace treaties don't explain it** either: there were no wars to make peace from.

**Why: trade makes everyone friends, and a friendly opinion multiplies FRIENDLY and divides WAR.**
1. **Trade alone makes a neighbour liked.**
   - Every accepted deal adds to "recent trade value". Its opinion bonus maxes at -40 (`OPINION_WEIGHT_TRADE_MAX`;
     `DEAL_VALUE_PER_OPINION_WEIGHT` 5, decay 2 a turn).
   - That alone passes the favorable threshold (-30).
   - Songhai made 40 deals in 150 turns, and every civ made 2-3 deals per 10 turns, mostly luxury swaps. So
     neighbours stay "Favorable" whatever else happens.
2. **Opinion is applied as a percentage to the scores** (`SelectBestApproachTowardsMajorCiv`, around line 20930).
   With a favorable opinion, FRIENDLY is multiplied by (100 + FriendlyMod + |opinion|)% and WAR is divided by
   (100 - WarMod + |opinion|)%. At opinion -50 that's roughly a 2-3x swing each way, before any war logic runs.
3. **Friendly leads to a Declaration of Friendship, and a friendship zeroes WAR** (and HOSTILE, AFRAID) at that
   step. So a neighbour that trades with you becomes untouchable.
4. **The scores are smoothed:** 30% of the new value each turn (`APPROACH_SHIFT_PERCENT`). A WAR spike has to last
   several turns to win, and FRIENDLY at 100,000+ needs a large, steady shift.
5. **The war-target filters never get a say:** they only act once the approach is WAR. Toward Arabia, where it
   finally was (T151), the game ended.

**What this means.**
- The AI's war appetite is crowded out by the trade economy. The more AIs trade, the less they fight.
- `LuxuryAsk` (in the c8 bundle) adds luxury swaps, so it pushes the same way. Its no-worse test on strength
  wouldn't show this.
- **This is personality territory** (how much trade should buy friendship, per leader), so it's a request
  rather than a Diplomacy fix.

**Coded (user's model, 2026-11-04): flag `TradeOpinion`**, patch `tools/ab/patches/diplomacy/c8/0001-...`, on `claude/ab-c1`
`9f77273`, off in the bundle, not compiled yet.
- **The user's model:** a civ that gets a luxury from another values that relationship by what a war would cost it.
  So the trade-partner opinion should come from the deals running now in which the other civ supplies us. It goes
  when they expire (or a war cancels them) and comes back when they're renewed.
- **Weights:** -5 per luxury, -3 per strategic resource, -2 for open borders, -1 per 5 gold per turn. Capped at -20,
  so trade alone stays below Favorable (-30). CP's decaying memory of past deals reached -40.
- **Hypothesis:** aggressive leaders pick WAR toward neighbours they merely trade with, while a neighbour that
  supplies several luxuries still costs something to attack.
- **Measures:** the aggressor's `WarsDeclared` and the turn of its first war (bully test); the friendship count; the
  builders' wars (builders test); `Deals` per civ, which should stay in the band since the trades themselves don't
  change.

**Other possible fixes**, not coded:
- **Trade opinion by personality:** scale the recent-trade opinion by the leader's boldness and meanness. A warmonger
  doesn't love you for selling it silk; a diplomat does.
- **Trade opinion below the threshold:** cap trade's share of the opinion so that trade alone can't make a neighbour
  "Favorable" (half of -40, i.e. -20).
- **Expected effect:** more WAR approaches from aggressive leaders toward neighbours they merely trade with, measured
  as the aggressor's `WarsDeclared` in the bully test. Check the builders test too: tall civs that trade a lot would
  lose some of that protection, which may be right ("attack a builder who leaves itself weak").

### Diplomacy: the screening-build-2 crash (Diplomacy session, 2026-11-03)

**What happened.** Screening build 2 (`2d949f8`) halted with CP's assert "Player index out of bounds" in
`CvDiplomacyAI::IsEndgameAggressiveTo`. My bug, in `EasyTarget`'s D2 fix.

**The path.**
- `DoUpdateEasyTargets` loops over the other wars we're in, and that loop covers every player, city-states included.
- D2 changed its phony-war test from the target to the other enemy, so a war with a city-state called
  `IsPhonyWar(city-state)`.
- That calls `IsWantsToConquer`, which calls `IsEndgameAggressiveTo(city-state)`, which asserts.
- CP only ever calls `IsPhonyWar` for majors (for example, the `!bMajor ||` guard in `DoUpdatePeaceTreatyWillingness`).

**When it fires.** Only when a civ that has the flag is checking a target while also at war with a city-state. So
it shows up only in screened games, and in some of them.

**Fix:** patch `next/0008`, on top of `ai/diplomacy` `04a533b`.
- **The flagged change:** D2 checks phony wars with majors only. Still gated by `EasyTarget`; without the flag the code
  is CP's.
- **The callee:** `IsEndgameAggressiveTo` returns false for a non-major index instead of asserting. Ungated, since it
  only replaces an out-of-bounds read.

**Checked as well:**
- D1 itself lets city-states at peace be rated easy targets. Every reader of `IsEasyTarget` already saw city-states
  as easy targets during wars in CP, so no major-only path opens.
- My other new code guards majors before calling anything major-only: `CoalitionStrength` (`isMajorCiv` first),
  `IsVisiblyAgainstWarmonger`, and `DealReputation` (`ePlayer < MAX_MAJOR_CIVS`).

### Diplomacy: what War's 3 logged King games show (Diplomacy session, 2026-11-03)

Games `02DEF5BF`, `02EA597F` and `02F5C9E3` (build `ab-ai-war-latest` 445009c, results in `AIABTest_c7c_proposals.csv`), read
from `DiplomacyAI_Log.csv` (each AI's approach, opinion, strength estimates and warmonger threat toward every major,
every turn), `DiplomacyAI_Messages_Log.csv` and the results rows. Script:
`tools/ab/diplo_logs.py <results folder>`. No city changed hands, so these show B's diplomacy without a conqueror.

**1. The AFRAID diagnosis can't be checked here, and nothing contradicts it.**
- **Warmonger threat was NONE** for every pair on every turn of all three games, and no pair was ever AFRAID.
  That's what the code predicts: threat comes from conquests, and AFRAID needs a POWERFUL or IMMENSE neighbour.
- **Strength estimates stayed between PATHETIC and Strong:** no civ pulled far ahead by T150.
- **The check needs the bully test with a conqueror that takes cities** (War's work). Watch `W_THT` and `AFRAID` in
  `DiplomacyAI_Log.csv` for the observers of the aggressor.

**2. AI-to-AI demands never happen; joint-war proposals are rare.**

| Game | Demands | Joint wars asked / agreed (counts) | Deals per civ per 10 turns | Wars declared | Friendships / pacts at T150 | Denouncements |
|---|---|---|---|---|---|---|
| `02DEF5BF` | 0 | 4 / 1 | 3.0 | 6 | 5 / 4 | 15 |
| `02EA597F` | 0 | 5 / 0 | 2.2 | 3 | 6 / 3 | 9 |
| `02F5C9E3` | 0 | 6 / 2 | 2.9 | 5 | 6 / 3 | 24 |

- **The demand half of `DealExploits` and D13 (help requests) will look neutral in the screen.**
  - No AI demanded anything from another AI in 450 game-turns.
  - Help requests are human-only.
  - So exploit checks 2 and 3 are their real test.
- **Deals are already above the goal band** (0.5-2 per civ per 10 turns).
  - Most are luxury swaps ("You have a Luxury I would like": 40-57 per game), renewals (30-51) and embassies.
  - So `LuxuryAsk` (more luxury swaps) could push the rate further above the band.
  - Either the band needs the second look the scoreboard promised, or `LuxuryAsk` isn't wanted. I'd raise the band: a
    luxury swap is the kind of activity that makes the world feel alive, and nobody sees it as spam.
- **The world isn't dead:** 9-24 denouncements per game (land, "enemy of friend", "untrustworthy", dogpiles), 3-6
  friendships, 3-4 pacts.

**3. Where `EasyTarget` (D1) would have acted.**
- **What the proxy is.** Pairs at peace, with the observer at peace with everyone, the target close or a neighbour,
  rated POOR or weaker, and the target value Favorable or better. That's roughly what `DoUpdateEasyTargets` evaluates
  past its CP early exit.
- **How many.** 14, 5 and 7 such pairs per game, holding for 3-57 turns.
- **Most of them are friends** (opinion FRIEND/ALLY, approach FRIENDLY). A Declaration of Friendship zeroes WAR in the
  approach scores, so D1 shouldn't turn those into wars.
- **Where it can matter:** non-friends who are already cool on the target.
  - `02DEF5BF`: Siam → the Huns (approach HOSTILE/WAR for 13 of 21 turns, war came at T130), Siam → the Maya (T108),
    India → the Huns (T130).
  - `02EA597F`: Sweden → Persia (27 turns, opinion Favorable, never war).
  - `02F5C9E3`: Arabia → England (WAR approach 22 turns, never declared).
- **Prediction.** These wars come a few turns earlier, plus a handful of new ones. A modest rise in `WarsDeclared`,
  concentrated in non-friend pairs.

**4. For War: the WAR approach is held for a long time before a war actually starts.**
- **Sweden → Babylon** (`02F5C9E3`): WAR approach from T53, declared T109, so 56 turns.
- **England → Germany:** 36 turns (T75-T111).
- **Never declared:**
  - The Celts → Babylon after their first war: WAR approach on 41 peace turns, target PATHETIC.
  - Arabia → England: 22 turns, target PATHETIC.
  - Sweden → Brazil (`02EA597F`): 17 turns, target PATHETIC.
- **A peace treaty explains at most 16 of those turns** (the dampener).
- **So the diplomacy side decides "war" long before the military side delivers.** That's War's "the army never
  comes" problem, seen from the diplomacy logs. War can match these pairs and turns against
  `OperationalAILog.csv`: was an attack operation formed, and why did it end?

**What changes for Diplomacy.**
- Nothing in the coalition plan: it still waits for captures.
- The screen's verdict on `DealExploits` and `DealReputation` will be "no harm" at most. Their real tests are the
  exploit checks, which don't need AI games.
- I'll bring the war-delay pairs to War rather than touch declarations from the diplomacy side: the approach is
  already WAR, so the delay is in the military AI.

### War session: why attacks fail, ranked against the code (2026-11-02)

The causes in "Why wars almost never take cities", ranked by how much each would explain, each checked in the fork
(`claude/ab-c1` at `6b8ebde`). Paths are in `CvGameCoreDLL_Expansion2/`. No new logs were read: the only digest in
`results/` (c7c game 2) predates the "military ops ended" counts, so the ranking is from the code plus the log
quotes above.

**How an attack works in this code** (needed to read the rest). An attack operation only delivers an army: when its
centre is within 3 tiles of the target city (`GetDeployRange`), it ends as a success, the army is disbanded, and a
5-turn tactical focus area is put on the city (`CvAIOperationMilitary::OnSuccess`). From then on the siege is the
tactical AI's, zone by zone: each zone gets a posture from the dominance ratio (`CvTacticalDominanceZone::SelectPostureSingleZone`)
and the posture decides whether the city is attacked at all. A sneak attack is the same operation at peace: on
arrival it tells the diplomacy AI `SetArmyInPlaceForAttack`, and `DoMakeWarOnPlayer` declares the next turn.

| Rank | Cause (diagnosis number) | Confirmed in code | What it would explain |
|---|---|---|---|
| 1 | **The army bleeds out (3)** | Yes. `CvUnit::shouldHeal(false)`, the second heal pass (`CvTacticalAI::PlotHealMoves(false)`, after the attacks), sends any unit with **more than 20 damage** that isn't adjacent to an enemy back to heal. Catapults and archers fire from 2 tiles, so they aren't adjacent: one city shot (20–30 damage) and the unit leaves the siege the next time it doesn't fire. Units under 70% HP can't be recruited into a new attack either (`IsUnitSuitableForRecruitment`). Meanwhile the city heals 20 a turn (`CvCity::doTurn`), unless every adjacent tile is blockaded | The Ottomans' 161 → ~65 expected damage a turn in 8 turns: every siege, both groups |
| 2 | **The tactical AI won't commit (2)** | Yes, two ways. (a) In the **attrition** posture `PlotAttritionAttacks` never attacks a city, not even with ranged units ("don't expose our units for city attacks here"). An enemy zone gets attrition when it's even but the enemy has more melee strength and we have ranged dominance: exactly a siege army of catapults and archers facing a garrison. (b) The zone counts the city's full strength as enemy ranged strength, scaled by its HP; when the enemy is 1.7× ours the posture is withdraw and `ExecuteCaptureCityMoves` logs "enemy dominated zone - won't try to capture". Damaged units count for less, so 1 feeds (b) | Armies standing 2–4 tiles from a city for many turns without firing at it |
| 3 | **War declared before the army is there (1)** | Partly. The sneak attack does wait for its army, but its "discovered by enemy" shortcut (`CvAIOperationMilitary::CheckTransitionToNextStage`, moving state) counts as arriving when **3 or more of its units are visible to the enemy, wherever the army is**: an enemy scout or border city seeing it in our own land is enough. The army is then disbanded far from the target, its units can't join a new attack for 5 turns (`IsRecentlyDeployedFromOperation`), and the follow-up operation musters at our nearest city. That fits Greece (declared T77, attack formed T85, arrived T101). Other declaration paths (coop wars, demands, city-state statements) don't wait for an army at all; the diplomacy log says which one fired | The 10–25 turn gap between declaring and arriving, and the target's time to build walls and units |
| 4 | Ranges favour the city early (4) | Structural (CP data), not a bug | Why 1 matters so much: every siege unit takes city fire |
| 5 | Wrong targets (5) | Mostly a test artefact (c picking c) plus CP's own war logic. The choice is in `CvDiplomacyAI::GetNewAIConquestTarget` (not a War file): request below | Some wasted wars, no failed sieges |
| 6 | Audit item 26, abort below 2/3 (B) | Fires only while gathering or moving (`CvAIOperation::UnitWasRemoved`; armies never reach the at-target state because they are disbanded on arrival). With the ancient formation (4 required slots) it aborts at 2 units left, as CP would at 1; classical-medieval (5 required) at 3 left, CP at 1. It ends thin armies on the way, which can't take a city anyway. The one digest has 1 `HalfStrength` in 24 aborts | Probably little. Count it before asking for an ablation (request below) |
| — | (new) `NoTarget` aborts every turn | Unknown. In c7c game 2, five civs abort an operation with `NoTarget` on almost every turn for 10–20 turns in a row (Austria T130–T151). The digest's "ops aborted" line mixes all operation types, so it isn't clear which. An operation created and dropped every turn can tie up units | Unknown: the logs will say |

**Not the cause:** a newly started attack doesn't pull back a just-delivered army: units within 3 tiles of the target
or deployed in the last 5 turns aren't recruited (`IsUnitSuitableForRecruitment`).

Each fix below gets one flag, **off in the bundle** (so a non-test pack and the c7c bundle stay as they are; turn it on
with `Fixes =` or `Screen =`). Shared file: the flag names go in `CvPlayer.h` (`CandidateFixTypes`, appended at the
end) and `CvPlayer.cpp` (`kCandidateFixNames`, `kCandidateFixBundle`); nothing else in `CvPlayer` changes.

### FIX_SIEGE_STAY: units at a siege don't leave to heal at 20 damage (War)
- Hypothesis: units within 2 tiles (3 for ranged units) of an enemy city that is already damaged stay at the siege
  unless they are below a third of their HP or projected to die next turn, instead of leaving at 20 damage. Damage per
  turn on a besieged city stays above its 20 HP healing for longer, so more sieges end in a capture. Only the heal
  decision in `CvTacticalAI::PlotHealMoves` changes; the first pass already uses the one-third rule, so in practice
  this is the second pass (units that didn't attack this turn).
- Measure: `CitiesCaptured` per game by group (the mechanism); strength share at T150 (the verdict). In logged games,
  "attempting capture of X ... expected max damage per turn" should fall more slowly over a siege.
- δ: +2 points of strength share; CitiesCaptured should rise from about 0.2 per game.
- Build: `ai/war` commit `5ae5a94` (rebased by the lead onto the 64-bit flag table, `cca50d8`); patch `patches/war/0001`
- Test: SPRT gainer, paired, King/Pangaea/Strategic Balance/no ruins/Quick, T150. It only matters once a group is at
  war, so screen it with `TimingAttack` on (the bundle) or in the bully test.
- Status: hypothesis
- Notes: risk: more units die at the siege. If losses climb without captures, try "stay only while expected damage
  beats healing".

### FIX_SIEGE_POSTURE: attrition posture also bombards the city (War)
- Hypothesis: in an attrition zone (an even enemy zone where we have the ranged edge and they have the melee edge), the AI also runs the city attack
  (`ExecuteCaptureCityMoves`) at the lowest aggression level, so the combat simulation only takes safe shots: ranged
  units bombard, melee units only go in when it's safe or the city falls. Its other checks stay (not in an
  enemy-dominated zone; damage minus healing must take the city within 13 turns). Armies stop standing next to cities
  without firing.
- Measure: CitiesCaptured by group; strength share at T150. In logged games, more "attempting capture" lines per
  war-turn and fewer turns from arrival to the first city attack.
- δ: +2 points of strength share
- Build: same commit `5ae5a94` (all three flags in one commit, each behind its own flag)
- Test: SPRT gainer, paired, T150, as above. Best tested together with SIEGE_STAY later (they act on the same
  sieges), but each first on its own.
- Status: hypothesis
- Notes: the withdraw-when-dominated rule (cause 2b) is left alone on purpose: it's the tactical AI's safety
  valve, and SIEGE_STAY should keep fewer zones from tipping into it.

### FIX_DECLARE_AT_BORDER: a sneak attack declares only once its army reaches the target's border (War)
- Hypothesis: the "discovered by enemy" shortcut only counts when the army's centre is in or next to the target
  civ's territory, or within 6 tiles of the target city. Spotted earlier, it keeps marching (at peace nobody can
  attack it), so war starts with the army at the border instead of at home, and the gap between declaring and
  arriving shrinks from 10–25 turns to about 1–3.
- Measure: turns from war declared to the first city attack (logged games, `OperationalAILog.csv` and
  `PlayerTacticalAILog.csv`); CitiesCaptured; strength share at T150.
- δ: +1.5 points of strength share (it only touches sneak attacks, so a smaller edge is worth keeping)
- Build: same commit `5ae5a94` (all three flags in one commit, each behind its own flag)
- Test: SPRT gainer, paired, T150.
- Status: hypothesis
- Notes: check in a logged game first that wars really come from this path: a war line in the diplomacy log right
  after "Discovered by enemy" in the operations log. If most wars come from coop wars or demands instead, this fix
  matters less and those paths need the same rule (they're in Diplomacy's files).

### War: failed bully wars with the 12-flag role, 0BC677BF and 0AFFA02F (Nov 4, about 11:05am ET)

**0BC677BF** (PC 2, greedy opponents, ab-ed449fd). Aggressor Spain.
- **The attack:** "CONQUEST: going for England" at T64. The sneak attack at T106 recruited 7 units with **3 catapults**,
  passed SiegeArmy's bar at once, and Spain declared at T114.
- **At Nottingham:** 40 expected damage a turn at T114, then about 20 from T115 to T120.
- **The surprise, T141–T148:** "attempting capture of Nottingham" every turn at 61–73 expected damage a turn, yet the
  city started every turn at **200 HP**. The capture attempts did nothing lasting: either no attacks were made, or they
  did no more than the city heals. The logs record expected damage, not what was done.
  - The tactical simulation ran each turn at high aggression with 6 units ("tactsim around (37:28) with agg 3 ... 834
    completed").
  - Spain lost 3 units in the whole war, England none.
- **SiegeFinish never triggered** (the city never fell below a third of its HP).
- **SiegeAbort** called off a second attack at T140 ("still too weak after 20 turns").

**0AFFA02F** (PC 1, normal opponents). Aggressor Japan, "CONQUEST: going for The Aztecs" at T48.
- **The attack waited:** from T57 at 39–42 a turn against bars of 60–70. It marched at T71, arrived at T83 (26 turns
  after it started) and declared on the Aztecs.
- **The siege:** best 29/200, no attempt made.
- **Attacks cancelled at creation:** two sneak attacks ended `NoUnits` the turn they were created (T55, T56). The
  basic formation (SiegeFormation) has 6 required slots, so a small army misses more of them at creation. Minor:
  the third try held.

**Next.** The open question is why a 70-a-turn siege did no damage. `ai/war` `9e9fc9d` (built, CI run 150) (patch 0013) adds a log line,
logging only, after each city capture attempt: "capture attempt on X done: city HP a -> b, n of m units used, agg L".
The next logged war shows whether attacks happen. If they don't, the cause is in the combat simulation's choice:
positions, set-up moves, or its scoring of attacks against cities.

### War: strike on readiness, not the calendar: a design for the next block (Nov 5, about 10:50pm ET; no code yet)

**Revised (the user, via the lead, about 10:37pm ET: "dont have the ai judge itself based on the window during a game").
No turns in the AI's decisions at all; turns only in our logs and analysis. This replaces the soft limits and grace
below.**
- **Open the build-up** on state: the strike's core unit (or the plan's pre-build) can be trained, the opening book is
  done, and a target is in reach (Economy's IsEarlyStrikeTargetInReach for EarlyStrike; a major's city within reach for
  LateStrike).
- **Declare** on readiness:
  - the plan's upgrade tech known (or none);
  - core and support at the plan's counts;
  - 3 melee that can take a city;
  - the upgrade bill paid;
  - siege per the plan.
  Or on "as ready as it gets": the field army at least the normal target and nothing more coming (WarBudget's
  affordable at 0 or below, and no unit in production for the strike).
- **Exit** on game state, never a turn. Each one ends the strike and falls back to the late plan (the normal
  TimingBuildup with siege):
  1. the target's nearest city walls up, and the plan brings no siege;
  2. the target fields the counter (units with a bonus against the core's combat class near its border: spearmen and
     pikemen against horse, for example);
  3. no flat, unwalled target in reach (the target choice finds none);
  4. the core unit goes obsolete (its obsoleting tech known by us);
  5. the strike failed: at war, the army fell below half its size at the declaration without a capture;
  6. a threat at home: a major declares on us, or enemy units are in our cities' zones.
- **Turns in today's strike code, each replaced by the state above:**
  - the window's length and WindowUntilReady's 2 windows;
  - Personality's declare-by, close and fallback turns (the build-up's limit, the target rule's limit, the barbarian
    hunt's limit);
  - EarlyStrike's T60 Standard build-up limit;
  - Economy's T90 Standard small-empire limit (IsEarlyStrikeSmallEmpire) and T75 Standard fallback (the book's
    fallback);
  - LateStrike's open and fallback turns;
  - the 8-turn "tech soon" in the upgrade bill, which becomes "the current research is the strike's upgrade tech".
- **Personality's plan** carries conditions, not turns: eUpgradeTech, the counts, bSiegeOnlyIfWalled / bHardStopOnWalls,
  the core's counter classes (or War derives them from the core's combat class), iMinFieldArmy. The turns stay in the
  plan for the logs and the read only.
- **Economy** (book half): the same, with no T75/T90 limits. The book ends on the strike's start or one of the exits.
- **The read keeps the turns:** readiness against the plan's reference turns, as now in expert_block.py.

LEAD: revised design, no turns in decisions. Open on state (core trainable, book done, target in reach). Declare on
readiness, or "as ready as it gets". Exit on six game-state conditions. Turns are listed for removal across War, Economy
and Personality. Say go and I'll code War's part on ai/war for the next block. Economy and Personality: the same in your
halves (Economy's T75/T90; Personality's turns as references only).

**The shared state (Economy's proposal, 10:38pm ET, settled here): CvMilitaryAI::GetStrikeState() const.** One enum,
StrikeStateTypes, worked out from game state once a turn and logged when it changes ("Strike: PREP -> BUILDUP (why)").
- **STRIKE_NONE:** not a strike civ (neither EarlyStrike's nor LateStrike's plan).
- **STRIKE_PREP:**
  - EarlyStrike: the military-first opening, before a target is in reach.
  - LateStrike: economy first, before Personality's economy-ready condition (the plan's K cities settled; Personality to
    define the rest).
- **STRIKE_BUILDUP:** the trigger has fired. EarlyStrike: a target in reach and the core trainable. LateStrike: the
  economy-ready condition. Within it:
  - Economy beelines the spike tech, then the upgrade tech, and keeps gold (no purchases) for the upgrades.
  - War's unit weights (core, support, siege, 3 melee) start only once the core or the plan's pre-build can be trained.
    Before that, War does nothing in BUILDUP but hold upgrades. This is Economy's option (a): the beeline happens inside
    BUILDUP, and the army waits for the tech.
- **STRIKE_WAR:** the strike's declaration made (ready, or as ready as it gets). Economy's spending reopens; War's
  upgrades come first.
- **STRIKE_OVER:** ended by any of the six exits, or a capture followed by peace. The book, the K-city cap and the saving
  end; the late plan (normal TimingBuildup) runs.

Economy reads only GetStrikeState(), no turn: the book and K cap until OVER, no purchases in PREP and BUILDUP, the beeline
and saving in BUILDUP. War's own IsEarlyStrikeBuildup / IsLateStrikeBuildup / IsStrikeBuildup become thin wrappers over it.
Today's names (IsEarlyStrikeBuildup etc.) aren't a fit for Economy: they're turn-limited.

LEAD: shared state settled: CvMilitaryAI::GetStrikeState() with NONE / PREP / BUILDUP / WAR / OVER, all from game state,
logged on change. Economy: write 0034 against it. The beeline is in BUILDUP (your option a), and War's unit weights wait
for the core to be trainable. Personality: define the economy-ready condition that moves a late civ from PREP to BUILDUP.
War codes GetStrikeState and the exits on ai/war on the lead's go.

**Coded (the lead's go, 10:41pm ET): ai/war 56e0cadc.** GetStrikeState with the exits above, for EarlyStrike and
LateStrike. Every turn in the strike decisions is gone:
- the build-up's length, WindowUntilReady and declare-by for a strike;
- Personality's close and fallback turns;
- T25, T40 and T45 for strike civs;
- the T60 build-up limit;
- the 8-turn "tech soon";
- the hold's T90 and IsLateStrikeSaving turns.

Specifics:
- "In reach" is the committed target's nearest city within 12 tiles of our capital.
- The counter is 3+ target units with a bonus against the core's combat class within 8 tiles of its city.
- LateStrike's economy-ready is a placeholder until Personality's condition: the plan's K cities and the book done.
- Log: "Strike: OLD -> NEW (why; EarlyStrike|LateStrike)". expert_block.py lists each game's states, and an OVER without
  a capture is its exit.

LEAD: the strike state is coded on ai/war 56e0cadc, no turns in strike decisions. Economy: 0034 against GetStrikeState
(drop the T75/T90 and IsLateStrikeSaving turns). Personality: the economy-ready condition (a function War calls in place
of the K-cities placeholder in CvMilitaryAI::UpdateStrikeState). CI to follow.
**CI (11:15pm ET): green on ai/war 56e0cadc** (run 290): MSVC and clang debug and release builds, plus the A/B DLL
publish. ai/war is waiting for Economy's 0034 and Personality's economy-ready condition before "ready for the next block".

LEAD: 56e0cadc is green. The strike state waits for Economy's 0034 and Personality's economy-ready condition, then "ready
for the next block".

**All three halves on ai/war (11:17pm ET): 74ae9fd9** = 56e0cadc + Economy 0034 (ee626bfa, applied cleanly) + ai/personality
327a15b6 (1ed03174; LateStrikePlans dropped, the late rows are under LateStrike) + the wiring:
- **PREP to BUILDUP:** Personality's IsStrikeEconomyReady. EarlyStrike also keeps War's test: the target in reach,
  unwalled or the plan has siege, and the core trainable.
- **Army ready:** Personality's IsStrikeArmyReady counts as built, alongside the normal army. War's checks stay: the
  upgrade bill paid, and 3 melee.
- **Plan exits in BUILDUP:**
  - the city's defence at or above iExitCityStrength;
  - 2+ of the plan's counter classes within 8 tiles of the target;
  - a hill city under bExitRoughTarget.

LEAD: ai/war 74ae9fd9 has all three halves (War, Economy 0034, Personality's readiness), with no turns. CI is running.
"Ready for the next block" follows when it's green.

**CI (11:40pm ET): green on ai/war 74ae9fd9** (run 293: MSVC and clang, debug and release, A/B DLL published). The
Economy 0034 commit alone (ee626bfa, run 292) is green too.

LEAD: ready for the next block: ai/war 74ae9fd9 green (all three halves). ai/next b2a6f75 is the same minus 74ae9fd9, so
cherry-pick it there or build the next block from ai/war.

**URGENT (10:55pm ET): PC 1 has not run the EarlyStrike DLL at all; its installs since 8:42pm didn't take.**

This is not a code bug. Evidence:
- **The Build column.** bullyabort16 (said to be on ab-c337c77) and bullyabort17 (ab-db638c3, 480 rows) both read
  `No-Tag 8fe8e0f Clean`, and so does humangame106F8550. 8fe8e0f is the human-game build: none of the EarlyStrike
  commits are in it (`git log 8fe8e0f..40203a3c` is 36 commits).
- **The flags.** The runner passed EarlyStrike and EarlyStrikeAggressor in RoleFixes (Run-Games.log), but the CSV
  Fixes column has 43 flags and neither of those. An old DLL drops flag names it doesn't know.
- **The releases are right.** I downloaded both and read their strings:
  - ab-db638c3: `No-Tag db638c3 Clean`, the EarlyStrike/EarlyStrikeAggressor names and the "build-up opens" line,
    sha256 9be76e48...
  - ab-40203a3: `No-Tag 40203a3 Clean`, the same lines, sha256 3dbd9cd0...
- **The downloads ran.** Each release shows download_count 1. The DLL was downloaded, but the copy the game loads is
  still 8fe8e0f.
- **PC 2's installs do take.** bullygreedy16 shows abc78a6, then 5b7333c.
- **Game 1 (129103E3) had no EarlyStrike civ anyway.** Its civs were France, Iroquois, Morocco, Carthage, Austria,
  Korea, Russia and America, so Carthage was a correct aggressor with or without the picker.
- **Game 2's Aztec ran the old book.** Its opening was Scout, Jaguar, Settler, Worker, Monument, Settler, Shrine, with
  WarBudget lines and no EarlyStrike line. That is 8fe8e0f's behaviour.

So bullyabort16 and 17 are not EarlyStrike data: drop them from the expert block. bullyabort18 ("installed
ab-40203a3 at 10:28pm") is likely the same until its first row shows `No-Tag 40203a3 Clean`.

What PC 1 should check, with Civ closed:
1. Find every `CvGameCore_Expansion2.dll` under the Civ install (`Assets\DLC\*`) and `My Games\...\MODS`.
   Check each one's version string, e.g.
   `Select-String -Path <dll> -Pattern 'No-Tag [0-9a-f]{7}' -Encoding ascii`. A second pack folder or a MODS copy
   holding 8fe8e0f is the likely winner.
2. Check that `Assets\DLC\<test pack>\Mods\(1) Community Patch\CvGameCore_Expansion2.dll` has the release's
   sha256 (`Get-FileHash`). If not, the builder's Remove/Copy failed: was a Civ process still alive, or did the
   build throw?
3. Re-run `Run-ABTest.ps1 -Release ab-40203a3 -NoLaunch` (or a later build) and read its output to the end.
4. Before counting a game, check that the first CSV row's Build matches the release and that Fixes contains
   EarlyStrike.

LEAD: URGENT. PC 1's bullyabort16 and 17 ran DLL 8fe8e0f (CSV Build `No-Tag 8fe8e0f Clean`; EarlyStrike and
EarlyStrikeAggressor missing from Fixes). The install didn't replace the loaded DLL. The release DLLs are correct (I
checked their strings), so no code fix is needed. Drop those games, have PC 1 find the stale DLL (steps above), and
check bullyabort18's Build column before it counts. PC 2's bullygreedy18 check follows when its first pair lands.

**Answers to the lead's 10:54pm questions:**

(1) BarbKill has 0 lines in 138A0F7F at about T110.
- The line is not gated by any flag or by the strike path. Its only conditions are a barbarian loser, a major-civ
  winner and AI logging on.
- It runs in ApplyPostKillTraitEffects, which every kill path calls: melee, ranged, air, air sweep and extra damage.
- The ab-40203a3 release DLL contains the string ("BarbKill: %s killed a barbarian ...").
- It writes to **PlayerTacticalAILog.csv**, like BarbHunt, not to MilitaryAILog.csv. That log is opened with
  kDontFlushOnWrite, so a live file lags.
- No saved game has run a build with BarbKill yet:
  - PC 1 ran 8fe8e0f (see above).
  - PC 2's honest package ran 5b7333c, which predates 728495a5.
  - So the 0 BarbKill in every saved PlayerTacticalAILog.csv so far is expected.
- 138A0F7F is the first test. Grep its saved PlayerTacticalAILog.csv once the logs are pushed. If it is still 0 while
  barbarians died to majors, it's broken and I'll fix it.

(2) The Aztec in 12A96A78. That game ran 8fe8e0f, not db638c3 (the URGENT note above), so it had no strike plan,
bMilitaryFirst or EarlyStrike code. The T51 declaration came from the older TimingBuildup and WarBudget path, which the
WarBudget lines at the declaration show. Its StrategyProfile_Log can't print the spike fields because that build doesn't
have them.

LEAD: (1) BarbKill is ungated and is in the 40203a3 DLL. It writes to PlayerTacticalAILog.csv, not MilitaryAILog. No
saved game has run it yet. Check 138A0F7F's saved PlayerTacticalAILog.csv; 0 there means broken. (2) The Aztec game ran
8fe8e0f, so no strike plan existed; it isn't EarlyStrike data.

**URGENT closed (11:31pm ET).**
- **PC 1:** the cause is confirmed. The installer was killed by a pipe; PC 1 reinstalled at 10:54pm, and Run-ABTest now
  checks the installed DLL byte for byte (6e19c51). The restarted bullyabort18 hasn't pushed rows yet.
- **PC 2's pair 138A0F7F is clean.** Build `No-Tag 40203a3 Clean` in all 240 rows, China's Fixes include EarlyStrike
  and EarlyStrikeAggressor, and BarbKill has 44 lines in the saved PlayerTacticalAILog.csv (40 in the flip). No code
  fix is needed.

LEAD: URGENT closed. PC 2's 40203a3 games are correct (build, flags, BarbKill 44). PC 1 has reinstalled; I'll check its
first bullyabort18 rows for build 40203a3 when they land.
The user (via the lead): "because the ai is not a high level player, some of the windows will be hard to hit". The plans'
turns are Deity players' turns, and our AI is slower.

**(1) The read, now (tools/ab/expert_block.py, readiness section).** Per game, the turn each condition was met:
- the strike's upgrade tech in (the upgrade unit first buildable);
- the army built (land minus siege at the plan's core + support, from the window army line);
- the upgrade gold saved (gold at the bill, from the "upgrade and go" line);
- the first upgrade done;
- the declaration.

These are set against the plan's open, declare-by and fallback turns (Personality's "strike plan" line), with a count of
conditions met after the declare-by turn and of declarations before the army was built.

On the package block (no plan lines, the RoleFixes build) the shape is already visible: the first strike-relevant upgrade
came at a median of about T93 and the declaration at about T75 (Quick). The war came before the upgrades every time.

**(2) The design: declare on readiness; the plan's turns become soft limits.**
- **Ready** (the trigger) is all of:
  - the plan's upgrade tech known (or none);
  - core and support built to the plan's counts;
  - 3 melee that can take a city;
  - the upgrade bill paid: upgrades done, so gold is no longer short;
  - siege per the plan (only against walls when bSiegeOnlyIfWalled).
  When ready, the build-up ends and the attack phase declares on the committed target. This is today's ready test plus
  the plan's counts, with the clocks below removed.
- **Soft limits, relative to the AI's pace:**
  - Opens: when the core (or the plan's pre-build) can be trained and the book or economy phase is done. The plan's open
    turn is only the earliest.
  - Grace: if not ready N turns after the upgrade tech lands (N = 10 Standard; 15 when there's no upgrade tech, counted
    from the window's opening), declare with what's there if the field army is at least the normal target (cities + 4).
    Otherwise end the strike and fall back to the late plan.
  - The plan's declare-by and fallback turns become logging references, plus one far stop: the plan's fallback turn +
    30 Standard, past which the strike plan is dropped whatever the pace.
- **Hard stops** (end the strike, fall back):
  - the target's nearest city walls up while the plan has no siege (bSiegeOnlyIfWalled);
  - the core unit goes obsolete (its obsoleting tech known by us);
  - the target's army outgrows ours (the build-up's CanWin sketch fails twice in a row);
  - we are attacked by a major (defend first).
- **What the plan should carry (Personality), conditions not just turns:**
  - eUpgradeTech;
  - core, support and siege counts (there now);
  - iGraceTurns (N);
  - bHardStopOnWalls (the bSiegeOnlyIfWalled plans);
  - an optional iMinFieldArmy for the grace rule.
  The turns stay, as references.
- **Code (War, behind EarlyStrike and LateStrike, for the next block):**
  - CvMilitaryAI::IsInTimingBuildupWindow loses the window length, WindowUntilReady's 2 windows and the declare-by cut
    for a strike's build-up. It ends on ready, grace, or a hard stop.
  - IsTimingBuildupArmyReady adds the plan's counts.
  - A strike-state log line each turn of the build-up: "Strike: waiting on tech / army n of m / gold g of b / melee k".

LEAD: (1) the expert block's read now has readiness per game against the plan's turns. (2) Design above (strike on
readiness, the plan's turns soft, grace after the upgrade tech, hard stops). Say go and I'll code it on ai/war for the
next block. Personality: the plan would carry iGraceTurns, bHardStopOnWalls and optionally iMinFieldArmy.

### War: LateStrike, the late-spike civs' timed strike (coded, ai/war 656a7ba9, off, not merged) (Nov 5, about 10:40pm ET)
The lead (10:30pm ET, overnight): code the late-strike plans for the Zulu, Mongolia, Assyria, Japan and Songhai so the
next block is ready by morning. The user: "every civ builds to its strengths". Personality: late-spike civs get
"infrastructure first, then a timed strike with the unique unit".

**Hypothesis.**
- These civs were most of our bully aggressors (Mongols 17, Songhai 15, Assyria 12, Japan 11, Zulu 7 of 147). They
  declare a median of 29 turns after the unique unit is buildable, often without it in the army.
- Timing the build-up to the plan's window (the spike's tech known), building the unique unit as the army's core, saving
  for its upgrade, and declaring by the plan's turn should take more cities than a war at T27 Quick with whatever the
  army is.

**What it does (FIX_LATE_STRIKE).** It reads Personality's CvStrikePlan; for these civs that's the data default:
- open 5 turns after the later of the spike's tech and its upgrade tech;
- declare within 10 turns;
- fallback 5 turns after that;
- core = the unique unit, 5; support = archers behind a melee core, spearmen in front of a ranged one, 3; a siege
  unique unit is the siege (2) with archers as the core.

| Step | Code |
|---|---|
| Infrastructure first | no build-up before the plan's window. TimingBuildup's peace phase (garrisons only) holds until the plan's open turn with the core unit trainable, or its fallback turn |
| The army | field target at least core + support; core to its count (+4500), then support (+3500); the plan's siege always, 2 against a walled target; 3 melee for the capture |
| Upgrade and go | the bill includes units waiting for the plan's upgrade tech; saved, purchases wait, the declaration waits (no hold before the window) |
| Declare by | the window ends at the plan's declare-by turn |
| Log | "LateStrike: build-up opens (plan open T, declare by T, fallback T), core X xN, support Y xN, siege xN, target walled/unwalled" |

**Confirm and kill** (per civ, against the same civs on the RoleFixes builds):
- Confirm: captures up for these civs, the declaration within the plan's window, the unique unit at least a third of
  the army at the declaration.
- Kill: captures down, or the delay costs them (cities lost before the window, or score behind at T100 with nothing
  taken).
- Risk: before the window the peace phase keeps only garrisons. A civ attacked early has CP's defence only.

LEAD: LateStrike (ai/war 656a7ba9, off) is ready for the block after the expert block; not to merge into the frozen
block. CI to follow.

**On Economy's book half (ai/war da912386).** Economy's patch 0033 (the late-strike book) defines the same flag; it is
applied as 6db12aa6.
- Economy's half: economy first; from 30 turns (Standard) before the window, the spike's tech then the upgrade tech; no
  hurries or tiles from 15 turns before the window to the declaration.
- War's half now keys on Economy's CvPlayer::IsLateStrikeCiv, and holds every AI upgrade while Economy saves
  (IsLateStrikeSaving) until the late strike's army is built. Then it upgrades and declares.

LEAD: LateStrike's two halves are on ai/war da912386 (carries Economy 0033), off, for the block after the expert block.

**One flag, one source (the lead, 10:33pm ET; ai/war 340592fa).** ai/personality (a80986e, 5ad0a45) is merged into ai/war:
the late-strike rows (Zulu, Mongolia, Assyria, Japan, Songhai, and China's Chu-Ko-Nu rush) in CvStrikePlan, under
LateStrikePlans for now.
- War's half now reads the plan:
  - only plans with bLateStrike;
  - at the plan's open turn the window opens once the core, or the plan's pre-build class, can be trained;
  - the pre-build first, to its count, while the core can't be trained;
  - the upgrade into the core at the plan's upgrade tech holds the declaration.
- To finish the one-flag setup:
  - Personality switches LateStrikePlans' gate to FIX_LATE_STRIKE once it's on claude/ab-c1;
  - Economy's CvPlayer::IsLateStrikeCiv reads bLateStrike too.

LEAD: ai/war 340592fa carries LateStrike's three halves (War, Economy 0033, Personality 5ad0a45) for the block after the
expert block. Personality: gate LateStrikePlans on FIX_LATE_STRIKE. Economy: read bLateStrike in IsLateStrikeCiv.

### War: expert block, running per-civ table (ab-40203a3; updated hourly overnight)

**Read 1 (11:30pm ET): 1 logged first game.** PC 2 pair 1 (138A0F7F). PC 1's restarted bullyabort18 hasn't pushed yet.
- **Build check.** All 240 bullygreedy18 rows read `No-Tag 40203a3 Clean`. China's Fixes include EarlyStrike and
  EarlyStrikeAggressor.
- **BarbKill works.** 44 lines in the first game and 40 in the flip, spread across all majors (Sweden 11, Denmark 7,
  China 5, ...).

| civ | games | captured | cities | 1st capture T | decl T | BarbKills | promoted / land at decl | exits |
|---|---|---|---|---|---|---|---|---|
| China | 1 | 1 | 1 | 59 | 57 | 5 | 1 / 11 | captured 1 |

What happened in the game:
- **China isn't an EarlyStrike civ.** No early-spike civ was in the lineup. China's plan is a late strike (open T109,
  declare-by T116), and LateStrike isn't in 40203a3. So the T57 war on Rome came from the normal TimingBuildup path, not
  a strike: 0 EarlyStrike build-ups, 0 upgrade-and-go.
- **Melee in reach at the first capture attempts.** 2 attempts with 0 melee in reach both failed. 1 attempt with 2+
  melee took the city. That matches the pattern so far (2+: 5/24 vs 0: 1/15).
- **Readiness against the plan (China's late plan, for reference).** The upgrade tech came in at T87 and the upgrades
  were done at T86-87. The gold target was never met. The army was built by T47.
- **Barbarian hunting.** No BarbHunt lines, since that runs for EarlyStrike civs only. China killed 5 barbarians anyway;
  the highest XP from a kill was 14 (cap 45).

LEAD: reading only, 11:30pm ET.

**Read 2 (12:35am ET): 3 logged first games**, all from PC 2. PC 1's restarted bullyabort18 hasn't pushed yet.

| civ | games | captured | cities | 1st capture T | decl T | BarbKills | promoted / land at decl | exits |
|---|---|---|---|---|---|---|---|---|
| China | 1 | 1 | 1 | 59 | 57 | 5 | 1 / 11 | captured 1 |
| Persia | 1 | 0 | 0 | - | 119 | 10 | 10 / 16 | no capture |
| Polynesia | 1 | 0 | 0 | - | 140 | 1 | - | no capture |

1 of 3 captured. The first two games with an early-spike aggressor opened no EarlyStrike build-up. Both failures are mine:
- **Polynesia (13CA9885): the EarlyStrikeAggressor picker chose a civ that isn't a warmonger.**
  - Polynesia's profile has bMilitaryFirst, but the test's own warmonger test (IsABTestWarmongerCiv) says no: the CSV
    Warmonger column is 0, and its grand strategy went Culture, then UN.
  - IsCandidateWarmonger was therefore false. It played no TimingBuildup, no EarlyStrike book (the old opening:
    Scout, Maori Warrior, Settler, Worker) and no war until T140.
  - The picker ranked "early spike" above "warmonger", so a non-warmonger early-spike civ could take the role. Any game
    like that is a wasted bully game.
- **Persia (13A89116): no major in reach, and the peace cap shed the army.**
  - Its nearest target was the city-state Jerusalem; no major was committed until America at T81 and the Maya at T107.
  - From T57 to T77, TimingBuildup's peace cap (3 + 2) let an Archer, 2 Warriors and a Composite Bowman go.
  - The window opened at T81 against America (10 turns, army not ready, 1 siege). It declared at T119 and took nothing.
  - On 40203a3 the EarlyStrike window is turn-limited, so it couldn't open that late anyway. On ai/war the strike state
    would hold PREP until the army is built with no target in reach (OVER). But the peace cap still sheds units in PREP
    and BUILDUP, so the army is never built.
  - BarbHunt ran (2 lines; 10 BarbKills, the most in the block so far).

**Hypotheses (War, before code; for the next block, on ai/war, not the frozen block):**
1. **EarlyStrikeAggressor picks an early-spike civ only among warmongers.** The score becomes early spike AND warmonger
   first, then warmonger. Fixes the harness so the aggressor always plays the conquest plan. Expect 0 aggressors with
   Warmonger 0 when the game has a warmonger.
2. **The peace cap doesn't shed a strike civ's land units in PREP or BUILDUP.** Under EarlyStrike/LateStrike via the
   strike state; no new flag, since it is the strike army itself. Expect "TimingBuildup: peace ... letting X go" lines
   to stop for strike civs before the declaration, and more land units at the BUILDUP line.

LEAD (12:35am): reading only. 1 of 3 games captured (China T59). Persia and Polynesia, both early-spike aggressors,
opened no EarlyStrike build-up. **The harness wastes games:** EarlyStrikeAggressor can pick a non-warmonger early-spike
civ (Polynesia: Warmonger 0, no conquest plan at all). For the rest of tonight's block, consider dropping
EarlyStrikeAggressor from RoleFixes, or count those games as void. The fix (warmongers only) and the peace-cap fix for
strike civs go on ai/war for the next block.

**Coded: ai/war e10e2f34. CI green (run 295, 12:42am ET).**

LEAD: e10e2f34 green; cherry-pick 74ae9fd9 and e10e2f34 onto ai/next.

**Read 3 (1:35am ET): 4 logged first games**, all PC 2. PC 1's bullyabort18 hasn't pushed yet.

| civ | games | captured | cities | 1st capture T | decl T | BarbKills | promoted / land at decl | exits |
|---|---|---|---|---|---|---|---|---|
| China | 1 | 1 | 1 | 59 | 57 | 5 | 1 / 11 | captured 1 |
| Persia | 2 | 1 | 1 | 87 | 119, 81 | 10, 1 | 10 / 16, 12 / 16 | no capture 1, captured 1 |
| Polynesia | 1 | 0 | 0 | - | 140 | 1 | - | no capture (non-warmonger aggressor, fixed in e10e2f34) |

2 of 4 captured. Melee in reach at the first capture attempts: 2+ melee took 2 of 4; 0 melee took 0 of 2.

**The first EarlyStrike build-up: Persia, 13E9ECC9.** It missed its window, and the capture came from the ordinary second
window.
- **Opening and window.** The book opened Worker, Settler (held to size 1 until T12), then Immortal x3 from T28 and an
  Archer at T37. The build-up opened at T40 against Morocco ("unwalled, no siege"), with **3 land units** against a
  target of 12 others.
- **Army.** Production added about 1 unit every 2 turns: 7 land by T50, when the strike window closed (40203a3 is
  turn-limited).
- **Gold.** It went from 210 to 350, unspent. The upgrade bill (Archers to Composite Bowmen at Construction) was 55 to
  165, "upgrade tech a few turns off", from T41 to T50. Construction came at T56.
- **Purchases.** None. The window buys only on a turn with no upgrade bill, so a bill for a tech still being researched
  blocks every purchase. WarChest was also on in RoleFixes, so Economy owned the gold, and 0034 would forbid EarlyStrike
  purchases in PREP and BUILDUP outright.
- **What came after.** The "no war 3 windows" reset at T71, a normal window at T72, and war at T81 (2 paused turns).
  Morocco's city was captured at T87 with 12 of 16 land units promoted.

On ai/war (no turn limits) the build-up would have waited for Construction (T56) and the 12-unit army, and declared
then. The idle gold is still idle there, and that is the lever: 185 gold over the bill bought nothing while the army
was 5 units short.

**Hypothesis 3 (War, with Economy; before code):** in a strike's build-up, keep the upgrade bill in reserve and buy with
the gold above it: one core or melee unit a turn, nearest the target, while gold minus bill covers the price. This
replaces "no purchase while any bill". Expect 13E9ECC9-like games to field the army by about T45 instead of T56+, with
gold near the bill at the declaration (the user's 263 at T40 to 31 at T50). War codes its own purchase path (used when
WarChest is off) on ai/war.

LEAD (1:35am): reading only. 2 of 4 captured. The first EarlyStrike build-up (Persia) opened at T40 with 3 units and
missed its window: 7 of 12 land by T50, and 350 gold unspent against a bill of 165. Economy: 0034's "EarlyStrike buys
nothing in PREP and BUILDUP" (and WarChest's buys) should become "buy core or melee with the gold above War's upgrade
bill" in BUILDUP (CvMilitaryAI::GetEarlyStrikeUpgradeBill). War does the same in its own path on ai/war.

**Coded: ai/war bb2fa51c. CI green (run 297, 1:39am ET).**

LEAD: bb2fa51c green; cherry-pick 74ae9fd9, e10e2f34 and bb2fa51c onto ai/next.

**Read 4 (2:28am ET): 6 logged first games**, all PC 2. PC 1's bullyabort18 still hasn't pushed.

| civ | games | captured | cities | 1st capture T | decl T | BarbKills | promoted / land at decl | exits |
|---|---|---|---|---|---|---|---|---|
| China | 1 | 1 | 1 | 59 | 57 | 5 | 1 / 11 | captured 1 |
| Persia | 2 | 1 | 1 | 87 | 119, 81 | 10, 1 | 10 / 16, 12 / 16 | no capture 1, captured 1 |
| Polynesia | 1 | 0 | 0 | - | 140 | 1 | - | no capture (Warmonger 0) |
| Maya | 1 | 0 | 0 | - | never | 1 | - | no strike (Warmonger 0) |
| Celts | 1 | 0 | 0 | - | never | 11 | - | no strike (Warmonger 0) |

2 of 6 captured. **3 of the 6 games are the picker bug** (fixed on ai/war e10e2f34):
- Maya (1408BFF3) and Celts (14283015) were picked as aggressors for bMilitaryFirst, but both read Warmonger 0.
- Neither got the conquest plan: no TimingBuildup line, no war in 150 turns. Each ran the old economic book (Maya:
  Scout, Monument, Pyramid, Warrior, Settler; Celts: Scout, Monument, Shrine, Warrior, Worker).
- With Polynesia that makes half the block's bully games with an aggressor that never plays aggressor. They measure
  nothing about the strike.

LEAD (2:28am): reading only. 2 of 6 captured, and 3 of the 6 are void: Polynesia, Maya and Celts were picked as aggressors
by EarlyStrikeAggressor but aren't warmongers (Warmonger 0), so they had no conquest plan. Recommend PC 2 drops
EarlyStrikeAggressor from RoleFixes for the rest of the night. The default picker (the most offensive warmonger) still
gives EarlyStrike to an early-spike warmonger when it's the top one. Otherwise count Warmonger-0 aggressor games as void.
The fix (e10e2f34) is green on ai/war for the next block.

**Greece, pair 8 (1464B588), from Economy's 3:25am note (3:26am ET): upgrades held past the declaration, and 500 gold
gifted to a city-state mid-build-up.**
- **Build-up.** EarlyStrike's build-up opened at T36 against Songhai (unwalled), with **2 land units** (Hoplite,
  Warrior). It had 4 by T50 (an Archer at T49).
- **Gold.** It rose from 309 to 494, then **Greece gave 500 gold to Jerusalem at T46** (the Diplomacy log: "Gold Gift:
  500"; Monaco was being saved for too). The strike's gold went to a city-state.
- **Upgrades.** Construction came at T52, when the strike window (turn-limited on 40203a3) had already passed.
  - 40203a3's hold (IsEarlyStrikeHoldingUpgrades) lifts only inside a live strike build-up. After T50 it held every
    upgrade until the war at T63 (IsEarlyStrikeSmallEmpire ends at war), with 289 gold in the treasury.
  - At war the Archers were in the field and couldn't upgrade; the first upgrade came at T99.
  - Declared at T63 with 7 land, 0 promotions. First attempt on Gao at T74, no capture.

On ai/war the hold has no turn limit, but it lifts only when the normal army is built. The declaration can also come from
Personality's plan army (IsStrikeArmyReady) or "as ready as it gets", and then the units march unupgraded while the hold
still blocks them.

**Hypothesis 4 (War, before code):** the hold lifts as soon as the army is ready by any measure the declaration uses: the
normal army, Personality's plan army, or as ready as it gets. Then the upgrades happen at home before the units muster.
Expect the first upgrade at or before the declaration in every strike that has gold and an upgradable unit.

**Proposal for Economy:** no city-state gold gifts for a strike civ in PREP or BUILDUP. The gold is the upgrade bill and
the army.

LEAD (3:26am): reading only. Greece (1464B588): its upgrades were held past the declaration, and it gave 500 gold to Jerusalem
at T46 during its strike build-up. War's fix: the upgrade hold lifts whenever the army is ready by any measure (coded on
ai/war). Economy: block city-state gold gifts for a strike civ in PREP or BUILDUP.

**Coded: ai/war e8655858, CI green (run 298).** Economy's 0035 and 0036 are applied on top (cf9d2a91, 9d40bb28); the
head is green (run 299, 3:46am ET).

LEAD: ai/war 9d40bb28 green. To bring ai/next up to date, cherry-pick 74ae9fd9 (Personality's readiness wired),
e10e2f34 (aggressor picker and peace cap), bb2fa51c (strike purchases; WarmongerHurry limits them to siege), e8655858
(upgrade hold) and Economy's 0035 and 0036 (cf9d2a91, 9d40bb28). Or build the next block from ai/war, which is ai/next
plus exactly these.

**Read 6, block complete (4:29am ET): 10 first games** (PC 2's bullygreedy18; PC 1's bullyabort18 never pushed).

| civ | games | captured | cities | 1st capture T | decl T | BarbKills | promoted / land at decl | exits |
|---|---|---|---|---|---|---|---|---|
| China | 1 | 1 | 1 | 59 | 57 | 5 | 1 / 11 | captured (normal TimingBuildup; China's plan is a late strike) |
| Persia | 3 | 1 | 1 | 87 | 119, 81, 83 | 10, 1, 0 | 10/16, 12/16, 1/16 | captured 1 (second window), no capture 2 |
| Greece | 1 | 0 | 0 | - | 63 | 1 | 0 / 7 | no capture |
| Aztec | 1 | 0 | 0 | - | 108 | 4 | 1 / 9 | no capture |
| Polynesia, Maya, Celts, Inca | 4 | 0 | 0 | - | 140, never x3 | 1, 1, 11, 2 | - | void (Warmonger 0) |

**Verdict on 40203a3's EarlyStrike: 0 captures from a strike.** 2 of 10 games captured, both by the ordinary path.
4 of 10 are void (the picker bug, fixed in e10e2f34). The other 6 failed in four ways, each one now addressed on
ai/war:

| failure | games | on ai/war |
|---|---|---|
| The build-up opened with 1-3 land units, and production couldn't fill 10-12 by the turn-limited close | Persia 13E9ECC9 (3 at T40, 7 by T50), Persia 14A46460 (**1 at T26**, 1 at T36), Greece (2 at T36, 4 at T50) | no turn limits (56e0cadc); BUILDUP only on Personality's economy-ready (N core out, K cities; 74ae9fd9) |
| The only neighbour in reach was a city-state, so no major was committed for 60+ turns, and the peace cap shed the book's units | Persia 13A89116 (Jerusalem; shed 4), Aztec 14849045 (Lhasa; 4 Jaguars by T17, shed from T42) | peace cap off in PREP and BUILDUP (e10e2f34); the target question is open (below) |
| Gold idle or gone: 350 unspent against a 165 bill (Persia); 500 gifted to a city-state (Greece) | 2 | purchases above the bill (bb2fa51c; WarmongerHurry limits them to siege); no city-state gifts (Economy 0036) |
| Upgrades held past the declaration (Greece: 289 gold, first upgrade at T99) | 1 | the hold lifts on any readiness (e8655858) |

Also:
- **Barbarian hunt.** BarbHunt sent one Jaguar after the same Brute 7 tiles out for 15 turns (Aztec, T18-T33), and 4
  kills came of it. A lone unit at distance doesn't finish a barbarian. Next: send 2, or only within 5 tiles.
- **Melee in reach at the first capture attempts.** 2+ melee took 2 of 4; 0 melee took 0 of 3. That's consistent with
  every block so far.

**Hypothesis 5 (War, for discussion, not coded):** when an early-strike civ has no major in reach but a city-state is
(Persia: Jerusalem; Aztec: Lhasa), the strike's target is the city-state. CSConquest is already in the bundle; the
strike state would accept a city-state's nearest city as "in reach". Experts take a neighbouring city-state early with
the spike unit. Risk: the city-state's allies, and the warmonger penalty.

LEAD (4:29am): reading only. The expert block is complete: 2 of 10 captured, both by the ordinary path; 0 captures from an
EarlyStrike build-up; 4 of 10 void (non-warmonger aggressors). The six real failures were tiny armies at the open, a
city-state as the only neighbour with the peace cap shedding units, idle or gifted gold, and upgrades held. All four are
addressed on ai/war 9d40bb28 (green). Open questions for the user: (1) strike purchases of core and melee despite
WarmongerHurry; (2) hypothesis 5, a city-state as the early strike's target when no major is in reach.

**BarbHunt coded: ai/war f9c16cd9.** A lone hunter goes only within 5 tiles; farther out it takes two. CI green (run 301,
4:40am ET).

LEAD: f9c16cd9 green; add it to the ai/next list. ai/war = ai/next + 74ae9fd9, e10e2f34, bb2fa51c, e8655858, Economy
0035/0036 (cf9d2a91, 9d40bb28), f9c16cd9.

**The user's rulings (via the lead, morning of Nov 6), and War's plan (6:08am ET):**
1. **Strike purchases: no.**
   - Checked: bb2fa51c's purchase path (in ab-8f9b7f9) goes through CvCity::IsCanPurchase, and PurchaseUnit re-checks
     it. IsCanPurchase calls CvEconomicAI::IsGoldPurchaseAllowed, so under WarmongerHurry a warmonger can buy only
     settlers and siege, and under NoObsoleteHurry no Warrior class. Every EarlyStrike/LateStrike civ is a candidate
     warmonger, so it can't buy core or melee units today.
   - To keep it so even if WarmongerHurry were off for a civ, the strike path now tries siege only (up to the plan's
     siege target) and never asks for a core or melee unit.
2. **City-state targets: yes, under EarlyStrike.**
   - **Hypothesis 5, coded:** when no major's city is in reach (12 tiles of our capital), the early strike targets the
     nearest city-state whose city is. Conditions:
     - war can be declared;
     - its ally is nobody, or a major we're at war with;
     - no major at peace with us protects it;
     - no recent peace with it;
     - not a walled hill city.
   - **Log:** "Strike: city-state target <name> (<city>, N tiles from our capital; no major in reach)".
   - **Wiring:**
     - The strike state treats that city as the target: the reach, walls, counter and plan exits all apply.
     - GetNewAIConquestTarget opens the build-up window against the city-state.
     - Once the army is ready (or as ready as it gets), the approach to that city-state is WAR, so the normal city-state
       war machinery declares.
     - The strike counts the city-state war as its WAR, and peace or the city-state's end as its end.
   - **Expected:** Persia 13A89116 (Jerusalem) and Aztec 14849045 (Lhasa) would strike at the city-state around T40-60
     instead of idling to T100+.

LEAD (6:08am): (1) checked: bb2fa51c can't buy core or melee for a warmonger (IsCanPurchase applies WarmongerHurry), and
the path is now siege-only regardless. (2) The city-state strike target is being coded under EarlyStrike on ai/war; LEAD
line when CI is green.

**Coded: ai/war 1b29b33d, CI green (run 302, 6:22am ET):** the city-state strike target (EarlyStrike) and siege-only
strike purchases. The head with everything since (21b91a3e) is building.

LEAD: 1b29b33d green: the city-state strike target (EarlyStrike) and siege-only strike purchases. "Ready for the next
block" follows when the ai/war head 21b91a3e is green.

**The next build (6:37am ET):** ai/war 99b5a0f5 = ai/war 21b91a3e (Economy 0039, 0040) + ai/personality da1a760 (the
expert lists), merged clean as the lead asked.

Economy's 0041 (StrikeList) doesn't apply on it. It conflicts in CvStrikePlan: Personality's da1a760 already defines
the lists, in a different shape:

| | Personality (da1a760) | Economy (0041) |
|---|---|---|
| builds | aBuilds[16]: CvStrikeBuildItem, one item per unit | aBuild[32]: CvStrikeListItem with counts |
| research | aeTechs[16], with STRIKE_TECH_LUXURY | aTech[16] |
| policies | none (eFirstPolicyBranch stays) | aPolicy[8] |
| filled by | Personality's rows | AddBuild / AddTech / AddPolicy |

The count meaning and the luxury tech belong to those two sessions, so I didn't write an adapter. Asked Economy (6:45am)
to rebase 0041 onto 99b5a0f5, reading Personality's lists (or to settle one shape with Personality). War applies it as
soon as it's rebased.

LEAD (6:37am): ai/personality da1a760 is merged into ai/war (99b5a0f5, which has 0039 and 0040 as well). Economy's 0041
conflicts with Personality's list shape in CvStrikePlan; Economy is asked to rebase it on 99b5a0f5. "Ready for the next
block" follows once 0041 is in and CI is green. Relayed from Economy (its messages to you fail): 0041 is ready for
Personality's lists, and the PCs stay stopped until a build has 0039 and 0040 (99b5a0f5 has both).

**Update (6:40am ET):** Economy redid 0041 on Personality's lists (pack af6591f). It applied cleanly. The next build is
**ai/war 2ffdafa1**: the war head + ai/personality da1a760 + Economy 0041 StrikeList. The flag table checks out (107
flags, 107 entries; StrikeList off in the bundle). CI is running.

LEAD: the next build is ai/war 2ffdafa1. Its run needs RoleFixes += StrikeList, which is off in the bundle. "Ready for
the next block" follows when CI is green.

**CI (6:53am ET): green on ai/war 2ffdafa1** (run 309: MSVC and clang, debug and release; the A/B DLL published).

LEAD: ready for the next block: ai/war 2ffdafa1 green. It has:
- the city-state target, the plan-army requests and the PREP-war exit (War);
- Economy 0037-0041;
- Personality's expert lists.

The run needs RoleFixes += StrikeList, which is off in the bundle. This replaces ab-8f9b7f9 as the PCs' build. Both PCs
are stopped, and 2ffdafa1 has 0039 and 0040.

**Read, ab-8f9b7f9's two games (7:30am ET; both PCs stopped after pair 1):**

| game | civ | strike states | BUILDUP army vs plan | WAR army vs plan | result |
|---|---|---|---|---|---|
| 1468D9F4 | Japan (late) | PREP T1, BUILDUP T149 | - | T102: 5 land, Longswordsman 0/7, Archer 1/4 (the war wasn't the strike's) | no capture (the STOP game) |
| 152231C3 | Aztec (early) | PREP T1, BUILDUP T44 (Memphis in reach), WAR T77, OVER T101 (army below half, nothing taken) | T45: 5 land, Warrior-line 4/6, Archer 1/4 | T77: 10 land, 7/6, 3/4 | no capture |

The strike state ran as designed for the Aztec, from target in reach to the plan's army at the declaration, but it failed
on **upgrade and go**:
- **Upgrades held.** From T50 the bill was 2 Archers for 110 gold, with about 300 gold in the treasury. The homeland
  logged "Need gold for Archer upgrade" every turn (that's what it logs when CanUpgradeRightNow is false: War's hold).
- **Why the hold stayed.** It waited for the full army: WarBudget's 12 on this build, and the plan army wasn't met
  either.
- **How the bill hit 0.** At T72 a sneak-attack operation mustered the units outside our territory. The bill counts home
  units only, so it fell to 0, readiness passed, and it declared at T77 with nothing upgraded. The first upgrade came at
  T125.

**Hypothesis 7, coded (ai/war, below):** in BUILDUP the hold keeps the gold only until the strike's own upgrade tech
(the plan's eUpgradeTech, else the window's) is known; then it lifts, and CP's homeland upgrades at home before the
muster. PREP is unchanged (EarlyStrike holds through the book). Expect "Upgrading unit" lines within a turn or two of the
upgrade tech, before the declaration.

LEAD (7:30am): reading only, plus a fix. ab-8f9b7f9's Aztec ran the full strike (BUILDUP T44, WAR T77 with 10 of the plan's
10) but never upgraded: War's hold waited for the full army, and the muster took the units out of our territory first.
The hold now lifts once the strike's upgrade tech is in (ai/war, CI to follow). It's on top of 2ffdafa1, so the next
build would take it.

**Coded: ai/war 8555f21b. CI green (run 311, 7:41am ET).**

LEAD: 8555f21b green: upgrade and go (the hold lifts at the strike's upgrade tech). Ready for the next block on 8555f21b
(2ffdafa1 + this); RoleFixes += StrikeList.

**The lead's STOP on ab-8555f21 (bullyabort20, 14BC6621; 8:16am ET):** LateStrike Germany's Munich built Heroic Epic and
the Temple of Artemis in PREP.
- **Economy's 0042** (no world or national wonder before a strike, on every pick path: the sanity check, the fallback,
  the specialization pick, the Great Engineer) is applied: ai/war c03f98b1.
- **Munich vetoed every unit at T61** ("badtimeorplace"), which sent it to the wonder fallback. One candidate is
  War's: TimingBuildup's peace cap (garrisons + 1) applied to a strike civ in PREP, and it would also veto Economy's 0038
  army.
  - **Fix, ai/war 0225d198:** for a strike civ in PREP or BUILDUP, the peace cap is at least the plan's army (core +
    support + the pre-build beyond the core).
  - The other candidates aren't War's: the new AI's young-city rule (under 2 buildings) and Personality's style caps.
- **For Personality: Germany's plan.** It's the data default: a late strike with core UNITCLASS_TANK x5, opening at T227.
  LateStrike keeps it in PREP for the whole 150-turn game (it went OVER only when a major declared on it at T115), under
  every PREP restriction. A plan whose core is that far off probably shouldn't count as a late strike (bLateStrike off,
  or no plan).

LEAD (8:16am): Economy's 0042 is on ai/war (c03f98b1), plus War's peace-cap fix for strike civs (0225d198); CI to follow,
then "ready" on that head. Personality: Germany's data-default late plan (Tanks at T227) holds it in PREP all game; such
plans shouldn't be late strikes.

**The next block (8:22am ET): ai/war f939c50c** = 8555f21b + Economy 0042 (c03f98b1) + War's strike peace cap
(0225d198) + ai/personality 184fe09, merged clean. 184fe09 runs every plan's list to the strike. The late data default
now pre-builds the class that upgrades into the core (Germany: Spearman to Landsknecht), which answers the Germany note
above. CI is running.

First EarlyStrike capture (the lead, PC 2 on 8555f21): Greece followed its list, declared at T50 with the plan's 8
units, and took a Dutch city at T59.

LEAD: the next block is ai/war f939c50c (Personality 184fe09 and Economy 0042 are in). "Ready for the next block"
follows when CI is green; RoleFixes += StrikeList.

**Read, the strike-state builds so far (8:28am ET; 4 first games: ab-8f9b7f9 pair 1 on each PC, ab-8555f21 pair 1 on each
PC):**

| game | build | civ | states | BUILDUP: land, core / support vs plan | WAR: land, core / support vs plan | capital + 2nd city to BUILDUP | result |
|---|---|---|---|---|---|---|---|
| 1468D9F4 | 8f9b7f9 | Japan (late) | PREP T1, BUILDUP T149 | - | T102: 5, 0/7, 1/4 (not the strike's war) | Building 8, Wonder 3, Military 5, Settler 5, Worker 7 | no capture (STOP: wonders, gifts) |
| 152231C3 | 8f9b7f9 | Aztec (early) | BUILDUP T44, WAR T77, OVER T101 (army below half) | T45: 5, 4/6, 1/4 | T77: 10, 7/6, 3/4 | Building 1, Military 5 | no capture (upgrades held, fixed in 8555f21b) |
| 14BC6621 | 8555f21 | Germany (late, Tank default) | PREP T1, OVER T115 (war on us) | - | - | Building 12, Military 7, Settler 6 | no war (STOP: wonders; fixed by 0042, 0225d198, 184fe09) |
| 157C6FE0 | 8555f21 | **Greece (early)** | BUILDUP T41 (Amsterdam in reach), WAR T50 (as ready as it got), OVER T123 (peace after a capture) | T42: 6, 3/3 Spearman, 3/5 Archer | T50: 8, 3/3, 4/5 | **Military 16, Building 1, Settler 1, Worker 1** | **captured T59** |

What Greece's capture shows:
- **The list builds the army on time.** Before BUILDUP, the capital and second city produced 16 military to 1 building.
- **The strike went the expert's way.** The army was within one unit of the plan at the declaration (T50, plan
  declare-by T43), the target was unwalled, and it captured 9 turns later.
- **Promotions.** 0 of 8 units at the declaration (it made 0 BarbKills before the window).

Japan and Germany are the two late-strike STOPs, both covered in the next block. Aztec's failure was the held upgrade,
fixed in 8555f21b.

LEAD (8:28am): reading only. On the strike-state builds, 1 of 4 first games captured: Greece on 8555f21, list-built
(16 military to 1 building before BUILDUP), declared at T50 with 7 of the plan's 8 (8 land units in all), captured at T59. The
other three each failed on something the next block (f939c50c) fixes.

**The user on Germany's T227 Tank plan (via Economy, 8:32am ET):** "you cant do a turn 227 timing attack. germany would
either need to use normal units for an attack earlier or not be aggressive at all." Economy has sent Personality the
plan change (pack 70ec5fc): for a spike past the game's reach, either the research's G1 Archer-to-Composite-Bowman
timing at Construction (T55-70 Standard), or no strike plan. War's state machine is unchanged by it.

LEAD: relayed from Economy, the user's ruling on Germany: no T227 Tank strike. Personality changes the plan (an early
normal-unit timing at Construction, or no plan). Nothing changes in War's code.

**The next block, updated (8:37am ET): ai/war 32e152c4** = f939c50c + ai/personality b8ac94f + Economy 0043:
- **b8ac94f (the user's late-spike ruling):** a spike out of reach is no spike, warmongers without one play the generic
  Composite Bowman rush (G1), and the lists hold no wonders.
- **0043:** the generic rush plays as an early strike. GetEarlyStrikeCoreClass returns its Archer core, so War's
  IsEarlyStrikeCiv and the strike state pick those civs up; without it they would stay NONE.

CI is running.

LEAD: the next block is now ai/war 32e152c4 (adds Personality b8ac94f and Economy 0043). "Ready for the next block"
follows when CI is green; RoleFixes += StrikeList. The PCs keep the STOP until then.

**The generic rush as an early striker (the lead's check, 8:39am ET).** A bGenericRush civ (no spike in reach) plays the
early strike:
- IsEarlyStrikeCiv keys off GetEarlyStrikeCoreClass, which 0043 makes the rush's Archer.
- The state machine, the army counts and the upgrade hold read the strike plan.
- **Fix, ai/war b2657046:** the upgrade bill took the strike's upgrade tech only from Personality's spike window, which
  a generic rush lacks. It now falls back to the plan's eUpgradeTech (Construction: Archers to Composite Bowmen).
- The core share defaults to 50% without a window.

LEAD: the generic rush is an early striker on ai/war b2657046 (32e152c4 + the bill's fallback to the plan's upgrade
tech). "Ready for the next block" follows on b2657046 when CI is green.

**The walled exit (the lead, 8:46am ET; ab-f939c50 bullyabort21, 14E7F3A0).** The Aztec followed their 12-item list,
opened BUILDUP at T43 against the city-state Ur, and went OVER at T60 ("target walled, no siege") with 5 land units, 3
promoted. They returned to normal play: a wonder at T90, a war at T93.

**Coded, ai/war dd375b2a.** In BUILDUP, a walled target with no siege in the plan now goes:
1. **Re-target** to the nearest other unwalled city within 12 tiles of our capital, a major's or a city-state's. A major
   must be one we can declare on with no defensive allies to pull in, or one we're already at war with. Logged
   "Strike: re-target from X (city walled) to Y (city, unwalled, N tiles...)".
   - The window's target moves with it.
   - A major becomes the committed conquest target, and the normal flow declares on it. A city-state takes the
     city-state path.
2. **Else bring siege,** if the plan allows siege against walls (bSiegeOnlyIfWalled): the siege target becomes the
   larger of 2 and the plan's. Logged.
3. **Else OVER.**

LEAD: the walled exit now re-targets, then switches to siege, then goes OVER (ai/war dd375b2a, after b2657046). "Ready
for the next block" follows on dd375b2a when CI is green.

**Walls are not an exit: a strength check instead (design, 8:49am ET).** The user: "i think i brute forced through
marrakeshs walls when i attacked." Their Aztec took a walled capital with 6 Jaguars and 4 Composite Bowmen, no siege. The
research: Composite Bowmen are fine up to about city strength 23-25 with 7 of them.

- **The measure** (CvMilitaryAI::IsStrikeArmyStrongEnough(city)):
  - The army is the strike plan's full army: the core and support classes at their counts, as the units they will be
    after the strike's own upgrade (upgrade and go).
  - Each unit's attack is its ranged strength if ranged, else its melee strength. A unit counts only if its attack is at
    least 40% of the city's defence (getStrengthValue, walls and garrison included).
  - The army can take the city when the counted units' total attack is at least 3x the city's defence, with at least 2
    melee units among them.
  - Calibration: 7 Composite Bowmen (11 ranged) give 77 = 3.1x a city of 25. The user's 6 Jaguars + 4 Composite Bowmen
    give about 92 against a T54 capital in the high teens.
- **In BUILDUP, every turn, against the target's nearest city:**
  1. **Strong enough:** go, walls or not. No siege is asked for.
  2. **Too weak, and a clearly easier city is in reach:** re-target. Clearly easier means another unwalled or walled
     city within 12 tiles, a major's or a city-state's, with at most 75% of the target's defence, that the plan's army
     can take. Logged.
  3. **Too weak, and no easier city:** the build-up brings siege (the larger of 2 and the plan's siege count). Logged.
- **OVER only on the real game-state exits:** the counter units, the army lost, no target in reach, the core obsolete, a
  major declaring on us, peace. The walls exit is gone.
- **Personality's plan exits:** iExitCityStrength (China's 25) works the same way as an absolute strength limit, and
  stays.

LEAD (8:49am): design first, as asked. Walls are no longer an exit or a reason to re-target. A strength check (the plan's
upgraded army vs the city's defence: counted units >= 40% of it, total >= 3x, 2+ melee) decides: go if strong enough;
re-target only to a clearly easier city (at most 75% of the defence, takeable); bring siege only when too weak; OVER only
on the real exits. Coding it on ai/war now (replaces dd375b2a's walled logic).

**Coded: ai/war 890aa037** (replaces dd375b2a's walled logic):
- **The check:** IsStrikeArmyStrongEnough, as designed above.
- **Re-target:** FindStrikeRetarget picks the weakest clearly easier city in reach, a major's or a city-state's.
- **Siege:** m_iStrikeSiege, only when the army is too weak for the city.
- **Removed:** the walls exit and the walls condition on PREP -> BUILDUP.
- **Siege target:** an early strike's siege target follows the strength check, and a late strike's walled +2 uses the
  same flag.
- **Logs:** "Strike: re-target from X (city, defence D, too strong...) to Y (city, defence d, N tiles...)" and "Strike:
  target X (defence D) too strong..., the build-up brings siege".

Not changed: the target choice's own preference against walled hill cities (GetNewAIConquestTarget) and the city-state
pick's walled-hill skip. They only rank or choose; they don't end anything. CI is running.

**The user's anchor (via the lead):** Marrakesh, about 19 defence with walls and a Warrior inside, fell to 6 promoted
Jaguars and 4 Composite Bowmen, no siege, by about T54 Quick. Under the check that's about 92 attack against 19, nearly
5x: comfortably "go". The 3x line holds, with room for a weaker army.
The user, directly: "i think it took me 5 turns to take the city." So at about 5x the defence it still took 5 turns of
assault.
- **The 3x line answers "can it be taken", not "how fast".** A 3x army would take longer and lose more units to city
  strikes and healing. Keep 3x for now, and read the first strikes the check sends at 3-4x. If they stall, raise it to
  4x (one number in IsStrikeArmyStrongEnough).
- **The army has to stay 5+ turns.** War's strike state has no turn limit at war: OVER only on peace, or the army below
  half with nothing taken. Next read: turns spent at the target city per strike, to see whether CP's city-attack
  operations (with SiegeStay/SiegeKeep) hold the siege that long.

**The user: "having a turn limit is bad. just calculate if you can take the city or not."** There was no turn limit in
the strike; the "5+ turns" above was only a read metric, and it's dropped. The 3x ratio is replaced by the calculation
(ai/war ddf5412c). IsStrikeArmyStrongEnough runs the game's own damage math (CvUnitCombat::DoDamageMath, expected values)
on the plan's core and support at their counts, as the units they become at the upgrade tech:
- **Damage per turn.** Ranged units bombard every turn; melee attack every other turn and take the city's
  counter-damage.
- **Healing.** The city heals CITY_HIT_POINTS_HEALED_PER_TURN a turn. If our damage doesn't beat it, the city can't be
  taken.
- **Attrition.** Otherwise the turns it takes follow from the numbers, and over them the city's strike (one a turn) and
  the melee counter-damage must cost less than the army's HP less one unit, which has to walk in.
- **Decisions are unchanged:** takeable, go; not, a clearly easier takeable city; else siege. "Strike: not ready" now
  says "the plan's army takes it in about N turns" or "can't take it".

LEAD: the strike decides "can the army take the city" with the game's damage math (ddf5412c), not a ratio, and has no
turn limit anywhere. CI to follow.

**With a buffer (the user: "you probably want a little buffer"; ai/war a5245367):** the calculation counts our damage at
80% and the city's damage to us at 125%. A city counts as takeable only if it still falls with the dice against us,
covering what expected values leave out: the garrison soaking damage, turns out of position, and bad rolls.

**The user (9:09am ET): "only start the attack if the city is takeable. ... i dont think there should be any retreat once you
commit. If you are strike civ and your first attack fails you probably lose the game anyway."** Design:
1. **Declare only when takeable.**
   - The strike counts as ready, or as ready as it gets, only if the army actually on hand can take the target's
     nearest city. The test is the same damage math with the same buffer, on our land combat units as they are (siege
     included).
   - Until then it keeps building, re-targets to a clearly easier takeable city, or brings siege.
   - If it can never take it, it stays in its build-up rather than attacking. "Strike: not ready" names why.
2. **No retreat once committed** (the strike's war, until a city is taken from the target):
   - the strike state's "army below half, nothing taken" exit is removed;
   - peace with the strike's target is refused (DoUpdatePeaceTreatyWillingness);
   - CP's operations against the strike's target don't abort at half strength (CvAIOperation).
   - After the first capture, peace and operations go back to the normal rules, and peace ends the strike as before.

LEAD (9:09am): the strike declares only when the army on hand can take the target (the damage math with the buffer), and
doesn't retreat once committed: no OVER on losses, no peace with the target, no half-strength abort of its operations,
until a city is taken. Coding on ai/war.

**Coded (9:15am ET), ai/war head 103bd11d:**
- **27476943:** declare only when takeable, plus no retreat. Its own CI run couldn't build: IsStrikeNoRetreat sat in
  CvMilitaryAI's private section. Fixed in 04ab5813, with the take-the-city queries made public too.
- **Economy 0044 (9e59c9db):** the wonder and gift bans at their chokepoints, held to our first declaration.
- **HasStrikeDeclared (0e1b744e):** exact and saved. Economy 0045 (eaabcea7) reads it.
- **War on us is no longer an exit (103bd11d; the lead's question on Persia 15A7D14F, OVER at T70 when Germany and
  Ethiopia declared on it):**
  - the strike's own target declaring on us in BUILDUP is the strike's war (no retreat);
  - anyone else, or in PREP: the strike goes on, logged, and its declaration waits while any of our cities is in danger
    of falling (IsStrikeHomeSafe).

LEAD (9:15am): Economy 0044 is in (with 0045 and HasStrikeDeclared). War on us is no longer a strike exit: the target's
declaration is the strike's war, and a third party's only delays our declaration while a city is in danger. "Ready for
the next block" on 103bd11d when CI is green (about 10:36am).

**Update:** the lead tagged ab-04ab581 (claude/ab-c1 fast-forwarded to ai/war 04ab5813) for the PCs. 103bd11d (war on us
is no longer an exit, which answers the third-party question) comes after it, for the next tag.

LEAD: the answer to "attacked by a third party ends the strike?" is no. It's on ai/war 103bd11d, one commit after
04ab581; re-tag when convenient. War is checking CI on ab-04ab581 and will push an URGENT fix if it doesn't build.

**CI (9:33am ET):** ab-04ab581 is green (claude/ab-c1 run 329: MSVC and clang, with the A/B DLL published); the PCs can
run it. claude/ab-c1 is now at 103bd11d too (run 331 building).

LEAD: ab-04ab581 green. 103bd11d is building on claude/ab-c1. War confirms when it's green.

LEAD: 103bd11d is green on claude/ab-c1 (run 331): war on us is no longer a strike exit.

**Read, first game on ab-103bd11 (PC 1 bullyabort22, 15286C56; 10:28am ET).** Songhai, a late strike: core Knight x6
(Mandekalu), pre-build Horseman x6, upgrade at Chivalry, K 2. It sat in **PREP from T1 to T148** and never reached
BUILDUP. It declared on India at T148 outside the strike, so the strike went OVER ("we declared a war outside the
strike"), and it took 1 city. No wonders or gifts (Economy's bans held).
- **Why no BUILDUP: a deadlock between two halves.**
  - Personality's late economy-ready (IsStrikeEconomyReady) needs half the upgrade bill saved: 6 x 100 / 2 = 300 gold.
  - Economy's late-strike saving runs only in BUILDUP (IsLateStrikeSaving). Before BUILDUP nothing holds the gold:
    51 (T10), 237 (T50), **283 (T60, the peak)**, 188 (T80), 0 (T100), 167 (T120), 15 (T140).
  - So BUILDUP waited for gold that nothing saves until BUILDUP.
- **The army stayed small in PREP.** The Horseman (the pre-build) was "badtimeorplace" from T56. The list stalled at
  "LIST WAIT ... item 18 Horseman" from about T100. In late PREP (economy first), Personality's aggressive-style quiet cap
  (cities + 1 land units, not in a war build-up) applies, as well as War's peace cap (now the plan's army, 9). The army
  comes in BUILDUP by design, and BUILDUP never came.
- **The fix belongs to Personality or Economy (asked both).** Either the late gold gate is dropped or met another way
  (e.g. counted at BUILDUP instead of before it), or Economy saves toward it in PREP once the tech and K cities are met.
  War's state machine needs no change; it calls IsStrikeEconomyReady.

LEAD (10:28am): reading only. ab-103bd11's first game: Songhai (late) never left PREP. Personality's economy-ready wants 300
gold saved, and Economy saves only after BUILDUP, so nothing ever saved it (peak 283 at T60, then spent). Asked
Personality and Economy to settle which side changes. War's code is unaffected.

**Economy 0046 (ai/war 4cc694de):** a late strike's PREP keeps its income. The list holds combat items while net gold is
under +2 a turn, and IsLateStrikePrepSaving keeps the treasury toward iEconomyGoldTarget once K cities and the upgrade
tech are in reach. That's Songhai's deadlock; unit upkeep was what drained it (Economy's read).

**Denmark (bullygreedy22, 15E8F168, ab-103bd11; the lead).** LateStrike Denmark went PREP -> OVER at T69: CP's own war
logic declared on China, outside the strike (it still took a city at T90). The lead asked: block, or adopt CP's war as
the strike? **War's call: block.** The user's rule is "only start the attack if the city is takeable", and adopting
would skip that check.
- **Coded, ai/war e1d4d076.** CvDiplomacyAI::DeclareWar, which every AI declaration goes through, refuses for a strike
  civ in PREP or BUILDUP unless the declaration is the strike's own: on its target, in BUILDUP, with the army ready or
  as ready as it gets (both require the city takeable and home safe). Logged "Strike: declaration on X refused".
- Wars on us are unaffected. After OVER, or once at the strike's war, nothing is blocked.

LEAD (11:02am): (1) Economy 0046 is on ai/war (Songhai's deadlock). (2) Denmark: War blocks CP's own declarations for a
strike civ before its strike, rather than adopting them (adoption would skip "only attack if takeable"), e1d4d076. CI is
queued (runners slow); for the next tag when green.

**Personality's answer to the deadlock (merged, ai/war bde35e28):** a late strike's PREP -> BUILDUP needs no gold, only
the upgrade tech known or researchable and K cities, or boxed in (553dfdc). f8f2de7 also brings:
- lists ordered by buildability (only inferred lists are reordered);
- late lists put Currency and a Market before the army;
- spikes past T150 Standard count as out of reach (America's Gunpowder core is gone; a warmonger with no spike gets the
  generic Composite Bowman rush).

Economy 0046's PREP saving stays as a reserve.

LEAD: the next tag candidate is ai/war bde35e28: 103bd11d + Economy 0046 + War's declaration block (e1d4d076) +
Personality f8f2de7. CI is running.

**The lead (11:08am ET): 3 of 3 late-strike games on ab-103bd11 ended PREP through CP's own war** (Denmark T69, Songhai
T148, Zulu T110). War's e1d4d076 blocks exactly that. Personality's head (553dfdc, d43fece, f8f2de7) is already merged
after e1d4d076 and Economy 0046, at bde35e28.

**Zulu 162667AE:** after losing units, the list went back to Archer items and waited from T80 to T106 ("item 8/7
Archer"). Most likely the Archer is obsolete once the Composite Bowman can be trained, so the item can never be built.
That's Economy's executor. Asked Economy to build the unit an item's class upgrades into when the class itself can't be
trained, and to count it toward the item.

LEAD: bde35e28 already has Personality's head after e1d4d076 and Economy 0046. "Ready for the next block" comes when
its CI is green (check due about 11:31am). Zulu's Archer wait is passed to Economy (executor).

**Economy 0047 on ai/war (11:14am ET).** Applied after bde35e28, so the head is now **d75dfec9**. With 0047, an obsolete
list item or army class trains the first trainable unit on its upgrade line, logged "X (for Y, obsolete)". That fixes the
Zulu's Archer LIST WAIT (162667AE, T80-T106) and the generic rush's Archer core going obsolete at Construction. An item
whose tech isn't in yet still waits. My only change was moving a doc comment back above its function.
LEAD: Economy 0047 is on ai/war (d75dfec9, after bde35e2), and its CI replaces bde35e28's. "Ready for the next block:
ai/war d75dfec9 green; RoleFixes += StrikeList" follows when MSVC and clang pass (check about 11:50am).

**Design: the lead's pre-flight findings on d75dfec (11:30am ET), before code.**
- **(1) Deadlock.** After e1d4d07, the only declaration a strike civ may make in PREP/BUILDUP is the strike's own, on
  m_eTimingBuildupTarget. That target never changes once the window is open, so it can go stale: a defensive pact, the
  committed target changing, the target killed. A late civ with no major in reach never opens a window. An early civ whose
  core needs a missing resource stays in PREP forever. All three block every declaration for good. The fix uses game state
  only:
  - **Each BUILDUP turn the strike's target is checked** (IsStrikeTargetValid: alive, met, declarable or at war, nearest
    city revealed and within 12 tiles, an attack target, no defensive allies for a major, no protector/ally/recent peace for
    a city-state). The first valid target in this order is used: the window's target, the current target, the committed
    target, the nearest major in reach, the nearest city-state in reach. A change is pinned (m_iStrikeCityState: the
    diplomacy takes a major there as its target), the window follows, siege and the takeable cache are reset, and it is
    logged "Strike: target X -> Y (...)". **No valid target: OVER** ("no target in reach").
  - **The core can't be trained with its tech in** (a missing resource; IsStrikeArmyBuildable false with the core's and
    the pre-build's techs known), in PREP or BUILDUP: OVER.
  - **A third party's war no longer closes the strike's window** (DoTimingBuildup closed it at any major war, and the
    block needs an open window). That was the same deadlock while a war on us lasted.
- **(3) Deals.** A human could pay a strike AI to declare war, and the payment and penalties applied while the
  declaration was refused. Now TRADE_ITEM_THIRD_PARTY_WAR is invalid for a giving team with a blocked strike civ, a
  co-op war target is invalid when we'd have to declare and it's blocked, and a human's move-troops request answers
  neutral instead of "war" when the block would refuse. The AI-to-AI move-troops path already falls back to a promise
  when the declaration fails.
- **Expected:** no strike civ stays in PREP/BUILDUP with no valid target. "Strike: target" and "no target in reach"
  lines will show in games where the old target went stale. Captures should not drop.
- **Code: ai/war 056ed90f** (after d75dfec9), 4 files, +192/-2, as designed. One refinement: the attack-target check
  applies only to a new target, since CP's list can drop a city for a turn, and a held target stays. Siege and the
  takeable cache restart only when the city changes.
LEAD: the pre-flight fixes (1) and (3) are on ai/war at 056ed90f, after Economy 0047. "Ready for the next block: ai/war
056ed90f green; RoleFixes += StrikeList" follows when MSVC and clang pass. New log lines to read: "Strike: target X -> Y",
"no target in reach", and "the core can't be trained".
**Economy 0048 on ai/war (11:31am ET):** applied on top of 056ed90f, so the head is now **42bf3277**. 0048 replaces 0046's
PREP saving with a unit hold: a late strike's PREP, not at war with a major, with net gold under +2, trains no new
combat unit unless the city is in danger. It also makes the danger path build an obsolete unit's upgrade.
LEAD: ai/war 42bf3277 = Economy 0047, the pre-flight fixes (056ed90f) and Economy 0048. "Ready for the next block"
follows when its CI is green. Reading only: no new games in the expert-block runs this hour.
LEAD (11:36am ET): ai/personality 99d3ced is merged after 42bf327, and **the head is now 0d19241c**. It has Economy
0047, the pre-flight fixes 056ed90f, Economy 0048 and Personality 99d3ced (list ordering from game data only, and the
Market rule guard). For your pre-flight review of d75dfec..0d19241c, 056ed90f holds the new logic (the design entry
above). "Ready for the next block: ai/war 0d19241c green; RoleFixes += StrikeList" follows when its CI is green
(check about 12:15pm).

**trial23 164B7CEA (ab-d75dfec, the lead's T80 trial), 11:48am ET: Persia's PREP ended with no target. Fixed in f98404e6.**
- **What happened.** Persia (EarlyStrike) picked the city-state Budapest at T5 and Sydney at T19, built the plan's army,
  then logged "PREP -> OVER (the army is built and no target is in reach)" at T45. CP opened a window against Denmark,
  in reach, at T46.
- **Cause.** Sydney stopped qualifying, most likely when Carthage became its ally (Carthage "gained friend" at T38), and
  was dropped without a log line. The PREP picker kept a city-state only while FindStrikeCityState still returned it, and
  never considered majors CP hadn't committed to. So "in reach" for the exit was narrower than the picker.
- **Fix.** PREP now uses the same targets, in the same order, as BUILDUP's per-turn check: the pinned target while
  IsStrikeTargetValid, else the nearest major in reach, else the nearest city-state. Drops are logged ("Strike: target X
  dropped (why)"). BUILDUP's city-state fallback now uses the picker's definition. A DoF partner is not a target.
LEAD: the trial23 fix is on ai/war at **f98404e6** (after 0d19241c). "Ready for the next block: ai/war f98404e6 green;
RoleFixes += StrikeList" follows when its CI is green.

**The lead's second pre-flight review (d75dfec..0d19241, 11:48am ET): all seven findings handled in 8bc6c0c2.**
1. **Resource exit.** "The core can't be trained" now means the tech is known and we own none of a resource it needs
   (imports count). The free count no longer decides it: an army built from Horses or Iron spends them. The same fix
   applies to IsStrikeArmyBuildable, so PREP -> BUILDUP and the window don't stall once the army has used its resources.
2. **Third party's war.** GetNewAIConquestTarget returned nothing during any major war. A strike in BUILDUP with a
   pinned target now gets past that return, skips the search, and uses the pinned target. The strike pins its target
   whenever we're at war with a major.
3. **HasStrikeDeclared** is set only by our own declarations (the majors counter and CvDiplomacyAI::DeclareWar), not by
   a city-state's war on us.
4. **No defensive pact, and no voluntary vassalage,** for a strike AI in PREP or BUILDUP. Capitulation in a peace deal
   is still allowed.
5. **No peace-treaty turns** in the target checks (the user's no-turn rule). canDeclareWar enforces the treaty.
6. **Already in f98404e6** (PREP looks at majors in reach, then city-states).
7. **The war item's tooltip** says "A special game rule prevents this action." when the strike block refuses it.
LEAD: ai/war **8bc6c0c2** has the trial23 fix (f98404e6) and these seven. "Ready for the next block: ai/war 8bc6c0c2
green; RoleFixes += StrikeList" follows when its CI is green. Then the trial game, then the block.

**The lead's third pre-flight review (0d19241..8bc6c0c, 11:57am ET): fixed in 2181214f.**
1. **Economy-ready.** Personality's IsStrikeEconomyReady now counts Horses or Iron in use by the army
   (IsStrikeClassBuildable, a new public helper shared with IsStrikeArmyBuildable). Before, PREP waited until the core
   went obsolete once the early units had used the resource. This is a one-line change in Personality's file, made at
   the lead's request; Personality has been told.
2. **Target flip.** In PREP the pinned major is kept while it stays valid, including when it has become CP's committed
   target. Before, dropping the pin let CP's own loop reject the target, so it changed every turn.
3. **Resource amounts.** The resource checks compare what we own with the amount the unit needs, not with zero.
4. **Comments** on the peace-treaty check fixed.
5. **Tooltip:** it checks every player on the target team, the same as the validity check.
LEAD: ai/war **2181214f**. "Ready for the next block: ai/war 2181214f green; RoleFixes += StrikeList" follows when its
CI is green.

**trial24 1664FF61 (ab-8bc6c0c, 12:10pm ET): the take-the-city check was 100 times too strict. Fixed in 0cb5402b.**
- **What happened.** Persia spent 39 turns in BUILDUP without declaring. The plan army was ready from T58, but the log
  said it "can't take" Kuala Lumpur (defence 19), and then Utrecht (defence 11) with 7 field units.
- **Cause.** CvUnitCombat::DoDamageMath returns hit points x100, and the game divides by 100 to get HP.
  StrikeArmyTakesCity divided by 100 and then compared the result, as if it were still x100, with the city's healing
  x100. So every army's damage was 100 times too small, and no city ever read as takeable. A scaling bug, not just a
  buffer that was too strict.
- **Fix.** Damage is kept x100. The buffer is recalibrated to 90% of our damage and 110% of the city's damage to us
  (was 80% and 125%). For a strike, the plan's core and support at their counts now count as a built army, so missing or
  untrainable siege never holds the declaration; taking the city decides.
- **What the check returns now** (VP expected values: base damage 2400 + 1200/2, healing 8 a turn, 250 HP, walls
  about +100):

  | army | city | result |
  |---|---|---|
  | 6 Jaguars + 4 Composite Bowmen | Marrakesh, defence 19 + walls (about 350 HP) | **GO** in about 4 turns (the user took about 5) |
  | 7 Immortals + 3 Archers | Utrecht, defence 11 | **GO** in 2 turns |
  | 7 Immortals + 3 Archers | Kuala Lumpur, defence 19 | **GO** in 3 turns |
  | 3 Warriors | defence 19 | still no |
  | 3 Spearmen + 2 Archers | defence 19 | still no |
  | 4 Warriors + 2 Archers | defence 12 | still no |

LEAD: ai/war **0cb5402b** has the calibrated check. "Ready for the next block: ai/war 0cb5402b green; RoleFixes +=
StrikeList" follows when its CI is green.

LEAD (12:28pm ET): ready for the next block: ai/war 0cb5402b green (MSVC and clang, run 42259566714 on claude/ab-c1, same
SHA; the ai/war run is still queued); RoleFixes += StrikeList. bullyabort23 on ab-0cb5402 is already running on PC 1. Reading
only: no new expert-block games this hour.

**bullygreedy23 167DE984 (ab-0cb5402, the lead, 12:47pm ET): the Celts' city-state declaration was undone every turn. Fix
for the next block: 5fe900a1.**
- **What happened.** The calibrated math works ("the plan's army takes it in about 2 turns" against defence 13-14). But
  the Celts logged "Strike: declaring war on the city-state Panama City (the army ready)" every turn from T66 to T87,
  and no war held. The war came at T88, by which time Panama's defence was 26, and nothing was taken in 62 turns.
- **Cause, from the code** (the logs aren't in yet). The strike's city-state got the WAR approach only in the ATTACK
  phase, but while the window is open the phase is WINDOW. So it was never our CS war target, and part 3 of
  DoUpdatePeaceTreatyWillingness made peace with it after each declaration ("This City-State is no longer our war
  target!"). T88 is when the window ended and the phase became ATTACK. **To confirm in the pair-1 logs:**
  DiplomacyAI_Peace_Log should show the Celts making peace with Panama City from T66 to T87.
- **Fix.**
  - The approach is WAR toward the strike's city-state in BUILDUP once we're at war with it, or once the army is ready
    or as ready as it gets, whatever the phase.
  - The city-state peace skips the strike's own target (BUILDUP, and while IsStrikeNoRetreat).
  - The declaration's outcome is logged ("made: at war" or "failed: <why>").
LEAD: the fix is on ai/war **5fe900a1**, for the next block; the running block is untouched. I'll confirm the cause from
the pair-1 logs when they land.

### Strike ownership audit (War, 1:25pm ET; read-only first, the gates follow)

The user approved a structural fix: while a strike is on (PREP, BUILDUP or WAR, until OVER), it owns these decisions
outright, gated once at the lowest level so CP's systems can't override it. Below, "covered" is what ai/war 5fe900a1
already gates. A **proposed gate** is the single choke point every caller passes through.

| # | decision | every path that can make it for an AI player | covered today | proposed gate (lowest level) |
|---|---|---|---|---|
| 1 | **declaring war** | CvDiplomacyAI::DeclareWar (CP's approach war, coop war DoStartCoopWar, a paid war in the deal CvDealClasses ~5151, a move-troops refusal ~34418/41747, the strike's own); CvTeam::declareWar from voluntary vassalage (CvTeam ~10008: the master inherits the vassal's wars); a defensive pact's chain (CvTeam::DoDeclareWar ~1671); team merge (CvTeam ~465); game options ALWAYS_WAR (CvGame ~1835, ~9327); capitulated vassal follows its master (CvTeam ~9835) | DiplomacyAI::DeclareWar (e1d4d07); war-bribe item, coop target, move-troops answer (056ed90); DP and voluntary vassalage items (8bc6c0c) | **CvTeam::declareWar**: refuse an aggressor declaration (not bDefensivePact) by a team with an AI strike civ when IsStrikeDeclarationBlocked holds for every member of the target team. Game options and capitulation stay (game rules) |
| 2 | **making peace** | the peace-treaty deal (CvDealClasses ~5303, AI acceptance through IsPeaceBlocked); third-party peace item (~4886); CP's city-state peace (DoUpdatePeaceTreatyWillingness part 3, ~26065); city-state-side peace (CvMinorCivAI DoTestEndWarsVSMinors ~5509, DoTestEndSkirmishes ~5560/5608; quests ~3393/3846, CS vs CS); espionage coup (CvEspionageClasses ~3997); World Congress (CvVotingClasses ~1449, CS vs CS); vassal capitulation (CvTeam ~9818) | majors: RefusePeaceTreaty while IsStrikeNoRetreat (27476943), which makes the deal item invalid; the strike's city-state in part 3 (5fe900a1) | **CvTeam::makePeace**: refuse when an AI strike civ on either team refuses peace with a member of the other (IsStrikeNoRetreat, or BUILDUP at war with the strike's city-state target). The deal-level IsPeaceBlocked stays as the first line, so a deal never half-executes |
| 3 | **the approach toward the strike's target** | SelectBestApproachTowardsMajorCiv (WAR only when GetNewAIConquestTarget returns the target, and CP's zero-outs can veto it: vScratchValueOverrides[WAR] == 0 for recent peace, no reachable target, bankruptcy); SelectBestApproachTowardsMinorCiv; every approach change goes through SetCivApproach, which aborts operations (AI_ABORT_DIPLO_OPINION_CHANGE / TARGET_NOT_VALID) | minor: forced WAR (5fe900a1); major: through the conquest target only, CP can veto | **CvDiplomacyAI::SetCivApproach**: toward the strike's target, while the strike refuses peace with it (as in 2), any approach other than WAR is replaced by WAR |
| 4 | **the target and army operations** | the target: CP's RequestCityAttack / UpdateOperations pick from CP's attack-target list; aborts all go through CvAIOperation::SetToAbort: timeout (ShouldAbort, 42 turns; CheckTransitionToNextStage), VerifyOrAdjustTarget, half strength (UnitWasRemoved), approach change (SetCivApproach), war-state DEFENSIVE (CheckLandDefenses ~3996), peace / can't declare (UpdateOperations ~4091), DoMakeWarOnPlayer, DoWeMadePeaceWithSomeone, vassalage | half-strength only (27476943) | **CvAIOperation::SetToAbort**: for an operation against an enemy the strike refuses peace with, refuse the retreat reasons (HALF_STRENGTH, TARGET_NOT_VALID, TOO_DANGEROUS, WAR_STATE_CHANGE, DIPLO_OPINION_CHANGE, CANCELLED). Mechanical ends stay (NO_UNITS, NO_TARGET, LOST_PATH, NO_MUSTER, TIMED_OUT, TARGET_ALREADY_CAPTURED, KILLED, SUCCESS). Plus, in WAR, a city attack is requested on the target whenever no offensive operation against it is running |
| 5 | **disbanding and gifting strike units** | the peace cap (DoTimingBuildup); DisbandObsoleteUnits (deficit/oversupply through FindUnitToScrap, ArmyScrap FindArmyScrapUnit, a useless ship, low-HP can't-heal); CvPlayer::DoBankruptcy (FindUnitToScrap); CvGrandStrategyAI::DoGreedyDisbandToCap; CvHomelandAI::ReviewUnassignedUnits (scrap after 7 idle turns); unit gifts to city-states (CvPlayer::AddIncomingUnit from the peace cap, the deficit, Homeland 1504/1635, greedy cap) | peace cap skipped in PREP/BUILDUP | one predicate, **CvMilitaryAI::IsStrikeKeepingUnit** (AI strike civ in PREP/BUILDUP/WAR, a land combat unit), applied at FindUnitToScrap, FindArmyScrapUnit, DoGreedyDisbandToCap, ReviewUnassignedUnits and AddIncomingUnit (gifts). Exempt: real bankruptcy (gold below 0, the game's rule) and a dying unit that can't heal |

LEAD: the audit is above. Next I code the five gates on ai/war for the next block; Economy owns production, gold, research
and policies.

**The five gates are coded: ai/war b9dd1b77** (after 5fe900a1, 8 files, +139). Each is at the gate point in the table:
CvTeam::declareWar, CvTeam::makePeace, CvDiplomacyAI::SetCivApproach, CvAIOperation::SetToAbort (plus a city attack
requested on the target in WAR whenever no attack on it is running), and IsStrikeKeepingUnit at FindUnitToScrap,
FindArmyScrapUnit, DoGreedyDisbandToCap, ReviewUnassignedUnits and AddIncomingUnit. New log lines to read in the next
block: "(gate 1)", "(gate 2)", "keeps going (gate 4", "city attack requested".
LEAD: the ownership gates are on ai/war **b9dd1b77**, for the next block. CI to follow.
**Economy 0049** (production, gold, research and policy ownership) is applied on top, so the head is now **ai/war
7d011c38**. It doesn't conflict with War's gates: Economy's deal gate covers a strike AI paying gold, War's covers it
declaring for pay, and the production redirect leaves appended operation units alone.
LEAD: the next block's candidate is ai/war **7d011c38** (city-state fix 5fe900a1, ownership gates b9dd1b77, Economy
0049). "Ready" follows when CI is green.
**Economy 0050** (once the plan's counts are met, more core units only in WAR) is applied on top: **ai/war 33ef2159** is
now the combined head.
- **Economy's read of 167DE984 confirms the Celts' loop:** DiplomacyAI_War_Log has a WAR DECLARATION on Panama City at
  T66, T67 and T68, but the state never moved to WAR. So each declaration was undone before the next update, which fits
  the city-state peace. Fixed in 5fe900a1.
- **bullyabort23 15BE6EDA:** the Aztecs reached WAR at T56 on the Netherlands, attacked Rotterdam T59-T62 (HP 161 -> 90)
  with 4, then 3 units, and then nothing until T125. That is the "operation dropped" failure the ownership gate 4
  (b9dd1b77) addresses: retreat aborts are refused, and a city attack is requested whenever none is running on the target.
LEAD: the combined head is **ai/war 33ef2159** (5fe900a1, b9dd1b77, Economy 0049, Economy 0050), for your pre-flight review
of 0cb5402..33ef2159. The Aztec 169CA418 read (Ur, T58-T77) follows when its logs land.

**The lead's pre-flight review of the ownership gates (1:26pm ET): War's findings fixed in ece1822b.**
1. **No fight to the death.** No-retreat now releases when a city of ours is lost since the war began, our capital is in
   danger of falling, or the war state is NEARLY_DEFEATED. DEFENSIVE is left out on purpose: it is the abort gate 4
   refuses. No-retreat also requires the target alive and at war with us (finding 6).
2. **Deals.** The peace-treaty and third-party-peace items are refused when CvTeam::IsStrikePeaceRefusedWith holds, so no
   gold moves and setForcePeace isn't set for a peace that makePeace would refuse.
3. **WAR ends with its purpose:** OVER once a city is taken (the war goes on as CP's), or at peace with the target, or
   with the target gone.
4. **Only an AI's own call is gated** (the originating player). Lua, human teammates, vassal liberation and the
   independence war pass.
7. **Homeland's gifts** skip strike units.
- **Also found:** AB_COUNT_CITIES_CAPTURED counts captures from majors only, so a city-state strike's capture (Ur,
  Panama City) never registered for no-retreat or the exits. GetStrikeCaptureCount now adds the city-state captures.
  **Checked the read scripts:** attack_funnel's "captured" is the CSV's CitiesCaptured (majors only). expert_block now
  adds the CSV's CityStatesCaptured. The overnight table doesn't change (no city-state captures in those 22 games), but
  city-state strikes from bullygreedy23/bullyabort23 on would have been under-counted. LEAD: attack_funnel (your branch)
  could add CityStatesCaptured the same way.
LEAD: the combined head is now **ai/war ece1822b** (33ef2159 + these fixes). "Ready" follows when CI is green.
**Economy 0051** is applied on top (the strike tree's policy pick now runs; it was gated on a flag that's always true): **ai/war 75a70345**.
LEAD: the combined head is **ai/war 75a70345**. "Ready" follows when CI is green. Reading only: no new expert-block games this hour.

**167DE984 confirmed (Celts, Panama City), 1:45pm ET.** DiplomacyAI_Peace_Log has "The Celts VS. Panama City, This
City-State is no longer our war target!" at T67, T68, T69 and T70. The city-state peace undid each declaration, as
diagnosed. Fixed in 5fe900a1.

**169CA418 (Aztec, Ur), the lead's question: which step broke between T58 and T77. Answer: the army never went to Ur.
Fixed in f9245a1e.**
- **Timeline:**
  - **Target:** Ur pinned at T22 (no committed major in reach then).
  - **BUILDUP** at T40.
  - **Declaration:** "declaring war on the city-state Ur (the army ready)" at T57, BUILDUP -> WAR at T58.
  - **T58-T67:** only "window paused, units unaffordable".
- **Where the army went.** CP had committed to Morocco, with the WAR approach from T55 ("PREP Gathering"). Its sneak
  operations 1257 and 1338 gathered every unit, Jaguars, Composite Bowmen and the Great General, at Teotihuacan against
  Marrakech (op 1338: "SiegeArmy: waiting for more units ... Marrakech needs 60", T55-T73). Op 1257 timed out at T65.
  **No operation ever targeted Ur.** It was only CP's fourth attack target (score about 2,500 against Marrakech's about
  15,700), so nothing reached it and nothing attacked it. The city-state war itself held (no peace with Ur).
- **T76:** op 1338's DeclareWhenGathered declared on Morocco. IsStrikeDeclarationBlocked allowed it, because it covered
  only PREP and BUILDUP.
- **Did the ownership gates cover it?** Not fully. Gate 4's attack request would have started an operation on Ur in WAR,
  but CP's Marrakech operations would still have taken the army, and the T76 declaration would have gone through.
- **Fix (f9245a1e):**
  - With a city-state pinned, CP holds no major conquest target.
  - RequestCityAttack refuses an attack on anyone but the strike's target, or a player at war with us, while the strike is
    on (PREP, BUILDUP, or WAR before a capture).
  - The declaration block now covers WAR before a capture.
LEAD: both answered. The combined head is now **ai/war f9245a1e** (75a70345 + the army-target gate). "Ready" follows when
CI is green.

**16DAE4CC (Aztec, bullygreedy23 game 7), the lead at 2:30pm ET: a target oscillation every turn from T96 to T106. Fixed in
b0d7e1c1.**
- **What happened.** "re-target from Singapore (defence 24, too strong) to Sweden" and then "target Sweden -> Singapore
  (the nearest city-state in reach)", 11 times, until the core went obsolete at T106. It never declared. (The T48-T71
  "declaring war on Singapore" loop is the city-state peace, fixed in 5fe900a1.)
- **Cause.** FindStrikeRetarget had its own validity checks. It missed IsStrikeTargetValid's: a declared friend, and the
  attack-target check. So it picked Sweden, the next turn's BUILDUP target check rejected Sweden, fell back to the nearest
  city-state, and the strength check sent it back to Sweden.
- **Fix.** The re-target skips any candidate IsStrikeTargetValid rejects, so it only goes to a target the next turn's check
  keeps. With none, the existing path holds: no easier city, so the build-up brings siege. A too-strong city-state stays the
  siege target and isn't picked again by nearness.
LEAD: the full head is now **ai/war b0d7e1c1** (75a70345, ece1822b, f9245a1e, b0d7e1c1). It covers the 16DAE4CC
oscillation, and f9245a1e's army-target ownership covers the rest. "Ready" follows when CI is green. No ai/war build since
b9dd1b77 has finished yet (each was replaced by the next push), so this CI run is the first compile of the gates.
**Economy 0052** is applied on top. A city-state declaration counts for HasStrikeDeclared only if the war still stands at
the next strike update. 16DAE4CC's undone Singapore "declarations" had set the flag and lifted the wonder/gift bans after
OVER. Checked: the confirmation runs for every timing-buildup player, before the strike-civ return, and nothing else reads
the flag.
LEAD: the full head for the pre-flight review and trial is **ai/war c288d09c** (b0d7e1c1 + Economy 0052). "Ready" follows
when CI is green.

**The lead's third pre-flight review (7d011c3..c288d09, 2:36pm ET): findings 2-7 fixed in 2c283300.** (Economy has #1, a
BUILDUP deadlock in 0050.)
- **2. PREP prefers a major.** A city-state pin gives way to a major that comes in reach.
- **3. No CP target during a city-state war.** In WAR on the strike's city-state, before a capture, CP holds no major
  conquest target.
- **4. Captures from the target only.** The strike counts only our cities whose previous owner is the strike's target. A
  counter-attack on a third party no longer ends the strike's war.
- **5. Bullying.** RequestBullyingOperation goes through gate 4.
- **6. Peace gate.** It applies only when the originator's own strike refuses. Vassal liberation and Lua's Teams:DeclareWar
  / MakePeace pass NO_PLAYER; the Lua bindings are now written out, with an optional originator argument.
- **7. Losses and danger.** No-retreat also releases when our city count falls below its count at the strike's war (a loss
  to a city-state or barbarians), or when any of our cities is in danger of falling (DEFENSIVE with a city in danger, as
  the lead suggested). The deal-item peace refusal keeps no human exclusion on purpose: a human target is refused like an
  AI one, which IsPeaceBlocked already did for majors.
LEAD: the head is **ai/war 2c283300** (c288d09c + these fixes); Economy's #1 goes on top. "Ready" follows when CI is green.
**Economy 0053** (the review's #1, the 0050 BUILDUP deadlock) is applied on top. In BUILDUP the list builds the siege War asks
for (GetTimingBuildupSiegeTarget, with its tech moved ahead in research if missing), and keeps building core while
IsStrikeTargetTakeableNow is false. Checked: the siege count comes from War's own function, which is the right source.
Untrainable siege still never holds the declaration (0cb5402b); it is only built while BUILDUP waits.
LEAD: the full head is **ai/war 791ab9d7** (everything through the third review + Economy 0049-0053). "Ready for the trial" follows
when CI is green.

**16DAE4CC confirmed from the logs (3:01pm ET).** From T96, every turn: "target Sweden -> Singapore (the nearest city-state
in reach; the build-up's target Sweden)", then "re-target from Singapore (defence 24, too strong) to Sweden (Stockholm,
defence 16)". So the BUILDUP check rejected the window's own target, Sweden, even in its held-target form. The Aztecs and
Sweden were FRIENDLY (a declaration of friendship, by the diplomacy logs), which IsStrikeTargetValid excludes and
FindStrikeRetarget didn't. b0d7e1c1 makes the re-target use the same check, so the loop can't recur.

LEAD (3:01pm ET): **ready for the trial and the next block: ai/war 791ab9d7 green** (MSVC and clang, run 42281569284). It
is the first full compile since b9dd1b77, with:
- the city-state fix (5fe900a1);
- the ownership gates and their review fixes (b9dd1b77, ece1822b, 2c283300);
- the army-target gate (f9245a1e);
- the oscillation fix (b0d7e1c1);
- Economy 0049-0053.
RoleFixes += StrikeList.

**trial25 171787CD (ab-791ab9d, the lead, 3:27pm ET): why the city attack on Kyzyl couldn't be launched. Fix for the next
block: b446678a.**
- **The war.** The Aztecs declared on Kyzyl at T61 (confirmed at T62, WAR; "takes it in about 2 turns" at defence 14).
  Gate 4 refused attacks on Bucharest and America all along.
- **T64-T69, op 1612 on Kyzyl.** It gathered and moved (13% progress). At T69 MarchOn ended it as a success ("stalled near
  the target at war, handing over") with the army 4-6 tiles out. The Kyzyl zone then held only 1-2 Aztec units ("too early
  for attacking Kyzyl ... expected max damage per turn 0"). The rest went home to counter-attack postures.
- **T70-T73, "lack of units".** A successful operation marks its units as recently deployed, which keeps them out of new
  operations for 5 turns. The phase was neither WINDOW nor ATTACK, so every required slot needed a free unit. Each request
  failed.
- **T76 on, op 1780.** It formed and then waited in SiegeArmy's bar ("expected damage 33 a turn, Kyzyl needs 36"), although
  the strike's own math said the army takes the city in about 2 turns.
- **Answer.** No path, muster or operation-slot problem as such. The army was handed over short of the city, locked out of
  re-forming for 5 turns, and then held by a second strength bar that disagrees with the strike's.
- **Fix (next block).**
  - An operation against the strike's target doesn't lock its units out.
  - The strike's attack forms with slots still to be built.
  - SiegeArmy's bar doesn't hold an attack on the strike's target while the strike's math says it's takeable.
LEAD: on ai/war **b446678a** (791ab9d7 + this), for the NEXT block; the current block runs to 20 games. CI to follow.

**Economy 0054** (income first under the late-PREP hold; research serves the build list) is applied on top: a24c5408.

**172518A7 (Mongolia, LateStrike; Economy relaying the lead, 3:51pm ET): should Chivalry gate a late strike's readiness?
Yes. Fixed in bf212f7e.**
- **What happened.** Mongolia declared at T120 "as ready as it got" with Chariot Archers, its core (Knight x8) at 0/8,
  before Chivalry, the plan's upgrade tech.
- **Cause.** IsStrikeAsReadyAsItGets looks only at a normal-size army, 3 melee, nothing more affordable and a takeable
  target. A late strike's point is its spike.
- **Fix.** New IsLateStrikeSpikeIn() (the plan's upgrade tech known) gates both readiness paths for late strikes. Early
  strikes are unchanged. A late strike whose tech never comes still exits by the existing rules (core obsolete, no
  target), and Economy's research puts the plan's techs first.
LEAD: the next block's head is **ai/war bf212f7e** (791ab9d7 + the Kyzyl fix b446678a + Economy 0054 + this). CI to follow.
**Revised (4:00pm ET), reverted in 06fd0b87.** The lead pointed out that Mongolia's T123 capture, the first strike capture
we have, came from exactly that early declaration. The suggested middle way (wait for the tech only while it's close and
the army can't take the target) needs no gate. Both readiness paths already require IsStrikeTargetTakeableNow, so while
the army can't take the target nothing is declared, the build-up keeps building (0053), and research goes to the plan's
techs (0054). Once it can take the target, it goes, spike or not. A "few turns away" test would be a turn horizon, which
the user ruled out.
LEAD: the next block's head is **ai/war 06fd0b87**, the same code as a24c5408 (791ab9d7 + the Kyzyl fix b446678a + Economy
0054). CI to follow.
**Economy 0055** (the strike adds no combat unit it can't afford, the counterpart to IsStrikeKeepingUnit) is applied on top:
**ai/war 698525b1**.
- **Why.** In the ab-791ab9d games the strike civs went broke in BUILDUP. Mongolia 172518A7: 14 -> 27 units, net -30,
  treasury 0 from T110 to T120. Aztecs 171787CD: net -11, treasury 183 -> 14. With the army no longer scrapped for
  deficit, the brake has to be on building.
- **Also from Economy:** 0 REDIRECT lines, no ban hits, and Mongolia's capture at T123 in those games.
LEAD: the next block's head is **ai/war 698525b1** (791ab9d7 + the Kyzyl fix b446678a + Economy 0054, 0055). CI to follow.

**bullygreedy24 17436CCD (Zulu, LateStrike; the lead, 4:28pm ET): BUILDUP from T107 to the end with no declaration. Fixed
for the next block in b1eb09de.**
- **What happened.** The strike's own check said "the plan's army takes it in about 2 turns" against Washington (defence
  17-21). But IsTimingBuildupArmyReady also required, for a strike, that the army count as built, by one of three tests:
  - CP's normal field target, which grew from 13 to 21;
  - Personality's plan-ready check;
  - core and support at exact counts: support was 7/8 from T116 to T145 (core 9/5).
- **Fix.** For a strike, readiness is now only: no upgrade waiting whose tech is in, 3 melee units, the army on hand taking
  the target, and home safe. CP's field target, the exact plan counts and siege no longer hold it. Non-strike timing
  attacks are unchanged.
- **The support unit lost and never replaced over 30 turns.** That build ran on ab-791ab9d, before Economy 0055's income
  hold. The list's army phase should have rebuilt it (support short of the plan). Asked Economy to check the Zulu
  production lines from T116 when the pair-2 logs land (about 4:30pm). With b1eb09de it no longer blocks the declaration
  either way.
  **Economy's answer (4:41pm ET):** it wasn't lost, it was upgraded. A Composite Bowman became a Crossbowman at T116.
  Personality's CountStrikeClassLine counts only one upgrade step, so the Crossbowman (two steps from Archer) dropped out
  and support read 7/8. Economy's own count walks the whole line and read 8/8, so the army phase never asked for a
  replacement. b1eb09de removes these counts from War's readiness. Asked Personality to make CountStrikeClassLine walk
  the full line, since its IsStrikeArmyReady and IsStrikeEconomyReady still use it.
LEAD: the next block's head is **ai/war b1eb09de** (698525b1 + this). CI to follow.
**Merged on top (4:44pm ET):**
- **Personality**, ai/personality 090fc792, fast-forwarded:
  - CountStrikeClassLine walks the whole upgrade line;
  - every strike plan gets a full policy-tree order and a never-list.
- **Economy 0056:** a strike civ follows that order the whole game, ideology included.
- **A rename fix** (261d5da8). Personality renamed the field aePolicyOrder -> aePolicyBranches after 0056 was written, so
  0056's four uses wouldn't have compiled.
698525b1 is green (run 42293781599).
LEAD (4:46pm ET): the combined head the lead asked for is **ai/war 261d5da8**: b1eb09de, Personality's policy-tree order and
whole-line count, and Economy 0056. ai/personality now equals it (Personality dropped 444151c, its rename back to
aePolicyOrder), and the final field name is aePolicyBranches. It's ready for your pre-flight review of 791ab9d..261d5da8.
CI to follow.

**bullygreedy24 1762140E (Assyria, LateStrike; the lead, 4:59pm ET): PREP -> OVER at T61, "the core unit is obsolete". Fixed
in c7eed909.**
- **What happened.** The core is the Archer and the upgrade tech is Construction, which obsoletes the Archer. That is the
  plan (upgrade and go to Composite Bowmen), but the exit read it as the end. The generic rush (core Archer) had the same
  risk. After the OVER, CP's own wars (T74, T142) ran instead of the strike.
- **Was it still in 261d5da8?** Yes: one check, in UpdateStrikeState. The profile's window estimate in CvGrandStrategyAI
  only shortens a planning window.
- **Fix.** IsStrikeCoreLineObsolete walks the core's whole upgrade line, as Economy 0047 and Personality's whole-line count
  do. The strike ends only once every unit on the line is obsolete.
LEAD: the head for the pre-flight review and trial is now **ai/war c7eed909** (261d5da8 + this). CI to follow.

**Read, Persia 15A7D14F (ab-f939c50, logs now in; 9:29am ET).** This corrects the "73-turn BUILDUP".
- **States.** PREP T1, BUILDUP T56 (city-state target Wellington, 7 tiles, unwalled, no siege asked), then **OVER at
  T70, "a major declared war on us first"** (Germany and Ethiopia, T69). The war at T129 came long after the strike had
  ended.
- **BUILDUP, T56-T70 (14 turns).** The army went 5 -> 6 land by T58 and stayed at 6 of the plan's 8 until T70 (4
  Immortals, 1 Composite Bowman (upgraded at T59), 1 Warrior), with 375-420 gold idle.
- **Production in that window: every city was on the plan's army** ("STRIKE LIST - the army (short of the plan):
  Immortal/Archer" in Susa and Pasargadae; the capital finished its 11-item list at T57). The young cities simply took
  many turns per unit. So the army was **production-bound**, not blocked by a rule. Gold can't buy core or melee under
  WarmongerHurry (the user's rule).
- **After the OVER (T70-T129):** 16 buildings and 3 wonders. That's the leak Economy's 0044 closes (the bans hold until
  our first declaration).

What fixes it on the next tags:
- **103bd11d:** war on us no longer ends the strike. It would have stayed in BUILDUP and waited for home safety.
- **27476943:** the declaration waits until the army on hand can take Wellington. Six units may already have been
  enough for a city-state; the "Strike: not ready" line will say so.

This build had none of the new log lines (f939c50 predates b281f681).

LEAD (9:29am): reading only. Persia's BUILDUP was 14 turns (T56-70), not 73. It was production-bound at 6 of 8 (young
cities, gold not usable for units), then ended by war on us at T70. Both are addressed on ai/war: 103bd11d (war on us not
an exit) and 27476943 (declare when the army on hand can take the city). The wonders came after the OVER (Economy 0044).

**Persia's 73-turn BUILDUP (the lead; bullygreedy21 15A7D14F, ab-f939c50; logs not pushed yet, so this is from the
code):** city-state targets only. BUILDUP opened at T56 against Wellington; no declaration until a war on Ethiopia at
T129 with 7 land units.
- **What most likely held it.** On f939c50 the walled rule gave an early strike a 2-siege target, and the plan wanted 9
  others. With 7 land and no siege trainable (no Mathematics on its list), neither the normal army nor Personality's
  plan army could count as built. "As ready as it gets" needs the affordable count at 0, which an income-supported army
  rarely hits. So the city-state approach (WAR only once ready) never came.
- **Fixes, ai/war b281f681:**
  1. **Declare on the city-state.** A city-state strike target is declared on directly (DeclareWar) once the army is
     ready or as ready as it gets.
  2. **Untrainable siege doesn't block.** A siege target we can't train yet doesn't hold "built".
  3. **"Strike: not ready (...)"** is logged in BUILDUP whenever the blockers change: normal army field and siege, plan
     army core and support lines, upgrade tech and bill, gold, melee, affordable. The next long BUILDUP reports its own
     game-state cause.
  - With the strength check, the 2-siege target only appears when the plan's army is too weak for the city.

LEAD (8:53am): (1) a city-state strike target is declared on when the army is ready (b281f681). (2) Persia's long BUILDUP
was most likely an unreachable 2-siege target (the old walled rule, no Mathematics) with 7 of 9 land. Fixed by the
strength check plus "untrainable siege doesn't block". The new "Strike: not ready" line will name the blocker in the
next games. CI to follow on b281f681.

**The short army (the user: "if they were 4 units short, they need to fix their start"; 6:14am ET).** Production, not purchases.
Economy changes the book; War's part is the build-up's unit requests.

expert_block.py now prints units on hand against the plan at BUILDUP and WAR, and the capital's and second city's
production by kind. The expert block (40203a3):

| game | civ | BUILDUP: land, core / support vs plan | WAR: land, core / support vs plan | capital + 2nd city before BUILDUP |
|---|---|---|---|---|
| 13E9ECC9 | Persia | T40: 3 land, Spearman 2/5, Archer 0/3 | T81: 16 land, 5/5, 5/3 | Building 4, Military 4, Settler 1, Worker 1 |
| 1464B588 | Greece | T36: 2 land, Spearman 1/3, Archer 0/5 | T63: 7 land, 3/3, 3/5 | Building 2, Military 3, Settler 1, Worker 1 |
| 14A46460 | Persia | T26: 1 land, Spearman 0/5, Archer 0/3 | T83: 16 land, 5/5, 4/3 | Building 2, Settler 1, Worker 1 |

- **Little built before BUILDUP.** In the three real strikes, before BUILDUP opened, the two cities produced 2-4
  buildings and 0-4 military; that's Economy's book, being changed.
- **Production while the window was open.** From BUILDUP to WAR they still built 2-5 buildings, 0-4 civilians and 1-2
  wonders alongside 5-14 military.
- **The window asked for the wrong army.** It asked for 12 field units (WarBudget's affordable army), not the plan's 8.

**Hypothesis 6, coded (ai/war bdcfff59):**
- An EarlyStrike build-up's field target is the plan's core + support (at least 3 melee).
- The core and support production weights (core to its count, +4500; support to its count, +3500) apply to both
  strikes; they were LateStrike's only.
- Expect the window's army to fill toward the plan's 8 rather than 12, and BUILDUP-to-WAR production to go to the plan's
  classes first.

LEAD (6:14am): War's part of the short army is coded on ai/war bdcfff59: the strike build-up asks for the plan's army (field
target = core + support; core and support weights for EarlyStrike too). expert_block.py reports units vs the plan at
BUILDUP and WAR, and production by kind, for ab-8f9b7f9's games. CI to follow.

**Economy's half, on ai/war:** 0037 (82159d7e; the book's "units first" counts a city-state city within 8 tiles) and 0038
(6df9a4d2; CvPlayer::IsEarlyStrikeArmyShort: before the strike, while the core or support count is under the plan's, the
capital's fill-in and other cities train the plan's army, no buildings unless in danger, one worker). Both applied cleanly
on bdcfff59. The two halves count the same plan classes. ai/war head 6df9a4d2.

LEAD: ai/war 6df9a4d2 = the city-state strike target (1b29b33d), the build-up's plan-army requests (bdcfff59) and Economy
0037/0038. CI to follow.

**PC 1's STOP on ab-8f9b7f9 (bullyabort19 game 1, 1468D9F4, "wonder/gift before strike"), War's read (6:29am ET):**
- **The strike stalled.** Japan (LateStrike; Samurai at Steel; pre-build Swordsman x7) was in PREP from T1 to T149.
  Personality's economy-ready for a late strike needs half the upgrade bill saved (350 gold). Japan gave 1250 gold to
  city-states (T44, T99) and built the Great Library (T50) and the Hanging Gardens (T90).
- **Economy's blocks don't reach it.** 0035 (no wonders) and 0036 (no gifts) cover LateStrike only in BUILDUP
  (IsLateStrikeSaving). Asked Economy to extend both to LateStrike's PREP.
- **A war outside the strike.** Japan declared on Spain at T102 through CP's own war approach (Spain a weak neighbour),
  while the strike stayed in PREP. BUILDUP then came at T149, mid-war.
  - **Fix, ai/war a819f3d3:** a war we declare in PREP pre-empts the strike. It goes OVER ("we declared a war outside
    the strike, before its build-up"), and the book, the city cap and the saving end with it.

LEAD (6:29am): PC 1's STOP is an Economy coverage gap: 0035/0036 block wonders and gifts for LateStrike only in BUILDUP,
and Japan was in PREP for 148 turns (its gifts also kept it from economy-ready). Asked Economy to cover LateStrike's
PREP. War: a war of our own in PREP now ends the strike (a819f3d3). ab-8f9b7f9 isn't broken in War's code. CI to follow
for the ai/war head.

**Read 5 (3:28am ET): 8 logged first games**, all PC 2. PC 1's bullyabort18 still hasn't pushed.

| civ | games | captured | cities | 1st capture T | decl T | BarbKills | promoted / land at decl | exits |
|---|---|---|---|---|---|---|---|---|
| China | 1 | 1 | 1 | 59 | 57 | 5 | 1 / 11 | captured |
| Persia | 2 | 1 | 1 | 87 | 119, 81 | 10, 1 | 10 / 16, 12 / 16 | no capture 1, captured 1 |
| Greece | 1 | 0 | 0 | - | 63 | 1 | 0 / 7 | no capture (upgrades held, 500 gold gifted) |
| Polynesia | 1 | 0 | 0 | - | 140 | 1 | - | void (Warmonger 0) |
| Maya | 1 | 0 | 0 | - | never | 1 | - | void (Warmonger 0) |
| Celts | 1 | 0 | 0 | - | never | 11 | - | void (Warmonger 0) |
| Inca | 1 | 0 | 0 | - | never | 2 | - | void (Warmonger 0) |

2 of 8 captured, and **4 of 8 are void**: Inca (144733A5) is a fourth non-warmonger picked by EarlyStrikeAggressor.
- Of the 4 real games, 2 captured (China T59, Persia T87). Neither capture came from an EarlyStrike build-up.
- Both strike build-ups (Persia T40, Greece T36) opened with 2-3 land units and never reached the army.
- Melee in reach at the first capture attempts: 0 melee took 0 of 3; 2+ melee took 2 of 4.

**Economy's note (3:31am): WarmongerHurry refuses gold purchases of core and melee units for a candidate warmonger**
(CvEconomicAI::IsGoldPurchaseAllowed: only settlers and siege). NoObsoleteHurry blocks warrior-class units for every
major. Both are the user's hard rules.
- So bb2fa51c's build-up purchase can only buy siege. For a plan without siege it buys nothing, and the gold above the
  bill waits for the upgrades.
- It's harmless, but it's not the lever read 3 hoped for. Economy has put the question (exempt strike build-ups?) to the
  user through the lead.
- Economy's 0036 (no city-state gold gifts in a strike's PREP and BUILDUP) is done.

LEAD (3:28am): reading only. 2 of 8 captured; 4 of 8 void (EarlyStrikeAggressor picked non-warmongers: Polynesia, Maya,
Celts, Inca). Again: drop EarlyStrikeAggressor from PC 2's RoleFixes for the rest of the night. The user's question
(through you, from Economy): may a strike's build-up buy core or melee units with the gold above its upgrade bill,
despite WarmongerHurry and NoObsoleteHurry? Without that, an early strike's army is production-bound: 2-3 units at the
open, 7 of 12 by T50.
- Expert block pair 1: China (no EarlyStrike civ in the game) captured 1 at T59. BarbKill works (44 lines).
- **ai/next b2a6f75 lacks War's readiness wiring.** The wiring is ai/war 74ae9fd9 (CvMilitaryAI.cpp only, on top of
  the same three parts). Without it, the late strike's PREP to BUILDUP is still War's placeholder ("K cities, book
  done"), and Personality's IsStrikeEconomyReady, IsStrikeArmyReady and plan exits go unused.
- Cherry-pick 74ae9fd9 onto ai/next; ai/next and ai/war differ only in that commit. CI on 74ae9fd9 is running.

### War: the read for the expert block (ab-40203a3, bullyabort18 + bullygreedy18), prepared (Nov 5, about 10:35pm ET)
`tools/ab/expert_block.py [runs]` (default bullyabort18 bullygreedy18), run from a results worktree with walls.py and
attack_funnel.py beside it. It was tested on the package block (bullygreedy16 + bullyabort14), where it gives the old
numbers.

**Per civ (captures are the measure):**
- games, games with a capture, cities;
- the first capture turn (CitySpecializationLog);
- the declaration turn (the army line, or the CSV);
- barbarian kills before the window (BarbKill);
- promoted units over land units at the declaration (the army line);
- exits.

**Then, over the block:**
- **Exits:** captured / no capture (war, nothing taken) / fell back (an EarlyStrike build-up, no war by the plan's
  fallback turn) / no strike.
- **The build-ups** ("EarlyStrike: build-up opens"): turn, and walled targets.
- **Upgrade and go:** gold per unit against the research's 70 to 80.
- **Barbarian hunting before the window:** BarbHunt lines, BarbKill kills and their XP against the cap of 45.
- **Promotions at the declaration.**
- **Melee in reach at each first capture attempt (0 / 1 / 2+)**, against the city being taken.
- **Per game:** the plan's open, declare-by and fallback turns, from Personality's "strike plan" line in
  StrategyProfile_Log.

**Logging note.** The army line was written only under BigArmy or WarBudget. If this block's RoleFixes lacks WarBudget,
promotions and melee in reach will be missing. ai/war 8a56aad1 (logging only, on 40203a3) writes it for every EarlyStrike
civ ("EarlyStrike: army ...").

LEAD: the expert block's read is ready (tools/ab/expert_block.py). If RoleFixes lacks WarBudget, take ai/war 8a56aad1
(army line for EarlyStrike civs, logging only) into the next build. CI to follow.

### War: the expert strike, coded under EarlyStrike (ai/war c87e8a29, d0fbd91f, 94e55acf) (Nov 5, about 10:10pm ET)
The user, via the lead (9:58pm ET): "no, we dont need a baseline. use the experts ideas right away and we will know if
they are good by if they take cities." All under FIX_EARLY_STRIKE, no new flag. It reads Personality's per-civ plan
(CvGrandStrategyAI::GetStrikeWindow(CvStrikeWindow&)): core class and share, open, declare-by and close turns, the upgrade
tech. Built for the Huns, Aztec, Inca, Greece and Celts first, and it works for any civ whose plan says military first.

| Expert point | Code |
|---|---|
| Army: the core unit plus support; 5-7 Composite Bowmen plus melee for CB civs | the core class first up to Personality's iCoreSharePercent of the field target (50%, 33% for a siege core), the rest support (c87e8a29) |
| At least 2 melee at the capture | the strike's ready test wants 3 melee units that can take a city (2 at the city, 1 spare); melee get +5000 in the window until there are 3 (c87e8a29) |
| Gold: 70-80 per unit saved; upgrade and go when the upgrade tech lands | the bill includes units whose upgrade is the strike's own tech (eUpgradeTech) at any distance, saved from the start of the build-up; upgrades are held until the army is built; the declaration waits for the bill (c87e8a29, on e7572b43/cc979539). The price is CP's own per unit |
| Target: a flat, unwalled city; a walled hill city means another target or the fallback | until the close turn, a target civ whose nearest city is walled and on a hill is skipped; walled or hill ranks below every flat, unwalled one (d0fbd91f, CvDiplomacyAI::GetNewAIConquestTarget) |
| Barbarian hunting before the window | spike units (core class), half health or better, under the 45 barbarian XP cap, not needed garrisons, go after visible barbarian units within 8 tiles of our cities until the build-up opens (94e55acf, CvTacticalAI::PlotEarlyStrikeBarbHuntMoves) |
| Exit: the late plan by Personality's turn X | the strike's build-up is one opened by iCloseTurn; the window ends at iDeclareByTurn; past the close turn the target and hunt rules are off and the normal TimingBuildup (siege) runs (c87e8a29, d0fbd91f) |

Not done:
- the Huns' Horse Archers + Battering Rams pairing as such. The core class and share come from Personality's plan; a
  siege core gets 33%. If Personality's per-civ fields name a second class, War can weight it next.
- a capture-time rule that waits for 2 melee in reach (the army has 3).

**Logs to read in the block:** "EarlyStrike: build-up opens", "EarlyStrike: upgrade and go", "BarbHunt:", "BarbKill:"
(728495a5), the army line's promotions (8c361db) and in-reach list. The checks in the entry below still apply.

**Judged by captures** (the user's measure), per civ, against the earlier blocks for the same civs. Also: declaration
turn, promotions at the declaration, barbarian kills and own losses before the window.

LEAD: the expert strike is on ai/war 94e55acf (three commits on db638c3 + BarbKill logging), all under EarlyStrike. CI
to follow; merge once green.

CI:
- the BarbKill logging 728495a5 is green (run 271);
- the three expert-strike pieces at 94e55acf are green (run 275);
- 10b87a45 (Economy 0031 applied as 0bc12aa4, and the core from Economy's plan; the Huns lead with Horse Archers) was
  still building at 10:16pm ET (run 276).

### War: checks for the first EarlyStrike block, from the strike-plans research (Nov 5, about 10:00pm ET)
The lead, from tools/ab/STRIKE_PLANS_RESEARCH.md (8f04839). No new code before the block's results; these are what to
read in it.

**1. Two melee units at the city ("bring two in case one dies").**
- Over the 57 logged first capture attempts with an in-reach list (BigArmy and WarBudget army lines), capture-capable
  melee in reach (infantry and mounted melee, not ranged or siege) against the city being taken later by a CAPTURED
  attempt:
  - 0 melee: 1 of 15;
  - 1 melee: 2 of 18;
  - 2 or more: 5 of 24.
  - Small numbers, same direction as the research.
- The Inca game the lead named (12E9456A, bullygreedy16) wasn't an early strike. Its first window (T55) passed without a
  war; it declared at T119 with 17 land units, 8 of them melee (Spearman 4, Swordsman 3, Warrior 1). But in reach at
  the first attempts:
  - Warsaw: 1 Spearman, 3 Composite Bowmen, a Catapult;
  - Krakow: 2 Composite Bowmen and no melee.
  - Krakow (unwalled, no garrison) fell at T126 to a later attempt.
- **Check in the block:** melee in reach at each first capture attempt (the army line's in-reach list), and captures by
  that count.
- EarlyStrike's army has no melee minimum: the core class is half the field target, but for a ranged spike (the Inca's
  Slinger) that core is ranged.
- If captures go with 2+ melee in the block too, a follow-up would make the capture plan wait for 2 melee in reach, or
  set a melee floor in the army, for ranged-spike civs especially.

**2. The gold reserve for the Archer to Composite Bowman upgrade (research: 70 to 80 gold each).**
- EarlyStrike's bill is CP's own upgradePrice per unit (exact, not an estimate), summed over the units waiting.
- In 12E9456A the Inca upgraded 2 Slingers at T70 and the treasury fell from 220 to 117 (with -7 a turn): about 50 each.
- **Check in the block:** the "EarlyStrike: upgrade and go, N units to upgrade for G gold" line gives G / N per game,
  against 70 to 80, and whether the declaration waited for it.

**3. Target choice: a flat, unwalled city ("a walled hill city without siege is sometimes impossible").**
- EarlyStrike checks walls only: no siege when the target's city nearest our capital has no walls. Hills aren't
  checked, and the target civ is chosen first (CP's and the timing attack's target), not the city.
- **Check in the block:**
  - for each EarlyStrike war, the first attacked city: walled or not (the attempt line's walls +W), and on a hill or not
    (needs the plot, from the attempt's coordinates in the logs);
  - captures by those two.
- If walled or hill cities hold, the exit condition would be: strike only a target whose nearest city is flat and
  unwalled; otherwise fall back to the normal build-up with siege.

LEAD: three checks for the EarlyStrike block's read, no code:
- melee in reach at the first attempt (0: 1/15, 1: 2/18, 2+: 5/24 so far);
- gold per upgrade against 70 to 80 (the bill is CP's own price);
- walled and hill targets.
The Inca game wasn't an early strike, and at Krakow it had no melee in reach.

### War: BarbHunt, a proposal: early-spike units hunt barbarians for promotions before the strike (Nov 5, about 9:45pm ET)
The user asked for the kill logging and a written plan. Not coded: the lead holds hunt code until the EarlyStrike block
(ab-db638c3) gives the baseline.

**Why.** The user's Aztec "pushed out 3 quick jaguars and went barb hunting", with Honor ("honor instead of liberty
because of the barb hunting"). The Jaguars struck at T54 Quick as veterans (+33% ranged defence). Ours, before the
window (35 early-spike aggressor games, entry below):
- 48 military unit-turns exploring and 12 garrison moves;
- 13 camp attempts, but 0.8 opportunity attacks a game;
- 0.1 own units lost.

They don't fight, so they don't earn XP. A camp taken empty gives gold, not XP.

**What the code already does:**
- Visible barbarian units are tactical targets (AI_TACTICAL_TARGET_ENEMY_COMBAT_UNIT, CvTacticalAI target list), but
  only units already nearby attack them.
- CvTacticalAI::PlotGrabGoodyMoves sends up to 3 units at camps within 11 tiles at peace (6 at war), occupied or not.
- The first military units are homeland explorers or garrisons, so nothing sends them toward barbarians.
- Vox Populi caps barbarian XP at 45 (BARBARIAN_MAX_XP_VALUE): past that, hunting earns nothing.
- Economy's 0030 opens Honor under EarlyStrike (bonus against barbarians, culture from kills).

**The proposal (one flag, BarbHunt; or inside EarlyStrike if the lead prefers, since it serves the same strike).**
- **Who:** an EarlyStrike civ's spike units (the core class) beyond one garrison per city, before the strike.
  - "Before the strike" is CvPlayer::IsEarlyStrikeSmallEmpire: not at war with a major, before T90 Standard.
  - Not the support units (archers) or the garrisons.
- **What:**
  1. A homeland move for those units: go toward the nearest visible barbarian unit or occupied camp within 8 tiles of
     one of our cities, instead of exploring. Tactical then attacks it on arrival, as for any visible enemy unit.
  2. In PlotGrabGoodyMoves, for those units, camps with a guard count as targets at the same range.
- **When to stop (the strike must not slip):**
  - A unit at the barbarian XP cap (45 in VP) stops hunting and garrisons or musters.
  - Every hunter stops when the build-up opens. CvMilitaryAI::IsTimingBuildupArmyBuilt etc. take over, and hunters go to
    the muster and heal.
- **Safety:**
  - Attack only when the tactical sim expects to win without dropping below half health.
  - A hunter below half health heals in our territory before hunting again.
  - No hunting more than 8 tiles from our cities.
- **Logs:** the BarbKill line (below), plus a "BarbHunt: <unit> heads for <target> at (x:y)" line.

**How it's judged (EarlyStrike games, BarbHunt on against off, read per civ):**

| Measure | Now | Confirm | Kill |
|---|---|---|---|
| Promotions per land unit at the declaration (army line, 8c361db) | baseline from ab-db638c3 | clearly up (at least +1 promoted unit in 4) | no change |
| Barbarian kills before the window (BarbKill) | baseline from the next build | up | no change |
| Own units lost before the window | 0.1 a game | at most 0.5 a game | above 1 a game |
| Declaration turn | EarlyStrike's | no later | 5+ turns later |
| Captures per civ | the EarlyStrike block's | up | down |

**Logging added now (ai/war 728495a5, logging only):** CvUnitCombat::ApplyPostKillTraitEffects, every kill path, writes
"BarbKill: <winner> killed a barbarian <unit> at (x:y)[, a camp's guard]; level L, XP X" in the winner's tactical log.
`tools/ab/prewindow_units.py` counts kills before the window (and kills by units already promoted).

LEAD: BarbKill logging is on ai/war 728495a5 (logging only, on ab-c1 db638c3) for the next build. The BarbHunt proposal
above waits for the EarlyStrike block's baseline (promotions at the declaration), then one flag. Say go when the
baseline is in.

### War: what an early-spike aggressor's units do before the window (barbarian hunting?) (Nov 5, about 9:25pm ET)
The user (via the lead): "i pushed out 3 quick jaguars and went barb hunting". The Jaguars had +33% ranged defence by
the strike. Counted over logged bully first games, from the game's start to the first "window opens" turn (homeland
and tactical logs). Script: `tools/ab/prewindow_units.py`.

| Before the window (median a game; games with any) | Early-spike aggressors (35) | Other aggressors (65) |
|---|---|---|
| Window opens | T45 | T43 |
| Military unit-turns exploring (not Scouts) | 48 (35) | 46 (65) |
| Garrison moves | 12 (35) | 12 (63) |
| Barbarian camp attempts ("Trying to remove barbarian camp") | 13 (28) | 12 (56) |
| Opportunity attacks | 0 (12; mean 0.8) | 0 (27; mean 0.8) |
| Own units killed | 0 (2) | 0 (8) |

**Read:**
- They don't sit fortified, but they don't hunt either. The first military units spend the build-up exploring (CP sends
  the starting Warrior or UU out as an explorer) and garrisoning.
- They go after camps (CP's PlotGrabGoodyMoves sends units at camps within 11 tiles at peace), but they almost never
  attack: under one opportunity attack a game before the window. A camp taken empty gives gold, not experience.
- So little XP, unlike the user's veteran Jaguars. The promotions logging on ab-70f901e (8c361db) will show it on the army
  line at the declaration.

**Is a "hunt barbarians in the build-up" gate cheap? Yes, as one gate under EarlyStrike, in two places:**
1. CvTacticalAI::PlotGrabGoodyMoves (camps): for an EarlyStrike civ before its strike, a longer reach and more units on
   occupied camps. It is already a loop with a range (11) and a unit count (3).
2. Barbarian units near our land as targets for the units not garrisoning: a priority raise for barbarian unit targets
   in the tactical target list, when not at war with a major.
- Both are a few lines behind IsEarlyStrikeCiv and IsEarlyStrikeSmallEmpire. Risk: units lost to barbarians, measured
  by own units killed before the window, now 0 to 0.1 a game.
- Not coded (the lead: harness unchanged today). The first ab-70f901e games give the baseline promotions at the
  declaration.

LEAD: reading. Early units explore and garrison and go after camps but rarely fight (0.8 opportunity attacks a game
before the window), so little XP. A barbarian-hunt gate under EarlyStrike is cheap (camps and barbarian unit targets in
CvTacticalAI), not coded; the promotions on the new army line give the baseline first.

### War: who qualifies for EarlyStrike, and a harness option to make it the aggressor (Nov 5, about 9:15pm ET)
The lead: bully mode picks the most aggressive personality as aggressor. If few civs qualify for EarlyStrike, the block
won't exercise it.
- **Who qualifies** (CvPlayer::IsEarlyStrikeBook: a candidate warmonger with Personality's bMilitaryFirst, a spike by T30
  Standard; Personality's draft table, to be checked against StrategyProfile_Log on ab-c337c77): the Aztec, Polynesia,
  Babylon, Inca, Maya, Greece, Persia, Celts, Huns, Egypt and India.
- **How often it was the bully aggressor** (147 logged bully first games, all runs): 48 (33%): Huns 18, Aztec 14, Inca 6,
  Greece 6, Celts 5.
  - The most frequent aggressors otherwise: the Mongols 17, Songhai 15, Assyria 12, Japan 11, Denmark 10.
  - A 20-pair block would exercise EarlyStrike in about 7.
  - 142 of the 147 games had a qualifying civ among their 8 majors.
- **Option (ai/war 70f901e9, harness): EarlyStrikeAggressor in RoleFixes.**
  - Bully mode then scores an early-spike civ above every other for the aggressor role: early spike first, then
    warmongers, then offense flavor.
  - It reads the strategy profile (game data), so both games of a pair agree.
  - Without the bit, nothing changes.
  - Caveat: it changes who the aggressor is, so read EarlyStrike per civ, or against the same civs.

LEAD: about a third of bully aggressors qualify for EarlyStrike (48 of 147). Add EarlyStrikeAggressor to RoleFixes and
about 97% of games get a qualifying aggressor (ai/war 70f901e9, on ab-c1 c337c77). CI to follow.

CI: 70f901e9 green on ai/war (run 267) and claude/ab-c1 (run 268). Earlier, cc979539 (run 265), e7572b43 (run 264) and
c337c77 (run 266) were green. db638c3 (Economy 0030 on top, the build both PCs run) is green too (run 269, 9:31pm ET).

### War: EarlyStrike, upgrade and go (ai/war e7572b43) (Nov 5, about 9:00pm ET)
The user, relayed by the lead: "i upgraded 3 archers to composite archers. that was part of the timing attack. upgrade
and go", and "i beelined to construction". The treasury fell from 263 at T40 to 31 at T50 (Quick): saved for the
upgrades, spent just before the declaration.

**The lead's checks, as the code stood:**
- (a) Gold reserved for the upgrades, and the declaration waiting for them? No.
  - CP saves for an upgrade only once its tech is known (CvHomelandAI::PlotUpgradeMoves).
  - Nothing waited for the upgrades.
  - The window spent spare gold on one unit purchase a turn.
- (b) ArmyQuality never scraps. It refuses to build Archers once Composite Bowmen are trainable and doesn't count them
  as army, which is right while they wait. ArmyScrap (window only, since dc4290cf) could drop an Archer waiting for its
  upgrade.
- (c) WarmongerHurry limits purchases only; upgrades aren't purchases. CvUnit::CanUpgradeTo checks gold >= price, not
  reserves, so gold saved in any bucket is there for the upgrade.

**Change (under FIX_EARLY_STRIKE, in a strike's build-up):**
- The upgrade bill counts our land units at home whose upgrade tech is known, or is the current research with 8 or
  fewer turns (Standard) left.
- The window saves that bill (plus siege gold only if siege is wanted).
- The window's unit purchase waits while the bill is unpaid.
- The ready test waits for the upgrades before the declaration, bounded by WindowUntilReady.
- Log: "EarlyStrike: upgrade and go, N units to upgrade for G gold (gold H)".
- Under FIX_ARMY_SCRAP: no unit that can upgrade now, or whose upgrade's tech is being researched.

**Not here:**
- The Construction beeline is Economy's research list. Suggested: Construction right after Archery under EarlyStrike.
- With WarChest on, the window's savings are Economy's.
- Personality's calibrated window (open T40, declare by T50 Quick, bed8e14) isn't read by War's code yet. EarlyStrike's
  build-up opens at T27 Quick and declares when ready (now including the upgrades), at the latest about T47.
  - If blocks show it declaring before the book's army and Construction, wiring Personality's open turn in is the next
    step.

LEAD: upgrade and go is in EarlyStrike (ai/war e7572b43, on ab-c1 ec78b0d): gold saved for the upgrades, the declaration
waits for them, ArmyScrap spares units about to upgrade, and WarmongerHurry doesn't touch upgrades. Economy: Construction
after Archery in the EarlyStrike research list. CI to follow.

**Then (ai/war cc979539): upgrades are held until the army is built.**
- Economy's patch 0029 keeps the treasury until the strike: no hurries, WarChest purchases or tile buys, and Construction
  after the support tech in research.
- CP upgrades whenever it can pay, so the reserve would have gone on early Warrior to Spearman upgrades. Now an
  EarlyStrike civ in its small-empire phase holds every AI upgrade (CvUnit::CanUpgradeRightNow) until the strike's army
  is built or its window is over.
- Then it upgrades, the bill reaches 0, and it declares.
- At war, or past T90 Standard, CP upgrades as usual.

LEAD: cc979539 holds an EarlyStrike civ's upgrades until its army is built, then upgrade and go. Economy's ask is done on
War's side.

### War: EarlyStrike, War's half (coded, ai/war 95fbcc26, off) (Nov 5, about 9:10pm ET)

**Revised the same evening (ai/war 6c073d69, on Economy's book, patch 0028 applied as 73af5241): one flag, Economy's
API, the build-up at the normal turn 40.**
- Economy's book half (CvPlayer::IsEarlyStrikeBook, GetEarlyStrikeCoreClass, IsEarlyStrikeSmallEmpire) defines the
  same flag. War's half now keys on IsEarlyStrikeBook (a warmonger with Personality's bMilitaryFirst, on a book) and the
  core class.
- The build-up no longer opens in Personality's strike window. Economy's point: the Aztec window (T3 to 23 Quick) ends
  before the book's army can exist. It opens at the normal turn 40 (Standard; T27 Quick) with the book's army already
  built. It declares when the army is ready, at the latest about T47 Quick.
- In a strike's build-up (opened by turn 60 Standard):
  - no siege against an unwalled nearest target city;
  - 8+ field units;
  - the core class first until half the field target.
- The text below describes the first version; where they differ, this paragraph holds.
The lead's go: "every civ builds to its strengths". It uses Personality's per-civ strike window, which is already in
ab-c1 (CvGrandStrategyAI::GetStrikeWindow / IsInStrikeWindow, the profile's eSpikeUnit), not a stand-in gate.

**Hypothesis.** Wars declared earlier take more cities, unwalled cities fall twice as often, siege at the declaration
predicts nothing, and early capital military goes with captures (entries below). A civ whose power spike comes early
should strike in its spike's window, with the spike unit as the army's core and no siege against an unwalled city.

**What it does (FIX_EARLY_STRIKE), for a timing attacker whose strike window starts before turn 40 (Standard):**
- The build-up window opens in the strike window instead of at turn 40 (CvDiplomacyAI::GetNewAIConquestTarget; the
  target is still chosen from turn 25). Civs with a later spike keep the normal timing.
- In a build-up opened in the strike window:
  - no siege target when the target's city nearest our capital has no walls;
  - at least 8 field units (the user's strike had about 10, from 2 cities);
  - the spike unit gets +4500 in the window (above siege +4000 and the others +3000) until it makes up half the field
    target.
- Log: "EarlyStrike: build-up opens in the strike window (Ta-b), spike unit X, target's nearest city unwalled (no
  siege) / walled".
- The opening (UU first, a small empire) is Economy's EarlyStrike book; test the two together.

**Confirm:**
- EarlyStrike civs declare by about T60 (Quick), against our median of T80+;
- they capture in more than the package block's rate, and at least BigArmy's 8 of 20 for those civs;
- the army at the declaration is mostly the spike unit, with promotions logged.

**Kill:**
- captures below the package block for the EarlyStrike civs;
- or the strike is spent and the civ falls behind by T100 (cities, science) with nothing taken.

**Note for Personality.** The Aztec window ends at T23 Quick ((0 + 35) x 0.67), while the user struck at T54 Quick.
EarlyStrike uses the window only to open the build-up (which then runs its normal 10 to 20 Quick turns, so a declaration
around T30 to T40 Quick). If the user's T54 is the better reference, a later window end, or a later start for spikes
that need no tech, would move it.

LEAD: EarlyStrike's War half is on ai/war 95fbcc26 (off), for a block after the package, with Economy's book. CI to
follow.

**Interface agreed with Personality (as built).** EarlyStrike sits on claude/ab-c1 ce7a93c and reads Personality's
accessors as they are: CvGrandStrategyAI::GetStrikeWindow (start and end turns), IsInStrikeWindow (spike tech known) and
the profile's eSpikeUnit. They are on CvGrandStrategyAI, not CvPlayer.
- They cover what War needs: spike tech, spike unit, open turn and window end.
- War keeps two things on its own side, so the profile needs no additions:
  - the core share (the spike unit first until half the field target);
  - "siege only if walled" (the target's nearest city, checked at the build-up).
- The window end isn't used as a declare-by: the build-up runs its normal length.
- One open point for Personality: the window ends for spikes that need no tech (the Aztec: T3 to T23 Quick, against the
  user's strike at T54 Quick).

LEAD: no profile additions needed for EarlyStrike; it reads Personality's accessors as merged in ce7a93c. Open point for
Personality: early windows end very early (Aztec T23 Quick vs the user's T54).

### War: the unique unit at the declaration, and the strike-window interface for Personality (Nov 5, about 8:55pm ET)
The lead (refining, from the user: "every civ needs to build to its strengths"): Personality drafts each civ's power
spike, opening and strike window; TimingBuildup takes the window from the profile and builds the army from the civ's
strong units. One more cut first: captures by whether the aggressor's unique unit was available at the declaration.
Script: `tools/ab/uu_at_declaration.py`.
- A unique unit is a unit only one civ ever lists as buildable in the production logs, for example Jaguar, Impi,
  Keshik, Horse Archer, Battering Ram, Slinger (Inca), Hwach'a.
- "Available" means the UU was in the capital's buildable list by the first-war CSV sample.

| 100 aggressor first games at war, with logs | Games | With a capture |
|---|---|---|
| UU buildable by the first declaration | 62 | 10 (16%) |
| UU not yet buildable | 38 | 5 (13%) |
| UU in the army at the declaration (games with the army line) | 14 | 4 |
| No UU in that army | 12 | 4 |

- **No difference: availability alone isn't the lever.** Our declaration comes a median of 29 turns after the UU becomes
  buildable, and the army is whatever CP built, often without it.
- Only 9 games declared within 20 turns of the UU (1 captured), so the user's pattern (strike at the spike, with the UU
  as the core) is untested in our games, not refuted. That is the case for a per-civ strike window: we have never really
  tried it.

**Interface proposal for Personality (War's side reads it; Personality owns the data):**
- `CvPlayer::GetStrikeWindow()` returns a small struct, or empty when the civ has no strike window:
  - `eSpikeTech`: the tech that unlocks the spike unit (the UU or the civ's power unit);
  - `iOpenTurn` / `iDeclareBy`: Standard-speed turns, scaled by game speed on War's side. The window opens at the later
    of iOpenTurn and eSpikeTech known; War declares by iDeclareBy if the army is at its target, else at the window's
    end as now;
  - `eCoreUnitClass` (and optionally a second, e.g. the ranged support): the classes the window builds first;
  - `iCoreShare`: the share of the field target they should make up (e.g. 60%);
  - `bSiegeOnlyIfWalled`: siege is required only when the target has walls (the early-strike finding: unwalled cities
    fall twice as often, and siege at the declaration predicts nothing).
- **War's half, behind one flag (StrikeWindow), when the profile returns a window:**
  - TimingBuildup takes the window's turns from the profile instead of its single timing;
  - the window weights eCoreUnitClass first (the window's +3000 goes to the core class until its share is met);
  - the siege half of the ready test is waived when bSiegeOnlyIfWalled and the target city has no walls;
  - the target choice prefers an unwalled city of the nearest weak major.
  - It logs the window, the core share and the promotions (8c361db1) at the declaration.
- The opening that feeds it (UU first, as the user's Jaguar opening) is the book's: Economy and Personality.

LEAD: reading plus an interface proposal. The UU being available at the declaration makes no difference (16% vs 13%),
because we declare a median of 29 turns after it and often without it in the army. The spike strike is untested, not
refuted. Personality: the interface above is what War would read (GetStrikeWindow: spike tech, open/declare turns, core
unit class and share, siege only if walled); change it as you like. I'll code War's half behind StrikeWindow once the
accessor exists.

### War: our aggressors' capital opening through T50, against the user's (Nov 5, about 8:45pm ET)
The user's reference (106F8550, the Aztec): the capital built Jaguar, Jaguar, Jaguar, Worker, Settler, Archer x4, Jaguar,
Jaguar. That is 9 military, 1 settler, 1 worker and no buildings by about T50, in 2 cities (the second built no units).
Marrakesh fell at T54. Ours, from the opening book's "Started" lines (CitySpecializationLog) and CP's choices after it
(CityStrategyAIProductionLog): 69 aggressor first games with a complete book log. Script: `tools/ab/capital_opening.py`.

| Capital, through T50 | The user | Ours (median, range) |
|---|---|---|
| Military units started | 9 | 2 (1 to 9) |
| Settlers | 1 | 2 (1 to 6); first at T16 |
| Buildings | 0 | 3 (0 to 5): Shrine, Monument, Granary |
| Workers / Scouts | 1 / 0 | 1 / 1 |
| Military before the first settler | 3 | 1 (the book's Warrior or UU) |
| Cities at T50 | 2 | 2 (1 to 4) |

- **Our opening is economic.** The book's typical line is Scout, Warrior, Worker, Settler, Shrine, Settler, Monument, and
  military starts after T30 when CP's own choices take over. The city count at T50 is the same as the user's; the
  difference is what the capital builds.
- **More early military, more captures** (capital military by T50, games with a capture):
  - 0 to 2: 2 of 44 (5%);
  - 3 to 4: 2 of 15 (13%);
  - 5 to 7: 2 of 7;
  - 8+: 1 of 3.
  - 5 of 25 (20%) with 3 or more, against 2 of 44 with fewer. Small numbers, but the same direction as the timing
    result below (declaring at T60 to 79: 31%).
- Even the 8 capitals with 6+ military by T50 didn't strike early (2 captured). The army was built, then the window
  waited (TimingBuildup opens at a median of T41 and waits for the siege train).

**Design proposal: EarlyStrike (not coded; the opening book is Economy's).** For warmongers with an early UU (melee or
ranged: Aztec, Zulu, Huns, Mongols, Songhai, Assyria, Inca, Celts, ...):
- Book: 3 UU, Worker, 1 Settler, 4 ranged (Archers, upgraded to Composite Bowmen), 2 more UU; no Shrine, Monument or
  Granary before them.
- War side (mine): a TimingBuildup window that opens with the book's army, around T35 to T45, and declares by about T60.
  - The target is the nearest weak major's unwalled city. No siege requirement while the target has no walls.
  - Units not in the army hunt barbarian camps in the build-up (CP already tries camps, a median of 36 times before the
    first war; promotions are now logged on the army line, ai/war 8c361db1).
- One flag for each half (book: Economy; window and target: War), tested together.
- Kill: captures below the package block's rate, or the attacker falling behind on cities and science by T100 without
  a capture.

LEAD: reading. Ours builds about 2 military in the capital by T50 against the user's 9, with 2 settlers and 3 buildings
first. More early military goes with more captures (20% with 3+, against 5%). EarlyStrike proposed (book with Economy,
window and target with War); say go and I'll code War's half behind a flag.

### War: an early strike? Walls, siege and timing over our games (Nov 5, about 8:30pm ET)
The lead, relaying the user's human game (106F8550, King, Quick, the Aztec against greedy AIs): Marrakesh taken at T54,
eliminating Morocco, with about 6 Jaguars and 4 Composite Bowmen and no siege. The Jaguars were promoted from barbarian
hunting. Three questions, counted across our games. Script: `tools/ab/early_strike.py`; the CSV counts run inline.

**1. Walls and siege.** One row per city our aggressor attacked, with the city's defence logged at the attempt: 59
cities in 32 first games (850e142 and later), 13 taken.

| | No siege in any capture plan | Siege in a plan |
|---|---|---|
| Unwalled | 1 of 7 | 8 of 24 |
| Walled | 0 of 2 | 4 of 26 |

- Unwalled cities fell twice as often (9 of 31, against 4 of 28). The city strength at the first attempt was a median
  13 for the cities taken and 16.5 for the rest.
- **Siege at the declaration doesn't predict captures** (games with the army line, cities taken): 0 siege 1 of 6, 1
  siege 4 of 12, 2 siege 5 of 23, 3+ siege 2 of 8.
- Siege is in nearly every plan (50 of 59), so the "no siege" column is too small to say siege isn't needed.

**2. Experience.** Not answerable from our logs: no unit XP or promotions are recorded.
- The tactical AI already goes after barbarian camps: "Trying to remove barbarian camp" lines before the first
  declaration have a median of 36 a game (122 logged first games). Captures don't rise with them: 2 of 11 games with
  under 10, 9 of 76 with 30+.
- Logging added (ai/war 8c361db1): the army line now carries "promoted N (P promotions, X XP)" in the window, at the
  declaration and at the first capture attempt on each city.

**3. Timing: the clearest signal.** 150 aggressor first games, all builds, CSV every 10 turns:

| First declaration seen | Games | With a capture | Cities |
|---|---|---|---|
| T60–79 | 19 | 6 (31%) | 8 |
| T80–99 | 37 | 5 (13%) | 7 |
| T100–119 | 31 | 2 (6%) | 3 |
| T120+ | 24 | 2 (8%) | 3 |

- Before T60: 3 games, none captured.
- Inside BigArmy, where the army size is the same:
  - the captured games declared at a median of T69 (T50 to T91), the rest at T90 (T68 to T114);
  - 4 of the 5 that declared by T69 took a city.
- By the first attempt on each city (the 59 cities): before T70, 4 of 7 taken and all 4 unwalled ones fell. From T70
  to T130, 8 of 39. After T130, 1 of 13.

**Read:**
- The data agrees with the user's game on timing: the earlier the war, the more it takes, and unwalled cities fall more
  often.
- It doesn't show that siege is needed; it doesn't show that it isn't, either (siege was almost always there).
- The current direction (SiegeSlots, the 4-siege BigArmy target, WarBudget's longer windows) pushes the declaration
  later. In BigArmy the median window ran 30+ turns past Mathematics.
- **Design proposal for the lead and the user (not coded): an early strike.**
  - The TimingBuildup window opens around T35 to T45 and declares by about T70.
  - Its target is an unwalled city.
  - No siege requirement while the target has no walls; the army is the civ's UU or best melee plus composite bows,
    sized by WarBudget.
  - Siege comes in for later wars, or a walled target (SiegeSlots then).
- Promotions and barbarian hunting: measure first (the new log line), then decide.
- Caveats: small numbers before T70 (19 games), and early declarers may differ in other ways (which leader, which map
  position).

LEAD: reading. Timing and walls agree with the user's game; siege isn't shown either way. Early strike proposed (not
coded); say if you want it as a flag. Army XP logging on ai/war 8c361db1 (logging only).

CI: the army XP logging (ai/war 8c361db1) is green, run 251. The lead merged it into claude/ab-c1 (ce7a93c).

### War: ArmyScrap in the package block fires only at war (Nov 5, about 6:40pm ET)
The lead (6:39pm ET): in 128B4199 (Assyria), the army went from 11 land at the T83 declaration to 6 at the first capture
attempt (T86). Is ArmyScrap scrapping units mid-war? Counted over the package block's first 5 games (bullyabort14 +
bullygreedy16). Script: `tools/ab/package_armyscrap.py`.

- **7 drops in 5 games, all at war, none in the window:** 5 Warriors, a Scout and a Spearman.
- In the window the treasury never fell under 9 turns (the window's gold pause and WarBudget's target hold it). At war
  these aggressors are always under 9, so ArmyScrap took bodies out of the fight it was meant to fund.
- **128B4199's loss was mostly combat.** 4 were killed in combat (2 Archers T84, a Warrior and a Spearman T85) and 1
  Warrior was scrapped (T86). The army was small for its war: 11 land against WarBudget's 8 others + 2 siege, and
  affordable -5 at the declaration.
- **Change (ai/war dc4290cf, for the block after the package):** no ArmyScrap at war; only in the window and the attack
  phase.
  - On these counts it would rarely fire. If the next block shows no window drops, drop the flag.

LEAD: ArmyScrap fired 7 times, all at war (5 games). ai/war dc4290cf takes it out of the war, for the block after the
package; the package block keeps the version it has. Its effect in 128B4199 is 1 of 5 units lost; 4 died in combat.

CI green: run 248 on ai/war dc4290cf, 6:47pm ET.

LEAD: ai/war dc4290cf (SiegeSlots + ArmyScrap not at war) is green. Ready to merge for the block after the package.

### War: BigArmy full block, 20 first games: size is the lever, the waiver pays for it (Nov 5, about 5:00pm ET)
Data: ab-1750459 (bullyabort13 + bullygreedy15), 20 first games and 20 flips (results CSVs; 20 and 9 logged), against
850e142 (15 first) and f6d1e84 (28 first). Script: `tools/ab/bigarmy_block.py`. The mid-block entry (11 games) below
holds up.

| First games | f6d1e84 (28) | 850e142 (15) | **BigArmy (20)** | BigArmy's flips (CP) |
|---|---|---|---|---|
| Games with a capture (cities) | 3 (3) | 1 (1) | **8 (12)** | 1 of 20 (1) |
| War in | 22 | 11 | **18** | 5 of 9 logged |
| Attacks delivered a game (games with 2+) | 1.4 (12) | 1.1 (4) | **3.9 (19)** | 1.2 (4) |
| Capture attempts a game | 3.4 | 2.3 | **16.5** | 1.8 |
| Attempts where the city lost HP; mean damage | 38%; 10.2 | 61%; 21.4 | 40%; 9.5 | 50%; 14.6 |
| Capture plans: units in the sim (median); with a city attack | – | 4; 52% | 7; 53% | 4; 52% |
| Pillage + plunder gold a game | not logged | not logged | 59 + 275 | 9 + 0 |

**The army at the declaration** (27 declarations): land median 20, which meets the target; siege median 2 of 4. Both
met in only 2 (see the siege entry below: production, not the tech).

**Gold:** upkeep waived at war, median 62 a turn over 1,232 war turns; no bankruptcy lines.

**Read:**
- **Size is the lever, confirmed over the full block.**
  - 8 of 20 games captured (12 cities), against 3 of 28 and 1 of 15 on the builds before it, and 1 of 20 in BigArmy's
    own flips under CP's AI.
  - The attempts are no better (the city lost HP in 40%, mean 9.5, as on f6d1e84). The volume is what changed: 3.9
    attacks delivered a game against 1.1 to 1.4, and 16.5 capture attempts against 2 to 3.
- **The waiver pays for it.** About 62 gold a turn at war, against the 24 to 40 gold an attacker holds at war without
  it. Pillage and plunder bring about 330 a game: roughly 8 a turn over a 40-turn war.
- **What follows is the package block running now:**
  - WarBudget's army is what gold keeps;
  - ArmyQuality and ArmyScrap: better units, and the upkeep of the ones that don't fight;
  - SiegeSlots (for the block after): the siege half of the army.
  - Judge the package against BigArmy's 8 of 20.

LEAD: reading only.

### War: siege starved in the BigArmy windows: production, not the tech or the ready test (Nov 5, about 4:55pm ET)
The lead (4:21pm ET): siege at the first declaration is 0 to 3 of the 4 targeted in nearly every BigArmy game, while the
land "others" target is met. Is it the tech, the siege weight in the window, or the ready test? Counted over the logged
BigArmy first games (19 with logs; scripts `tools/ab/bigarmy_siege.py` and `bigarmy_siege_weights.py`, run from a
results worktree).

| Question | Count |
|---|---|
| Mathematics (first siege unit in the production list) | median T40 (T35 to T47) |
| Window opened | median T41 (T26 to T83) |
| Declaration after Mathematics | 12+ turns in every game (median about 30) |
| Declarations (28): field target met / siege met / both | 16 / 5 / 2 |
| Field met but siege short | 14 of 28 |
| Siege refused in the window: over the land army size ("nosupply") / other | 180 / 24 |
| City-turns where siege could be built: siege the top-weighted unit | 43 of 395 (a median 81% of the top unit's weight otherwise) |
| Military picks in the window | siege 69 of 490; Archers 112, Warriors 90, Scouts 45 |

**Read:**
- **Not the tech.** Siege is buildable about when the window opens, and every war comes 12+ turns later.
- **Not the ready test.** It wants both halves, but the war comes anyway: when the window runs out, or from CP's own
  approach. Only 2 of 28 declarations had both.
- **It's production.**
  - The window gives siege +4000 and every other land unit +3000, so siege tops the list in only 11% of city-turns.
    Cheaper Archers and Warriors win the rest.
  - Once the land count reaches the recommended size (siege target + field target + 2), CP refuses every land unit,
    siege included ("nosupply", 180 times). The siege slots end up filled by extra field units.
- This holds for the normal and WarBudget targets too: the cap and the weights are the same.

**Proposal: SiegeSlots (coded, ai/war 5b6e48b6 on claude/ab-c1 5b7333c0, off).** In the window:
- while siege (built and being built) is short of its target, a siege unit isn't refused for the land army size;
- other land units get the window's +3000 only while the field units are short of the field target.
- Siege keeps its +4000 while short.
- Confirm: siege at the first declaration reaches its target in most games (BigArmy 5 of 28), with the field target met
  as often.
- Kill: the declaration comes later than with BigArmy or WarBudget alone, or the field target is met less often.

LEAD: for the block after the package. ai/war 5b6e48b6 = claude/ab-c1 5b7333c0 + SiegeSlots (off). CI green (run 241,
5:06pm ET); ready to merge.

### War: WarBudget, War's half: the army target is what gold keeps (Nov 5, about 2:22pm ET)
The lead's honest package for the block after BigArmy. Economy's half is GetAffordableWarUnits (patch 0025, a21e842):
how many more paid units the treasury plus 20 turns of income can keep.

**War's half (ai/war dbe68ec0, on claude/ab-c1 0561379 plus 0025):**
- The field target is min(2 x normal, max(normal, field units now + affordable)), with normal = cities + 4. It runs
  from the normal army up to BigArmy's size, with no waiver and no lifted build caps.
- It is counted from today's army, not the lead's normal + min(normal, affordable). Affordable falls by one with each
  unit built, so added to a fixed normal, the target would shrink as the army grows. Counted from today's army, it
  stays put.
- "Ready" then means gold can't keep another unit, or the army is at twice normal. WindowUntilReady's 2 windows
  bound it; the gold pause and CP's upkeep guard still apply.
- Logs: "WarBudget: army ..." with "affordable N more", in the window, at the declaration and at the first capture
  attempt. bigarmy_block.py reads both names.

**Hypothesis:**
- Economy measured 22 a turn of upkeep in the window and 73 at war for BigArmy's armies, against +7 and +25 left after
  buildings. So 20 turns should afford roughly 8 to 10 extra units at the window's start: an army near BigArmy's land
  median of 20.
- Confirm: land at the declaration at or above 15 (median), and captures at or above half of BigArmy's rate (5 of 11)
  with no waiver.
- Kill: land at the declaration under 12, or the army shrinks at war (land at +20 below the declaration), or captures
  at f6d1e84's rate (3 of 28).
- Read with ArmyQuality and ArmyScrap: the field count and the gold both change under them.

LEAD: ai/war dbe68ec0 is 0561379 + Economy's 0025 + War's WarBudget half. Merge once CI is green (I'll confirm here).

**CI (2:48pm ET): green.** Run 236 on ai/war abc78a60: the lead's const fix for ArmyQuality (runs 232 and 233 failed
with C2662 at CvMilitaryAI.cpp:2008, GetNumUnitsWithDomain on a const CvPlayer*) on top of dbe68ec0.

LEAD: ai/war abc78a60 is green (run 236). It carries ArmyQuality, ArmyScrap, Economy's 0025 and WarBudget's War half, all
off in the bundle. Ready to merge into claude/ab-c1.

### War: without the waiver, gold holds the army at 9 to 10 units for 40 turns of war (Nov 5, about 2:15pm ET)
The lead asked for idle gold to go to the army. The results CSVs (aggressor rows every 10 turns; first games only) say
there is no idle gold without the waiver.

**Gold and land units from the first sample with a war:**

| | f6d1e84 (22 at war) | 850e142 (11) | BigArmy (11, waiver) |
|---|---|---|---|
| Land units at -10 / 0 / +10 / +20 / +30 / +40 | 9 / 9 / 9 / 10 / 10 / 9 | 9 / 10 / 9 / 8 / 9 / 9 | 16 / 16 / 17 / 20 / 21 / 25 |
| Gold median at war; samples with 300+ | 40; 4% | 24; 3% | 143; 17% |
| Window paused for gold (turns a game) | 6.6 | 8.7 | 0 (waived) |
| Gave up: no war 3 windows after the build-up | 28 in 28 games | 12 in 15 | 1 in 11 |

**Read:**
- **No idle gold.** Without the waiver, an aggressor at war holds a median of 24 to 40 gold, and 300+ in 3 to 4% of
  the samples. A "spend idle gold on the army" flag would target nothing: the gold BigArmy left idle was the waiver's.
- **The army is held at the gold ceiling, not destroyed.** Without the waiver, land units stay at 9 to 10 from the
  declaration to 40 turns in: losses are replaced and the army never grows. With the waiver it grows from 16 to 25,
  and the captures come along the way (2 games by the declaration sample, 4 by +10, 5 by +40).
- So a sustained army is a gold question first. War's levers inside that ceiling:
  1. **Better units for the same upkeep: ArmyQuality** (coded, c74f22163). The army stays the same size, of units
     that do damage.
  2. **Upkeep freed from units that don't fight (ArmyScrap; coded, ai/war 74cf8b3cd, 2:20pm ET).** Under ArmyQuality, Warriors and Scouts no
     longer count as army but are still on the payroll. BigArmy's armies carried 42 of 194 such units at the first
     declaration (about 4 a game). At the war-time upkeep BigArmy logged (median 71 a turn for about 20 units, about
     3.5 a unit), scrapping them frees about 14 a turn, a fifth of Economy's 70 a turn gap.
     - Proposed rule: in the window or at war, while the window is paused for gold or the treasury is falling, disband
       one land unit below the ArmyQuality floor a turn, never a city's last garrison.
     - It uses ArmyQuality's floor (it works without that flag), so it would go into the same block or the one after.
     - As coded: from the window on, when the treasury would run dry in under 9 turns (the window's own pause test),
       the weakest land unit below the floor that isn't siege, a garrison, in an army or upkeep-free. One a turn,
       gifted to a city-state if one takes it, else disbanded. Logs "ArmyScrap: dropping ...".
     - Confirm: the gold-pause turns in the window fall (f6d1e84 6.6 a game), and the land units at +20 and +40 grow
       past 10 with the same gold.
     - Kill: cities lost to counterattacks go up (CitiesLost), or the army at the declaration is smaller.
  3. **War pays: plunder.** BigArmy plundered 3,700 gold in 11 games (about 340 a game, 100 x era per trade route) and
     pillaged 700. That is about 10 a turn over a 40-turn war. The f6d1e84 and 850e142 builds predate the gold logging,
     so their plunder isn't measured. Not a flag yet: first see what a non-waived army plunders, measured in the next
     block.
- The rest of the gap (about 70 a turn for the doubled army) is Economy's.

LEAD: a spend-idle-gold flag is dropped: there is no idle gold without the waiver. ArmyScrap is coded on ai/war
(74cf8b3cd, off) to go with ArmyQuality (c74f22163) in the block after BigArmy.

### War: a sustained army without the waiver: patterns over the 11 BigArmy games, and the flags (the lead, 2:08pm ET) (Nov 5, about 2:09pm ET)
**Per-game numbers (BigArmy first games, ab-1750459):**

| Pattern | Over the 11 games |
|---|---|
| Siege at the first declaration (of 4) | 4/4 in 3 games (1 captured); 0–2 in 8 games (4 captured) |
| Units in reach at the first capture attempt / land army | median 5 / 17 (range 1–8 of 12–29) |
| Gold at war (per-game median; max) | 40–247; 174–837 in every game |
| Land units added a window turn | 0.16–0.72 (window 19–48 turns) |
| First-declaration army | 194 units: Swordsman 34, Archer 34, **Warrior 31**, Catapult 18, Jaguar 16, Chariot Archer 11, Composite Bowman 11, **Scout 11**, Spearman 9 |

**What these say:**
1. **Siege before the declaration: not supported.** Games that declared with the full train captured less often (1 of 3)
   than those without it (4 of 8). No gate on siege; the lead's proposal is noted against the data.
2. **Idle gold at war is the waiver's gold.** The 71 gold a turn of upkeep BigArmy waived at war is about what sat
   in the treasury. Without the waiver there is no idle gold to spend, so no buying flag from War. Economy's gap
   measure covers it.
3. **Composition is real and honest.**
   - 22% of the army at the first declarations was Warriors and Scouts (42 of 194), counted as army by
     IsTimingBuildupArmyReady and paid upkeep like the rest.
   - Funnel stage: not taken (6 of 11 BigArmy first games, 11 of 28 on f6d1e84).
4. **Concentration:** about a third of the army is in reach at the first attempt. SiegeFeed (built, merged into 850e142
   but off) keeps the units in reach from being pulled into new armies; SiegeClose (in the role) brings them up.
   Funnel stage: not taken / refused.

**Flags for the block after BigArmy:**
- **ArmyQuality (new; coded, ai/war c74f22163, Nov 5 2:12pm ET).** A TimingBuildup civ builds no land unit weaker
  than 70% of the best of its kind (melee or ranged; siege and scouts apart) it can train, and such units don't count
  toward its army. That rules out Warriors once Swordsmen are trainable, and Archers once Composite Bowmen are. The
  army becomes the same size, of better units, for the same upkeep.
  - Units are compared within their kind so Archers aren't judged against Horsemen.
  - Targets the 22% obsolete share.
  - Funnel stage: not taken (6/11 BigArmy, 11/28 f6d1e84).
  - Code:
    - CvMilitaryAI::GetArmyQualityFloor and IsArmyQualityUnit;
    - IsTimingBuildupArmyReady and GetTimingBuildupUnitsWanted count only units at or above the floor;
    - shared code: CvUnitProductionAI::CheckUnitBuildSanity refuses units below the floor, unless the city is under
      siege or the unit is free.
  - Off in the bundle; nothing changes with the flag off.
  - Confirm: in the next block, the share of Warriors and Scouts at the first declaration (BigArmy 42/194) falls to
    near 0, with the same land count at the declaration.
  - Kill: the declaration comes later than BigArmy's (median), or captures fall below BigArmy's 5/11.
- **SiegeFeed on (built):** concentration at the walls (5 of 17 in reach).
- **SecondWave (already in the role):** follow-up waves.
- **BigArmy's army target (4 siege, 2 x (cities + 4))** without the waivers: whether that is affordable is Economy's
  gap (about 70 a turn).

### War: BigArmy mid-block, 11 first games: size is the lever (Nov 5, about 1:57pm ET)
Data: ab-1750459 (bullyabort13 + bullygreedy15), 11 first games and 5 flipped, against 850e142 (15 first) and f6d1e84
(28 first). Script: `tools/ab/bigarmy_block.py` (uses attack_funnel.py and walls.py).

| First games | f6d1e84 (28) | 850e142 (15) | **BigArmy (11)** | BigArmy's flips (5, CP) |
|---|---|---|---|---|
| Games with a capture (cities) | 3 (3) | 1 (1) | **5 (9)** | 0 (0) |
| War in | 22 | 11 | **11** | 3 |
| Attacks delivered a game (games with 2+) | 1.4 (12) | 1.1 (4) | **4.3 (11)** | 1.2 (2) |
| Capture attempts a game | 3.4 | 2.3 | **21.2** | 1.4 |
| Attempts where the city lost HP; mean damage | 38%; 10.2 | 61%; 21.4 | 38%; 9.3 | 28%; 4.6 |
| Capture plans: units in the sim (median); plans with a city attack | – | 4; 52% | 7; 52% | 4; 60% |

**The army.** 15 declarations:
- land median 20, which meets the target (siege + others median 20);
- siege median 2 against a target of 4. Fully ready (both met) in only 2: the first war usually comes before the
  siege train, from CP's own WAR approach and MarchOn.
- no "bankruptcy skipped" lines.

**Read:**
- **Size is the lever.** With the doubled army, 5 of 11 games captured (9 cities), against 3 of 28 on f6d1e84, 1 of
  15 on 850e142, and none of BigArmy's own CP flips.
- **The attempts themselves didn't get better:** the city lost HP in 38% of them, mean 9.3, as on f6d1e84, and the
  plans attack the city as often (52%). What changed is volume:
  - 4.3 attacks delivered a game against 1.1–1.4, every game with 2 or more;
  - 21 capture attempts a game against 2–3.
  - The army survives the first wave and keeps coming back, which is the wave effect the funnel pointed at.
- **The cost:**
  - At war, the waived upkeep was a median 71 gold a turn (750 turns logged); at peace it was 7–13 in the window.
  - Pillage and plunder paid 64 + 336 gold a game: a few turns' worth, far from 71 a turn.
  - So pillaging can't fund an army this size.

**What follows (the lead's rule: if captures jump, size is the lever, and Economy and War make it reachable
honestly):**
- **Economy:** about 70 gold a turn of upkeep at war is the gap to fund (gold buildings, trade, war-time taxes...).
- **War: cheaper armies, sustained.**
  - Waves: SecondWave and SiegeFeed keep units flowing.
  - Composition: siege first; the declaration waits for the siege train (2 of 15 were ready).
  - Using unspent gold: Japan sat on 638.
- **The capture-plan line (half the plans don't attack the city)** stays the open question at the walls; with more
  attempts, the per-attempt rate matters less than it seemed.

The block runs to 20 games each; the full read follows.

### War: WindowUntilReady block (850e142, ended early) and the first BigArmy game (Nov 5, about 11:53am ET)
**850e142 (bullyabort12 + bullygreedy14, 15 first games) against f6d1e84 (28 first games).** Small block; signals only.

| First games | f6d1e84 (28) | 850e142 (15) |
|---|---|---|
| Stages: no war / attacked first / never at walls / refused / not taken / captured | 1 / 4 / 3 / 6 / 11 / 3 | 0 / 2 / 4 / 2 / 6 / 1 |
| Attacks delivered a game (games with 2+) | 1.4 (12) | 1.1 (4) |
| Endings a game: NoUnits / DiploOpinionChange / TimedOut | 0.1 / 0.9 / 1.7 | 0.2 / 0.2 / 1.3 |
| Attempts a game; city lost HP; mean damage | 3.4; 38%; 10.2 | 2.3; 61%; 21.4 |

- **WindowUntilReady fired:** "army not ready ... the window goes on" 28 times across the 15 games. TimedOut endings
  fell a little (1.7 → 1.3), and DiploOpinionChange endings fell (0.9 → 0.2).
- **Fewer waves:** 1.1 delivered a game.
- **Capture plans (the new log; agg 2 and up), 70 plans:**
  - a median 4 units in the sim;
  - 52% of plans include an attack on the city, a median of 1 city attack a plan.
- **City defence at the 34 logged attempts:** strength median 13, walls in 47%, and the garrison took damage in 29%.
- **Read:** attempts hurt more when they happen, but there are fewer of them and fewer waves. Half of all plans at a
  city don't attack it at all. That's the next look at the walls, now that the log can show it.

**The first BigArmy game (110B2E42, PC 2, ab-1750459), the lead's question: does the doubled army form and reach a
city?** Yes, slowly.
- **Japan's window opened vs Russia at T44** with 4 land units (target 4 siege, 12–16 others).
- **Army growth in the window:** 8 land by T62 and 13 by T68, nearly all Warriors and Archers. With 4 small cities a
  unit took 3–5 turns, and the capital built the Great Library T54–T65.
- **Gold:** went unused, up to 262 by T69 and 638 by T121. BigArmy lifts caps but doesn't buy.
- **The first war came before the army was ready:** Japan declared on Assyria at T69 with 15 land and 1 of 4 siege.
  - The route: a sneak attack and MarchOn, on Japan's own WAR approach toward Assyria (PATHETIC, Soft).
  - The readiness gate is only in GetNewAIConquestTarget; CP's own WAR approach and MarchOn don't ask it.
- **Later:** the army kept growing: 25 land at T104, 30 at the declaration on Russia at T118, 35 at T121.
  Attempts on Assur, Nineveh, Novgorod, St. Petersburg and Moscow had 2–8 units in reach.
- **Result: 2 cities captured** (by T110 and by T130); the flipped game took none.
- **Not a bug to fix mid-block:** the army forms and reaches cities.
- **The caveat for the block read:** the first war doesn't wait for the doubled army, so read BigArmy's
  "at the declaration" lines next to the captures.

### War: pillage gold, counted (the user: "could pillaging help to keep attacking armies in positive money?") (Nov 5, about 10:03am ET)
**What pillage pays in VP:**
- an improvement's PillageGold (8 to 20) × the era (at least 1) × 85–100% (CvUnit pillage), so about 8–40 gold early;
- a trade route plundered: TRADE_ROUTE_BASE_PLUNDER_GOLD (100) × era, adjusted for its domain;
- the pillaging unit also heals.

So a pillage or two a turn could plausibly cover an army's upkeep during a war; it can't fund the build-up (no
pillage at peace).

**How much our aggressors pillage now (walls.py over all logged games):**
- role games: 11 pillages in 88 games, 0.1 a game. 78 of 88 games had none, and the most in one game was 2.
- CP's flipped games: 5 in 14.
- So the money is there and almost unused.

**Counting it from now on:**
- `ai/war` `17504599c` (logging only) logs "Pillage gold: N from <improvement> at (x:y), owner X, gold now G" for every
  pillage, and "Plunder gold: N from a trade route ..." for plunders.
- walls.py prints per group: pillages a game, games with none, and the pillage and plunder gold where it's logged.

**The plan:** BigArmy's block logs the war-time upkeep it waives ("BigArmy: upkeep waived X ... a turn"), which gives
the deficit a big army runs at war. Set against the pillage gold, that shows whether a pillage flag (units with no
attack to make, and fast units, pillage and plunder near the target) could close it. No pillage flag until then.

### War: BigArmy, a diagnostic flag, never for the bundle (the user and the lead, 8:20am ET) (Nov 5, about 8:27am ET)
**The question:** is the attack failing because the army is too small, or because of how it fights at the walls?
- The user: "a warmonger with 7 super greedy civs, a fox in the henhouse, and they still can't capture cities."
- CP's AI captures in 2 of 27 flipped games, ours in 3 of 27.
- 4 of 112 capture attempts were expected to reach the city's HP.
- 46 "too weak" give-ups in the last block.

**BigArmy (flag; War; test only, never in the bundle or a style), for a TimingBuildup aggressor:**
- **Twice the ready army:** 4 siege units and 2 x (cities + 4) others, against 2 and cities + 4. This applies to
  IsTimingBuildupArmyReady and GetTimingBuildupUnitsWanted, and through them the declaration, WindowUntilReady,
  CoopWhenReady and WarChest's purchases. It also covers the window's siege weight (+4000 until 4 siege) and its
  recommended army size.
- **Time to build it:** the window lasts until the army is ready, up to 4 windows; the plan goes back to peace after 5.
- **The window's build caps are lifted** for land combat units: CP's under-2-buildings rule, the
  9-turns-to-bankruptcy upkeep guard, and the window's own pause for gold. It may go into debt.
- **Nothing else changes.** A capture difference is then about army size.
- **Logs:** "BigArmy: army <when>: n land (s siege; target ...), gold G, X a turn: <unit types>", logged:
  - each window turn;
  - at the declaration on a major;
  - at the first capture attempt on each city, with the units in reach.

**How it's read (the lead):**
- If captures jump, size is the lever, and Economy and War make it reachable honestly.
- If they stay rare with a big army, the siege/tactical code is the blocker, and that is War's next study.

**Gold made irrelevant (the lead, 8:30am ET):** in 0C22F161 debt itself destroyed an army: CP's "Gifting Warrior ...
b/c bankrupt" gave away 37 warriors and the siege train. So under BigArmy, from the window's start to the end of the
war (phase WINDOW, ATTACK or WAR):
- no unit upkeep (CvTreasury::CalculateUnitCost returns 0); logged each turn as "BigArmy: upkeep waived X (phase P,
  gold G, Y a turn)";
- no bankruptcy gifting or disbanding (CvPlayer::DoBankruptcy returns; the treasury is already floored at 0); logged
  as "BigArmy: bankruptcy skipped";
- no unit counts as out of supply (CvPlayer::GetNumUnitsOutOfSupply returns 0). That lifts VP's training cap (14 over
  supply), its 5%-a-unit production penalty and the over-supply scrapping;
- DisbandObsoleteUnits doesn't count a deficit.

Shared code: CvTreasury::CalculateUnitCost, CvPlayer::DoBankruptcy, CvPlayer::GetNumUnitsOutOfSupply, test only.

Coded: `ai/war` `0ed387c16`, `ecdc7837e`, `4cb5ae135`, `5db364c47` (include fix; run 222 had failed on it) on `claude/ab-c1` `850e142f1` (a fast-forward), CI run 223 green. Runs
as a 20-game block (RoleFixes + BigArmy) after the WindowUntilReady block.

### War: the f6d1e84 block against the earlier builds (first games); SiegeVolley withdrawn (Nov 5, about 1:56am ET)
**Data:**
- **f6d1e84 (bullyabort11, bullygreedy13):** 10 first games, 2 flipped.
- **e4d5785 (bullyabort9, bullygreedy11):** 14 first games.
- **7bb7885 (bullyabort10, bullygreedy12):** 5 first games.
- **Tools:** attack_funnel.py and walls.py. The samples are small; the differences below are signals, not proofs.

| First games, per game | e4d5785 (14) | 7bb7885 (5) | f6d1e84 (10) |
|---|---|---|---|
| Stages: no war / never at walls / refused / not taken / captured | 1 / 0 / 8 / 4 / 1 | 3 / 0 / 1 / 1 / 0 | 0 / 2 / 2 / 5 / 1 |
| Attacks formed (median) | 5 | 3 | 5 |
| Attacks delivered to the target (mean; games with 2+) | 1.4 (5) | 0.6 (1) | 1.5 (5) |
| Attacks ended NoUnits (mean) | 1.0 | 0.0 | **0.0** |
| Attacks ended DiploOpinionChange (mean) | 2.3 | 1.2 | **0.3** |
| Attacks ended TimedOut (mean) | 0.7 | 1.0 | **1.6** |
| Capture attempts per game | 3.6 | 1.4 | 1.9 |
| Attempts where the city lost HP | 32% | 57% | **57%** |
| Mean damage per attempt | 6.8 | 16.6 | **18.6** |
| Own units killed | 4.2 | 4.4 | 5.4 |

**Read:**
- **Fewer cancelled attacks:** SecondWave and TargetHold do what they were for. NoUnits endings are gone, and
  DiploOpinionChange endings fell from 2.3 a game to 0.3. CSAfterWar's effect can't be read here (city-state attacks
  aren't counted yet).
- **Better attempts:** they land more often and hit harder: 57% against 32%, mean 18.6 against 6.8. Fewer games
  stop at "refused" (2 of 10 against 8 of 14).
- **Waves, the funnel's best predictor of a capture, haven't moved:** 1.5 delivered a game against 1.4.
- **More TimedOut endings:** up from 0.7 to 1.6. SiegeArmy holds the sneak attacks at peace for 20 turns, then gives
  up, because the armies are still too small at peace. That is the army-building side WindowUntilReady and
  CoopWhenReady (built, not merged) are aimed at.
- **SiegeDominated never attacked** in this block (only "stays skipped": 1 unit, expected 0).

**Update with the whole block (14 first games, about 2:59am ET).** Four more f6d1e84 games came in after the table, three of
them "no war declared" (PC 1 pairs 7 and 8, PC 2 pair 6). Over all 14:
- **Stages:** no war 3, never at walls 2, refused 2, not taken 6, captured 1.
- **Delivered:** 1.2 attacks a game (6 games with 2 or more).
- **Attack endings a game:** NoUnits 0.1, DiploOpinionChange 0.9, TimedOut 1.6.
- **Attempts:** 41 (2.9 a game); the city lost HP in 43%, mean 11.7.

So against e4d5785 the gains shrink: attempts land 43% against 32% (not 57%), mean damage 11.7 against 6.8.
DiploOpinionChange endings are down to 0.9 from 2.3, not 0.3. The no-war games are back to 3 of 14 (e4d5785: 1 of 14).
The direction holds (fewer cancelled attacks, harder hits, fewer refusals), but it is smaller.

**Next build:** the lead merged WindowUntilReady and the capture-plan logging into `claude/ab-c1` `850e142f1` (CI run
219 green); SiegeFeed and CoopWhenReady are merged but off. That block is read against these 14.

**Update with 22 first games (about 5:05am ET; the PCs stayed on f6d1e84 past the block).**

| First games | e4d5785 (14) | f6d1e84 (22) |
|---|---|---|
| Stages: no war / never at walls / refused / not taken / captured | 1 / 0 / 8 / 4 / 1 | 4 / 2 / 5 / 9 / 2 |
| Attacks delivered a game (games with 2+) | 1.4 (5 of 14) | 1.4 (10 of 22) |
| Endings a game: NoUnits / DiploOpinionChange / TimedOut | 1.0 / 2.3 / 0.7 | 0.1 / 1.0 / 1.9 |
| Capture attempts a game | 3.6 | 3.6 |
| Attempts where the city lost HP; mean damage | 32%; 6.8 | **35%; 9.2** |
| Own units killed a game | 4.2 | 5.3 |

**Read at 22 games: the early numbers were noise.**
- At the walls, almost nothing changed: attempts land 35% against 32% (the 57% at 10 games was the first games'
  luck), and captures are 2 of 22 (9%) against 1 of 14.
- What clearly changed is upstream:
  - attacks no longer end NoUnits (SecondWave);
  - half as many end DiploOpinionChange (TargetHold);
  - but TimedOut nearly tripled (0.7 → 1.9), and no-war games rose from 1 in 14 to 4 in 22.
- The attacks that used to be cancelled now sit in SiegeArmy's peace bar until they time out, and some wars never come.
- Waves didn't move (1.4).
- The sieges are not being won at the walls by any of the at-the-walls flags yet (SiegeClose, SiegeDominated,
  SiegeExposure, SiegeFinish are all in this role).

**Next:**
- The new build (850e142f1) changes the army-building side: WindowUntilReady keeps the window's army target until the
  army is ready. Its block should show whether TimedOut and no-war fall and waves rise.
- At the walls, the capture-plan logging in that build is the first chance to see what the plans actually do. Until
  then, no new at-the-walls change.

**Correction (my earlier at-the-walls entry): SiegeVolley withdrawn.**
- The "6 or more units in the sim: the city lost HP in 22%" figure came almost entirely from one game: the Inca at
  Mumbai (0DF72455), 18 attempts with 6+ units, 1 landed.
- Every other attempt with 6+ units over all logged games landed: 8 of 9 (f6d1e84: 3 of 4).
- So it isn't a pattern, and SiegeVolley would have been a one-game fix.
- The capture-plan logging (`249985284`) stays useful: it will show what a plan does when a city like Mumbai holds.

**What the block points at (funnel stages: not taken 5 of 10, refused 2, never at walls 2):** the armies still get
one wave, and the peace-time attacks time out in SiegeArmy. The next merge's candidates are already built: SiegeFeed,
CoopWhenReady, WindowUntilReady, and the logging. Nothing new is coded from this block.

### War: the first two games on ab-f6d1e84 (block 1, pair 1 on each PC): which merged flags show up (Nov 5, about 12:01am ET)
Signals only; the block is read as a whole (the user's rule), not fixed game by game.
- **SecondWave:** it forms attacks at war that used to end NoUnits.
  - Huns 0DC8850A: attack 2102 started with 3 units at T100, at war; it ended WarStateChange at T106.
  - Germany 0E84B5F4: attack 2678 started with 3 units at T132, at war, and was handed over at T149.
- **TargetHold part 2:** "CONQUEST: holding Egypt as a war plan, attack under way" (Germany, T58).
- **SiegeClose:** fired at Thebes (T148).
- **Still there:**
  - Germany's sneak attacks on Egypt timed out in SiegeArmy four times before the war (T56, T60, T82, T107; 1–5 units
    each).
  - Germany logged 155 "requested attack … not possible for lack of units".
  - Thebes' one attempt (T118, 3 units) did 0 damage.
- **Count after the block:** run walls.py and attack_funnel.py on all f6d1e84 games.

### War: at the walls, over every logged bully game (the lead's funnel; the user: patterns, not single games) (Nov 5, about 11:52pm ET)
**Tool.** `tools/ab/walls.py` (on this branch; it imports the lead's `attack_funnel.py` from claude/sleepy-hopper-x77moh).
`python3 tools/ab/walls.py [results dir] [--games]` puts the aggressor's attack operations, capture attempts, refusals
and zone strengths of every logged game next to the funnel stage. Data: 60 logged games, 51 first (RoleFixes), 9 flipped
(CP).

**What the armies look like.**
- **Size:** each attack recruits a median 5 units (refused games) or 7 (not taken, captured); CP's flipped attacks 5–6.
- **Composition:**
  - Ours are Warriors, Swordsmen, Composite Bowmen and Archers, as CP's are, but with more siege: 40% of the units
    recruited in our capturing games, 21–22% in refused and not taken, against 2–15% in CP's.
  - Before T80, 54 Catapults across our attacks against none in CP's.
  - Composition is not where we're worse than CP.
- **Waves:**
  - The games that captured had 2–3 attacks delivered to the target (ours: 2, CP's: 3).
  - Refused and not taken had 1, out of a median 3–3.5 attacks formed; the rest ended NoUnits, DiploOpinionChange
    or TimedOut.
- **Arrival:** handed over with the nearest unit a median 3 tiles from the city and the farthest 5, in every group,
  ours and CP's.
- **Losses:** a median 5 of our units killed per not-taken game (melee 63, ranged 19, siege 11 over 18 games).

**What happens at the walls (capture attempts with an outcome: 88 ours, 27 CP's).**
- **Expected damage:**
  - A median 53 a turn against 200 HP in not-taken games; it never reached the city's HP there.
  - The city must be hit about 4 turns in a row, less its healing.
- **Damage done:** the city lost HP in 30% of our attempts against 52% of CP's (58% on consecutive turns, against
  our 33%). The median damage done is 0 for both.
- **Units within striking distance (sim size) against how often the city lost HP:**

  | Units in the sim | Ours: attempts, city lost HP | CP's: attempts, city lost HP |
  |---|---|---|
  | 1 | 5, 0% | – |
  | 2–3 | 23, 47% | 14, 28% |
  | 4–5 | 19, 57% | 11, 90% |
  | 6+ | 22, 22% | 1, 0% |

  With 6 or more units the tactsim explored a median 4,768 positions and completed 429, past King's budget of 384
  completed plans (TacticalSimMaxCompletedPositions), and the plan chosen rarely hurt the city.
- **Aggression:** at AL_HIGH (more than 2 melee within reach) the city lost HP in 21% of our attempts; at AL_MEDIUM
  38%. CP's: 53% and 50%.
- **"Too early" (the 13-turn healing rule):** 348 turns in not-taken games, 245 in refused. The median expected damage
  was 0, meaning every unit in reach would take more damage than it dealt (ComputeTotalExpectedDamage drops "suicidal"
  attacks).

**Read.**
- **Waves:** the armies are not obviously worse than CP's, and they arrive the same way. What separates the captures
  is waves: 2–3 delivered, not 1.
- **The attempts themselves:** ours land less often than CP's, and much less when the sim is big (6+ units: 22%).
  The new AI's tactsim differs from CP's in one known way here: one extra breadth-first level for battles up to 9
  units (an earlier AI_AB_TEST change in FindBestUnitAssignments). SiegeExposure also changes the end-turn danger score
  after an attack on a city.
- **Untested:** the counts are small (73 attempts of ours with a tactsim line, 26 of CP's), and the logs don't say
  which units attacked, so the sim-size effect is a lead, not a proof.

**Proposals (each names its funnel stage):**
1. **Waves (refused 23 games, not taken 18):**
   - SecondWave (in f6d1e84, running) and SiegeFeed (ready, not merged) are aimed at exactly this.
   - The f6d1e84 block will show whether delivered attacks per war go from 1 to 2+.
   - No new code until then.
2. **(Withdrawn at the f6d1e84 block read: the effect was one game.) Big sims at the walls (not taken 18, captured 3):**
   - Flag SiegeVolley: when 6 or more units are in striking distance of a city, the capture attempt runs in two passes.
     Ranged and siege units go first (a small sim that can only attack), then the melee units with the city's new HP.
   - Each sim stays well under the 384-plan budget; the 4–5-unit sims are the ones that land.
   - Before coding it I'd want one logging-only line (below) to confirm the big sims choose moves instead of attacks.

**Log lines asked for (logging only):**
- per capture attempt, each unit's chosen action (ranged attack, melee attack, move, none) with damage to the city
  and to the garrison;
- the city's combat strength (and whether it has walls) on the attempt line.

Coded (the user: "add the log lines"): `ai/war` `249985284` (built, CI run 218), logging only.
- **The plan line:** "capture plan vs X, agg A: n units in the sim, m in the plan, k attacks (j on the city): <unit>
  MOVE>RANGEATTACK(city, garrison g, self s)>FINISH; ..." (or "no plan"), one per tactsim run against an enemy city,
  so the SiegeClose positioning runs (agg 1) show too.
- **The attempt line:** gains "; city strength S, walls +W, garrison G HP a -> b".
- **walls.py** reads both: attacks on the city per attempt, attempts with none, city strength, walls, and how often
  the garrison took the damage.

### War: CoopWhenReady and WindowUntilReady, from the corrected read of 0DB01EF0 (the user: "code both") (Nov 4, about 11:37pm ET)
**CoopWhenReady (flag, War; shared: CvDiplomacyAI::DoUpdatePlanningExchanges' coop loop, around DoStartCoopWar).**
- **Seen:** the Ottomans' coop war on the Shoshone (agreed T63) declared itself at T73. Mongolia went in with 3
  Warriors, 2 Archers and a general and lost 8 units.
- **The mechanism:** CP starts a coop war 10 turns after it is agreed (COOP_WAR_SOON_COUNTER), whatever the armies,
  and either partner's turn can start it for both.
- **Hypothesis:** if either partner is a TimingBuildup attacker whose army isn't ready (2 siege units plus cities+4
  others), the coop war waits. Neither partner's turn starts it. After 30 turns (Standard) it starts anyway, so an ally
  isn't held forever.
- **Logs:** "CoopWhenReady: coop war on X waits for the army (n turns since agreed)".
- **Expect:** coop wars on the target starting with a siege army, or not at all in the first window.

**WindowUntilReady (flag, War, CvMilitaryAI::IsInTimingBuildupWindow).**
- **Seen:** the window (10 turns on this speed) built 2 Warriors and an Archer. When it ended at T52, the army target
  (cities+6) and the unit weights ended with it. The attack phase fell back to CP's small army target, and units were
  skipped as "nosupply" from T53.
- **Hypothesis:** the window lasts until the army is ready, up to 2 windows. That leaves the attack phase one window as
  the fallback before the existing 3-window limit sends the plan back to peace. Its army target, unit weights and purchases stay on, and GetNewAIConquestTarget doesn't return the
  target before then, so the attack starts with the army or at the limit.
- **Logs:** "TimingBuildup: army not ready (s siege, l land), the window goes on".
- **Expect:** windows ending "ready", more units per window, wars with siege units.
- **Not covered:** young cities still can't build military (CP's under-2-buildings rule); that is a bigger change,
  left for later.

Coded: CoopWhenReady `ai/war` `83ed6a540` (built, CI run 216), WindowUntilReady `57a9b02cd` (built, CI run 217), on `1fe84572f` (SiegeFeed).

### War: 0DB01EF0 pair 3 (PC 1, ab-7bb7885): the flip without RoleFixes took Troyes; the role game made one attack in 150 turns (Nov 4, about 11:29pm ET)
- **Flip (0DB01EF0F, CP's Mongolia):**
  - City attacks at T69, T101, T104, T119, T142 and T147, each recruiting 6–8 units (CP's smaller formation, 9 slots).
  - Troyes (France) was taken in 3 turns: expected 115–121 a turn, 200 → 97 at T111, CAPTURED at T112, 5 of 5 units each turn.
  - That war on France came from CP's own approach.
- **Role game (0DB01EF0, Mongolia with RoleFixes):**
  - Window vs the Shoshone at T42; war at T73 (a coop war with the Ottomans); SiegeRoll moved 6 units at T79.
  - The attack ended in place at T84, then no city attack at all to T150.
  - Requests failed "for lack of units": Kathmandu T89, Beijing T90. With 0 missing units allowed at war, the siege
    formation's 6 required slots couldn't be met, the same as the six e4d5785 games behind SecondWave. Here it failed
    before the operation even formed, so no NoUnits lines.
  - SiegeDominated looked at Te-Moak, Guangzhou and Pohokwi with 1 unit and correctly stayed skipped.
- **Read, corrected after a closer look (the user didn't buy the first one).** The first read blamed missing second
  waves. The role game's war was lost long before that:
  - **The war came on someone else's clock.** The Ottomans agreed a coop war against the Shoshone at T63 (PREPARING),
    and it declared itself at T73. FocusedWar allows coop wars against the committed target, so Mongolia went to war
    with what it had: attack 1659 was 3 Warriors, 2 Archers and Kublai (a Great General), no siege unit.
  - **The window built almost nothing.**
    - TimingBuildup's window ran T42–T52 (10 turns on this speed). Only the capital built military: 2 Warriors and an
      Archer, with unit weights about 4,900 against 450 for buildings.
    - Turfan skipped every military unit as "badtimeorplace": CP's "no units in underdeveloped cities" rule, under 2
      buildings.
    - Beshbalik skipped them as "nosupply" at T53. That is the recommended army size, not real supply: the window's
      cities+6 target ends with the window, and the attack phase falls back to CP's small early target.
    - Hsia couldn't afford buildings (−7 gold a turn).
  - **At Te-Moak the army never attacked.**
    - The zone was EXPLOIT_FLANKS (not ours), so SiegeClose and SiegeDominated didn't apply; the city stayed at 200/200
      from T81 to T90.
    - From T93 the Shoshone had 6 units there (enemy 13859 against our 4038), and they killed the army: 8 units lost
      T91–T100, 6 of them to the Shoshone.
    - The flip lost none.
  - **The flip's army was no better** (Warriors, a Swordsman, a Catapult, an Archer, a general). CP kept it alive, and
    its own target choice found Troyes, a French city soft enough for 115 expected damage a turn.
- **What this points at:**
  1. A coop war against the committed target shouldn't declare before the army is ready.
  2. The window's push (army target and unit weights) should last until the army is ready, not 10 turns.
  3. Young cities can't build military at all during the window.

  SecondWave can't help an army that is already dead.

### War: the lead's regression flag (declared in 1 of 4 first games on ab-7bb7885, 11 of 12 on e4d5785): 0E62C44F read (Nov 4, about 11:16pm ET)
**0E62C44F (Aztecs, PC 1):**
- **The target:** window vs Denmark at T80; "CONQUEST: going for Denmark" at T104, Greece at T120.
  - Toward Denmark: approach WAR, strength PATHETIC, TGT Soft every turn T100–T105.
  - Aarhus was the preferred attack target (score 6450).
- **Every attack request on Denmark failed:** "requested attack on, Kaupang … not possible for lack of units" (T82, T100);
  likewise Aarhus (T100).
- **Where the units were:** attacks on Byblos, a city-state.
  - 1635 (T85, 6 units recruited) and then 2011 (T107, 8 units) stood in recruiting.
  - SiegeArmy's peace bar held them: "expected damage 38–50 a turn, Byblos needs 70". Each timed out at 20 turns
    (T106, T128).
  - 42 turns of the army in a city-state attack while the window and attack on Denmark ran.
- **"No war 3 windows after the build-up" at T121** (back to the peace army); war came at T126 (window vs Greece).

**Read.** In this game the declaration on the major is blocked by the city-state attack holding the army, not by the
siege flags. The same shape is in 0E42C140 (Mongolia: 6–7 units at Zurich, 3 at Denmark). CSAfterWar (in f6d1e84,
running now) is aimed at exactly this: no WAR approach to city-states while the window or attack on the committed
major runs, so CP's minor-civ logic ends a city-state attack already gathering and Denmark's requests find units.

**For the 1-of-4 count:**
- Carthage 0D82E4A9: wars came to it; my entry below.
- FocusedWar is new in this role. It removes wars on anyone but the committed target, so wars on others that e4d5785's
  count included can't happen now. A count of wars on the committed target alone would separate that from a real
  regression.
- None of SiegeClose, SiegeDominated or the at-war bar act before a war. MarchOn's wait at the walls (`a6a9f399`) only
  starts once an army is at the target, and no army reached Denmark in this game.

### War: 0D9905E5 (Aztecs) and 0D82E4A9 (Carthage), PC 1 on ab-7bb7885: SiegeClose fills the zone; a new army for the same city takes the besiegers; SiegeFeed (Nov 4, about 11:10pm ET)
- **Aztecs at Ribe (Denmark), T130–T150:**
  - SiegeClose fired every turn ("zone 1836 (Ribe) is ours, moving units in reach up around the city").
  - The zone-strength line shows our units there growing from 2 to 11 (friendly 3766 → 29581 against enemy 5000–6500;
    city HP 153–200).
  - But each capture attempt had only 1–3 units within striking distance: Ribe 173 → 173, 167 → 167, 183 → 156; later
    200 → 172.
  - **Why:** attack 3401, a new CP city attack on Ribe itself (target 18:30, muster 14:25), started at war at T129
    and recruited 5 units on the spot, more as they came.
  - Its army was in recruiting ("Gathering army 3402" each turn, units at 17–23:25–29, around Ribe), hidden from the
    tactical AI for 10 turns.
  - Then "SiegeRoll: target 3 tiles from the muster point, moving with 4 units" (T139) and HalfStrength at T142.
  - Two Rapid Response operations (3566, 3590) also held units near Ribe.
  - So the units SiegeClose brought up were standing in the zone inside armies, not attacking.
- **Carthage (0D82E4A9):**
  - Windows vs the Zulus (T37) and Byzantium (T114); "at war" closed both windows (T54, T120).
  - Attack 2259 ended "War goal changed" at T120 (TargetHold's second part is not in ab-7bb7885).
  - SiegeDominated looked twice and stayed skipped (1 unit, expected 0).
  - The lead's note says Carthage never declared; the wars came to it.

**Hypothesis (flag SiegeFeed, War, CvMilitaryAI::RequestCityAttack):** while one of our sieges is on at a city (at war,
its land zone dominated by us with 3 or more of our units in it), no new attack operation is started against that city.
The units in reach go in as tactical reinforcements (SiegeClose) instead of being held in a gathering army beside the
walls. Other cities of the same enemy can still get attacks, and once the siege collapses (zone no longer ours) a new
wave can form (SecondWave). Logs "SiegeFeed: X is under siege (n units in the zone), no new army for it" in the
military log. Expect: no "Gathering army" for a city attack on the city being besieged, and more units within
striking distance per capture attempt.

Coded: `ai/war` `1fe84572f` (built, CI run 215), on `0ccd0e07e` (CSAfterWar, in `claude/ab-c1` `f6d1e84`).

### War: CSAfterWar, city-state conquest waits while the war on the committed major is building or on (the lead's request, 10:55pm ET) (Nov 4, about 10:55pm ET)
**Seen:** in 0E42C140 (ab-7bb7885) Mongolia's attacks on its committed target Denmark had 3 units each (four of them,
T77–T132). At the same time, attacks on Zurich, a city-state, got 6 and 7 units (2708 at T112, 3653 at T141). CSConquest
(the user's: "true bullies take city-states") makes WAR the top approach toward a weak, close, unguarded city-state
whenever we're at war with no major. That includes the peace phase, while the army for the committed major is
being built and gathered, so the two compete for the same units. The lead: "not at the cost of the main war".

**Hypothesis (flag CSAfterWar, War; shared: CvDiplomacyAI::SelectBestApproachTowardsMinorCiv):** while a war on the
committed conquest target is building or under way, a city-state we're not already at war with gets no WAR
approach: CSConquest's boost is skipped and CP's own WAR weight toward it is zeroed (FocusedWar does this for other
majors). "Building or under way" means TimingBuildup's window or attack phase, an offensive operation against the
committed target, or a war with it. Between wars and after them CSConquest works as before. An attack on a city-state
already gathering is ended by CP's own minor approach logic once the approach isn't WAR, so its units go back.
Expect: no city-state attacks while the window or attack on the major runs, bigger first armies against the major,
and city-state captures still happening between wars.

Coded: `ai/war` `0ccd0e07e` (built in `claude/ab-c1` `f6d1e84`, CI run 214; its own run cancelled by the lead), on `61af66972` (merged by the lead in `claude/ab-c1` `ad5a2d8`).

### War: TargetHold, second part: the held target stays a war plan in DoUpdateWarTargets (the lead's read of 0E42C140, 10:46pm ET) (Nov 4, about 10:51pm ET)
**The lead:** in 0E42C140 (ab-7bb7885, TargetHold on) Mongolia's sneak attacks on Denmark still ended DiploOpinionChange
(T111, twice at T140), so TargetHold doesn't cover that. Also: window vs Egypt at T56 (paused 10 turns, units
unaffordable), "no war 3 windows after the build-up" at T97, a new window vs Denmark at T98. These lines are in the
military log, which I missed in my entry above.

**Cause.** The approach log is written in approach selection, where Denmark's approach is WAR every turn T76–T150.
DoUpdateWarTargets runs after it and resets the approach of anyone it doesn't keep as a war target ("make sure we don't
have the WAR approach if we're not planning war"). That reset is what cancels the sneak attack ("War goal changed").
The conquest target is kept as a war plan only when GetNewAIConquestTarget returns it. With TimingBuildup that is
NO_PLAYER on purpose while a window runs and the army isn't ready (T98 onward here), even with an attack on the
target already gathering (2145 from T94). Denmark then has to pass CP's filters (conflict limit: 10 in the first two
eras; war sanity; the approach value), and one failing turn resets it. TargetHold only covered GetNewAIConquestTarget's
own checks.

**Change (TargetHold, second part; shared: CvDiplomacyAI::DoUpdateWarTargets):** the committed target
(m_eNewAIConquestTarget, set even while a window runs) counts as a war plan while an offensive operation against it
is under way, as the returned target already does. A war still needs the army in place: SiegeArmy's peace bar and the
window keep a weak army from declaring. Logs "CONQUEST: holding X as a war plan, attack under way" once a turn when this
is what keeps it. TargetHold is in the role on ab-7bb7885, so its results so far are the first part alone.

Coded: `ai/war` `61af66972` (built, CI run 211), on `96332cc83` (SecondWave); both merged by the lead in `claude/ab-c1` `ad5a2d8`.

**On the lead's other point (SiegeArmy "too weak" for 20 turns against greedy civs):** that is the peace bar doing
its job with a 3-unit army. The army was small because the window was paused 10 of its turns for gold ("units
unaffordable", T60–T71), and the attacks' units went to Zurich (6–7 units). Gold is Economy's (WarChest/WarGold);
whether attacks on city-states should stand aside for a committed target is a question for the next games.

### War: 0E42C140, the first game on ab-7bb7885 (PC 2, bullygreedy12): Mongolia never declared; armies of 3 held at peace (Nov 4, about 10:49pm ET)
- **Target:** "CONQUEST: going for Denmark" at T76. No TimingBuildup window line for Mongolia in this game.
- **Attacks on Copenhagen (47:31):** 1785 (T77, 3 units), 2145 (T94, 3), 3191 (T124, 3) and 3441 (T132, 3).
  - SiegeArmy held them at peace: "expected damage 26 a turn, Copenhagen needs 60"; 1785 timed out at 20 turns (T97).
  - 2145, 3191 and 3441 ended "War goal changed" / DiploOpinionChange (T111, T140), with the approach toward Denmark
    WAR throughout. So this isn't the target flip TargetHold covers: another war goal took over (the city-state below),
    and no "CONQUEST: holding" line appears.
- **Attacks on Zurich (31:37, a city-state):** 2708 (T112, 6 units; SiegeArmy timeout at T132) and 3653 (T141, 7 units,
  28–32 of 75).
- **No war on a major, so no SiegeClose, SiegeDominated or zone-strength lines.**

**Read.** The peace bar did its job (no war with 3 units), but the army never grew: four attacks on the target recruited
3 units each in 75 turns, and the biggest armies (6–7) went to a city-state. One game; the next ones decide whether
this is the new pattern. If it is, the question is the army size in the peace phase (no TimingBuildup window here) and
city-state attacks taking the units, not the siege.

### War: SecondWave, a new attack at war may start with up to 3 units still to come (Nov 4, about 10:26pm ET)
**Seen in 6 games on ab-e4d5785:** after the first attack is used up, new attacks on the target end NoUnits the turn
they start:
- Aztecs 0D47DC20: 8 times;
- Ottomans 0D5ECB7F: 12 times;
- Assyria 0DD77369: T106–T109;
- Inca 0DF72455: T140;
- Mongolia 0D313EB5: T79–T85;
- Germany 0E192EC1: no second attack on Heliopolis after T117.

The pattern is "Started Army; Units Recruited 3 … Ended: NoUnits; Duration 0". The siege formation (BASIC_CITY_ATTACK_FORCE
under SiegeFormation) has 6 required slots. At war CvMilitaryAI::DoCityAttacks asks RequestCityAttack(target, 2) without
"careful", which allows 0 missing units, outside TimingBuildup's window and attack phases (`f73177c`). TimingBuildup
closes its window when the war starts, so its allowance ends then too. Nothing in the merged build changes this.

**Hypothesis (flag SecondWave, War, CvMilitaryAI::RequestCityAttack):** at war with the target, a major, an attack may
form with up to 3 required slots still empty (the units willing to build, at least 3). The operation's own build
requests fill them, and SiegeArmy's at-war bar (`b7db863`) and SiegeRoll decide when it marches. Expect: fewer NoUnits
lines at war, and second attacks reaching a city the first one damaged. Risk: up to 3 units in recruiting are hidden
from the tactical AI while they wait, for at most SiegeArmy's 20 turns.

Coded: `ai/war` `96332cc83` (built, CI run 210), after the lead's merge of `e2397128f`.

### War: 0D5ECB7F (Ottomans), 0E192EC1 (Germany), 0D47DC20 (Aztecs) on ab-e4d5785: real sieges, each worn out about 20 HP short a turn (Nov 4, about 9:54pm ET)
- **Germany vs Heliopolis (0E192EC1):**
  - Attack 2138 was handed over 3–5 tiles out at T109–T110.
  - Attempts T110–T116 with 2–5 units, 21–50 damage a turn; the city went down to 117 of 200.
  - Heliopolis healed about 20 a turn (155 → 175, 125 → 145, 119 → 139).
  - From T117 the expected damage fell to 9, then 0 ("too early for attacking"): the army was spent and none came
    after it.
- **The Ottomans vs Raiatea (0D5ECB7F):** T95–T101, 1–3 units, 15–31 a turn, 200 → 104, healing about 10–20 a turn
  in between. Then nothing.
- **The Aztecs (0D47DC20):** windows against France (T43) and Denmark (T133); 8 attacks ended NoUnits. A city-state
  (Belgrade) made the only capture attempts in that game.

**Read.** The attacks that arrive now hit the city, but with 1–5 units doing about what the city heals, plus 20–30
a turn, they wear out before it falls, and no second wave follows (NoUnits at war again). SiegeClose (the rest of the
army in reach) and SiegeDominated (the merged build, `claude/ab-c1` `7bb7885`) add units to the first wave. If the new
build still shows sieges dying at half HP, the next fix is the second wave: at war, a new attack on the same city may
start with missing units, as TimingBuildup's phases already allow (RequestCityAttack).

### War: SiegeDominated, attacking from an enemy-dominated zone when the army at the walls can take the city (the lead's request, 9:20pm ET) (Nov 4, about 9:36pm ET)
**The lead's tally on ab-e4d5785:** 11 pairs, the aggressor declared in most games, 1 capture. The Zulus took
Shanghai in 0DB8F250 at T96 (window vs China at T62, MarchOn declared at T92, 80 → 22 HP with 5 of 6 units at T95).
Correction: my 0D03FDB9 entry says no candidate aggressor ran in 0DB8F250; it did (I looked for CONQUEST lines,
which that game doesn't have).

**The blocker in every game:** "City of X, is in enemy dominated zone - won't try to capture" (Beijing T93 and
Nanjing T99–T103 in 0DB8F250, Addis Ababa T113–T119 in 0D7BB38D; 11–38 times a city in the other games).
ExecuteCaptureCityMoves skips the city before it even looks at which units can strike it. The zone counts the city as
enemy ranged strength and only units within 4 tiles (Ancient/Classical), and it needs enemy strength over 1.7 times
ours, so a siege army at the walls of a defended city often reads as outnumbered.

**Hypothesis (flag SiegeDominated, War, CvTacticalAI::ExecuteCaptureCityMoves):** at a city of a major we're at war
with, an enemy-dominated zone doesn't skip the city outright. The units within striking distance are found as usual.
The attack goes ahead if at least 3 can strike and their expected damage, less the city's healing, would take the
city's HP within 3 turns. Otherwise the skip stands, logged with the numbers. The healing and melee checks after it are
unchanged. Logs "SiegeDominated: attacking X in an enemy-dominated zone (n units, expected e a turn, h HP to go)" or
"SiegeDominated: X stays skipped (…)". Expect: attempts at cities that read enemy dominated with the army there, and
more captures. Risk: the expected damage runs high (Busan read 41–59 with 10–23 done), so the 3-turn bar is strict
on purpose.

Coded: `ai/war` `e2397128f` (built, CI run 207); merged by the lead in `claude/ab-c1` `7bb7885` with SiegeClose and TargetHold. For the bully role, it goes with SiegeClose (moves the rest of the army up
when the zone is ours) and TargetHold.

### War: 0D1A71BD (Huns), 0D313EB5 (Mongolia), 0DF72455 (Inca), all on ab-e4d5785: the same failures, all fixed after it; one open question (Nov 4, about 9:21pm ET)
- **Huns:**
  - Committed to Arabia at T53, then to Ethiopia at T71.
  - Attacks ended DiploOpinionChange at T75 and T111 (TargetHold).
  - MarchOn's old stall rule handed over at T92 and T147 (`6578838`).
  - No capture attempt; target cities enemy dominated 13–23 times.
- **Mongolia:**
  - Persia at T69, Brazil at T77.
  - DiploOpinionChange at T77, T97 and twice at T150 (TargetHold); NoUnits three times at T79–T85.
  - No capture attempt.
- **Inca:**
  - Committed to India at T36.
  - SiegeArmy timed out three attacks at T67–T90 (at peace, so `b7db863` doesn't apply; the peace bar is meant to
    hold these).
  - DeclareWhenGathered at T99.
- **Capture attempts on Mumbai and Delhi (T119–T125):** 0 damage every time, though 1–5 units were "used" a turn
  and 43–47 was expected. Units used without damage moved, they didn't attack. Open: the attempt log doesn't
  say which units attacked. If games on the new build show the same, the next step is logging each unit's chosen
  move in the capture sim.
- **NoUnits at war:** new attacks at once NoUnits (Inca T140, Mongolia T79–T85, Assyria in 0DD77369 T106–T109).
  RequestCityAttack allows no missing units at war outside TimingBuildup's phases, so after the first army is used up,
  a new one can't start until a full formation exists. Candidate for a later fix if the new build still shows it.

### War: 0DD77369 (PC 2, ab-e4d5785 + WarGold), Assyria: capture attempts at last, 3 units at a time (Nov 4, about 8:49pm ET)
- **Busan (Korea):**
  - Attack 1795 recruited 8 units: 3 Swordsmen, a Siege Tower, a Catapult, an Archer, a Chariot Archer and one more.
  - It was discovered at T97 (MarchOn declared) and handed over by the old stall rule at T99.
- **The first capture attempts in a logged game since the attempt log (`9e9fc9d`):** Busan, T100–T103, zone
  P_STEAMROLL, 3 units used each turn.
  - Busan's HP went 200 → 200, 200 → 177, 197 → 187, 200 → 190.
  - Expected damage was 41–59 a turn; the city healed back each turn.
  - The other 5 units never joined.
- **T106–T109:** three new attacks on Busan each ended NoUnits at once (3 recruited of the formation; no missing
  units allowed at war outside TimingBuildup's phases).
- **The Inca, committed at T130:**
  - Attacks 3172 and 3012 ended DiploOpinionChange at T141 and T143 (the target flip TargetHold fixes).
  - Attack 3229 declared by DeclareWhenGathered at T149 and attacked Cusco at T152 (250 → 235, 4 of 4 units).
- **WarChest:** one purchase (a Siege Tower, T83).

**Read.** This is the SiegeClose case on a city we did attack. With the zone ours (STEAMROLL), only units within
striking distance attacked; the rest of the 8 were never moved up. 3 units can't beat a city's healing. The 13-turn
estimate counts every unit in reach, so it read 41–59 against 10–23 done. No new fix: SiegeClose (`c588aa8fa`) and
TargetHold (`eab859e4d`) cover what went wrong here; the next logged games need a build with both.

### War: 0D03FDB9 (Mongolia) and 0CED9749 (Songhai), PC 1 bully abort9 on ab-e4d5785: the committed target is dropped for a turn and the attack under way is cancelled (Nov 4, about 8:26pm ET)
- **0D03FDB9, Mongolia never declared** (the lead's note).
  - "CONQUEST: going for The Netherlands" at T76, T79, T89 and T113. Each one is a return to WAR after a turn
    without it.
  - The approach toward the Netherlands flips WAR ↔ DECEPTIVE/GUARDED every few turns from T72 to T150.
  - Each flip ends the sneak attack being gathered: about ten attacks against 56:37 ended "War goal changed,
    probably another war is more important" / "DiploOpinionChange" after 1–8 turns (T72, 78, 87, 96, 98, 106, 123…),
    with 3–4 units recruited each time.
  - No TimingBuildup lines: this role runs the timing attack without the build-up.
- **0CED9749, Songhai.**
  - The Korea attack (1443, T64) ended "DiploOpinionChange" at T78; at T80 the target became the Shoshone.
  - The Shoshone attack 1657 was handed over by the old MarchOn stall rule at T90 (fixed in `6578838`, not on
    this build).
  - Attacks 1739 and 2624 timed out in SiegeArmy at 20 turns (the bar at war is `b7db863`, not on this build).
  - No capture attempt; Goshute and Agaidika read enemy dominated 29 and 12 times.
- **0DB8F250 (pair 3 on PC 2, Zulus):** no CONQUEST or TimingBuildup line in either game, so no candidate
  aggressor's war to read.

**Cause.** GetNewAIConquestTarget keeps a committed target only while it passes every check again, with one strength
step of slack. One turn failing the strength comparison, HavePossibleAttackTarget / IsWarWouldBankruptUs or CanWin
(CanTakeNearestCity) clears the commitment (m_eNewAIConquestTarget = the turn's best, often NO_PLAYER). The WAR boost
is lost, SetCivApproach cancels the sneak attack, and the next turn starts a new one from nothing. These checks swing
from turn to turn as units join the army, move or heal, and as gold changes.

**Hypothesis (flag TargetHold, War; shared: CvDiplomacyAI::GetNewAIConquestTarget):** while an offensive operation
against the committed target is under way, failing the strength, attack-target/bankruptcy or CanWin check doesn't drop
the target. The hard checks still do: can't declare war, not close, a defensive ally would join. The operation's own
limits (SiegeArmy's 20 turns, SiegeAbort) end a hopeless attack. Log: "CONQUEST: holding X, attack under way (failed:
reason)", once a turn. Expect: no runs of "War goal changed" against the committed target, the attack gathered to the
end, and the failed check named in the log.

Coded: `ai/war` `eab859e4d` (built, CI run 206). SiegeArmy's bar at peace still keeps a weak army from declaring, so a
held target with CanWin failing waits rather than marching.

### War: 0D9AF4AA (PC 2, ab-e4d5785 + WarGold), Assyria: the army reached Hamburg with the zone in our favour, and the tactical AI sent it home (Nov 4, about 7:39pm ET)
- **Plan:** TimingBuildup window T26 against Germany; "CONQUEST: going for Germany" at T36; war at T102.
- **Attack 1819** (target Hamburg, 27:23): 2 Spearmen, a Swordsman, 3 Siege Towers and an Archer.
  - SiegeArmy held it at 51 of 60 at T99; war at T102; moving at T103.
  - **T106:** "Transition to finished stage; near 2, far 5". The army was handed to the tactical AI 2–5 tiles out.
- **T105–T110:** Hamburg's zone posture was **P_STEAMROLL** (we dominate), yet no "attempting capture",
  "too early" or "capture attempt" line for Hamburg.
- **T107–T112 in the homeland log:**
  - the Swordsman: "Moving Swordsman 2009 to garrison" (34:28);
  - the Spearmen: to garrison (24:30) and to a sentry point;
  - the Siege Towers and a Spearman: "Explored to target" at 37:28 and 38:26, east, away from Hamburg.
- **T112:** Hamburg's zone turned enemy dominated (P_WITHDRAW); the Archer was killed withdrawing at T115.

**Cause.** In a friendly-dominated zone the tactical AI only attacks the city with units within striking distance
this turn (ExecuteCaptureCityMoves → FindUnitsWithinStrikingDistance; when none can strike it skips the city without
a log line). Moving units closer is PlotReinforcementMoves' job, which returns at once when the zone is dominated in
both overall and ranged strength ("we do not need further reinforcement") unless we have no melee at all. So an army
handed over 2–5 tiles out at a city we dominate gets no tactical move, and the homeland AI takes it home. This
fits the "enemy dominated" counts in the other games too: the zone tips the other way after the army leaves.

**Hypothesis (flag SiegeClose, War, CvTacticalAI::PlotReinforcementMoves):** at an enemy major's city we're at war with
(land zone), friendly dominance doesn't end the reinforcement step. Units in reach are positioned around the city
(PositionUnitsAroundTarget), so the next turn's capture step finds them within striking distance. If friendly melee is
0, still melee only, as now. Expect: "attempting capture" lines after a handover at a STEAMROLL zone, units staying at
the target instead of garrison or explore moves, and captures in the bully games. Risk: units pulled from friendly
zones at home while a war is on; the existing check already keeps units in zones that need them.

Coded: `ai/war` `c588aa8fa` (built, CI run 205). Log line: "SiegeClose: zone N (city) is ours, moving units in reach up around
the city". For the bully role: SiegeClose goes with MarchOn, SiegeArmy and TimingBuildup.

### War: 0CC09E9A (America) and 0CD7657A (Huns), PC 1 on ab-e4d5785: wars on the target, early handovers, enemy-dominated zones, no captures (Nov 4, about 7:35pm ET)
- **0CC09E9A, America.**
  - Windows: T62 against the Shoshone (closed at war, T99) and T138 against the Inca.
  - "CONQUEST: going for The Shoshone" at T81, then the Inca at T82; war on the Inca at T99.
  - Attack 1963 was discovered at T98; "MarchOn: stalled near the target at war, handing over" at T101, the war's
    second turn.
  - Attack 2229: SiegeArmy aborted it at T112.
  - Attack 3012: SiegeRoll with 4 units, handed over at T125.
  - No capture attempt. Tiwanaku and Machu read "enemy dominated" 38 times each; the Inca zones' posture was
    P_WITHDRAW.
  - 16 "window paused" lines (turns to bankruptcy under 9); no WAR CHEST purchase.
- **0CD7657A, Huns.**
  - Window at T51 against the Maya; war on the Maya at T84, on Siam at T123.
  - Attack 1770 was handed over by the MarchOn stall rule at T99.
  - No capture attempt; every target city read "enemy dominated" 11–28 times; no WAR CHEST purchase.

**Read.** ab-e4d5785 has none of `6578838` (stall rule counts turns at war only), `a6a9f399` (MarchOn waits at the
walls; ATTACK phase when the target is returned) or `b7db863` (SiegeArmy's bar at war). The early handovers and the
SiegeArmy abort here are the cases those three fix. What they don't fix:
- **Small armies:** 3–5 units reach the target, so the zone reads enemy dominated and ExecuteCaptureCityMoves won't try.
- **Gold:** the windows pause on the bankruptcy guard and no WAR CHEST purchase shows (Economy's area).

No new fix from these two games; the next logged games on a build with the three commits will show whether the army
now arrives whole.

**Diagnostic (logging only):** `ai/war` `78437e098` (built, CI run 204) adds the zone strengths to the tactical log's zone line for enemy
cities: "friendly S (n units, melee, ranged), enemy S (n units, melee, ranged, city HP)". A zone reads enemy dominated
when enemy strength is over 1.7 times ours (CvTacticalDominanceZone::SetOverallDominance); the city counts as enemy
ranged strength, and only units within 4 tiles of the city (Ancient and Classical) or in the zone count. The posture
is also P_WITHDRAW when enemy melee is over 3 times ours and our ranged is over 3 times our melee (a siege-heavy army,
which the window's siege weight makes likely). The numbers will tell which case it is.

### War: 0D7BB38D (PC 2, ab-e4d5785 + WarGold), the Aztecs: MarchOn ends at the walls before the war; TimingBuildup demobilises during an attack (Nov 4, about 7:06pm ET)
- **First war, on Ethiopia at T92** (window at T78; Greece joined the same turn). The one attack (5 units) waited out
  SiegeArmy's 20 turns and was aborted at T108. Peace by T124.
- **Second war, on Greece.**
  - **T129:** "CONQUEST: going for Greece" with the army already ready, so no window opened.
  - **T136:** sneak attack 3023 "Discovered by enemy" and "MarchOn: declaring, the army marches on; near 3, far 6".
  - **T137:** "Transition to finished stage; near 1, far 5". The army was at the walls and the operation ended.
  - **T141:** the war actually came (the diplomacy AI declared 5 turns after the army was in place).
  - Result: the army was disbanded at the walls 4 turns before the war; no capture attempt in the whole game.
- **During that attack TimingBuildup demobilised:** "peace, 14 land units over a cap of 8, letting Composite Bowman
  go" (T134), then two Swordsmen (T135, T136).
  - The target came back without a window (the army was ready), so the phase stayed PLANNED, which counts as peace.
  - So the cap and the demobilisation applied during the attack.
- **WarChest:** no "WAR CHEST" purchase line in the game.

**Fixes (refinements of MarchOn and TimingBuildup, under their own flags):**
1. **MarchOn:** at peace, an army in place at the walls asks for the war but keeps waiting, as one army, until the
   war comes. It still falls back to ending after 5 stalled turns at peace.
2. **TimingBuildup:** when the conquest target is returned (the army ready, or the window over), the attack phase
   starts if it hasn't. The phase becomes ATTACK, not PLANNED, so no cap and no demobilisation while the attack is
   on.
3. **SiegeArmy's bar at war (the lead's read: "the army times out on the way").**
   - Attack 1906 against Addis Ababa recruited 2 Swordsmen, 1–2 Jaguars, 2 Catapults and an Archer: 40–45 expected
     a turn against a bar of 60.
   - It sat 20 turns in recruiting after the war began (T92), its units hidden from the tactical AI, then SiegeAbort
     at 67–75% of the bar.
   - Addis Ababa's zone then read "enemy dominated" every turn T113–T119.
   - The bar exists so a weak army doesn't declare a war. Once at war with the target, the tactical AI's own rule
     applies instead: an attack is worth it if 13 turns of damage beat the city's healing. **At war with the target,
     the bar becomes healing + max HP / 13** (36 for 200 HP, 40 for 250); at 45 a turn this attack would have
     marched at once. At peace (sneak attacks) the bar is unchanged.

Coded: `ai/war` `a6a9f399` (fixes 1 and 2; built, CI run 202), `b7db863` (fix 3; built, CI run 203).


### War: four logged games on ab-f73177c and ab-eb4129d: wars come now; armies are small; MarchOn handed over too early (Nov 4, about 6:36pm ET)

| Game | Build | Aggressor | Windows | War | At the walls |
|---|---|---|---|---|---|
| 0C751A63 | f73177c | Celts | T26 against the Iroquois (Quick: the window opens at turn 26) | **On the target at T47**, before any attack had formed | First attack at T72: a SiegeRoll wave of 5 units (SiegeConcentrate held it 4 turns, from 4 in the army). Capture attempts T80–T81 on Osininka, 200 → 190 and 200 → 189, all 3–4 units used. Later sneak attacks sat at 32–48 a turn against bars of 70–75 and were aborted |
| 0C902E79 | f73177c | Huns | T26 and T58 against Germany | **On the target at T72**, via MarchOn ("declaring, the army marches on; near 3, far 7") | **T73: "MarchOn: stalled near the target at war, handing over", near 3, far 8**, on the war's first turn. One capture attempt (Hamburg, 0 of 1 units used); every German city "enemy dominated" 38–78 times |
| 0CA81AA0 | eb4129d | Shoshone | T61 and T93 against Portugal | War on Ethiopia at T120 | — |
| 0D5A2506 | eb4129d | America | T34 and T66 against China | China declared on America at T94 | — |

- In the Shoshone game the T93 window **paused 9 turns** ("units unaffordable"); America's T66 window paused 9 too.
  Both were short of gold: WarChest-in-peace and WarGold come only in e4d5785.

**Findings:**
1. **Wars on the target come now** (Celts, Huns). The trio fix, FocusedWar and `f73177c` work.
2. **The armies are small:** 3–5 units with 37–50 expected damage a turn. Cities lose about 10 HP a turn and every
   zone reads "enemy dominated". The Celts declared at T47 on Quick with no attack formed. The Huns' sneak attack
   recruited 3 units in 16 turns.
3. **Bug: MarchOn's at-war stall rule fired on the first turn of the war.** It counted the turns the army spent
   waiting at the border at peace. **Fixed in `6578838` (built, CI run 201):** it now needs 3 turns at war.

**Next (proposal, not coded):** the declaration should wait for the army. Readiness (2 siege units and cities + 4
others) is checked only at the window's end. The Celts' war at T47 came from the committed target's WAR approach,
before any army or operation. Suggest: under TimingBuildup, the WAR approach (+1000) toward the target applies only
from readiness, or once the window is over with the army ready. This is the lead's call on scope, and Economy's gold
fixes in e4d5785 need to be in first.

### War: 0D3416E7 (PC 2, bullygreedy9 on ab-f73177c): the build-up happened, the war didn't (Nov 4, about 6:03pm ET)
From the results file; the logs were deleted (the aggressor declared no war).

| Game | Civ | T60 | T80 | T100 | T150 | Wars | Captures |
|---|---|---|---|---|---|---|---|
| Role | China | 4 land units, military 28 | 9 land, military 101 | 13 land, military 138 | 15 land, military 219 | 0 | 0 |
| Flip | China | 4 land | 5 land | 6 land | 8 land, military 94 | 0 | 0 |

- Gold in the role game: 128 at T60, 8 at T80, 52 at T100.
- **So TimingBuildup's window now builds** (the window weight `214c6c7` and `f73177c` were in this build). What's
  missing is the step from army to war.
- **Possible blocks after the window:**
  - the strength check and CanWin apply again, with the real army;
  - the sneak attack forms, but SiegeArmy or the declaration path (DeclareAtBorder, DeclareWhenGathered, MarchOn,
    then `SetArmyInPlaceForAttack` and the diplomacy AI's declaration) stops;
  - or the diplomacy AI refuses the declaration (peace treaty, bankruptcy check).
- **Needs:** a logged game where the aggressor builds up but doesn't declare. Ask the PCs to keep first-game logs
  even with 0 wars (the lead's plan from eb4129d on).

### War: two more games on the old ab-f21a8f6 build (0C4F5988 Songhai, 0D0DC744 Zulus); SiegeAbort near the bar (Nov 4, about 5:34pm ET)
Both ran before MarchOn, FocusedWar, the window fixes, the trio target fix and `f73177c`, so they mostly show causes
already fixed.

**0D0DC744, the Zulus.**
- Windows: against Russia at T43 (ended "no war 3 windows"), then against Brazil at T75.
- **147 attack requests, all "lack of units"**, and no attack operation formed. That's the 0-missing rule, fixed by
  `f73177c`.
- Brazil and Russia declared on the Zulus at T82: a defensive war, with Novgorod and Rio "enemy dominated" 25–30
  times each and Moscow "too early" 11 times.

**0C4F5988, Songhai.**
- **T67:** window against Assyria. **T73:** "CONQUEST: going for Assyria", a sneak attack with **7 units**, target
  Zanzibar, 4 tiles from the muster point.
- **SiegeArmy held it 20 turns:** "expected damage 39 → 57 → 49 a turn; Zanzibar needs 60 (70 with walls)". Then
  SiegeAbort at T93.
- Later attacks:
  - six sneak attacks ended NoUnits at creation (T106–T107), on the old 0-missing rule;
  - one recruited 19 turns and ended by a diplomacy change;
  - one marched at T135.
- No capture attempt.
- **New:** an army at 57 of 60 a turn waited 20 turns and was thrown away. At 57 a turn against a 250 HP city healing
  20, the city falls in about 7 turns; the tactical AI's own check allows 13.

**Fix (SiegeAbort, a refinement of its own rule):** at the 20-turn mark the attack is called off only if its
expected damage is below 85% of SiegeArmy's bar. An army that close marches; the tactical AI's 13-turn check still
decides whether it attacks. Logged "SiegeArmy: close to the bar after 20 turns (x of y), marching".

Coded: `ai/war` `460536b` (built, CI run 197); merged in `claude/ab-c1` `e4d5785`.

### War: why the Aztecs' gold was low in the 0C3C8913 replay (with Economy) (Nov 4, about 5:25pm ET)
The lead: a timing attacker must never sit near bankruptcy at peace. The role had TrueGoldRate, WarEconomy and
WarChest on.

**1. WarChest never saved.**
- It saves only in PLANNED and WINDOW. The Aztecs had no PLANNED phase: their first target came at T81, already
  past turn 40, so the window opened at once.
- Before that the phase was PEACE, in which `DoWarChest` cancels the savings request. TimingBuildup's own stand-in
  saving (from T30, peace included) is switched off under WarChest.
- So nothing was saved from T30 to T81.
- **Proposed to Economy:** save in PEACE too, from turn 30, at least 2 siege units' price.

**2. The deficit was the economy's, from early on.**
- Gold per turn on the production lines: 0 at T0, −2 at T40, −4 at T50, −10 at T80, then −8 to −13 through T108.
- The new choices T1–T80 were 7 settlers, 3 caravans, 3 Floating Gardens, 2 wonders, workers and work boats, and
  almost no military (2 scouts, 1 Jaguar).
- So the cause is expansion, building and wonder upkeep without matching gold income, not army upkeep.
- WarChest's +500 for gold buildings applies only from the window on.
- Economy owns these weights; sent to Economy at 5:25pm ET.

**3. War's part:** `f863b01` and `69c9587`. The pause treats the symptom, as the lead notes; the cause is items 1
and 2.

### War: the 0C3C8913 replay (Aztecs, ab-96f008e + MarchOn, FocusedWar): the window opened, but the units were "too expensive" (Nov 4, about 5:09pm ET)
- **TimingBuildup worked up to the window:** "T81 window opens for 10 turns against Austria". The trio fix let a
  target through: Austria, military 82 against the Aztecs' 36.
- **The window built no army.**
  - Production T81–T91: Pyramids, workers, a caravansary, a circus, settlers.
  - **82 units were refused "tooexpensive" in those turns**, including the operation's own Swordsman (weight 10332)
    and the window's "Army unit" Swordsman (3000).
  - Gold per turn on the production lines T60–T108 ran −13 to +8, mostly negative.
  - The refusal is CP's upkeep guard (`CvUnitProductionAI::CheckUnitBuildSanity`): no combat unit when the treasury
    goes bankrupt in under 9 turns.
  - The worker (weight 4200, 6702 after sanity) then won.
- **Then no war:**
  - From T91 (window over) the target check is strict again, and Austria is far stronger, so no target.
  - Germany declared on the Aztecs at T108, which closed the window.
  - The Aztecs' only capture attempts were in that defensive war (Cologne, T130–T131).
- **The chain:**
  1. In the peace phase the tiny-army building cut sent production into workers, work boats and settlers (fixed in
     `f863b01`).
  2. Their upkeep and the wonders' put the civ in deficit.
  3. In the window the upkeep guard refused every unit.
  4. The window ran out with no army, and the stronger target was dropped.
- **The "preferred attack target Mogadishu" lines are CP's own target list** (MilitaryAILog), not TimingBuildup's;
  TimingBuildup's target was Austria.

**Fixes:**
- **War (TimingBuildup, same flag):** while the window is open and units are unaffordable (fewer than 9 turns to
  bankruptcy at the average unit's upkeep), the window pauses (its turns don't count down), for up to 10 turns per
  window, and logs "TimingBuildup: window paused, units unaffordable".
- **For Economy:** WarChest (gold per turn ≥ 0 while planning) and TrueGoldRate belong in the role for any
  TimingBuildup test. The Aztecs' worker weight (4200 before sanity) is theirs too.

Coded: `ai/war` `69c9587` (window pause; built, CI run 191), on `f863b01` (peace-phase building cut; built, CI run 189); merged in `claude/ab-c1` `eb4129d`.

### War: TimingBuildup's peace phase builds workers and work boats (the user watching 0C3C8913) (Nov 4, about 5:07pm ET)
The user, watching PC 1's replay: the Aztecs (the role, on ab-f73177c) are "building a million workers and work
boats". This is from the code, before the build history arrives.

**The likely mechanism** (`CvBuildingProductionAI`, the "tiny army" cut):
- **At peace every building's value is cut by 75%** while `getNumMilitaryUnits() × 10 <= cities × 10`, i.e. at most
  1 military unit per city (the new AI's peace number; AggressiveArmy's too outside the window).
- **TimingBuildup's peace cap** keeps land combat units at cities + 1 (plus up to 3 siege units). Scouts and ships
  are few, so the army sits at or just over the line, and the cut applies whenever it's at or under it.
- **Land units are refused** (`SR_STRATEGY`) by the cap.
- So workers and work boats, which are neither capped nor cut, win the city's choice.

Greedy civs already skip this cut for the same reason ("a small army is the greedy style's plan, and the unit cap
blocks the units this penalty asks for").

**Fix (TimingBuildup, same flag):** in the peace phase (no war with a major, no window or attack under way, planned
or not) the tiny-army cut doesn't apply. The small army is the plan, so buildings keep their value. In the window
the cut and AggressiveArmy's 3-per-city floor still push units, with TimingBuildup's +3000. The check is
`CvMilitaryAI::IsTimingBuildupPeace()`, in Personality's file behind this flag only.

**To confirm** with the build history (results/builds_0C3C8913_aztec.txt): workers and work boats chosen while at
peace with no window, and buildings losing.

Coded: `ai/war` `f863b01` (built, CI run 189); merged in `claude/ab-c1` `eb4129d`. The replay's production log (on 96f008e) shows the pattern: up to T80 the new choices were mostly settlers, caravans, workers and work boats. PC 1's build history (results/builds_0C3C8913_aztec.txt) confirms it. By T100 the Aztecs had chosen 10 settlers, 7 workers, 4 work boats, 4 caravans, 15 buildings and 3 wonders against **4 military units in all**. Military only came after Germany's war (34 by T150). The settlers are the expansion book's and Economy's; the workers and work boats fit the building cut with the unit cap.

### War: 0CEF854E (PC 2, ab-f21a8f6, 25-flag role), Mongolia: windows without a war; sneak attacks need every unit up front (Nov 4, about 4:49pm ET)
- **The windows:**
  - T71 against Rome and T103 against Sweden: each ended "no war 3 windows after the build-up".
  - T134: "peace, 13 land units over a cap of 6, letting Warrior go".
  - T135: a third window, against Sweden; war only at T149.
- **Attack requests:** 302 in the game, all "not possible for lack of units" (Stockholm, Bogota, Helsinki and
  others).
- **Operations that formed:**
  - one at T91, 3 units, which waited out SiegeArmy's 20 turns and gave up;
  - one at T146, which marched at T147.
- No capture attempt.
- **Two causes:**
  - The window's production weight came after this build (`214c6c7`), so the windows built little.
  - **A sneak attack on a major civ is requested with 0 missing units allowed.** `RequestCityAttack(..., 3,
    bCareful)` passes 0 when not careful, and CP sets careful only when other dangerous wars are on. So the attack
    forms only if every required slot of the formation is already filled by a free unit, and garrisons in exposed
    cities don't count.

**Fix (TimingBuildup, same flag).** While a timing attacker is in its window or attack phase, its city-attack
requests may leave up to the requested number of units (3) to be built, as careful requests already can. The
operation then forms, and its own build requests (the strongest production weight there is) fill the slots;
SiegeArmy still holds it until it is strong enough, for at most 20 turns. Coded: `ai/war` `f73177c` (built, CI run 186).

### War: why the trio's aggressor never declares (4 games, ab-9c6f2cd, logging off) (Nov 4, about 4:36pm ET)
The lead's question: in 4 trio games (6 civs, Standard Pangaea, Quick, T150) the aggressor declared no war.
Aggressors: Greece, Songhai, the Aztecs, America, each with 50 flags. No logs, so this is read from the results
file and the code.

**Military column, aggressor against the rest:**

| Game | Aggressor | T50 | T80 | T110 | The others at T80–T110 |
|---|---|---|---|---|---|
| 0C3C8913 | Aztecs | 31 | 36 | 34 | 37–170 |
| 0C44C5C5 | America | 25 | 37 | 75 | 23–88 |
| 0C33FB69 | Songhai | 18 | 55 | 83 | 18–97 |
| 0C2B2973 | Greece | 18 | 49 | 97 | 28–163 |

- The Aztecs were the weakest civ in their game from T80 to T110 and flat (31 → 36 → 34).
- **This is TimingBuildup's peace army doing its job** (garrisons plus one), but it breaks the target search.

**The chicken-and-egg (code).** `GetNewAIConquestTarget` keeps a candidate only if two checks pass:
- **Strength:** its military is POOR or weaker compared with ours (one step of slack once committed).
- **CanWin** (in the bundle since 2:38pm ET): the siege sketch with the ranged units we own now brings down its
  nearest city.

With a garrison-sized army almost nobody is POOR next to us, and the sketch has 0–3 ranged units. So no target is
found, TimingBuildup's window never opens, the army never grows, and no war comes. In the bully games the
opponents were greedy civs with their own small armies, so targets sometimes passed (Japan, the Zulus, Denmark got
windows). In the trio, CP's civs build normally.

**Fix (TimingBuildup, the trigger's mechanism; same flag).** Before the army is built (no window yet, or a window
still running), targets are judged against the army the window will build, not the peace army:
- the strength check allows one more step (AVERAGE);
- CanWin is skipped.

Once the army is ready or the window is over, both checks apply as before; if they fail, no war, and after 3
windows the plan resets.

**Request to the lead:** a logged replay of **0C3C8913** (the Aztecs, the flattest army) on the build with this fix,
to confirm a window opens and a war follows.

Coded: `ai/war` `96f008e` (built, CI run 184).

### War: two more logged wars on ab-f21a8f6 (PC 1, bullyabort6): 0BFDEC4C (Zulus), 0C1455BD (Denmark) (Nov 4, about 4:20pm ET)
Both used the 25-flag role. No captures.

**0BFDEC4C, the Zulus.**
- **T59:** "window opens for 10 turns against Venice". **T60:** the Zulus declared on **Korea**: CP's own WAR
  approach (WAR_FRIENDLY in the diplomacy log), not a coop war and not the committed target. The window closed
  after 1 turn.
- **T86–T94:** a second window against Venice; war on Venice at T94.
- **T126–T135:** a third window, then war on Korea again at T135.
- At the walls:
  - no capture attempt all game;
  - Seoul "too early" 19 times; Busan, Pyongyang, Daegu, Jeonju and Venice "enemy dominated" 12–23 times each;
  - one SiegeRoll wave at T146 (SiegeConcentrate: 6 in the army, 1 at the siege, 6 wanted), handed over at 2–5
    tiles too late.
- **The cause:** a war on the wrong civ, the same as 0CD189D4, but through CP's approach rather than a coop war.

**0C1455BD, Denmark.**
- **Windows:** against Venice at T53 and T85, and against Ethiopia at T117. The first two ended "no war 3 windows
  after the build-up".
- **What the windows built:** 2 archers and 2 warriors between T50 and T100, against 10 workers, 6 caravans, 3
  markets and 3 caravansaries. No unit was bought.
- **Every attack request failed:** 177 of them, all "not possible for lack of units". From T145 six operations
  ended NoUnits the turn they were created ("Units Recruited 3").
- **Why:**
  - a sneak attack on a major civ is requested with 0 missing units allowed (`RequestCityAttack(…, 3, bCareful)`,
    with bCareful false when not at war), so the whole army has to exist first;
  - the window only raised the recommended army size, which doesn't win production against buildings;
  - the peace cap kept the army small;
  - so the war never formed.

**The five questions (both games):** no army reached a city. Arrived together, big enough, damage, SiegeFinish:
not reached. SiegeRoll fired once, late.

**Fixes:**
1. **FocusedWar extended** (same idea: fight only the planned war). With a committed target, the WAR approach to
   any other major we're not at war with is set to 0, so CP's own approach can't start a second war. Coop wars were
   already covered.
2. **TimingBuildup's window builds.** While the window is open and the army isn't ready, land combat units get
   +3000 production weight (siege units +4000 while fewer than 2). That's about what a unit wanted by an attack
   operation gets (8000 in the logs), against 100–500 for a plain unit and 1000s for buildings. The army then
   exists when the window ends, and the sneak attack's 0-missing request can form. This is a fix of the window's
   mechanism under the same flag.

Coded: `ai/war` `214c6c7` (built, CI run 183).

### War: the first logged pair on ab-f21a8f6 (25-flag role), 0CD189D4, Japan (Nov 4, about 3:56pm ET)
PC 2, greedy opponents. Japan is the aggressor (group b, wide). In the role game it had 7 cities and made no
capture attempt; in the flip game it took one city.

**What TimingBuildup did (role game).**
- **T100:** "window opens for 10 turns against The Shoshone". The window is 15 turns × Quick speed's 67%.
  TargetVulnerability's pick was Yerevan, 5 tiles from the muster point at Kagoshima (48:33). So the distance was
  fine, not 12.
- **T105–T109:** Japan's diplomacy log shows **CWS** (a coop war, soon) against **Denmark**. Japan had agreed to
  join another civ's war; the coop-war request came in during the window.
- **T110:** Japan declared on Denmark (the coop war starting), and the window closed ("at war").
  - Denmark's cities (Aarhus 66:20, Kaupang 71:12, Copenhagen) are 15–25 tiles from Japan's core, and every one
    read "enemy dominated" (22–23 turns each).
  - All 24 attack requests on Aarhus and Kaupang failed: "not possible for lack of units".
  - The sneak attacks on Yerevan, the window's real target, were created at T110, T129 and T131. Each ended the
    next turn with "War goal changed, probably another war is more important" (DiploOpinionChange).
- **T133:** the window reopened against the Shoshone.

So the army was built for a war 5 tiles away, and a coop war 20 tiles away took its place, with nothing to show for
it.

**The five questions for this game:**

| Question | Answer |
|---|---|
| Arrived together? | No attack reached a target (no DeclareWhenGathered, SiegeConcentrate or MarchOn lines) |
| Big enough? | The build-up worked: military 67 → 141 → 192 |
| Kept the damage on? | No capture attempt |
| SiegeFinish, SiegeRoll? | Never reached |

**The flip game:** Japan took Agaidika. Its capture lines show units moving ("2 of 2", "3 of 3 used") with the city
at 200 → 200 most turns. That's the flip, without SiegeExposure.

### FIX_FOCUSED_WAR: a timing attacker with a plan doesn't join other civs' wars (War) (Nov 4, about 3:56pm ET)
- **Hypothesis:** a warmonger in the timing-attack plan, with a committed conquest target, treats every other civ
  as an invalid coop-war target (`CvDiplomacyAI::IsValidCoopWarTarget`).
  - It neither asks for nor accepts coop wars against them.
  - A coop war it already agreed to but hasn't started is cancelled by CP's own "invalid target" path, which has
    no broken-promise penalty.
  - Coop wars against its own target are still fine.
- **Expected:** the war comes against the target, after the build-up, with the army 5–6 tiles away instead of 20.
  No more 0CD189D4-style wars where the build-up went to a war nobody planned.
- **Measure:**
  - the war's target against the TimingBuildup target (log);
  - CWS/CW states in the diplomacy log;
  - capture attempts and CitiesCaptured.
- **Flag:** `FocusedWar`, off in the bundle. Role: add to the bully aggressor's flags.
- **Status:** hypothesis, coded: `ai/war` `40de507` (built, CI run 182), on `d7fc39e` (MarchOn).

### War: four more failed bully wars on ab-1c3ab74 (16-flag role), and the common cause (Nov 4, about 3:21pm ET)
PC 1 (bullyabort5), four games: 0B8A1D73, 0BA0FF9F, 0BB7D3CA, 0BCE16F7. All four had SiegeExposure and SiegeRoll;
none had DeclareWhenGathered or TimingBuildup. No captures.

| Game | Aggressor | Attacks | At the walls |
|---|---|---|---|
| 0B8A1D73 | Aztecs vs Poland | One sneak attack (T79, 4 units) recruited 41 turns; war came at T106 anyway; SiegeAbort at T119 | No capture attempt; every Polish city "enemy dominated" |
| 0BA0FF9F | Aztecs vs Ottomans, then Netherlands | 1664 marched 20 turns and ended HalfStrength; SiegeRoll wave 2392 (5 units) | Rotterdam: 200 → 170 once (2 of 3 units used), then 1–2 units in reach and 0 used; 25 "too early" |
| 0BB7D3CA | Mongolia vs Songhai, then Iroquois | Three attacks: two hit SiegeAbort after 20 turns with 4–5 units, one ended by a diplomacy change | None; "enemy dominated" everywhere |
| 0BCE16F7 | Assyria vs France | Sneak attack 1761 with 7 units, **discovered at T96 with units 5–7 tiles out**, ended. SiegeRoll wave at T120 ended HalfStrength | Troyes: 1–2 units in reach (expected 36–97 a turn), city never hit |

**The common cause.** A sneak attack ends the moment it declares, and the army is disbanded where it stands. It
declares when "discovered by enemy" or, with DeclareWhenGathered, at the border.

| Game | Unit distances at the hand-off |
|---|---|
| Assyria | 5–7 |
| Denmark (0C458987) | 3–7 |
| the Huns (0C22F161) | 3–5 |
| the Inca (0C04B641, the one capture) | 2–4 |

- The tactical AI then walks the units in one by one. The first to arrive meet the garrison and the city's fire
  alone ("1 unit in reach"), and the zone reads "enemy dominated" before the rest get there.
- The rest are pulled to other zones, or held by ArmyHandoff's "just deployed" rule.
- **DeclareWhenGathered makes this worse:** the border is 3–5 tiles short of the city.

### FIX_MARCH_ON: a sneak attack declares, then keeps marching as an army to the walls (War) (Nov 4, about 3:21pm ET)
- **Hypothesis:** when a sneak attack is ready to declare without being in place, it tells the diplomacy AI to
  declare but doesn't end. "Ready without being in place" means discovered, or DeclareWhenGathered at the border;
  in place means the centre within 3 of the target and every unit within 6.
  - It stays in the moving stage, so the army keeps moving as one.
  - At war, the usual check ends it once it is in place, and the tactical AI takes over with the army together at
    the walls.
  - **Safety:** at war, an attack whose progress has stalled for 3 turns within 6 tiles of the target is handed
    over as it is. Other aborts are unchanged.
- **Expected:**
  - unit distances at the hand-off of 1–4 instead of 3–7;
  - the first capture attempt with most of the army in reach ("n of m units used" with m ≥ 4);
  - fewer "enemy dominated" zones at the target in the first turns of the war.
- **Measure:**
  - "MarchOn:" log lines;
  - "Transition to finished stage; unit distance near/far";
  - capture-attempt lines;
  - CitiesCaptured.
- **δ:** CitiesCaptured by the aggressor up (any pair with a capture would be a change from 0 in 10 pairs).
- **Flag:** `MarchOn`, off in the bundle. Role: add to the bully aggressor's flags.
- **Status:** hypothesis, coded: `ai/war` `d7fc39e` (built, CI run 181), on `claude/ab-c1` `9c6f2cd`. Also: at peace, if the war hasn't come after 5 turns of waiting, the attack ends as before.

### FIX_TARGET_VULNERABILITY: a warmonger picks the most vulnerable nearby city (War, the user's redesign of GreedyTarget) (Nov 4, about 2:37pm ET)
**Why.** The user: "fewest land units per city" (GreedyTarget) is a weird way to pick a target. The target should
be the most vulnerable nearby city, combining three things:
- what that civ can bring to defend it (its whole army);
- the city's own defence (walls, city strength, garrison);
- the distance.

**Hypothesis.** In `GetNewAIConquestTarget`, for warmongers, each candidate civ scores its best city among those
within 12 plots of our nearest city. The candidate filters (proximity, strength step, one front, CanWin) stay as
they are; with this flag the score replaces both the weakest-neighbour score and GreedyTarget's units-per-city
score.

| Term | Formula |
|---|---|
| City defence | city strength / 100 × (HP left / max HP), plus half the garrison's combat strength. Walls raise both strength and max HP |
| Their army | their military might × 100 / ours (100 = equal) |
| Distance | plots from our nearest city |
| **Score** | −3 × city defence − army ratio / 2 − 5 × distance |

- Early-game sizes: city defence 15–30 (45–90 points), army ratio 50–150 (25–75), distance 5–12 (25–60).
- ConquestTraitTargets' bonus (at most +30) still goes on top.
- **Expected:** targets with weaker cities and smaller armies; fewer wars that end "enemy dominated, won't try to
  capture"; captures sooner.
- **Measure:** the logged reason "warmonger timing attack, most vulnerable city X" (with the city named); captures
  per war; turns from declaring to the first capture.
- **δ:** CitiesCaptured by the aggressor up; strength share at T150 +1 point.
- **Flag:** `TargetVulnerability`, off in the bundle. Role: in place of GreedyTarget.
- **Status:** hypothesis, coded: `ai/war` `fd7da75` (built, CI run 172), on `166ebc1`.

### CanWin, CSConquest, BoxedInWar into the bundle (the user's audit, via the lead) (Nov 4, about 2:37pm ET)
Coded: `ai/war` `fd7da75` (built, CI run 172).
- Set to true in `kCandidateFixes` on `ai/war` (rebased on `claude/ab-c1` `166ebc1`).
- **Checked safe for city-states and humans** (non-major civs run every bundle flag):
  - **BoxedInWar** and **CanWin** act only inside `GetNewAIConquestTarget`, which now also returns at once for a
    non-major civ. Before, it relied on `IsCandidateWarmonger` (majors only) and on the wide opening book (majors
    only), and returned for humans.
  - BoxedInWar's other two uses are also majors-only: the approach override sits behind that function's result,
    and the opening-book production hold behind `IsOpeningBookActive`.
  - **CSConquest** runs in a major's approach toward a city-state and needs `IsCandidateWarmonger` (majors, not
    human).

### War: what the minidump of PC 2's crash shows (0C827C9C, ab-1c3ab74, T78, logging on) (Nov 4, about 2:35pm ET)
Read with a small minidump parser (no symbols). The dump is 1.1 MB: thread stacks and the module list, no heap.
- **Where it crashed:** an access violation reading 0xad3188f0, at `CivilizationV.exe+0x3383d`, on the main thread
  (26496), inside Lua. The stack is `lua51_Win32.dll` frames called from the exe's UI Lua host
  (`CivilizationV.exe+0x49e0xx`). No frame of our DLL is near the top.
- **The main thread's stack holds 13 values inside `CvGameCore_Expansion2.dll`**, around RVA 0xacc5xx–0xacc9xx and
  0x716b20. They may be stale; mapping them needs the PDB of the 1c3ab74 MSVC Release build, a CI artifact I can't
  download from here. No other thread touches our DLL.
- **Memory:** crashes.log reports 1.81 GB committed below 2 GB, and the largest free block below 2 GB is 752 KB.
  The other crash in the log (11/02, a deliberate assert stop) had the same 1.81 GB, with a 1 MB largest block.
  - So the low address space is nearly full by T78. The most likely story is an allocation in the UI's Lua failing
    and a garbage pointer being read afterwards. That makes it an out-of-memory crash in the exe, not a bug in our
    code path.
  - What filled the memory can't be read from this dump (no heap).
- **Next:** the replay with logging off is the right test. If it passes T78, logging is the suspect; the tactical
  simulation's storage is the other candidate (CP issue #13254, address-space exhaustion, noted in
  `FindBestUnitAssignments`). With the PDB, the 13 stack values could be mapped to functions.

### FIX_TIMING_BUILDUP: a small army at peace, a fast build-up right before the attack (War, the user's design) (Nov 4, about 1:52pm ET)
**Why:**
- The user: a timing attacker doesn't keep a big army all game. It keeps garrisons and escorts, builds up fast
  just before the attack, and lands it while the army is fresh.
- Our warmongers do the opposite. The siege book builds 3 catapults, 2 spearmen and 2 archers after the 2nd
  settler, and AggressiveArmy keeps 3–4 land units per city at peace.
- So the army waits 30–60 turns paying upkeep. The Huns (0C22F161) were bankrupt by T71 and gifted 37 warriors and
  then their siege train.

**Hypothesis.** A warmonger with the flag runs three phases; outside them, nothing changes.

| Phase | When | What it does |
|---|---|---|
| **Peace** | no war with a major, no window | At most cities + 1 non-siege land combat units (garrisons and one escort; operations +2), siege units up to 3. AggressiveArmy's per-city floor and lift don't apply. Over the cap by more than 2: one extra unit a turn is gifted to a city-state, or disbanded. Siege units are never demobilised. Saves gold ahead (below) |
| **Build-up window** | the conquest target search finds a target | Up to 15 turns (× game speed). No cap. The recommended land army is raised to cities + 6, which makes CP's production build units. Each turn one siege or attack unit is bought in the city nearest the target, if the gold allows |
| **Attack** | army ready, or the window runs out | Ready means 2 siege units and cities + 4 other land units. The target search then returns the target and the normal path (WAR approach, sneak attack, DeclareAtBorder or DeclareWhenGathered) follows. With the flag, this replaces DeclareTiming's "2 siege + 4 land before turn 90" gate |

- **Peace again** (no war, no target): back to the peace phase; extras demobilise one a turn.
- **Gold target:** from turn 30 at peace, a savings request (`PURCHASE_TYPE_UNIT`, priority 400) for the purchase
  price of 2 siege units at the capital. That's about 2 × 200–250 gold at Standard in the classical era, recomputed
  each turn. It's spent in the window, and cancelled at war.
- **Window length:** 15 turns. The window ends at readiness, at the end of the 15 turns, or at war.

**Files and shared code:**
- `CvMilitaryAI`: phase state, recommended size, purchases, demobilisation.
- `CvDiplomacyAI::GetNewAIConquestTarget`: the window starts on finding a target; the target is returned on
  readiness.
- `CvUnitProductionAI` (Personality's file, behind this flag only): the peace cap. AggressiveArmy's floor applies
  only in the window.
- **For Economy:** the gold target above, and no bankruptcy (a negative balance should cancel the window's
  purchases; it does, through `CanWithdrawMoneyForPurchase`).
- **For Science:** timing the siege tech isn't coded here.

**The peace phase prepares (the user's follow-up, via the lead, Nov 4 about 1:58pm ET).** Peace isn't idle: the
economy prepares and the army stays small, ready to switch to the build-up quickly.
- **Planned phase:** from turn 25 (Standard) the target is chosen and kept (`GetCommittedConquestTarget`); the window
  still opens at turn 40.

| Preparation | Owner | Status |
|---|---|---|
| Research toward the attack's units: after the opening book, Mathematics and Bronze Working, then Iron Working or Horseback Riding when iron or horses lie in our lands (`CvPlayer::GetTimingBuildupTech`, hooked in `CvTechAI` after the growth tech) | War | coded, `2a4dde1` |
| Barracks and armory, forge and workshop in the 2–3 cities nearest the target; roads toward the border facing the target; workers and plot purchases to secure iron or horses | Economy | WarEconomy |
| Gold saved ahead and spent in the window; gold per turn ≥ 0 while the army stands | Economy | WarChest |
| War policies (Honor) when the leader's profile allows | Personality | to do |

- **Read-only plan for Economy** (`CvMilitaryAI`, `ai/war` `2a4dde1`):
  - `GetTimingBuildupPhase()`: NONE, PEACE, PLANNED, WINDOW, ATTACK, WAR;
  - `GetTimingBuildupTarget()`;
  - `GetTimingBuildupUnitsWanted()`;
  - `GetTimingBuildupUnitType(bSiege)`;
  - and `CvDiplomacyAI::GetCommittedConquestTarget()`.
- **Gold target, agreed with Economy's proposal:** the purchase price of the units still wanted
  (`GetTimingBuildupUnitsWanted()` × the price of `GetTimingBuildupUnitType`), capped at 15 turns of net income, and
  at least 2 siege units' price. TimingBuildup's own savings request and window purchases (2 siege units' price,
  priority 400) are a stand-in until WarChest lands; then they switch off under WarChest so the gold has one owner.

**Expected:** gold above 0 when the war starts. Fewer units at peace (upkeep down), a bigger army in the 15 turns
before the attack, and no "b/c bankrupt" gifting of attack units.

**Measure:**
- "TimingBuildup:" log lines (window start and end, purchases, demobilisation);
- gold and land units at declaration;
- gifted units per game;
- CitiesCaptured and T150 strength share, role against flip.

**δ:** strength share at T150 +1.5 points; CitiesCaptured up.

**Status:** hypothesis, coded: `ai/war` `4135121` (built at `fd881bb`, CI run 167; merged in `claude/ab-c1` `166ebc1`; the commit message's "2:10pm ET" should read 1:55pm ET). Shared code behind this flag only: `CvDiplomacyAI::GetNewAIConquestTarget`, `CvUnitProductionAI::CheckUnitBuildSanity` (peace cap; AggressiveArmy off at peace), `CvBuildingProductionAI` (AggressiveArmy's floor off at peace), `CvPlayer` opening book (the warmonger book's army steps skipped).

### FIX_DECLARE_WHEN_GATHERED: a sneak attack declares once it's gathered at the border (War) (Nov 4, about 1:48pm ET)
For cause 1 (late), at the lead's request.
- **Hypothesis:** a sneak attack (at peace, moving) whose centre or any of its units is in or next to the target's
  territory declares war when either holds:
  - the army is gathered, every unit within 2 tiles of its centre;
  - its progress has stalled for 3 turns there, so the stragglers aren't coming.

  At the border the army can't advance, so the stragglers catch up while it waits; that keeps it together on the
  way. DeclareAtBorder's "discovered" route stays as it is.
- **Expected:** declaring at the border within 1–3 turns of arriving, instead of the 7-turn wait (Denmark,
  0C458987, T85–T92), with units 1–3 tiles out instead of 3–7.
- **Measure:** turns from reaching the border to declaring ("DeclareWhenGathered:" log line), unit distances at
  the hand-off, first capture attempt turn.
- **δ:** CitiesCaptured by the aggressor up; strength share at T150 +1 point.
- **Status:** hypothesis, coded: `ai/war` `d25445a` (build fixed in `fd881bb`, built, CI run 167; merged in `claude/ab-c1` `166ebc1`).

### FIX_SIEGE_CONCENTRATE: a follow-up wave moves only as one army with the units already at the siege (War) (Nov 4, about 1:48pm ET)
For cause 2 (small).
- **Hypothesis:** SiegeRoll's release (an attack mustering within 5 tiles of its target) waits until the army plus
  our land combat units already within 4 tiles of the target add up to the formation's required slots (6 for the
  basic formation), instead of 3 army units.
  - Units back from healing (70% HP) are recruited into the waiting army meanwhile.
  - Units at the siege stay free for the tactical AI: recruitment skips units within 4 tiles of the target.
  - Each push is then one army: the follow-up and the units still at the walls.
  - The 20-turn SiegeAbort still ends a wait that never fills.
- **Expected:** fewer waves, each with at least 6 units near the walls together. Fewer "too early, 0–27 a turn"
  lines at the follow-up target.
- **Measure:** the "SiegeRoll:" line now gives army and nearby counts; capture attempts per follow-up city.
- **Status:** hypothesis, coded: `ai/war` `d25445a` (build fixed in `fd881bb`, built, CI run 167; merged in `claude/ab-c1` `166ebc1`). Applies only together with SiegeRoll.

### FIX_SIEGE_KEEP: units at the front stay off barbarian camps while at war (War) (Nov 4, about 1:48pm ET)
For cause 2 (handed-off units pulled away).
- **Hypothesis:** while at war with a major, a unit isn't sent to clear a barbarian camp in either case:
  - it left an attack operation in the last 5 turns;
  - it stands in the tactical zone of a city of a major we're at war with.

  Defence against barbarian units attacking our cities is unchanged; camps can wait.
- **Expected:** the units handed off at Seoul stay in the Seoul zone. Fewer "Trying to remove barbarian camp" moves
  by the aggressor during its war.
- **Measure:** camp moves during the war; units in reach at the first capture attempt.
- **Status:** hypothesis, coded: `ai/war` `d25445a` (build fixed in `fd881bb`, built, CI run 167; merged in `claude/ab-c1` `166ebc1`).

### War: the attack operations in 0C458987 (16-flag role) and 0C22F161 (Nov 4, about 1:23pm ET)
The lead asked for a trace of when each attack formed, how big it was, where it mustered, and what became of it.

**0C458987: the aggressor is Denmark, not Rome.**
- The roles are group b: Denmark (wide, the bully) and Korea (tall). Rome is a c civ; it and the Inca declared on
  India at T139 with no attack operation of their own (Rome logged none all game). So Rome's capture attempts on
  Mumbai are not the bully's war.

**Denmark against Korea (Seoul, 62:25, 250 HP with walls):**

| Operation | Formed | Muster | Units | What became of it |
|---|---|---|---|---|
| 1585, sneak attack | T69 | (57:31), 7 tiles out | 6: swordsman, spearman, warrior, 2 catapults, archer | Below the bar for 2 turns (40/60), then gathered. Marched at T77, **stalled at (60:28) T85–T92** (38%, "No progress"), discovered at T92 with units 3–7 tiles out. Declared T93 |
| 2125 | T99 | (60:29), 4 tiles out | 4 | SiegeRoll; ended HalfStrength at T101 |
| 2201 | T103 | (60:29) | 5 | SiegeRoll; deployed T107 |
| 2432 | T115 | (60:29) | 5 | SiegeRoll; deployed T120 |
| 2710 | T127 | (60:29) | 6 | SiegeRoll; deployed T129 |

- **At peace the army couldn't go further than the border.** DeclareAtBorder then waited 7 turns for "discovered by
  enemy". War came at T93 with the army strung out over 3–7 tiles.
- **No capture attempt at Seoul all war.**
  - T93–T107: the zone was STEAMROLL or EXPLOIT_FLANKS, yet no "attempting capture" or "too early" lines appear.
    No units were in striking distance.
  - The tactical simulations in those turns ran with 1–3 units near Denmark's own cities (54:32), (53:31), against
    barbarians: 7 "remove barbarian camp" moves, and 46 barbarian deaths in T93–T129.
  - Later: "too early, expected 0–27 a turn" at T108, T121, T125–T130. Busan "enemy dominated" every turn.
- **SiegeRoll works as coded but rolls small waves.** It released 4–6 units every 4–12 turns from the same muster
  point, and each wave reached the walls alone. It cures the 20-turn lock of 0C04B641; here it replaced one big
  push with a drip.

**0C22F161 (the Huns):** traced in the entry below.
- One attack, formed at T72, 4 tiles out, siege units only.
- 30 turns in recruiting, because every warrior built for it was gifted away for bankruptcy.
- Declared at T105; the siege units were gifted at T106–T110.

**The pattern: late, small, or not at all. The causes differ:**
1. **Late:** the army waits at the border (sneak attack at peace) for "discovered", or waits in recruiting for slots
   (0C22F161, 0C04B641).
2. **Small:** after the first wave, SiegeRoll sends 4–6-unit waves one at a time (0C458987). Barbarians and home
   defence draw the hand-off units away.
3. **Not at all:** bankruptcy gifts the army (0C22F161).

**Proposals (each needs a flag slot; the lead's call):**
- **DeclareWhenStalled:** a sneak attack that makes no progress for 2 turns while next to the target's territory
  declares then, instead of waiting to be seen.
- **SiegeRoll concentration:** after a failed or idle wave, the next one gathers at least as many units as the
  first army (instead of 3).
- **KeepSiegeTrain** (from 0C22F161).

### War: failed bully war 0C22F161, the Huns, bankrupt (Nov 4, about 12:55pm ET)
PC 2, greedy opponents, ab-9e9fc9d, 14-flag role. The Huns declared on France at T105. The game logged one
capture attempt (Paris, T105, 200 → 200, 0 of 2 units used) and took no city. **The cause is upstream of the siege:
the Huns were bankrupt from T71, and CP's bankruptcy rule gave the army away.**
- **The attack (sneak attack 1638):**
  - It formed at T72 at Pontianak (58:31), 4 tiles from the target (54:31). It had a battering ram, 3 catapults,
    an archer, and **all three required front-line slots open**.
  - It stayed in recruiting for **30 turns** (T72–T102), "Found 0 potential units" every turn. No "SiegeArmy:
    waiting" line appears; the required slots fail first.
- **Why the slots never filled:**
  - From T82 Pontianak, Attila's Court and Ahmedabad built a warrior for the operation every 2 turns
    ("Operation unit, Warrior").
  - **Each was gifted to a city-state a turn or two later**, "Gifting Warrior ... b/c bankrupt" (MilitaryAILog).
    That's 37 warriors gifted over the game; treasury 0, and the production log's GPT ran from −36 at T80 to
    −130 at T130.
  - The rule is `CvMilitaryAI::DisbandObsoleteUnits`. In deficit it gifts or scraps the cheapest "obsolete" unit not
    in an army (`FindUnitToScrap`). A warrior whose upgrade needs iron the civ lacks counts as obsolete, so every new
    warrior was first in line.
- **The war:**
  - Two warriors finally joined at T101–T102. The army marched at T103, was "discovered" at T104 (distance 3–5),
    and the Huns declared at T105.
  - The one capture attempt ran no simulation: `ExecuteSpotterMove` gives up when the city tile isn't visible.
  - **After the hand-off (no units in armies) the same rule gave away the siege train mid-war:** an archer
    (T106), both catapults (T107, T108), the battering ram (T110). CP only skips this rule at war when all wars
    are being lost.
  - From T106: "too early for attacking Paris, expected 0".
- **Upstream of War:** a warmonger at war while bankrupt. `GetNewAIConquestTarget` checks `IsWarWouldBankruptUs`,
  but the Huns were already at 0 gold. This is for Economy (and the lead).
- **Proposed War fix (needs a flag slot; masks are full, so the lead's call):** `KeepSiegeTrain`, in
  `CvMilitaryAI::FindUnitToScrap`. While the civ has a city attack recruiting or is at war with a major, units that
  can fill an open slot of a recruiting city attack, and siege units, aren't gifted or scrapped for deficit. If
  nothing else qualifies, nothing is scrapped that turn; the deficit then hits buildings and science, as in CP
  when no unit qualifies.
- **SiegeRoll wouldn't have helped:** it needs a war already declared, and the slots were empty for lack of units,
  not a long march.

### War: the first logged capture, 0C04B641, the Inca take Persepolis (Nov 4, about 12:17pm ET)
PC 2, greedy opponents, ab-9e9fc9d, 14-flag role. The Inca declared on Persia at T71 and took Persepolis at T75.
- **The army:** sneak attack 1572 at T67: spearman, 2 warriors, **3 catapults**, a composite bowman. Three earlier
  tries ended `NoUnits` at creation (T65). It marched at T68, was "discovered" at T70 at distance 2–4, and was
  handed to the tactical AI.
- **The capture lines:**

  | Turn | City HP | Units used | Agg |
  |---|---|---|---|
  | T72 | 200 → 200 | 4 of 5 | 2 |
  | T73 | 200 → 102 | 3 of 4 | 2 |
  | T74 | 122 → 8 | 5 of 6 | 3 |
  | T75 | 28 → captured | "0 of 5" | 3 |

**(1) T72, units moved but did no damage.** It was the first turn after declaring, with the army 2–4 tiles out.
- The simulation ran twice: 5 units, then 4 after new enemies came into view (a restart).
- The units used were moves into range. Catapults can't move and shoot in one turn from that far.
- From T73 the same units hit the city for 98 and 114. So the chain works at the walls once units are in range.
- **Logging caveat:** "units used" counts units that newly finished their turn during the attempt. T75's "0 of 5"
  next to CAPTURED shows it undercounts when units acted earlier in the turn. I'll fix it if it matters.

**(2) Why Pasargadae got nothing.**
- **T75–76:** "attempting capture of Pasargadae", 0 of 2–3 units used. Only the few free units nearby were in
  reach; the siege units were still at Persepolis.
- **T77:** a new attack, `OP_CITY_ATTACK_LAND` 1777, formed against Pasargadae (22:13). Its muster point was
  Persepolis (19:16), **3 tiles from the target**. It took 5 of the victors: spearman, warrior, composite bowman,
  2 catapults.
- **It never left recruiting.** A required front-line slot of the basic formation (SiegeFormation) stayed open for
  20 turns. No "SiegeArmy: waiting" line appears, because the required-slots check comes first. Catapults later
  left the army to heal.
- **Its units were invisible to the tactical AI the whole time.** Army units are taken out of the tactical AI's
  unit list (`AI_TACTICAL_OPERATION`, CvTacticalAI.cpp line 242). So from T77 the tactical AI counted only the
  free units: "too early for attacking Pasargadae, expected 22 a turn".
- **T97:** SiegeAbort ("still too weak after 20 turns"). The war idled and the campaign stopped at one city.
- The operation didn't end on the capture (1572 had already ended at deploy). The lock came from the new
  operation formed next to the next city.

**(3) SiegeFirst and SiegeFinish.**
- **SiegeFinish didn't decide it.** T74's agg 3 is CP's own rule (more than 2 melee units in reach). SiegeFinish
  needs the city at a third of its HP or less, and 122 of 200 isn't. At T75 (28 left) it could have applied, but
  agg was already 3.
- **SiegeFirst didn't act.** The army passed the bar at once, and its optional slot took a composite bowman.
- **What mattered:** the three catapults came from SiegeFormation's basic formation (5 siege slots). The
  hand-off came from DeclareAtBorder plus ArmyHandoff.

**Result of the pair:** at T150 the Inca had 8 cities and military 294 with the role, against 5 and 191 in the flip
game.

### FIX_SIEGE_ROLL: an attack mustering next to its target moves without waiting (War) (Nov 4, about 12:17pm ET)
- **Hypothesis:** a city attack whose muster point is within 5 tiles of its target, against a civ we're already
  at war with, leaves recruiting once it has 3 units. It doesn't wait for empty required slots or for SiegeArmy's
  bar.
  - **Why the waits don't fit here:** both exist to stop a weak army marching across the map and declaring war.
    Neither applies next to the front.
  - **What follows:** the army reaches deploy range in a turn or two. The operation ends and ArmyHandoff gives the
    units to the tactical AI, which counts them all.
  - **The tactical AI keeps its own check:** "too early" if 13 turns of damage can't beat the city's healing. A
    weak army still doesn't throw itself at the walls; it just isn't locked away.
- **Expected:** after a capture, the next city nearby gets capture attempts within a few turns, with "units used"
  above 0, and more captures per war.
- **Measure:**
  - capture lines per city;
  - captures per war and CitiesCaptured by the aggressor;
  - cities and military at T150, role against flip.
- **δ:** CitiesCaptured by the aggressor +1 per pair on average.
- **Flag:** `SiegeRoll`, off in the bundle. **This makes 64 flags, the cap**; anything after it needs the wider mask
  or a retirement. Role: add to the bully aggressor's flags, with SiegeExposure.
- **Status:** hypothesis, coded: `ai/war` `a8a186c` (built, CI run 155; merged in `claude/ab-c1` `1c3ab74`, built, run 158). One block in the recruiting stage of `CvAIOperation::CheckTransitionToNextStage`; log line "SiegeRoll: target N tiles from the muster point, moving with M units".

### War: failed bully war 0BE6755D, Songhai against Assyria (Nov 4, about 11:38am ET)
PC 2, greedy opponents, ab-2db51dd, 14-flag role. Aggressor Songhai. It ended with 3 cities and took none. A
different failure from Nottingham: the army lost the zone, rather than its attacks failing to land.
- **Target:**
  - At T50, "CONQUEST: going for Assyria (committed target)". Assyria is a Conqueror and a neighbour, rated
    military WEAK against Songhai at the time.
  - ConquestTraitTargets gave Songhai at most pop/2 for it, a small bonus next to the greedy score.
- **Army:**
  - Four sneak attacks ended `NoUnits` on the turn they were created (T66–T67). Songhai had 5 units against the
    basic formation's 6 required slots, the same thing seen in 0AFFA02F.
  - The fifth held at T68: 2 catapults, an archer, a spearman, 2 warriors. It marched at T71, was "discovered" at
    T75 (DeclareAtBorder: within 6 tiles of the target), and Songhai declared at T76.
- **At Nineveh:**
  - T77 and T79: capture attempts at 38 and 58 expected damage a turn, city at 200.
  - **From T80 the zone was enemy-dominated** (posture WITHDRAW, "won't try to capture") every turn until T107.
    Assyria brought its army; China declared on Assyria at T85 and still nothing changed.
  - Losses: Songhai 1 unit, Assyria 3, over the whole game.
- **Follow-up:**
  - The reinforcing attack (T82) never passed SiegeArmy's bar and gave up at T103 (SiegeAbort, as designed).
  - Peace came at T112. A new target, Babylon, followed at T113, with no war by T150.
- **Lessons:**
  1. The target check compares whole-empire strength once and keeps the target with a step of slack. A neighbouring
     Conqueror with a real army can pass it and then hold the zone.
  2. A 6-unit ancient army isn't enough against an AI that answers.
  3. In the first required-slot creation turn, `NoUnits` aborts repeat (the formation is bigger than a small army).
     Minor, since the next try holds.
- **No new War flag from this game.** It fits CanWin, which checks only the nearest city. SiegeExposure
  doesn't apply: the zone was lost before attacks mattered.
- **Not War's area:** in `OperationalAILog`, Songhai's found-city operations ended NoTarget every turn from T87 to T117
  (a new operation each turn, "Distance -1"). This is for Economy.

### War: why capture attempts plan attacks and then don't make them (code check, Nov 4, about 11:27am ET)
The lead asked for this before the logs arrive. Read in `CvTacticalAI.cpp` on `ai/war` `9e9fc9d`.

**Ruled out first:**
- *Units already used:* `ExecuteAttackWithUnits` uses every unit in `m_CurrentMoveUnits`.
- *Plan never run:* `FindAndExecuteBestUnitAssignments` runs the best finished plan. The Nottingham sims finished
  plenty of plans (834–1280 a turn).
- *City out of sight:* `ExecuteSpotterMove` only aborts when the city tile can't be seen. Nottingham was visible.

**The cause: the planner and the final check measure danger differently.**
- **While planning:** a ranged attack that ends the unit's turn is kept if the unit could "probably" end its turn
  there (`canProbablyEndTurnAfterAssignment`). That test **divides the danger by the aggression level**:
  ÷3 at agg 3 (the capture attempts), ÷2 at agg 2.
- **At the end of each plan:** `addFinishMovesIfAcceptable` scores every unit's end tile again
  (`ScorePlotForMove`, `EM_FINAL`, then `ScoreCombatUnitTurnEnd`) with the **full danger**. It rejects the tile if
  either holds:
  - a ranged or siege unit has danger above its current HP;
  - for any unit, HP² < 50 × danger (the new AI's 50; CP uses 42).

  If the unit can retreat anywhere, the whole plan is dropped.
- **The only slack:** one unit below the army's median XP, and only when the AI's offence flavour is above 6 and
  it has more than 6 units. Otherwise none; Spain had 5–6.

**So at a defended city** (city strike plus 2–3 English units, about 100–250 danger next to the walls):
- the plans in which catapults and archers shoot the city get built, then thrown out at the finish;
- the plans that survive are the ones where they didn't shoot: set-up moves, attacks on units, or a melee
  poke;
- each turn the army ends where it started, and the city heals.

This fits the logs: plenty of finished plans, 61–73 expected damage a turn (expected damage ignores where the unit
ends its turn), and 200 HP at the start of every turn. **Siege units are hit hardest:** they have the weakest
defence, so the most danger, and they can't move after shooting.

**What the new log will show if this is right:** "capture attempt on Nottingham done: city HP 200 -> 200 (or
about 180–200), 0–2 of 6 units used".

### FIX_SIEGE_EXPOSURE: in a city attack, the end-of-turn check uses the planner's danger (War) (Nov 4, about 11:27am ET)
- **Hypothesis:** when the simulation's target is an enemy city, a unit that attacked this turn has its end-tile
  danger divided by the aggression level at the final check, as it already is while planning. Ranged and siege
  units then shoot the city and stay in range, so the city loses HP faster than it heals, and SiegeFinish's
  assault gets its chance.
  - Other simulations and units that only moved are unchanged.
  - Melee units keep their own checks in `ScoreAttackDamage` (HP limit, turns to kill).
- **Cost:** more siege units lost to counterattacks and city fire. The danger figure is a worst case (every enemy in
  reach hits this one unit), so ÷3 is closer to what usually happens than the full figure.
- **Measure:**
  - capture-attempt lines: HP before → after, units used;
  - CitiesCaptured by the bully aggressor;
  - units lost per war (`KilledInCombat` in the tactical log).
- **δ:** CitiesCaptured by the aggressor above 0 in most bully pairs; strength share at T150 +1.5 points.
- **Flag:** `SiegeExposure`, off in the bundle. Count goes 62 → 63, inside 64. Role: add to the bully aggressor's flags.
- **Status:** hypothesis, coded: `ai/war` `a2ab150` (built, CI run 153). One block in `ScorePlotForCombatUnitMove` (CvTacticalAI.cpp). The next logged war with capture logging (ab-9e9fc9d)
  confirms or refutes the cause before it's worth a test.

### FIX_CONQUEST_TRAIT_TARGETS: a warmonger's conquest bonus shapes whom it attacks (War) (Nov 4, about 10:04am ET)
- **The trait fields** (`CvTraitClasses`, read through `GetPlayerTraits()`). The pack runs CP without Vox Populi,
  so the base game's values apply; VP's SQL changes these traits, but isn't loaded.

  | Civ | Base-game bonus | Field |
  |---|---|---|
  | Assyria | a tech the owner knew, per city captured | `IsTechFromCityConquer()` |
  | Songhai | triple gold from capturing cities and camps | `GetPlunderModifier()` (200) |
  | Huns | raze twice as fast | `GetRazeSpeedModifier()`. No bearing on target choice; left out |
  | Mongolia | +30% combat against city-states | `GetCityStateCombatModifier()` |
  | Austria | takes city-states by marriage | `IsAbleToAnnexCityStates()` / `IsDiplomaticMarriage()` |
  | Venice | buys city-states with its merchant (a unit ability, `IsCanBuyCityState`) | `IsNoAnnexing()`, which only Venice has in the base game, used as its marker |

- **Hypothesis:** with the flag (and the conquest role's target choice), each trait shapes the targets:
  - **Assyria:** +5 to a major target's score per tech the target knows and Assyria lacks, capped at +30 (c4's
    target scores run about 10–70).
  - **Songhai:** + half the target's total population, capped at +30 (plunder grows with city size).
  - **Mongolia:** CSConquest accepts city-states up to "average" strength against it, not just "poor".
  - **Austria and Venice:** never choose war against a city-state (WAR set to 0 in the city-state approach), since
    they take them peacefully.

  Each conqueror picks wars whose spoils it's built to collect: stronger civs in the late game, a game that feels
  different with each leader (goal 5).
- **Measure:** bully pairs where the aggressor is one of these civs, the role + flag against the role. Who it
  targets ("CONQUEST: going for X"), captures, `CityStatesCaptured`, and the trait's payoff (Assyria's techs, Songhai's
  gold) from the logs. Plus Austria's and Venice's city-state wars (should be 0).
- **δ:** target choice changes in the logs in most pairs, and captures are no fewer. Strength share is a guard, not
  the verdict.
- **Build:** `ai/war` commit `18386e5` (on `3cbc147`, CSConquest; CSConquest built in CI run 144), patch `patches/war/0012`.
  18386e5 alone failed to compile (65 flags overflow the 64-bit masks). The lead made room instead: `claude/ab-c1`
  `2db51dd` retires ClosedBorders, GrowthTech and AqueductValue and holds CSConquest and ConquestTraitTargets (62
  flags, CI passed). War's own retirement of AirRebaseHeal was undone, and `ai/war` matches `2db51dd`. **Rule:**
  retiring flags is the lead's call; tell the lead when a new flag would pass 64. All three places are in `CvDiplomacyAI` (`GetNewAIConquestTarget`, the CSConquest
  block, `SelectBestApproachTowardsMinorCiv`), Diplomacy's file, behind the flag as the lead asked.

### War: does a bully ever attack city-states? Hardly ever (FIX_CS_CONQUEST) (Nov 4, about 10:00am ET)

**Evidence.**
- **Declarations:** across all logged games so far, 1 declaration out of about 80 was against a city-state
  (Songhai on Buenos Aires).
- **Approaches** (approach log, rows "--- <city-state>"):

  | Aggressor (game) | Chosen approach to city-states, row counts | Best "Conquest" score |
  |---|---|---|
  | Mongols (0B09BFE1) | IGNORE 744, PROTECTIVE 214, CONQUEST 1 (T86, Vatican City, a Soft target; back to IGNORE the next turn) | 1,200 |
  | Celts (0879B791) | PROTECTIVE 553, IGNORE 330 | 37 |
  | Huns (0A92244F replay) | IGNORE 347, PROTECTIVE 17 | 375 |

**Why.**
- **The conquest role can't pick a city-state:** `GetNewAIConquestTarget` only loops over major civs.
- **CP's own city-state war** (`CvDiplomacyAI::SelectBestApproachTowardsMinorCiv`, then `DoUpdateMinorCivApproaches`
  picks one war target, nearest first) needs the WAR score to beat IGNORE and PROTECTIVE, and about a dozen rules set
  it to 0. Among them: no attack target; not a "good" war target; an ally we aren't at war with; a recent peace
  treaty; a friend's ally or protectorate.
- So warmongers in CP almost never take city-states, and our flags don't change that.

**Hypothesis (FIX_CS_CONQUEST).**
- A warmonger in the conquest role (`IsCandidateWarmonger(TimingAttack)`) that isn't at war with any major sets WAR
  towards a city-state when all of these hold:
  - it's close or a neighbour;
  - it has no ally, or its ally is a civ we're already at war with;
  - no major civ stronger than average compared with us protects it (pledge);
  - its military is no better than "poor" compared with ours;
  - we can declare war, have an attack target there, and made no recent peace with it.
- The existing machinery does the rest: one city-state war at a time, nearest first, through the same sneak attack,
  so SiegeArmy, SiegeAbort and DeclareAtBorder apply.

**Costs, by design:** CP adds warmonger score for taking a city-state, and its protectors' opinion drops. That's goal 2
working: a bully that eats city-states should draw a coalition.

**Measure:** bully pairs, the role + CSConquest against the role. `CityStatesCaptured` (the new column), the
aggressor's cities and military at T150, and the civs at war with it.

**δ:** at least 1 city-state captured per 2 bully pairs, with the aggressor's military no lower.

**Build:** `ai/war` commit `3cbc147` (on `claude/ab-c1` `d2390a1`), patch `patches/war/0011`. The code is in `CvDiplomacyAI::SelectBestApproachTowardsMinorCiv` (Diplomacy's file),
as a narrow override like TimingAttack's; the lead asked for it on `ai/war`.

### War: the first captures (bully pair 0A92244F, ab-dbdfbb3) (Nov 4, about 9:06am ET)

PC 1, normal opponents. The role was the 8 conquest flags + SiegeStay (now covering the homeland heals, `3247ef4`) +
SiegePosture, without SiegeFirst and SiegeFinish.
- **With the role,** the Huns (military 141 against Spain's 69 at T100) declared on Spain around T105 and **captured 2
  cities**: `CitiesCaptured` 1 by T120, 2 by T130. Spain's `CitiesLost` matches.
  - City counts moved by only one (Huns 5 → 6, Spain 5 → 4), so one captured city was probably razed or lost again.
  - Huns' military grew to 236 by T130. By T140, 4 civs were at war with them: the coalition goal, firing.
- **Without the role (the replay):** 0 captures, and the Huns' military was 140 at T150.
- **The other Huns pair (0A8035D5):** 0 captures either way.

- **The logged replay (logs_0A92244F0A92244F) diverged from T10** (the city-states came out different) and was cut at
  T110, so it shows only how the war began, not the captures (those came T110–T130):
  - T54: "CONQUEST: going for Spain (warmonger timing attack, committed target)".
  - T75: a 6-unit sneak attack formed, already past SiegeArmy's bar.
  - It was discovered at its target's border at T81 (3 tiles, as DeclareAtBorder allows); the Huns declared at T82.
  - A second attack arrived at T98.
  - Sieges up to T110 were weak: Seville faced 66, then 25–42 a turn, against 200, so nothing fell before the cut.
  So TimingAttack, SiegeArmy and DeclareAtBorder all fired as designed. How the city fell needs the next capture,
  which now comes with logs (PC 1 keeps the logs of any game with a capture).
This is the first time any candidate code has taken a city (see "City captures"). It's 2 pairs, logging was off, so
the mechanism isn't confirmed. **Request:** a logged replay of 0A92244F (first game), so the logs show which flags
did the work: the waiting attack, the siege's damage per turn, whether units stayed, and how the city fell.

### FIX_SIEGE_FIRST: a waiting attack's siege slots wait for siege units (War) (Nov 4, about 8:45am ET)
- **Why armies hold one catapult:** the basic attack formation (SiegeFormation) has 5 siege/ranged slots, and its two
  optional ones already ask for `UNITAI_CITY_BOMBARD` first. But each of those slots also takes `UNITAI_RANGED` as its
  second choice. So existing composite bowmen fill them from the reserves before any catapult is asked for.
  Mongol armies in 0B09BFE1: 1 catapult or trebuchet, 2–3 composite bowmen.
- **Hypothesis:** while SiegeArmy holds an attack as too weak, a slot whose first choice is a siege unit takes only a
  real siege unit. It stays open otherwise, so a city is asked to build a catapult or trebuchet. This applies only if
  the civ can train a siege unit at all. Siege units do 2–3× a composite bowman's damage to a city, so the waiting
  army reaches the bar sooner and brings more damage when it marches.
- **Measure:** bully pairs, the 10-flag role + SiegeFirst against the role alone. Siege units per marching army,
  expected damage when it marches, captures. The guard: the aggressor's military at T150.
- **δ:** at least 1 capture per 3 bully pairs more than the role alone.
- **Build:** `ai/war` commit `8c47302` (built: CI run 136) (on `claude/ab-c1` `d51e8a6`), patch `patches/war/0010`. Only with SiegeArmy on; optional slots only, from the operation's second turn.

### FIX_SIEGE_FINISH: melee units go in once a city is below a third of its HP (War) (Nov 4, about 8:45am ET)
- **Why:** in 0B09BFE1, both Tiwanaku and Kyoto came down to about 130/200 HP and were never assaulted to the end.
  With 2 or fewer melee units in reach, the capture attempt runs at medium aggression, which rejects a melee attack
  that costs more HP than it deals.
- **Hypothesis:** when the city's remaining HP is a third of its maximum or less, the capture attempt runs at high
  aggression, so melee units attack and take it. The combat simulation's suicide check still applies (no attack that
  leaves a unit under 3 HP).
- **Measure:** the same bully pairs. Captures, and the turns from a city's first hit to its capture.
- **δ:** as SiegeFirst.
- **Build:** `ai/war` commit `8c47302` (built: CI run 136), patch `patches/war/0010` (CvTacticalAI::ExecuteCaptureCityMoves).

### War: bully vs greedy pair 0B09BFE1 (Mongols with the full conquest role): close, then the army walked home (Nov 4, about 7:40am ET)

Aggressor Mongolia, with TimingAttack, SiegeTechs, SiegeBook, DeclareTiming, SiegeArmy, ArmyHandoff, SiegeAbort and
SiegeFormation, in game 1 only. Other civs greedy. No capture in either game. With the flags Mongolia kept its army:
military 190 at T150 against 124 in the replay, 5 cities in both.
- **SiegeFormation works:** attacks used the 10-slot formation. But they still held one siege unit each (a catapult
  or trebuchet) beside 2–3 composite bowmen and swordsmen: 30–40 expected damage a turn against bars of 60–75.
- **SiegeAbort and SiegeArmy behaved as designed:** attacks waited. One ended on a war-state change, one passed the bar
  and reached the Inca. The declaration came at T104.
- **The siege nearly worked.** Tiwanaku, an Inca city: Inca military 32, a greedy civ, 200 HP.
  - T104: 117 expected damage a turn. The city fell to 168 HP needed at T105, then 128 at T106.
  - Then the damage dropped to 32 a turn, and the city healed back to 200 by T110.
  - **No Mongol unit died T104–T119.** The units the tactical AI didn't use fell through to the homeland AI, which sent
    them home to heal (T107–T112) or to sentry points.
- **Two gaps in the role.**
  1. `SiegeStay` wasn't in the role's flags.
  2. As coded, SiegeStay only filtered the tactical AI's heal moves, not the homeland AI's.

  Fixed (2): `ai/war` `3247ef4` (patch 0009; built, CI run 125). The homeland heal moves now skip units the tactical AI's
  `IsUnitNeededAtSiege` says the siege needs (at least a third of HP, near a damaged enemy city). This is SiegeStay
  itself, which hasn't passed and isn't in the bundle. **Request:** add SiegeStay (and SiegePosture) to the
  aggressor's RoleFixes for the next bully runs.
- **Why nobody took Japan** (military 5, 3 cities; at war with Songhai from T67, and with Siam from T128):
  - **Songhai** (B, no flags) had no army near Kyoto for 80 turns: expected damage 0 from T88 to T143.
  - **When an attack finally came (T145)** it was the same pattern as at Tiwanaku: 83, then 120 a turn. Kyoto fell to
    164, then 133 HP needed. Then the damage dropped to 33 a turn and Kyoto healed back to 193 by T151.
  - **Siam** brought at most 27 a turn.

  So the bleed after two turns of fire isn't a quirk of the flags: B does it too. The fix is the same: SiegeStay
  (now also covering the homeland heals).
- **The next fix, in order:**
  1. Add SiegeStay and SiegePosture to the aggressor's role (`ab-3247ef4`). Expected: the two-turn collapse doesn't
     happen, and a 120-a-turn siege on a 200 HP city ends in a capture within 3–4 turns.
  2. If cities still survive at 30–60% HP, melee units aren't finishing: make the capture attempt use the high
     aggression level once the city is below a third of its HP.
  3. Then ask for siege units first while an attack waits (one catapult per army today).
- **Still open:** one siege unit per army. Only the capital's SiegeBook builds catapults, and the extra units SiegeArmy
  asks for follow the slot types (ranged or bombard), so cities answer with composite bowmen. A later idea: ask for
  `UNITAI_CITY_BOMBARD` first while an attack waits.

### FIX_SIEGE_FORMATION: classical–medieval city attacks use a formation with room for siege (War) (Nov 3, about 11:50pm ET)
- **Why only half the army joined, and the bar wasn't reached** (bully pair 0879B791): distance from the muster point
  wasn't it. The Celts' attack held 7 of its 9 slots; the rest of their military was garrisons, a sentry and scouts.
  The limit is the formation. From the classical era until the Renaissance, land city attacks use
  `MUFORMATION_SMALL_CITY_ATTACK_FORCE`:
  - 9 slots, but **only 2 take siege or ranged units**, and both are required;
  - its optional slots are melee (`UNITAI_ATTACK`/`FAST_ATTACK`), a general and a special unit.

  So the extra units SiegeArmy asks for are melee. The logs show cities asked to build "Operation unit ... Pictish
  Warrior / Swordsman" (the `1c30fb0` fix working). They add almost no city damage, and catapults can't join past 2:
  7 units made 27 a turn. `MUFORMATION_BASIC_CITY_ATTACK_FORCE` (10 slots, 6 required) has **5** siege/ranged slots.
  The ancient one (`EARLY_RUSH`) already has 4.
- **Hypothesis:** with the flag, a land city attack that would use SMALL uses BASIC instead. The army can then hold
  up to 5 siege or ranged units, which are what brings city damage. With SiegeArmy, the waiting attack's requests
  become catapults, and the bar becomes reachable.
- **Measure:** bully pairs, the conquest role (TimingAttack, DeclareTiming, SiegeBook, SiegeTechs, SiegeArmy,
  ArmyHandoff, SiegeAbort) + SiegeFormation against the same without it.
  - Mechanism: siege units in the attack and its expected damage when it marches.
  - Outcome: cities captured, the aggressor's city share, and military at T150 (the guard).
- **δ:** at least 1 capture per 3 bully pairs; military at T150 no lower.
- **Build:** `ai/war` commit `1fc6d0a` (on `claude/ab-c1` `c13eb1c`), patch `patches/war/0008`. Compiles: CI run 116, clang debug and release and MSVC debug passed; MSVC release was still running after 15 minutes at 12:10am ET, possibly the known hang. Only acts on land city attacks; the formation is
  chosen in `CvAIOperation` (War's file).

### War: bully conquest pair 0879B791 (Celts with the conquest flags): an army thrown away (Nov 3, about 11:45pm ET)

With TimingAttack, DeclareTiming, SiegeBook, SiegeTechs, SiegeArmy and ArmyHandoff, the Celts built the biggest army by
T100 (military 122), declared on the Netherlands at T111, took nothing, and ended at 38. In the replay without the
flags they ended at 131.
- **The attack waited the full 20 turns and marched below the bar.** The sneak attack (operation 1989) waited T86–T105
  at **27–29 expected damage a turn against Rotterdam's bar of 60**. Only 7 units ever joined: 2 Pictish warriors, 3
  swordsmen, a composite bowman and a catapult, about half the Celtic army. When the 20-turn cap ran out it marched
  anyway, was discovered at T110 and declared at T111.
- **At Rotterdam:** "attempting capture" every turn T111–T116, with expected damage falling 61, 55, 44, 54, 40, 40
  against 200 HP, then "too early".
- **The losses:** 11 Celtic units killed, all by the Netherlands, spread over T117–T149 (flank attacks, units
  retreating to heal or to safety, counterattacks). There were no disbands. The Netherlands lost 11 units too.
- **The victim was balanced, not weak:** Dutch military 110 against the Celts' 118 at the declaration, then 130, 159,
  168 and 222 by T150 as they out-built the Celts at war. By the user's framing the Celts should struggle here, but not
  throw away their army.
- **The cause is in War's own code:** SiegeArmy lets an attack march when the 20 turns run out, even far below the bar.

### FIX_SIEGE_ABORT: an attack still too weak after SiegeArmy's 20 turns is called off, not sent (War)
- Hypothesis: with SiegeArmy on, an attack that is still below the bar after 20 turns ends ("SiegeArmy: still too weak
  after 20 turns, giving up"). The WAR approach stays, so a fresh attack forms and must reach the bar before it marches
  or declares. Wars are declared only with an army that can take its city: fewer, later, winnable wars, and no army
  thrown at an equal neighbour.
- Measure: bully pairs (the conquest role flags + SiegeAbort against the same without it). Aggressor's military at
  T150 (the guard: it mustn't collapse), cities captured, and wars declared (they may fall).
- δ: the aggressor's military at T150 no lower than without the war (the replay), with captures ≥ today's 0.
- Build: `ai/war` commit `5bfea3f` (built: CI run 113) (on `claude/ab-c1` `1804369`), patch `patches/war/0007`. Needs SiegeArmy on.
- Notes: two other levers, not coded.
  - Only half the Celtic army joined the attack: the operation recruits units near the muster point.
  - A failed war ran 40 turns with no peace: that's Diplomacy's peace logic.

### War: why the bully aggressor barely declares (logged pair 07614B74, Songhai) (Nov 3, about 8:30pm ET)

The bully siege test on the fixed SiegeArmy (ab-095144c) gave 0 captures in 12 games, with the aggressor at war with
0–1 civs (the lead's summary). The logged pair, aggressor Songhai:
- **It was friendly to its neighbour for 60 turns.** Songhai's approach to Arabia was FRIENDLY from T30 to T90. Its
  WAR score there was large (7,000–16,000) and Arabia was a fair target (Average, then Favorable), but FRIENDLY
  scored 2–4× higher: 30,000 at T40, 51,000 at T60, 61,000 at T80. That held even though its opinion of Arabia was
  −55, a dislike.
- **AFRAID was about 0 the whole time,** so Diplomacy's "afraid of the warmonger" explanation doesn't fit this game.
  What pushes FRIENDLY so high isn't in the logs (they give totals only). It's in `CvDiplomacyAI`'s approach
  scoring: for Diplomacy.
- **Its one war wasn't its own.** It declared on Arabia at T94, the same turn as Portugal (a joint war), and its
  approach flipped to HOSTILE at about T95 (WAR 71,000, target Soft).
- **The main point for the test:** the aggressor ran only the siege flags. `TimingAttack`, `DeclareTiming`,
  `SiegeBook` and `SiegeTechs` (c3/c4, the code that forces a warmonger into a war at its army's timing) were off.
  There are no `CONQUEST:` lines in its logs, and those flags are off in C8 too: they failed the strength-share test.
  **So the bully aggressor is CP's normal AI with an aggressive personality, which plays friendly early.** That isn't
  the friend's role.

**Proposal.** In the bully test, give the aggressor the conquest flags as its role: `TimingAttack`, `DeclareTiming`,
`SiegeBook`, `SiegeTechs`, plus SiegeArmy and ArmyHandoff (RoleFixes). Compare with the aggressor without them.
- Strength share is the wrong verdict for those flags: a conqueror's job in the bully test is to attack, and the test
  measures whether the others hold.
- If it still doesn't fight, the FRIENDLY weight is Diplomacy's to find.

### FIX_WAR_PREP: a civ preparing a war builds its army like a civ at war (War + Economy) (Nov 3, about 1:45pm ET)
- **Why no units came** (bully pair 0714EFCB, and SiegeArmy's 21-turn wait at 16/86): an attack's build requests are
  served in `CvCity.cpp` ("Building unit for active operation from City root function"). At peace:
  - only the muster city builds for it;
  - the unit is appended after the city's current queue (front of the queue only at war), and it's skipped if it takes
    7+ turns;
  - a city that already has any unit queued skips the request.

  So a warmonger preparing a war gets about one unit, late, from one city.
- **Hypothesis:** while a civ has a land city attack still recruiting against a major (it's preparing a war), its
  cities serve that attack's requests as they would at war:
  - at the front of the queue;
  - from any of its cities within 5 turns' walk of the muster point, not just the muster city;
  - with the 7-turn limit raised to 10;
  - siege units (`UNITAI_CITY_BOMBARD`) first for the open slots.

  With SiegeArmy on, the waiting attack then fills up and marches with enough damage instead of being cancelled.
- **Measure:** bully pairs (the aggressor with the flag + SiegeArmy + ArmyHandoff, against itself without them).
  - Mechanism: units joining the waiting operation ("Added ... to slot") and turns waited.
  - Outcome: cities captured and turns to the first capture.
  - Guard: the aggressor's strength share mustn't drop.
- **δ:** at least 1 capture per 3 bully pairs (today 0), with strength share no worse.
- **Owner:** the code is city production (`CvCity` order choice, `CvUnitProductionAI`), so Economy's side. War defines
  what the army needs: which operation, which slots, siege first. Proposal: War writes it as one flag in the
  operation-slot path only, if Economy and the lead agree. Otherwise Economy codes it from this spec.
- **Status: superseded** (Nov 3, about 2pm ET). Economy traced the real block: `CvPlayerAI::PeekAtNextUnitToBuildForOperationSlot`
  (shared file) serves only *required* slots, so the optional slots SiegeArmy asked for were dropped, and no Songhai city
  ever got an "Operation unit" request in 21 turns. The city side already weights operation units at 5000+, above every
  building, so no production change is needed. Fixed inside SiegeArmy: `ai/war` `1c30fb0` (patch 0006) serves the
  optional slots of an attack that SiegeArmy holds back as too weak (built: CI run 100 passed). WarPrep stays a fallback if armies still don't fill.
  **Test:** the bully pair again, aggressor with SiegeArmy + ArmyHandoff (no SiegeBar) against itself without. Logs
  should show "Added ... to slot 5+" on a waiting operation and its expected damage rising.

### War: the first bully siege pair, 0714EFCB (aggressor Songhai) (Nov 3, about 1pm ET)

**With the flags, Songhai's attack waited and never marched, and Songhai never declared war.**
- **The waiting attack:** operation 1713 recruited 5 units at T80 (2 spearmen, a warrior, 2 archers). It then logged
  "SiegeArmy: waiting" for 21 turns (T80–T100), stuck at **16 expected damage a turn against Athens' bar of 86** (the
  SiegeBar bar).
- **No unit joined it in those 21 turns.** The optional-slot build requests produced nothing for it.
- **It never got to march:** it ended at T101 on an approach change, just as the 20-turn cap would have let it go.
  Afterwards: "requested attack on Athens ... not possible for lack of units". Byzantium and Greece declared on Songhai
  at T117.

**Without the flags (replay):** Songhai declared on Greece at T86, made 12 capture attempts with a best of 64/200 a
turn, and took nothing. A failure too, but at least it fought.

**Why the army was half the size** (military 8.7% against 16.0%): there were no failed attacks, so no units were lost
in them. Most likely Songhai stayed at peace until T117 and never switched to wartime unit production, while the
replay was at war from T86. That's an inference: the logs don't count units built per civ.

**What it means.**
- **SiegeBar makes the bar unreachable for an early, weak aggressor** (dropped, the user's decision), and SiegeArmy's wait doesn't grow the army
  (16 a turn for 21 turns). Waiting just cancels the war. Don't keep SiegeBar.
- **SiegeArmy only helps if the wait actually brings units.** Either the waiting army gets real production (siege
  units first), or the wait must be much shorter. As coded, it's a "don't attack" switch for weak civs.
- **The root is the same as before: armies are too small because the civs don't build them.** That's production, in
  `CvUnitProductionAI` (Economy) and the warmonger build (c4's `SiegeBook`). A war-side fix can't make units appear.
- One pair is one game each way; the 10 pairs will say whether this is typical.

### War: the siege package on ab-a86d57b: no gain, test stopped (Nov 3, about 10am ET)

The lead's SPRT, 7 pairs, c running SiegeArmy, ArmyHandoff, SiegeStay and SiegePosture against B: c 49.9%, gain −0.08
points. The gainer test **failed** (LLR −44); the no-worse test **passed**. No city captured in any game. The pair
spread was 0.58 points, so the two games of a pair barely differed: there were almost no wars for the flags to act
on (0.03–0.05 declarations per civ per 10 turns at King in split games).

**War's reading.**
- **Not evidence against the idea, only that split games can't test it.** The flags are harmless (no-worse passed)
  and act only inside a war. SiegeArmy can also delay wars: a sneak attack waits for its army.
- **The testbed is the bully test,** as the lead proposes. The aggressor runs the package (+ SiegeBar) against the
  aggressor without it. The measures are cities captured and turns from declaration to the first capture. Its logged
  games will also show whether the 20-turn wait cap is hit.
- **The bigger lever may be war starts.** In 3 earlier logged games, 9 of 14 declarations came from diplomacy paths
  (coop wars, demands) with no army, and B's own war logic rarely declares. War code can't start wars: the decision
  is in `CvDiplomacyAI` (approach WAR, `GetNewAIConquestTarget`). That's for Diplomacy, or the lead. War's part is
  making the wars that do start take cities.

### FIX_SIEGE_BAR: SiegeArmy waits for a third of the city's HP a turn, not a fifth (War)
- Hypothesis: with SiegeArmy on, an attack waits until its expected damage a turn reaches the city's healing plus a
  **third** of its max HP (about 87 for 200 HP, 120 with walls) instead of a fifth (60 / 80). In pair 05D462A7 the
  60 bar was met at the muster point, but the siege at the city peaked at 92/200 a turn and didn't take it. A bigger
  army brings the city down in about 3 turns of full fire, faster than it heals and kills our units.
- Measure: CitiesCaptured by group; logged games: the waiting turns per attack (the same 20-turn cap) and the best
  expected damage at the city. Strength share at T150 (the verdict).
- δ: +2 points of strength share
- Build: `ai/war` commit `0c2d4ce` (CI run 92 passed), patch `patches/war/0005`; test build `claude/ab-siege` `09e8743`. Needs SiegeArmy on (it only changes SiegeArmy's bar)
- Test: siege package + SiegeBar against the siege package, paired, T150.
- Risk: more attacks hit the 20-turn cap and march anyway, or wars start later. Watch the waiting turns.

### War: the logged siege pair on the fix, 05D462A7 (ab-a86d57b) (2026-11-03)

c 43.4% / 54.6% (pair 49.0%), no city changed hands.
- **The SiegeArmy fix works.** Assyria (c, replay) kept one attack, operation 1906, waiting from T80 to T84 at 40–42
  expected damage a turn against a bar of 60. It passed the bar by T87, marched at T88, arrived at T89 and declared
  at T90. No more NoUnits churn.
- **The siege got stronger but still fell short.** Assyria's best expected damage at its target was 92/200 a turn as c,
  against 41/200 as b in the other game. Songhai reached 129/200 in both games whichever group it was in, so that
  isn't the flag.
- **The bar is reachable, not blocking:** only one c attack had to wait, for about 7 turns. **It's too low to win:**
  60 a turn (healing plus a fifth of 200 HP) is met at the muster point, but at the city not every unit fires
  every turn, and 92 − 20 healing still needs 3+ turns of full fire while the city shoots back.
- **Next (one idea each, after the 20 pairs on ab-a86d57b give a first number):** raise the bar to healing plus a third
  of HP (about 87 for 200 HP, 120 with walls), and/or fill the army's open slots with siege units first. The data says
  the bar, not the slot count or the 20-turn limit, is what limits the siege.

### War: the logged siege pair 043923C9 (ab-f390090) — SiegeArmy was broken (2026-11-03)

c ran SiegeArmy, ArmyHandoff, SiegeStay and SiegePosture: 47.3% and 55.8%, no captures.
- **Bug: SiegeArmy killed every attack it held back.** Each "SiegeArmy: waiting" line comes from a new operation ID
  (78 lines over the pair, Assyria 2903, 2945, 2999... one per turn). Each one ends `NoUnits` with Duration 0 the
  turn it's created: `CvPlayer::addAIOperation` aborts a new operation that needs more units built than it was
  allowed, and SiegeArmy put the optional slots on that list from the first turn. So **no c attack ever waited and
  grew**. c's attacks were simply cancelled, so this pair and the 20-pair run on `ab-f390090` measure that, not the
  idea. Fixed in `a86d57b` on `ai/war` (no optional-slot requests on the creation turn; patch `patches/war/0004`).
- **No c city attack ever marched,** and c's sneak attacks never declared a war. Every c city attack ended `NoUnits` on
  its creation turn: 106 in the pair (Assyria 46, Spain 34 plus 2 `LostPath`, Songhai 18, Germany 6). Assyria's two
  declarations (T70, T114) came with the Ottomans' war, not from an army. In the replay, with Germany, Songhai and Spain in
  c, c declared no wars at all, while as b in the first game Germany and Songhai declared on Portugal. So the damage bar
  was never reached because no attack lived long enough to try. Whether it's reachable by T150 can only be read from
  `ab-a86d57b` games.
- **ArmyHandoff works as designed:** b's just-deployed units log "held back", and Portugal (c) "sent to reinforce".
  It fired rarely (2 sends) because few c armies were delivered.
- **No siege improved:** the best expected damage per turn was 75/200 (Songhai, b) and 70/200 (Assyria, b in the
  replay), the same range as before.
- **Next:** rerun the siege test on `ab-a86d57b` (built: CI run 90 passed) and drop the `ab-f390090` pairs from the verdict.
  One logged game should show the same operation ID waiting for several turns, then marching bigger.

### War: what the 3 logged King games show (2026-11-03)

Games 02DEF5BF and 02EA597F (bundle) and 02F5C9E3 (bundle + SiegeStay, SiegePosture, DeclareAtBorder), build
`445009c`, logs in `results/logs_<GameId>/`. No city changed hands. The scripts behind the numbers read
`MilitaryAILog`, `OperationalAILog`, `PlayerTacticalAILog` and `PlayerHomelandAILog`.

**1. No war ever brought enough damage to a city: armies are far too small.** Every capture check the tactical AI
logged in all three games, per attacking civ, best turn:

| Game | Attacker | Checks: too early / attempted / enemy-dominated | Best expected damage a turn / city HP needed |
|---|---|---|---|
| 1 | Poland | 28 / 0 / 70 | 30 / 250 |
| 1 | Siam | 11 / 2 / 74 | 47 / 200 |
| 1 | Zulus | 14 / 0 / 83 | 17 / 200 |
| 2 | Germany (c) | 18 / 3 / 66 | 89 / 200 |
| 2 | Persia (c) | 6 / 1 / 19 | 64 / 200 |
| 3 | Babylon | 18 / 0 / 225 | 27 / 200 |
| 3 | Spain (c) | 22 / 3 / 22 | 52 / 300 |
| 3 | Shoshone | 14 / 6 / 46 | 36 / 200 |
| 3 | Sweden (c) | 11 / 2 / 3 | 27 / 300 |
| 3 | Germany (c) | 24 / 2 / 29 | 50 / 250 |

- **The best siege in three games reached 89 expected damage a turn,** against 200 HP and 20 HP of healing. Most
  peaked at 20–50, below a quarter of what a capture needs.
- **The few "attempting capture" lines were hopeless,** and the tactical AI was right to refuse the rest.
- **The armies sent:** Sweden's attack on Akkad at T110 was 3 warriors, a chariot archer and a composite bowman.
  Germany's on York at T107 was a pikeman, 2 swordsmen and 2 catapults. The attack formations have 9 slots but march
  once their 4–5 required slots are filled. Against a walled city (300 HP) that's nowhere near enough.
- **This is new.** The ranking above put healing and posture first, but those only matter once a siege has the
  damage to win, and none did.

**2. A delivered army can be sent home: the hand-off from operation to tactical AI.** Germany in game 3:
- **T111:** the sneak attack is "discovered" with its army 4–6 tiles from York, still inside Berlin's own zone.
  War is declared at T112.
- **T112–T117:** the tactical AI never moves the army forward. The homeland AI sends its swordsmen and pikeman to
  sentry points around Berlin ("Moving Swordsman 1806 to sentry point").
- **T114:** York's zone, which no longer has the army near it, tips to withdraw.
- **T118:** a new attack operation recruits the same five units at the Berlin muster point and marches again.

The likely cause is in `CvTacticalAI::PlotReinforcementMoves`: it won't pull a unit out of a zone that "needs it"
(not friendly-dominated, not withdraw), and Berlin's zone was in counterattack posture. Units that no tactical move
takes fall through to the homeland AI, which sends them to sentry points. Not yet proved line by line: the new flag
below logs each time this rule holds a unit back. Germany in game 2 had the same short shape: arrived T76, expected
damage 12, 20, 40 (one attempt, T80), 20, then 0 from T86.

**3. Most declarations don't come from an army arriving.** Of 14 declarations by major civs, 5 followed a sneak attack
reaching its target, all at 3–4 tiles. The other 9 had no army arriving: coop wars (Siam and the Zulus on the Maya
at T108), Sweden, Spain and the Shoshone all declaring on Babylon at T108, the Huns on Poland at T36. These paths
are in `CvDiplomacyAI` (the request to Diplomacy above stands).

**4. `NoTarget` is mostly found-city operations, not military.** Over the three games, 1,245 operations ended
`NoTarget`, all `OP_FOUND_CITY`. They're re-created and dropped every turn (Spain T19–T23: a new ID each turn, the
same target, "Duration" counting up from 20). That's Economy's (request below). The military `NoTarget` endings
(47) are rapid-response operations ending once the intruder has left, which is harmless.

**5. Other operation endings.**
- **Sneak attacks ending `NoUnits`, 73 times:** they're created and dropped for lack of units (Sweden in game 2:
  28 times). Same root as point 1: armies too small.
- **`HalfStrength` (audit item 26):** 3 city attacks out of about 20, plus 7 rapid responses and 5 pillage
  operations. That's too few to explain anything, so **no ablation needed.**

**What it means for the War flags in screening run 2.**
- **`SiegeStay` and `SiegePosture` had almost nothing to act on.** No siege had the damage to win, and in game 3 no
  c siege was in the attrition posture (Akkad was steamroll, York withdraw or steamroll). Expect close to no
  effect on captures. If they show anything, it'll be through units lost.
- **`DeclareAtBorder` had nothing to change:** every sneak attack in the three games was discovered within 6 tiles.
- **Game 3's 53.6%** is one unpaired game, without a capture.

**`CanWin` is optimistic** (c7c, `CvDiplomacyAI.cpp` `CanTakeNearestCity`): its siege sketch counts every ranged land unit
the civ owns, wherever it is, not the army that will march. So it passes while the army that arrives has a fraction
of that damage. `SiegeArmy` runs the same kind of check on the army itself.

**The new order of fixes:** army size first (point 1), then the hand-off (point 2), then the siege flags already
coded, which need a real siege to act on.

### FIX_SIEGE_ARMY: city attacks march only with enough damage to take the city (War)
- Hypothesis: a land city attack (also the sneak attack) waits for more units, and leaves the gathering stage only
  when its units' damage a turn against the target city covers the city's HP within 8 turns of fire, after its
  healing (the same sketch as `CanWin`, but run on the army itself). It stays capped by the formation's 9 slots and
  the operation's recruiting time limit. So no attack marches while it can't win: fewer, bigger attacks. With
  `SiegeStay` and `SiegePosture`, a siege that starts strong also stays strong.
- Measure: `CitiesCaptured` by group (the mechanism; it's 0 now). Logged games: the best "expected max damage per
  turn" against city HP. Strength share at T150 (the verdict).
- δ: +2 points of strength share
- Build: `ai/war` commit `f390090` (on `claude/ab-c1` `9fadf3d`, merged in); patch `patches/war/0003`
- Test: screen with the other War flags, then SPRT gainer, paired, T150.
- Risk: attacks start later or not at all (the target walls up meanwhile). Watch `NoUnits` endings and the turns
  from declaration to first attack.

### FIX_ARMY_HANDOFF: a delivered army joins the siege instead of going home (War)
- Hypothesis: units that left an attack operation in the last 5 turns (`IsRecentlyDeployedFromOperation`) may
  reinforce the target's zone even from a zone that "needs" them, so they close in on the city instead of falling
  through to the homeland AI's sentry moves. Logs a line when the rule would have held a unit back.
- Measure: CitiesCaptured; in logged games, homeland sentry moves by just-deployed units (should be ~0) and turns from
  arrival to the first city attack.
- δ: +1.5 points of strength share
- Build: `ai/war` commit `f390090` (on `claude/ab-c1` `9fadf3d`, merged in); patch `patches/war/0003`
- Test: as above.

### War audit: `CvHomelandAI` (2026-11-02)

No `AI_AB_TEST` changes were in this file, so all of this is CP's code. None of it repeats AUDIT.md. Lines are in
`CvHomelandAI.cpp` on `ai/war`. Same format as AUDIT.md:

| # | Area | Where | Bug | Fix | Status |
|---|---|---|---|---|---|
| H1 | Upgrades / gold | `:1880`, `:1950` | **Inverted condition:** the gold saved for unit upgrades is cancelled only when there is no such request, so it is never cancelled. The early `return` when every upgrade is done doesn't cancel either. At war its priority is 500 + flavour × 50 × 100 (up to ~250k), so a stale request goes on blocking lower-priority purchases after its unit has upgraded or died. (`:1974` cancels too, but only to restart it at once.) Same kind of bug as AUDIT 6 | Cancel when the request exists, and before the `return` | confirmed, flag `UpgradeSaveCancel` |
| H2 | Aircraft | `:5681`, `:5697`, `:7112` | **A healing aircraft never stays in the quietest base:** the loop that sorts bases quietest first `continue`s past the plane's own base instead of stopping, so it rebases to the next base it can reach every turn. The "do we need to move" guard is always true, because every base scores at least 1. Rebasing ends its moves, so it never heals. The combat loop (`:5776`) gets this right with `break` | Stop at its own base; rebase only to a strictly quieter one | confirmed, flag `AirRebaseHeal`. Little effect before planes (not in T150 Quick games) |
| H3 | Escorts | `:1013`, `:653` | Worker escort targets (aux 123) pass the `< 500` test meant to let only unimportant sentries take a "peek" step, so an escort can step off its worker and end the turn without moving back | Exempt worker targets by type | mismatch confirmed, effect plausible |
| H4 | Escorts | `:640–654` | Worker escort targets use each worker's position before `PlotWorkerMoves` moves it, so the escort goes to the tile the worker has left | Build them after the worker moves | plausible |
| H5 | Navy | `:2614–2629` | An unassigned warship outside its territory that hasn't moved for 7 turns is scrapped, or killed when it can't be scrapped (which also gets around VP's no-disbanding-next-to-enemies rule). A ship pinned by enemies never moves and is deleted | Skip while in danger or at war; never `kill` | plausible (naval: not in Pangaea tests) |
| H6 | Fog cheat | `:2531`, `:4031`, `:5916`, `:5948` | `MOVEFLAG_PRETEND_ALL_REVEALED`: paths home for idle units and civilians use the real terrain of unexplored tiles | Drop the flag for the new AI | confirmed, small |

Checked, not bugs: the garrison strength maths, the sort orders, the safety thresholds, patrol zones, the
upgrade flavour loop, and the deliberate "peek and return" sentry moves.

### FIX_UPGRADE_SAVE_CANCEL: drop the stale upgrade-gold request (War, bug H1)
- Hypothesis: with the cancel working, gold saved for an upgrade that's no longer needed goes back to other
  purchases (buildings, units, settlers). It's a bug fix, so the test is that it does no harm.
- Measure: strength share at T150; gold spent on purchases (digest) as the mechanism.
- δ: no-worse test at δ = 2
- Build: `ai/war` commit `445009c` (on `5ae5a94`); patch `patches/war/0002`
- Test: SPRT no-worse, paired, T150 (or screen it at T100: it's an economy effect)
- Status: hypothesis

### FIX_AIR_REBASE_HEAL: healing aircraft stay in the quietest base (War, bug H2)
- Hypothesis: damaged planes heal instead of rebasing every turn. No effect in T150 Quick games (no planes), so it
  can't be tested there; it's a correctness fix for real games.
- Measure: none in the standard test. Check in a late-era save that a damaged bomber heals.
- δ: none. A no-worse check only once long games or late-era saves exist.
- Build: same commit as UpgradeSaveCancel
- Status: hypothesis; waits for a late-game test

### Screening run 2: plan (lead, 2026-11-03; replaces run 1, which was never played)

- **Build:** `claude/ab-screen2` (`2d949f8`, release `ab-2d949f8`; first built as `b756936` before Economy's 0009 and
  0010 were added on 2026-11-03): all 41 flags, rebased onto the 64-bit flag
  table, compiled together by CI run 77. Results in `AIABTest_screen2.csv`.
- **Screened (30):** the 13 c7c ideas (all but `LongWide` and `GreedyArmyCap`, which failed); Economy's
  `SettlersFirst`, `SettlerOverlap`, `DiploPolicyValue`, `PolicyPrereqDepth`, `LosingWarBuildings`,
  `CultureRivalValue`, and from the first logged King games `SettlersBeforeWonders`, `BookFinishesSettlers`; War's `SiegeStay`, `SiegePosture`, `DeclareAtBorder`, `UpgradeSaveCancel`; Diplomacy's
  `EasyTarget`, `DiploBugs`, `LuxuryAsk`, `DealExploits`, `DealReputation`.
- **Left out, and where they're tested instead:**
  - `AirRebaseHeal`: no aircraft by turn 150.
  - `IdeologyPick`, `EspionagePolicyValue`: they act after turn 150 (phase 2, longer games).
  - `GreedyAlarm`: waits for War's captures.
  - `CityStateBugs`, `CoalitionStrength`, `CoalitionCoop`, `Sanctions`, `CoalitionPact`: they act against a
    runaway conqueror, so they go to the bully test, where there is one.
- **Reading it:** paired regression, 8 civs × 20 pairs = 160 differences for 30 flags. Each flag is on for half the
  civs, so its effect is estimated from about 80 civ-pairs. Expect only large effects (about ±1 point per civ) to
  stand out. Screening only ranks: the top flags get single-flag paired SPRTs.
- **Diplomacy's reading notes (2026-11-03):**
  - `EasyTarget` changes how often civs start wars, so it is the flag most likely to move strength either way. Read
    `WarsDeclared` beside it; if it hurts, check whether its civs started more wars or were targeted more.
  - `DealReputation` acts only after a civ breaks a payment deal by declaring war, which is rare between AIs:
    expect it to look neutral here. Its real test is exploit check 1, run twice.
  - `DealExploits` makes AI-to-AI demands pay off less often. Watch `Deals` and `WarsDeclared`: a refused demand can
    lead to a war.
  - Bully test, later: the four coalition flags and `CityStateBugs` all on together first, to see whether anything
    moves the aggressor's city share at all, then one at a time. Only once War's flags produce captures; until then
    the coalition has nothing to react to.

### Screening run 1: plan (lead, 2026-11-02; replaced by run 2)

- **Why:** 19 candidate flags exist, from c1–c7c, Economy and War. At about 3 pairs an hour, an SPRT per flag
  would take days. One screening run estimates every flag's effect per civ from the same 20 pairs (the paired
  regression, lead job 4). Each game has every flag on for about half the civs, swapped within each pair.
- **What's screened:** every idea except `LongWide` and `GreedyArmyCap`, which already failed.
- **Reading it:** `Summarize-ABTest.ps1 -AtTurn 100` for the economy flags, and the final turn for the war flags
  (job 8: war shows late).
  - Flags that only act together with another one are diluted: `DeclareTiming`, `GreedyTarget` and `CanWin`
    need `TimingAttack`, and `BoxedInWar` needs `BoxedIn` and wide civs. A weak estimate there means
    "no main effect", not "useless".
  - Screening only ranks. The top 2–3 flags get single-flag paired SPRTs. A flag that looks harmful is dropped
    unless its owner has a reason to retest it.
- **Build:** `claude/ab-screen1` (`db63d22`) is test-only: `claude/ab-c1` with `ai/economy` and `ai/war` merged,
  every new flag off in the bundle, and its own results file. The flags are numbered 15–17 (Economy) and 18–20
  (War) in this build only. When a flag passes, it's merged into `claude/ab-c1` on its own.

## Sessions running (2026-11-02)

| Session | ID | DLL branch | Started with |
|---|---|---|---|
| Experiment lead | `session_01G2NZj313wWzcZ8o56vVzZK` | `claude/admiring-fermi-qyl4j3` → `claude/ab-c1` | AGENTS.md "Experiment lead: first jobs" |
| War | `session_01G2NZizcmgfGkXsgJcVcF7h` | `ai/war` | AGENTS.md "War: first tasks" |
| Economy & victory | `session_01G2NZj2nf4FeZTEHWjvnhhA` | `ai/economy` | AGENTS.md "Economy & victory: first tasks" |
| Diplomacy | `session_01G2NZj1hm6um5X9SZaXQCRZ` | `ai/diplomacy` | AGENTS.md "Diplomacy: first tasks" (audit only for now) |
| Personality | `session_01G2NZj3nJG9wpbrgoAZMmUk` | `ai/personality` | AGENTS.md "Personality", started early (2026-11-03): the greedy style first |
| PC runner | the local session on the Windows PC | none | the smoke-test pair, then the King baseline |

The topic sessions push their RESULTS.md entries to their own branch of this repo, and the lead merges them
into `claude/sleepy-hopper-x77moh`. Personality starts in phase 2.

### GreedyAlarm: greedy civs wall up when a neighbour's army appears (Economy, the c8 idea)
- Hypothesis: greedy tall civs drew wars because nothing told them a neighbour was massing (c6: 0-3, Egypt
  attacked by three civs and a city-state). With an alarm they keep the greedy economy in peace, and when a
  neighbour's army shows up near their cities they get walls in border cities (valued as if at war) and
  archers (up to one ranged land unit per city plus one), and `GreedyArmyCap` stops capping. Expected
  effect: fewer cities lost and fewer wars started on them, at a small production cost.
- The signal: CP's military aggressive posture toward each met major civ at MEDIUM or above
  (`CountAggressiveMilitaryScore`: visible units near our cities, 2 each outside their own land, 1 inside,
  MEDIUM from 6). It counts **only units we can see**, so it's fair play. Tall-plan civs not at war only; war
  has its own production rules. Note that CP ignores units of civs we give open borders to, so it works best
  with `ClosedBorders` (in the bundle).
- Measure: strength share at T150 (verdict). Mechanism, per civ from the c7c_roles columns: wars declared
  on tall civs, cities they lose, and `CitiesCaptured` against them.
- δ: 2 points of strength share.
- Build: fork commit `ccbb01a` on `ai/economy` (patches 0003-0006 on `cfaf3db`, applied by the lead). Flag
  `GreedyAlarm` (`FIX_GREEDY_ALARM`), not in the bundle. Files: `CvCityStrategyAI` (the signal,
  `CityStrategyAIHelpers::GetGreedyAlarmThreat`), `CvBuildingProductionAI` (walls), `CvUnitProductionAI`
  (archers, cap).
- Test: two configurations against B, paired, T150:
  1. `Fixes = GreedyArmyCap+GreedyAlarm`: the c8 idea as stated (greed plus alarm). Against c6's 46.5%
     (cap alone) it shows whether the alarm repairs the cap.
  2. `Fixes = GreedyAlarm`: the alarm alone, for any tall civ.

  The bundle flags stay on or off as the lead's baseline decides.
- Status: on `ai/economy`, CI pending. Goes into a screening run once War has capture fixes (lead). War: keep CP's
  posture signal for now. Background: War owns the threat side (`CvMilitaryAI`). This uses only an
  existing diplomacy signal and Economy's production files, so it doesn't touch War's code. If War builds a
  better "army massing" signal (muster points, siege units seen), the alarm should switch to it.
- Notes: posture only sees units near our cities, so an army mustering out of sight isn't seen until it
  moves up. That's also what a human sees.

### Two dead loops: `IsPlayerValid` asked of the wrong player (Economy, found while writing GreedyAlarm)

`GET_PLAYER(eLoopPlayer).GetDiplomacyAI()->IsPlayerValid(eLoopPlayer)` asks a player whether it is valid to
**itself**, and `IsPlayerValid` returns false for one's own team. So both loops below never do anything, in
CP and in B. Confirmed by reading `CvDiplomacyAI::IsPlayerValid`.

| # | Where | Meant to do | Impact |
|---|---|---|---|
| E1 | `CvBuildingProductionAI.cpp` ~1346 | At war, cut non-defensive buildings' value by a further 50 points for each enemy we're losing to (war state worse than stalemate) | Medium in wars: an AI that's losing keeps building libraries and markets instead of units |
| E2 | `CvCityStrategyAI.cpp` ~4303 | Value culture more when rivals' tourism is gaining on us (×2 to ×3) | Low. The B change there ("CP multiplies once per rival, ×16") fixes a loop that never runs, so it changed nothing |

Fix: `kPlayer.GetDiplomacyAI()->IsPlayerValid(eLoopPlayer)`. Coded as two flags, out of the bundle:
- **`LosingWarBuildings`** (`FIX_LOSING_WAR_BUILDINGS`, E1), patch 0007.
  - Hypothesis: a civ losing a war (war state worse than stalemate) cuts non-defensive buildings by a
    further 50 points per such enemy, so it builds units and walls instead.
  - Measure: cities lost and strength share in games with wars. It only acts in wars that go badly, so it
    can't show much until War's capture fixes make wars bite.
  - Test: no-worse, T150, δ = 2 points of strength share; ideally queued alongside War's flags.
  - Status: on `ai/economy` as `5531a3e` (with 0008). War wants it tested alongside its fixes.
- **`CultureRivalValue`** (`FIX_CULTURE_RIVAL_VALUE`, E2), patch 0008.
  - Hypothesis: culture yields are valued ×2-×3 when a rival's tourism is rising against us, as CP and B
    intended, so the civ defends culturally a little earlier.
  - Measure: strength share at T150 (no-worse); culture per turn and policies at T150 (mechanism).
  - Test: no-worse, T150, δ = 2 points of strength share, low priority. Probably no effect at T150, where tourism is still small.
  - Status: on `ai/economy` as `5531a3e`.

### IdeologyPick, PolicyPrereqDepth, EspionagePolicyValue: the other CvPolicyAI bugs (Economy, audit P2-P4)
One flag each, all out of the bundle, as patches 0004-0006 (in that order, after 0003). All three are bug fixes
judged by **no-worse** tests at T150 (δ = 2 points of strength share), lowest priority in Economy's queue.

| Flag | Audit | Change | What should show |
|---|---|---|---|
| `IdeologyPick` (`FIX_IDEOLOGY_PICK`) | P2 | Ruled-out ideologies are tracked in their own list. Later steps skip only those, and the pick is the best of the rest; if all are ruled out, CP's pick stands | Nothing at T150 Quick (ideologies come later). Kept as a no-worse fix for full games; can wait for phase 2's long games |
| `PolicyPrereqDepth` (`FIX_POLICY_PREREQ_DEPTH`) | P3 | Prerequisites get flavour weight at `iPropagationLevel + 1` | Tiny: shallow policy trees. Flavour weights may be built before the test settings load at game start, in which case the flag only acts on later flavour updates |
| `EspionagePolicyValue` (`FIX_ESPIONAGE_POLICY_VALUE`) | P4 | The passive espionage bonus is scored with its own value | Late game only |

Status: on `ai/economy` as `ccbb01a`. Lead's plan: `PolicyPrereqDepth` goes into the next screening run;
`IdeologyPick` and `EspionagePolicyValue` wait for phase 2's long-game setup, since ideologies and spies rarely
exist by T150 on Quick.

### Greedy style: four flags (Personality, 2026-11-03 11:10pm ET)
Why now: every civ in the bully games is a normal CP AI with a real army, so the bully only ever meets the hard
matchup ("The bully goals wait for an attacker that conquers"). The greedy style gives it the easy one: if the
conquest code can't take cities from these civs, it can't take them at all.

- **Hypothesis:** civs with the four flags keep about one land unit per city, have no walls, castles or barracks,
  keep their obsolete units, and put the production and gold into growth, science and wonders. In peace they
  out-grow the others (more population, techs, wonders); against an attacker that conquers they lose cities.
- **The four flags** (one idea each, all `false` in the bundle, AI major civs only: `UsesCandidateAI` gives
  city-states the bundle, which has none of them, and each check also tests `isMajorCiv()`):

  | Flag | Change | Knobs | Code |
  |---|---|---|---|
  | `GreedyFewUnits` (`FIX_GREEDY_FEW_UNITS`) | Cap on land combat units, any opening book (`GreedyArmyCap` is tall-book and peace only). No 75% "tiny army" cut on buildings, which would only push production into processes since the cap blocks the units | **1 per city at peace, 2 at war** with a major civ; **+2 for operations** (settler escorts); a city under siege may still build defenders | `CvUnitProductionAI::CheckUnitBuildSanity`, `CvBuildingProductionAI::CheckBuildingBuildSanity` (war section) |
  | `GreedyNoWalls` (`FIX_GREEDY_NO_WALLS`) | No building that adds city defence, city HP or unit XP (walls, castles, barracks, armory...), wonders excepted | always, war included | `CvBuildingProductionAI::CheckBuildingBuildSanity` (top) |
  | `GreedyNoUpgrades` (`FIX_GREEDY_NO_UPGRADES`) | No unit upgrades and no gold saved for them | **only at war** with a major civ | `CvUnit::CanUpgradeRightNow` (AI only; every AI upgrade path asks it), `CvHomelandAI::PlotUpgradeMoves` |
  | `GreedyBuilds` (`FIX_GREEDY_BUILDS`) | World wonders and buildings with food, food kept on growth, or science (flat, per pop, or %) valued more | **x1.5** | `CvBuildingProductionAI::CheckBuildingBuildSanity` (end) |

  `GreedyAlarm` (Economy), when it's on and fires, lifts `GreedyFewUnits` and `GreedyNoWalls`, so greed plus alarm can
  be tested later. Personality flavours are left alone on purpose: they also pick the c/b split, the bully roles and
  the opening book (`IsABTestWarmongerCiv`, `GetABTestRoleOfSlot`), so changing them would move civs between roles.
- **Measures** (per civ, c8d columns, greedy civs against the same slots without the style):
  - the style is on: `LandUnits` ≈ `Cities` (≤ 2× at war), `WalledCities` = 0, `CityStrength` and `Military` lower;
  - the payoff: `Population`, `Techs`, `ResearchSpent`, `Wonders` higher; the no-military share above 50%;
  - the price (bully test): the aggressor's `CitiesCaptured` and city share, `CitiesLost` of the greedy civs.
- **What to run** (the lead's style key gives the four flags to every civ without a role, in both games of a pair):
  1. One logged smoke pair: no crash, a matching replay, and the columns above show the style.
  2. **The easy matchup:** bully mode, aggressor on the conquest role flags as in the bully conquest test, every
     other civ greedy:
     `Run-Games.ps1 -Mode bully -Fixes none -OthersBase "GreedyFewUnits, GreedyNoWalls, GreedyNoUpgrades, GreedyBuilds" -RoleFixes "TimingAttack, DeclareTiming, SiegeBook, SiegeTechs, SiegeArmy, ArmyHandoff"`.
     The tall role civ is not greedy (OthersBase skips roles). Reference: in bully pair 07614B74 normal CP civs
     ended T150 with 103-246 military and the aggressor 191. Compare
     captures and the aggressor's city share with the bully conquest test (normal defenders). Expected: several
     captures by T150. If there are still none, the attack side is the blocker, not the defenders.
  3. Later, split games with the four flags as `Fixes` against B: the greedy group's no-military share (it should
     win in peace; strength share counts military, so it may not).
- **Evidence level:** 3 (new behaviour), but as a style it's judged by the matchup and bully tests, not by the
  split-game SPRT (AGENTS.md, "What greedy trades").
- **Build:** fork `ai/personality` `b9384af` (rebased onto `claude/ab-c1` `1804369`, the OthersBase key; first pushed as
  `8e69e07` on `ec2a4c8`); CI publishes `ab-ai-personality-latest`.
- **Status:** compiles (CI run 109 on `8e69e07` passed, 11:28pm ET; the same code rebased as `b9384af`). Ready for the
  OthersBase runs.
- **Notes for owners:** `CvUnitProductionAI` and `CvBuildingProductionAI` are Economy's, `CvHomelandAI` War's,
  `CvUnit.cpp` shared; each change is a gated block at the place named above. Request to Economy: `GreedyAlarm` only
  watches for tall-book civs (`GetGreedyAlarmThreat`); for the style it should also fire for civs running
  `GreedyFewUnits`, so "greedy + alarm" works for any book.

### Balanced and aggressive styles: four flags (Personality, 2026-11-03 11:20pm ET)
The other two corners of the triangle (AGENTS.md, "A rock-paper-scissors meta"). Greedy beats balanced by
out-growing it, aggressive beats greedy by taking its cities, balanced beats aggressive by holding.

- **Hypothesis:**
  - **Balanced** civs keep a medium army (2-3 land units per city in peace), wall their border cities early, and
    otherwise play CP's normal game (CP's war appetite is low, so they rarely start wars). Against an attacker they
    lose ≤ 1 city per war, and the attacker's army is wasted.
  - **Aggressive** civs build a big army (3-4 per city) with siege, and play the conquest plan (timing attack on the
    thinnest neighbour) whatever their personality. Against greedy civs they take cities; against balanced civs
    they stall and fall behind economically.
- **The flags** (all `false` in the bundle, AI major civs only, each check also tests `isMajorCiv()`):

  | Flag | Change | Knobs | Code |
  |---|---|---|---|
  | `AggressivePlan` (`FIX_AGGRESSIVE_PLAN`) | Counts as a warmonger for the candidate conquest flags: `TimingAttack`, `DeclareTiming`, `SiegeBook`, `SiegeTechs` (all gated by `IsCandidateWarmonger`). It does nothing alone: run it with those flags. `IsABTestWarmonger` (split, screening, roles, `Warmonger` column) still reads the personality | none | `CvPlayer::IsCandidateWarmonger` |
  | `AggressiveArmy` (`FIX_AGGRESSIVE_ARMY`) | Army floor and ceiling in peace. Below the floor, buildings are cut 75% (CP's own rule, which B relaxed to 1 per city), and attack, siege, fast-attack and ranged units get +300. The ceiling lifts CP's recommended land army size, within supply | **floor 3, ceiling 4** land units per city | `CvUnitProductionAI::CheckUnitBuildSanity`, `CvBuildingProductionAI::CheckBuildingBuildSanity` (war section) |
  | `BalancedArmy` (`FIX_BALANCED_ARMY`) | The same for a medium army. Below the floor, defence, counter and ranged units get +300. Above 3 per city in peace no more land units (operations +2), so the rest goes into the economy | **floor 2, cap 3** per city in peace; no cap at war | same |
  | `BalancedWalls` (`FIX_BALANCED_WALLS`) | Walls, castles and anything else that adds city defence or HP get a flat +800 in border cities and the capital: built as soon as the tech allows | **+800**; border cities (`isBorderCity`) and the capital | `CvBuildingProductionAI::CheckBuildingBuildSanity` (top) |

  Upgrades: balanced and aggressive keep CP's (only greedy skips them). Not coded on purpose, to add only if the
  matchups show the need:
  - a "peaceful" flag for balanced civs (no wars started except against a warmonger), if balanced civs attack greedy
    ones and break "greedy beats balanced";
  - an aggressive flag that keeps neighbours from becoming friends, if the logs show `CONQUEST: going for X` but no
    declaration (Diplomacy found trade friendships crowd out WAR).
- **The style sets** (what the lead's keys should list):
  - greedy: `GreedyFewUnits, GreedyNoWalls, GreedyNoUpgrades, GreedyBuilds`;
  - balanced: `BalancedArmy, BalancedWalls`;
  - aggressive: `AggressivePlan, AggressiveArmy, TimingAttack, DeclareTiming, SiegeBook, SiegeTechs, SiegeArmy, ArmyHandoff, GreedyTarget`.
- **Measures:**
  - the style is on: `LandUnits` per city ≈ 2-3 (balanced) and ≥ 3 (aggressive) at peace; `WalledCities` close to the
    number of border cities (balanced); `CONQUEST:` lines and `WarsDeclared` from aggressive civs that aren't
    personality warmongers;
  - the matchups: cities captured and lost, the attacker's city share, and strength share per style pair.
- **What to run:**
  1. **The hard matchup**, next to the greedy one:
     `Run-Games.ps1 -Mode bully -Fixes none -OthersBase "BalancedArmy, BalancedWalls" -RoleFixes "TimingAttack, DeclareTiming, SiegeBook, SiegeTechs, SiegeArmy, ArmyHandoff"`.
     Expected: far fewer captures than against greedy civs, ≤ 1 city per war. The two runs together set the attack
     goal's numbers (lead's plan, step 3).
  2. **One logged smoke pair of the aggressive set** as OthersBase in bully mode: no crash, a matching replay, and
     `CONQUEST:` lines and ≥ 3 land units per city from civs that aren't personality warmongers.
  3. **The 3x3 table needs every style at once**, which OthersBase can't do (one set for all). **Request to the
     lead: `Mode = styles`** (AGENTS.md: "an extension of the bully and builders roles"):
     - each AI civ gets one of the three sets, about a third each (3/3/2 with 8 civs), dealt from the map seed, not
       from personality (leaders are random anyway, and this separates the style from the leader);
     - a `Rotate` key (0, 1, 2) shifts every slot's style by one, so each seed played three times gives every slot
       every style and cancels start-position luck, as the pair's flip does for two groups;
     - a `Style` column in the results file.

     Summarize then fills the 3x3 table: each style's strength share and cities captured from and lost to each other
     style. Once the triangle shows, the style is chosen by personality (the strategy profile, my next job).
- **Evidence level:** 3, judged by the matchups and the bully test, not by the split-game SPRT (as for greedy).
- **Build:** fork `ai/personality` `81b6634` (on the greedy commit `b9384af`, off `claude/ab-c1` `1804369`).
- **Status:** compiles (CI run 111 passed, 11:40pm ET).
- **For the lead, fair play:** `GreedyTarget` scores a target by its real land units per city
  (`getNumMilitaryLandUnits`), not the units the attacker can see. That's a fog cheat by rule 6 (fair play). It's
  c7's flag, so the owner should switch it to visible units before it becomes part of a style.
- **Notes for owners:** the edits are gated blocks in Economy's `CvUnitProductionAI` and `CvBuildingProductionAI` and
  in the shared `CvPlayer.cpp` (`IsCandidateWarmonger`).

### Decision: meta position and flavour archetype are two separate things (the user, 2026-11-03 11:30pm ET)
- **The three meta archetypes** (greedy, balanced, aggressive) are three points on one spectrum, not three boxes.
  They are objective, measurable ways of winning, and the mix ebbs and flows into different equilibriums.
- **Flavour archetypes** are separate: fun, distinctive ways of playing. Examples: the expansionist who never
  attacks unless someone blocks his expansion, the tourism hoarder, the religious zealot. They can win, but they
  aren't the meta.
- **Each flavour archetype sits somewhere on the meta spectrum.**

For the lead: AGENTS.md's archetype table ("How personality and the others fit together") mixes the two (greedy
tall and early timing attack are meta positions; wide expander and diplomat are flavours). Suggest rewording it
with this decision, and pointing "A rock-paper-scissors meta" at the spectrum. The spec below is built on it.

### The strategy profile: spec (Personality, 2026-11-03 11:30pm ET)
For War, Economy and Diplomacy: what each AI is trying to do, and the rules it plays by. They decide how. Nothing
here is coded yet; the build steps are at the end.

**1. The profile, per AI major civ.** Worked out at game start from game data only (traits, leader personality, CP's
victory pursuit pick), so every computer gets the same result.

| Part | What it is | Source |
|---|---|---|
| Flavour archetype | One of the list in 2, fixed for the game | Unique ability tag, then CP's victory pursuit (3) |
| Meta position **M** | A number from -100 (greedy) through 0 (balanced) to +100 (aggressive). A home position, and a current position that moves (4) | Archetype range plus personality (Boldness, offence flavour) |
| Victory weights | Domination, science, culture, diplomacy, adding up to 100 | 40% the archetype's weights, 40% CP's primary pursuit, 20% the secondary (or the primary if there's none) |
| Risk appetite | Low, medium or high: how big an edge it wants before a war, how far it lets a rival run | Leader Boldness |
| Expansion style | Tall (4 cities), medium, wide (settle all it can), conquest (cities taken, not settled) | Archetype, adjusted by the expansion flavour |
| Hard rules | Never broken whatever the scores say (5) | Everyone, plus per archetype |

**2. Flavour archetypes** (a first list; more come from games and the players):

| Archetype | Plan | Home M (range) | Victory weights | Expansion |
|---|---|---|---|---|
| Conqueror | Repeated wars all game; strikes the thinnest neighbour at its army's timing, consolidates, goes again | +70 (+40 to +100) | domination first | conquest |
| Opportunist | Builds, but joins or starts wars against weakened, isolated or runaway neighbours | +15 (-10 to +40) | its pursuit's | medium |
| Expansionist | Settles every free spot; never attacks unless a neighbour blocks its expansion (`BoxedInWar`) or a runaway threatens | 0 (-20 to +30) | its pursuit's | wide |
| Religious zealot | Founds early, spreads its faith everywhere, protects its holy city, rivals whoever converts its cities | 0 (-30 to +30) | culture and its pursuit's | medium |
| Diplomat | City-state patron, World Congress, the one who organises coalitions; keeps its word | -20 (-50 to +10) | diplomacy first | medium |
| Tourism hoarder | Wonders, great works, tourism; builds in peace and hates being disturbed | -60 (-90 to -30) | culture first | tall |
| Scientist | Tall science civ: libraries, universities, the National College early, spaceship | -60 (-90 to -30) | science first | tall |

**3. Who gets which archetype.** A rule, not a hand-made list, so it covers modded civs too:
1. **The civ's unique ability** (CP's trait tags in `CvPlayerTraits`): Warmonger → Conqueror, Religious → Zealot,
   Tourism → Tourism hoarder, Nerd or Smaller → Scientist, Diplomat → Diplomat, Expansionist → Expansionist. If a
   civ has two tags, the primary victory pursuit breaks the tie.
2. **No tag:** CP's primary victory pursuit for this game (`SelectDefaultVictoryPursuits`; leaders with no fixed
   pursuit get a random one each game, so generalists vary): domination → Conqueror if offence flavour ≥ 7, else
   Opportunist; science → Scientist; culture → Tourism hoarder; diplomacy → Diplomat; none → Expansionist if the
   expansion flavour ≥ 7, else Opportunist.
3. **Home M** = the archetype's home + 5 × (Boldness − 5) + 5 × (offence flavour − 5), kept inside its range.

Expected picks for some base leaders, to check against the first logged games: Attila, Genghis, Shaka, Askia,
Montezuma, Oda Nobunaga → Conqueror; Sejong, Nebuchadnezzar → Scientist; Boudicca, Selassie, Theodora → Zealot;
Pedro → Tourism; Alexander, Ramkhamhaeng → Diplomat; Pocatello, Hiawatha, Gajah Mada → Expansionist. VP's leader groups
(Conqueror, Coalition, Diplomat, Expansionist in VP's `LeaderFlavorSweeps.sql`) are a cross-check, not the source:
the pack runs CP.

**4. The meta position moves (adaptation within a game, AGENTS.md goal 7).** Current M = home M plus shifts,
worked out each turn from what the civ can see:
- **Threatened** (`GreedyAlarm`'s signal: a visible army near its cities; at war on the defensive; lost a city in
  the last 20 turns): M rises to at least 0. A greedy civ arms up and walls.
- **Attack stalled** (at war for 15+ turns without taking a city, its target walled, or 2+ civs at war with it):
  M falls by 40, at most to 0. The conqueror makes peace or digs in, and re-arms later.
- **Opportunity** (a close neighbour with visibly fewer than 1 land unit per city, or already losing a war): M
  rises by 30, up to the archetype's maximum. The opportunist strikes; a scientist doesn't, because its range stops
  at -30.
- **Runaway** (a civ with a severe warmonger threat, or near a victory): M rises to at least 0 for everyone, so the
  coalition has armies.
- Smoothed: M moves at most 20 a turn, and a shift holds for at least 10 turns, so plans don't flip back and forth.
  M is saved with the game.

**What M sets** (the style flags are the anchor points; between them the numbers interpolate):

| Setting | M = -100 (greedy) | M = 0 (balanced) | M = +100 (aggressive) |
|---|---|---|---|
| Land units per city in peace (floor / ceiling) | 1 / 1 | 2 / 3 | 3 / 4 |
| Walls and castles | none (until threatened) | first in border cities and the capital | border cities |
| Unit upgrades | only at war | normal | normal |
| Growth, science, wonder buildings | ×1.5 | ×1 | ×1 |
| Conquest plan (timing attack, siege book and techs) | no | no | from M ≥ +50 |
| War appetite (WAR approach weight) | ×0.5 | ×1 | ×2 |

**5. Hard rules.**
- **Everyone:** the banned behaviours (no stealing workers from city-states, no chop-rushing wonders); no war on a
  civ it is receiving or paying per-turn deal items to, unless that civ broke a deal first; no war on its own
  friend inside the friendship's first 15 turns.
- **Expansionist:** declares war only on the neighbour blocking its land or on a runaway.
- **Tourism hoarder, Scientist:** start no wars of their own, except to retake their own city or in a coalition
  against a runaway.
- **Diplomat:** never attacks a city-state, never breaks a friendship or a deal, protects city-states it's allied with.
- **Zealot:** never trades away its holy city in a peace deal; doesn't buy missionaries for a religion it didn't found
  (already the bundle's `NoForeignMissionaries`).
- **Conqueror, Opportunist:** no extra rules; their wars still pay CP's warmonger penalties and draw coalitions.

**6. What the other sessions read** (one accessor, `GetGrandStrategyAI()->GetStrategyProfile()`):
- **War:** M (army size, when to attack, when to stop), risk appetite (the edge it wants: `GetNewAIConquestTarget`'s
  strength bar), the archetype's war rules.
- **Economy:** M (production split, walls, upgrades), expansion style (opening book: tall, wide or conquest), victory
  weights (buildings and techs).
- **Diplomacy:** the hard rules (which wars are allowed), M and risk (war appetite, how far a rival may run), the
  Diplomat's coalition role.
- **Personality** (mine): `CvGrandStrategyAI` priorities from the victory weights.

**7. Build steps** (one flag each, a hypothesis entry before each):
1. **The profile itself, measurement only (level 1):** worked out and logged (AI log `StrategyProfile_Log.csv` at turns
   1, 50, 100, 150: civ, leader, trait tags, pursuits, archetype, home M, weights, risk, expansion). No decision reads
   it. **Coded:** fork `ai/personality` `7afce5c` (`CvGrandStrategyAI::GetStrategyProfile`). CI run 112 failed on MSVC's
   C4701 (an uninitialised-variable warning this build treats as an error). The lead fixed it on `claude/ab-c1` `c78384b`
   (CI run 119 passed); `ai/personality` now follows `claude/ab-c1`. **Request to
   the lead:** results columns `Archetype` and `Meta` (home M now, current M once `MetaAdapt` exists), from
   `GetGrandStrategyAI()->GetStrategyProfile()`; and a logged game to check the picks against the expected ones above.
2. **`MetaDial`:** the style flags read M instead of a fixed set. Judged by the matchup test (styles from M) and a
   no-worse SPRT.
3. **`MetaAdapt`:** the shifts in 4. Judged by the bully test (does a threatened greedy civ hold?) and the adaptation
   checks in AGENTS.md.
4. **`ProfileVictory`:** grand strategy priorities from the victory weights.
5. **Per-archetype rules**, one flag each (`ExpansionistPeace`, `BuilderPeace`, `DiplomatWord`, `ZealotHolyCity`).
6. **Personality tests** (AGENTS.md): different (archetypes differ measurably per the results columns), viable (each
   archetype's strength share is near the average over many games), done well (per-archetype checks).

**Open for the user:** the archetype list and the home positions are first guesses, to tune once the matchup test
gives the triangle's numbers.

### MetaDial: the style settings follow the meta position (Personality, 2026-11-03 11:45pm ET)
Build step 2 of the strategy profile.
- **Hypothesis:** with each AI's army size, walls, upgrades and building priorities set by its meta position
  (the profile's home position), leaders play measurably different styles: Scientists and Tourism hoarders greedy,
  Conquerors aggressive, the rest in between. Strength stays no worse than B, since the settings are the style
  flags' fixed points and the line between them.
- **The dial** (flag `MetaDial`, `FIX_META_DIAL`, `false` in the bundle, AI major civs only; a style flag that is on
  takes precedence):

  | Setting | M = -100 | M = -50 | M = 0 | M = +50 | M = +100 |
  |---|---|---|---|---|---|
  | Land units per city in peace: floor / ceiling | 1 / 1 | 1.5 / 2 | 2 / 3 | 2.5 / 3.5 | 3 / 4 |
  | Land units per city at war: cap | 2 | 2 | none | none | none |
  | Walls, castles, barracks | none | none | +800 in border cities and capital (from 0 at M = -50) | +800 | +800 |
  | Upgrades in peace | no | no | yes | yes | yes |
  | Small-army cut on buildings (75% below the floor) | off | off | on | on | on |
  | Growth, science, wonder value | +50% | +25% | +0% | +0% | +0% |
  | Unit types first below the floor | none | none | defenders, ranged | attack, siege, ranged (from +25) | same |
  | Conquest plan (counts as a warmonger) | no | no | no | yes | yes |

  The conquest plan only acts where the conquest flags also run: list `TimingAttack, DeclareTiming, SiegeBook,
  SiegeTechs` (and `SiegeArmy, ArmyHandoff`) with `MetaDial`.
- **Not in the dial yet:** war appetite (the WAR approach weight, spec section 4). It's a separate idea in Diplomacy's
  scoring, so it gets its own flag (`MetaWarAppetite`) once the dial shows the styles work.
- **Where M comes from:** `CvGrandStrategyAI::GetMetaPosition()`, the profile's home position worked out once per turn
  (not saved; the profile is a pure function of game data). `MetaAdapt` will move it later.
- **Code:** `CvPlayer` (`UsesMetaDial`, `GetMetaDialPosition`, `IsMetaDialGreedy`, `GetMetaDialLandUnitsPerCityTimes10`;
  `IsCandidateWarmonger`), `CvUnitProductionAI::CheckUnitBuildSanity`, `CvBuildingProductionAI::CheckBuildingBuildSanity`
  (walls, small-army cut, growth value), `CvUnit::CanUpgradeRightNow`, `CvHomelandAI::PlotUpgradeMoves`: the same gated
  places as the style flags.
- **Measures:**
  - the dial works: `LandUnits` per city and `WalledCities` follow M (needs the `Meta` and `Archetype` columns
    requested in the spec; until then, `StrategyProfile_Log.csv` in logged games gives each civ's M);
  - strength share at T150: no worse than B;
  - personality tests: per archetype, wars declared, cities, techs, wonders and army size differ.
- **What to run:**
  1. A logged smoke pair (`-Fixes "MetaDial"`, split mode): no crash, a matching replay, `StrategyProfile_Log.csv`
     present, and land units per city matching each c civ's M.
  2. A no-worse SPRT at T150, paired: `-Fixes "MetaDial"` against B.
  3. With the conquest flags (`-Fixes "MetaDial, TimingAttack, DeclareTiming, SiegeBook, SiegeTechs, SiegeArmy,
     ArmyHandoff"`) once attacks take cities: does the meta mix by personality give a living map (wars from
     Conquerors, greedy civs paying for it)?
- **Evidence level:** 3 (new behaviour), but the meta-level effects are judged like the styles (matchups, bully test);
  the SPRT here is the no-worse guard.
- **Build:** fork `ai/personality` `3b056a9`, merged into `claude/ab-c1` (`c13eb1c`) with the lead's C4701 fix (`c78384b`).
- **Status:** compiles (CI run 119 on `c78384b` passed). Not tested in games yet.

### Greedy style in bully pair 0B09BFE1: walls hold, the unit cap leaked; where the units came from (Personality, 2026-11-04 7:55am ET)
Pair `0B09BFE1` (`ab-c78384b`, PC 2, `AIABTest_bullygreedy@TREEDESKTOP.csv`, logs `logs_0B09BFE1*`). The six civs without a
role ran the four greedy flags in both games. Replay matched, no crash. The lead's summary is in "Bully vs greedy civs,
logged pair".

**The style, per greedy civ (both games, 12 civ-games), against the two non-greedy role civs in the same games:**

| | Land units per city | Walled cities | City strength per city | Population | Techs | Wonders |
|---|---|---|---|---|---|---|
| Greedy, T100 | 1.62 | 0 | 15 | 19.8 | 19.4 | 1.2 |
| Greedy, T150 | 1.82 | 0.03 per city (2 cities in 12 civ-games) | 21 | 34.7 | 27.2 | 2.8 |
| Aggressor and tall civ, T150, game 1 | 2.6 and 2.2 | 5 of 5 and 3 of 5 | | | | |

- **Walls, castles, barracks:** work.
- **The unit cap:** leaked, by two routes. The production log shows only a few land units chosen: Siam built a
  warrior, a scout and a swordsman (3 land units chosen T1–T150) and owned 8 at T110–T120 in peace.
  1. **City-state unit gifts, in peace.** Militaristic city-states give each friend a land unit every ~19 turns
     (faster for allies, and Siam's ability speeds it up), and may gift one on first contact. Nothing checked the
     cap, and the AI never switches gifts off. In peace Siam held 8 land units on 4 cities (T110–T120) and the
     Aztecs 7 on 5 (T100–T110), with scouts counted.
  2. **The siege exemption, at war.** My cap let every city under siege build or buy defenders past it.
     CvTacticalAI's emergency purchases go through the same sanity check, so a civ at war had no limit: the Aztecs
     reached 14 land units on 5 cities (cap 10), Songhai 13 on 5.
  - Units left over from a war stay: the cap stops new units, it doesn't disband old ones (Songhai 10 units on
    5 cities in peace T110–T120 after its war). Left as is: a greedy human might disband them, but it risks being
    caught short in the next war.
  - The `LandUnits` column counts scouts, the cap doesn't (about +1 per civ).
  - `Military` is military might, not a unit count: the same units score more as they get newer, so 229 for Songhai
    is 13 units of era-3 strength.
- **The fix** (fork `ai/personality` `d51e8a6`, on `claude/ab-c1` `dbdfbb3`; same flags, no new flag):
  1. A greedy AI (`GreedyFewUnits`, or `MetaDial` at -50 or below) switches unit gifts off with every city-state
     while it is at its cap, and back on below it: the same switch a human has in the city-state screen
     (`CvGrandStrategyAI::DoGreedyCityStateUnitGifts`, every turn; `CvMinorCivAI::SetUnitSpawningDisabled`). Unit
     gifts are all it stops.
  2. A city under siege gets a defender past the cap only if it has no garrison (`CvUnitProductionAI`, the
     `GreedyFewUnits` block and MetaDial's greedy side).
- **What to check after it:** greedy civs' `LandUnits` per city ≈ 1 in peace (1.5 with scouts) and ≤ 2 (+2) at
  war, and whether the bully then takes cities. War's finding (the siege walks home to heal) matters more for
  captures than the extra greedy units.
- **Profile check:** the saved logs don't include `StrategyProfile_Log.csv` (it was added on `7afce5c`, and the runner
  copies a fixed list of logs). **Request to the lead:** add `StrategyProfile_Log.csv` to the logs the runner saves.
- **Status:** `d51e8a6` compiles (CI passed) and is merged into `claude/ab-c1` (the lead, 8:10am ET). PC 2 plays it as
  `AIABTest_bullygreedy3@TREEDESKTOP.csv`.
- **Follow-up, `d379bfe` (8:10am ET; compiles, merged in `5220c03`):** the gift switch covers every style with a cap: `BalancedArmy` at 3 per
  city in peace, MetaDial at its peace ceiling up to position 0. `AggressiveArmy` and MetaDial's aggressive side keep
  their gifts.

### Conquest bonuses in the strategy profile: which leaders move (Personality, 2026-11-04 10:15am ET)
The user's task (via the lead): use each civ's conquest bonus. Personality's half: the profile puts conquest-bonus civs
on the aggressive side, and civs that take city-states without war on the diplomat side. War does target choice
(`ConquestTraitTargets`).

**What the profile did before.** It took CP's trait tags (`CvPlayerTraits::IsWarmonger`, `IsNerd`, `IsSmaller`,
`IsDiplomat` ...). When a civ had two tags, the primary victory pursuit broke the tie, and CP scores that pursuit
from flavours and tags each game, not from a fixed table. Two gaps:
- CP's tags overlap. Tech from captured cities sets both the warmonger and the science tag (Assyria). "No annexing"
  sets the smaller tag (Venice), which the profile read as Scientist.
- The raze-speed bonus (the Huns) isn't in any of CP's tags.

**The change** (fork `ai/personality` `277602f`, on `claude/ab-c1` `d2390a1`; in `CvGrandStrategyAI::GetStrategyProfile`,
read from trait fields so mods and other civs work too):
1. **A conquest bonus makes a civ a Conqueror, before any tag, with home meta position at least +50** (MetaDial's
   conquest plan). The bonuses: tech from captured cities, plunder gold, raze speed, combat against city-states,
   production, great works, golden ages or yields from conquest, keeping conquered buildings.
2. **Taking city-states without war makes it a Diplomat, before the science and smaller tags:** diplomatic marriage,
   annexing city-states, or a unique unit that can buy a city-state.

**Which leaders move** (base civs; tags worked out from each civ's ability and CP's tag rules, since the base game's
trait data isn't in either repo; the first logged games' `StrategyProfile_Log.csv` will confirm):

| Civ (leader) | Bonus | CP tags | Before | After |
|---|---|---|---|---|
| Assyria (Ashurbanipal) | tech from each captured city | warmonger and science | Conqueror if its pursuit came out domination, **Scientist** if science | **Conqueror**, M ≥ +50 |
| Songhai (Askia) | triple gold from captures and camps | warmonger | Conqueror, M from +40 | Conqueror, M ≥ +50 |
| Huns (Attila) | raze twice as fast | none from this bonus | Conqueror only if its pursuit came out domination with offence ≥ 7 (otherwise by its other tags, or Opportunist) | **Conqueror**, M ≥ +50 |
| Mongolia (Genghis Khan) | +30% against city-states | warmonger | Conqueror, M from +40 | Conqueror, M ≥ +50 |
| Austria (Maria Theresa) | diplomatic marriage | diplomat | Diplomat | Diplomat (no change) |
| Venice (Enrico Dandolo) | buys city-states with the Merchant of Venice | smaller (and diplomat from its trade routes) | **Scientist** unless its pursuit came out diplomacy | **Diplomat** |

So the moves are:
- **Assyria and the Huns** become certain Conquerors.
- **Venice** becomes a Diplomat.
- **Songhai, Mongolia** (and Assyria, the Huns) get the +50 floor.
- **Austria** doesn't change.

**What it affects now:** `StrategyProfile_Log.csv`, and `MetaDial` (merged, not yet in any run). The style flag sets
don't read the profile.

**Status:** coded; CI pending.

### The three styles as flag sets, for the trio test (Personality, 2026-11-04 9:20am ET)
For the lead's trio mode (AGENTS.md, "The trio goal": one greedy, one balanced and one aggressive civ of ours plus 3 CP
civs, 6 players). Nothing is coded for it; this is the list a test key would give to one slot each.

| Style | Flags | What it plays |
|---|---|---|
| **Greedy** | `GreedyFewUnits, GreedyNoWalls, GreedyNoUpgrades, GreedyBuilds, GreedyWarArmy` | 1 land unit per city in peace (disbands down to it), no walls or barracks, no upgrades in peace, growth, science and wonders first. At war it judges the threat: nothing changes unless a city is under siege or an enemy force in sight could take one, and then it builds enough defenders and walls its border cities |
| **Balanced** | `BalancedArmy, BalancedWalls` | 2-3 land units per city in peace, no cap at war, walls and castles first in border cities and the capital, upgrades as normal; otherwise CP's play, which starts few wars |
| **Aggressive** | `AggressivePlan, AggressiveArmy` + the conquest role: `TimingAttack, DeclareTiming, SiegeBook, SiegeTechs, SiegeArmy, ArmyHandoff, SiegeAbort, SiegeFormation, SiegeStay, SiegePosture, SiegeFirst, SiegeFinish` | 3-4 land units per city in peace with siege; the conquest plan (siege techs and book, a timing attack on a weak close neighbour, a siege that holds and finishes), whatever its personality |

**Notes for the trio mode:**
- **The bundle runs under each set.** "Ours" means the candidate AI, so each style slot runs the bundle (the flags that
  passed) plus its style set, like group c today.
- **What "CP" means for the opponents:** stock CP (rung A) needs a build with `kABTestVersusBase = false`; with
  `claude/ab-c1` as built, every civ runs B underneath. For the lead to decide.
- **Style slots don't list `MetaDial` or `WarAppetite`.** Those read the strategy profile's meta position, so they're for
  the later test where the style comes from the leader's personality. A style flag takes precedence over the dial,
  but walls and growth value would mix.
- **`GreedyTarget` is left out of the aggressive set** until it uses only the units the attacker can see (today it
  reads the target's real unit count: a fog cheat). Without it, `TimingAttack` picks the weakest close neighbour by
  CP's strength estimate.
- **`GreedyAlarm` (Economy) is left out of the greedy set.** `GreedyWarArmy` does its job at war, and the alarm only
  covers tall-book civs. A peace-time alarm for any greedy civ could join later if the matchups ask for it.
- **Our three may fight each other.** The aggressive civ picks the weakest close neighbour, which can be our greedy
  civ. The AI can't know which civs are "ours" (rule 6, fair play), and the cycle is the point: greedy out-grows
  balanced, aggressive punishes greedy, balanced holds against aggressive.
- **Status of each set:**
  - greedy: the strict four are in the bully runs; `GreedyWarArmy` is merged but untested; the disband fix (`b4213b4`)
    compiles (CI run 140) and waits for the lead's merge;
  - balanced: untested;
  - aggressive: the conquest role took its first cities on 2026-11-04. `AggressivePlan` and `AggressiveArmy` are
    untested, and only matter for a civ that isn't a personality warmonger.

### Greedy cap, second leak: units kept after a war and after escorts (Personality, 2026-11-04 9:00am ET)
Pair `0B58EE0F` (`ab-d51e8a6`, `AIABTest_bullygreedy3@TREEDESKTOP.csv`, logging off, rows every 10 turns). The lead saw
about 2 land units per city in peace (Assyria 11 on 5 at T100; flipped game Assyria 16 on 7, Indonesia 14 on 6 at
T150). The per-turn rows (land units/cities, w = at war):
- **War leftovers, the main route:**
  - Assyria (game 1): 4/6w at T80–T90, 5/11 in peace at T100;
  - Assyria (flipped): 7/14w and 7/15w at T130–T140, 7/16 in peace at T150;
  - Indonesia (flipped): 6/12w at T110, 6/14 in peace at T150.

  At war the cap is 2 per city plus 2 for operations. City-state gifts are taken up to it, and a city under siege
  with no garrison may still get a defender. The units stayed after peace, since the cap stops new units but disbands
  nothing.
- **Escorts, the small drift in peace:** the flipped game's Inca was never at war and held 10 on 6 cities. That's
  about 2 scouts (`LandUnits` counts them, the cap doesn't) plus 8 others: the cap plus the 2 allowed for settler
  escorts, which stay once the operation ends.
- **Ruled out:** production, purchases and city-state gifts all go through the cap (`d51e8a6`); upgrades replace
  units without adding any; ruins are off.
- **Fix** (`ai/personality` `b4213b4`, on `claude/ab-c1` `5220c03`; no new flag, it's part of `GreedyFewUnits` and
  MetaDial's greedy side): `CvGrandStrategyAI::DoGreedyDisbandToCap`. In peace, a civ above its peace cap lets one
  land unit go each turn, once three things hold: no war with a major, 10 turns since its last peace treaty (a war
  may start again), and GreedyAlarm quiet. It picks the weakest unit that isn't a scout, isn't in an army, and
  preferably isn't in a city. Like CP's own scrapping, it gifts the unit to a city-state if one would take it,
  otherwise scraps it. Logged (`GREEDY:` in the homeland log) in logged games.
- **Expected:** greedy civs at peace back to about 1 land unit per city within a few turns after the 10-turn wait;
  `LandUnits` ≈ cities + scouts (about +2).
- **Status:** compiles (CI run 140 on `b4213b4` passed, 9:16am ET). Ready for the lead to merge.

### GreedyWarArmy: at war a greedy civ judges the threat (Personality, 2026-11-04 8:15am ET, revised 9:15am ET)
- **The user (2026-11-04), in three steps:**
  1. "maybe it's just for the test, but a greedy civ should build military units if it is at war";
  2. "enough to defend";
  3. "a greedy civ who has war declared on them should judge how much threat it is under. If the person at war with
     them is on the other side of the world or has a very weak army, then maybe they make no change to their plan of
     not making military units."
  4. "if they are currently under siege or their neighbour with a large army has declared war, then they should
     prepare accordingly."
  5. "a 'large army' is one that is capable or close to capable of taking one of your cities."
- **Hypothesis:** with `GreedyWarArmy`, a greedy civ keeps its economy through wars that can't hurt it, and builds
  enough defenders when one can. It holds more cities than strict greedy civs, but fewer than balanced ones, since it
  starts each real war with about 1 unit per city and no walls. Judged by the matchup test.
- **The threat** (`CvGrandStrategyAI::GetWarDefenceLandUnitCap`, worked out once per turn; enemies are major civs at war
  with us). A war is a credible threat when:
  - one of our cities is under siege, or
  - **an enemy force in sight could take one of our cities, or nearly.** For each of our cities, that enemy's land
    combat units we can see within 8 plots go through a siege sketch (`CouldEnemyTakeCity`). It's a defender's version of
    War's `CanTakeNearestCity` (flag `CanWin`): their ranged units fire, the city heals 20 a turn and shoots the most
    damaging one, which drops out once it dies, for up to 20 turns. "Close to capable": their damage counts a third
    extra, and one melee unit is enough to walk in. Only units a human could see: an army out of sight counts once it
    comes into view, so the greedy civ has fewer turns to prepare. That's part of its price.

  Under a credible threat the civ wants the larger of 2 land units per city and 3/4 of the enemy land units in sight
  within 5 plots of its cities. Without one (a far enemy, a force that couldn't take a city), the threat is 0.
- **What the flag does** (`GreedyWarArmy`, `FIX_GREEDY_WAR_ARMY`, `false` in the bundle; 63 of 64 flags), at war with a
  major civ:

  | | No credible threat | Credible threat |
  |---|---|---|
  | Land unit cap | the peace cap (1 per city) | the threat (at least the peace cap) |
  | Small-army cut on buildings | none, as in peace | until it has the threat's number of land units (not CP's 3 per city) |
  | CP's at-war cut on non-defensive buildings | none, as in peace | as for any civ at war |
  | City-state unit gifts | refused at the cap | refused at the cap |
  | Upgrades | none, as in peace | allowed |
  | Siege units | none | none |
  | Walls and castles | none | allowed in border cities and cities under siege (barracks stay off) |

  A city under siege gets a defender past the cap only if it has none.
- **Knobs:** the sketch's 8-plot radius, +1/3 damage and 1 melee unit for "close to capable"; then 2 per city, or 3/4
  of the units in sight within 5 plots.
- **Strict greedy is unchanged:** without `GreedyWarArmy`, a greedy civ at war keeps 2 per city and upgrades. That's
  the running easy-matchup test (`bullygreedy3`), which checks whether the conquest code can take cities at all.
  **The greedy style for the matchup test is the four greedy flags plus `GreedyWarArmy`.**
- **MetaDial changed to match** (not played yet): at war the greedy side (M ≤ -50) follows the same rules, with its
  peace ceiling as the floor; above it, no war cap.
- **Measures:** greedy civs at war with a far or weak civ keep `LandUnits` ≈ 1 per city and their growth; at war with a
  credible neighbour they reach the threat's number within ~10-20 turns, and stop there. Cities lost per war against
  strict greedy (`bullygreedy3`) and balanced civs.
- **Run, once the bully takes cities from strict greedy civs:** the same bully run with `-OthersBase "GreedyFewUnits,
  GreedyNoWalls, GreedyNoUpgrades, GreedyBuilds, GreedyWarArmy"`.
- **Build:** fork `ai/personality` `c1518c4` (on `674c1bd`, `ddf3311`, `cbb291c`, `9017ee3`, `d379bfe`; off `claude/ab-c1` `d51e8a6`).
- **Status:** compiles (CI run 138 on `5220c03` passed, 9:05am ET); merged into `claude/ab-c1` `5220c03`. Waits for the
  matchup test.
- **For the lead:** 63 of 64 flags. Retiring flags that failed or were replaced (`LongWide`; `GreedyArmyCap`, replaced by
  `GreedyFewUnits`) will be needed soon.

## Requests

**Blocked (lead, 2026-11-03 00:25 UTC): GitHub Actions is disabled on `treezeegaga/Community-Patch-DLL`.** At
00:16:55 every running build was cancelled mid-compile (runs 70, 71, 73, 74), and a new run is refused with
"Actions has been disabled for this repository". The owner turns it back on under the fork's Settings → Actions →
General. Run 75 (`27437f0`, 64-bit masks) finished first and published `ab-27437f0`. Waiting until Actions is
back:
- run 76 (`cca50d8`, Diplomacy's proposal counts), re-queued;
- `claude/ab-screen2` (`6fa752e`), which is `cca50d8` + Economy + Diplomacy (0001–0007) + War, rebased onto the
  flag table: 39 flags, results in `AIABTest_screen2.csv`;
- `ai/economy` (`d950f88`), `ai/diplomacy` (`5788c4e`) and `ai/war` (`445009c`), each rebased onto `cca50d8`.
The PC runner isn't affected: the baseline uses the published `ab-6b8ebde`.

**Difficulty (PC runner, 2026-11-03):** editing `LastDifficulty` in `config.ini` does nothing (Civ rewrites it).
The runner picked King once on the setup screen; Civ now remembers it. `Run-Games.ps1`'s turn-10 check caught the
Prince game (`029BA19B`, a few turn-10 rows in `AIABTest_c7c_roles.csv`; the summary ignores games under turn 100).
Next test build: the DLL forces the difficulty from `AIABTest.ini`, so this can't happen silently.

- **For Diplomacy** (from lead job 7): `HumanStrengthPerceptionMod` (`CvDiplomacyAI.cpp` ~11606) inflates
  human military strength by 20% at Prince, 50% at Deity, and only for humans. Decide whether the new AI
  should keep a human-only rule here (goal 2 says threats are judged by behaviour).
- **For War** (not urgent): `GetNewAIConquestTarget` keeps the committed target in a `static` array
  (`s_aiCommittedTarget`), which isn't saved, so a reloaded game re-picks. Not a multiplayer desync
  (every computer runs the same turns), but it should be game state before anything ships.
- **Answer to the request above (Diplomacy):** at King the even rules set `HumanStrengthPerceptionMod` to 0, so
  the 25% is gone. One human-only rule is left in the same function: a human's army is never rated below 100% while
  it's above the starting rating, whereas an AI's below-average army is rated down to 50% (`CvDiplomacyAI.cpp:11602`).
  It's small and only makes AIs more careful of humans; the new AI drops it with `FIX_COALITION_STRENGTH`, which
  rewrites how threats are judged. Also: `HUMAN_USES_AI_MECHANICS = 1` only covers `isHuman(ISHUMAN_MECHANICS)`; the 32
  `ISHUMAN_HANDICAP` checks in diplomacy follow `HUMAN_USES_AI_HANDICAP` (still 0). They read the human's own King
  row, which equals the game's, so no other difference remains (AUDIT.md, "Human-only rules").
- **For the lead (from Diplomacy):** scripted exploit checks, in this order: (1) a human surrenders with GPT in a
  peace deal, waits out the peace lock and re-declares: how many payments did the AI get? (2) a human friend asks
  for help repeatedly in one turn (D13); (3) a demand backed only by units parked at the border, from a civ that
  couldn't take a city. A save per check plus a Lua or FireTuner script is enough.
- **For the lead (from Diplomacy):** counts the coalition flags need in the results rows: coop (joint) war
  proposals made and accepted, and World Congress sanction proposals, per civ, with the target. I can write the DLL
  side if you prefer (they are raised in `CvDiplomacyAI` and `CvLeagueAI`), but the CSV writer is yours.
- **For the lead (from Diplomacy):** no push access to the DLL here either. DLL changes will come as format-patch
  files in `tools/ab/patches/diplomacy/` on pack branch `claude/ai-diplomacy`, based on `claude/ab-c1` `6b8ebde`.
- **Lead's answer to Diplomacy (2026-11-02):**
  - **Proposal counts:** yes, please write the DLL side. Add entries at the end of `ABTestCountTypes` (CvPlayer.h),
    columns at the end of the results row in `CvGame::LogABTestResults`, and bump `AI_AB_TEST_BATCH`. Count
    proposals made and accepted, plus a "vs aggressor" variant when the target's `GetABTestRole()` is
    `AB_ROLE_AGGRESSOR`. Send it as its own patch, separate from AI changes. The lead reviews it and merges it
    into `claude/ab-c1` directly, since it only measures.
  - **Exploit checks:** queued after the King baseline. Each needs a save made on the PC and a script, so first
    write each check as an exact scenario: the starting position (what the save must contain), the human
    actions turn by turn, and the pass/fail measure. The PC runner can then make the saves.
- **For War (from Diplomacy):** a coalition only matters if its members can take cities, so coalition flags are
  judged on the bully test after War's first capture fixes. Also from the audit: D1 (easy targets never computed
  for civs at peace) changes how often AIs start wars, so it may interact with `FIX_CAN_WIN` and the timing flags.

- **For the lead, from Economy (expansion pace, step 1 of Economy's first tasks):**
  - **2-3 logged King games.** The cheapest way: the first pair of the King baseline with
    `LoggingEnabled = 1`, copying `Logs\` aside after each game, plus `Digest-ABLogs.ps1 -UpToTurn 80`
    for each into `tools/ab/results/`.
  - **A per-settler timeline in `Digest-ABLogs.ps1`**, so the turns can be split into waiting, training,
    walking and escort: for each settler, the city and turn it was started (book or not), the city's size
    then, the turn it was finished or bought (`EXPANSION SETTLER - Bought`), its found-city operation's
    start, and the founding or abort. Also what the capital built while a book settler step was held, and
    turns with `EXPANSION SETTLER - Saving`.
  - **Queue `SettlersFirst` and `SettlerOverlap`** (and later `DiploPolicyValue`, patch 0002) after the baseline (T100 paired SPRTs, or one screening
    run of both), once the commit is on `ai/economy` and `ab-ai-economy-latest` is built.
  - **Lead's answer (2026-11-02):**
    - **Logged games:** the King baseline's first pair runs with logging on and `Run-Games.ps1 -SaveLogs`,
      which saves each game's digest to `results/digest_<GameId>.txt`.
    - **Timeline:** `Digest-ABLogs.ps1` now prints a per-civ settler timeline: book or AI settler starts with
      their city, settlers bought, found-city operations started, founded or ended, and the turns spent
      saving gold. A city's size when a settler starts isn't in the logs, so it's left out.
    - **The two flags** are queued right after the baseline, once the patch is relayed to `ai/economy`
      (see the patch relay in AGENTS.md) and `ab-ai-economy-latest` is built.

- **For Diplomacy, from Economy's victory-push audit:** L2 in `GetScienceVictoryProgress` (counts every
  project, Apollo twice; count only space-race projects, capped at their thresholds) and L3 in
  `GetDominationVictoryProgress` (half the world's military counts as "close to world conquest", which
  flips the civ's pursuit to domination). See "Late-game victory push audit".
- **For the lead, from Economy:** the victory push is almost never active in T150 Quick games (L1 in the
  victory-push audit), so goal 6 needs a long-game test (Standard pace, or saves from the Industrial era on)
  before any victory-push fix can be judged.
- **For the lead, from War: the DLL commit.** Done: the three War flags are on `ai/war` as `4917284` (on
  `claude/ab-c1` at `6b8ebde`; the patch is also in `patches/war/`). The War session now has push access and pushes
  `ai/war` itself. CI run 41549033176 compiled `4917284` cleanly (MSVC and clang, debug and release), then was
  cancelled at "Analyze build warnings" (the known hang), so no release came out of it. `0bc96d3`'s run was cancelled
  before it started (Actions was off). `ai/war` is now `445009c` (the lead's rebase onto `cca50d8`, 64-bit flag table),
  pushed 2026-11-03. **CI run 78 passed** (all five War flags compile), and so did the screening build `claude/ab-screen2`
  (run 77, release `ab-b756936`). Screening run 2 has SiegeStay, SiegePosture, DeclareAtBorder and UpgradeSaveCancel.
  `ai/war` is one commit behind `claude/ab-c1` (`fdad60d`, which only adds a Difficulty key); it gets rebased at the next push. Please add `SiegeStay`,
  `SiegePosture`, `DeclareAtBorder` to `AIABTest.ini.example`.
- **For the lead / PC runner, from War: 3 logged King games before any SPRT on the War flags.** Same setup as the
  baseline, bundle on (so warmongers attack), logging on, `Fixes` = bundle + `SiegeStay,SiegePosture,DeclareAtBorder`
  for one game and the bundle alone for two, so both sides of each flag show up. Copy `OperationalAILog.csv`,
  `MilitaryAILog.csv`, `DiplomacyAI_Messages_Log.csv` (or whichever file has the war declarations) and the
  `*TacticalAILog*.csv` files of the warmongers to `results/logs_<game>/`, plus the digest. War reads from them:
  - **how each war was declared:** "Discovered by enemy" versus "Transition to finished stage" just before it, or no
    operation at all (coop war, demand, city-state statement);
  - **military ops ended** per civ: is `HalfStrength` (audit item 26) a real share? Under ~20% of military operation
    ends, no ablation is needed;
  - **which operation type** ends with `NoTarget` on almost every turn (c7c game 2: Austria T130–T151 and four others);
  - **heal moves next to a besieged city** and "attempting capture ... expected max damage per turn" over a siege.
- **For the lead, from War: battle tests from saves.** War fixes act within a 10–20 turn siege, so a test that loads
  the same mid-war save and plays 15 turns would give an answer in minutes. Wanted: (1) 3–5 saves, each with an AI
  army 3–6 tiles from an enemy city at the turn war is declared (the c7c logged games have them: China vs the Iroquois
  T81, the Ottomans vs Siam T64); (2) a runner mode that loads a save with given `Fixes`, plays N turns and writes the
  besieged city's owner and HP and each side's units lost per turn. Measure: captures out of runs, turns to capture.
  Does Civ V reseed the combat rolls on load? If not, runs with the same flags will repeat exactly and only the flags
  vary, which is what we want.
- **Lead's answers to War (2026-11-02):**
  - **Pushed:** patch 0001 applied cleanly to `ai/war` = `4917284` (on `6b8ebde`). Its push build publishes
    `ab-ai-war-latest`. Before pushing, the lead checked that the identifiers it uses exist with the right
    const-ness (`isProjectedToDieNextTurn`, `m_AllTargets`, `eAggressionLevel`, `getNeighborsUnchecked`). CI is
    the first compile. `AIABTest.ini.example` now lists the War flags. Put later patches in
    `tools/ab/patches/war/` (numbered 0002, ...).
  - **Logged games:** queued as the PC runner's step 3, right after the baseline's logged pair. That's 2 games
    with the bundle and 1 with the bundle plus your three flags, on `ab-ai-war-latest`, with the log files you
    listed committed to `results/logs_<GameId>/`.
  - **Battle tests:** yes, and determinism is on our side. CP's rolls hash the map seed with the turn, unit IDs
    and plots (`CvGame::randCore`, `CvUnitCombat`), so the same save with the same flags plays out the same way.
    Each save then gives one run per flag configuration, and variety comes from many saves, not repeats.
    - The PC runner keeps the autosaves of the logged War games as the first saves.
    - The runner mode (load a save with given `Fixes`, play N turns, log the besieged city and losses) needs
      the Load Game screen's click positions, which only the PC runner can calibrate. The lead writes it after
      the baseline, with the PC runner. Until then, SPRTs on paired games are the test.
  - **Your two declaration issues** (the `static` committed target; coop wars, demands and city-state statements
    not waiting for an army) are passed to Diplomacy.
- **For Diplomacy (or the lead), from War:** two war-declaration issues in `CvDiplomacyAI`, which War doesn't own:
  1. The committed conquest target (`s_aiCommittedTarget` in `GetNewAIConquestTarget`) is a `static`, not game
     state. That's the request above "For War", but the file is Diplomacy's.
  2. Declarations through coop wars (`CvDiplomacyAI.cpp` ~9625), demands (~34524) and city-state statements (~28209)
     don't wait for an army in place. If the logged games show wars starting that way with no army near, those paths
     should also go through the sneak-attack operation (`RequestCityAttack` then `IsArmyInPlaceForAttack`).
- **For Economy, from War (logged games 02DEF5BF, 02EA597F, 02F5C9E3):** `OP_FOUND_CITY` ends `NoTarget` about 400 times
  per game: an operation is created and dropped every turn (Spain in 02F5C9E3, T19–T23: a new ID each turn, "Duration"
  20, 21, 22...). Probably a settler whose target fails the check in `CvAIOperationCivilianFoundCity` right after it's
  chosen. It may be costing settler turns, so it's worth a look for expansion pace.
- **For the lead, from War (the user agreed, Nov 4 ~7:35am ET): one `ConquestPlan` switch.** `TimingAttack`,
  `DeclareTiming`, `SiegeBook` and `SiegeTechs` are four parts of one plan (c4's siege timing attack): pick a target,
  research siege, build the siege army, declare when it exists. None makes sense alone, so single-flag tests of them
  mean little. Proposal: a `ConquestPlan` flag that turns all four on, for warmonger roles and personalities. The
  general war fixes stay separate flags, since they help any civ at war: SiegeArmy, SiegeAbort, SiegeFormation and
  ArmyHandoff. War can write it if you prefer (CvPlayer's flag table is yours).
- **For War (from War, noted): target choice.** c picking c in the test is an artefact of the split, not a bug, and
  `CanWin` already checks that a target can be beaten. Nothing to code until the bully test shows the aggressor
  picking hopeless targets.

- **Lead (2026-11-02):**
  - Economy's patches 0003–0006 are on `ai/economy` = `ccbb01a`. E1 and the note below are forwarded to War.
  - `IdeologyPick` and `EspionagePolicyValue` act on ideologies and spies, which rarely exist by T150 on
    Quick, so they wait for the phase-2 long-game setup.
  - `PolicyPrereqDepth` acts all game, so it goes into the next screening run; so does `GreedyAlarm`, once War
    has capture fixes.
  - War has push access now and pushes `ai/war` itself.
- **For War, from Economy:** `GreedyAlarm` (patch 0003) reads CP's visible-unit aggressive posture as its
  threat signal. If War builds a better "neighbour is massing an army" signal, tell Economy and the alarm
  will use it. Also E1 (losing wars don't cut building production; a dead loop in
  `CvBuildingProductionAI`): Economy can code it as a flag whenever War wants it tested alongside its fixes.



## Instructions for PC runner 2 (the second PC, from 2026-11-03)

The second PC plays **screening run 2** while the first PC plays the King baseline: different builds and different
results files, so the two never mix. Its log is its own (`machines\<COMPUTERNAME>.json`, below), so pushes from
the two PCs don't touch the same files. Always `git pull --rebase` before pushing.

**One-time setup** (the user does steps 1–2; the runner does the rest):
1. **Steam:** one Steam account can run a game on only one PC at a time, so PC 2 uses the user's **second Steam
   account** (they have two). It must own Civ V with Gods & Kings and Brave New World; check both expansions show
   as installed under Civ V's DLC in Steam. Install Civ V and start it once so `My Games\Sid Meier's
   Civilization 5` exists. (Without a second account: log PC 2 in once with "remember me" and switch it to
   Offline Mode before every run.) Community Patch comes from the first PC (step 2), not the Workshop, so both
   PCs have the same version.
2. **Copy from the first PC** through a shared network folder, so both PCs build exactly the same pack: Community
   Patch's mod folder and the repo's `CPModpack\data\` (the database snapshot; git ignores it).
   `tools\ab\Copy-RunnerFiles.ps1` does both ends and checks the copy (file count, size, the DLL's hash):
   - the computers are **PC 1 = `BOX`**, **PC 2 = `TREEDESKTOP`**. The shared folder `\\TREEDESKTOP\civrunner` is on
     PC 2 (`C:\civrunner`), and BOX has no access to it ("Access is denied"), so on 2026-11-03 PC 1 exported to
     `Documents\civrunner-export\` and the user carried the zip over. PC 2's copy matched (DLL `262AEE88C531`);
   - **PC runner 1:** `powershell -ExecutionPolicy Bypass -File tools\ab\Copy-RunnerFiles.ps1 -Export \\TREEDESKTOP\civrunner`
     (safe while a game runs);
   - **PC runner 2**, after the clone (step 3) and starting Civ once:
     `powershell -ExecutionPolicy Bypass -File tools\ab\Copy-RunnerFiles.ps1 -Import \\TREEDESKTOP\civrunner\civ-runner-files.zip`
     (Windows asks for PC 1's sign-in the first time). It ends "same as the first PC".
3. Clone `treezeegaga/Civ5-CP-AnimatedLeaders`, branch `claude/sleepy-hopper-x77moh`, with push access (sign in to
   GitHub in Git Credential Manager on the first push).
4. **Windowed Civ:** in `My Games\...\GraphicsSettingsDX9.ini`, `FullScreen = 0`. On a 3840x2160 screen at 150%
   scaling (the first PC's), `WindowResX = 1914`, `WindowResY = 2034`; on another screen, the largest window that
   fits, and calibrate (step 6). In `config.ini`: `LoggingEnabled = 0`. Set the setup screens once: Pangaea,
   Standard, Quick, King, 8 civs on separate teams (the screening build also forces King itself).
5. **The machine file** `tools\ab\machines\<COMPUTERNAME>.json` (`$env:COMPUTERNAME`), committed:
   `{"Log": "Run-Games-<COMPUTERNAME>.log"}`, plus step 6's values on a different screen. With it, the saved
   screens go to `machines\<COMPUTERNAME>.screens.json`.
6. **Calibrate.** Install the build (next list, step 1), start Civ by hand and, on each screen, dot-source
   `tools\ab\CivScreens.ps1` and save it: `Save-CivScreen menu`, `single`, `setup`, `advanced`, and
   `Save-CivBeginButton` on "Begin Your Journey". On the same 4K screen at 150% that's all. On another screen, first
   measure from screenshots, in physical pixels, and put in the machine file:
   - `Positions`: `Continue`, `SinglePlayer`, `SetUpGame`, `AdvancedSetup`, `QuickCombat`, `QuickMovement`,
     `StartGame`, `BeginJourney`, `Neutral` (an empty band at the top of Civ's window), each `[x, y]`, where Civ
     first opens its window;
   - `CivArea` `{X, Y, W, H}` (Civ's window below the title bar), `MenuPanel` and `BeginButton` `[x1, y1, x2, y2]`
     (the main menu's button panel; the "Begin Your Journey" button's text).
   Check with `Get-CivScreen` that each screen comes back with its own name at a distance under 2.5.
7. One game to check: `Run-Games.ps1 -Fixes none -MaxGames 2 -Screen "WidePlans, BoxedIn, BoxedInWar, TimingAttack, SiegeTechs, SiegeBook, DeclareTiming, GrowthTech, AqueductValue, GreedyBook, GreedyTarget, CanWin, ClosedBorders, SettlersFirst, SettlerOverlap, DiploPolicyValue, PolicyPrereqDepth, LosingWarBuildings, CultureRivalValue, SettlersBeforeWonders, BookFinishesSettlers, SiegeStay, SiegePosture, DeclareAtBorder, UpgradeSaveCancel, EasyTarget, DiploBugs, LuxuryAsk, DealExploits, DealReputation"` (the first pair of the run below).
   Its log should show "replay matches the first game" and no "WRONG SETUP".

**Then screening run 2**, as in "After the baseline: screening run 2" below, but on PC 2 and starting now:
1. `powershell -ExecutionPolicy Bypass -File tools\ab\Run-ABTest.ps1 -Release ab-819be70 -NoLaunch -NoUpdate`
   (the title must name `819be70`, the crash fix; if the release doesn't exist yet, CI is still building it: wait).
2. `powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Fixes none -MaxGames 20 -Screen "WidePlans, BoxedIn, BoxedInWar, TimingAttack, SiegeTechs, SiegeBook, DeclareTiming, GrowthTech, AqueductValue, GreedyBook, GreedyTarget, CanWin, ClosedBorders, SettlersFirst, SettlerOverlap, DiploPolicyValue, PolicyPrereqDepth, LosingWarBuildings, CultureRivalValue, SettlersBeforeWonders, BookFinishesSettlers, SiegeStay, SiegePosture, DeclareAtBorder, UpgradeSaveCancel, EasyTarget, DiploBugs, LuxuryAsk, DealExploits, DealReputation"`
3. Every 5 pairs or so: copy `AIABTest_screen2.csv` to `tools\ab\results\AIABTest_screen2@<COMPUTERNAME>.csv`
   (PC 1 keeps the plain name; the summary reads both files as one run), commit it with your log,
   `git pull --rebase`, push.

PC 1 plays the other 10 pairs of the same run (its queue, below).

- **For the lead and Diplomacy, from Economy (screening run 2 crash, `0303DC43`, assert in `CvDiplomacyAI.cpp` line 3029):**
  that's `IsEndgameAggressiveTo`'s `ePlayer < MAX_MAJOR_CIVS` check. No Economy code calls it. A likely caller is
  `DoUpdateEasyTargets`: it loops `ePlayer` over `MAX_CIV_PLAYERS` (city-states included) and ends with
  `bWantsConquest |= IsEndgameAggressiveTo(ePlayer)` (screen2 line ~12232). The crashed game's Zulu ran `EasyTarget`
  (D1/D2), which lets more city-states through to that line. Not verified in a game; a guard
  `GET_PLAYER(ePlayer).isMajorCiv() &&` before the call would settle it.

## Instructions for the PC runner

**Pinned build (lead, 2026-11-03 00:20 UTC):** the smoke-test pair and the whole King baseline run on
**`ab-6b8ebde`** (build `c7c_roles`, results in `AIABTest_c7c_roles.csv`), the build the PC runner installed at
00:09. `ab-c-latest` is about to move to `cca50d8` (64-bit flag masks plus proposal counts, file
`AIABTest_c7c_proposals.csv`); don't reinstall `ab-c-latest` until the baseline is finished, or its games
split across two files. Wherever a step below reinstalls the baseline build, use `-Release ab-6b8ebde`.

**Pull before the next `Run-Games.ps1` start (lead, 2026-11-03 00:55 UTC):** a failed start used to count as a good
one (`Write-Log` wrote to the output stream, so "log, then return `$false`" came back true). That's why game 2 of
the smoke pair sat on "Begin Your Journey" until the user clicked it. Fixed, and when the button isn't recognised the
runner now clicks it anyway; if the game still doesn't start, it sets the game up again.

**Logs for the sessions (lead, 2026-11-03 01:30 UTC):** from `-SaveLogs` games on, after pulling, the runner copies
each game's operation, military, diplomacy, tactical, book, production and homeland logs into
`tools\ab\results\logs_<GameId>\` (files over 20 MB left out and named in the log). Commit that folder with the
CSV. **One-off for Economy now:** from `My Games\LogsArchive\02A37B0302A37B03F\`, copy `OperationalAILog.csv`,
`CitySpecializationLog.csv`, `CityStrategyAIProductionLog.csv` and `PlayerHomelandAILog.csv` into
`tools\ab\results\logs_02A37B0302A37B03F\` (and the same for `02A37B0302A37B03`), commit and push. Economy needs the
Songhai settler operation's "no path" and "found target" lines.

**Baseline step 2 is cancelled (lead, 2026-11-03 01:35 UTC).** The PC runner found that with `-Fixes none` the
flipped game is the same game: all 120 result rows of pair `02C5BBF9` are identical, only `Group` swaps (49.0% then
51.0%). Civ's replay is fully deterministic, so an A/A pair always averages exactly 50% and 19 more of them measure
no noise. That's good news for every real test: within a pair, everything that differs comes from the flags
tested and what they set off. The SPRT measures its own spread from its pairs as it goes, so no baseline is needed
first. B's seconds per turn come from the logged pair (logging costs about 15%).

### City-state conquest and conquest bonuses merged; three more flags retired; both PCs to the 14-flag role (lead, 2026-11-04 10:25am ET)

- **War found** that CP's own weights almost never choose war on a city-state: a test bully picked it once in 959
  city-state updates, and the conquest target search looks only at major civs. New flags on `ai/war`: `CSConquest` (a
  warmonger in the conquest role goes to war on a weak, nearby city-state with no ally, or only an enemy as ally, and
  no strong protector) and `ConquestTraitTargets` (its civ's conquest bonus shapes its targets). Personality's
  `277602f` puts conquest-bonus civs among the Conquerors, and the civs that take city-states without war among the
  Diplomats.
- **Retired** (`2db51dd`): `ClosedBorders` (dropped), `GrowthTech` (-0.47) and `AqueductValue` (+0.09), all c7c ideas
  with no gain. 62 flags. **The 64-flag mask is tight;** a wider mask is lead work to do soon.
- **Both PCs**, from their next pair once `ab-2db51dd` is out, logging on, `-SaveLogs` (logs kept only for capture games
  and their partners). The role is the 12 flags + `CSConquest` + `ConquestTraitTargets`:
  - PC 2 against greedy civs: `AIABTest_bullygreedy6@TREEDESKTOP.csv`.
  - PC 1 against normal civs: `AIABTest_bullyabort4@BOX.csv`.
- **Before the switch:** `bullyabort3` (PC 1, 12-flag role, `5220c03`), 2 pairs, 0 captures.

### Use each civ's conquest bonus (the user; lead, 2026-11-04 10:10am ET)

Some civs are rewarded for taking cities (base rules; CP's database to be checked): Assyria (a free tech the owner knew
per city captured), Songhai (triple gold from captures and pillaged camps), the Huns (raze twice as fast), Mongolia
(+30% against city-states). Austria and Venice take city-states without war.
- **War:** flag `ConquestTraitTargets`. With the conquest flags on, a warmonger's target value adds its trait's
  reward: Assyria favours neighbours with techs it lacks, Songhai rich cities, Mongolia city-states first. Austria
  and Venice exclude city-states.
- **Personality:** the conquest-bonus civs on the aggressive side of the profile, Austria and Venice on the
  city-state side, read from the trait fields rather than a civ list.

### Does conquest pay? And city-states (lead, 2026-11-04 10:05am ET)

- **The user:** a bully grows by absorbing other civs' cities, so if it conquers nothing it won't grow. So the
  conquest role's verdict is whether the aggressor ends **bigger**, not only whether it captures. Across the 14 valid
  bully pairs so far, the aggressor's T150 share of the game, with the role against without (an even share is 12.5%):
  cities 12.7 / 12.2, population 12.3 / 11.1, techs 11.7 / 11.7, land 12.3 / 12.0, military 13.6 / 15.7. **Strength
  12.5% both ways: a wash.** With the role the army is spent in wars, and almost nothing comes back (2 captures, both in
  the Huns' game). From now on every bully result reports this alongside captures.
- **The user: a true bully conquers city-states too.** `CitiesCaptured` counts only cities taken from major civs. New
  column `CityStatesCaptured` (`claude/ab-c1` `d2390a1`, results file `c8e`, measurement only). War is asked whether the
  conquest role ever targets city-states, and to propose a flag if it doesn't.

### Replaying the capture game with logging on; every game's replay keys now kept (lead, 2026-11-04 9:15am ET)

- **The user asked for a logged replay of `0A92244F0A92244F`.** The replay keys weren't kept, but the game ID is the
  two seeds in hex (map seed `0A92244F`, sync seed `0A92244F` = 177349711). PC 1 writes `AIABTest.ini` by hand with the
  seeds, the 8 civs and their leaders, and the same role, on `ab-dbdfbb3`, logging on (`-NoSettings -Unpaired
  -MaxGames 1 -SaveLogs`). The city-states weren't recorded, so the T10 rows are checked against the original's
  before it goes on. Results `AIABTest_bullyreplay@BOX.csv` + logs.
  **Outcome (9:33am ET): not faithful.** T10 already differed (Venice score 35 against 34), because the replay picked
  other city-states, and the runner cut it at T110. The Huns were at war with Spain by T100 there too (military 84
  against 44), but there were no captures by T110. Its logs show only the start of that war. **From now on PC 1's bully
  run keeps logging on** (`-SaveLogs`, about 15% slower) and commits the logs of games with a capture and their
  partner game only.
- **`Run-Games.ps1`:** after every game, `AIABTest_lastgame.ini` (seeds, civs, leaders, city-states) is copied to
  `results\replay\<GameId>.ini`. Commit that folder with the results, and any game can be replayed exactly.

### FIRST CAPTURES: the Huns take 2 cities from Spain with the conquest role (lead, 2026-11-04 9:05am ET)

`AIABTest_bullyabort2@BOX.csv` (PC 1, `ab-dbdfbb3`, normal opponents; the role = 8 conquest flags + `SiegeStay` +
`SiegePosture`), 2 pairs:
- **Pair `0A92244F`, the Huns as aggressor.** With the role: at war from about T105 with Spain, the weakest neighbour
  (military 141 against 69). **2 cities captured** (Spain 5 cities to 4, Huns 5 to 6 by T130), military 227 at T150,
  and 4 civs at war with the Huns by T140 (a coalition). Without the role (the flip): at war all game, 0 captures,
  4 cities, military 140.
- **Pair `0A8035D5`, the Huns again:** 0 captures either way.

It's the first city an aggressor running our conquest code has ever taken (11 earlier captures in about 60 games
were all B's or CP's). And it fits the user's matchup framing: the victim was the weakest-defended neighbour, at
half the attacker's military. Both PCs move on to the 12-flag role (+ `SiegeFirst`, `SiegeFinish`, `ab-5220c03`).

### SiegeFirst and SiegeFinish merged; three flags retired; both PCs to the 12-flag role (lead, 2026-11-04 8:50am ET)

- **Retired** (`claude/ab-c1` `578d23a`): `LongWide` and `GreedyArmyCap` (both failed; `GreedyFewUnits` replaces the
  latter) and `SiegeBar` (dropped, the user's decision). Their code is the off branch, CP's behaviour, so play is
  unchanged for every test that didn't name them. This made room in the 64-bit masks.
- **`5220c03`:** that + War's `SiegeFirst` (a waiting attack's spare siege slots take only catapults or trebuchets)
  and `SiegeFinish` (melee assault once a city is at a third of its HP or less), `8c47302` + Personality's
  `GreedyWarArmy` (`c1518c4`). 62 flags.
- **Runs**, from each PC's next pair once `ab-5220c03` is out, logging off: the bully's `RoleFixes` are the 12 conquest
  flags (the 10 + `SiegeFirst`, `SiegeFinish`):
  - PC 2 against strict greedy civs: `AIABTest_bullygreedy4@TREEDESKTOP.csv`.
  - PC 1 against normal civs: `AIABTest_bullyabort3@BOX.csv`.

  War asked for "the role + both against the role alone". That needs a key for "the aggressor runs it in both games",
  which doesn't exist yet. With 0 captures so far, the first question is whether any city falls; the key comes once
  one does.

### A dead aggressor at T10: pair 0B40B5B7 left out (lead, 2026-11-04 8:35am ET)

`AIABTest_bullygreedy2@TREEDESKTOP.csv`, the only pair on `ab-dbdfbb3` before PC 2 moved to `d51e8a6`: Songhai, the
aggressor, has `Alive` 0, 0 cities and 0 military from T10 in **both** games. The flipped game runs no role flags, so
it comes from the map or start, not the conquest flags. It's the first such case in any results file (all files
checked for a civ dead by T30). Left out of the bully reading. If it happens again, PC 2 keeps the autosaves.

### Greedy unit cap fixed; PC 2 moves to it (lead, 2026-11-04 8:15am ET)

Personality's `d51e8a6` (see "greedy pair 0B09BFE1, where the extra units came from"): greedy civs switch off
city-state unit gifts while at their cap, and a besieged city gets a defender past the cap only with no garrison.
Same flags. CI passed (release `ab-d51e8a6`); `claude/ab-c1` fast-forwarded to it. It only acts for greedy civs, so PC 1
(normal opponents) stays on `ab-dbdfbb3`. PC 2 moves to `ab-d51e8a6` after its first pair on `dbdfbb3`, results
`AIABTest_bullygreedy3@TREEDESKTOP.csv`, same command. `Run-Games.ps1 -SaveLogs` now also saves `StrategyProfile_Log.csv`
(Personality's request).

### War: the Mongols' siege walked home to heal; SiegeStay and SiegePosture join the bully runs (lead, 2026-11-04 7:45am ET)

**War, pair `0B09BFE1`:** the Mongols' siege of Tiwanaku reached 117 expected damage a turn and brought it to
128/200 HP (T107–T112). Then the units the tactical AI didn't use that turn fell through to the homeland AI's heal
moves, walked home with no deaths, and the city recovered. `SiegeStay` only filtered the tactical heals. War's
`3247ef4` makes the homeland heals skip units the siege needs too.

**`claude/ab-c1` `dbdfbb3`:** `af99bc1` + War `3247ef4` + Diplomacy `WarAppetite` (`916925b`, CI passed). 62 flags.
**Both PCs switch at their next pair boundary**, logging off, `RoleFixes` = the 8 conquest flags + `SiegeStay` +
`SiegePosture`:
- PC 2: against greedy civs (`OthersBase` = the 4 greedy flags), `AIABTest_bullygreedy2@TREEDESKTOP.csv`.
- PC 1: against normal civs, `AIABTest_bullyabort2@BOX.csv`.
`StaleWarPeace` and `WarAppetite` stay out of these runs, so they change only the attack side.

### Bully vs greedy civs, logged pair: still no captures; the greedy cap leaks (lead, 2026-11-04 8:00am ET)

Pair `0B09BFE1` (`ab-c78384b`, PC 2, `AIABTest_bullygreedy@TREEDESKTOP.csv`, logs `logs_0B09BFE1*`). The aggressor is the
Mongols, running the 8 conquest flags in the first game only. The others are greedy (`OthersBase`), and Babylon is the
tall civ. Replay matched.
- **Aggressor:** biggest army at T100 (military 107, next 79). It declared 1 war between T100 and T150 and was at
  peace at T150, military 190. **0 captures** in both games. Babylon (tall, not greedy) took 1 city from Poland in the
  first game.
- **Greedy civs:** walls work (0 walled cities except one city in each of two civs). **The unit cap leaks:** at T150,
  `LandUnits`/`Cities` were 13/5, 12/5, 10/4 and 9/4, and military reached 229 (Songhai) and 154 (Aztecs). So
  they weren't the easy matchup yet.
- **A free target nobody took:** Japan at T150 had military 5, was at war with 2 civs, and kept its 3 cities.
- **Asked:** War, the Mongols' war and what SiegeAbort did, and why no one took Japan. Personality, where the
  extra greedy units come from.
- The 20-game run goes on (logging off).

### Overnight: PCs idle 12am–7am, now running; StaleWarPeace merged (lead, 2026-11-04 7:15am ET)

- **Lost night:** `c13eb1c` and `1fc6d0a` failed to compile (VC9 C4701 in the strategy profile). I fixed it in
  `c78384b` (1:05am, released 1:16am), but my session restarted before I told the PCs, and PC 2's 2:45am question
  waited until 7am. Both PCs were idle from about midnight to 7am ET. **Lesson for the lead:** after a fix, message the
  PCs the release name in the same turn; and topic sessions check their own CI before reporting a commit ready.
- **Now (7:03am ET, `ab-c78384b`):** PC 2 plays the bully against greedy civs, the logged pair first
  (`AIABTest_bullygreedy@TREEDESKTOP.csv`). PC 1 plays the bully against normal civs, 20 games
  (`AIABTest_bullyabort@BOX.csv`). Both run `RoleFixes` through `SiegeFormation`.
- **`StaleWarPeace`** (Diplomacy, see its entry) is on `claude/ab-c1` `af99bc1`, off in the bundle; it compiles there for
  the first time. It goes into the bully runs after these two (it acts for every civ, so as `Base`).

### War's read of the conquest pair; both PCs move to the conquest package with SiegeAbort (lead, 2026-11-03 11:50pm ET)

**War, pair `0879B791` (Celts):** the sneak attack held only 7 units, about half the army. It waited the full 20
turns (T86–T105) at 27–29 damage a turn against the 60 needed, then marched anyway when the cap ran out and declared
on the Netherlands at T111. The Dutch were an equal (military 110 against 118) and out-built the Celts to 222. The
assaults on Rotterdam (T111–116) did 61 then 40 damage against 200 HP. The Celts lost 11 units over T117–149, mostly to
counterattacks and while retreating to heal, and no peace came.
- **Fix in:** `SiegeAbort` (an attack still too weak at the cap is called off instead of sent), in `c13eb1c`.
- **Open, War:** only half the army joins the attack, because the operation recruits only near the muster city.
- **Open, Diplomacy:** a failed war ran 40 turns with no peace.

**Runs on `ab-c78384b`** (`1fc6d0a` plus a one-line fix: `c13eb1c` and `1fc6d0a` failed to compile on VC9's C4701 in the strategy profile, so neither release exists; `1fc6d0a` is `c13eb1c` plus War's `SiegeFormation`: classical-medieval city attacks use the formation
with 5 siege/ranged slots, not 2, since catapults couldn't join past 2), **the conquest package + `SiegeAbort` +
`SiegeFormation` as `RoleFixes`, logging off unless noted:**
- PC 1: against normal CP civs, `AIABTest_bullyabort@BOX.csv` (after its current pair, which closes `AIABTest_bullyconquest@BOX.csv`).
- PC 2: against greedy civs (`OthersBase`), `AIABTest_bullygreedy@TREEDESKTOP.csv`, logged pair first.
The two runs differ only in the opponents.

### C8 decided: no worse, no gain; C8 is the new base. Everything merged; PC 2 plays bully vs greedy (lead, 2026-11-03 11:45pm ET)

- **C8 against B, 6 pairs** (`afc9f22`): c 50.36%, **+0.36 points; gainer FAILED** (LLR -4.71), **no-worse PASSED**
  (+8.19). C8 stays the integration bundle: every flag in it passed its own test, and together they cost nothing.
  The top five's +1.35 in 5 pairs was mostly luck. **Lesson:** at T150 the AI's economy is close to what these
  flags can move. The big lever left is war (cities changing hands), so attack and defence come first now.
- **`claude/ab-c1` `c13eb1c`:** merges `ai/diplomacy` (`TradeOpinion`), `ai/war` (`SiegeAbort`: an attack still too
  weak after SiegeArmy's 20 turns is called off) and `ai/personality` (the greedy, balanced and aggressive style
  flags, the strategy profile log, `MetaDial`). 59 flags, enum and table in the same order, all new ones off in the
  bundle. Results file `c8d` (with the defence columns).
- **PC 2 next:** the bully against greedy civs, the easy matchup, on `ab-c13eb1c`. The same conquest package as PC 1's
  run (no `SiegeAbort`, so the two runs differ only in the opponents), logged smoke pair first. Results
  `AIABTest_bullygreedy@TREEDESKTOP.csv`.
  ```
  powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Mode bully -Fixes none -OthersBase "GreedyFewUnits, GreedyNoWalls, GreedyNoUpgrades, GreedyBuilds" -RoleFixes "TimingAttack, DeclareTiming, SiegeBook, SiegeTechs, SiegeArmy, ArmyHandoff" -MaxGames 2 -SaveLogs
  ```

### Bully conquest, logged pair: the army is built, then lost for nothing (lead, 2026-11-03 11:40pm ET)

Pair `0879B791` (`ab-8109f67`, PC 1, `AIABTest_bullyconquest@BOX.csv`, logs `logs_0879B791*`), aggressor the Celts:
- **With the conquest flags:** at T100 the biggest army in the game (military 122, next 99). One war declared between
  T100 and T150. At T150: military 38, 4 cities, **0 captured**, 9.0% strength share.
- **Without them (flip):** military 131 at T150, 4 cities, 10.9%.

So the flags make the army, then waste it. War is asked to read the logs: target, army against defence, how the
units died. The 20-game run goes on meanwhile (logging off).

### C8 against B, first 5 pairs: no worse, gain small (lead, 2026-11-03 11:35pm ET)

`AIABTest_c8@TREEDESKTOP.csv`, `ab-8109f67`, PC 2, 5 pairs (10 games), no crash, replays matched: **c 50.60%, gain +0.60
points ± 0.6**; first games +0.02, flipped +1.19 (split bias, cancelled in pairs). **No-worse PASSED** (LLR +8.54);
gainer -2.49, running (fails at -2.94). Captures 0, wars 0.05 per civ per 10 turns. So C8 costs nothing, and its gain
looks smaller than the top five's +1.35 from 5 pairs (that was within luck of this). PC 2 goes on, pushing each pair,
until the gainer decides. Game `0930A57D0930A57DF` has 112 rows: one missing 10-turn snapshot, everyone alive at T150.

For the record, `SettlersBeforeWonders` alone (`AIABTest_sbw.csv`, 4 pairs, stopped by the user's ruling): c 51.56%,
+1.56 points, too few pairs for the SPRT to decide, in line with the ruling.

### Personality session started; OthersBase key for the matchups (lead, 2026-11-03 11:25pm ET)

- **Personality** (session `session_01G2NZj3nJG9wpbrgoAZMmUk`, branch `ai/personality`) starts now at the user's
  request. Every civ in the bully games keeps a real army (in pair `07614B74` the weakest, Portugal, had 103
  military against the aggressor Songhai's 191, and three civs outgunned it), so the aggressor only meets the hard
  matchup. First job: the greedy style as flags (few units, no walls or castles, no defensive upgrades).
- **`OthersBase` key** (`claude/ab-c1` `1804369`; `Run-Games.ps1 -OthersBase`): flags every AI civ without a role runs,
  in both games of a pair. It sets the opponents the roles meet, the same in both games, while `RoleFixes` still
  differ between the two games on the aggressor. The easy-matchup test, once the greedy flags exist:
  ```
  powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Mode bully -Fixes none -OthersBase "<greedy flags>" -RoleFixes "TimingAttack, DeclareTiming, SiegeBook, SiegeTechs, SiegeArmy, ArmyHandoff" -MaxGames 20
  ```

### The bully goals wait for an attacker that conquers; defence columns added (lead, 2026-11-03 11:10pm ET)

**The user's points:**
- The bully goals (aggressor ≤ 20% of all cities, ≤ 1 city per war, a coalition within 20 turns) pass trivially
  while no AI can take cities (about 11 captures in 60 games; our conquest code has never taken one from B). They
  wait until an attacker conquers.
- How much the attacker should take depends on the meta. Against greedy civs with few units, no walls and no
  defensive techs it should take several cities, maybe whole civs by T150; against balanced civs with medium armies
  and walls it should struggle. So the attack goal is a pair of matchups, not one number.

**Plan:**
1. **Teach the AI to conquer** (the bully conquest test, PC 1 now, judged on the attacker). Read each war as the
   victim's defence against the cities it lost: captures should come from the worst-defended neighbours.
2. **Defence against a real attacker:** once an attacker conquers, the best attack flags become the aggressor's fixed
   role (both games of a pair) and the other civs run the defence candidates. The 20% goal then means something.
3. **The matchup test** (Personality session, once greedy and balanced styles exist): the same aggressor against
   all-greedy opponents (should win big) and all-balanced ones (≤ 1 city per war, a coalition forms). Those runs set
   the attack goal's numbers.

**Defence columns (level 1, measurement only):** `claude/ab-c1` `ec2a4c8` adds `WalledCities` (cities with Walls),
`CityStrength` (the summed defensive strength of a civ's cities: CP's city strength, from buildings, population,
techs and garrison) and `LandUnits` (land combat units). Play is the same as `8109f67`, so games from both builds pool.
New results file name `c8d`, so the new header starts a fresh file. **Installed only after the running C8 and
conquest runs finish**, so no run switches builds midway.

### SettlersBeforeWonders ruled obviously right; PC 1 moves to the bully conquest test (lead, 2026-11-03 10:40pm ET)

The user ruled `SettlersBeforeWonders` obviously right: an earlier 2nd and 3rd city beat a capital wonder like
Stonehenge, so it needs no single-flag test. It stays in C8, and C8 against B (PC 2) still catches it if the code
does harm. PC 1 stops its SBW run (finished games are kept as `AIABTest_sbw.csv` for the record, not judged) and starts
the **bully conquest test** on the same build `ab-8109f67`: logged pair first, then 20 games, results
`AIABTest_bullyconquest@<COMPUTERNAME>.csv`. Command and verdict as in "Queue after tonight's two tests" below.

### C8 crash fixed: city-states run the bundle (lead, 2026-11-03 9:00pm ET)

The first C8 game (PC 2, `08B98ABC`) halted at T75 with "Error ... the game will now crash": `CvCultureClasses.cpp:3670`,
"Invalid player index". **Cause:** outside group membership, `UsesCandidateAI` gives every non-major civ the bundle's
flags (meant for the shipped pack). `CultureRivalValue` joined the bundle in C8, so city-states ran it, and for a
city-state's city its revived rival loop asked a major's influence on the city-state (`GetInfluenceOnTimes100` on a
minor). **Fix:** the flag acts for major civs only (`claude/ab-c1` `8109f67`, release `ab-8109f67`). `LosingWarBuildings`,
the same pattern, is safe for city-states. Both PCs restart their runs on `ab-8109f67`; games on `ab-0cd5a5c` that
finished cleanly still count.

**For the lead to decide:** city-states running every bundle flag in test games means each new bundle flag also
changes city-state behaviour, in both groups. That's fair to both sides but untested for crashes. Each flag joining
the bundle needs a check that its code is safe for a city-state.

### Queue after tonight's two tests (lead, 2026-11-03 8:35pm ET)

War and Diplomacy found why nobody fights: trade-made friendship crowds out war (Diplomacy), and the bully aggressor
ran none of the conquest code (War). Next:
1. **Bully conquest test** (next free PC; War's proposal): the aggressor plays the warmonger role. Build `ab-0cd5a5c`
   (C8; it has every flag), logged pair first:
   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Mode bully -Fixes none -RoleFixes "TimingAttack, DeclareTiming, SiegeBook, SiegeTechs, SiegeArmy, ArmyHandoff" -MaxGames 2 -SaveLogs
   ```
   then logging off, `-MaxGames 20`, results `AIABTest_c8.csv` copied as `AIABTest_bullyconquest@<COMPUTERNAME>.csv`
   (all rows of these bully games). Verdict: captures and the aggressor's city share, not strength share.
2. **TradeOpinion** (Diplomacy, `ai/diplomacy` `72ab43a`, building): trade-partner opinion from the deals running now,
   capped at -20. Level 3: no-worse on strength, plus more wars in split games and an aggressor that fights.

### Evening results: DeclareAtBorder does nothing alone; the bully aggressor barely fights (lead, 2026-11-03 8:15pm ET)

- **`DeclareAtBorder` alone** (`ab-819be70`, PC 2, `AIABTest_declare@TREEDESKTOP.csv`, 7 pairs; pair `080C740E` left out
  after a mountain-city dialog stall): c 50.04%, gain +0.04, **gainer failed**, no-worse passed. Pair spread 0.09: the two
  games of a pair are almost identical, so the flag almost never acts. Its screening rank (+0.86) was luck. It stays in
  C8 (harmless: no-worse passed) but contributes nothing.
- **Bully siege on the fixed SiegeArmy** (`ab-095144c`, PC 1, `AIABTest_bullysiege2.csv`, 6 pairs): **0 captures in all
  12 games**; the aggressor's share of cities with the package minus without +0.5 ± 0.4; aggressors (Songhai, Inca,
  Denmark, Japan) at war with 0-1 civs in most games. Stopped.
- **The blocker is war itself:** even the most aggressive personality starts few wars by T150 at King. War and
  Diplomacy are asked why (approach scoring, AFRAID, war-target filters, peace lengths). No war flag can show
  anything until civs fight.
- **Mountain-city dialog:** CP looks up `IMPROVEMENT_MOUNTAIN_CITY` (Vox Populi only) when a city is founded on a
  mountain; with CP alone that raised an assertion dialog that stalled an unattended game. Fixed for play-neutral
  builds from `claude/ab-c1` `0cd5a5c`.
- **Now:** PC 2 plays C8 (`ab-0cd5a5c`, `-Fixes bundle`) against B; PC 1 plays `SettlersBeforeWonders` alone on the same
  build (`AIABTest_sbw.csv`).

### C8: the new C bundle (lead, 2026-11-03 5:05pm ET)

`claude/ab-c1` is now `9f77273`: all three topic branches merged (`ai/economy` `63c7b7b`, `ai/diplomacy` `6e83115`, `ai/war`
`1c30fb0`; 48 flags, enum and table match, no doubled code), results file `AIABTest_c8.csv`. **The bundle is the 12 flags
that passed:** `DeclareAtBorder, SettlersBeforeWonders, PolicyPrereqDepth, LosingWarBuildings, DealExploits` (top five,
gainer passed), `DiploBugs, UpgradeSaveCancel, LuxuryAsk, DiploPolicyValue, EasyTarget, CultureRivalValue` (bug-fix
bundle, no-worse passed) and `NoForeignMissionaries` (the user's ruling). The 13 c7c ideas leave the bundle: they never
passed. Everything else stays off. `ab-c-latest` becomes C8 once CI passes.

Test: C8 (`-Fixes bundle`) against B, paired, gainer SPRT, on whichever PC is free. Expected about +1.5 points (the top
five's +1.35 plus whatever the extra fixes add). Topic branches now rebase onto `9f77273`.

### Bug-fix bundle: PASSED the no-worse test (lead, 2026-11-03 3:50pm ET)

The 8 screened level-2 fixes together in group c (`PolicyPrereqDepth, LosingWarBuildings, DiploBugs, UpgradeSaveCancel,
LuxuryAsk, DiploPolicyValue, EasyTarget, CultureRivalValue`) against B, `ab-819be70`, PC 2,
`AIABTest_bugfix8@TREEDESKTOP.csv`. **5 pairs: c 50.21%, gain +0.21 points; no-worse SPRT passed** (LLR +4.22), gainer
failed (-3.49), as expected for bug fixes. Replays matched, no crash. By the level-2 rule all 8 merge into the C bundle.
Next on PC 2: `DeclareAtBorder` alone (gainer SPRT), `AIABTest_declare@TREEDESKTOP.csv`.

### Queue for tonight (lead, 2026-11-03 1:45pm ET)

- **PC 2 (now):** the bug-fix bundle, a no-worse test of the 8 screened level-2 fixes, on `ab-819be70`, results
  `AIABTest_bugfix8@TREEDESKTOP.csv`. If it passes, all 8 merge.
- **PC 1 (once unlocked, about 7:50pm ET):** the bully siege test again, on the fixed SiegeArmy. Economy found the
  waiting armies never asked for their optional slots, so no city built for them; War's fix `1c30fb0` makes cities
  build them. Build `claude/ab-siege` `095144c` (release `ab-095144c`; results `AIABTest_bullysiege2.csv`). SiegeBar is
  dropped:
  ```
  powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Mode bully -Fixes none -RoleFixes "SiegeArmy, ArmyHandoff, SiegeStay, SiegePosture" -MaxGames 2 -SaveLogs
  ```
  then logging off, `-MaxGames 20`. Before starting: Windows set never to lock (Settings, Accounts, Sign-in options).
- **Then:** single-flag gainer tests of the top-five's level-3 ideas (`DeclareAtBorder`, `SettlersBeforeWonders`,
  `DealExploits`), and the new C bundle.

### The top five together: PASSED (lead, 2026-11-03 12:40pm ET)

`DeclareAtBorder, SettlersBeforeWonders, PolicyPrereqDepth, LosingWarBuildings, DealExploits` in group c against B, on
`ab-819be70`, PC 2, `AIABTest_top5@TREEDESKTOP.csv`. **5 pairs: c 51.35%, gain +1.35 points; gainer SPRT passed**
(LLR +3.13 at the +2.94 bound), no-worse passed (+18.9). Pair spread 1.05 (single games 3.82: each paired game is worth
6.6 unpaired ones). c won 8 of 10 games on strength. Replays matched, no crash.

Note: it passed at the earliest point the rules allow (5 results), just over the bound, and the measured gain is below
δ. So the five gain together, probably by +1 to +2 points rather than the +3.6 screening suggested (screening flatters
its top picks). Next: these five become the new C bundle (two are level 2, three level 3; NoForeignMissionaries joins
by the user's ruling), and single-flag tests show which carry it.

### The bully siege test: does a stronger aggressor take cities? (lead, 2026-11-03 11:00am ET)

Build `claude/ab-siege` `07805c8` (`ai/war` `5043f05` with SiegeBar, plus the `RoleFixes` key from `claude/ab-c1`), release
`ab-07805c8` once CI passes, results `AIABTest_bullysiege.csv`. In bully mode one civ is the aggressor (the most
aggressive personality). `RoleFixes =` gives it the siege flags in the first game of each pair only; the flipped
replay is the same game with the same aggressor, without them. Group c runs nothing (`-Fixes none`), so the aggressor's
flags are the only difference in a pair.
```
powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Mode bully -Fixes none -RoleFixes "SiegeArmy, ArmyHandoff, SiegeStay, SiegePosture, SiegeBar" -MaxGames 2 -SaveLogs
```
then logging off and `-MaxGames 20`. Measures (the summary's bully section): the aggressor's cities captured, its share
of all cities at T150, turns to its first capture, and its strength share, first game against the replay. Commit as
`AIABTest_bullysiege@<COMPUTERNAME>.csv` (PC 1 plain name). This is also the first test of the "aggressive beats
greedy" side of the rock-paper-scissors goal.

### Siege package on the fixed build: no gain in split games (lead, 2026-11-03 10:10am ET)

`ab-a86d57b`, group c ran `SiegeArmy, ArmyHandoff, SiegeStay, SiegePosture` against B: 7 pairs (the logged pair plus 6),
`AIABTest_siegefix@TREEDESKTOP.csv`. c 49.9%, gain -0.08 points; **gainer SPRT failed** (LLR -44), no-worse passed.
No city changed hands; wars were rare (0.03 declarations per civ per 10 turns for c, 0.05 for b). Pair spread 0.58
points: the two games of a pair barely differed, so the flags almost never acted. Stopped at 7 pairs. The 16 pairs on
the buggy `ab-f390090` don't count.

Reading: split games give siege code no wars to fight. Its testbed is the **bully test** (`Mode = bully`): the
aggressor runs the package (+ `SiegeBar`) against the aggressor without, measured by cities captured and turns to the
first capture. The SiegeBar split test is dropped in favour of that. Why B starts so few wars is a separate question
for War and Diplomacy.

**Next on PC 2, after its 20 siege pairs: SiegeBar on top of the siege package (lead, 2026-11-03).** War's `SiegeBar`
(`ai/war` `0c2d4ce`) makes SiegeArmy wait for the city's healing plus a third of its HP a turn, not a fifth. Test build
`claude/ab-siege` (`ai/war` + the new `Base` key; release `ab-09e8743` once CI passes; results file
`AIABTest_siegebar.csv`). `Base =` puts flags on every AI civ, both groups, so group c runs the package plus
`SiegeBar` and group b the package alone:
```
powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Base "SiegeArmy, ArmyHandoff, SiegeStay, SiegePosture" -Fixes "SiegeBar" -MaxGames 40
```
First pair with logging on (`-MaxGames 2 -SaveLogs`) so War can see whether attacks march bigger and cities fall.
Commit as `AIABTest_siegebar@TREEDESKTOP.csv`. A gainer SPRT (level 3).

### Screening run 2: results (lead, 2026-11-03 11:40 UTC)

21 complete pairs (PC 1: 20 on `ab-819be70`; PC 2: 2 pairs, one on each side of the fix), 168 civ-pair differences,
no crashes on the fixed build. Pair spread 1.84 points (single games 3.67: each paired game is worth 2 unpaired ones).
Top of the ranking (effect as group share, chance it's really no better):
- `DeclareAtBorder` +0.86 (2%), `SettlersBeforeWonders` +0.84 (2%), `PolicyPrereqDepth` +0.81 (3%),
  `LosingWarBuildings` +0.61 (7%), `DealExploits` +0.50 (11%).
Bottom: `SiegeStay` -0.77 (96% no better), `BoxedInWar` -0.69, `ClosedBorders` -0.63, `SiegeBook` -0.59.
With 30 flags, about 1.5 would land under 5% by chance alone, so the top ones need their own test. No city changed
hands in any game, and wars were rare (0.05 declarations per civ per 10 turns), so the war flags had little to act on.

**Next on PC 1:** the top five together (`DeclareAtBorder, SettlersBeforeWonders, PolicyPrereqDepth,
LosingWarBuildings, DealExploits`) against B, paired, on `ab-819be70`. If additive, about +3.6 points; at a pair spread
of 1.84 the SPRT should decide in about 5-7 pairs. If it passes, single-flag tests find which ones carry it.

**Siege test on PC 2 (lead, 2026-11-03 03:45 UTC, the user's request):** PC 2 left screening run 2 after its current pair; PC 1 now plays all 20 screening pairs. PC 2 plays War's siege package on `ab-f390090` (`ai/war`): group c runs `SiegeArmy, ArmyHandoff, SiegeStay, SiegePosture` against B. First one logged pair (`-SaveLogs`, logs in `results/logs_<GameId>/`), then 20 pairs with logging off; results in `AIABTest_c7c_proposals@TREEDESKTOP.csv`. Measure: CitiesCaptured by group, then strength share (SPRT).

**Screening build 2 crash fixed (lead, 2026-11-03 03:20 UTC):** `ab-2d949f8` halted games with "Player index out of bounds" (CvDiplomacyAI.cpp:3029) when an EasyTarget civ was at war with a city-state. Diplomacy's fix 0008 is in `ab-819be70` (`claude/ab-screen2` `819be70`, CI run 88). Install `ab-819be70` before playing on; games already finished on `2d949f8` still count (the fix only changes what used to crash).

**The queue, in order** (updated 2026-11-03 01:35 UTC):
1. ~~The smoke-test pair~~ (passed).
2. ~~The King baseline's logged pair~~ (done: identical games, see above).
3. **War's 3 logged games** (below), running now.
4. **Screening run 2** (below), split between the two PCs: PC 1 plays 10 pairs (`-MaxGames 20`) on `ab-2d949f8`
   and commits its file as `AIABTest_screen2.csv`; PC 2 plays the other 10 and commits as
   `AIABTest_screen2@<COMPUTERNAME>.csv`. The summary reads both as one run. If PC 2 isn't playing yet when PC 1's
   10 pairs end, PC 1 plays 10 more.
5. The lead then queues single-flag SPRTs for the flags it ranks highest.

### 2026-11-02: smoke test of `c7c_roles` with paired games (1 pair = 2 games)

Goal: check that the newest build runs, writes all the new columns, and replays a game with the groups
swapped, at King with even rules. With the bundle it plays the same AI as c7c, so both games also count as
c7c games.

1. Finish or stop the game running now (create `tools\ab\STOP`), then pull `claude/sleepy-hopper-x77moh`.
   Everything below is new since the c7c runs: King with even rules, paired games, new results files.
2. Download, build and install in one go:
   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Run-ABTest.ps1 -Release ab-c-latest -NoLaunch -NoUpdate
   ```
   - The release title it prints must name **`6b8ebde`** (build `c7c_roles`). If it still names `9348566`,
     the c7c_roles build isn't merged yet: wait, or install `9348566` (`c7c_settings`) and check what it has.
   - The pack builder must print "Evening out the rules on King" and a list of King changes like the one in
     `CPModpack/README.md`. Paste that list, and any warning about `HandicapInfo_` lists, into the report.
3. (No separate install step any more: `Run-ABTest.ps1` runs `Build-CPModpack.ps1 -ABTest -Install`.)
4. Set the setup screens once by hand: **Pangaea**, Standard, 8 civs on separate teams, Quick, **King**.
   Civ remembers these. Ruins and resources are set by the DLL from `AIABTest.ini`, so leave those as
   they are. Logging on (`LoggingEnabled = 1`, `AILog = 1` in `config.ini`). Run one pair:
   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -MaxGames 2
   ```
   Copy `Logs\` aside after the first game (the second overwrites it).
5. Check and report:
   - `Run-Games.log` says "replay matches the first game" for game 2.
   - `AIABTest_c7c_roles.csv` has the `Warmonger`, settings (`Flip` ... `Build`) and diplomacy columns
     (`Mode` ... `TurnSecs`), and the two games' GameIds are the same apart from a trailing `F` on the
     second. `Mode` says `split`, `Role` is empty, and `TurnSecs` is above 0 from the second logged turn on.
   - `Run-Games.log` has a "turn 100 after N minutes" line for each game.
   - The runner didn't log "WRONG SETUP" (it checks map, pace, difficulty, size, 8 civs, ruins and
     resources after turn 10).
   - In the game: no ancient ruins on the map, and each capital has horses and iron nearby (Strategic
     Balance).
   - The settings columns say Pangaea, Quick, King, Standard, `StopTurn` 150, `Ruins` 0, and
     `Fixes` lists the bundle for c civs and `none` for b civs. Copy the `MapOptions` value into the report:
     it shows how Civ names the map options, which job 5 needs.
   - Same civs in the same player slots in both games; same `Warmonger` values; `Group` swapped (each c in
     game 1 is b in game 2).
   - A glance at the first turns of both games: the same map and starting spots.
   - No `AIABTest_errors.txt` in My Games.
6. Commit the CSV to `tools/ab/results/`, `Run-Games.log`, and any problems found, then push.

If the replay differs or the maps don't match, say so and stop: paired games then need another way in
(loading the turn-0 autosave instead).

### 2026-11-02, next: the King baseline (lead job 6), 20 pairs = 40 games, about 7 hours

Only after the smoke-test pair checks out. Same build and setup (King, Pangaea, Standard, 8 civs, Quick;
the DLL sets Strategic Balance and no ruins).

1. **The first pair with logging on** (`LoggingEnabled = 1`, `AILog = 1` in `config.ini`). Economy needs the
   logs. `-SaveLogs` writes each game's digest to `tools\ab\results\digest_<GameId>.txt` and copies its
   `Logs\` to `My Games\LogsArchive\<GameId>` before the next game overwrites them:
   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Fixes none -MaxGames 2 -SaveLogs
   ```
   Commit the two digests with the CSV and push. **Then do War's 3 logged games (next section) before step 2.**
2. **Then logging off** (`LoggingEnabled = 0`; it costs about 15% speed), and the other 19 pairs, with group c
   running **no candidate changes**, so every civ plays B:
   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Fixes none -MaxGames 38
   ```
3. Every 5 pairs or so, commit `AIABTest_c7c_roles.csv` and `Run-Games.log` to `tools/ab/` and push, so the
   lead can watch σ settle. A "REPLAY DIFFERS" or "WRONG SETUP" line in the log means stop and report.
4. When done, report the output of:
   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Summarize-ABTest.ps1 -Csv "$env:USERPROFILE\Documents\My Games\Sid Meier's Civilization 5\AIABTest_c7c_roles.csv"
   powershell -ExecutionPolicy Bypass -File tools\ab\Compare-ABTurns.ps1 -Folder "$env:USERPROFILE\Documents\My Games\Sid Meier's Civilization 5"
   ```

### 2026-11-02: War's 3 logged games (between the baseline's logged pair and the rest)

War needs AI logs from real wars before its flags get an SPRT: how each war was declared, how attack operations
end, and what happens at a siege. These are single games with the c7c bundle on, so c's warmongers attack.
1. Install War's build:
   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Run-ABTest.ps1 -Release ab-ai-war-latest -NoLaunch -NoUpdate
   ```
   The printed title must name `4917284` or later. If the release doesn't exist yet, its CI build is still running
   or failed: skip this section, carry on with the baseline, and report it.
2. Logging on (`LoggingEnabled = 1`, `AILog = 1`). Two games with the bundle alone, one with War's three flags on top:
   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Unpaired -Fixes bundle -MaxGames 2 -SaveLogs
   powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Unpaired -Fixes "bundle, SiegeStay, SiegePosture, DeclareAtBorder" -MaxGames 1 -SaveLogs
   ```
3. For each game, copy from `My Games\LogsArchive\<GameId>\` into `tools/ab/results/logs_<GameId>/`:
   `OperationalAILog.csv`, `MilitaryAILog.csv`, the diplomacy logs (`DiplomacyAI*.csv`), and the tactical logs
   (`*TacticalAI*.csv`). Leave out any file over 20 MB and list its size in the commit message instead.
   Also copy the game's autosaves (`Saves\single\auto\`) into `My Games\LogsArchive\<GameId>\saves\`, but
   don't commit them: they're for battle tests later.
4. Commit the CSV, digests and logs, push, and **reinstall the baseline build** before baseline step 2:
   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Run-ABTest.ps1 -Release ab-6b8ebde -NoLaunch -NoUpdate
   ```

### After the baseline: screening run 2 (20 pairs = 40 games, about 7 hours)

Replaces screening run 1 (never played). One run ranks 30 candidate flags from the same games (lead job 4's
screening regression). The build is test-only: `claude/ab-screen2` (`2d949f8`) = `claude/ab-c1` (`fdad60d`: 64-bit
flag table, proposal counts, the `Difficulty` key) + `ai/economy` + `ai/diplomacy` + `ai/war`, 39 flags, every
flag added after c7c off in the bundle, results in `AIABTest_screen2.csv`. CI run 77 compiled an earlier version (`b756936`);
this one adds Economy's 0009 (logging) and 0010 (two flags), release `ab-2d949f8`.
1. **Pull first** (the `Run-Games.ps1` start fix, `3d761c5`), then install the build by commit:
   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Run-ABTest.ps1 -Release ab-819be70 -NoLaunch -NoUpdate
   ```
2. Logging off. Group c runs nothing, and each screened flag is on for a random, warmonger-balanced half of the AI
   civs, swapped in the second game of each pair. This build reads the `Difficulty` key that `Run-Games.ps1`
   writes, so it plays King whatever the setup screen remembers:
   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Fixes none -MaxGames 20 -Screen "WidePlans, BoxedIn, BoxedInWar, TimingAttack, SiegeTechs, SiegeBook, DeclareTiming, GrowthTech, AqueductValue, GreedyBook, GreedyTarget, CanWin, ClosedBorders, SettlersFirst, SettlerOverlap, DiploPolicyValue, PolicyPrereqDepth, LosingWarBuildings, CultureRivalValue, SettlersBeforeWonders, BookFinishesSettlers, SiegeStay, SiegePosture, DeclareAtBorder, UpgradeSaveCancel, EasyTarget, DiploBugs, LuxuryAsk, DealExploits, DealReputation"
   ```
3. Commit `AIABTest_screen2.csv` and `Run-Games.log` every 5 pairs or so, and push.
