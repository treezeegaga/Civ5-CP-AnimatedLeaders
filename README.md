# Civ V MP Leaderheads

Animated 3D leader screens for AI diplomacy in Civilization V network multiplayer, on top of
Community Patch 5.4.8, shipped as a one-click mod pack.

## Download

**[CP-MP-Leaderheads.zip](https://github.com/treezeegaga/Civ5-MP-Leaderheads/releases/latest/download/CP-MP-Leaderheads.zip)**
(latest release). Needs Civilization V with all expansions and DLC. Unzip, double-click
`Install.bat`, then play multiplayer without enabling any mods. Everyone in a game needs the same
pack version, which the installer shows.

## Credits and license

[Community Patch](https://github.com/LoneGazebo/Community-Patch-DLL) is by the Community Patch
Project team. This project modifies its game DLL (source:
[`treezeegaga/Community-Patch-DLL`, branch `mp-leaderheads`](https://github.com/treezeegaga/Community-Patch-DLL/tree/mp-leaderheads))
and packs it the way CP's own Modpack Maker does (after Gedemon's MP Modpacks Maker). Released
under the GNU GPL v3 like Community Patch; free, and never to be sold.

## Layout

| Folder | What |
|---|---|
| `CPLeaderheads/` | The Community Patch DLL change: `patched/` vs `original/` source, `build/` DLLs (+ PDB), `backup/` stock CP files, README with the EXE addresses |
| `CPModpack/` | Mod pack builder, packager, one-click installer template, `CP-MP-Leaderheads.zip` for players |
| `CPModpack/data/` | DB snapshot of a CP game and the unmodded text baseline the builder needs |
| `CPModpack/probe/` | Lua probe that logs game core updates per second (testing only) |
| `MPLeaderScreens/` | Older 2D fallback (leader art behind the diplomacy UI), pseudo-DLC; not used |
| `MPLeaderProbe/`, `MPLeaderDiag/`, `MPModsButton/` | Experiments from the investigation; not used |
| `tools/re/` | Reverse-engineering helpers: `dis.ps1` (Iced disassembler), `ctx.ps1`, `sigscan.ps1`, `sym.ps1` (PDB symbols) |

Not in git (see `.gitignore`): `CPModpack/data/` (game databases), `CPLeaderheads/build/` and
`backup/` (DLL binaries), the zip, and `tools/re/iced/` (the [Iced](https://www.nuget.org/packages/Iced/1.21.0)
NuGet package; put `lib/netstandard2.0/Iced.dll` there to use the scripts).

DLL source lives on GitHub: `treezeegaga/Community-Patch-DLL`, branch `mp-leaderheads`
(patch `f9371ea`, CI fix `836b07c`). Builds run there through `build_vp.yml`
(`gh workflow run build_vp.yml --ref mp-leaderheads`). Ship the **MSVC** artifact; the clang one
fails to load.

## Status

- Working: 3D leaders in network MP (tested solo on LAN), one-click zip build `9B2822AC`.
- Known: while a 3D leader screen is open, the local game core stops updating (0/s in game state
  12; CP's 2D screen keeps ~9/s). Network messages are still processed. A fix that keeps the core
  running is in progress: diagnostic commits `8ba5dc8`/`4bfbde0` log who calls `CvDllGame::Update`
  and on which thread (revert them before release).
- Not yet done: a test with a second human player.
