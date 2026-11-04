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

### Why warmongers go bankrupt (Economy, Nov 4, about 2:30pm ET)

**How often:** across all `AIABTest_bully*.csv`, a civ sits at 0 gold for 3+ snapshots (T30 on) in **10 of 79
aggressor civ-games (13%)**, against 9 of 474 (2%) for the other civs and 1 of 79 for the tall civ.

**The Huns in `0C22F161`** (from `CityStrategyAIProductionLog.csv`, its `GPT` field, and the results CSV):
- Gold per turn went negative at T43, reached −18 at T60 and −36 at T80, and sank to −148 by T140. The treasury hit
  0 by T80 and stayed there. The other majors in the game stayed between −5 and +50 a turn throughout.
- At T70 the Huns had **10 land units on 3 cities and 10 population**; every other civ had 3-6 (military 79 against
  20-48). That's the warmonger build (siege book, conquest role) bought on a small economy.
- While broke they kept building:
  - walls in four cities (T68-T85);
  - libraries (T85, T87);
  - about one operation warrior every two turns. Each was gifted to a city-state a turn later by CP's deficit rule.
- No gold building, no extra trade route until T108, no peace.

**Why the guards didn't stop it (confirmed in code):**
- Both upkeep guards, the unit one (`CvUnitProductionAI::CheckUnitBuildSanity`: refuse if bankrupt in under 9 turns)
  and the building one (`CvBuildingProductionAI`, same test), ask `CvPlayer::getTurnsToBankruptcy`.
- That uses `getAvgGoldRate`, which `cacheAvgGoldRate` sets to **current net rate + the 10-turn average of
  `m_GoldChangeForTurnTimes100`**.
- `CvTreasury::ChangeGoldTimes100` records **only positive changes** there (`if (iChange > 0)`).
- So the "average rate" is the net rate plus the average one-off income: city-state gold, plunder, scrapping refunds.
  Losses never count. In a deficit, any one-off income can flip it positive, and `getTurnsToBankruptcy` returns
  "never": both guards switch off while net gold per turn is −36. In surplus it double-counts income.
- Walls are exempt from the building guard anyway (`GetExtraCityHitPoints() > 0`).

**Fix, one flag: `TrueGoldRate`** (patch 0013): for flagged civs, `cacheAvgGoldRate` is the net gold rate
(`calculateGoldRate()`), so `getTurnsToBankruptcy` sees the real deficit. The existing guards then refuse new units
and maintenance buildings when bankruptcy is under 9 turns away, and penalise them under 17.
- Hypothesis: aggressors stop running into 0 gold, keep the units they build (no deficit gifting), and reach their
  war with the army intact.
- Measure: civ-games at 0 gold for 3+ snapshots (aggressors: 13% now); strength share at T150 (no-worse). Mechanism:
  units gifted "b/c bankrupt" (`MilitaryAILog.csv`).
- δ: 2 points, no-worse. It's a bug fix.
- Also reaches, through `getAvgGoldRate`: 7 places in `CvDiplomacyAI` (deal and war affordability) and 1 in
  `CvCityStrategyAI`. They all see the true rate too, which is the intent, but it's why this is a flag and not a plain fix.
- Build: patch 0013 on `7aaee41` (`ai/economy` reset to `claude/ab-c1`), flag `TrueGoldRate` (`FIX_TRUE_GOLD_RATE`).
  Status: coded, not built.
- Not in this flag, for later if it isn't enough:
  - a war-chest rule (a civ preparing a war keeps gold per turn ≥ 0 by favouring markets and trade routes);
  - walls under the guard.

### WarChest: a warmonger saves for its build-up and pays for its army (Economy, Nov 4, about 2:00pm ET; proposal, waiting on War's hook)

The user's model: a timing attacker keeps a small, cheap army most of the game, saves, and builds up fast just before
the attack. War codes the timing (`TimingBuildup`); Economy pays for it.
- **Hypothesis:**
  - While a warmonger has a planned attack and isn't at war, it puts gold aside (like the settler savings in
    `CvEconomicAI::DoHurry`) up to a target. With 2+ turns' notice, buying part of the build-up lets the army form
    in a few turns instead of 20-30.
  - When the build-up starts, it buys the attack's missing operation units with that chest.
  - While the army stands (build-up or war), gold per turn is kept ≥ 0: gold buildings and trade routes get more
    weight while the deficit lasts, and `TrueGoldRate`'s upkeep guards block units it can't pay for.
  - Expected: fewer bankrupt aggressors (13% now) and attack armies that form in a few turns.
- **Gold target, to agree with War:** the purchase cost of the build-up's units (about N × the gold price of the
  attack's main unit), capped at 15-20 turns of income so it can't freeze the economy.
- **The hook needed from War:**
  - something Economy can read: is a build-up planned or active, against whom, and how many units it needs;
  - for example a const accessor on the committed conquest target (today the private `m_eNewAIConquestTarget`), plus
    `TimingBuildup`'s phase.
- **Measure:** civ-games at 0 gold (aggressors); turns from build-up start to the army marching; strength share at T150
  (no-worse) and cities captured in bully games.
- **δ:** 2 points, no-worse.
- **Build:** patch 0014 on `ai/war` `2a4dde1` (it uses War's accessors). It carries `TrueGoldRate` too, since 0013's flag
  list doesn't apply on `ai/war`: **0014 replaces 0013** when `ai/war` and `ai/economy` are merged. Flag `WarChest`
  (`FIX_WAR_CHEST`):
  - `DoWarChest` in `CvEconomicAI.cpp`, from `DoHurry`;
  - a +500 bonus for gold-yield buildings in `CvBuildingProductionAI` when the phase is window or later and gold per
    turn is below 0;
  - logs "WAR CHEST - Bought ..." in the homeland log.

  Gold target as agreed with War: units still wanted × the unit's price, capped at 15 turns of net income, at least 2
  siege units. War gates its stand-in saving and buying (`DoTimingBuildup`) on `!UsesCandidateAI(FIX_WAR_CHEST)`.
  Status: coded, not built. Test it together with `TimingBuildup`, since it only acts for timing attackers.

### WarEconomy: a planned attack prepares the economy in peace (Economy, Nov 4, about 2:00pm ET; proposal, same hook)

The user's follow-up: while the attack is planned and the civ is still at peace, it gets ready to switch to war
fast. One flag, `WarEconomy`, separate from `WarChest` (gold). It reads the same War hook (committed target and
`TimingBuildup`'s "planned" phase).
- **Production in the cities that will build the army** (the 2-3 cities nearest the target):
  - production buildings (forge, workshop) and military ones (barracks, armory) get a bonus in
    `CvBuildingProductionAI`;
  - other cities keep their normal choices.
- **Strategic resources:** if the attack's main units need iron or horses and the civ has none connected, workers
  prioritise an owned source, and plot purchases favour one in reach (`CvEconomicAI`, `CvBuilderTaskingAI`).
- **Hypothesis:** the build-up takes fewer turns and the army arrives sooner, with better units, for little peacetime
  cost (buildings it would want anyway, a few roads).
- **Measure:** turns from build-up start to the army marching; cities captured in bully games; strength share at T150
  (no-worse).
- **δ:** 2 points, no-worse.
- **Build:** patch 0015, on 0014. **Part 1 only (buildings):**
  - flag `WarEconomy` (`FIX_WAR_ECONOMY`): +400 for buildings with a production modifier or land-unit experience;
  - for the cities within 3 tiles of our nearest city's distance to the target's nearest city;
  - in War's "planned" and "window" phases (`CvBuildingProductionAI`).

- **Part 2, patch 0016 (on 0015), same flag:**
  - **Iron and horses:** `CvBuilderTaskingAI::GetResourceWeight` multiplies the improvement value by 4 while the civ
    has none of that resource, in the "planned" and "window" phases.
  - **No road toward the target:** dropped on the user's call. Road upkeep is about 1 gold a tile per turn, on the
    civs most prone to bankruptcy.
  - No plot purchases toward a resource.
- Status: both parts coded, not built. 0014-0016 apply cleanly on `ai/war` `250ee9d`.

### The user's flag rulings for Economy (Nov 4, about 2:40pm ET)
- **`WidePlans` and `SettlerOverlap` go into the bundle** (ruled obviously right). Patch 0017 on `claude/ab-c1` `166ebc1`.
  Both are read only inside the opening book, which `GetOpeningBook` gives to AI major civs only, so city-states (which
  run every bundle flag) never reach them.
- **`SettlersFirst` stays off** (the user disagrees: monument, shrine and worker come first). No more work on it.
- **`BookFinishesSettlers`:** no ruling, tested as usual.

### GreedyBook redesigned: beeline the National College, then open up (Economy, Nov 4, about 2:40pm ET)
The user's design. The old `GreedyBook` (c7) ran the tall capital's book on through the aqueduct and university to
T130 Standard, with Engineering and Education.
- **New:**
  - greedy tall capitals use B's tall book (… library, National College), with B's tall research (Pottery, Writing,
    Philosophy);
  - the book stays on until the capital has the National College (capped at T130 Standard), instead of B's fixed
    T80;
  - then it ends and the normal AI opens up: more cities, buildings and wonders as it sees fit.
- **Hypothesis:** the National College comes sooner and the civ isn't locked into a long greedy build, so tall civs
  gain science early and still expand afterwards.
- **Measure:** strength share at T100 and T150. Mechanism: `NationalCollege` (results column, the turn it's built),
  cities at T150 for tall civs.
- **δ:** 2 points, gainer test. The flag keeps its name (`GreedyBook`); it's off in the bundle.
- **Build:** patch 0018 on 0017 (`claude/ab-c1` `166ebc1`). The greedy book arrays and the Engineering/Education
  research list are removed; `IsOpeningBookActive` ends the tall book once the capital has the National College.
  Status: coded, not built.

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

### Diplomacy: flag `GreedyWideDeals` (Diplomacy session, 2026-11-04 5:25pm ET)

Personality's request, for the user's "greedy wide" design. Pushed as `ai/diplomacy` `f1deaa1`, on `claude/ab-c1`
`c5015f1`; off in the bundle.
- **When it acts:** for a civ with `GreedyWide` once `IsGreedyWideOutOfRoom()` is true, while the civ grows
  vertically.
- **What it does:**
  - luxury trade, open-borders and research-agreement offers come twice as often (cooldowns 10/12/10 turns instead of
    20/25/20);
  - it wants research agreements with any major civ it's at peace with, doesn't distrust and is at least neutral
    toward (the deal AI still checks it can afford one);
  - it wants open borders with any major civ it's at least neutral toward, after CP's vetoes (denouncements, an army
    in place to attack).
- **Major civs only:** the helper `IsGreedyWideDealSeeker` checks `isMajorCiv`.
- **Measures:** deals and research agreements made by greedy wide civs after they run out of room; strength share of
  the greedy wide kind (Personality's matchup test).

### Diplomacy: `StaleWarPeace` reworked to the user's rule, and into the bundle (Diplomacy session, 2026-11-04 2:55pm ET)

**The rule, as the user put it:** "Hold out while the enemy is in danger" is the wrong question. The real question is
whether we're interested in conquering their cities. If we want to counterattack and take their cities, going on
with the war makes sense. If we don't intend to attack them, accept the peace.

**Done:** `ai/diplomacy` `f1e913c`, in the bundle (the user ruled it obviously right).
- **The question,** asked at war by `IsStaleWar`: do we intend to take their cities? Yes if any of these holds:
  - we have an attack operation against them;
  - they're our committed conquest target (TimingAttack and TimingBuildup's target);
  - our approach is WAR and the military AI has a preferred attack target among their cities.
- **If not:**
  - that alone is reason to consider peace;
  - the "they're in danger, hold out" term is dropped;
  - the peace score is raised to at least the peace threshold (20), so a fair peace is offered or accepted. The treaty
    terms still follow war score, as in CP.
- **No time condition any more:** the 20-turn stale wait from the first version is gone.
- **If yes:** CP's logic, unchanged.
- **City-state safe:** the helper checks that both players are major civs, and peace willingness is only computed in
  major civs' diplomacy turns.
- **The coalition risk from the first version still applies.** A coalition member with no attack of its own makes
  peace with the conqueror, so the bully test should watch whether coalitions now dissolve early. If they do, the
  next step is to count "an ally of ours is attacking them" as intent.

### Diplomacy: five flags join the bundle on the user's ruling (Diplomacy session, 2026-11-04 2:45pm ET)

**The ruling (user):** `TradeOpinion`, `DealReputation`, `CoalitionStrength`, `CoalitionCoop` and `CoalitionPact` are
obviously right. They go into the bundle with no test. `Sanctions` and `WarAppetite` stay off, to be tested.

**Done:** `ai/diplomacy` `1efdf86`, on `claude/ab-c1` `166ebc1`. The five are `true` in `kCandidateFixes`.

**City-state check** (non-major civs run every bundle flag):
- Every caller of the five is already limited to major civs: the diplomacy turn (`CvPlayer.cpp` ~10291), first
  contact (`CvTeam.cpp` ~4145), and deals and defensive pacts, which are between majors only.
- Each flag's own entry point now also checks `isMajorCiv()`, so none depends on its callers:
  - `GetRecentTradeScore` (`TradeOpinion`);
  - the coalition block in `DoUpdatePlayerStrengthEstimates` (`CoalitionStrength`);
  - `IsVisiblyAgainstWarmonger` (`CoalitionCoop`, `CoalitionPact`);
  - the broken-deal discount in `GetDealValue` (`DealReputation`, both players).

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
- **Status:** hypothesis, coded: `ai/war` `fd7da75` (CI pending), on `166ebc1`.

### CanWin, CSConquest, BoxedInWar into the bundle (the user's audit, via the lead) (Nov 4, about 2:37pm ET)
Coded: `ai/war` `fd7da75` (CI pending).
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
| Raider (added 2026-11-04, the user) | Wars for loot: pillages, plunders and razes, sells or burns what it takes rather than holding it, then peace for tribute | +60 (+40 to +80) | domination 40, the rest even | medium |

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

### AggressiveArmy: a small army until the build-up window (Personality, 2026-11-04 1:55pm ET)
- **The user (via the lead, 2026-11-04):** an aggressive player doing a timing attack keeps a small army most of the
  game, to avoid maintenance, and builds up fast just before attacking. `AggressiveArmy`'s 3-4 land units per city
  in peace contradicted that. War codes the build-up window (`TimingBuildup`), Economy the gold saved for it.
- **The change** (fork `ai/personality` `019c646`, on `claude/ab-c1` `7aaee41`; no new flag):
  - **The window:** `CvPlayer::IsInWarBuildup`. It's open when:
    1. we are at war with a major civ; or
    2. our approach to a major civ is WAR (CP's own war preparation, and `TimingAttack`'s committed target); or
    3. **interim, until War's `TimingBuildup` defines it:** we are a timing attacker (`TimingAttack`) from turn 70
       (Standard speed), 20 turns before `DeclareTiming`'s fallback declaration at 90. `DeclareTiming` waits for the
       army before it picks a target, so case 2 alone would never open the window for a timing attack.
  - **Outside the window**, `AggressiveArmy` keeps about a garrison plus one:
    - at most cities + 1 land units (operations +2);
    - B's small-army rule only (1 per city), and no unit-type bonus;
    - CP's recommended army size isn't lifted;
    - city-state unit gifts are refused at cities + 1.
  - **Inside the window:** 3-4 land units per city, attack, siege and ranged units first, as before.
  - **MetaDial:** its conquest-plan side (M ≥ +50) does the same. 0 < M < +50 is unchanged.
- **Coordinated with War (2:10pm ET):** War exposed the window (`CvMilitaryAI::GetTimingBuildupPhase`, `ai/war` `2a4dde1`).
  With `TimingBuildup` on, `IsInWarBuildup` follows its phases: the big army in WINDOW (15 turns from when a target is
  found) and ATTACK, and at war; garrisons in PEACE and PLANNED. War's peace cap (cities + 1) is the same as
  `AggressiveArmy`'s. Case 3 (turn 70) only applies without `TimingBuildup`. `ai/personality` merges `ai/war`
  (`d6c872c`) so it compiles with War's function; the lead merges both together.
- **What to watch** (once the aggressive set runs): an aggressive civ's `LandUnits` about cities + 1 most of the game,
  rising quickly in the 20 turns before its declaration; its economy in between (population, techs) close to a balanced
  civ's.
- **Build:** `019c646` (compiles, CI run 162), then `d6c872c` (merge with `ai/war`), then `166ebc19a` (merge with War's
  build fix `fd881bb`; compiles, CI run 168).
- **Status:** compiles (CI run 168 passed on `166ebc19a`); merged into `claude/ab-c1` by the lead.

### AggressiveWalls: walls only in threatened border cities (Personality, 2026-11-04 2:10pm ET)
- **The lead (2026-11-04):** in PC 2's pair `0C63D961` the bully had walls in every city (7 of 7; 8 of 8 in the flip).
  For the aggressive style, walls belong on threatened border cities; interior walls are upkeep spent on nothing.
- **The flag** (`AggressiveWalls`, `FIX_AGGRESSIVE_WALLS`, off in the bundle; fork `ai/personality` `48ba2e9`). A
  non-wonder building that adds city defence or HP only in a city that is:
  - under siege; or
  - close to a city of a major civ we're at war with (CP's `IsCloseToCity`); or
  - close to a city of a neighbour whose army we can see at our border (CP's military posture toward us MEDIUM or
    worse, the `GreedyAlarm` signal; only units we can see).

  Elsewhere it builds none.
- **A separate flag** so it can join the bully's role as well as the aggressive style set.
- **Measure:** the aggressor's `WalledCities` against its border cities at war; its gold per turn.
- **Status:** compiles (CI run 168 passed on `166ebc19a`, with War's build fix); merged into `claude/ab-c1` by the lead.

### GreedyAlarmScale: the alarm's reaction scales with how greedy the civ is (Personality, 2026-11-04 2:40pm ET)
- **The user's flag audit (via the lead, 2026-11-04):** GreedyAlarm should depend on the personality. A very greedy civ
  builds one extra archer when it sees the army, and builds walls only once war is actually declared; a less greedy
  one reacts sooner and more. Economy wrote GreedyAlarm; the style side is mine, coordinated with Economy's code.
- **Hypothesis:** GreedyAlarm today gives every alarmed civ the same reaction: walls valued as if at war, archers up to
  cities + 1, and no army cap at all. For the greedy style that undoes the plan whenever a neighbour's units walk past
  (posture MEDIUM needs only 3 units outside their land). Scaling it keeps most of the greedy economy for the greediest
  civs, and lets the less greedy ones keep Economy's full reaction. Expected: greedy civs' gold and science per turn up,
  cities lost no worse.
- **How greedy (g, 0 to 100):** 100 with the greedy style flags (`GreedyFewUnits` or `GreedyNoWalls`); with `MetaDial`,
  minus the meta position on the greedy half (M = -100 gives 100, M = -50 gives 50, M >= 0 gives 0); otherwise 0.
- **The flag** (`GreedyAlarmScale`, `FIX_GREEDY_ALARM_SCALE`, off in the bundle; needs `GreedyAlarm` on):
  - **Who is alarmed:** a civ with g > 0 is alarmed whatever its opening book (the greedy style keeps a small army on
    any book; GreedyAlarm alone looks only at the tall book). g = 0 is GreedyAlarm unchanged.
  - **Units:** the alarm lifts the army cap by 1 + cities x (100 - g) / 100 land units instead of removing it: the
    greedy style (g = 100) gets one unit over its peace garrison, and GreedyAlarm's archer bonus makes it an archer;
    M = -50 gets 1 + half a unit per city. A civ without a cap is unchanged. City-state unit gifts follow the same
    lifted cap.
  - **Walls:** g >= 75 builds no walls on the alarm (only once war is declared, under GreedyWarArmy's credible threat);
    below 75 the greedy wall ban is lifted for walls and castles only (barracks stay off) and GreedyAlarm's wall bonus
    (border 1000, elsewhere 300) is scaled by (100 - g) / 100.
- **Measure:** greedy civs' gold and science per turn while alarmed (`GREEDY:` lines in the log), `LandUnits` and
  `WalledCities` at T150, cities lost and wars declared on them; against `GreedyAlarm` alone, paired.
- **Build:** fork `ai/personality` `35272f9`.
- **Status:** coded, CI pending.

### Decision: Raider is a flavour archetype; Songhai stays a Conqueror (the user, 2026-11-04 11:30am ET)
The user asked whether some civs are rewarded for pillaging and sacking: "raiders" that are aggressive but needn't
conquer cities. They are, and the user ruled: "raider is a great flavour archetype. songhai works better as a
conqueror."

- **The Raider:** aggressive (home meta +60, range +40 to +80), wars for loot rather than land. It pillages
  improvements, plunders trade routes, and razes or gives back cities rather than holding them, then makes peace for
  tribute. Victory weights domination 40, the rest 20 each; medium expansion. Added to the spec's archetype table.
- **Who is a Raider** (trait data, so mods and other civs work too):
  - faster razing (the Huns);
  - plundering trade routes without a war;
  - a free promotion that rewards pillage or attacking cities: free pillage moves, healing or strength from pillage,
    plunder from city attacks (Denmark's Viking promotion).
- **The order in `GetStrategyProfile`:**
  1. a conquest bonus that pays off by holding cities (Conqueror);
  2. then raiding (Raider);
  3. then city-state takeover (Diplomat);
  4. then CP's tags.

  Raze speed moves from the conquest bonus to the raider signal.
- **Who moves:**
  - **the Huns:** Conqueror (+100 in `0A92244F`) to Raider (+40 to +80);
  - **Denmark:** Conqueror (+90 in `0AFFA02F`, from CP's warmonger tag) to Raider;
  - **Songhai:** stays a Conqueror (its plunder gold comes from taking cities). Assyria and Mongolia stay Conquerors.

  To confirm in logged games on this build.
- **What it changes now:** `StrategyProfile_Log.csv`, and `MetaDial`, where a Raider at +50 or more gets the conquest
  plan. Nothing in the running tests reads either.
- **Which cities a Raider keeps (the user, 2026-11-04 11:30am ET):** "a raider would only keep a city if it is a very
  valuable location and they think they can hold it without much trouble". Proposed rule, a stricter version of CP's
  own keep-or-raze rule (`CvPlayerAI::AI_conquerCity`: keep at 80% of the median city's value, or with wonders, a holy
  city, or the only city on a landmass). A Raider keeps a captured city only if both hold:
  1. **very valuable:** economic value at least about 1.5× the median city's (`getEconomicValue`), or a world wonder or
     a holy city;
  2. **holdable without much trouble:** within about 8 plots of one of its own cities, and no enemy force it can see
     could retake it (the defender's siege sketch `CouldEnemyTakeCity`, from the Raider's side).

  Otherwise it razes the city, or liberates it if it was already trying to. Original capitals can't be razed, so it
  keeps them as puppets; they're good to trade back in a peace deal (Diplomacy). Not coded: it's a new flag in a
  shared file, with 2 flag slots left. Waiting for the user's call, now or together with War's raid mode.
- **Sack or raze (the user, 2026-11-04 11:35am ET: "look into when a raider should sack vs raze").** The mechanics:
  - **Capture gold is automatic:** 20 + 10 per citizen plus a random part, cut back if the old owner only just took
    the city, times the plunder modifier. Whatever the raider does next, the loot is already taken.
  - **Razing:** the city loses 1 citizen a turn (more with a raze-speed bonus: 2 for the Huns), so it takes as many
    turns as the city has citizens. A razing city is annexed and counts against the raider's happiness, and it can
    be retaken mid-raze (the old owner gets a smaller city). Original capitals can't be razed.
  - **Selling back:** cities can be traded in peace deals, so a captured city can be held as a puppet and returned for
    gold, per-turn payments or peace.

  So "sack" means take the loot and give the city back for a ransom; "raze" means take the loot and destroy the city.
  **Proposed rule, after a capture:**

  | Situation | A raider should |
  |---|---|
  | very valuable and holdable (above) | keep it |
  | can't be razed (an original capital), or worth a lot to its owner (wonders, holy city, big population) but not worth holding | sack: puppet it, return it in the peace deal for gold, per-turn payments or peace |
  | small enough to burn before an enemy force in sight could retake it (citizens / raze speed ≤ turns until it could fall) | raze: denies the rival the city for good |
  | big, not holdable, and the owner won't pay | raze anyway: each turn still costs them a citizen |

  The inputs:
  - razing time: citizens ÷ raze speed, so the Huns raze far more often;
  - retake time: `CouldEnemyTakeCity` from the raider's side;
  - ransom: what the old owner would pay, from Diplomacy's deal valuation (`CvDealAI`, `TRADE_ITEM_CITIES`).

  A raider done with its war leans toward sacking (the city doubles as a peace offer). One facing a long-term rival
  leans toward razing.
  **Who does what:**
  - Personality: the keep, sack or raze choice (`CvPlayerAI::AI_conquerCity`, shared file);
  - Diplomacy: asking a ransom for the city in the peace deal;
  - War: the raid goals.

  **Not coded.** The keep rule above and this choice would be one flag ("what a Raider does with a captured city").
- **What a Raider needs from War (request, later; the lead's hold applies):** a raid mode for its wars. That means
  pillage and trade-route plunder as goals, razing captured cities it can't hold, and peace once the loot is taken. It
  also needs its own measures, since it fails a "cities captured" test while doing its job: tiles pillaged, gold
  plundered, cities razed, and the victim's economy.
- **Build:** fork `ai/personality` `0672835` (on `claude/ab-c1` `9e9fc9d`). **Status:** compiles (CI run 154 passed, 11:48am
  ET); ready to merge.

### Strategy profile picks in the first logged games (Personality, 2026-11-04 11:30am ET)
`StrategyProfile_Log.csv` from `logs_0A92244F`, `logs_0AFFA02F`, `logs_0BC677BF` (24 civs; played on `ab-ed449fd`, before
the conquest-bonus change `277602f`, so they show the earlier rule).

| Archetype | Civs (home meta) |
|---|---|
| Conqueror | Huns +100 (no CP tag: domination pursuit and offence), Japan +100, Aztecs +95 and +100, Denmark +90, Germany +70, England +65, Shoshone +60 |
| Opportunist | none |
| Expansionist | Spain +10 and +15, Inca +10 and -5 |
| Zealot | Byzantium +5 |
| Diplomat | Venice -40 (pursuit diplomacy), Morocco -30, Netherlands -30, Arabia -35, Russia -35 (no tag: pursuit diplomacy), Portugal -20 |
| Tourism | Sweden -40, France -35 |
| Scientist | Maya -65, India -75, Babylon -55 |

- **As expected:** the Huns are Conquerors and Venice is a Diplomat, here by their pursuits. Assyria, Songhai,
  Mongolia and Austria weren't in these games; the conquest-bonus rule shows in games on `2db51dd` or later.
- **The meta spread is wide, as meant:** Conquerors from +60 to +100, the builders from -20 to -75, Expansionists and
  the Zealot near 0. Boldness and offence push most Conquerors to the top of their range.
- **No Opportunists:** the archetype only comes from a domination pursuit with offence below 7, or no pursuit and
  low expansion. It may be too narrow. To watch over more games.
- **One questionable pick: the Shoshone as Conquerors (+60).** They have both the warmonger and the expansionist tag.
  Their pursuit (science) matched neither, and the tie-break fell back to the fixed order, warmonger first. The
  Shoshone are a classic expansionist civ. **Proposed fix (not coded; the lead asked to hold new work until attacks
  take cities):** when the pursuit doesn't break a tie between the warmonger tag and another, take the warmonger tag
  only if the leader's offence flavour is 7 or more. Nothing in the test runs reads the profile yet (only MetaDial
  does), so it can wait.

**Update, games on `ab-2db51dd` to `ab-1c3ab74` (2:00pm ET), 9 more logged games:** the conquest-bonus rule and the Raider
archetype show as designed.
- **Conquerors with home meta ≥ +50:**
  - Assyria in all 5 games (+65, +85, +90, +90, +100), despite its science tag;
  - Songhai twice (+85, +90);
  - Mongolia twice (+100, +100).
- **Diplomats:** Austria (-10), Venice (-20).
- **Raider:** Denmark on `ab-1c3ab74` (+80). On the earlier builds it was a Conqueror (+75 to +95), before the Raider
  archetype. The Huns weren't in these games.
- **Generalists vary from game to game, as meant:** Rome came out an Opportunist (+30) in one game and Tourism (-75) in
  another. The first Opportunist so far.
- **The same tie as the Shoshone:** America has the warmonger and expansionist tags and came out a Conqueror (+90) twice.
  The proposed tie-break by offence flavour would cover it too.

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

**Status:** compiles (CI run 145 on `277602f` passed, 10:15am ET). Ready for the lead to merge.

### The three styles as flag sets, for the trio test (Personality, 2026-11-04 9:20am ET)
For the lead's trio mode (AGENTS.md, "The trio goal": one greedy, one balanced and one aggressive civ of ours plus 3 CP
civs, 6 players). Nothing is coded for it; this is the list a test key would give to one slot each.

| Style | Flags | What it plays |
|---|---|---|
| **Greedy** | `GreedyFewUnits, GreedyNoWalls, GreedyNoUpgrades, GreedyBuilds, GreedyWarArmy` | 1 land unit per city in peace (disbands down to it), no walls or barracks, no upgrades in peace, growth, science and wonders first. At war it judges the threat: nothing changes unless a city is under siege or an enemy force in sight could take one, and then it builds enough defenders and walls its border cities |
| **Balanced** | `BalancedArmy, BalancedWalls` | 2-3 land units per city in peace, no cap at war, walls and castles first in border cities and the capital, upgrades as normal; otherwise CP's play, which starts few wars |
| **Aggressive** | `AggressivePlan, AggressiveArmy` (a small army until the build-up window, then 3-4 per city), `AggressiveWalls` + the conquest role: `TimingAttack, DeclareTiming, SiegeBook, SiegeTechs, SiegeArmy, ArmyHandoff, SiegeAbort, SiegeFormation, SiegeStay, SiegePosture, SiegeFirst, SiegeFinish` | 3-4 land units per city in peace with siege; the conquest plan (siege techs and book, a timing attack on a weak close neighbour, a siege that holds and finishes), whatever its personality |

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

### First pair on the 25-flag role (f21a8f6): a capture, but in the game without the role (lead, 2026-11-04 4:00pm ET)

`AIABTest_bullygreedy8@TREEDESKTOP.csv`, pair `0CD189D4` (PC 2, greedy civs, logs of both games kept). Aggressor Japan.
- **With the role:** military 67 (T90), 141 (T110), 192 (T130). One war declared between T110 and T130. 7 cities at T150,
  **no capture attempt logged at all**. The army existed and the war came, but no attack reached a city.
- **Without the role (flip):** 1 city captured from a greedy civ. The capture log on Agaidika (T107–127) shows units
  "used" most turns at 200 -> 200 HP: they moved but didn't hit.
- War is asked to trace the role game: TimingBuildup's phases and target, the war's timing, and whether
  TargetVulnerability's pick (up to 12 plots) was out of reach.

### The crash didn't repeat without logging (lead, 2026-11-04 3:25pm ET)

PC 2 replayed `0C827C9C` (same seeds and civs, `ab-1c3ab74`, the same role) with **logging off: no crash**, through
T150. So the T78 crash ("32-bit address space nearly exhausted") points to logging's memory, not the code; one run
only. Logging stays on for the bully runs (the logs are what War works from); a second out-of-memory crash turns it
off. Note: the runner stops games at its own `-StopTurn` (150); the ini's `StopTurn` only records it.

### Greedy wide and tall merged (lead, 2026-11-04 5:10pm ET)

Personality's `ai/personality` `cf84181` (CI run 187) is merged into `claude/ab-c1` `c5015f1` (78 flags; the conflict
was only both sides' new flag lines). It adds:
- **The kind:** set in the strategy profile (`eGreedyKind`). An expansionist ability means wide; a small-empire or
  science ability means tall. Otherwise the expansion flavour is weighed against the larger of growth and science.
- **`GreedyWide`:** Liberty; keeps expanding while not unhappy and there's room; once out of room, food and happiness
  buildings x2.
- **`GreedyTall`:** Tradition (GreedyBook to the National College); at most 4 cities; culture buildings x1.5.
- **Results:** a `GreedyKind` column (wide/tall, every AI major). `Summarize-Trio.ps1` now names the greedy civ's kind
  per game and tallies how often each kind came out on top.
- **Trio pick:** when the greedy set lists either flag, the greedy civ is a random non-warmonger, so wide leaders come
  up too.

**The greedy style set is now** `GreedyFewUnits, GreedyNoWalls, GreedyNoUpgrades, GreedyBuilds, GreedyWarArmy,
GreedyAlarm, GreedyAlarmScale, GreedyWide, GreedyTall`. Each kind flag acts only for a leader of that kind. Not tested
yet: both PCs stay on the attack (`ab-f73177c`, the user's priority). The next trio run uses this build or a later
one. Diplomacy is asked for the wide kind's trade deals once out of room (`CvGrandStrategyAI::IsGreedyWideOutOfRoom`).

### Attack first: War's three fixes in one build, both PCs on the attack (lead, 2026-11-04 4:52pm ET)

The user: fixing the attack is the priority. **`claude/ab-c1` = `ai/war` `96f008e` (release `ab-96f008e`, CI run 184).**
It adds:
- `MarchOn`: a sneak attack that declares keeps marching as an army to the walls, instead of breaking up.
- `FocusedWar`, extended in `214c6c7`: a timing attacker with a committed target asks for and accepts no coop wars
  elsewhere and starts no second war by CP's own approach.
- `TimingBuildup` (`214c6c7`): its window gives real production weight to land and siege units.
- `TimingBuildup` (`96f008e`, the trio cause): until the army is built, targets are judged against the army the window
  will build, not the garrison army. Before this, no rival passed the strength and CanWin checks, so no window opened.

Bully RoleFixes are now the 25 flags plus `MarchOn, FocusedWar`. PC 1 runs a logged replay of trio game 0C3C8913 (the
Aztecs), then `bullyabort7` (vs normal civs). PC 2 runs `bullygreedy9` (vs greedy civs) after pair 3 of `bullygreedy8`.
Both log their first pair.
**Update 5:06pm ET:** `ai/war` `f73177c` (CI run 186) fast-forwarded in, release `ab-f73177c`: TimingBuildup's attack may
form with up to 3 units still to build (0CEF854E: Mongolia's 302 attack requests failed "for lack of units", since a
sneak attack on a major allowed 0 missing). Same flags. PC 2 restarted `bullygreedy9` on it; PC 1 runs on it too.

### Trio quick look: one of ours on top in 3 of 4, but our aggressor never declared war (lead, 2026-11-04 4:36pm ET)

PC 1, `ab-9c6f2cd`, 4 games of 6 civs to T150, logging off, no crashes (`AIABTest_trio@BOX.csv`, `2d5f0ef`).

| Game | Top (strength share) | Ours: aggressor / greedy / balanced | Our three's total share |
|---|---|---|---|
| 0C2B2973 | Greece, aggressor (20.2%) | Greece 20.2 (1st) / Egypt 16.9 (4th) / Inca 14.6 (5th) | 51.7% |
| 0C33FB69 | France, balanced (20.6%) | Songhai 17.7 (3rd) / Egypt 19.3 (2nd) / France 20.6 (1st) | 57.6% |
| 0C3C8913 | Austria, balanced (25.2%) | Aztec 14.5 (5th) / Portugal 13.3 (6th) / Austria 25.2 (1st) | 53.0% |
| 0C44C5C5 | Sweden, CP (21.4%) | America 18.7 (2nd) / Ethiopia 18.0 (3rd) / Songhai 15.6 (4th) | 52.3% |

- **On top: 3 of 4 (75%)** against the 90% goal and the 50% you'd get if all six played alike. By style: balanced 2,
  aggressive 1, greedy 0, CP 1. Four games is a first look, not a measure.
- **Our three held more than half the strength in every game** (mean 53.7%; 50% would be a draw).
- **Greedy was never on top** (2nd, 3rd, 4th, 6th), even though CP plays mostly balanced.
- **The aggressor declared no wars in any of the 4 games, and nobody captured a city.** Its RoleFixes include
  `AggressivePlan, AggressiveArmy` and the 25 conquest flags. In a 6-civ game with no flipped partner, the timing attack
  never fired. Greece came out on top by growing, not by conquest. This is the same failure as the bully tests (the
  army rarely gets there), but here the attacker never even started. **For War:** why no declaration in trio games
  (target choice with 5 rivals? the build-up never reaching its trigger?).

### The trio test is built (the user's goal; lead, 2026-11-04 3:10pm ET)

The user's point: CP plays mostly balanced, so our greedy civ should usually out-grow it, and the trio goal may be
easier than estimated. Now testable.
- **DLL (`claude/ab-c1` `9c6f2cd`):** `Mode = trio`. Our aggressive civ (the most warlike personality, `RoleFixes =`), our
  greedy civ (the most science/culture-minded of the rest, `GreedyFixes =`) and our balanced civ (a random other,
  `BalancedFixes =`) run the new AI plus `Fixes =`; every other civ runs CP's AI (`UsesNewAI` is false for it).
  `Civs = N` closes the AI slots past the Nth before the players are set up, so a 6-civ game doesn't depend on the
  setup screen. Roles `greedy` and `balanced` in the results' Role column. Single games: a flipped replay would be the
  same game.
- **`Run-Games.ps1`:** `-Mode trio`, `-Civs`, `-GreedyFixes`, `-BalancedFixes`.
- **`Summarize-Trio.ps1`:** per game, the civ on top (the winner if the game ended, else the top strength at the last
  turn), whether it's one of our three, and the tally by style. The goal is 90%; if all six played alike, 50%.
- **First run (PC 1, after 2 pairs of the attack test on `ab-f21a8f6`), at T150, logging off:**
  ```
  powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Mode trio -Civs 6 -ExpectCivs 6 -Unpaired -Fixes bundle -RoleFixes "<the 25 conquest flags>, AggressivePlan, AggressiveArmy" -GreedyFixes "GreedyFewUnits, GreedyNoWalls, GreedyNoUpgrades, GreedyBuilds, GreedyWarArmy, GreedyAlarm, GreedyAlarmScale" -BalancedFixes "BalancedArmy, BalancedWalls" -MaxGames 20
  ```
  Results `AIABTest_trio@BOX.csv`. The first game is a smoke test: 6 civs, roles set, no crash at start.

### Greedy style set grows; GreedyAlarmScale pending (lead, 2026-11-04 2:46pm ET)

Personality's `GreedyAlarmScale` (`ai/personality` `35272f9`, CI pending; the user's audit: a greedy civ's reaction
to an army at its border scales with its greed) is merged once CI passes. **The greedy style set** (OthersBase in
greedy matchups, and the trio test's greedy slot) is now `GreedyFewUnits, GreedyNoWalls, GreedyNoUpgrades,
GreedyBuilds, GreedyWarArmy, GreedyAlarm, GreedyAlarmScale`. The running easy-matchup runs keep the strict 4-flag set
(no alarm, no war army), so they stay a test of whether the attack works at all.
Economy's review (2:47pm ET): no conflict. Everything is gated by greed (0 without the flag), so `GreedyAlarm` alone is
unchanged. One trade-off, by the user's design: at greed 75 or more the wall bonus is 0, so the greediest civs build no
walls until war is declared. **Watch in the matchup test:** cities lost by the greediest civs in their first war turns.

### Everyone's work in one build: bankruptcy fixes, the audit's bundle, TargetVulnerability (lead, 2026-11-04 2:50pm ET)

**`claude/ab-c1` `f21a8f6`:** 73 flags, 24 in the bundle.
- Economy's patches 0013–0018, applied by the lead to `ai/economy` (Economy can't push to the DLL repo):
  - `TrueGoldRate`: bankruptcy checks use the net gold rate. CP added only positive changes, so a civ at -36 a turn
    read as never bankrupt until its army was gifted away.
  - `WarChest`: a timing attacker saves for its build-up, buys it, and keeps gold per turn non-negative.
  - `WarEconomy`: production and military buildings near the target; iron and horses weigh more for workers.
  - The `GreedyBook` redesign (beeline the National College, then open up).
  - `WidePlans` and `SettlerOverlap` into the bundle.
  - 0013 and 0014 both added `TrueGoldRate`; the doubled entry was dropped.
- War's `fd7da75`: `CanWin`, `CSConquest` and `BoxedInWar` into the bundle; `TargetVulnerability` (the user's redesign
  of `GreedyTarget`: the most vulnerable revealed city within 12 plots, by its defence, its owner's army against
  ours, and distance).
- Diplomacy's `1efdf86` and `f1e913c`: the five audit flags and `StaleWarPeace` (reworked to the user's rule) into the
  bundle, each with an `isMajorCiv()` guard at its entry point.
- **The merges duplicated table lines** (the bundle changes conflicted line by line), so `kCandidateFixes` was rebuilt
  from the enum: one line per flag, in the bundle if any branch put it there.
- **Both PCs skip `ab-166ebc1` and go to `ab-f21a8f6`.** The role is the 21 flags + `TrueGoldRate`, `WarChest`,
  `WarEconomy`, `TargetVulnerability`. PC 2 against greedy civs (`bullygreedy8`), after its crash replay; PC 1 against
  normal civs (`bullyabort6`).

### The timing-attack build merged; a crash; both PCs to the 21-flag role (lead, 2026-11-04 2:35pm ET)

- **`claude/ab-c1` `166ebc1`** (a fast-forward to Personality's merge of `ai/war` `fd881bb`, CI passed; 69 flags in the
  128-bit masks). It adds:
  - War's `TimingBuildup` (the user's design): a small army at peace, the attack's research and gold, a 15-turn
    build-up once a target is found, then demobilise after peace.
  - `DeclareWhenGathered`: declare once the army is gathered, not after waiting to be seen.
  - `SiegeConcentrate`: a follow-up wave joins the units near the city.
  - `SiegeKeep`: no barbarian-camp detours at war.
  - Personality's `AggressiveArmy` change (the big army only in the build-up window and at war) and `AggressiveWalls`
    (walls only in threatened cities).
  - War's `2a4dde1` broke the build (an undeclared op type); `fd881bb` fixed it.
- **Crash (PC 2, `ab-1c3ab74`, logging on):** game `0C827C9C` at T78, an access violation with "the 32-bit address space
  nearly exhausted" (~1.8 GB). Minidump in `results/crash-20261104-0C827C9C`. PC 2's guard now kills Civ at once on a
  crash window. PC 2 replays the game with logging off: a crash again at T78 means the code, none means logging's
  memory.
- **Both PCs**, from their next pair, `ab-166ebc1`, logging on: the role is the 16 flags + `DeclareWhenGathered`,
  `SiegeConcentrate`, `SiegeKeep`, `TimingBuildup`, `AggressiveWalls`. PC 2 against greedy civs,
  `AIABTest_bullygreedy8@TREEDESKTOP.csv`; PC 1 against normal civs, `AIABTest_bullyabort6@BOX.csv`.

### Where bully attacks fail: late, small, or not at all (lead, 2026-11-04 1:50pm ET)

- **Tally:** across all bully files, 2 of 39 first games (with the role) have a capture (the Huns in `0A92244F`, the Inca
  in `0C04B641`). The siege works once an army is at the walls; the attack rarely gets there whole.
- **War's trace** (its entry "the attack operations in 0C458987 and 0C22F161"), three causes:
  1. **Late:** at peace the army waits at the border for "discovered" (7 turns in `0C458987`), and the war starts
     with it strung out over 3–7 tiles; or it sits in recruiting for slots.
  2. **Small:** SiegeRoll releases 4–6-unit waves one at a time, and barbarians and home defence pull the handed-off
     units away.
  3. **Not at all:** bankruptcy. The Huns' warriors and siege units were gifted away for gold (`0C22F161`).
- **Assigned:** War, causes 1 and 2 as flags; Economy (idle until now), cause 3: why a warmonger building up runs
  out of gold, and a fix.
- The watch's first scheduled run (1:13pm ET) succeeded.

### SiegeExposure and SiegeRoll merged; the Raider archetype; masks widened to 128 flags (lead, 2026-11-04 12:35pm ET)

- **`claude/ab-c1` `1c3ab74`:** War's `SiegeExposure` (in a city attack, a unit that fired is judged at turn end by the
  planner's danger, so siege units keep shooting instead of pulling back) and `SiegeRoll` (an attack mustering within
  5 tiles of its target, already at war, moves with 3+ units: after a capture the army goes on to the next city).
  Plus Personality's Raider archetype (the Huns and Denmark; Songhai stays a Conqueror, the user's decision). That's
  exactly 64 flags.
- **`7aaee41`:** the flag masks are 128 bits wide (`ABTestFixMask` is a two-word struct in `CustomMods.h`). Play is
  unchanged; test-pack saves only.
- **Both PCs**, from their next pair once `ab-1c3ab74` is out, logging on: the role is the 14 flags + `SiegeExposure` +
  `SiegeRoll`. PC 2 against greedy civs, `AIABTest_bullygreedy7@TREEDESKTOP.csv`; PC 1 against normal civs,
  `AIABTest_bullyabort5@BOX.csv`.

### FIRST CAPTURE against greedy civs, with the capture log: the Inca take Persepolis (lead, 2026-11-04 12:20pm ET)

`AIABTest_bullygreedy6@TREEDESKTOP.csv`, pair `0C04B641` (PC 2, `ab-9e9fc9d`, the 14-flag role, greedy opponents with the
disband fix), logs of both games kept.
- **With the role**, the Inca (aggressor) were the strongest at T100 (military 80, next 54) and captured Persepolis
  from Persia at **T75**. The capture log (`*TacticalAI*`, War's `9e9fc9d`), on Persepolis: T72 200 -> 200 (4 of 5 units
  moved, no damage), T73 200 -> 102, T74 122 -> 8 (high aggression), T75 **CAPTURED**. Two attempts on Pasargadae
  (T75–76, 200 -> 200, no units used) came to nothing.
- **Conquest paid:** at T150, 8 cities and military 294 with the role, against 5 cities and 191 without (the flip, where
  the Inca declared 2 wars and captured nothing).
- So the chain works when the army is next to the city: two turns of fire and an assault at high aggression. What
  still fails is reaching that point. The first turn moves without attacking, and attacks on a second city don't
  start.

### Sieges that look strong but don't hurt: capture-attempt logging (lead, 2026-11-04 11:25am ET)

- **War, on the kept logs:** in `0BC677BF` (greedy opponents) Spain's army had 3 catapults, but at Nottingham its capture
  attempts (61–73 expected damage a turn, T141–148) left the city at full 200 HP every turn. In `0AFFA02F` (normal
  opponents) Japan's siege peaked at 29/200. So the expected damage isn't being dealt: the attacks look planned but
  don't happen, or are rejected.
- **`claude/ab-c1` `9e9fc9d`** (War, logging only): city HP before and after each capture attempt, and the units used.
  Play is identical to `2db51dd`, so both PCs switch at their next pair and keep the same results files.
- **The scheduled check-in** couldn't run in the lead's session (trusted-device limit: every fire since Nov 2 9:42pm ET
  was denied). It's now a watch that starts a fresh session every 3 hours (from 1:13pm ET): it reads results,
  refreshes the dashboard, and notifies the user only when something needs them. It can't steer sessions.

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
