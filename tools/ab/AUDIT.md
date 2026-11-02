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

## Batch 2: bigger behaviour changes, need tuning

| # | Area | Where | Problem | Status |
|---|---|---|---|---|
| 12 | Buildings | `CvCityStrategyAI.cpp:4226`, `4253` | Flat yields scored as % increase, % buildings scored as absolute yield: University/Bank/Factory lose 5-20x to Monument/Shrine/Temple | Confirmed |
| 13 | Buildings | `CvBuildingProductionAI.cpp:1329` | Under 3 military units per city, every building's value is cut 75% even in peacetime | Confirmed |
| 14 | Expansion | `CvEconomicAI.cpp:5071` | Expansion stops after 3 cities if any stronger civ is a neighbour | Confirmed |
| 15 | War | `CvMilitaryAI.cpp:2388` | Effectively one attack at a time across all enemies | Confirmed |
| 16 | Research | `CvTechAI.cpp:104-110`, `391` | Civ/locale/victory-plan priorities are added once per flavor (~30-45 times), swamping personality; cost reweighting then favours the cheapest tech, so research goes broad instead of beelining | Confirmed |
| 17 | Research | `CvTechClasses.cpp:1245` | Victory plan barely affects research; no planned beelines | Confirmed |
| 18 | Combat | `CvTacticalAI.cpp:8250`, `7951` | Damage taken weighted ~20x less than damage dealt; units end turns where visible enemies can deal 2x their HP | Likely |
| 19 | Combat | `CvTacticalAI.cpp:12366` | Units starting the turn in danger get a huge starting penalty before safe plots are known, so their moves all tie | Likely |
| 20 | Combat | `CvTacticalAI.cpp:39`, `12408` | Search goes greedy after 3 levels, so the 2560-position Deity budget can't be reached (~600-800) | Likely |
| 21 | Cities | `CvCityCitizens.cpp:1933` | Specialised cities (half of them, plus all cities in a gold deficit) aim for +2 food and stagnate | Likely |
| 22 | Buildings | `CvCityStrategyAI.cpp:4281` | Culture building value multiplied by 2-3 once per rival civ (up to x16) | Likely |
| 23 | Gold | `CvCityStrategyAI.cpp:1367` | Gold purchase weights a barely started item up to 100x | Likely |
| 24 | War | `CvMilitaryAI.cpp:902` | "Preferred target" cut-off measured against all civs' cities, so a walled human may never be attacked | Likely |
| 25 | War | `CvCityStrategyAI.cpp:912` | Only the muster city builds units for an attack | Likely |
| 26 | War | `CvAIOperation.cpp:868` | Armies keep marching at under half strength, never reinforced | Likely |
| 27 | War | `CvMilitaryAI.cpp:2335` | No defensive response when one city is attacked but the war overall looks fine | Likely |
| 28 | Expansion | `CvAIOperation.cpp:1795`, `CvPlayer.cpp:47813` | Settlers wait for escorts in safe land and walk to far sites, re-picking targets every turn | Likely |

## Fog cheats to remove (the AI must use only what a human can see)

- `CvTacticalAnalysisMap.cpp:800-811`, `885-886`: unseen enemy units count at 50% strength; tiles
  next to visible ones are treated as visible.
- `CvDangerPlots.cpp:479-483`: unseen units inside known cities and barbarian camps count as danger.

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
