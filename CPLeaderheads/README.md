# MP Leaderheads for Community Patch 5.4.8 (v151)

Shows the animated 3D leader scenes for AI diplomacy in network multiplayer.

`patched/` holds the changed files and `original/` holds the Release-5.4.8 versions they
came from. To build, copy each patched file over its counterpart in a Release-5.4.8 checkout of
https://github.com/LoneGazebo/Community-Patch-DLL:

| File | Path in the repo |
|---|---|
| CvDllPreGame.cpp | `CvGameCoreDLL_Expansion2/CvDllPreGame.cpp` |
| CvPlayer.cpp | `CvGameCoreDLL_Expansion2/CvPlayer.cpp` |
| CustomMods.h | `CvGameCoreDLL_Expansion2/CustomMods.h` |
| CustomMods.cpp | `CvGameCoreDLL_Expansion2/CustomMods.cpp` |
| NewCustomModOptions.xml | `(1) Community Patch/Database Changes/NewCustomModOptions.xml` |

## How it works

In network MP the EXE's leaderhead system asks the DLL's `ICvPreGame1::isNetworkMultiplayerGame`
(vtable slot 53) whether to run, and bails if the answer is yes. Four call sites matter:

| Call site | Function (DX11) | Effect when told "not MP" |
|---|---|---|
| Enter leader view | `GameplayDiplomacyAILeaderMessage` handler `0x51B1E0` | switches to `CIV5_GS_LEADER_HEAD_VIEW` |
| Leave leader view | `RequestLeaveLeader` handler `0x5DB0E0` | restores the previous game state |
| Preload scene | `NotifyAILeaderInGame` handler `0x5985B0` | loads the leader's scene file |
| Activate scene | leader message handler `0x6EC820` | makes the scene current and plays its animation |

`CvDllPreGame::isNetworkMultiplayerGame` now answers `false` when called from exactly those
four return addresses (tables for the DX11, DX9 and Tablet EXEs) and `MP_LEADERHEADS` is on.
Every other caller gets the real answer. Gameplay code reads `CvPreGame` directly and never goes
through this interface, so synced state is untouched.

The EXE only preloads AI leader scenes when a single player game starts, so `CvPlayer::setTurnActive`
calls `gDLL->NotifyAILeadersInGame()` at the start of the local player's turn in network MP.
Scenes that are already loaded are skipped.

Turn it off without rebuilding by setting `MP_LEADERHEADS` to 0 in `NewCustomModOptions.xml`.

## Call site tables

Return addresses at the preferred image base 0x400000 (each follows a `call edx` / `call eax`):

| EXE | Enter | Leave | Preload | Activate |
|---|---|---|---|---|
| CivilizationV_DX11.exe | 0x51B2CC | 0x5DB1AB | 0x5985D1 | 0x6EC841 |
| CivilizationV.exe (DX9) | 0x7B24AC | 0x428ECB | 0x460781 | 0x49D3E1 |
| CivilizationV_Tablet.exe | 0x6CE90C | 0x79977B | 0x4F15C1 | 0x72D6E1 |
