# Community Patch AI audit

Findings from reading Community Patch 5.4.8's AI code (fork `treezeegaga/Community-Patch-DLL`,
branch `claude/sleepy-hopper-x77moh`; paths below are in `CvGameCoreDLL_Expansion2/`). Nothing here
is measured yet: each fix goes in behind `UsesNewAI()` and is kept only if the "new" group wins
the A/B test games (see [README.md](README.md)).

**Confirmed** means the code was re-read and does what's described. **Likely** means a reviewer
reported it with code references but it hasn't been re-checked. Impact is a judgement.

## Batch 1: small confirmed bugs, low risk

Coded in fork commit `6fd3058` (results go to `AIABTest_batch1.csv`).

| # | Area | Where | Bug | Fix |
|---|---|---|---|---|
| 1 | Expansion | `CvUnitProductionAI.cpp:207` | A city with fewer than 2 regular buildings trains no units at all; the Palace doesn't count, so the capital builds 2 buildings before its first Settler or Worker | Exempt settlers and workers |
| 2 | Combat | `CvTacticalAI.cpp:7651` | The "finish off weak targets" bonus compares against city HP, which is 0 for unit targets, so nearly every attack gets the full bonus: damage gets spread instead of killing units | Only use city HP when the target is a city |
| 3 | Combat | `CvTacticalAI.cpp:12640` | A planned melee kill or city capture goes ahead even when the re-check just before it says it can no longer succeed | Skip it and re-plan |
| 4 | Combat | `CvTacticalAI.cpp:7272` | HP-floor table lacks its first entry, so every aggression level uses the next level's floor (normal attacks may leave units at 25 HP, intended 40) | `{0,70,40,20,-5}` |
| 5 | Gold | `CvEconomicAI.cpp:3069`, `3396` | When income is negative the gold reserve shrinks instead of growing, so the AI spends to zero exactly when losing money | Grow the reserve |
| 6 | Gold | `CvEconomicAI.cpp:3461` | A savings request for buying a tile is never cancelled, so gold stays locked up for the rest of the game | Cancel it after a purchase / each turn |
| 7 | Expansion | `CvPlayer.cpp:47680` | Settle-site search doesn't skip plots next to cities of civs it's at war with (`continue` only leaves the inner loop) | Skip the plot |
| 8 | Research | `CvTechAI.cpp:321` | `iPropagationLevel++` passes the wrong depth to prerequisites: the first one's chain is never cut off, later ones too early | `iPropagationLevel + 1` |
| 9 | War | `CvArmyAI.h:30` | A slot emptied while an army forms stops counting as required, so armies leave without the units they lost (often their siege) | Check against the formation's template |
| 10 | War | `CvMilitaryAI.cpp:1845` | Defense levels: "below 3/4" is checked after "below 100%", so it's unreachable; the AI either feels fine or panics over one unit | Check the lower threshold first |
| 11 | War | `CvMilitaryAI.cpp:848`, `879` | "Is our city exposed?" tests the AI's own route to the enemy, not the enemy's route to it | Use the reverse route's score |

## Batch 2a: opening book

Coded in fork commit `5539cfb` (results go to `AIABTest_batch2a.csv`), in `CvPlayer.cpp`
(`GetOpeningBook` and the functions after it). Community Patch has no scripted opening; its early game
runs on the same general scoring as the rest of the game. The new AI follows a short plan picked by
personality:

| Plan | Who | Capital builds | Other cities | Techs | First branch | Ends |
|---|---|---|---|---|---|---|
| Tall | Default; science, culture or "smaller" traits | Scout, Monument, Settler, Worker, Settler, Settler, Library, National College (settlers at size 3+) | Monument, Library | Pottery, Writing, Philosophy | Tradition | Turn 80 |
| Wide | Expansionist trait, or expansion flavor >= 7 and above science and culture | Scout, Settler, Worker, Settler, Monument, Settler, Settler, Settler, Library (settlers at size 2+) | Monument | Pottery, Mining, Writing, Currency | Liberty | Turn 100 |
| Conquest | Warmonger trait, or offense flavor >= 8 and at least expansion | Scout, Settler, Worker, Archer, Settler, Archer, Monument | Monument | Archery, Bronze Working, Writing, Construction | Honor | Turn 70 |

A step is skipped when it can't be done now (city too small, no settle site, empire unhappy, not
unlocked yet, scout after turn 20), so the start adapts to the map. Turn limits are for Standard
speed and scale with game speed. The book also ends as soon as the civ is at war with a major civ.
Tech steps research the prerequisites on the way. Nothing is saved; each step is worked out from the
game state. Targets are from the CivFanatics notes below; tune them against the milestone columns.

## Batch 2: bigger behaviour changes, need tuning

Status "2b" means coded in fork commit `8eaf65e`, "2c" in `345b615`, "2d" in `25c26d8` and "2e" in
`60b57a0`, with the change described. Build 2e contains everything (results go to
`AIABTest_batch2e.csv`). The tuning
numbers are first guesses.

| # | Area | Where | Problem | Status |
|---|---|---|---|---|
| 12 | Buildings | `CvCityStrategyAI.cpp:4226`, `4253` | Flat yields scored as % increase, % buildings scored as absolute yield: University/Bank/Factory lose 5-20x to Monument/Shrine/Temple | 2b: modifiers scored as their percent |
| 13 | Buildings | `CvBuildingProductionAI.cpp:1329` | Under 3 military units per city, every building's value is cut 75% even in peacetime | 2b: 3 per city only at war, 1 per city at peace |
| 14 | Expansion | `CvEconomicAI.cpp:5071` | Expansion stops after 3 cities if any stronger civ is a neighbour | 2b: 4 cities guaranteed, stronger neighbour only stops it at war |
| 15 | War | `CvMilitaryAI.cpp:2388` | Effectively one attack at a time across all enemies | 2b: a second attack when spare land units >= cities + 4 |
| 16 | Research | `CvTechAI.cpp:104-110`, `391` | Civ/locale/victory-plan priorities are added once per flavor (~30-45 times), swamping personality; cost reweighting then favours the cheapest tech, so research goes broad instead of beelining | 2b: priorities once per tech (x10, x10, x30), cost weight 0.02 per turn left |
| 17 | Research | `CvTechClasses.cpp:1245` | Victory plan barely affects research; no planned beelines | Opening book covers the early game; later game open |
| 18 | Combat | `CvTacticalAI.cpp:8250`, `7951` | Damage taken weighted ~10-20x less than damage dealt; units end turns where visible enemies can deal 2.4x their HP (4.3x after a kill) | 2e (confirmed): danger penalty doubled; survival cut-off hp² < 50×danger (CP 42), 30 after a kill or with nowhere to flee (CP 23) |
| 19 | Combat | `CvTacticalAI.cpp:12366` | Units starting the turn in danger get a huge starting penalty before safe plots are known, so their moves all tie | 2e (confirmed): start plot scored SHRT_MIN and every move hit the SHRT_MAX cap; now a finite penalty that grows with danger, also used for units with no safe plot |
| 20 | Combat | `CvTacticalAI.cpp:39`, `12408` | Search goes greedy after 3 levels, so the 2560-position Deity budget can't be reached (~600-800) | 2e (confirmed): 4 breadth-first levels when 9 or fewer units are involved |
| 21 | Cities | `CvCityCitizens.cpp:1933` | Specialised cities (half of them, plus all cities in a gold deficit) aim for +2 food and stagnate | 2b (confirmed): half the unspecialised target |
| 22 | Buildings | `CvCityStrategyAI.cpp:4281` | Culture building value multiplied by 2-3 once per rival civ (up to x16) | 2b (confirmed): largest rival multiplier once |
| 23 | Gold | `CvCityStrategyAI.cpp:1367` | Gold purchase weights a barely started item up to 100x | 2b (confirmed): up to x1.5 |
| 24 | War | `CvMilitaryAI.cpp:902` | "Preferred target" cut-off measured against all civs' cities, so a walled human may never be attacked | 2b (confirmed): judged per owner |
| 25 | War | `CvCityStrategyAI.cpp:912` | Only the muster city builds units for an attack | 2d (confirmed): every city is offered army units but CP keeps them only in the muster city; now any city within 8 tiles of a recruiting army's muster point can build for it, while open slots exceed units already in training elsewhere |
| 26 | War | `CvAIOperation.cpp:868` | Armies keep marching at under half strength, never reinforced | 2b: abort below 2/3 while gathering or moving |
| 27 | War | `CvMilitaryAI.cpp:2335` | No defensive response when one city is attacked but the war overall looks fine | 2b (confirmed): defend anyway |
| 28 | Expansion | `CvAIOperation.cpp:1795`, `CvPlayer.cpp:47813` | Settlers wait for escorts in safe land (up to 42 turns) and walk to far sites, re-picking targets every turn | 2c (confirmed): no escort when the trip looks safe (no visible danger, at most 5 turns, no known camp or enemy city within 5 tiles); sites discounted by travel time, current target gets a 15% edge |

## Diplomacy audit (Diplomacy session, 2026-11-02)

Read from fork branch `claude/ab-c1` at `6b8ebde` (the four diplomacy files are the same at `9348566`); paths are in
`CvGameCoreDLL_Expansion2/`. The pack runs Community Patch only (`BALANCE_VP = 0`), so only the CP branches count.
Every bug marked **confirmed** was re-read in the code by the Diplomacy session, not just reported. No code yet.

### Confirmed bugs

| # | Area | Where | Bug | Fix | Impact |
|---|---|---|---|---|---|
| D1 | War targets | `CvDiplomacyAI.cpp:12046` (`DoUpdateEasyTargets`) | `if (eWarState < WAR_STATE_STALEMATE)` exits for every civ at peace, because peace is `NO_WAR_STATE_TYPE` = -1. The code below (`bAlreadyAtWar = !IsAtWar(ePlayer) && ...`, and `bDoEasyTargetCheck = bEasyTarget && !IsAtWar(ePlayer)` at 15287) is written for civs at peace. So "easy target" never helps pick a new war: opportunists never notice a weak or overstretched neighbour, a conqueror that has lost its army included | `eWarState != NO_WAR_STATE_TYPE && eWarState < WAR_STATE_STALEMATE` | High: it changes how often AIs start wars, so its own flag |
| D2 | War targets | `CvDiplomacyAI.cpp:12097` | Inside the loop over other wars, `IsPhonyWar(ePlayer)` tests the target, not the other enemy `eLoopPlayer` (the same loop in approach selection, 15309, uses `eLoopPlayer`). Matters once D1 is fixed | `IsPhonyWar(eLoopPlayer)` | Goes with D1 |
| D3 | Peace | `CvDiplomacyAI.cpp:25737`, `25808` | `bAllWarsArePhony` starts `false` and is only ever set `false`, so "make peace, the war is phony" (25890) and its term in `bConsiderPeace` (26104) never fire. AIs dragged into wars by pacts sit in them | Start it `true` | Medium |
| D4 | City-states | `CvDiplomacyAI.cpp:24210-24250` (`DoUpdateMinorCivApproaches`) | The city-state war and bully targets are only ever set, never reset (resets only at init, death and vassalage: 769, 1024, 58030). An AI that has turned friendly to a city-state keeps planning attacks on it, declares on it (27849) and refuses peace with it (25566) | `SetCSWarTargetPlayer(NO_PLAYER); SetCSBullyTargetPlayer(NO_PLAYER);` before the selection loop | Medium-high: wars nobody wants, armies spent on city-states |
| D5 | Opinion | `CvDiplomacyAI.cpp:33301`, `7611`, `22289` | "Recent assist" is positive when they helped us (`GetRecentAssistScore`, 47082: positive gives the -30 opinion bonus). Three places use it backwards: on a declaration of war, under "Clear positive diplomatic values", `if (GetRecentAssistValue(ePlayer) < 0) Set...(0)` wipes the grievances and keeps the goodwill; being plotted against (7611) does the same; and "being nasty to us" in friendship planning (22289) tests `> 75`, i.e. dropping civs that helped a lot | `> 0`, `> 0`, `< -75` | Medium: an aggressor who declares war loses the bad memories |
| D6 | Approach | `CvDiplomacyAI.cpp:18727-18738` | "Our friend is being attacked by a weak civ": `if (< STRENGTH_POWERFUL) {half weight} else if (< STRENGTH_AVERAGE) {full weight}`. The second branch is unreachable | Test `< STRENGTH_AVERAGE` first | Low-medium: AIs defend friends half-heartedly |
| D7 | Opinion | `CvDiplomacyAI.cpp:12810` | Land dispute re-evaluates the approach when the dispute level **falls**; the comment and the twin code (posture 12485) say rises | `eDisputeLevel > eCurrentDisputeLevel` | Low: a turn late |
| D8 | Threat | `CvDiplomacyAI.cpp:12440` (`CountAggressiveMilitaryScore`) | `continue` meant to skip a unit sitting near a third party its owner is fighting only advances the inner player loop, so every unit counts | Flag and break, then skip the unit | Low-medium: inflated "aggressive posture" against civs at war with neighbours |
| D9 | Deals | `CvDealAI.cpp:3879-3906` (`DoAddLuxuryResourceToThem`) | `viTradeValues.push_back` sits inside the Netherlands-only monopoly `else if`, so for everyone else the list stays empty: when balancing a deal or making a demand the AI never asks for the other side's luxuries (the mirror, `DoAddLuxuryResourceToUs`, pushes for everyone) | Move the push out of the `else if` | Medium: fewer luxury swaps, a less lively trade world |
| D10 | City-states | `CvMinorCivAI.cpp:11484` | When the ally's influence falls below a rival's, the handover calls `DoFriendshipChangeEffects(eNewAlly, X, X)` with equal old and new values, and the early return at 11350 swallows it. The old ally keeps the city-state until the rival's influence changes again | Call `SetAlly(eNewAlly, bFromQuest)` | Medium for diplomatic play |
| D11 | City-states | `CvMinorCivAI.cpp:16135` (`DoTeamDeclaredWarOnMe`) | The roll for "other city-states turn permanently hostile to the aggressor" is seeded without `eOtherMinorCiv`, so every city-state gets the same number: all react or none do | `.mix(eOtherMinorCiv)` | Medium: city-states' reaction to a warmonger is all-or-nothing |
| D12 | World Congress | `CvVotingClasses.cpp:14098`, `14104` | "Proposed last session, halve the score" compares a proposal's running ID with the resolution type's index (`it->GetID() == pkInfo->GetID()`); the right test, `it->GetType() == eResolution`, is used at 2826 | `it->GetType() == eResolution` | Low: random halving early, none later |
| D13 | Deals | `CvDealAI.cpp:6376`, `CvDiplomacyAI.cpp:57882` | A human friend's help request rolls `getAsyncRandNum` and only a yes starts the cooldown, so the human can ask again until the roll passes (gold up to half the gap, GPT, a luxury, a tech, for free). Human-only by design (help requests are a human UI) | Start the cooldown on a refusal too; roll with the synced RNG seeded by turn and players | Medium against humans |

**Likely, not yet confirmed:** coop-war desire's "target is stronger than us" term has the opposite sign of its
comment (`CvDiplomacyAI.cpp:42813`, `-=` where the ally term below uses `+`); the denounce weight's "don't be a pawn"
check tests the target instead of the third party (45148); the AI's sell price for one of its cities is computed
from the buyer's side only, skipping its own guards (fewer than 5 cities, original capital, holy city;
`CvDealAI.cpp:985` against 2148-2161); the "generous deal" check never fires for a human proposal
(`CvDealAI.cpp:229-237`, cosmetic plus a smaller trade-opinion gain); in CP a just-successful gold tribute can pay 0
(`CvMinorCivAI.cpp:14000`, may be intended).

### Human-only rules that survive the even rules

The pack's even rules make `HUMAN_USES_AI_MECHANICS = 1`, but in the DLL that switch only covers
`isHuman(ISHUMAN_MECHANICS)` (4 places in diplomacy: AI-aggressive game options). The 32 `isHuman(ISHUMAN_HANDICAP)`
checks are governed by `HUMAN_USES_AI_HANDICAP`, which stays 0. Most of them read the human's own difficulty row,
which at King equals the game's row, so they make no difference. Two don't:
- **`ComputeRatingStrengthAdjustment`** (`CvDiplomacyAI.cpp:11602`): with `HumanStrengthPerceptionMod` = 0, a human's
  army is still never rated below 100% while it's above the starting rating, whereas an AI's below-average army is
  rated down to 50%. Small, and it makes AIs more cautious of humans only.
- **Deal margins:** an AI keeps 2 GPT in reserve against AI partners only (`CvDealAI.cpp:4675`, `4744`), and accepts
  any human gift (192-195). Harmless.

No rule exempts a human conqueror. The failure below is behavioural and applies to AI bullies just the same.

### Exploit checklist: deals first

| Trick | Verdict | Why (code) | Fix idea |
|---|---|---|---|
| Lump sum paid for per-turn gold or resources, then war cancels the payments | **Blocked in ordinary trades** | `BlockTemporaryForPermanentTrade` (`CvDealClasses.cpp:1428-1449`, `DEALAI_HUMAN_PERMANENT_FOR_AI_TEMPORARY = 1`) forbids paying AI gold, cities, techs or maps for a human's GPT, resources, open borders or embassy; `BlockGoldOnlyTrade` also blocks plain gold for GPT. The reverse (human pays a lump, AI pays per turn) is safe for the AI | none needed |
| ... in a **peace deal** | **Real** | A surrendering human's GPT and resources run `GetDealDuration()` turns (`CvDealAI.cpp:5094`) and the AI values all of them, but the peace lock is only `getPeaceDealDuration()` (5124; base data: 10 turns of 30 at Standard, not checked in this repo). After the lock the human re-declares and the rest of the payments vanish. Also, the AI counts GPT it *pays* as a gain from war (`CvDiplomacyAI.cpp:13576`) | Value per-turn items over the turns the other side is actually bound, discounted by its record (below) |
| War cancels a deal: no reputation cost | **Real** | `DoCancelDealsBetweenPlayers` ends everything with nothing refunded; the only fallout is RecentTradeValue set to 0 (`CvDiplomacyAI.cpp:33277`). No "broke a deal" memory exists; backstab penalties cover only friendships and military promises (33220-33262) | Remember deals cancelled by the declarer's war while it still owed payments; opinion penalty and worse deal terms |
| Bluffing with demands | **Partly real** | `GetDemandResponse` (`CvDealAI.cpp:435-575`) gives in on perceived relative strength and units parked near the border; nothing asks whether the demander could take a city. Refusing is the default for big items (gold lumps, cities, techs) | Judge with the war-outcome estimate below |
| Help-request re-roll | **Real** | D13 | D13 |
| Cities cheaply in peace deals | **Mostly not real** | Cities are valued from the winner's side (15000 base, at least pop × 729, `CvDealAI.cpp:2355`); the AI gives one only above war score 25 (a city about to fall) or 60 (5135-5235) | Not first. The likely city-sale hole (above) is outside peace deals |
| Same luxury sold twice, re-exports | Not real | `CvDealClasses.cpp:570-585` | |
| Tech resale (if tech trading is on) | Partly real | price ignores how many civs know the tech (`CvDealAI.cpp:6692`) | Low priority |

### What CP has against a conqueror, and why it doesn't stop one

The warmonger score works. It's the step from hating a conqueror to acting against it that fails.

1. **Warmonger penalties work, and pile up per observer.** Each capture is charged to every living major
   (`ApplyWarmongerPenalties`, `CvDiplomacyAI.cpp:54378`), scaled up for a strong conqueror, close observers and
   victims who are pact partners; down when the observer was itself losing to the victim (54457) or hates it.
   Decay is 2 points a turn, halved for an IMMENSE conqueror, never below 1 (11872-11940). Conquering a quarter of
   all majors forces SEVERE, a third CRITICAL (11966). A ~100-city conqueror is CRITICAL to everyone, and opinion
   has no cap (14143).
2. **But strength is judged one against one, and fear wins.** A conqueror's army is compared with the observer's
   alone, plus only allies already at war with it or bound by treaty (`GetWarAllies`, 1311). Civs that hate it
   just as much count for nothing until they're already fighting. Against an IMMENSE civ the approach scores add
   `AFRAID += bias*8`, `WAR -= bias*6` (16591), and the same again for economic strength (16680). CRITICAL
   warmonger adds only `WAR += bias*Hate*2` (16527), and also adds AFRAID. Typical result: WAR ≈ 0, AFRAID ≈ 11,000.
3. **AFRAID shuts every door.** An AFRAID or IMMENSE-rated civ is not a potential war target (24050-24058, 23739);
   the coop-war score is then 0 (42307), and the coop-war asker skips GUARDED and AFRAID targets anyway (42285).
   Sanctions count warmonger threat only when the approach is worse than GUARDED (`CvVotingClasses.cpp:12538`), and
   an AFRAID AI's denounce weight stays under the threshold (44945).
4. **Coalitions need friends.** Coop wars are only asked of civs with a Declaration of Friendship
   (`DoTestCoopWarDesire`, 42242), one at a time, and the score is shrunk by target value (an IMMENSE target is
   IMPOSSIBLE: ×40%, 42843). Defensive pacts: at most 2 per AI (`CvPlayer.cpp:32475`), only with existing friends,
   and their score has no "common threat" term (`ScoreDefensivePactChoice`, 23153).
5. **Piece by piece.** A losing AI sues for peace at war score about -40 (26158) and gives up a city about to fall
   (`CvDealAI.cpp:5135`). Then 16 turns of peace dampener zero WAR toward it and block pacts and coop wars against
   it (20660, 23051, 42345). Peace is per pair, and the others are AFRAID, so the conqueror always fights one civ
   at a time.
6. **The anti-leader logic comes too late and drops the victims.** "Close to world conquest" needs 50% domination
   progress (3298), and endgame aggression needs the AI to be competing, which a civ that lost its capital isn't
   (9720).

In game-theory terms each AI plays a one-on-one game it rightly loses, and nobody plays the coalition game, which
it would win. The fixes below give each AI the coalition's view: who would win if the civs that fear it all
fought.

## Fog cheats (the AI must use only what a human can see)

Removed for the new AI in 2b.

- `CvTacticalAnalysisMap.cpp:800-811`, `885-886`: unseen enemy units count at 50% strength; tiles
  next to visible ones are treated as visible.
- `CvDangerPlots.cpp:479-483`: unseen units inside known cities and barbarian camps count as danger.
  (The camp check also tested the camp against the barbarians' team, so even camps the AI never saw
  counted.)

Remembering units seen last turn (`CvDangerPlots.cpp:277-297`) is fair and stays.

## Strategy ideas from CivFanatics

From search-result snippets of CivFanatics threads (the forum itself is blocked by this
environment's network policy, so the full posts weren't read). Mostly vanilla BNW, Emperor to
Deity, which applies to CP's rules. They give targets for batch 2 rather than code fixes.

| Idea | Expert practice | Audit items it informs |
|---|---|---|
| Expansion pace | Scout, then settler at capital size 4-5 (~T40); 4 cities by ~T50-60 for tall play, 6-10 by ~T100 for wide play while each city brings a new luxury | 1, 14, 28 |
| Science beeline | Writing, Philosophy, National College by ~T75-90, then Education/Universities; University called the best building | 12, 16, 17 |
| Internal trade routes | Food caravans/cargo ships to the capital and new cities, Granary first | 21 (growth) |
| Spend gold | Don't hoard: buy settlers early (e.g. with 500 gold by T50), libraries, National College | 5, 6, 23 |
| Muster, then strike | 6-8 ranged units plus melee screens before attacking; kill the field army first, then the city | 15, 24-26 |
| Defend smart | Fortified melee in front, ranged behind, walls, a mobile reaction group | 27 |
| Policies | Tradition opener; Rationalism as soon as behind in tech; ideology by play style | policy AI (not yet audited) |

Tricks players use against the AI, each pointing at a weakness: the AI attacks piecemeal from
several sides; it suicides melee into walls and fortified units; it hovers around cities without
attacking; it sits next to citadels; it sends siege and embarked units unescorted; it judges war by
total military score (a few cheap units deter it); it accepts lump-sum-for-per-turn trades and
doesn't punish broken deals; it hoards gold; it leaves workers and settlers unescorted.

## Not a problem

- Turn order in simultaneous multiplayer: all AIs move first, then humans, each turn. That's the
  same alternation as single player, so humans get no special edge from it.
- No multiplayer-only shortcuts in the combat AI (no time limits or reduced search).
