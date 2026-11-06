# Playing a test game by hand: a human against the greedy civs (PC 1)

Goal (the user's): play 100 turns as the aggressor on the map of bully-vs-greedy game `106F8550` ("dominate some
greedy noobs"), so we can watch how a human takes cities. Written from the test DLL's source (claude/ab-c1, CvGame.cpp
and CvPlayer.cpp) and the results of 106F8550, 2026-11-05. Nothing here has been run yet; "UNVERIFIED" marks guesses.

## Short answers

| Question | Answer |
|---|---|
| Does Run-Games need a `-Human` switch? | **No.** Don't use Run-Games.ps1 at all: it clicks through setup and kills Civ at the stop turn. Install with `Run-ABTest.ps1`, hand-write `AIABTest.ini`, and set the game up by hand in Civ's own screens. |
| Which build? | **ab-850e142**, the build 106F8550 was played on (results Build column: `No-Tag 850e142 Clean`). |
| How to confirm the greedy flags? | The results CSV's `Fixes` column, per row (see "Checking" below). |
| Anything that blocks it? | One thing, and it is not fatal: at turn 0 the test DLL hands the human's civ to the AI (observer mode). The user must press **Ctrl+Shift+O** at once to take it back. Details under "Blocker". A second thing to decide: roles skip humans (see "Roles"). |

## What the DLL does with a human slot (from the source)

- **The ini is read once at game start** (`ReadABTestSettings`). `MapSeed`, `SyncSeed` and `Player<i> = CIVILIZATION_X LEADER_Y`
  are applied to any slot that is playing: status computer **or taken**, so the human's slot accepts a civ and leader from
  the ini too. City-states (`Player22..`) are applied the same way. A key that doesn't fit is logged in
  `My Games\...\AIABTest_errors.txt`.
- **`Difficulty = HANDICAP_KING` is forced for every human slot** as well, so the setup screen's remembered difficulty
  doesn't matter.
- **Flags never go to the human.** `UsesCandidateAI` returns `!isHuman()` for `Base`, `OthersBase`, `RoleFixes` and the
  rest. The human plays plain Civ V (King, the pack's even rules).
- **`Base` = flags every AI civ runs** (any mode). **`OthersBase`** = flags every AI civ **without a role** runs, bully and
  builders modes only. `RoleFixes` goes to the bully aggressor, first game of a pair only.
- **Roles skip humans** (`GetABTestRoleOfSlot`: `isHuman()` is skipped). In bully mode the aggressor and tall roles are
  picked among the AI civs only, from the map seed and the personalities. If the human takes the Zulu slot, the Zulu is no
  longer a candidate, so a *different* AI civ becomes the bully's aggressor, and the tall civ may change too.
- **The results rows include the human**: the writer skips only never-alive civs, observers and non-major civs, so the human
  gets its own row every 10 turns with Cities, Population, Military, Gold, Techs and so on, like the AIs.

## The map and who is who in 106F8550 (from `AIABTest_bullygreedy14@TREEDESKTOP.csv`, T150)

| Slot | Civ | Role in 106F8550 | Cities |
|---|---|---|---|
| 0 | Aztec | none (greedy flags) | 3 |
| 1 | Zulu | **aggressor** (RoleFixes) | 8 |
| 2 | Brazil | none | 7 |
| 3 | Morocco | **tall** | 4 |
| 4 | China | none | 4 |
| 5 | Maya | none | 6 |
| 6 | Persia | none | 2 |
| 7 | Russia | none | 6 |

King, Pangaea, Standard size, 8 civs, **Quick** pace (the whole test pack plays Quick, so the results stay comparable: pick
Quick on the setup screen, not "Standard speed", unless the lead says otherwise). MapSeed = SyncSeed = 275744080.
The seeds, civs, leaders and city-states are in `results/replay/106F8550106F8550.ini` (copied from PC 2).

## Which slot is the human?

The human is slot 0 (Civ V's single-player setup puts "you" in player 0; UNVERIFIED but it matches every roster line
so far, where the observer-mode civ is player 0). So:

- **Option A (closest to the replay): the user plays slot 0 = the Aztec** (leader Montezuma). Same start position, same
  neighbours; the Zulu AI keeps slot 1. The user is then "the Aztec", not the Zulu.
- **Option B: the user plays the Zulu**: write `Player0 = CIVILIZATION_ZULU LEADER_SHAKA` and `Player1 = CIVILIZATION_AZTEC LEADER_MONTEZUMA`.
  Start plots follow the slot, not the civ, as far as I know (UNVERIFIED: Civ V assigns regions to slot order, with
  start biases for a few civs), so the human Zulu would start where the Aztec started, and the AI Aztec where the Zulu
  started. Check at T10: slot 0's row (Cities, Population, Score, Techs) should equal the original Aztec row, whichever civ
  the human plays.

Ask the user which they want. Option A is the safer replay; B gives the Zulu name but not the Zulu's position.

## Roles

Pick one:

1. **No roles (recommended): `Mode =` empty (split) and `Base = GreedyFewUnits, GreedyNoWalls, GreedyNoUpgrades, GreedyBuilds`.**
   Every AI civ plays greedy, nobody is aggressor or tall, and the results show it per civ. Simplest and clearest.
2. **Keep bully mode** (`Mode = bully`, `OthersBase = <the four greedy flags>`, `RoleFixes =` empty, `HeadStart... = 0`). The
   roles move to AI civs (the human is skipped), so one AI civ is an "aggressor" with no flags and one is "tall" with the
   tall opening book; **neither gets the greedy flags** (OthersBase excludes roles). The map still matches; the opposition
   doesn't. Use only if the lead wants the tall civ kept as a tall civ.

## Steps (do these after bullyabort13 finishes and Civ is closed)

1. Check no runner is running and Civ is closed. Don't touch the bullyabort runs while they play.
2. Install the build (`-NoLaunch` so Civ doesn't start yet):
   ```
   powershell -ExecutionPolicy Bypass -File tools\ab\Run-ABTest.ps1 -Release ab-850e142 -NoLaunch -NoUpdate
   ```
3. Turn logging on in `config.ini` (My Games\Sid Meier's Civilization 5): `LoggingEnabled = 1` and `AILog = 1`.
4. Move the old `AIABTest_c8e.csv` aside (rename it) so this game's rows start a fresh file.
5. Write `My Games\Sid Meier's Civilization 5\AIABTest.ini`, **ASCII, no BOM**:
   ```
   [ABTest]
   Fixes = none
   Screen =
   Base = GreedyFewUnits, GreedyNoWalls, GreedyNoUpgrades, GreedyBuilds
   RoleFixes =
   OthersBase =
   StopTurn = 100
   Ruins = 0
   MapOption5 = 5
   Mode =
   Difficulty = HANDICAP_KING
   Flip = 0
   MapSeed = 275744080
   SyncSeed = 275744080
   ```
   then append the civ and city-state lines from `results/replay/106F8550106F8550.ini`:
   ```
   findstr /R "^Player[0-9]* =" tools\ab\results\replay\106F8550106F8550.ini >> "%USERPROFILE%\Documents\My Games\Sid Meier's Civilization 5\AIABTest.ini"
   ```
   For Option B, edit `Player0` and `Player1` to swap the Aztec and the Zulu. The runner's `Civs = 6` key doesn't apply (8 civs).
   For roles option 2 use the bully keys above instead.
6. Start Civ V (`CivilizationV.exe` directly, not the DX11 launcher), then **Single Player > Set Up Game**: Pangaea, Standard,
   **8 civs**, **Quick** pace, King, and under Advanced Setup tick **Quick Combat** and **Quick Movement** (Civ doesn't
   remember them), all civs on separate teams. Pick any civ for yourself: the ini overrides it. Start the game.
7. **Immediately press Ctrl+Shift+O** (see "Blocker") to take your civ back from the AI.
8. Play to turn 100. Rows for every civ, yours included, are appended to `AIABTest_c8e.csv` every 10 turns. Quit after
   the T100 rows are in the file (the DLL doesn't stop a human game by itself; `StopTurn` is only recorded).
9. Copy the rows out and commit them like the runs (e.g. `results/AIABTest_humangame@BOX.csv`, with the logs).
10. **Before any multiplayer: `tools\ab\Run-ABTest.ps1 -Restore`.**

## DirectX 11, full screen (the user's wish)

What I found on PC 1 (read only, 2026-11-05):

- **Run-Games starts `CivilizationV.exe` (DX9) on purpose** (Run-Games.ps1 line 236): its click automation needs the DX9
  windowed mode set in `GraphicsSettingsDX9.ini`. **Leave `GraphicsSettingsDX9.ini` alone.** `Run-ABTest.ps1` without
  `-NoLaunch` starts `CivilizationV_DX11.exe` by default, so the test pack has been launched in DX11 before.
- **The two renderers have separate files.** `GraphicsSettingsDX11.ini` today: `FullScreen =0`, `FSResID =44`, `WindowResX =1914`,
  `WindowResY =2034`. I made a backup: `GraphicsSettingsDX11.ini.bak-windowed-20261105` in My Games\Sid Meier's Civilization 5.
- **Steam has no launch options** for Civ V (app 8930) in this account's `localconfig.vdf`, so nothing forces DX9 from Steam.
  If Steam's Play button asks which version to run, pick DirectX 11; or skip Steam and start
  `CivilizationV_DX11.exe` from `C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization V\` (Steam must be running).
- **Native resolution: 3840x2160** (the GPU reports it; Windows scales the desktop to 2560x1440 logical, so tools that read
  the screen see 2560x1440). The ini stores the full-screen mode as an id (`FSResID`), and I can't map id 44 to a
  resolution from here, so pick the resolution in the game rather than guessing an id.
- **Heads-up: two DX11 crash dumps exist** (`civilizationv_dx11_..._crash_2026_10_31T...mdmp`, 13:06 and 14:12 on Oct 31,
  in the Civ folder), from earlier DX11 sessions before the runs moved to DX9. Cause unknown. If DX11 crashes tonight, that
  is why to suspect it; a DX9 fallback is just `CivilizationV.exe`.

Steps (with Civ closed, after the build is installed and `AIABTest.ini` is written):

1. Set `FullScreen = 1` in `GraphicsSettingsDX11.ini` (keep the backup). Don't touch the DX9 file.
2. Start `CivilizationV_DX11.exe`. **Check the window title or the Task Manager name**: `(DX11)` and
   `CivilizationV_DX11.exe` mean DX11; `(DX9)` or `CivilizationV.exe` mean the launcher handed off to DX9 (an earlier
   session saw `CivilizationV_DX11.exe` hand off to `CivilizationV.exe`; UNVERIFIED which happens now, so check).
3. In the game open **Options > Video**, choose **3840x2160** (native) and full screen, then apply. Civ rewrites `FSResID` itself.
4. Go on with the setup (step 6 above), start the game, press **Ctrl+Shift+O** at once.
5. **Confirm the test-pack DLL is active in DX11.** It is the same `CvGameCore_Expansion2.dll` for both renderers, but I
   haven't run it, so confirm in the first minute: `AIABTest_lastgame.ini` in My Games gets a fresh timestamp and starts
   with `; written by the test game ...` (the DLL writes it at game start, only when the test pack's DLL is loaded), and
   at T10 the results CSV (`AIABTest_c8e.csv`, Build column `... 850e142 ...`) gets 8 rows, yours included. If neither
   appears, the DLL isn't loaded: close and tell the lead.
6. After the game: switch back isn't needed for the runs (they use the DX9 file), but **before multiplayer run
   `Run-ABTest.ps1 -Restore`** as always, and set `FullScreen = 0` again if full screen gets in the way of the runner
   (the runner only reads the DX9 file).

## Checking that the others got the greedy flags (the `Fixes` column)

Each results row's `Fixes` column lists the flags that civ ran. At T10:

- Every AI row should read `GreedyFewUnits+GreedyNoWalls+GreedyNoUpgrades+GreedyBuilds` (roles option 1).
- **The human's row should show no flags** (empty or `none`), since flags never go to a human.
- `Role` is empty for everyone in roles option 1; `Mode` is empty/split.

This is exactly how 106F8550's own rows read (greedy flags on the non-role civs, the 25-flag list on the aggressor).

## Blocker: the DLL hands the human's civ to the AI at turn 0

In `CvGame::update` (AI_AB_TEST block): *"test games are AI only, so at the start of a single player test game hand the
player's civ to the AI, the same as pressing Ctrl+Shift+O. Only on the first turn, so the player can still leave
observer mode later."* It applies when `MOD_AI_AB_TEST`, single player, turn 0, and the active player is human.

- **It is not a hard block.** Ctrl+Shift+O leaves observer mode (`CONTROL_TOGGLE_OBSERVER_MODE` returns the civ to the human).
  But the AI plays turn 0 first, so it makes the opening moves (founding the capital with the first settler, the first
  builds). Expect to inherit an AI-founded capital. For a "dominate the greedy civs" game that is probably fine.
- **Clean fix, if the lead wants it:** a `Human = 1` (or `KeepHuman`) key in AIABTest.ini that skips this block. A few
  lines in CvGame.cpp, then a new build. Not needed to start.
- **Not a blocker:** roles skip humans (no crash, just the role shift described above); the results rows include the
  human; flags are never applied to the human.

## Decision so far (the user, 2026-11-05)

**The user plays the Aztec tonight (Option A: slot 0, Montezuma).** So no civ swap is needed: use `Player0 = CIVILIZATION_AZTEC LEADER_MONTEZUMA`
exactly as the replay file has it, and the Zulu AI keeps slot 1. Questions 2 to 4 below are still open (my defaults:
roles option 1, inherit the AI-founded capital, Quick pace).

## Open questions for the lead

1. Option A (the user is the Aztec, slot 0) or Option B (the user is the Zulu, same slot numbers swapped)?
2. Roles option 1 (every AI greedy, no roles) or 2 (bully roles on AI civs)?
3. OK to inherit an AI-founded capital, or should War add the `Human = 1` skip?
4. Pace: Quick, as in 106F8550 (my default), or the user's "standard speed"?

## Setup done on PC 1 (2026-11-05, evening)

Set up with the steps above, Option A, roles option 1: build **ab-5b7333c** (the lead's choice: it has the tribute popup fix;
the greedy AIs don't use WarChestTribute; the replay game itself ran on 850e142), logging on, results file moved aside
(`AIABTest_c8e.before-humangame.csv`), `AIABTest.ini` written (every AI civ greedy, no roles, StopTurn 100, 51 civ, seed and
city-state keys), `GraphicsSettingsDX11.ini` has `FullScreen =1` (backup next to it), `GraphicsSettingsDX9.ini` untouched, Civ closed.
First steps for the player: start `CivilizationV_DX11.exe`, check the title bar says DX11, Options > Video > 3840x2160 full
screen, Single Player > Set Up Game (Pangaea, Standard, 8 civs, Quick, King, Quick Combat and Quick Movement), start, then
**Ctrl+Shift+O at once**. After the game: `Run-ABTest.ps1 -Restore` before any multiplayer.

## How the user won (106F8550, the user's account, 2026-11-05 evening)

The user played the Aztec and took Marrakesh, Morocco's capital and last city, at T54 (Quick). The results rows show
the war was declared between T41 and T50.
- **Tech:** a beeline to Construction. The user skipped Calendar too, so the Aztec citrus got no plantations.
- **Capital builds:** Jaguar, Jaguar, Jaguar, Worker, Settler, Archer x4, Jaguar, Jaguar. The second city built no
  units by T54.
- **Upgrade and go:** the user saved gold and, at Construction, upgraded 3 Archers to Composite Bowmen right before
  declaring. That's why the Aztec treasury fell from 263 to 31 between T40 and T50.
- **The army that took the capital:** about 6 Jaguars and 4 Composite Bowmen. The Jaguars had hunted barbarians and had the
  +33% ranged defence promotion. There was no siege. The user brute-forced through Marrakesh's walls ("i think i brute forced through marrakeshs walls"), so walls alone don't stop a strike with enough army.
- **The user's ruling:** the Jaguar suits this opening, so it can't be generalised. Every civ should build to its own strengths.
- **Before the war:** the first 3 Jaguars hunted barbarians for experience and promotions. The user opened **Honor**, not
  Liberty, "because of the barb hunting".
- **The user on other warmongers:** a late-spike civ like the Zulu should build infrastructure first, then time an Impi strike.
  So the aggressors split into early-spike civs (EarlyStrike) and late-spike civs (a timed strike). Personality's per-civ
  strike table will put each civ in one group.
