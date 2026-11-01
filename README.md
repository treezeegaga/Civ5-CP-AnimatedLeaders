# CP with Animated Leaders

Animated 3D leader screens for AI diplomacy in Civilization V network multiplayer, on top of
Community Patch 5.4.8, shipped as a one-click mod pack.

## Download

**[CP-Animated-Leaders.zip](https://github.com/treezeegaga/Civ5-CP-AnimatedLeaders/releases/latest/download/CP-Animated-Leaders.zip)**
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
| `CPModpack/` | Mod pack builder, packager, one-click installer template, `CP-Animated-Leaders.zip` for players |
| `CPModpack/data/` | DB snapshot of a CP game and the unmodded text baseline the builder needs |
| `CPModpack/probe/` | Lua probe that logs game core updates per second (testing only) |
| `MPLeaderScreens/` | Older 2D fallback (leader art behind the diplomacy UI), pseudo-DLC; not used |
| `MPLeaderProbe/`, `MPLeaderDiag/`, `MPModsButton/` | Experiments from the investigation; not used |
| `tools/re/` | Reverse-engineering helpers: `dis.ps1` (Iced disassembler), `ctx.ps1`, `sigscan.ps1`, `sym.ps1` (PDB symbols), `xref.ps1` (references and calls to an address), `dllfn.ps1` (disassemble a DLL function by name from its PDB) |

Not in git (see `.gitignore`): `CPModpack/data/` (game databases), `CPLeaderheads/build/` and
`backup/` (DLL binaries), the zip, and `tools/re/iced/` (the [Iced](https://www.nuget.org/packages/Iced/1.21.0)
NuGet package; put `lib/netstandard2.0/Iced.dll` there to use the scripts).

DLL source lives on GitHub: `treezeegaga/Community-Patch-DLL`, branch `mp-leaderheads`
(patch `f9371ea`, CI fix `836b07c`, game core fix `bfda6f9`). Builds run there through `build_vp.yml`
(`gh workflow run build_vp.yml --ref mp-leaderheads`). Ship the **MSVC** artifact; the clang one
fails to load.

## Status

- Working: 3D leaders in network MP, and the game keeps running while a leader screen is open
  (9-10 game core updates a second, same as the map). Tested solo on LAN with the DX9 EXE;
  one-click zip build `5F2D34BF`.
- Not yet done: a test with a second human player; the DX11 and Tablet EXEs (their addresses
  were found by signature).
