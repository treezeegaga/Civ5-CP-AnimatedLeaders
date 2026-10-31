# Installs or removes the Community Patch MP pack (3D leaders) for Civilization V.
# Run through Install.bat / Uninstall.bat.
param([switch]$Uninstall, [string]$CivDir = "")

$ErrorActionPreference = "Stop"
$PackName = "MP_CPLeaderheads"
$here = $PSScriptRoot
$Host.UI.RawUI.WindowTitle = "Community Patch MP pack (3D leaders)"

function Finish([int]$code) {
    Write-Host ""
    if ($env:CPMP_NO_PAUSE -ne "1") { Read-Host "Press Enter to close" }   # keep the window open after double-clicking
    exit $code
}

function Say([string]$msg, [string]$color = "Gray") { Write-Host $msg -ForegroundColor $color }

function Test-CivDir([string]$dir) {
    return $dir -and (Test-Path (Join-Path $dir "Assets\DLC")) -and
        ((Test-Path (Join-Path $dir "CivilizationV.exe")) -or (Test-Path (Join-Path $dir "CivilizationV_DX11.exe")))
}

function Find-CivDir {
    # 1. Civ V's own uninstall entry, written by Steam
    foreach ($root in "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall") {
        $loc = (Get-ItemProperty "$root\Steam App 8930" -ErrorAction SilentlyContinue).InstallLocation
        if (Test-CivDir $loc) { return $loc }
    }
    # 2. Every Steam library folder
    $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { $steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath }
    if ($steam) {
        $libs = @($steam)
        $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += $m.Groups[1].Value.Replace("\\", "\") }
        }
        foreach ($lib in $libs) {
            $dir = Join-Path $lib "steamapps\common\Sid Meier's Civilization V"
            if (Test-CivDir $dir) { return $dir }
        }
    }
    # 3. Ask
    Say "Couldn't find Civilization V automatically. Please pick its folder (the one with CivilizationV.exe)." Yellow
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select your Sid Meier's Civilization V folder (it contains CivilizationV.exe)"
    if ($dlg.ShowDialog() -eq "OK" -and (Test-CivDir $dlg.SelectedPath)) { return $dlg.SelectedPath }
    return $null
}

try {
    Say ""
    Say "=== Community Patch MP pack (3D leaders) ===" Cyan
    $version = (Get-Content (Join-Path $here "PackVersion.txt") -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($version) { Say "Pack version: $version" }
    Say ""

    if (-not (Test-CivDir $CivDir)) { $CivDir = Find-CivDir }
    if (-not $CivDir) { Say "Civilization V wasn't found, so nothing was changed." Red; Finish 1 }
    Say "Civilization V: $CivDir"
    $dlcDir = Join-Path $CivDir "Assets\DLC"
    $target = Join-Path $dlcDir $PackName

    # Civ V must be closed, or its files are locked and the game keeps the old pack loaded.
    while (Get-Process -Name CivilizationV, CivilizationV_DX11, CivilizationV_Tablet -ErrorAction SilentlyContinue) {
        Say "Civilization V is running. Close it, then press Enter." Yellow
        Read-Host | Out-Null
    }

    # Steam's folder is often writable without admin rights; if not, restart this script as admin.
    $canWrite = $true
    try {
        $probe = Join-Path $dlcDir "__write_test.tmp"
        New-Item -ItemType File -Path $probe -Force -ErrorAction Stop | Out-Null
        Remove-Item $probe -Force -ErrorAction Stop
    }
    catch { $canWrite = $false }
    if (-not $canWrite) {
        Say "The game folder needs administrator rights. Asking Windows for permission..." Yellow
        $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-CivDir", "`"$CivDir`"")
        if ($Uninstall) { $psArgs += "-Uninstall" }
        Start-Process powershell -Verb RunAs -ArgumentList $psArgs
        exit 0
    }

    if ($Uninstall) {
        if (Test-Path $target) {
            Remove-Item -Recurse -Force $target
            Say "Removed. Civilization V is back to normal." Green
        }
        else {
            Say "The pack wasn't installed. Nothing to remove." Green
        }
        Finish 0
    }

    # Community Patch needs every expansion and DLC; the game crashes without them.
    $required = [ordered]@{
        "Expansion"  = "Gods & Kings"
        "Expansion2" = "Brave New World"
        "DLC_Deluxe" = "Babylon (Nebuchadnezzar)"
        "DLC_01"     = "Mongolia (Genghis Khan)"
        "DLC_02"     = "Spain and Inca"
        "DLC_03"     = "Polynesia"
        "DLC_04"     = "Denmark - The Vikings"
        "DLC_05"     = "Korea"
        "DLC_06"     = "Wonders of the Ancient World"
        "DLC_07"     = "Conquest of the New World Deluxe"
    }
    $missing = @($required.Keys | Where-Object { -not (Test-Path (Join-Path $dlcDir $_)) })
    if ($missing.Count -gt 0) {
        Say "These DLC aren't installed:" Red
        foreach ($m in $missing) { Say "  - $($required[$m])" Red }
        Say ""
        Say "In Steam: right-click Civilization V > Properties > DLC, tick them all, then let Steam download them." Yellow
        Say "Nothing was changed." Yellow
        Finish 1
    }
    Say "All required DLC found."

    $source = Join-Path $here $PackName
    if (-not (Test-Path $source)) { Say "The pack folder is missing next to this installer. Unzip the whole download first." Red; Finish 1 }

    if (Test-Path $target) {
        Say "Removing the previous version..."
        Remove-Item -Recurse -Force $target
    }
    Say "Copying files (about 115 MB)..."
    Copy-Item -Recurse $source $target

    $expected = @(Get-ChildItem $source -Recurse -File).Count
    $actual = @(Get-ChildItem $target -Recurse -File).Count
    if ($actual -ne $expected) { Say "Only $actual of $expected files were copied. Try again, or run as administrator." Red; Finish 1 }

    Say ""
    Say "Installed! ($actual files)" Green
    Say ""
    Say "How to play:" Cyan
    Say "  1. Start Civilization V normally. Don't enable any mods in the Mods menu."
    Say "  2. Multiplayer > Internet or LAN > host or join a NEW game."
    Say "     (Old saves from the unmodded game can't be loaded with this pack.)"
    Say "  3. Everyone in the game needs this same pack. Compare the pack version above."
    Say ""
    Say "To go back to the normal game, run Uninstall.bat."
    Finish 0
}
catch {
    Say ""
    Say "Something went wrong: $($_.Exception.Message)" Red
    Finish 1
}
