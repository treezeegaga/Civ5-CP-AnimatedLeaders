# MP Leaderheads for Community Patch 5.4.8 (v151)

Shows the animated 3D leader scenes for AI diplomacy in network multiplayer.

`patched/` holds the changed files and `original/` holds the Release-5.4.8 versions they
came from. To build, copy each patched file over its counterpart in a Release-5.4.8 checkout of
https://github.com/LoneGazebo/Community-Patch-DLL:

| File | Path in the repo |
|---|---|
| CvDllPreGame.cpp | `CvGameCoreDLL_Expansion2/CvDllPreGame.cpp` |
| CvPlayer.cpp | `CvGameCoreDLL_Expansion2/CvPlayer.cpp` |
| CvLuaGame.cpp | `CvGameCoreDLL_Expansion2/Lua/CvLuaGame.cpp` |
| CvLuaGame.h | `CvGameCoreDLL_Expansion2/Lua/CvLuaGame.h` |
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

## Keeping the game running

In single player the leader view pauses the game on purpose. Two things in the EXE do that, and
in network MP both would stop the local game core while the other players carry on:

1. **The pause counter.** Right after the enter call site the EXE increments a global counter
   (`InterlockedIncrement`); the "Game Core" task skips its update while it is nonzero, and the
   leave path only decrements it if it is nonzero. At the enter site the DLL sets it to -1 so the
   increment lands on 0, and sets it to 0 at the activate and leave sites.
2. **Who runs the core.** Only `GameViewState::Update` (the map view, `0x7253E0` in DX11) schedules
   a game core update: it adds the frame time to a global timer and, once the timer passes
   `vtbl[0x198]()`, calls the run function unless `vtbl[0x3A4]()` says it is blocked. The leader
   view state never does. The DLL exposes `Game.UpdateCoreInLeaderScene(timeIncrement)`, which does
   the same thing on the map view object (`[[app global]+0x1460]`) while a leader scene that the
   DLL let in is up. The pack's `UI\InGame.lua` calls it from `Events.LocalMachineAppUpdate`
   while `UI.GetCurrentGameState()` is 12 (the leader view) in network MP.

Tested on DX9 in a LAN game: 9-10 game core updates a second on the leader screen, the same as on
the map.

## Address tables

All addresses are at the preferred image base 0x400000; the DLL rebases them on the running EXE.
Call sites are return addresses (each follows a `call edx` / `call eax`):

| EXE | Enter | Leave | Preload | Activate |
|---|---|---|---|---|
| CivilizationV_DX11.exe | 0x51B2CC | 0x5DB1AB | 0x5985D1 | 0x6EC841 |
| CivilizationV.exe (DX9) | 0x7B24AC | 0x428ECB | 0x460781 | 0x49D3E1 |
| CivilizationV_Tablet.exe | 0x6CE90C | 0x79977B | 0x4F15C1 | 0x72D6E1 |

| EXE | Pause counter | App global | Game core timer | Run game core |
|---|---|---|---|---|
| CivilizationV_DX11.exe | 0x2DE044C | 0xCC8E74 | 0xCCF91C | 0x53AF10 |
| CivilizationV.exe (DX9) | 0x2DD024C | 0xCB8CF4 | 0xCBF764 | 0x535B30 |
| CivilizationV_Tablet.exe | 0x2DE2434 | 0xCCA8F0 | 0xCD139C | 0x5DDC50 |

The run function is `thiscall` with one bool argument; the DLL calls it as `__fastcall` with a
dummy `edx`.
