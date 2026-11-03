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
  optional slots of an attack that SiegeArmy holds back as too weak. WarPrep stays a fallback if armies still don't fill.
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
