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
