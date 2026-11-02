# AI A/B tests

How we check that a change to the AI actually makes it stronger. A test game is an AI-only single
player game where half the civs run the changed AI code ("new") and half run Community Patch's
original ("cp"). Run enough games, and if "new" keeps finishing ahead, the change is real.

Results so far, build by build, are in [RESULTS.md](RESULTS.md); the raw CSVs are in [results/](results/).

## The A/B/C ladder

| Rung | What | Fork (`treezeegaga/Community-Patch-DLL`) |
|---|---|---|
| **A** | Community Patch's original AI | code outside `UsesNewAI()` |
| **B** | batch 2p, frozen 2026-11-02 after beating A 5-0 on strength (52.4% ± 0.7, p 1%) | commit `24cc575`, branch `claude/sleepy-hopper-x77moh` |
| **C** | candidate changes, tested against B | branch `claude/ab-c1` (branched from `24cc575`) |

- **Stage 1** builds (branch `claude/sleepy-hopper-x77moh`) split the civs into `new` and `cp`.
- **Stage 2** builds (branch `claude/ab-c1`, `kABTestVersusBase = true` in CvPlayer.cpp) give every civ
  B: `UsesNewAI()` is true for all.
  - Half of them also run the C changes, gated on `UsesCandidateAI()`. Their results file labels the
    groups `c` and `b`.
  - The split is warmonger-balanced, so c gets a warmonger whenever the game has one; RESULTS.md has
    the details.
- **When a C build passes the bar**, it becomes the new B and the next candidates are tested against it.
- **One flag per idea** (from build `c7c_flags`): every candidate change sits behind its own flag,
  `UsesCandidateAI(FIX_xx)` in the DLL. `AIABTest.ini` in `Documents\My Games\Sid Meier's Civilization 5`
  picks which flags group c runs (`Fixes =`), and which ones are screened instead (`Screen =`: each on for a
  random half of the AI civs). With no file c runs the bundle, the same AI as c7c. See
  [AIABTest.ini.example](AIABTest.ini.example); RESULTS.md lists the flags.
- **Every row records its settings** (from build `c7c_settings`): flip, the flags the civ ran, the screened
  flags, map, map options, ruins, barbarians, pace, difficulty, world size, stop turn and the DLL build.
  The summary lists each file's setups and flag configurations and warns when a file mixes them.

**The verdict is the strength share:** the test group's share of the game's techs, population, land,
military and cities, averaged, at the last logged turn (50% = even).
- Civ's score is shown alongside but not used, because religion and wonders inflate it.
- A build passes when a one-sided t-test on its per-game strength shares gives p < 5%. That's roughly
  9+ wins in 10 games, or a steady edge of about 52% over 5.
- The summary also prints a no-military share, for builds that skip units on purpose.

## How it works

- DLL: `treezeegaga/Community-Patch-DLL`, branch `claude/sleepy-hopper-x77moh`. The custom mod
  option `AI_AB_TEST` (off by default) turns a game into a test game. `CvPlayer::UsesNewAI()` says
  which group a major civ is in: player ID plus map seed, odd = new. Over many games each slot plays
  both sides. Outside a test game every civ runs the new code, so the normal pack is unaffected.
- Every AI change is written as `if (UsesNewAI()) { new } else { CP's code }`.
- Every 10 turns, and when someone wins, each civ's standing is appended to a file in
  `Documents\My Games\Sid Meier's Civilization 5`. Each build writes its own file, so results never
  mix: `AIABTest.csv` from the first build (no AI changes), `AIABTest_batch1.csv` from batch 1, and so
  on. Files are never cleared, so games from many sessions collect there.
- `Summarize-ABTest.ps1` reads that file and reports how often each group finished ahead.

## Running test games

One command does everything: updates this repo, shows the results so far, downloads the newest test
DLL (the fork's CI publishes it as the `ab-latest` release), builds and installs the test pack, and
starts Civ V:

```
powershell -ExecutionPolicy Bypass -File tools\ab\Run-ABTest.ps1
```

Then in Civ V: Single Player > Set Up Game, **Prince**, Standard map with **8 civs**, **Quick** pace,
and Quick Combat and Quick Movement under Advanced Setup (Civ V remembers these next time). Start the
game and leave it running. Observer mode turns itself on at the start (the same as Ctrl+Shift+O), so
the AI plays every civ until someone wins. Standings are saved every 10 turns, so quitting early is
fine; games shorter than 100 turns aren't counted.

- Results so far: `tools\ab\Run-ABTest.ps1 -Summary`
- **Before playing multiplayer**: `tools\ab\Run-ABTest.ps1 -Restore` puts the normal pack back.
  Never play multiplayer with the test pack.
- A specific build instead of the newest: `-Release ab-<commit>` (e.g. `ab-80746d8`).

### Unattended games

`tools\ab\Run-Games.ps1` plays test games back to back with nobody at the keyboard: it starts Civ V
windowed, clicks through the setup (ticking Quick Combat and Quick Movement, which Civ doesn't remember),
moves the window to the left half of the screen, stops each game at turn 150 (`-StopTurn`) and logs one
line per game to `tools\ab\Run-Games.log`. Create `tools\ab\STOP` to stop after the current game. It needs
the test pack installed (`Run-ABTest.ps1 -NoLaunch`), windowed mode in `GraphicsSettingsDX9.ini`
(`FullScreen = 0`, `WindowResX = 1914`, `WindowResY = 2034`) and the setup screen already on Prince,
Standard, Quick and 8 civs on separate teams. Its click positions are for a 3840x2160 screen at 150%.

**Paired games** (C builds from fork commit `7097d49` on): by default `Run-Games.ps1` plays games in pairs. The
second game of a pair replays the first one's map seed, civs, leaders and city-states with the groups swapped
(`Flip = 1`), so luck of the map and the draw cancels out within the pair. A flipped game's GameId ends in `F`.
The runner writes `AIABTest.ini` before every game from `-Fixes` (default `bundle`) and `-Screen`, and logs
whether the second game's start matched the first ("replay matches the first game" or "REPLAY DIFFERS"). A
STOP file takes effect after the current pair. `-Unpaired` plays single games; `-NoSettings` leaves
`AIABTest.ini` alone.

With `LoggingEnabled = 1` and `AILog = 1` in `config.ini`, test games write Civ's AI logs, and
`tools\ab\Digest-ABLogs.ps1` boils them down to a few lines per civ: early builds, settlers ordered,
found-city operations and idle settlers.

Doing it by hand: download the DLL from the release (or the **MSVC Release** artifact of a Build run on
the fork branch), run `CPModpack\Build-CPModpack.ps1 -Dll <dll> -ABTest -Install`, start a game as
above, and run `Summarize-ABTest.ps1` afterwards.

## Which build to test

- **First build** (fork commit `7aecbfe`): no AI code gated on `UsesNewAI()`, so both groups run the
  same AI. Their results should come out about even, and how far apart they land shows how much is
  luck, which tells us how many games a real change needs.
- **Batch 1** (fork commit `80746d8`): the 11 fixes listed in [AUDIT.md](AUDIT.md).
- **Batch 2e** (fork commit `60b57a0`): batch 1, plus the opening book, the fog cheats removed, and
  the batch 2 fixes marked "2b", "2c" (settlers), "2d" (army production) and "2e" (combat) in
  [AUDIT.md](AUDIT.md). Its results file, `AIABTest_batch2e.csv`, also records when each civ founded its 2nd, 3rd and 4th cities,
  whether it has the National College, and which opening plan it followed; the summary shows these
  per group.

Fork commits `5539cfb` (2a) and `8eaf65e` (2b) don't compile (a missing include, fixed in 2c), so
there are no builds for them. 2c (`345b615`) and 2d (`25c26d8`) were replaced by later batches before their builds started. 2e
searches more positions in battles of up to 9 units, so if AI turns feel slower during wars, say so.

- **Batches 2f–2p** (stage 1, each on top of the last). The full table is in [RESULTS.md](RESULTS.md).
  - **2f–2h:** settler fixes.
  - **2i (`fb324ce`):** the root-cause fix. Found-city operations had needed a spare military unit to
    start, so new-AI civs sat on one city.
  - **2j, 2k:** saving gold for settlers.
  - **2l:** an early shrine.
  - **2m, 2n:** unescorted settlers; settlers wait only for imminent growth.
  - **2o:** the book gives way to wonders.
  - **2p (`24cc575`):** a warrior before the first settler. **It passed (5-0, p 1%) and is B.**
- **Batches 2q–2u** were pushed to the same branch after 2p, but were never validated against CP. They
  became c1's candidate bundle instead.
- **C builds c1–c7c** (fork branch `claude/ab-c1`) are listed in [RESULTS.md](RESULTS.md).
  - **Best so far: c4 (`ea22df3`)**, 5-1 at 51.6% ± 1.1, p 10%. It is not frozen.
  - **Newest: c7c (`2e9fad1`)**, 52.9% in its 1 game.

### Installing a C build

The fork's CI only publishes releases from `claude/sleepy-hopper-x77moh`, so `Run-ABTest.ps1` can't fetch
C builds. Instead:

1. Push the change to `claude/ab-c1`, behind its own flag. Set the batch name (`AI_AB_TEST_BATCH` in
   CvGame.cpp, e.g. `"c7c_flags"`) when the build changes what the AI does with the same settings, so its
   games go to their own `AIABTest_<batch>.csv`. A new flag that is off by default doesn't need a new name.
2. Start the build:
   ```
   gh workflow run build_vp.yml --repo treezeegaga/Community-Patch-DLL --ref claude/ab-c1
   ```
3. When the run finishes, download its DLL:
   ```
   gh run download <run id> --repo treezeegaga/Community-Patch-DLL --pattern "VP_MSVC_Release*" -D <empty dir>
   ```
4. Check that the artifact's name ends in the commit you pushed, e.g.
   `VP_MSVC_Release_24cc575-15-g2e9fad187` for `2e9fad1`. Runs queue behind each other, and an older run
   can finish first.
5. Install it:
   ```
   powershell -ExecutionPolicy Bypass -File CPModpack\Build-CPModpack.ps1 -Dll <dir>\...\CvGameCore_Expansion2.dll -ABTest -Install
   ```
6. Put the `AIABTest.ini` that RESULTS.md asks for in My Games (or none, for the bundle). Play games with
   `Run-Games.ps1`, and read results with `Run-ABTest.ps1 -Summary`. For B-vs-C files,
   the summary's "new" column is c and its "cp" column is b.

`gh run cancel` sometimes has no effect, and a hung run blocks later runs on the branch. Use
`gh api -X POST repos/treezeegaga/Community-Patch-DLL/actions/runs/<id>/force-cancel`.

`Summarize-ABTest.ps1` with no arguments reports each results file separately. Send its output (or
the CSV files) back after a handful of games.
