# CP with Animated Leaders: build tools

`CP-Animated-Leaders.zip` is what players get: unzip, double-click `Install.bat`.

## Rebuilding

1. Get a database built with Community Patch: either the pack is installed and the game reached
   the main menu, or CP is enabled in the Mods menu and you clicked Next. Then close the game.
   The builder snapshots that database to `CPModpack\data\cp-snapshot` and builds from the
   snapshot, so later game runs can't spoil the input. `CPModpack\data\baseline` holds the
   unmodded BNW text database the text diff is taken against.
2. Build and package:

   ```
   powershell -ExecutionPolicy Bypass -File CPModpack\Build-CPModpack.ps1 -Dll CPLeaderheads\build\CvGameCore_Expansion2.msvc-coredrive.dll
   powershell -ExecutionPolicy Bypass -File CPModpack\Package-CPModpack.ps1
   ```

   `-Install` on the builder also installs the pack locally. `-LeaderheadsOff` ships the 2D
   diplomacy screens (`MP_LEADERHEADS = 0`) for comparison tests. `-StockRules` ships CP's own
   Prince instead of the even one below. `-ABTest` ships `AI_AB_TEST = 1`, a test pack for AI-only
   games ([`../tools/ab/README.md`](../tools/ab/README.md)); don't play multiplayer with it.

## Even rules on Prince

CP's Prince still favours the AI. The builder rewrites the `HANDICAP_PRINCE` row while exporting,
so on Prince an AI ends up with exactly what a human gets, and prints each change:

| Column | CP | Pack | Why |
|---|---|---|---|
| `AIResearchPercent`, `AIPolicyPercent` | 85, 75 | 100, 100 | AI paid 15% less for techs, 25% less for policies |
| `AIHappinessDefault` | 15 | 9 | a human gets 9 |
| `AIEmpireSizeUnhappinessMod`, `AIPopulationUnhappinessMod` | -10, -10 | 0, 0 | AI had 10% less unhappiness |
| `AIUnitSupplyBase`, `AIUnitSupplyPerCity`, `AIUnitSupplyBonusPercent` | 7, 3, 20 | 5, 2, 0 | a human gets 5 + 2 per city, no bonus |
| `AIImprovementCostPercent`, `AIUnitCostPercent`, `AIUnitUpgradePercent` | 50, 85, 50 | 100, 100, 100 | AI paid less maintenance and half price upgrades |
| `AIBonusVSBarbarians` | 60 | 40 | a human gets 40 |
| `HumanStrengthPerceptionMod` | 20 | 0 | AI rated humans 20% stronger than they are |
| `TacticalSimMax*` (positions, branches, choices) | 256, 4, 4 | Deity's 2560, 5, 5 | how hard the tactical AI searches; not a bonus |

The values aren't hard-coded: an AI gets its own row (`HANDICAP_AI_DEFAULT`) plus the game
difficulty's `AI...` columns, a human gets their own row, so each `AIx` is set to Prince's `x`
minus (or, for cost percentages, divided by) `HANDICAP_AI_DEFAULT`'s `x`, and each `Humanx` (how
the AI treats humans) to its `AIx` twin (how it treats other AIs), or 0. Prince rows of
`HandicapInfo_AI*` tables (AI-only free techs and yields) are left out, and the builder warns if
another `HandicapInfo_*` list differs between Prince and `HANDICAP_AI_DEFAULT`. It also ships
`HUMAN_USES_AI_MECHANICS = 1` (the AI drops its human-only exceptions, such as not spreading
religion to human teammates). Only Prince is changed: on other difficulties the AI keeps CP's bonuses.

## How the pack works

Same layout as CP's own Modpack Maker (`(5) Modpack Maker for VP` and `CvGame::CreateMPMP`):

| Path | Contents |
|---|---|
| `Override\CIV5Units.xml` | The whole CP gameplay database: schema and rows |
| `Override\CIV5Units_Mongol.xml` | Text CP adds or changes, as `<Replace>` rows |
| `Override\*.xml` (empty) | Stops the base game database files loading |
| `Mods\(1) Community Patch\` | CP's Lua, UI, art, audio, and the patched DLL |
| `UI\InGame.lua` | CP's InGame.lua with its InGameUIAddins listed at the modpack marker, plus a per-frame call to `Game.UpdateCoreInLeaderScene` on the leader screen |
| `MP_CPLeaderheads.Civ5Pkg` | Priority 300, Brave New World's SteamApp/Key |

Things learned the hard way:

- Tables that exist before XML loads (`ArtDefine_*`, `Audio_*`, `Map_Folders`, `Map_Sizes`, `Maps`)
  get rows only. A `<Table>` for them makes the loader drop the whole file.
- The pack can't load saves made without it: the host step feeds the save's PreGame to CP's DLL.
- The CI clang build fails to load (LoadLibrary error 1114). Ship the MSVC build.

## Known behaviour

The base game pauses its game core on the leader screen. The pack keeps it running in MP: the
`UI\InGame.lua` snippet drives it each frame while the game state is 12 (the leader view), at the
same 9-10 updates a second as the map, measured with `probe\MPLeaderTick.lua`. See
`..\CPLeaderheads\README.md` for the DLL side.

Lua.log shows `Error loading VPUI_loader.lua` from CP's tooltip script (that file is part of
Vox Populi's UI, which this pack doesn't include); it is harmless.
