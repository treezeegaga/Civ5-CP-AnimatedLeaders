# AI A/B test results

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
| c7c | `2e9fad1` | c7b + can-win siege check + greedy civs refuse open borders | 1 | 52.9% | | ahead in its first game; needs more games |
| c7c_flags | `46fc076`, `7097d49` | c7c with one flag per idea (see Fixes below) and a Warmonger column; `7097d49` adds paired games. With the bundle and `Flip = 0` it plays the same as c7c | 0 | | | superseded by c7c_settings before any games |
| c7c_settings | `24f6ba8`, `614af3d` | c7c_flags with the game's settings in every row (lead job 3); `614af3d` sets ruins and map options from `AIABTest.ini` (job 5). The same AI as c7c with the bundle | 0 | | | CI build running; then the smoke-test pair |

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
  other. Use the force-cancel API above.
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
- **`Run-ABTest.ps1` only downloads releases** (`ab-latest` or `-Release ab-<sha>`), which come from
  `claude/sleepy-hopper-x77moh`. C builds have to be installed by hand (README.md).
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

## Requests

- **For Diplomacy** (from lead job 7): `HumanStrengthPerceptionMod` (`CvDiplomacyAI.cpp` ~11606) inflates
  human military strength by 20% at Prince, 50% at Deity, and only for humans. Decide whether the new AI
  should keep a human-only rule here (goal 2 says threats are judged by behaviour).
- **For War** (not urgent): `GetNewAIConquestTarget` keeps the committed target in a `static` array
  (`s_aiCommittedTarget`), which isn't saved, so a reloaded game re-picks. Not a multiplayer desync
  (every computer runs the same turns), but it should be game state before anything ships.

## Instructions for the PC runner

### 2026-11-02: smoke test of `c7c_settings` with paired games (1 pair = 2 games)

Goal: check that the flags build runs, writes the new column, and replays a game with the groups
swapped. With the bundle it plays the same AI as c7c, so both games also count as c7c games.

1. Check out this repo's branch `claude/admiring-fermi-qyl4j3` (the lead's branch, until it's merged into
   `claude/sleepy-hopper-x77moh`) and pull.
2. Download the DLL of fork commit `614af3d`. Its CI run is the newest run of the fork's Build workflow on
   branch `claude/admiring-fermi-qyl4j3`; the lead will put the run id here once it has passed. Until then:
   ```
   gh run list --repo treezeegaga/Community-Patch-DLL --workflow build_vp.yml --branch claude/admiring-fermi-qyl4j3 --limit 3
   gh run download <run id> --repo treezeegaga/Community-Patch-DLL --pattern "VP_MSVC_Release*" -D <empty dir>
   ```
   The artifact name must contain `g614af3d`.
3. Install: `powershell -ExecutionPolicy Bypass -File CPModpack\Build-CPModpack.ps1 -Dll <dir>\...\CvGameCoreDLL_Expansion2.dll -ABTest -Install`.
   It should print "Evening out the rules on King" and a list of King changes like the one in
   `CPModpack/README.md`. Paste that list, and any warning about `HandicapInfo_` lists, into the report.
4. Set the setup screens once by hand: **Pangaea**, Standard, 8 civs on separate teams, Quick, **King**.
   Civ remembers these. Ruins and resources are set by the DLL from `AIABTest.ini`, so leave those as
   they are. Logging on (`LoggingEnabled = 1`, `AILog = 1` in `config.ini`). Run one pair:
   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -MaxGames 2
   ```
   Copy `Logs\` aside after the first game (the second overwrites it).
5. Check and report:
   - `Run-Games.log` says "replay matches the first game" for game 2.
   - `AIABTest_c7c_settings.csv` has the `Warmonger` and settings columns (`Flip` ... `Build`), and the two
     games' GameIds are the same apart from a trailing `F` on the second.
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
