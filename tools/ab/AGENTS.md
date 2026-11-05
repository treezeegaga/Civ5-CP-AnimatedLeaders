# AI optimization: how the sessions work together

The test tooling and the audit are in [README.md](README.md) and [AUDIT.md](AUDIT.md); this file
says what we're aiming for, who does what, and how a change gets from idea to kept.

## The goal

This pack is played in multiplayer by two friends who aren't experts: one a very aggressive
warmonger, the other a tall builder. Today the AIs roll over: the warmonger conquers them one by
one, ends up with ~100 cities and wins easily, and the game is boring. We want AIs that:

1. **Put up a real fight.** Competent defence: walls, ranged units behind fortified melee, no
   suicide attacks, counter-attacks, rebuilding after losses, no giving away cities cheaply in
   peace deals. A conqueror should pay for every city.
2. **Stop a runaway conqueror together.** Civs that conquer a lot become everyone's problem:
   defensive pacts, joint wars, coordinated attacks, embargoes, World Congress votes against them.
   This is judged by **behaviour** (cities taken, civs eliminated, warmonger score), never by
   whether a player is human, and applies to AI bullies too. A peaceful tall player should find
   allies, not enemies.
3. **Are engaged in the world.** Lots of trade offers, friendships, alliances, requests, joint war
   proposals, denouncements and wars of their own: a world that feels alive, without spamming.
4. **Are extremely competent, but not experts.** Sound fundamentals and no blunders, played like
   a good, honest human player, not a min-maxer. No cheese, no cheating
   (see Fog cheats in AUDIT.md).

5. **Play many different styles, each one well.** Personality picks a real game plan, from
   super greedy tall builds to early timing attacks, and the AI carries it out competently. Every
   game should feel different depending on who's in it.

6. **Bring the pressure when the humans don't.** The pack is also played by two friends who both
   turtle. Then the AIs are the game: they race for wonders and victories, fight each other and
   change the map, pull the humans into their wars and alliances, and attack a builder who
   leaves itself weak, the way a human opportunist would. If the humans ignore the world, an AI
   should be on track to win.

7. **Adapt.** An archetype is a starting plan, not a script. Every plan has exit conditions
   and the AI keeps re-reading the game: a timing attacker whose target walls up picks another
   target or calls it off; a greedy tall civ that's threatened arms up; a conqueror facing a
   coalition makes peace or digs in; a civ whose victory is blocked switches to another. The
   same AI should cope with a warmonger game, a two-turtle game and anything in between, because
   it reacts to what's happening, not to who the players are.

Adaptation happens within a game. The AI doesn't learn across games: in multiplayer every
computer must run the AI identically, so it can't read anything a single computer remembers.

### A rock-paper-scissors meta (the user's goal, 2026-11-03)

No single play style should win everything. Three styles, each beating one and losing to one:
- **Greedy** (few defensive units, all-in economy) **beats balanced** (non-aggressive, medium defence): in peace the
  greedy civ out-grows it.
- **Aggressive** (many attacking units) **beats greedy**: it punishes thin defence by taking cities.
- **Balanced beats aggressive**: its defence holds, and the attacker has spent its production on an army for nothing.

**Today there's no triangle:** no city fell in any King test game and wars are rare, so aggression never pays and greedy
simply wins. What each side needs:
- Aggressive beats greedy: attacks that take cities (War's siege work, tested in the bully test), and attackers that
  pick thin targets (`GreedyTarget` already picks the neighbour with the fewest land units per city).
- Greedy isn't free: a greedy civ notices danger and arms up in time (`GreedyAlarm`).
- Balanced beats aggressive: a sensible defence holds against a real attack, not just against today's weak ones.
- Reading neighbours: an AI that sees a thinly defended neighbour treats it as a target, as a strong human does.

**How it's measured: a matchup test** (to build, after the bully test shows attacks can take cities). Each AI civ is
assigned a style (an extension of the bully and builders roles, `Mode = styles`). Over many games, a 3x3 table records
each style's strength share and cities captured or lost against each other style. The goal is met when each style
clearly beats one and loses to one. The order: attacks that take cities, then `GreedyAlarm`, then the matchup test.

**What greedy trades (the user, 2026-11-03):** a greedy civ that doesn't upgrade its defenders, builds no walls and
keeps very few units saves unit upkeep, production and upgrade gold for growth, and pays for it in vulnerability. So
a style flag's worth depends on the opponents: while no attack takes a city, greedy gets its savings for free and
looks strong in split games. **Style flags (`GreedyArmyCap`, `GreedyAlarm`, defence levels) are judged by the matchup
test and the bully test, not by the split-game strength SPRT alone**, which can't see the risk. Aggressors should spot
thin defence (`GreedyTarget`: fewest land units per city).

**Greedy comes in two kinds, tall and wide (the user, 2026-11-04 4:45pm ET; Personality owns it).** The trio quick
look showed the top civ usually had the most cities. Tall isn't the best answer to civs that never attack: wide is. A
good aggressor punishes a wide civ more easily, but where none is around, a wide civ can expand for a long time
unpunished. Both kinds are non-violent and greedy:
- **Greedy wide:** takes Liberty and expands across the map as fast as happiness and growth allow, without regard for
  defence. Once it runs out of room, it grows its cities vertically and makes trade deals.
- **Greedy tall:** takes Tradition and keeps to 3-4 cities. It spends everything on non-military interests, rushing up
  the tech and social policy trees as fast as possible.

Built: `GreedyWide`, `GreedyTall` (`claude/ab-c1` `c5015f1`), in the greedy style set; `GreedyKind` column. A leader's personality decides which kind it plays (e.g. its expansion flavour against its growth/science flavours).
The greedy role in the trio and matchup tests plays whichever kind its leader is. Judged by matchups like every style
flag. Expected: wide out-grows tall while nobody attacks; once attacks take cities, aggressors punish wide more.

**Hurry rules, no test (the user, 2026-11-05 10:37am ET):** "I just never want to see a civ hurry a warrior again."
- No civ of ours buys a Warrior with gold, ever: `NoObsoleteHurry`, in the bundle.
- Warmongers buy only settlers and siege units with gold: `WarmongerHurry`, in the bundle.

### Priorities: competence first, then flavour and fun

The list above is where we're going, not the order we work in. Making the AI merely competent is
already hard, so the work comes in two phases:

**Phase 1: strength, until the AI is competent.** The number one priority is making the AI play
better: bug fixes, combat, defence, expansion, economy, and not being exploitable in diplomacy.
Strength share against CP's AI is the main measure. Flavour work waits, except the rules that are
never optional (no cheating, multiplayer-safe).

**Phase 2: flavour and fun.** Archetypes, interactivity, coalitions tuned for fun, the
two-turtle game. Strength becomes a guard: phase 2 changes must pass a no-worse test so they don't
give back what phase 1 gained.

**Full games to a winner (the user, 2026-11-04), once the AI is competent:** attacks take cities, the early game is
fixed, and the matchup table cycles. Then games run to a victory (no `StopTurn`), so each game has a winner. They
answer what T150 can't: does a leader close out a win, do the others gang up on it, do the victory pursuits and
the late game work? They're slow, a few hours a game with late-game AI turns, and a win is one result per game, so a
win-rate stopping test needs a few hundred games (50% to 60% at 5% errors is about 260). So full games are for
checks and a running win table, and the change-by-change verdicts stay on T150 strength share.

**How the goal has grown (the user, 2026-11-04).** The original targets (beat CP's AI on strength, survive a bully)
still stand, but the aim is now **a competent AI that plays like a real opponent**:
1. **Different styles, each played well:** greedy, balanced and aggressive, in a rock-paper-scissors cycle, so no
   style is best overall.
2. **Judged by matchups, not one number:** an attacker should take cities from greedy civs and struggle against
   balanced ones; a defender is judged against an attacker that can actually conquer.
3. **Reacts like a good player:** prepares only for threats it can see (a force that could take a city, not a war
   declared from across the world), makes peace when a war goes nowhere, and lets the others gang up on a runaway.
4. **Plays fair:** no cheats, and only the information a human would have.
5. **Sensible strategy, not just stronger strategy**, with the user's rulings as the guide: settlers before
   wonders, no missionaries for another civ's religion, city-state gifts mainly with Patronage, no rule against
   attacking a trade partner.
6. **Then full games with winners** (above).

Strength share stays as the guard and the quick test for each change, and 60% against CP stays a milestone; it's no
longer the whole definition of good.

**The trio goal (the user, 2026-11-04):** put our three styles (one greedy, one balanced, one aggressive) into a
6-player game with 3 CP civs. One of our three should win. The user's aim is 100% of games. The working target is
**≥ 90% of full games won by one of our three**, against 50% if all six played alike. A test can never prove 100%,
and a lucky CP start will take the odd game even from a much stronger AI. At T150 the proxy is that one of our
three holds the top strength spot. It needs a test mode with 6 civs: 3 style slots and 3 CP slots (lead tooling,
with Personality's style flags), once attacks work and the styles hold.

**"Competent" means** (numbers agreed with the players on 2026-11-02; they're the goal row of the scoreboard
at the top of RESULTS.md):
- clearly ahead of CP's AI: **strength share ≥ 60%** against CP, at King with even rules (raised from 55% by the
  user, 2026-11-03)
- ~~the bully test: the aggressor no longer rolls everyone over (≤ 20% of all cities, ≤ 1 city per war)~~ **removed by
  the user (2026-11-04 2:55pm ET): "if we achieve the other things that will follow naturally".** The bully test stays as a tool: an aggressor role for testing the attack code
  and the matchups. The attack is judged by matchups (the user): against greedy civs with few units and no walls the
  aggressor should take several cities, against balanced ones it should struggle.
- a lively world without spam: **0.5–2 deals per civ per 10 turns**
- AI turns **no more than 25% slower** than B's (the banned-behaviours goal, 0 per game, was **removed by the user,
  2026-11-04 9:55pm ET**)
- most tricks on the exploit checklist no longer work
- milestones at a good human player's pace (not an expert's)
- no obvious blunders when we watch games or play against it

The bully test, builders test and interactivity measures run from the start so we can see where
the AI stands, but in phase 1 they're for tracking, not for deciding what merges.

### Banned behaviours (removed)

The user removed this goal (2026-11-04 9:55pm ET). There is no list of banned moves, such as stealing city-state workers or
chopping forests for wonders, and nobody works on them. The digest's counts stay as information only.

## Where we are

The full record is [RESULTS.md](RESULTS.md): every build, its games, the city captures, why wars
fail, dead ends and fragile tooling. Read it before starting anything. In short:

| Rung | Build | Status |
|---|---|---|
| **A** | Stock Community Patch | The anchor; every rating is measured from here |
| **B** | Batch 2p, fork commit `24cc575` (on `claude/sleepy-hopper-x77moh`, whose head has moved on to unvalidated 2q-2u) | Beat A 5-0 on strength, 52.4% ± 0.7, p 1%. Frozen |
| **C** | Candidates on fork branch `claude/ab-c1`, gated by `UsesCandidateAI()` | Best so far c4 (siege timing attack): 5-1, 51.6% ± 1.1, p 10%, not frozen. Latest c7c: 52.9% in 1 game |

What follows from it:

- **Real edges are small: 1.5-2.5 points of strength share**, and single games swing about ±5.
  The per-game spread in RESULTS.md is roughly 3-5 points, so an unpaired SPRT test at δ = 2 needs
  about 15-40 games. Paired games should cut that a lot. Most C verdicts so far are 1-3 games,
  which can't tell good from bad, and each C build bundles several ideas. From here on: one idea
  per flag, paired games, SPRT decides.
- **The b/c split isn't neutral.** With W warmongers, c gets ceil(W/2) and b floor(W/2), so c has a
  warmonger whenever there is one and b only with 2+. The groups have different personalities, so
  50% may not be the no-change result. A flip option (start the alternation with b) on the same
  seed makes each pair balanced. Until then, an A/A run (C with no changes) measures the bias.
- **`kABTestVersusBase` is a compile-time constant** (`true` on `claude/ab-c1`): every civ runs B
  and only `UsesCandidateAI()` splits. A vs B tests need a build with it `false`. A non-test pack
  built from `claude/ab-c1` gives every civ every C change, untested ones included.
- **The main open problem: cities almost never change hands.** About 11 lost cities in about 60
  games, one elimination, and the candidate conquest code has never taken a city from b. RESULTS.md
  already has a diagnosis from the AI logs: war declared before the army exists; the tactical AI
  won't commit in enemy-dominated zones; armies bleed out below the city's 20 HP/turn healing;
  early siege units have the same range as cities; wrong targets (c attacking c); defensive pacts;
  short games. Captures happened only at 3-10x military superiority against a defender already at
  war. That's phase 1's top priority for War, and the root of the original complaint from the
  other side: an AI that can't take cities can't counter-attack a conqueror either.
- **The greedy problem.** Greedy tall civs that cap their army get attacked (c6, 0-3). The idea
  queued in RESULTS.md: keep greed, add an alarm (walls and archers when a neighbour masses an army).
- **Existing work to reuse.** Fork branches `claude/ab-switches-diagnostics` and
  `claude/ab-switches-diagnostics-2r` (release `ab-e9f7ecf`) have per-change switches and
  diagnostic columns from a side session, based on 2r and unmerged; the matching pack branch
  `claude/angry-goodall-0e693c` was never pushed. Start the per-idea flags from there if it fits.
- **Game length.** Games stop at T150 on Quick, where armies are still small and civs have about
  25-30 techs. War fixes may need longer games to show.

Locations:

- DLL code: `treezeegaga/Community-Patch-DLL`. B is commit `24cc575`; the
  **integration branch** for new work is `claude/ab-c1` (candidates gated by
  `UsesCandidateAI()`). Paths below are in `CvGameCoreDLL_Expansion2/`.
- Test tooling and results: this repo, `tools/ab/`. Result CSVs are copied from the PC's
  `Documents\My Games\Sid Meier's Civilization 5\AIABTest_<batch>.csv` into `tools/ab/results/`
  unchanged; the PC runner keeps them up to date.
- New AI changes are gated per idea: `if (UsesCandidateAI(FIX_xx)) { new } else { B's code }`.

## Sessions

Testing time is the bottleneck, not writing code. One Windows PC plays roughly one game an hour, so
the setup is built to get the most out of each game, and no session merges anything that hasn't
been measured.

| Session | Job | Starts |
|---|---|---|
| **Experiment lead** | Test tooling, statistics, the results log, merging into the integration branch, choosing what's tested next | First |
| **War** | Military execution: tactics, armies, war decisions. Defence against a conqueror comes first | After the lead's first jobs |
| **Economy & victory** | Growth, research, buildings, gold, settling, the push to the target victory | With War: most phase 1 fixes are already coded |
| **Diplomacy** | Phase 1: bugs and exploits (deal pricing, being bluffed, reacting to real threats). Phase 2: coalitions tuned for fun, alliances, joint wars, lively trade, game-theory decisions within the personality's limits | After War and Economy have passing fixes |
| **Personality** | Each leader's strategy profile and archetype: which victory to aim for, risk appetite, wide or tall, hard rules | Phase 2 |
| **PC runner** (local, on the Windows PC) | Pulls builds, runs `Run-ABTest.ps1` / `Run-Games.ps1`, collects CSVs and logs, pushes results | Whenever games run |

Cloud sessions can't reach the Windows PC, so anything that runs Civ V is the PC runner's job: the
Claude desktop app, or `claude` in a terminal in this repo on that PC.

### How personality and the others fit together

Personality decides **what** a leader is trying to do and **the rules it plays by**. War, economy
and diplomacy decide **how** to do it as well as possible within those limits. So personality
publishes a strategy profile per leader, and the other three read it:

- victory weights (domination, science, culture, diplomatic)
- risk appetite
- expansion style (wide / tall / conquest)
- hard rules (e.g. honours deals, never attacks a friend, protects city-states)

Each leader gets an **archetype**: a game plan with its own targets, carried out by the other
sessions. A starting list (extends the opening book's Tall / Wide / Conquest):

| Archetype | Plan | What doing it well means |
|---|---|---|
| Greedy tall | 3-4 cities, maximum infrastructure and wonders, minimal army | Walls and ranged defenders in time, friends and pacts with neighbours, never an easy target |
| Wide expander | Settle fast, claim land and luxuries | Settlers escorted only where needed, happiness kept positive |
| Early timing attack | Mass an army for a specific unit timing (e.g. composite bows or chariots, catapults) and strike the nearest weak neighbour | Strikes on time with the planned army, before walls; takes cities or makes peace for a good price, then switches to building |
| Steady conqueror | Strong military economy, repeated wars all game | Fights with massed armies, consolidates conquests; triggers coalitions against itself like any other conqueror |
| Diplomat / city-state patron | Allies, city-states, World Congress | Wins votes, holds alliances, organises coalitions |
| Opportunist | Builds, but joins wars against weakened or isolated neighbours | Picks fights it can win, joins coalitions early |

Archetypes can be weighted by victory type and mixed. Within an archetype, flavours still vary
(risk, loyalty, forgiveness), so two timing attackers needn't feel the same.

Constraints aren't only costs: a leader known to keep its word gets better deals and steadier
allies. Diplomacy should cash in on that reputation, and every civ's AI should notice who keeps its word.

## File ownership

A session edits only the files it owns. To change someone else's file, write the request in the
results log under **Requests** and the owner (or the lead) does it.

| Owner | Files |
|---|---|
| Experiment lead | `tools/ab/*`, `UsesNewAI()` and the test options in `CvPlayer`, the CSV writer, `AGENTS.md`, `RESULTS.md` |
| War | `CvTacticalAI`, `CvTacticalAnalysisMap`, `CvDangerPlots`, `CvMilitaryAI`, `CvArmyAI`, `CvAIOperation` (military operations), `CvHomelandAI` |
| Economy & victory | `CvEconomicAI`, `CvTechAI`, `CvTechClasses`, `CvCityStrategyAI`, `CvBuildingProductionAI`, `CvUnitProductionAI`, `CvCityCitizens`, `CvPolicyAI`, `CvBuilderTaskingAI` (workers, including chopping), settling code and the opening book in `CvPlayer`, settler operations in `CvAIOperation` |
| Personality | `CvGrandStrategyAI`, leader flavour data (SQL/XML), the opening-book plan choice, the strategy profile |
| Diplomacy | `CvDiplomacyAI`, `CvDealAI`, `CvVotingClasses` (the World Congress AI, class `CvLeagueAI`), `CvMinorCivAI` (AI side) |

`CvPlayer.cpp` and `CvAIOperation.cpp` are shared: name the function you're changing in the
results log before you start. In `CvDiplomacyAI`'s attitude choice, personality changes the weights
and goals, diplomacy changes how decisions are computed from them.

## Rules

0. **Patterns, not whack-a-mole (the user, 2026-11-04 11:45pm ET).** Don't fix what went wrong in one game. Look for
   what goes wrong across many games, and fix the biggest pattern. For the attack, `python3 tools/ab/attack_funnel.py`
   places every logged bully game at the stage where the aggressor's attack died and counts the signals. A new fix
   names the funnel stage it targets and how many games die there. A build is frozen for a block of pairs (at least
   8, both PCs) before the next merge, so each block measures one build. A crash or a broken build is the only reason
   to switch sooner.

1. **One idea per fix.** Each fix gets its own flag (`FIX_18`, `FIX_OPENING_BOOK`, ...). Never bundle. Adding a
   flag (from fork commit `27437f0`):
   - append it to `CandidateFixTypes` in `CvPlayer.h`;
   - append one line to `kCandidateFixes` in `CvPlayer.cpp`: `{"Name", false}`, the name the ini file and the
     results use, and `false` because new flags stay out of the bundle until they pass.

   Nothing else changes. Two flags added on different branches only conflict on those two appended lines, and
   the fix is to keep both.
2. **Hypothesis before code.** In `RESULTS.md`: what should change, which measure shows it, and the
   smallest gain worth keeping (δ).
3. **Topic sessions work on their own DLL branch** (`ai/war`, `ai/economy`, `ai/personality`,
   `ai/diplomacy`) off the integration branch (`claude/ab-c1`), and rebase onto it after each merge.
4. **Only the experiment lead merges** into the integration branch, and only fixes that passed.
5. **Bugs first, tuning second.** Fix confirmed bugs before tuning numbers.
6. **Fair play.** The new AI uses only what a human player could see (see Fog cheats in AUDIT.md).
7. **Multiplayer-safe.** AI decisions use only the game state, never anything stored on one
   computer, so every computer in a multiplayer game computes the same thing (otherwise the game
   desyncs).
8. **Read `RESULTS.md` at the start of every session** and append to it before ending.
10. **Times in Eastern Time** (the user's decision, 2026-11-03): every time written for the user, in messages,
   RESULTS.md and commit messages, is US Eastern (EST, UTC-5 until March), e.g. "7:30am ET". Logs and tools that print UTC
   stay as they are; convert when reporting.
9. **Scripts run in Windows PowerShell 5.1**, the only PowerShell on the PC. PowerShell 7 (`pwsh`) parses
   things 5.1 doesn't: no `??`, `?:`, `&&`/`||` or `ForEach-Object -Parallel`, and a 2-D index inside a method
   call needs parentheses (`[Math]::Abs(($A[$r, $c]))`, not `[Math]::Abs($A[$r, $c])`; the comma reads as an
   argument separator, which stopped `Run-ABTest.ps1` on 2026-11-03). Check a changed script with
   `[System.Management.Automation.Language.Parser]::ParseFile` under `powershell.exe`, or ask the PC runner.

## Testing

### How much evidence a change needs: three levels (the user's decision, 2026-11-03)

Not every change needs a full gain test. As in Stockfish's testing, the evidence matches the risk:

| Level | Kind of change | Needs | Then |
|---|---|---|---|
| **1. No effect on decisions** | Crash guards, logging, results columns, bookkeeping the AI never reads | Compiles, plus one smoke pair with no crash and a matching replay | Merge |
| **2. Bug fix** | Code that plainly does something other than what it was written to do (inverted test, dead loop, wrong variable, wrong value scored), fixed to do what CP meant | A **no-worse SPRT** only ([-1.75, +0.25]): it mustn't hurt. Fixes can go in one bundle test; if the bundle fails, split it | Merge if no worse |
| **3. New idea** | A new behaviour or strategy, or a retuned number | The full **gainer SPRT** ([0, +2]): it must gain | Merge if it passes |

Why bug fixes still get a test: CP's numbers were tuned with the bugs in place, so a fix can upset that balance
(screening run 2: `CultureRivalValue`, a dead-loop fix, came out -0.29; `EasyTarget` -0.27 and a crash). Why ideas
need the full test: intuition misleads. `SiegeStay` looked obviously right and screened last (-0.77, 96% chance it's
worse). The level is set by the lead when the flag is added; a session can propose one in its RESULTS.md entry.
The user can also rule a change obviously right: it then merges on code review and a clean smoke pair, like level 1.

**The 41 flags, sorted (2026-11-03).** Screening run 2 effect as group share in brackets; "not screened" means it can't
act in a 150-turn split game.

*Level 1* (not flags; ungated, merged as they come): the `Difficulty` key, the `ResearchSpent`/`Faith` columns, the
proposal counts, the defence columns `WalledCities`/`CityStrength`/`LandUnits` (`ec2a4c8`), Economy's 0009 hold logging, Diplomacy's `IsEndgameAggressiveTo` guard (0008).

*Level 2, bug fixes: one no-worse bundle test, then merge.*
- Screened: `PolicyPrereqDepth` (+0.81), `LosingWarBuildings` (+0.61), `DiploBugs` (+0.42), `UpgradeSaveCancel`
  (+0.37), `LuxuryAsk` (+0.11), `DiploPolicyValue` (-0.25), `EasyTarget` (-0.27), `CultureRivalValue` (-0.29).
- Not screened: `IdeologyPick`, `EspionagePolicyValue` (act after T150), `AirRebaseHeal` (no aircraft by T150).
  They can't be measured in this setup, so they merge on code review and a clean smoke pair, and are re-checked in the
  longer games of phase 2. `CityStateBugs` goes with the bully test (it acts against a runaway).
- Not screened yet: Economy's settler-operation fixes `SettlerEscortSafe`, `SettlerSitePathFlags`, `SettlerPathCheck`
  (0011, on `ai/economy` `63c7b7b`): they join the bug-fix bundle test.
- **Ruled obviously right by the user (2026-11-03), no test:** `NoForeignMissionaries`, a civ without its own religion
  no longer buys missionaries (they spread a rival's religion with its faith). Merges on code review and a clean
  smoke pair. A founder still buys missionaries for its own religion.
- **Ruled obviously right by the user (2026-11-03 10:40pm ET), no single-flag test:** `SettlersBeforeWonders`, the
  capital starts no world wonder while the opening book still has settlers to start ("two extra cities beat
  Stonehenge"). It stays in C8, whose test against B still covers it.

**The user's flag audit (2026-11-04 2:40pm ET), flags 22–41 of the lead's list:**
- **Ruled obviously right, into the bundle** (after a city-state safety check by the owner, since non-major civs
  run every bundle flag): `CanWin`, `CSConquest`, `BoxedInWar` (War); `SettlerOverlap`, `WidePlans` (Economy);
  `TradeOpinion`, `DealReputation`, `CoalitionStrength`, `CoalitionCoop`, `CoalitionPact` (Diplomacy).
- **Ruled wrong, stays off:** `SettlersFirst`.
- **Redesigns:**
  - `GreedyTarget`: the target is the most vulnerable nearby city (the owner's total army, the city's walls and
    defence, distance), not the fewest units per city (War).
  - `GreedyBook`: a tall civ beelines the National College, then opens up (Economy).
  - `GreedyAlarm`: the reaction scales with greed; a very greedy civ builds an extra archer when it sees an army
    and walls only once war is declared (Personality).
- **`StaleWarPeace` reshaped (the user):** "hold out while the enemy is in danger" is the wrong question. The question
  is whether we're interested in conquering their cities. If we mean to attack (an attack operation, a committed
  conquest target, a war plan), fight on; if not, accept peace, with no waiting period. Ruled obviously right once
  reworked (Diplomacy).
- **No ruling, tested as usual:** `ConquestTraitTargets`, `BoxedIn`, `BookFinishesSettlers`, `WarAppetite`,
  `Sanctions`. Flags 1–21 weren't in the user's reply.

*Level 3, new ideas: full gainer SPRT.*
- c7c ideas: `WidePlans` (+0.08), `BoxedIn` (+0.34), `BoxedInWar` (-0.69), `TimingAttack` (-0.10), `SiegeTechs`
  (+0.27), `SiegeBook` (-0.59), `DeclareTiming` (-0.11), `GrowthTech` (-0.47), `AqueductValue` (+0.09), `GreedyBook`
  (-0.02), `GreedyTarget` (-0.12), `CanWin` (-0.45), `ClosedBorders` (-0.63). `LongWide` and `GreedyArmyCap` already
  failed.
- Economy: `SettlersBeforeWonders` (+0.84; ruled obviously right, see above), `SettlerOverlap` (+0.38), `BookFinishesSettlers` (+0.14),
  `SettlersFirst` (-0.20), `GreedyAlarm` (not screened: waits for captures).
- War: `DeclareAtBorder` (+0.86), `SiegePosture` (-0.18), `SiegeStay` (-0.77), `SiegeArmy` and `ArmyHandoff` (on PC 2,
  on the fixed build `ab-a86d57b`).
- Diplomacy: `DealExploits` (+0.50), `DealReputation` (+0.01), and the coalition flags `CoalitionStrength`,
  `CoalitionCoop`, `Sanctions`, `CoalitionPact` (the bully test).

**Next tests from this:** PC 1's running top-five test mixes levels (`PolicyPrereqDepth` and `LosingWarBuildings` are
level 2; `DeclareAtBorder`, `SettlersBeforeWonders`, `DealExploits` level 3). It still answers whether they gain
together. After it: one no-worse test of the eight screened level-2 fixes together, then single gainer tests of the
top level-3 ideas.


### Standard test setup

| Setting | Value | Why |
|---|---|---|
| Map | Pangaea, always (the user's decision, 2026-11-02) | Pangaea puts everyone in contact. Naval and embarked-unit code goes untested by these games, so watch for breakage there in real play |
| Size / civs | Standard, 8 civs, separate teams | 4 vs 4 per game |
| Resources | Strategic Balance | Cuts starting-position luck |
| Ancient ruins | Off | Free settlers and techs are pure luck |
| Barbarians | On | Needed for settler-escort fixes |
| City-states | Default | Realistic economy, needed for diplomacy |
| Difficulty | King, with the pack's even rules (the players' decision, 2026-11-02) | The friends play King too, and on King AIs and humans play by exactly the same rules; combat search size and diplomacy weights scale with difficulty |
| Pace | Quick; confirm finalists on Standard now and then | Speed |
| Leaders | Random | Paired games cancel the luck it adds |
| Stop turn | 100 for screening, 150+ for confirmation | Short then long |

Every CSV row records map type, resources, ruins, pace, difficulty, stop turn, the flip flag and the
enabled fixes. Changing the setup starts a new baseline: re-run a build with no fixes enabled to
measure the noise again.

### Paired games

Each map seed is played twice: once normally, once with `AI_AB_FLIP` on, which swaps the groups.
Scoring the pair's average removes most of the map's luck. (Today the group comes from player ID +
seed parity, so flipping needs its own option.)

### Stopping rule: SPRT (the Stockfish Fishtest method)

- Measure per **pair**: new group's share of total strength, minus 0.5.
- **Gainer test**, for fixes meant to make the AI stronger: H0 gain = 0, H1 gain = δ.
- **No-worse test**, for simplifications, fairness fixes and personality changes: H0 gain = −0.875δ,
  H1 gain = +0.125δ (Fishtest's non-regression shape: as wide as the gainer test, slightly above 0).
- Stop at LLR ≥ +2.94 (pass) or ≤ −2.94 (fail): 5% chance of each kind of mistake.
- Expected pairs: about **5.3 · σ² / δ²** when the true gain is at H0 or H1, up to **8.7 · σ² / δ²**
  when it's halfway (Wald), where σ is the spread of per-pair results measured on the no-fix baseline.
  If that's in the hundreds, raise δ or find a faster test. `Summarize-ABTest.ps1` prints the LLRs and
  this estimate for every setup and flag configuration in a results file.
- Checking after every pair is fine with SPRT. With fixed game counts it isn't: don't stop a
  t-test because it looks good.

### Pipeline for a fix

1. **Screen** (cheap): turn-100 games, many fixes at once. Each civ gets a random on/off for every
   fix being screened; a regression of strength share on the fix flags estimates every fix's effect
   from the same games. Fixes that look harmful are dropped, promising ones move on.
2. **Confirm**: SPRT on the single fix, paired games, stop turn 150+.
3. **Merge** into the integration branch. All later tests include it.
4. **Regression check** now and then: the current integration build against CP and the last
   kept build, so small losses don't pile up.

Before trusting turn-100 screening, check on existing data that turn-100 standings predict final
ones. Chess developers find short tests a poor predictor of long ones.

### Faster tests for combat

Battle fixes can be tested from saved games: load the same mid-war save repeatedly, let the AI
play N turns, record the outcome of the fight. Minutes per run instead of hours, and much less luck.

### Tuning numbers (SPSA)

Once a fix has passed, its "first guess" numbers (danger multipliers, the 15% target edge, the 2/3
army cut-off, ...) can be tuned with SPSA: nudge a few related numbers at once, randomly up or
down, follow whatever wins more, with shrinking steps. Each value needs a start, min, max and step
size. If values barely move after a long run, stop. Needs hundreds to thousands of games, so it
waits for fast tests (saves, turn 100) and unattended runs.

### Weaknesses, not just win rate

The human tricks listed at the end of AUDIT.md are the exploit checklist. AI-only games can't show
whether humans can still beat the AI with them, so each trick gets a check: a save or a scripted
offer that sets up the trick, and whether the new AI falls for it. Diplomacy especially: winning
against CP's old diplomacy may just mean exploiting it.

### The bully test (the headline test)

AI-only games where one civ plays the friend's role: a designated **aggressor**, the most aggressive
personality in the game, with no head start (the players' decision, 2026-11-02: the friend is aggressive,
not a strong player, and CP's AI used to fold anyway), plus one civ with a tall profile in the user's role.
The test option picks both slots. Measured per game:

- **Aggressor's share of all cities** at turns 100 and 150, and civs it eliminates. This is the
  headline number: lower means the AIs held.
- **Cities the aggressor took per war**, and turns per city taken.
- **Coalitions:** how many civs are at war with the aggressor or in defensive pacts against it,
  and how many turns after its first conquest they joined.
- **The tall civ's treatment:** wars declared on it vs. friendships and pacts with it. Being
  peaceful shouldn't make it a target.

The aggressor and the tall civ run B; the other AIs run the candidate in the first game of a pair and
B in the second, so the measure is what the candidate does to the aggressor's game, not strength share.

### The builders test

AI-only games where two slots play the turtling friends: tall profiles, no head start, no
aggression of their own. Measured per game:

- **Pressure on the builders:** wars declared on them, cities they lose, turns at war. Some, not
  a dogpile: attacks should come from opportunists and conquerors against builders with weak
  defences, not from everyone at once.
- **Pulled into the world:** offers, requests and joint-war or pact proposals made to the builders.
- **Races:** wonders the AIs take from the builders, and at turn 150 how close the leading AI is
  to a victory. If no AI is a credible threat, the builders have nothing to play against.
- **A changing map:** AI-vs-AI wars and cities changing hands. A frozen map is a dull game.

### Adaptation checks

Saves that set up a change of situation, each played several times from the same turn:

- A timing attacker's target has just built walls and archers: does it switch target or stand down?
- A greedy tall civ sees an army massing on its border: does it arm up and seek pacts in time?
- A conqueror has a coalition forming against it: does it make peace, split it, or dig in, rather
  than keep marching into it?
- A civ's victory is out of reach (wonders lost, votes lost): does it change its target?

Each check passes if the response comes within a set number of turns.

### Both games, every time (phase 2)

The bully test and the builders test pull in opposite directions (coalitions that fire too
easily make the turtle game dull; too much aggression turns it into a dogpile). Every candidate
fix is checked on both, and the scoreboard shows them side by side. A fix that helps one and
hurts the other doesn't merge.

### Interactivity measures

Per AI per 10 turns: trade offers made and accepted, friendships, defensive pacts, joint war
proposals, requests, denouncements, wars declared. Aim for a band, not a maximum: too few is a dead
world, too many is spam. The real check is multiplayer games: after each one, note in RESULTS.md
whether the AIs felt engaged or annoying, and whether they put up a fight.

### Banned-behaviour counts

Information only (the goal was removed): the log digest still counts stolen workers and wonder chops.

### Personality tests

Strength isn't enough. Two extra measures, by leader:
- **Different?** Victory types pursued, wars started, settling pace, research path, deals made.
  Leaders with different profiles should differ measurably.
- **Viable?** Every profile type should win at a reasonable rate; none far below average.
- **Done well?** Each archetype has its own checks, from the table under Sessions. For example:
  timing attackers declare war in the planned window with the planned army and take a city;
  greedy tall civs lead in science or culture at turn 100 and lose few cities when attacked.
  An archetype that's viable but sloppy (wins by luck, or only against CP's AI) still needs work.

## Results log (`tools/ab/RESULTS.md`)

One file, append-only, read by every session. Each entry:

```
### FIX_18: combat danger penalty (War)
- Hypothesis: units stop ending turns in lethal danger; fewer units lost per war
- Measure: strength share at T150; units lost per war (digest)
- δ: +2 points of strength share
- Build: fork commit abc1234, ab-abc1234
- Test: SPRT gainer, paired, Pangaea/Strategic Balance/no ruins/Quick/King
- Status: running 37 pairs, LLR +1.2 | passed | failed | merged in def5678
- Notes:
```

Sections: **Baseline** (σ per setup), **Fixes**, **Requests** (cross-owner changes), **Open
questions**.

## Experiment lead: first jobs

Status 2026-11-02: all done except job 6 (the King baseline), which needs games from the PC. Each job's
entry is in RESULTS.md, and the scoreboard is at its top.

0. Done by the previous chat: RESULTS.md, README past 2e, CSVs in `tools/ab/results/`. Check
   that `Summarize-ABTest.ps1 -MyGames tools\ab\results` reproduces the numbers in RESULTS.md.
1. Per-idea flags: `UsesCandidateAI(FIX_xx)` with each flag enabled per civ, so candidates can be
   tested one at a time or screened together. Look at `claude/ab-switches-diagnostics` first.
   Split the c4 and c7c ideas into flags (c4's research line, siege book and declare timing;
   c7c's can-win check and closed borders), and add a warmonger column to the CSV.
2. `AI_AB_FLIP` custom option (in `IsABTestCandidateSlot`, assign `(i % 2) == 1` instead of `== 0`;
   the same in `IsABTestOddSlot` for A vs B), and paired-game support in `Run-Games.ps1` (each seed twice).
3. CSV rows record settings, flip flag and enabled fixes.
4. `Summarize-ABTest.ps1`: SPRT (gainer and no-worse) per fix, the screening regression, and the
   expected-games estimate.
5. Update the `Run-Games.ps1` click script for the new setup (Pangaea every game, Strategic Balance,
   ruins off).
6. Re-run the no-fix baseline under the new setup; record σ.
7. Check whether difficulty changes AI logic beyond handicap bonuses (open question 1).
8. Check on existing data whether turn-100 standings predict turn-150 ones.
9. Don't re-prove B fix by fix: it passed as a whole and is the new reference. Splitting it
   (ablation) can wait until a B fix is suspected of hurting, e.g. item 26 in the city-capture problem.
9a. CI publishes C builds as releases (like `ab-latest`), so the PC runner doesn't need
   `gh run download`, and `Run-ABTest.ps1` can install them. Note the CI hang and force-cancel fix
   in RESULTS.md.
10. The bully test and the builders test: an option choosing the aggressor and tall slots, the
   aggressor's head start (later dropped: no head start), and digest counts for coalitions, interactivity, pressure on builders,
   victory progress and banned behaviours.
11. A scoreboard at the top of RESULTS.md, one row per milestone build: aggressor's city share,
   cities per war, coalition size and speed, interactivity rate, banned-behaviour count, strength
   vs CP, AI turn time. Plus a goal row (set the numbers with the players) that says when we're done.

## Experiment lead: the check-in ("avengers assemble", or just "aa")

When the user says **"avengers assemble"**, the lead checks on every session and reports back in one
summary. A scheduled task (`trig_011XWTtRZXtTjdt9KBqEG31m`, hourly at :42, firing into the lead's session)
runs the same check-in on its own, as the user asked; to stop it, disable that scheduled task.

**Updates for the user** (the user's choice, 2026-11-03):
- **The dashboard** (https://claude.ai/artifact/SyxMyA8FPt5MMxegEKtjiq) is refreshed at every check-in:
  `pwsh tools/ab/Export-Dashboard.ps1` writes `tests.json` and `games.json` (and `screen.json` once a screening run
  has ranks) to `tools/ab/dashboard/`; the lead edits `status.json` by hand (headline, the PC runner's queue,
  sessions, blockers, goals). Each file is uploaded as an asset to the dashboard and its source updated to the new
  asset with a fresh `updated` time. The numbers are `Summarize-ABTest.ps1 -Json`'s, the same as the report.
- **Phone notifications only for decisions**: a flag passes or fails its SPRT, a run stops (WRONG SETUP, REPLAY
  DIFFERS, a stall, three failed starts), or something needs the user. Routine progress waits for the hourly summary.

1. **The topic sessions** (IDs in RESULTS.md, "Sessions running"): for each one, `get_session` for its
   status and its latest messages (`list_events`, kinds user/assistant/result): what it's doing, what it
   found, what it's waiting for, whether it's stuck or failed.
2. **Their branches.**
   - The fork's `ai/war`, `ai/economy`, `ai/diplomacy`: new commits, and whether their CI builds and
     `ab-ai-<topic>-latest` releases passed.
   - Their pack-repo branches: new RESULTS.md entries and requests. Merge them into
     `claude/sleepy-hopper-x77moh` (fast-forward or merge, never dropping anyone's lines).
   - **Patch relay:** sessions without push access to the fork (Economy, Diplomacy; War has had access since
     2026-11-02 and pushes `ai/war` itself) commit their DLL work as `git format-patch` files under
     `tools/ab/patches/<topic>/` on their pack-repo branch. The lead applies the new ones to `ai/<topic>`
     (`git am --keep-cr`), pushes, and tells the session the commit and the build result.
   - **Flag count:** 64 at most. From fork commit `27437f0` the masks are 64-bit (`ABTestFixMask`). Before it,
     ints allowed 31, and the topic branches were at 29.
3. **The PC runner** (`claude/sleepy-hopper-x77moh`): new results CSVs and `Run-Games.log` lines. Run the
   summary and the scoreboard. Check for "REPLAY DIFFERS", "WRONG SETUP", stalls and failed starts.
4. **Act on it:**
   - Update RESULTS.md: results, the scoreboard, instructions for the PC runner.
   - Queue the tests the sessions are ready for.
   - Answer requests aimed at the lead.
   - Merge into `claude/ab-c1` only fixes that passed.
   - Push and fast-forward `claude/sleepy-hopper-x77moh`.
5. **Report** to the user: per session in a line or two, then results, decisions needed, and what runs next.

## War: first tasks (from the lead, 2026-11-02)

**Offence first: get an AI army to actually take a city.** "Defence comes first" is the long-term aim, but
in AI-only games defence can't be measured until some AI can take cities.
- About 11 cities changed hands in about 60 games, and no candidate build has ever captured one from b.
- The bully test's aggressor plays B with no head start, so it probably won't conquer anything either.
- It's also why AIs don't counter-attack a conqueror.

Once attacks work, defence fixes get a real test: the bully test against a competent aggressor.

1. **Look at the evidence first (cheap: games take about 10 minutes).** Ask the PC runner for a few
   logged King games and read `Digest-ABLogs.ps1`'s "military ops ended" counts. They show how often
   attacks die before reaching a city. `HalfStrength` is B's audit item 26 (abort below 2/3 strength);
   if it dominates, ask the lead for the item 26 ablation (RESULTS.md, lead job 9).
2. **Then fixes, one flag each, from RESULTS.md's diagnosis ("Why wars almost never take cities"),** in
   this order:
   - **Declare only when the army has gathered at its muster point.** Wars start before the army exists:
     Greece declared at T77, its army formed at T85 and arrived at T101. The most bug-like cause, and the
     easiest to test.
   - **Keep siege damage above the city's healing.** Armies bleed out: the Ottomans' damage fell from
     161 a turn to about 65, while a city heals 20 a turn. Pull back to heal, send replacements, or commit
     all at once instead of trickling in.
   - **Commit to the assault.** The tactical AI's "enemy-dominated zone, won't try to capture" rule
     keeps armies hovering outside cities.
3. **Build on the conquest flags that already exist.** c4's ideas (`TimingAttack`, `DeclareTiming`,
   `SiegeBook`, `SiegeTechs`) and c7c's `CanWin` are separate flags now (RESULTS.md, "Candidate flags").
   c4 was the best bundle so far (51.6%, 6 games), and c7c came out even (50.0%, 7 games). Once the King
   baseline gives σ, the lead runs single-flag SPRTs on them at T150. Build on the ones that pass, and
   don't redo them.

**How War's fixes are judged.**
- A hypothesis entry in RESULTS.md before any code.
- One `FIX_xx` flag per idea, gated `UsesCandidateAI(FIX_xx)`, on branch `ai/war`. Pushes there build by
  themselves and publish `ab-ai-war-latest`.
- A paired SPRT at turn 150 or later, not a turn-100 screen alone: war effects show late (lead job 8).
- Strength share is the verdict; `CitiesCaptured` (results file) is the measure that shows the mechanism.
- Battle tests from saved games would make war fixes much faster to test: ask the lead when ready.

## Economy & victory: first tasks (from the lead, 2026-11-02)

**Expansion pace first.** It's the biggest gap between our AI and a good human player:

| When cities get founded (Quick) | 2nd city | 3rd city | 4th city | Cities at T150 |
|---|---|---|---|---|
| Good human target (AUDIT.md: 4 cities by T50–60 Standard) | | | **T33–40** | |
| B (batch 2p, new group, 5 games) | T35 | T59 | T79 (80% get there) | 4.9 |
| c4 (6 games) | T31 | T61 | T73 (79%) | 5.1 |
| c7c (7 games) | T34 | T65 | T87 (82%) | 5.0 |
| CP's own AI | T32–49 | T61–65 | T80–84 | 4.7–5.1 |

The AI reaches its 4th city about 40 turns late, and one civ in five never does by T150.
- **It counts heavily in the verdict:** three of the five strength measures (cities, land, population)
  grow with it. B's one big win, 2i (found-city operations without a spare unit), was an expansion fix.
- **It's cheap to test:** economy effects show by T100 (lead job 8), games take about 10 minutes, and the
  results file records city-founding turns (`City2Turn`–`City4Turn`).
- **It's independent of War's work.**

1. **Find where the turns go before writing fixes.** Ask the PC runner for 2–3 logged King baseline
   games. `Digest-ABLogs.ps1` shows per civ:
   - its early builds (opening-book picks marked);
   - when settlers were ordered and found-city operations started;
   - turns a settler stood idle.

   Candidates to check:
   - the first settler waiting for growth;
   - one settler at a time (2h);
   - long walks to sites;
   - the book's monument and shrine coming first;
   - happiness stopping settlers;
   - saving gold that sits unspent (2j/2k).
2. **Then one flag per cause,** with a hypothesis entry in RESULTS.md before any code.
   - Test: paired games at T100, `Summarize-ABTest.ps1 -AtTurn 100`. Strength share is the verdict, and
     the founding turns show the mechanism.
   - The wide plan was already the strongest opening (13.3% strength share and 5.3 cities against 12.6% and
     4.4 for tall, batches 2e–2p), so settling more and sooner looks promising.
3. **Not first:**
   - The greedy-tall problem (c6, c7) needs War's alarm too. The existing greedy flags (`GreedyBook`,
     `GrowthTech`, `AqueductValue`, `ClosedBorders`) get single-flag SPRTs from the lead after the
     baseline: don't redo them.
   - Auditing `CvPolicyAI` and the late-game victory push come after expansion.
   - Chop-rushing wonders is counted now (`WonderChops`); act only if the count isn't 0.

Work on branch `ai/economy`: pushes there build by themselves and publish `ab-ai-economy-latest`.

## Diplomacy: first tasks (from the lead, 2026-11-02)

**An audit and a map first, no code yet.**
- A coalition against a conqueror only works if its members can fight, and today AI armies rarely take a
  city (War's first job), so "2+ civs at war with the aggressor" would mostly be wars on paper.
- The audit costs no test games, so it runs alongside War and Economy without competing for the PC.

1. **Map what CP already has against conquerors, and why it doesn't stop one.** That covers warmonger
   penalties and how fast they decay, how threats are judged, defensive pacts, coop (joint) wars, World
   Congress sanctions, the "afraid" approach and peace deals. For each: when it fires, against whom, and
   why a steady conqueror gets through anyway. This answers the original complaint (the friend's ~100
   cities) and points at the fixes.
2. **Confirmed bugs in AUDIT.md's format** (where, what, fix): `CvDiplomacyAI`, `CvDealAI`,
   `CvVotingClasses` (`CvLeagueAI`), `CvMinorCivAI`. Bugs first, tuning later.
3. **The exploit checklist, deals first**, since these matter most against humans:
   - lump-sum gold paid for per-turn gold, then a war that cancels the payments;
   - being bluffed into concessions;
   - cities given away cheaply in peace deals.

   AI-only games can't show these, so each needs a scripted check (a save or a staged offer: does the AI
   fall for it?). The audit says which exploits are real; the lead builds the check tooling for those.
4. **Then coalition fixes.** One flag each, with a hypothesis before code, judged by the bully test:
   - civs at war with the aggressor at the end;
   - turns from its first conquest until 2+ civs are at war with it;
   - the tall civ's treatment (wars on it, friends, pacts);

   plus a no-worse SPRT on strength. The goal row on the scoreboard has the targets. The first bully pairs
   (B everywhere) show the starting point.

**Already done, skip:**
- On King, the pack's even rules zero every human-only difficulty setting, including
  `HumanStrengthPerceptionMod` (AIs rating human armies 25% stronger) and `HumanOpinionChange`. Still check
  the code for human-only exceptions that don't come from the difficulty table.
- Wars declared and suffered, deals, friends, defensive pacts, denouncements and being at war with the
  aggressor are already in every results row. Requests and joint-war proposals aren't counted yet: add
  them if a fix needs them.

Work on branch `ai/diplomacy`: pushes there build by themselves and publish `ab-ai-diplomacy-latest`.

## Opening prompts

Paste one into a new session. Each assumes the repos are attached:
`treezeegaga/Civ5-CP-AnimatedLeaders` and `treezeegaga/Community-Patch-DLL`. Topic sessions write their
RESULTS.md entries and requests on their own branch of `treezeegaga/Civ5-CP-AnimatedLeaders`; the lead
merges them into `claude/sleepy-hopper-x77moh`, which only the lead and the PC runner push to. Sessions
without push access to the fork commit their DLL work as patches under `tools/ab/patches/<topic>/` on that
branch, and the lead applies them to `ai/<topic>` (see the check-in).

### Experiment lead

> You're the experiment lead for the Civ V AI optimization project. Read `tools/ab/AGENTS.md`,
> `tools/ab/README.md`, `tools/ab/AUDIT.md` and `tools/ab/RESULTS.md` on branch
> `claude/sleepy-hopper-x77moh` of `treezeegaga/Civ5-CP-AnimatedLeaders`, and the DLL fork
> `treezeegaga/Community-Patch-DLL` (B on `claude/sleepy-hopper-x77moh`, candidates on
> `claude/ab-c1`). You own the test tooling, statistics,
> the results log and merges into the integration branch. Work through "Experiment lead: first
> jobs" in AGENTS.md in order, one commit per job, and keep RESULTS.md up to date. You can't run
> Civ V: when games are needed, write exact instructions for the PC runner session in RESULTS.md.

### War

> You're the war session for the Civ V AI optimization project. Read `tools/ab/AGENTS.md`,
> `AUDIT.md` and `RESULTS.md` (repo `treezeegaga/Civ5-CP-AnimatedLeaders`, branch
> `claude/sleepy-hopper-x77moh`). Work in `treezeegaga/Community-Patch-DLL` on branch `ai/war`,
> off the integration branch `claude/ab-c1`, and edit only the files AGENTS.md gives to War.
> Read "The goal" and "Where we are" in AGENTS.md: the top priority is competent war, attack and
> defence, and the open problem is that cities almost never change hands. Then read "War: first
> tasks" in AGENTS.md: offence first, evidence from the logs before code, and the order of fixes.
> RESULTS.md ("Why wars almost never take cities") already has a diagnosis from the AI logs: start
> from it, not from scratch. Rank its causes by how much each would explain, confirm the top ones in the code, and
> turn each into one testable fix: for example declaring only once the army has gathered,
> committing to an assault instead of hovering, keeping damage above the city's healing, picking
> targets the AI can actually beat. Also check whether audit item 26 (armies abort below 2/3
> strength, already in B) makes operations give up early. Each fix gets its own `FIX_xx` flag
> behind `UsesCandidateAI()` and a hypothesis entry in RESULTS.md before any code. Battle tests
> from saved games would help: ask the experiment lead for them. After that, audit `CvHomelandAI`
> and the rest of the war code for confirmed bugs the audit missed. Read the strategy profile once
> Personality publishes it. Don't merge: the experiment lead does.

### Economy & victory

> You're the economy & victory session for the Civ V AI optimization project. Read
> `tools/ab/AGENTS.md`, `AUDIT.md` and `RESULTS.md` (repo `treezeegaga/Civ5-CP-AnimatedLeaders`,
> branch `claude/sleepy-hopper-x77moh`). Work in `treezeegaga/Community-Patch-DLL` on branch
> `ai/economy`, off the integration branch (`claude/ab-c1`), and edit only the files AGENTS.md gives to Economy.
> Read "Economy & victory: first tasks" in AGENTS.md first: expansion pace comes before everything below.
> Audit items 1, 5-8, 12-14, 16, 17, 21-23, 28 and the opening book are already in B; RESULTS.md
> has what the games showed about them (settling, religion, wide vs tall). New ideas each get a
> `FIX_xx` flag behind `UsesCandidateAI()`. After expansion pace, take the greedy problem in RESULTS.md
> (c6, c7c), together with War, since greedy civs need an alarm. Then audit `CvPolicyAI` (not yet
> audited) and the late-game victory push for confirmed bugs. Every new idea gets a hypothesis
> entry in RESULTS.md before code. Don't merge: the experiment lead does.

### Personality

> You're the personality session for the Civ V AI optimization project. Read `tools/ab/AGENTS.md`,
> `AUDIT.md` and `RESULTS.md` (repo `treezeegaga/Civ5-CP-AnimatedLeaders`, branch
> `claude/sleepy-hopper-x77moh`). Work in `treezeegaga/Community-Patch-DLL` on branch
> `ai/personality`. Personality decides what each leader tries to do and the rules it plays by;
> War, Economy and Diplomacy decide how. Read "The goal" in AGENTS.md: leaders should play
> clearly different game plans (the archetype table, from greedy tall to early timing attacks)
> and each one competently. Your first job: design the strategy profile (archetype, victory
> weights, risk appetite, expansion style, hard rules), and
> assign an archetype to every leader, from CP's existing leader flavours,
> `CvGrandStrategyAI` and the opening-book plan choice, and write it up for the other sessions as
> a short spec in RESULTS.md before coding it. Your changes are judged by no-worse tests on
> strength, plus whether leaders play measurably differently and every profile can still win.
>
> You also own **the rock-paper-scissors meta** (AGENTS.md, "A rock-paper-scissors meta"): greedy
> beats balanced, aggressive beats greedy, balanced beats aggressive. Map every leader onto one of
> the three styles (greedy, balanced, aggressive) as part of the profile. Build the **matchup test**
> with the lead: a `Mode = styles` that assigns styles to the AI civs, and a 3x3 table of each
> style's strength share and cities won or lost against each other style. When one side of the
> triangle is too strong or too weak, you fix it by tuning the styles' numbers (unit counts, defence
> levels, aggression thresholds). War, Economy and Diplomacy own the mechanics: attacks that take
> cities, `GreedyAlarm`, target choice. Ask them, through the lead, when a side fails for lack of a
> mechanic.
>
> **Started early (the user, 2026-11-03 11:15pm ET).** Every civ in the bully games is a normal CP AI with a real
> army (the weakest still has over half the bully's military), so the bully only ever meets the hard matchup.
> **First job: the greedy style as flags**, so the bully gets its easy matchup and we can see whether the conquest
> code works at all: few military units, no walls or castles, no defensive upgrades, the production into growth,
> science and wonders. Write the hypothesis and the knobs in RESULTS.md first, then code it on `ai/personality`.
> The lead adds the test key that gives a style to every civ without a role, in both games of a pair. Balanced
> and aggressive next, then the strategy profile above.

### Diplomacy

> You're the diplomacy session for the Civ V AI optimization project. Read `tools/ab/AGENTS.md`,
> `AUDIT.md` and `RESULTS.md` (repo `treezeegaga/Civ5-CP-AnimatedLeaders`, branch
> `claude/sleepy-hopper-x77moh`). Work in `treezeegaga/Community-Patch-DLL` on branch
> `ai/diplomacy`, off the integration branch `claude/ab-c1`, and edit only the files AGENTS.md gives
> to Diplomacy. Read "The goal" and
> "Diplomacy: first tasks" in AGENTS.md first (an audit and a map before any code): the main job is making AIs gang up on a runaway conqueror (judged by
> behaviour, never by being human) and be lively, engaged neighbours. Start with an audit of
> `CvDiplomacyAI`, `CvDealAI`, `CvVotingClasses` and `CvMinorCivAI`: confirmed bugs first, in the
> format of AUDIT.md, and a map of what CP already has for warmonger penalties, coalitions,
> defensive pacts and joint wars, and why it doesn't stop a conqueror today. Then apply game
> theory within each leader's strategy profile: price deals
> by time and the risk they end early (the lump-sum-for-per-turn exploit), make broken deals cost
> reputation, judge deterrence by who would actually win a war, and form coalitions against the
> leader. Lesson from Meta's Cicero: trustworthy strategy beats purely optimal strategy when
> humans are playing. Test against the exploit checklist as well as win rate.

### PC runner (local session on the Windows PC)

> You're the PC runner for the Civ V AI optimization project, running on the Windows PC with
> Civ V. In this repo (`treezeegaga/Civ5-CP-AnimatedLeaders`, branch
> `claude/sleepy-hopper-x77moh`), read `tools/ab/AGENTS.md`, `README.md` and the newest
> instructions for the PC runner in `RESULTS.md`. Pull, install the build they name with
> `tools\ab\Run-ABTest.ps1`, run the games with `tools\ab\Run-Games.ps1`, then commit the new CSV
> rows, `Run-Games.log` and any digest output to the results folder and push. Report stalls with
> the screenshot the runner saves. Never play multiplayer with the test pack installed:
> `Run-ABTest.ps1 -Restore` first.

### PC runner 2 (local session on the second Windows PC)

> You're PC runner 2 for the Civ V AI optimization project, running on the second Windows PC with
> Civ V. In this repo (`treezeegaga/Civ5-CP-AnimatedLeaders`, branch `claude/sleepy-hopper-x77moh`),
> read `tools/ab/AGENTS.md`, `tools/ab/README.md` and "Instructions for PC runner 2" in
> `tools/ab/RESULTS.md`. Do the one-time setup there (ask the user for the Steam and copy steps), then
> play the runs it names with `tools\ab\Run-Games.ps1`. Commit your results CSV and your own log
> (named in your machine file), `git pull --rebase` before every push, and never touch the first PC's
> files (`Run-Games.log`, its results files). Report stalls with the screenshot the runner saves. Never
> play multiplayer with the test pack installed: `Run-ABTest.ps1 -Restore` first.

## Open questions

1. Does difficulty change AI logic beyond handicap bonuses? **Answered (lead job 7, RESULTS.md):
   yes.** War appetite, peace length and dispute weights scale with difficulty (the pack gives the even
   difficulty Deity's combat search budget). Settled: everyone, humans and test games, plays King with
   even rules.
2. Where should committed results live: CSVs in `tools/ab/results/`, or only the summary?
3. Can Civ V run two games at once on the PC (or a second PC) to double throughput?
4. Is the turn-100 screen trustworthy for this AI? **Mostly yes (lead job 8, RESULTS.md):** turn-100
   strength predicts turn 150 with correlation 0.88 and slope about 1, with no extra noise. War fixes may
   only show later, so they're confirmed at T150+. Recheck on King pairs.
