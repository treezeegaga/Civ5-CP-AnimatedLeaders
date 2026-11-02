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
    already set to Prince, Standard, Quick, 8 civs on separate teams (Civ remembers those, not the
    Quick Combat/Movement boxes). Click positions assume Civ opens its window centred on a 3840x2160
    screen at 150% scaling, which it does on this machine.

    Windowed Civ only takes clicks in the place it first opened its window, so setup happens there and the
    window is moved afterwards, with the same messages a title-bar drag sends.

    Create the file named by -StopFile to stop after the current game.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\ab\Run-Games.ps1 -MaxGames 1
#>
param(
    [int]$MaxGames = 1000,
    [int]$StopTurn = 150,
    [int]$StallMinutes = 30,          # no new results rows for this long = stuck; restart
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
    $xy = $P[$name]
    [AbInput]::SetCursorPos($xy[0] - 6, $xy[1] - 6) | Out-Null; Start-Sleep -Milliseconds 120
    [AbInput]::SetCursorPos($xy[0], $xy[1]) | Out-Null; Start-Sleep -Milliseconds 150
    [AbInput]::mouse_event(0x02, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 60
    [AbInput]::mouse_event(0x04, 0, 0, 0, [UIntPtr]::Zero)
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

function Start-TestGame {
    Stop-Civ
    Start-Process (Join-Path $CivDir "CivilizationV.exe") -WorkingDirectory $CivDir
    for ($i = 0; $i -lt 60 -and -not (Get-CivWindow); $i++) { Start-Sleep 2 }
    if (-not (Get-CivWindow)) { return $false }

    # Intro movie, then the legal screen once loading is done
    Start-Sleep 8
    Press-Escape
    Start-Sleep 30
    Click Continue 3000
    Click SinglePlayer 2000
    Click SetUpGame 2000
    Click AdvancedSetup 2500
    foreach ($box in "QuickCombat", "QuickMovement") {
        Set-CivFront
        [AbInput]::SetCursorPos($P.Neutral[0], $P.Neutral[1]) | Out-Null; Start-Sleep -Milliseconds 400
        if (-not (Test-Ticked $box)) { Click $box 800 }
    }
    [AbInput]::SetCursorPos($P.Neutral[0], $P.Neutral[1]) | Out-Null; Start-Sleep -Milliseconds 400
    $ticked = (Test-Ticked QuickCombat) -and (Test-Ticked QuickMovement)
    if (-not $ticked) { Write-Log "WARNING: Quick Combat/Movement not confirmed ticked; starting anyway" }
    Click StartGame 45000
    Click BeginJourney 8000

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
        if ($mine | Where-Object { $_.Final -eq '1' }) { return "won at turn $($last.Turn) ($($last.GameId))" }
        if ([int]$last.Turn -ge $StopTurn) { return "turn $($last.Turn) ($($last.GameId))" }
        if (((Get-Date) - $lastChange).TotalMinutes -ge $StallMinutes) { return "stalled at turn $($last.Turn) ($($last.GameId))" }
    }
}

Remove-Item $StopFile -ErrorAction SilentlyContinue
$played = 0
$failures = 0
while ($played -lt $MaxGames) {
    if (Test-Path $StopFile) { Write-Log "Stop file found; stopping"; break }
    $known = Get-GameIds
    Write-Log "Starting game $($played + 1)"
    if (-not (Start-TestGame)) { Write-Log "Civ V window never appeared"; $failures++; if ($failures -ge 3) { break }; continue }
    $status = Wait-TestGame $known
    Stop-Civ
    Write-Log "Game ended: $status"
    if ($status -eq "never started") { $failures++; if ($failures -ge 3) { Write-Log "Three failed starts in a row; giving up"; break }; continue }
    $failures = 0
    $played++
}
Write-Log "Runner finished after $played games"
