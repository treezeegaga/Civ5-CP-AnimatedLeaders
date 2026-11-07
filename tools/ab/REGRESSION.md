# Regression cases

Replay with `Run-Games.ps1 -Regression <ids> -StopTurn 100 -SaveLogs` and the block's own flags. Each case passes when the
"should" column happens. Add a line for every failure a fix targets.

| GameId | Block / settings | Aggressor vs target | Failure seen | Should (after the fix) | Fix |
|---|---|---|---|---|---|
| 18BE1E3E18BE1E3E | bullygreedy (greedy setup) | Greece vs La Venta (walled city-state) | declared T81, 0 melee city attacks in 70 turns | builds ranged/siege first, then damages the city; a capture | ae8e9ae / a990c84 |
| 186D5858186D5858 | bullygreedy (trial28) | Aztec vs Sofia (city-state) | army handed back 6 tiles out, Sofia 250/250 to T100 | the army reaches Sofia and damages it | 5f5334e / a990c84 |
| 1B22084A1B22084A | bullygreedy | Persia, target Yerevan | strike never left PREP in 150 turns | leaves PREP once the plan's army is out | 9367095 |
| 1A5C4C1E1A5C4C1E | bullyabort (normal civs) | Persia vs Vancouver (defence 27) | the attack recruited 3-5 of 10 units, timed out 9-10 tiles out | the whole field army marches ("StrikeAllIn:" lines), the city takes damage | a990c84 |
| 1B02BA851B02BA85 | bullygreedy | Assyria vs the Netherlands (Amsterdam) | the attack stalled at home, timed out T135 | the attack reaches Amsterdam | a990c84 (partly) |
