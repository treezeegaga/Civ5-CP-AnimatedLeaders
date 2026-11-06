<#
.SYNOPSIS
    One command for AI A/B test games.

.DESCRIPTION
    By default:
      1. updates this repo (git pull), if git is installed;
      2. prints the results collected so far;
      3. downloads the newest test DLL from the fork's "ab-c-latest" GitHub release (no login needed): the
         newest build of the integration branch claude/ab-c1. -Release picks another: ab-<commit> for one
         build, ab-ai-<topic>-latest for a topic branch's newest, ab-latest for stage 1 (new AI vs CP);
      4. builds and installs the test pack (Build-CPModpack.ps1 -ABTest -Install);
      5. starts Civ V.
    In a test game observer mode turns itself on at the start, so after setting up the game there is
    nothing to press: the AIs play until someone wins.

    -Summary only prints the results. -Restore puts the normal multiplayer pack back.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\ab\Run-ABTest.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\ab\Run-ABTest.ps1 -Summary
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\ab\Run-ABTest.ps1 -Restore
#>
param(
    [string]$Release = "ab-c-latest", # or ab-<commit> for a specific build, ab-latest for stage 1
    [switch]$Summary,                 # only print the results so far
    [switch]$Restore,                 # install the normal multiplayer pack again
    [switch]$NoLaunch,                # don't start Civ V
    [switch]$NoUpdate,                # don't git pull
    [string]$Branch = "claude/sleepy-hopper-x77moh",
    [string]$CivDir = "C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization V",
    [string]$MyGames = "$([Environment]::GetFolderPath('MyDocuments'))\My Games\Sid Meier's Civilization 5"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest is very slow with the progress bar in Windows PowerShell

$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$builder = Join-Path $repo "CPModpack\Build-CPModpack.ps1"
$summarizer = Join-Path $PSScriptRoot "Summarize-ABTest.ps1"

function Write-Step([string]$text) { Write-Host ""; Write-Host "== $text" -ForegroundColor Cyan }

function Show-Results {
    Write-Step "Results so far"
    if (@(Get-ChildItem -Path $MyGames -Filter "AIABTest*.csv" -ErrorAction SilentlyContinue).Count -eq 0) {
        Write-Host "No test games logged yet."
        return
    }
    & $summarizer -MyGames $MyGames
}

function Start-Civ {
    if ($NoLaunch) { return }
    Write-Step "Starting Civ V"
    $exe = Join-Path $CivDir "CivilizationV_DX11.exe"
    if (Test-Path $exe) { Start-Process -FilePath $exe -WorkingDirectory $CivDir }
    else { Start-Process "steam://rungameid/8930" }
}

if ($Summary) { Show-Results; return }

if (Get-Process -Name CivilizationV_DX11, CivilizationV, CivilizationV_Tablet -ErrorAction SilentlyContinue) {
    throw "Civ V is running. Close it first."
}

if (-not $NoUpdate -and (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Step "Updating the repo"
    $current = (& git -C $repo rev-parse --abbrev-ref HEAD).Trim()
    if ($current -eq $Branch) {
        & git -C $repo pull --ff-only origin $Branch
        if ($LASTEXITCODE -ne 0) { Write-Warning "git pull failed; carrying on with the files you have." }
    } else {
        Write-Warning "The repo is on branch '$current', not '$Branch'; not updating it."
    }
}

if ($Restore) {
    Write-Step "Installing the normal multiplayer pack"
    $normalDll = Join-Path $repo "CPLeaderheads\build\CvGameCore_Expansion2.msvc-coredrive.dll"
    if (Test-Path $normalDll) { & $builder -CivDir $CivDir -MyGames $MyGames -Dll $normalDll -Install }
    else { & $builder -CivDir $CivDir -MyGames $MyGames -Install }
    Write-Host ""
    Write-Host "Normal pack installed. Ready for multiplayer." -ForegroundColor Green
    return
}

Show-Results

Write-Step "Downloading the test DLL ($Release)"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
# which build that is (a "latest" release moves with each build)
try {
    $info = Invoke-RestMethod -Uri "https://api.github.com/repos/treezeegaga/Community-Patch-DLL/releases/tags/$Release" -UseBasicParsing
    Write-Host ("Release '{0}': {1}, published {2}" -f $Release, $info.name, $info.published_at)
} catch { Write-Warning "Couldn't read the release's details ($($_.Exception.Message)); downloading anyway." }
$dllDir = Join-Path $env:TEMP "cpmodpack\abtest\$Release"
New-Item -ItemType Directory -Force -Path $dllDir | Out-Null
$dll = Join-Path $dllDir "CvGameCore_Expansion2.dll"
$url = "https://github.com/treezeegaga/Community-Patch-DLL/releases/download/$Release/CvGameCore_Expansion2.dll"
try {
    Invoke-WebRequest -Uri $url -OutFile $dll -UseBasicParsing
} catch {
    throw "Couldn't download $url ($($_.Exception.Message)). The build may still be running; try again later."
}
Write-Host "Saved $dll ($([math]::Round((Get-Item $dll).Length / 1MB, 1)) MB)"

Write-Step "Building and installing the test pack"
& $builder -CivDir $CivDir -MyGames $MyGames -Dll $dll -ABTest -Install

# Check the install took (2026-11-05: PC 1 reported installing ab-db638c3 and ab-40203a3 but kept playing 8fe8e0f).
# Every copy of the DLL in the pack's DLC folder must match the download byte for byte (not the base game's own
# DLL in Assets\DLC\Expansion2).
$want = (Get-FileHash $dll -Algorithm SHA256).Hash
$packDir = Join-Path $CivDir "Assets\DLC\MP_CPLeaderheads"
$installed = @(Get-ChildItem $packDir -Recurse -Filter "CvGameCore_Expansion2.dll" -File -ErrorAction SilentlyContinue)
if ($installed.Count -eq 0) { throw "No CvGameCore_Expansion2.dll under $packDir after the install." }
$bad = @($installed | Where-Object { (Get-FileHash $_.FullName -Algorithm SHA256).Hash -ne $want })
if ($bad.Count) {
    throw ("The installed DLL isn't $Release" + ": " + (($bad | ForEach-Object { "$($_.FullName) ($($_.Length) bytes)" }) -join "; ") + ". Close Civ V and run this again.")
}
Write-Host ("Installed DLL checked: {0} cop{1} match {2} ({3} bytes)" -f $installed.Count, $(if ($installed.Count -eq 1) { "y" } else { "ies" }), $Release, (Get-Item $dll).Length) -ForegroundColor Green

Start-Civ

Write-Step "In Civ V"
Write-Host @"
Single Player > Set Up Game:
  - Difficulty: King
  - Map type: Pangaea
  - Map size: Standard, 8 civilizations (Civ V remembers these settings next time)
  - Game pace: Quick
  - Advanced Setup: tick Quick Combat and Quick Movement
Start the game and leave it running. Observer mode turns on by itself, so the AI plays every civ,
yours included, until someone wins. Results are saved every 10 turns, so you can quit any time
(games shorter than 100 turns aren't counted).

Afterwards:
  - results:           powershell -ExecutionPolicy Bypass -File tools\ab\Run-ABTest.ps1 -Summary
  - before multiplayer: powershell -ExecutionPolicy Bypass -File tools\ab\Run-ABTest.ps1 -Restore
"@
