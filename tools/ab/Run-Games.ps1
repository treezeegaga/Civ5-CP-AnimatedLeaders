<#
.SYNOPSIS
    Plays AI A/B test games back to back with no one at the keyboard.

.DESCRIPTION
    For each game: starts Civ V windowed, clicks through Single Player > Set Up Game > Advanced Setup, ticks
    Quick Combat and Quick Movement, starts the game (observer mode turns itself on), moves the window to the
    left half of the screen, waits until the game logs -StopTurn (or someone wins), then closes Civ V and
    writes one line to the runner log.

    Needs the test pack installed (Run-ABTest.ps1 -NoLaunch), windowed mode in GraphicsSettingsDX9.ini
    (FullScreen = 0, WindowResX = 1914, WindowResY = 2034 on a 3840x2160 screen) and the setup screens
    already set to Pangaea, Prince, Standard, Quick, 8 civs on separate teams (Civ remembers those, not the
    Quick Combat/Movement boxes). Ruins and the resources setting aren't clicked: the test DLL sets them
    from AIABTest.ini (Ruins = 0, MapOption5 = 5 for Strategic Balance). Once a game logs its first rows
    (turn 10), the runner checks its map, options, pace, difficulty, size and civ count against the
    -Expect* values and stops if anything is off, so no games are spent on the wrong setup. Click positions assume Civ opens its window centred on a 3840x2160
    screen at 150% scaling, which it does on this machine.

    Windowed Civ only takes clicks in the place it first opened its window, so setup happens there and the
    window is moved afterwards, with the same messages a title-bar drag sends.

    Create the file named by -StopFile to stop after the current game (after the current pair when games are paired).

    Paired games (C builds from fork commit 7097d49 on): games are played in pairs on the same map. Before each game the
    runner writes AIABTest.ini in My Games with -Fixes and -Screen. The first game of a pair is a normal game; when
    it starts, the DLL writes its seeds, civs and city-states to AIABTest_lastgame.ini. The second game gets those
    keys plus Flip = 1, so it replays the first game's start with the groups swapped. -Unpaired plays single games.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -MaxGames 2
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -Fixes CanWin -MaxGames 20
#>
param(
    [int]$MaxGames = 1000,            # games, not pairs (paired runs stop after a whole pair)
    [string]$Fixes = "bundle",        # AIABTest.ini Fixes = (candidate flags group c runs)
    [string]$Screen = "",             # AIABTest.ini Screen = (flags each on for a random half of the AI civs)
    [switch]$Unpaired,                # single games instead of pairs
    [switch]$NoSettings,              # leave AIABTest.ini alone (builds before c7c_flags, or a hand-written file)
    [int]$Ruins = 0,                  # AIABTest.ini Ruins = (0 = no ancient ruins)
    [int]$Resources = 5,              # AIABTest.ini MapOption5 = (Pangaea's resources option; 5 = Strategic Balance)
    # the setup every game must have; checked against the first results rows (files from c7c_settings on)
    [string]$ExpectMap = "Pangaea",
    [string]$ExpectPace = "GAMESPEED_QUICK",
    [string]$ExpectDifficulty = "HANDICAP_PRINCE",
    [string]$ExpectSize = "WORLDSIZE_STANDARD",
    [int]$ExpectCivs = 8,
    [int]$StopTurn = 150,
    [int]$StallMinutes = 30,          # no new results rows for this long = stuck; restart
    [switch]$AttachRunning,           # a test game is already running: finish it first, then start new ones
    [string]$StopFile = "$PSScriptRoot\STOP",
    [string]$Log = "$PSScriptRoot\Run-Games.log",
    [string]$CivDir = "C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization V",
    [string]$MyGames = "$([Environment]::GetFolderPath('MyDocuments'))\My Games\Sid Meier's Civilization 5"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class AbInput {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint f, UIntPtr e);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@
[AbInput]::SetProcessDPIAware() | Out-Null
. (Join-Path $PSScriptRoot "CivScreens.ps1")   # Get-CivScreen, Get-CivBeginButtonDistance

# Physical screen positions of the buttons with Civ's window where it opens (top-left 963,63; client 1914x2034)
$P = @{
    Continue      = @(1920, 1311)   # legal screen "Click to Continue"
    SinglePlayer  = @(1920, 973)
    SetUpGame     = @(1928, 1034)
    AdvancedSetup = @(1999, 1398)
    QuickCombat   = @(1920, 1556)
    QuickMovement = @(1920, 1582)
    StartGame     = @(2231, 2054)
    BeginJourney  = @(1920, 1453)
    Neutral       = @(1920, 300)    # black band at the top of the window, nothing to click there
}

$SettingsFile = Join-Path $MyGames "AIABTest.ini"
$ReplayFile = Join-Path $MyGames "AIABTest_lastgame.ini"

# AIABTest.ini for the next game: the flags, and for the second game of a pair the first game's replay keys and Flip = 1
function Write-Settings([string[]]$replay) {
    if ($NoSettings) { return }
    $lines = @("; written by Run-Games.ps1", "[ABTest]", "Fixes = $Fixes", "Screen = $Screen", "StopTurn = $StopTurn",
        "Ruins = $Ruins", "MapOption5 = $Resources")
    if ($replay) { $lines += "Flip = 1"; $lines += $replay } else { $lines += "Flip = 0" }
    [IO.File]::WriteAllLines($SettingsFile, [string[]]$lines, [Text.Encoding]::ASCII)
}

# The replay keys the DLL wrote when the current game started (MapSeed, SyncSeed, Player<i>), or $null
function Read-Replay {
    if (-not (Test-Path $ReplayFile)) { return $null }
    $keys = @(Get-Content $ReplayFile | Where-Object { $_ -match '^\s*(MapSeed|SyncSeed|Player\d+)\s*=' } | ForEach-Object { $_.Trim() })
    if ($keys.Count -eq 0) { return $null }
    return $keys
}

# What's wrong with a game's setup, from its first results rows; "" if it's right or the build doesn't record it
function Test-Setup($gameRows) {
    $r = $gameRows[0]
    if (-not ($r.PSObject.Properties.Name -contains "Map")) { return "" }
    $problems = @()
    if ($r.Map -ne $ExpectMap) { $problems += "map $($r.Map) (want $ExpectMap)" }
    if ($r.Pace -ne $ExpectPace) { $problems += "pace $($r.Pace) (want $ExpectPace)" }
    if ($r.Difficulty -ne $ExpectDifficulty) { $problems += "difficulty $($r.Difficulty) (want $ExpectDifficulty)" }
    if ($r.WorldSize -ne $ExpectSize) { $problems += "size $($r.WorldSize) (want $ExpectSize)" }
    $civs = @($gameRows | Where-Object { $_.Turn -eq $r.Turn } | ForEach-Object { $_.Player } | Sort-Object -Unique).Count
    if ($civs -ne $ExpectCivs) { $problems += "$civs civs (want $ExpectCivs)" }
    if (-not $NoSettings) {
        if ([int]$r.Ruins -ne $Ruins) { $problems += "ruins $($r.Ruins) (want $Ruins)" }
        if (@($r.MapOptions -split ';') -notcontains "5=$Resources") { $problems += "map options $($r.MapOptions) (want 5=$Resources)" }
    }
    return ($problems -join "; ")
}

function Write-Log([string]$text) {
    $line = "{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $text
    Add-Content -Path $Log -Value $line
    Write-Output $line
}

function Get-CivWindow { Get-Process CivilizationV -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1 }

function Stop-Civ {
    Get-Process CivilizationV, CivilizationV_DX11 -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep 3
}

function Set-CivFront {
    $w = Get-CivWindow
    if (-not $w) { return }
    # Windows only lets a background process take the foreground right after a key press
    [AbInput]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [AbInput]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    [AbInput]::SetForegroundWindow($w.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 300
}

function Click([string]$name, [int]$waitMs = 1500) {
    Set-CivFront
    # a click on an inactive window only activates it, so click the empty band at the top first
    [AbInput]::SetCursorPos($P.Neutral[0], $P.Neutral[1]) | Out-Null; Start-Sleep -Milliseconds 100
    [AbInput]::mouse_event(0x02, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 60
    [AbInput]::mouse_event(0x04, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 300
    $xy = $P[$name]
    [AbInput]::SetCursorPos($xy[0] - 6, $xy[1] - 6) | Out-Null; Start-Sleep -Milliseconds 120
    [AbInput]::SetCursorPos($xy[0], $xy[1]) | Out-Null; Start-Sleep -Milliseconds 150
    [AbInput]::mouse_event(0x02, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 60
    [AbInput]::mouse_event(0x04, 0, 0, 0, [UIntPtr]::Zero)
    # move away so no hover tooltip covers what we check next
    Start-Sleep -Milliseconds 100
    [AbInput]::SetCursorPos($P.Neutral[0], $P.Neutral[1]) | Out-Null
    Start-Sleep -Milliseconds $waitMs
}

function Press-Escape {
    Set-CivFront
    [AbInput]::keybd_event(0x1B, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 60; [AbInput]::keybd_event(0x1B, 0, 2, [UIntPtr]::Zero)
}

# A ticked box has a bright green check mark; an empty one is dark teal
function Test-Ticked([string]$name) {
    $xy = $P[$name]
    $bmp = New-Object System.Drawing.Bitmap 20, 20
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($xy[0] - 10, $xy[1] - 10, 0, 0, $bmp.Size)
    $green = 0
    for ($x = 0; $x -lt 20; $x++) { for ($y = 0; $y -lt 20; $y++) {
        $c = $bmp.GetPixel($x, $y)
        if ($c.G -gt 120 -and $c.G -gt $c.R + 30 -and $c.G -gt $c.B + 30) { $green++ }
    } }
    $g.Dispose(); $bmp.Dispose()
    return ($green -ge 8)
}

function Get-ResultsFile { Get-ChildItem $MyGames -Filter "AIABTest*.csv" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1 }
function Get-GameIds { $f = Get-ResultsFile; if ($f) { @(Import-Csv $f.FullName | ForEach-Object { $_.GameId } | Sort-Object -Unique) } else { @() } }

# True once the screen matches a saved one (CivScreens.json; same screen ~0, different screens 4 or more)
function Test-Screen([string]$name) { $s = Get-CivScreen; return ($s.Name -eq $name -and $s.Distance -lt 2.5) }
function Wait-Screen([string]$name, [int]$timeoutSec = 30) {
    $until = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $until) { if (Test-Screen $name) { return $true }; Start-Sleep 1 }
    return $false
}

function Start-TestGame {
    Stop-Civ
    Start-Process (Join-Path $CivDir "CivilizationV.exe") -WorkingDirectory $CivDir
    for ($i = 0; $i -lt 60 -and -not (Get-CivWindow); $i++) { Start-Sleep 2 }
    if (-not (Get-CivWindow)) { Write-Log "  no Civ V window"; return $false }

    # Intro movie, loading, then the legal screen. Click its Continue button until the main menu shows; never
    # click there once the menu is up, because the menu's EXIT button is at nearly the same spot.
    $until = (Get-Date).AddSeconds(240)
    while (-not (Test-Screen menu)) {
        if ((Get-Date) -gt $until) { Write-Log "  main menu never showed"; return $false }
        Click Continue 4000
    }
    Click SinglePlayer
    if (-not (Wait-Screen single)) { Write-Log "  Single Player menu never showed"; return $false }
    Click SetUpGame
    if (-not (Wait-Screen setup)) { Write-Log "  Set Up Game never showed"; return $false }
    Click AdvancedSetup
    if (-not (Wait-Screen advanced)) { Write-Log "  Advanced Setup never showed"; return $false }
    foreach ($box in "QuickCombat", "QuickMovement") {
        for ($try = 0; $try -lt 3 -and -not (Test-Ticked $box); $try++) { Click $box 800 }
        if (-not (Test-Ticked $box)) { Write-Log "  couldn't tick $box"; return $false }
    }
    Click StartGame 5000

    # Loading the map; then the "Begin Your Journey" screen
    $until = (Get-Date).AddSeconds(240)
    while ((Get-CivBeginButtonDistance) -ge 8) {
        if ((Get-Date) -gt $until) { Write-Log "  Begin Your Journey never showed"; return $false }
        Start-Sleep 3
    }
    for ($try = 0; $try -lt 3 -and (Get-CivBeginButtonDistance) -lt 8; $try++) { Click BeginJourney 3000 }

    # Move to the left half the way a title-bar drag would, and the Claude app to the right half
    $h = (Get-CivWindow).MainWindowHandle
    [AbInput]::SendMessage($h, 0x0231, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
    [AbInput]::SetWindowPos($h, [IntPtr]::Zero, 0, 0, 0, 0, 0x0005) | Out-Null
    [AbInput]::SendMessage($h, 0x0232, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
    $claude = Get-Process claude -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -eq 'Claude' } | Select-Object -First 1
    if ($claude) { [AbInput]::SetWindowPos($claude.MainWindowHandle, [IntPtr]::Zero, 1920, 0, 1920, 2088, 0x0040) | Out-Null }
    return $true
}

# Waits for the new game's rows; returns a short status
function Wait-TestGame([string[]]$knownIds) {
    $started = Get-Date
    $lastRows = -1; $lastChange = Get-Date
    $checked = $false
    while ($true) {
        Start-Sleep 20
        if (-not (Get-CivWindow)) { return "civ exited" }
        $f = Get-ResultsFile
        $rows = if ($f) { @(Import-Csv $f.FullName) } else { @() }
        if ($rows.Count -ne $lastRows) { $lastRows = $rows.Count; $lastChange = Get-Date }
        $mine = @($rows | Where-Object { $knownIds -notcontains $_.GameId })
        if ($mine.Count -eq 0) {
            if (((Get-Date) - $started).TotalMinutes -ge 8) { return "never started" }
            continue
        }
        $last = $mine[-1]
        if (-not $checked) {
            $checked = $true
            $wrong = Test-Setup $mine
            if ($wrong) { return "WRONG SETUP ($($last.GameId)): $wrong" }
        }
        if ($mine | Where-Object { $_.Final -eq '1' }) { return "won at turn $($last.Turn) ($($last.GameId))" }
        if ([int]$last.Turn -ge $StopTurn) { return "turn $($last.Turn) ($($last.GameId))" }
        if (((Get-Date) - $lastChange).TotalMinutes -ge $StallMinutes) {
            # keep what the screen showed and whether Civ was hung, to tell a hang from a blocking popup or crash dialog
            $shot = Join-Path $PSScriptRoot ("stall-{0:yyyyMMdd-HHmmss}.png" -f (Get-Date))
            try {
                $bmp = New-Object System.Drawing.Bitmap 3840, 2160
                $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen(0, 0, 0, 0, $bmp.Size); $g.Dispose()
                $bmp.Save($shot); $bmp.Dispose()
            } catch { $shot = "(screenshot failed)" }
            $civ = Get-Process CivilizationV -ErrorAction SilentlyContinue | Select-Object -First 1
            return "stalled at turn $($last.Turn) ($($last.GameId)); responding $($civ.Responding); screenshot $shot"
        }
    }
}

Remove-Item $StopFile -ErrorAction SilentlyContinue
$played = 0
$failures = 0
$pairReplay = $null   # set while the second game of a pair is due: the first game's replay keys
while ($played -lt $MaxGames -or $pairReplay) {
    if (-not $pairReplay -and (Test-Path $StopFile)) { Write-Log "Stop file found; stopping"; break }
    $known = Get-GameIds
    if ($AttachRunning -and $played -eq 0 -and $failures -eq 0 -and (Get-CivWindow)) {
        # the newest game in the results file is the one running; it's played as a single game
        $f = Get-ResultsFile
        $current = if ($f) { (Import-Csv $f.FullName)[-1].GameId } else { $null }
        $known = @($known | Where-Object { $_ -ne $current })
        Write-Log "Finishing the game already running ($current)"
        $wasFirstOfPair = $false
    } else {
        $wasFirstOfPair = (-not $Unpaired -and -not $NoSettings -and -not $pairReplay)
        Write-Settings $pairReplay
        if ($wasFirstOfPair) { Remove-Item $ReplayFile -ErrorAction SilentlyContinue }
        $what = if ($pairReplay) { "second game of the pair (Flip = 1)" } elseif ($wasFirstOfPair) { "first game of a pair" } else { "single game" }
        Write-Log "Starting game $($played + 1): $what; Fixes = $Fixes; Screen = $Screen"
        if (-not (Start-TestGame)) { Write-Log "Setup failed; retrying"; $failures++; if ($failures -ge 3) { Write-Log "Three failed starts in a row; giving up"; break }; continue }

        $replay = Read-Replay
        if ($wasFirstOfPair -and -not $replay) {
            Write-Log "  no $ReplayFile after the start (a build before fork commit 7097d49?); playing single games"
            $wasFirstOfPair = $false
        }
        if ($pairReplay -and $replay) {
            # the second game should have started exactly like the first
            $diff = @(Compare-Object $pairReplay $replay | ForEach-Object { $_.InputObject })
            if ($diff.Count -eq 0) { Write-Log "  replay matches the first game" }
            else { Write-Log ("  REPLAY DIFFERS from the first game: " + ($diff -join "; ")) }
        }
    }
    $status = Wait-TestGame $known
    Stop-Civ
    Write-Log "Game ended: $status"
    if ($status -like "WRONG SETUP*") { Write-Log "Stopping: fix the setup screens (or the -Expect* values) and start again"; break }
    if ($status -eq "never started") { $failures++; if ($failures -ge 3) { Write-Log "Three failed starts in a row; giving up"; break }; continue }
    $failures = 0
    $played++
    if ($wasFirstOfPair) { $pairReplay = $replay } else { $pairReplay = $null }
}
if (-not $NoSettings) { Write-Settings $null }   # leave a plain file behind, so a game started by hand isn't a replay
Write-Log "Runner finished after $played games"
