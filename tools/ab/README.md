# AI A/B tests

How we check that a change to the AI actually makes it stronger. A test game is an AI-only single
player game where half the civs run the changed AI code ("new") and half run Community Patch's
original ("cp"). Run enough games, and if "new" keeps finishing ahead, the change is real.

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

`Summarize-ABTest.ps1` with no arguments reports each results file separately. Send its output (or
the CSV files) back after a handful of games.
