# Community Patch MP pack (3D leaders): build tools

`CP-MP-Leaderheads.zip` is what players get: unzip, double-click `Install.bat`.

## Rebuilding

1. Get a database built with Community Patch: either the pack is installed and the game reached
   the main menu, or CP is enabled in the Mods menu and you clicked Next. Then close the game.
   The builder snapshots that database to `CPModpack\data\cp-snapshot` and builds from the
   snapshot, so later game runs can't spoil the input. `CPModpack\data\baseline` holds the
   unmodded BNW text database the text diff is taken against.
2. Build and package:

   ```
   powershell -ExecutionPolicy Bypass -File CPModpack\Build-CPModpack.ps1 -Dll CPLeaderheads\build\CvGameCore_Expansion2.msvc-final.dll
   powershell -ExecutionPolicy Bypass -File CPModpack\Package-CPModpack.ps1
   ```

   `-Install` on the builder also installs the pack locally. `-LeaderheadsOff` ships the 2D
   diplomacy screens (`MP_LEADERHEADS = 0`) for comparison tests.

## How the pack works

Same layout as CP's own Modpack Maker (`(5) Modpack Maker for VP` and `CvGame::CreateMPMP`):

| Path | Contents |
|---|---|
| `Override\CIV5Units.xml` | The whole CP gameplay database: schema and rows |
| `Override\CIV5Units_Mongol.xml` | Text CP adds or changes, as `<Replace>` rows |
| `Override\*.xml` (empty) | Stops the base game database files loading |
| `Mods\(1) Community Patch\` | CP's Lua, UI, art, audio, and the patched DLL |
| `UI\InGame.lua` | CP's InGame.lua with its InGameUIAddins listed at the modpack marker |
| `MP_CPLeaderheads.Civ5Pkg` | Priority 300, Brave New World's SteamApp/Key |

Things learned the hard way:

- Tables that exist before XML loads (`ArtDefine_*`, `Audio_*`, `Map_Folders`, `Map_Sizes`, `Maps`)
  get rows only. A `<Table>` for them makes the loader drop the whole file.
- The pack can't load saves made without it: the host step feeds the save's PreGame to CP's DLL.
- The CI clang build fails to load (LoadLibrary error 1114). Ship the MSVC build.

## Known behaviour

While a 3D leader screen is open in MP, the local game core stops updating (0 updates/s in game
state 12, measured with `probe\MPLeaderTick.lua`) and catches up afterwards. Other players keep
playing. CP's 2D screen keeps updating (~9/s). See `..\CPLeaderheads\README.md` for the DLL side.
