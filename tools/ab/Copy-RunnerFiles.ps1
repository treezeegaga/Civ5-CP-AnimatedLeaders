<#
.SYNOPSIS
    Moves the files a second PC runner needs from the first PC: Community Patch's mod folder and the repo's
    CPModpack\data (the database snapshot the test pack is built from; git doesn't track it).

.DESCRIPTION
    On the first PC:   -Export <folder>   writes civ-runner-files.zip there (a USB stick or a network share)
    On the second PC:  -Import <zip>      puts both folders in place and checks them against the zip's list

    Both PCs then build exactly the same test pack. Civ V doesn't need to be closed on the first PC.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\ab\Copy-RunnerFiles.ps1 -Export E:\
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\ab\Copy-RunnerFiles.ps1 -Import E:\civ-runner-files.zip
#>
param(
    [string]$Export = "",
    [string]$Import = "",
    [string]$MyGames = "$([Environment]::GetFolderPath('MyDocuments'))\My Games\Sid Meier's Civilization 5"
)
$ErrorActionPreference = "Stop"
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$cpDir = Join-Path $MyGames "MODS\(1) Community Patch"
$dataDir = Join-Path $repo "CPModpack\data"

# file count, bytes and the Community Patch DLL's hash: what "the same files" means here
function Get-Summary([string]$cp, [string]$data) {
    $cpFiles = @(Get-ChildItem $cp -Recurse -File)
    $dataFiles = @(Get-ChildItem $data -Recurse -File)
    $dll = Join-Path $cp "CvGameCore_Expansion2.dll"
    [ordered]@{
        cpFiles = $cpFiles.Count; cpBytes = [long](($cpFiles | Measure-Object Length -Sum).Sum)
        dataFiles = $dataFiles.Count; dataBytes = [long](($dataFiles | Measure-Object Length -Sum).Sum)
        cpDllSha256 = if (Test-Path $dll) { (Get-FileHash $dll -Algorithm SHA256).Hash } else { "" }
    }
}

if ($Export) {
    foreach ($d in $cpDir, $dataDir) { if (-not (Test-Path $d)) { throw "Missing $d" } }
    $stage = Join-Path ([IO.Path]::GetTempPath()) "civ-runner-files"
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force (Join-Path $stage "MODS") | Out-Null
    Copy-Item $cpDir (Join-Path $stage "MODS") -Recurse
    Copy-Item $dataDir (Join-Path $stage "CPModpack-data") -Recurse
    $sum = Get-Summary $cpDir $dataDir
    $sum | ConvertTo-Json | Set-Content (Join-Path $stage "summary.json")
    $zip = Join-Path $Export "civ-runner-files.zip"
    Remove-Item $zip -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip
    Remove-Item $stage -Recurse -Force
    "Wrote $zip ({0:N0} MB): Community Patch {1} files, CPModpack\data {2} files, DLL {3}" -f ((Get-Item $zip).Length / 1MB), $sum.cpFiles, $sum.dataFiles, $sum.cpDllSha256.Substring(0, 12)
}
elseif ($Import) {
    if (-not (Test-Path $Import)) { throw "No file $Import" }
    if (-not (Test-Path $MyGames)) { throw "No ${MyGames}: start Civ V once on this PC first" }
    $stage = Join-Path ([IO.Path]::GetTempPath()) "civ-runner-files-in"
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $Import -DestinationPath $stage
    $want = Get-Content (Join-Path $stage "summary.json") -Raw | ConvertFrom-Json
    # replace, never merge: leftovers from another Community Patch version would change the pack
    Remove-Item $cpDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force (Join-Path $MyGames "MODS") | Out-Null
    Copy-Item (Join-Path $stage "MODS\(1) Community Patch") (Join-Path $MyGames "MODS") -Recurse
    Remove-Item $dataDir -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $stage "CPModpack-data") $dataDir -Recurse
    Remove-Item $stage -Recurse -Force
    $got = Get-Summary $cpDir $dataDir
    $same = ($got.cpFiles -eq $want.cpFiles -and $got.cpBytes -eq $want.cpBytes -and $got.dataFiles -eq $want.dataFiles -and
        $got.dataBytes -eq $want.dataBytes -and $got.cpDllSha256 -eq $want.cpDllSha256)
    if (-not $same) { throw ("Copied files differ from the first PC's: got {0}, want {1}" -f ($got | ConvertTo-Json -Compress), ($want | ConvertTo-Json -Compress)) }
    "Installed: Community Patch ({0} files) in {1}, CPModpack\data ({2} files) in {3}; same as the first PC (DLL {4})" -f $got.cpFiles, $cpDir, $got.dataFiles, $dataDir, $got.cpDllSha256.Substring(0, 12)
}
else { throw "Use -Export <folder> on the first PC or -Import <zip> on the second" }
