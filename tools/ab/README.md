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
- Every 10 turns, and when someone wins, each civ's standing is appended to
  `Documents\My Games\Sid Meier's Civilization 5\AIABTest.csv`. The file is never cleared, so games
  from many sessions collect there.
- `Summarize-ABTest.ps1` reads that file and reports how often each group finished ahead.

## Running test games

1. Download the **MSVC** DLL from the fork's latest Build run on the branch above, and build a test
   pack with it:

   ```
   powershell -ExecutionPolicy Bypass -File CPModpack\Build-CPModpack.ps1 -Dll <path to the DLL> -ABTest -Install
   ```

   Don't play multiplayer with the test pack. Reinstall the normal pack (same command without
   `-ABTest`) before playing with friends.
2. Start a **single player** game: Prince, an even number of civs (8 on a Standard map is good),
   Quick game speed so games finish sooner, and Quick Combat and Quick Movement on.
3. On turn 1, press **Ctrl+Shift+O** (Community Patch's observer mode). Every civ, yours included,
   is now played by the AI. Leave it running; it goes on until someone wins.
4. You can stop any time (Ctrl+Shift+O again, or quit). Standings already logged stay in the file.
   Games that stop before turn 100 are left out of the summary.
5. After a few games:

   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Summarize-ABTest.ps1
   ```

## First run: an A/A test

No AI code is gated on `UsesNewAI()` yet, so both groups run the same AI. Their results should come
out about even, and how far apart they land shows how much luck there is, which tells us how many
games a real change needs. Send the summary output (or the CSV) back after a handful of games.
